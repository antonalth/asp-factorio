#!/usr/bin/env python3
from __future__ import annotations

import math
import re
import subprocess
from collections import defaultdict
from pathlib import Path


ATOM_RE = re.compile(r"([a-z_][a-zA-Z0-9_]*)\(([^)]*)\)")


def split_args(arg_text: str) -> list[str]:
    parts: list[str] = []
    buffer: list[str] = []
    depth = 0
    for char in arg_text:
        if char == "," and depth == 0:
            parts.append("".join(buffer).strip())
            buffer = []
            continue
        if char == "(":
            depth += 1
        elif char == ")":
            depth -= 1
        buffer.append(char)
    if buffer:
        parts.append("".join(buffer).strip())
    return parts


def parse_atoms(text: str) -> dict[str, list[tuple[str, ...]]]:
    atoms: dict[str, list[tuple[str, ...]]] = defaultdict(list)
    for match in ATOM_RE.finditer(text):
        pred = match.group(1)
        atoms[pred].append(tuple(split_args(match.group(2))))
    return atoms


def extract_answer_atoms(text: str) -> dict[str, list[tuple[str, ...]]]:
    lines = text.splitlines()
    answer_indices = [idx for idx, line in enumerate(lines) if line.startswith("Answer:")]
    if not answer_indices:
        raise RuntimeError("No answer found in solver output.")

    atom_lines: list[str] = []
    for line in lines[answer_indices[-1] + 1 :]:
        stripped = line.strip()
        if not stripped:
            break
        if stripped.startswith("Optimization:") or stripped.startswith("SATISFIABLE"):
            break
        if stripped.startswith("OPTIMUM FOUND") or stripped.startswith("Models"):
            break
        atom_lines.append(stripped)
    return parse_atoms(" ".join(atom_lines))


def run_graph_solver(instance_path: str | Path, root: str | Path = ".") -> str:
    root_path = Path(root).resolve()
    instance = Path(instance_path)
    if not instance.is_absolute():
        instance = (root_path / instance).resolve()
    cmd = [
        "clingcon",
        "graph.lp",
        "game.lp",
        str(instance.relative_to(root_path)),
        "--opt-mode=opt",
        "--quiet=1",
    ]
    proc = subprocess.run(
        cmd,
        cwd=root_path,
        capture_output=True,
        text=True,
        check=False,
    )
    output = proc.stdout + proc.stderr
    if proc.returncode not in {0, 10, 20, 30}:
        raise RuntimeError(f"clingcon failed for {instance}:\n{output}")
    if "UNSATISFIABLE" in output:
        raise RuntimeError(f"graph model is UNSAT for {instance}")
    return output


def run_graph_phase(
    instance_path: str | Path,
    log_path: str | Path,
    root: str | Path = ".",
) -> Path:
    root_path = Path(root).resolve()
    instance = Path(instance_path)
    if not instance.is_absolute():
        instance = (root_path / instance).resolve()
    log = Path(log_path)
    if not log.is_absolute():
        log = (root_path / log).resolve()

    log.parent.mkdir(parents=True, exist_ok=True)
    output = run_graph_solver(instance, root=root_path)
    header = [
        "================ GRAPH BEGIN ================",
        f"Instance: {instance.relative_to(root_path)}",
        "------------------------------------------------",
        instance.read_text(),
        "",
        "================ CLINGCON OUTPUT ================",
        output.rstrip(),
        "",
    ]
    log.write_text("\n".join(header))
    return log


def parse_goal_facts(text: str) -> tuple[set[str], set[str]]:
    goal_items: set[str] = set()
    goal_buildings: set[str] = set()
    for pred, args in ATOM_RE.findall(text):
        split = split_args(args)
        if pred == "goal_item" and split:
            goal_items.add(split[0])
        elif pred == "goal_building" and split:
            goal_buildings.add(split[0])
    return goal_items, goal_buildings


def parse_graph_log(log_path: str | Path) -> tuple[dict[str, list[tuple[str, ...]]], set[str], set[str]]:
    text = Path(log_path).read_text()
    atoms = extract_answer_atoms(text)
    goal_items, goal_buildings = parse_goal_facts(text)
    return atoms, goal_items, goal_buildings


def _add_item_nodes(
    node_ids: set[str],
    nodes: dict[str, dict[str, object]],
    items: set[str],
    base_items: set[str],
    goal_items: set[str],
) -> None:
    for item in sorted(items):
        node_id = f"item:{item}"
        node_ids.add(node_id)
        nodes[node_id] = {
            "label": item,
            "kind": "item",
            "base": item in base_items,
            "goal": item in goal_items,
        }


def _add_building_nodes(
    node_ids: set[str],
    nodes: dict[str, dict[str, object]],
    buildings: set[str],
    goal_buildings: set[str],
) -> None:
    for building in sorted(buildings):
        node_id = f"building:{building}"
        node_ids.add(node_id)
        nodes[node_id] = {
            "label": building,
            "kind": "building",
            "base": False,
            "goal": building in goal_buildings,
        }


def _add_craft_nodes(
    node_ids: set[str],
    nodes: dict[str, dict[str, object]],
    crafts: set[str],
) -> None:
    for craft in sorted(crafts):
        node_id = f"craft:{craft}"
        node_ids.add(node_id)
        nodes[node_id] = {
            "label": craft,
            "kind": "craft",
            "base": False,
            "goal": False,
        }


def build_global_graph(
    atoms: dict[str, list[tuple[str, ...]]],
    goal_items: set[str] | None = None,
    goal_buildings: set[str] | None = None,
) -> tuple[dict[str, dict[str, object]], list[tuple[str, str, str]]]:
    goal_items = goal_items or set()
    goal_buildings = goal_buildings or set()

    nodes: dict[str, dict[str, object]] = {}
    node_ids: set[str] = set()
    edges: set[tuple[str, str, str]] = set()

    base_items = {args[0] for args in atoms.get("source_item", [])}
    if not base_items:
        base_items = {args[0] for args in atoms.get("base_item", [])}
    items = {args[0] for args in atoms.get("graph_item", [])}
    buildings = {args[0] for args in atoms.get("graph_building", [])}
    crafts = {args[0] for args in atoms.get("graph_craft", [])}

    _add_item_nodes(node_ids, nodes, items, base_items, goal_items)
    _add_building_nodes(node_ids, nodes, buildings, goal_buildings)
    _add_craft_nodes(node_ids, nodes, crafts)

    for building, item in atoms.get("graph_requires_building", []):
        edges.add((f"item:{item}", f"building:{building}", "requires"))
    for craft, item in atoms.get("graph_requires_craft", []):
        edges.add((f"item:{item}", f"craft:{craft}", "requires"))
    for building, item in atoms.get("graph_produces_building", []):
        edges.add((f"building:{building}", f"item:{item}", "produces"))
    for craft, item in atoms.get("graph_produces_craft", []):
        edges.add((f"craft:{craft}", f"item:{item}", "produces"))

    return nodes, sorted(edges)


def build_selected_graph(
    atoms: dict[str, list[tuple[str, ...]]],
    goal_items: set[str],
    goal_buildings: set[str],
) -> tuple[dict[str, dict[str, object]], list[tuple[str, str, str]]]:
    nodes: dict[str, dict[str, object]] = {}
    node_ids: set[str] = set()
    edges: set[tuple[str, str, str]] = set()

    base_items = {args[0] for args in atoms.get("source_item", [])}
    if not base_items:
        base_items = {args[0] for args in atoms.get("base_item", [])}
    need_items = {args[0] for args in atoms.get("need_item", [])}
    need_buildings = {args[0] for args in atoms.get("need_building", [])}
    need_crafts = {args[0] for args in atoms.get("need_craft", [])}

    _add_item_nodes(node_ids, nodes, need_items, base_items, goal_items)
    _add_building_nodes(node_ids, nodes, need_buildings, goal_buildings)
    _add_craft_nodes(node_ids, nodes, need_crafts)

    selected_building_outputs = {(item, building) for item, building in atoms.get("support_building", [])}
    selected_craft_outputs = {(item, craft) for item, craft in atoms.get("support_craft", [])}

    for building, item in atoms.get("graph_requires_building", []):
        if building in need_buildings and item in need_items:
            edges.add((f"item:{item}", f"building:{building}", "requires"))
    for craft, item in atoms.get("graph_requires_craft", []):
        if craft in need_crafts and item in need_items:
            edges.add((f"item:{item}", f"craft:{craft}", "requires"))
    for item, building in selected_building_outputs:
        edges.add((f"building:{building}", f"item:{item}", "produces"))
    for item, craft in selected_craft_outputs:
        edges.add((f"craft:{craft}", f"item:{item}", "produces"))

    return nodes, sorted(edges)


def compute_depths_from_base(
    nodes: dict[str, dict[str, object]],
    edges: list[tuple[str, str, str]],
) -> dict[str, int]:
    item_depths: dict[str, int] = {
        node_id: 0
        for node_id, data in nodes.items()
        if data["kind"] == "item" and data["base"]
    }
    producer_depths: dict[str, int] = {}

    required_items: dict[str, set[str]] = defaultdict(set)
    produced_items: dict[str, set[str]] = defaultdict(set)

    for src, dst, edge_kind in edges:
        if edge_kind == "requires":
            required_items[dst].add(src)
        elif edge_kind == "produces":
            produced_items[src].add(dst)

    producer_nodes = {
        node_id
        for node_id, data in nodes.items()
        if data["kind"] in {"building", "craft"}
    }

    changed = True
    while changed:
        changed = False

        for producer_id in sorted(producer_nodes):
            producer_reqs = required_items.get(producer_id, set())
            if any(req not in item_depths for req in producer_reqs):
                continue

            if producer_reqs:
                candidate_depth = max(item_depths[req] for req in producer_reqs) + 1
            else:
                candidate_depth = 1

            current_depth = producer_depths.get(producer_id)
            if current_depth is None or candidate_depth < current_depth:
                producer_depths[producer_id] = candidate_depth
                changed = True

            for item_id in produced_items.get(producer_id, set()):
                item_candidate = candidate_depth + 1
                current_item_depth = item_depths.get(item_id)
                if current_item_depth is None or item_candidate < current_item_depth:
                    item_depths[item_id] = item_candidate
                    changed = True

    depths = dict(item_depths)
    depths.update(producer_depths)

    missing = [node_id for node_id in nodes if node_id not in depths]
    if missing:
        raise RuntimeError(
            "Could not assign depths from base resources to every selected node. "
            f"Missing: {', '.join(sorted(missing))}"
        )
    return depths


def layered_positions(
    nodes: dict[str, dict[str, object]],
    depths: dict[str, int],
) -> dict[str, tuple[float, float]]:
    buckets: dict[int, list[str]] = defaultdict(list)
    for node_id, depth in depths.items():
        buckets[depth].append(node_id)

    positions: dict[str, tuple[float, float]] = {}
    kind_order = {"item": 0, "building": 1, "craft": 2}
    for depth in sorted(buckets):
        bucket = sorted(
            buckets[depth],
            key=lambda node_id: (kind_order[nodes[node_id]["kind"]], str(nodes[node_id]["label"])),
        )
        count = len(bucket)
        for index, node_id in enumerate(bucket):
            y = -float(index - (count - 1) / 2.0)
            positions[node_id] = (float(depth), y)
    return positions


def graph_log_to_lp(log_path: str | Path, out_path: str | Path) -> Path:
    atoms, goal_items, goal_buildings = parse_graph_log(log_path)
    nodes, edges = build_selected_graph(atoms, goal_items, goal_buildings)
    depths = compute_depths_from_base(nodes, edges)

    out = Path(out_path)
    out.parent.mkdir(parents=True, exist_ok=True)

    lines = [
        "% Generated from phase-1 graph solve.",
    ]

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

    max_depth = max(depths.values(), default=0)
    lines.append(f"hint_max_depth({max_depth}).")

    for node_id, depth in sorted(depths.items()):
        kind, name = node_id.split(":", 1)
        if kind == "item":
            lines.append(f"hint_depth_item({name}, {depth}).")
        elif kind == "building":
            lines.append(f"hint_depth_building({name}, {depth}).")
        elif kind == "craft":
            lines.append(f"hint_depth_craft({name}, {depth}).")

    out.write_text("\n".join(lines) + "\n")
    return out
