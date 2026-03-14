#!/usr/bin/env python3
from __future__ import annotations

import math
import re
import subprocess
import tempfile
from collections import defaultdict, deque
from pathlib import Path


ATOM_RE = re.compile(r"([a-z_][a-zA-Z0-9_]*)\(([^)]*)\)")


def split_args(arg_text: str) -> list[str]:
    parts: list[str] = []
    buf: list[str] = []
    depth = 0
    for ch in arg_text:
        if ch == "," and depth == 0:
            parts.append("".join(buf).strip())
            buf = []
            continue
        if ch == "(":
            depth += 1
        elif ch == ")":
            depth -= 1
        buf.append(ch)
    if buf:
        parts.append("".join(buf).strip())
    return parts


def parse_atoms(text: str) -> dict[str, list[tuple[str, ...]]]:
    atoms: dict[str, list[tuple[str, ...]]] = defaultdict(list)
    for match in ATOM_RE.finditer(text):
        pred = match.group(1)
        args = tuple(split_args(match.group(2)))
        atoms[pred].append(args)
    return atoms


def parse_goal_text(text: str) -> tuple[set[str], set[str]]:
    goal_items: set[str] = set()
    goal_buildings: set[str] = set()
    for pred, args in ATOM_RE.findall(text):
        split = split_args(args)
        if pred == "goal_item" and split:
            goal_items.add(split[0])
        elif pred == "goal_building" and split:
            goal_buildings.add(split[0])
    return goal_items, goal_buildings


def parse_goal_file(goal_file: Path) -> tuple[set[str], set[str]]:
    return parse_goal_text(goal_file.read_text())


def extract_goal_file(instance_file: Path) -> Path:
    goal_lines = [
        line
        for line in instance_file.read_text().splitlines()
        if line.strip().startswith("goal_item(") or line.strip().startswith("goal_building(")
    ]
    if not goal_lines:
        raise ValueError(f"No goal facts found in {instance_file}")
    tmp_goal = Path(tempfile.gettempdir()) / f"{instance_file.stem}_goals.lp"
    tmp_goal.write_text("\n".join(goal_lines) + "\n")
    return tmp_goal


def run_graph_solver(goal_file: Path, root: Path) -> str:
    cmd = [
        "clingcon",
        "graph.lp",
        "game.lp",
        str(goal_file),
        "--opt-mode=opt",
        "--quiet=1",
    ]
    proc = subprocess.run(
        cmd,
        cwd=root,
        capture_output=True,
        text=True,
        check=False,
    )
    output = proc.stdout + proc.stderr
    if proc.returncode not in {0, 10, 20, 30}:
        raise RuntimeError(f"clingcon failed for {goal_file}:\n{output}")
    if "UNSATISFIABLE" in output:
        raise RuntimeError(f"graph model is UNSAT for {goal_file}")
    return output


def extract_answer_atoms(output: str) -> dict[str, list[tuple[str, ...]]]:
    lines = output.splitlines()
    answer_indices = [i for i, line in enumerate(lines) if line.startswith("Answer:")]
    if not answer_indices:
        raise RuntimeError("No answer found in solver output.")

    answer_idx = answer_indices[-1]
    atom_lines: list[str] = []
    for line in lines[answer_idx + 1 :]:
        stripped = line.strip()
        if not stripped or stripped.startswith("Assignment:") or stripped.startswith("Optimization:"):
            break
        atom_lines.append(stripped)
    return parse_atoms(" ".join(atom_lines))


def parse_graph_log(log_path: str | Path) -> tuple[dict[str, list[tuple[str, ...]]], set[str], set[str]]:
    text = Path(log_path).read_text()
    atoms = extract_answer_atoms(text)
    goal_items, goal_buildings = parse_goal_text(text)
    return atoms, goal_items, goal_buildings


def build_support_graph(
    atoms: dict[str, list[tuple[str, ...]]],
    target_items: set[str],
    target_buildings: set[str],
) -> tuple[dict[str, dict[str, object]], list[tuple[str, str, str]]]:
    nodes: dict[str, dict[str, object]] = {}
    edge_set: set[tuple[str, str, str]] = set()

    source_items = {args[0] for args in atoms.get("source_item", [])}
    need_items = {args[0] for args in atoms.get("need_item", [])}
    need_buildings = {args[0] for args in atoms.get("need_building", [])}
    need_crafts = {args[0] for args in atoms.get("need_craft", [])}
    req_building = {(b, i) for b, i in atoms.get("full_requires_building", [])}
    req_craft = {(c, i) for c, i in atoms.get("full_requires_craft", [])}

    for item in need_items:
        nodes[f"item:{item}"] = {
            "label": item,
            "kind": "item",
            "source": item in source_items,
            "goal": item in target_items,
        }

    for building in need_buildings:
        nodes[f"build:{building}"] = {
            "label": building,
            "kind": "building",
            "source": False,
            "goal": building in target_buildings,
        }

    for craft in need_crafts:
        nodes[f"craft:{craft}"] = {
            "label": craft,
            "kind": "craft",
            "source": False,
            "goal": False,
        }

    for building in need_buildings:
        pnode = f"build:{building}"
        for b, req_item in req_building:
            if b == building and req_item in need_items:
                edge_set.add((f"item:{req_item}", pnode, "requires"))

    for craft in need_crafts:
        pnode = f"craft:{craft}"
        for c, req_item in req_craft:
            if c == craft and req_item in need_items:
                edge_set.add((f"item:{req_item}", pnode, "requires"))

    for item, building in atoms.get("support_building", []):
        edge_set.add((f"build:{building}", f"item:{item}", "produces"))

    for item, craft in atoms.get("support_craft", []):
        edge_set.add((f"craft:{craft}", f"item:{item}", "produces"))

    return nodes, sorted(edge_set)


def compute_levels(nodes: dict[str, dict[str, object]], edges: list[tuple[str, str, str]]) -> dict[str, int]:
    outgoing: dict[str, list[str]] = defaultdict(list)
    indegree = {node: 0 for node in nodes}
    undirected: dict[str, set[str]] = defaultdict(set)

    for src, dst, _kind in edges:
        outgoing[src].append(dst)
        indegree[dst] += 1
        undirected[src].add(dst)
        undirected[dst].add(src)

    queue = deque([node for node, deg in indegree.items() if deg == 0])
    levels = {node: 0 for node in queue}
    seen = 0

    while queue:
        node = queue.popleft()
        seen += 1
        base = levels[node]
        for succ in outgoing[node]:
            levels[succ] = max(levels.get(succ, 0), base + 1)
            indegree[succ] -= 1
            if indegree[succ] == 0:
                queue.append(succ)

    if seen == len(nodes):
        return levels

    seed_nodes = [node for node, data in nodes.items() if data.get("source")]
    if not seed_nodes:
        seed_nodes = [next(iter(nodes))]

    levels = {node: math.inf for node in nodes}
    queue = deque(seed_nodes)
    for node in seed_nodes:
        levels[node] = 0

    while queue:
        node = queue.popleft()
        for nbr in undirected[node]:
            if levels[nbr] == math.inf:
                levels[nbr] = levels[node] + 1
                queue.append(nbr)

    max_level = max(v for v in levels.values() if v != math.inf)
    for node in nodes:
        if levels[node] == math.inf:
            max_level += 1
            levels[node] = max_level
    return levels


def layered_positions(nodes: dict[str, dict[str, object]], levels: dict[str, int]) -> dict[str, tuple[float, float]]:
    buckets: dict[int, list[str]] = defaultdict(list)
    for node, level in levels.items():
        buckets[level].append(node)

    positions: dict[str, tuple[float, float]] = {}
    for level in sorted(buckets):
        bucket = sorted(
            buckets[level],
            key=lambda n: (0 if nodes[n]["kind"] == "item" else 1, str(nodes[n]["label"])),
        )
        count = len(bucket)
        for idx, node in enumerate(bucket):
            positions[node] = (float(level), -float(idx - (count - 1) / 2.0))
    return positions


def reverse_goal_depths(
    nodes: dict[str, dict[str, object]],
    edges: list[tuple[str, str, str]],
) -> dict[str, int]:
    reverse_adj: dict[str, list[str]] = defaultdict(list)
    for src, dst, _kind in edges:
        reverse_adj[dst].append(src)

    goal_nodes = [node for node, data in nodes.items() if data.get("goal")]
    if not goal_nodes:
        return {node: 0 for node in nodes}

    dist = {node: math.inf for node in nodes}
    queue = deque(goal_nodes)
    for node in goal_nodes:
        dist[node] = 0

    while queue:
        node = queue.popleft()
        for prev in reverse_adj[node]:
            if dist[prev] == math.inf:
                dist[prev] = dist[node] + 1
                queue.append(prev)

    max_seen = max(v for v in dist.values() if v != math.inf)
    for node in nodes:
        if dist[node] == math.inf:
            max_seen += 1
            dist[node] = max_seen
    return {node: int(value) for node, value in dist.items()}


def graph_log_to_lp(log_path: str | Path, out_path: str | Path) -> Path:
    atoms, goal_items, goal_buildings = parse_graph_log(log_path)
    nodes, edges = build_support_graph(atoms, goal_items, goal_buildings)
    depths = reverse_goal_depths(nodes, edges)
    out = Path(out_path)

    lines: list[str] = []
    for item, in sorted(atoms.get("need_item", [])):
        lines.append(f"hint_item({item}).")
    for building, in sorted(atoms.get("need_building", [])):
        lines.append(f"hint_building({building}).")
    for craft, in sorted(atoms.get("need_craft", [])):
        lines.append(f"hint_craft({craft}).")
    for item, building in sorted(atoms.get("support_building", [])):
        lines.append(f"hint_support_building({item}, {building}).")
    for item, craft in sorted(atoms.get("support_craft", [])):
        lines.append(f"hint_support_craft({item}, {craft}).")

    for node_id, depth in sorted(depths.items()):
        kind, name = node_id.split(":", 1)
        if kind == "item":
            lines.append(f"hint_depth_item({name}, {depth}).")
        elif kind == "build":
            lines.append(f"hint_depth_building({name}, {depth}).")
        elif kind == "craft":
            lines.append(f"hint_depth_craft({name}, {depth}).")

    out.write_text("\n".join(lines) + "\n")
    return out
