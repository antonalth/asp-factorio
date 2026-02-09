#!/usr/bin/env python3
import argparse
import math
import re
import sys
from collections import Counter, defaultdict

from PIL import Image, ImageDraw, ImageFont


ANSWER_BLOCK_RE = re.compile(
    r"Answer:\s*\d+.*?\n(.*?)(?=\nAssignment:|\nAnswer:|\nSATISFIABLE|\nUNSATISFIABLE|\Z)",
    re.S,
)
ASSIGNMENT_BLOCK_RE = re.compile(
    r"Assignment:\s*\n(.*?)(?=\nCost:|\nOptimization:|\nSATISFIABLE|\nUNSATISFIABLE|\nAnswer:|\Z)",
    re.S,
)
ATOM_ASSIGN_RE = re.compile(r"([a-zA-Z_]\w*)\(([^()]*)\)=(-?\d+)")
INT_RE = re.compile(r"^-?\d+$")


COLORS = [
    (31, 119, 180),
    (255, 127, 14),
    (44, 160, 44),
    (214, 39, 40),
    (148, 103, 189),
    (140, 86, 75),
    (227, 119, 194),
    (127, 127, 127),
    (188, 189, 34),
    (23, 190, 207),
    (0, 102, 204),
    (204, 102, 0),
]

PAGE_W = 1650
PAGE_H = 1275


def parse_args():
    parser = argparse.ArgumentParser(
        description="Parse clingcon output from stdin and generate a PDF of step-wise graphs."
    )
    parser.add_argument("-o", "--output", default="clingcon_report.pdf")
    parser.add_argument("--max-series-per-page", type=int, default=12)
    return parser.parse_args()


def parse_answer_atoms(text):
    blocks = ANSWER_BLOCK_RE.findall(text)
    return blocks[-1].strip() if blocks else ""


def parse_assignment_atoms(text):
    blocks = ASSIGNMENT_BLOCK_RE.findall(text)
    if not blocks:
        return []
    return [(name, args, int(val)) for name, args, val in ATOM_ASSIGN_RE.findall(blocks[-1])]


def split_atom_args(args_str):
    if not args_str:
        return ()
    return tuple(a.strip() for a in args_str.split(","))


def is_int_str(s):
    return bool(INT_RE.match(s))


def parse_event_atoms(answer_atoms_str):
    event_tokens = answer_atoms_str.split()
    craft_act, build_act, craft_finish, build_finish, slot_map = [], [], [], [], []
    for tok in event_tokens:
        m = re.match(r"act\(craft\(([^)]+)\),(\d+)\)$", tok)
        if m:
            craft_act.append((m.group(1), int(m.group(2))))
            continue
        m = re.match(r"act\(build\(([^,]+),(\d+)\),(\d+)\)$", tok)
        if m:
            build_act.append((m.group(1), int(m.group(2)), int(m.group(3))))
            continue
        m = re.match(r"finish\(craft\(([^)]+)\),(\d+)\)$", tok)
        if m:
            craft_finish.append((m.group(1), int(m.group(2))))
            continue
        m = re.match(r"finish\(build\(([^,]+),(\d+)\),(\d+)\)$", tok)
        if m:
            build_finish.append((m.group(1), int(m.group(2)), int(m.group(3))))
            continue
        m = re.match(r"slot_map\((\d+),(\d+),([^)]+)\)$", tok)
        if m:
            slot_map.append((int(m.group(1)), int(m.group(2)), m.group(3)))
    return craft_act, build_act, craft_finish, build_finish, slot_map


def build_time_series(assignments):
    timed = defaultdict(lambda: defaultdict(dict))
    scalar = defaultdict(dict)
    max_time = 0
    for pred, args_str, val in assignments:
        args = split_atom_args(args_str)
        if args and is_int_str(args[-1]):
            t = int(args[-1])
            timed[pred][args[:-1]][t] = val
            max_time = max(max_time, t)
        else:
            scalar[pred][args] = val
    return timed, scalar, max_time


def chunked(seq, n):
    for i in range(0, len(seq), n):
        yield seq[i : i + n]


def series_rank(points):
    if not points:
        return 0
    return max(abs(v) for _, v in points)


def new_page(title):
    img = Image.new("RGB", (PAGE_W, PAGE_H), "white")
    draw = ImageDraw.Draw(img)
    font = ImageFont.load_default()
    draw.text((40, 24), title, fill="black", font=font)
    return img, draw, font


def draw_multiline(draw, x, y, text, font, line_h=15):
    for line in text.splitlines():
        draw.text((x, y), line, fill="black", font=font)
        y += line_h


def draw_chart(draw, title, series, x_min, x_max, y_min, y_max, font):
    left, top = 80, 80
    right, bottom = 1180, 1120
    legend_x = 1220

    draw.text((left, 52), title, fill="black", font=font)
    draw.rectangle([left, top, right, bottom], outline="black", width=2)

    if x_max == x_min:
        x_max += 1
    if y_max == y_min:
        y_max += 1

    def px_x(x):
        return int(left + (x - x_min) * (right - left) / (x_max - x_min))

    def px_y(y):
        return int(bottom - (y - y_min) * (bottom - top) / (y_max - y_min))

    # grid
    for i in range(0, 6):
        gx = left + i * (right - left) // 5
        gy = top + i * (bottom - top) // 5
        draw.line([(gx, top), (gx, bottom)], fill=(225, 225, 225), width=1)
        draw.line([(left, gy), (right, gy)], fill=(225, 225, 225), width=1)

    # ticks
    for i in range(0, 6):
        tx = x_min + (x_max - x_min) * i / 5
        ty = y_min + (y_max - y_min) * (5 - i) / 5
        draw.text((left + i * (right - left) // 5 - 10, bottom + 8), f"{tx:.0f}", fill="black", font=font)
        draw.text((left - 55, top + i * (bottom - top) // 5 - 6), f"{ty:.0f}", fill="black", font=font)

    # lines
    for i, (label, pts) in enumerate(series):
        color = COLORS[i % len(COLORS)]
        pts = sorted(pts)
        path = []
        for t, v in pts:
            path.append((px_x(t), px_y(v)))
        if len(path) >= 2:
            draw.line(path, fill=color, width=2)
        elif len(path) == 1:
            x, y = path[0]
            draw.ellipse([x - 2, y - 2, x + 2, y + 2], fill=color, outline=color)
        ly = 90 + i * 14
        draw.line([(legend_x, ly + 6), (legend_x + 20, ly + 6)], fill=color, width=2)
        draw.text((legend_x + 26, ly), label[:58], fill="black", font=font)


def make_summary_page(total_assignments, timed, scalar, max_time):
    img, draw, font = new_page("Clingcon Output Summary")
    timed_preds = sorted(timed.keys())
    scalar_preds = sorted(scalar.keys())
    text = "\n".join(
        [
            f"Total assignment atoms parsed: {total_assignments}",
            f"Timed predicates: {len(timed_preds)}",
            f"Scalar predicates: {len(scalar_preds)}",
            f"Max observed time index: {max_time}",
            "",
            "Timed predicates:",
            ", ".join(timed_preds) if timed_preds else "(none)",
            "",
            "Scalar predicates:",
            ", ".join(scalar_preds) if scalar_preds else "(none)",
        ]
    )
    draw_multiline(draw, 40, 70, text, font)
    return img


def make_event_page(craft_act, build_act, craft_finish, build_finish, max_time):
    horizon = max(
        [max_time]
        + [t for _, t in craft_act]
        + [t for _, _, t in build_act]
        + [t for _, t in craft_finish]
        + [t for _, _, t in build_finish]
    )
    xs = list(range(horizon + 1))

    def counts(vals):
        c = Counter(vals)
        return [(x, c.get(x, 0)) for x in xs]

    series = [
        ("act craft", counts([t for _, t in craft_act])),
        ("act build", counts([t for _, _, t in build_act])),
        ("finish craft", counts([t for _, t in craft_finish])),
        ("finish build", counts([t for _, _, t in build_finish])),
    ]

    img, draw, font = new_page("Action/Finish Counts by Step")
    all_y = [v for _, pts in series for _, v in pts]
    draw_chart(draw, "event_counts", series, 0, max(xs) if xs else 1, 0, max(all_y) if all_y else 1, font)
    return img


def make_slot_map_page(slot_map):
    img, draw, font = new_page("slot_map")
    if not slot_map:
        txt = "(No slot_map atoms found)"
    else:
        txt = "\n".join(
            f"zone={z:>2} slot={s:>2} building={b}" for z, s, b in sorted(slot_map)
        )
    draw_multiline(draw, 40, 70, txt, font)
    return img


def make_predicate_pages(timed, max_series_per_page):
    pages = []
    for pred in sorted(timed.keys()):
        labels_points = []
        min_t = math.inf
        max_t = -math.inf
        for key, tv in timed[pred].items():
            pts = sorted(tv.items())
            if not pts:
                continue
            label = pred + "(" + ",".join(key + ("t",)) + ")"
            labels_points.append((label, pts))
            min_t = min(min_t, pts[0][0])
            max_t = max(max_t, pts[-1][0])
        if not labels_points:
            continue

        labels_points.sort(key=lambda it: (-series_rank(it[1]), it[0]))
        for idx, chunk in enumerate(chunked(labels_points, max_series_per_page), start=1):
            all_y = [v for _, pts in chunk for _, v in pts]
            y_min = min(all_y) if all_y else 0
            y_max = max(all_y) if all_y else 1
            if y_min > 0:
                y_min = 0
            img, draw, font = new_page(f"{pred} over time (page {idx})")
            draw_chart(
                draw,
                f"{pred} over time (page {idx})",
                chunk,
                int(min_t),
                int(max_t),
                int(y_min),
                int(y_max),
                font,
            )
            pages.append(img)
    return pages


def main():
    args = parse_args()
    raw = sys.stdin.read()
    if not raw.strip():
        print("No input provided on stdin.", file=sys.stderr)
        return 1

    answer_atoms = parse_answer_atoms(raw)
    assignments = parse_assignment_atoms(raw)
    craft_act, build_act, craft_finish, build_finish, slot_map = parse_event_atoms(answer_atoms)
    timed, scalar, max_time = build_time_series(assignments)

    pages = [
        make_summary_page(len(assignments), timed, scalar, max_time),
        make_event_page(craft_act, build_act, craft_finish, build_finish, max_time),
        make_slot_map_page(slot_map),
    ]
    pages.extend(make_predicate_pages(timed, args.max_series_per_page))

    if not pages:
        print("No pages generated.", file=sys.stderr)
        return 1

    pages[0].save(args.output, "PDF", resolution=100.0, save_all=True, append_images=pages[1:])
    print(f"Wrote PDF: {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
