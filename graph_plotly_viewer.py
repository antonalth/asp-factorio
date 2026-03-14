#!/usr/bin/env python3
"""Render phase-1 dependency graphs as Plotly figures."""
from __future__ import annotations

from pathlib import Path
from typing import Mapping, Sequence

import plotly.graph_objects as go

from graph_tools import (
    build_global_graph,
    build_selected_graph,
    compute_depths_from_base,
    layered_positions,
    parse_graph_log,
    run_graph_solver,
)


class GoalDependencyViewer:
    def __init__(
        self,
        nodes: Mapping[str, Mapping[str, object]],
        edges: Sequence[tuple[str, str, str]],
        title: str,
    ) -> None:
        self.nodes = {node_id: dict(data) for node_id, data in nodes.items()}
        self.edges = list(edges)
        self.title = title
        self.depths = compute_depths_from_base(self.nodes, self.edges)
        self.positions = layered_positions(self.nodes, self.depths)

    @classmethod
    def from_log(
        cls,
        log_path: str | Path,
        graph_kind: str = "selected",
    ) -> "GoalDependencyViewer":
        log = Path(log_path).resolve()
        atoms, goal_items, goal_buildings = parse_graph_log(log)
        if graph_kind == "global":
            nodes, edges = build_global_graph(atoms, goal_items, goal_buildings)
        else:
            nodes, edges = build_selected_graph(atoms, goal_items, goal_buildings)
        return cls(nodes, edges, title=f"{graph_kind.title()} dependency graph: {log.stem}")

    @classmethod
    def from_instance(
        cls,
        instance_path: str | Path,
        root: str | Path = ".",
        graph_kind: str = "selected",
    ) -> "GoalDependencyViewer":
        root_path = Path(root).resolve()
        instance = Path(instance_path)
        if not instance.is_absolute():
            instance = (root_path / instance).resolve()
        output = run_graph_solver(instance, root=root_path)
        atoms = parse_graph_log_text(output, instance.read_text())
        goal_items, goal_buildings = atoms["goals"]
        if graph_kind == "global":
            nodes, edges = build_global_graph(atoms["atoms"], goal_items, goal_buildings)
        else:
            nodes, edges = build_selected_graph(atoms["atoms"], goal_items, goal_buildings)
        return cls(nodes, edges, title=f"{graph_kind.title()} dependency graph: {instance.stem}")

    def _edge_traces(self, edge_kind: str, color: str) -> list[go.Scatter]:
        xs: list[float | None] = []
        ys: list[float | None] = []
        hover_x: list[float] = []
        hover_y: list[float] = []
        hover_text: list[str] = []

        for src, dst, current_kind in self.edges:
            if current_kind != edge_kind:
                continue
            x1, y1 = self.positions[src]
            x2, y2 = self.positions[dst]
            xs.extend([x1, x2, None])
            ys.extend([y1, y2, None])
            hover_x.append((x1 + x2) / 2.0)
            hover_y.append((y1 + y2) / 2.0)
            hover_text.append(f"{self.nodes[src]['label']} -> {self.nodes[dst]['label']}<br>{edge_kind}")

        line_trace = go.Scatter(
            x=xs,
            y=ys,
            mode="lines",
            line=dict(color=color, width=1.8),
            hoverinfo="skip",
            name=edge_kind,
        )
        hover_trace = go.Scatter(
            x=hover_x,
            y=hover_y,
            mode="markers",
            marker=dict(size=10, color=color, opacity=0.0),
            hovertemplate="%{text}<extra></extra>",
            text=hover_text,
            showlegend=False,
        )
        return [line_trace, hover_trace]

    def _node_traces(self) -> list[go.Scatter]:
        groups = {
            "base_item": {"nodes": [], "color": "#d4d4d8", "symbol": "circle"},
            "item": {"nodes": [], "color": "#93c5fd", "symbol": "circle"},
            "building": {"nodes": [], "color": "#86efac", "symbol": "square"},
            "craft": {"nodes": [], "color": "#fdba74", "symbol": "diamond"},
        }

        for node_id, data in self.nodes.items():
            if data["kind"] == "item" and data["base"]:
                groups["base_item"]["nodes"].append(node_id)
            else:
                groups[data["kind"]]["nodes"].append(node_id)

        traces: list[go.Scatter] = []
        for name, config in groups.items():
            node_ids = config["nodes"]
            if not node_ids:
                continue
            traces.append(
                go.Scatter(
                    x=[self.positions[node_id][0] for node_id in node_ids],
                    y=[self.positions[node_id][1] for node_id in node_ids],
                    mode="markers+text",
                    text=[str(self.nodes[node_id]["label"]) for node_id in node_ids],
                    textposition="middle center",
                    hovertemplate="%{customdata}<extra></extra>",
                    customdata=[
                        f"{self.nodes[node_id]['label']}"
                        f"<br>kind={self.nodes[node_id]['kind']}"
                        f"<br>base={self.nodes[node_id]['base']}"
                        f"<br>goal={self.nodes[node_id]['goal']}"
                        f"<br>depth={self.depths[node_id]}"
                        for node_id in node_ids
                    ],
                    marker=dict(
                        size=30,
                        color=config["color"],
                        symbol=config["symbol"],
                        line=dict(color="#1f2937", width=1),
                    ),
                    name=name,
                )
            )

        goal_nodes = [node_id for node_id, data in self.nodes.items() if data["goal"]]
        if goal_nodes:
            traces.append(
                go.Scatter(
                    x=[self.positions[node_id][0] for node_id in goal_nodes],
                    y=[self.positions[node_id][1] for node_id in goal_nodes],
                    mode="markers",
                    marker=dict(size=40, color="rgba(0,0,0,0)", line=dict(color="#dc2626", width=3)),
                    hoverinfo="skip",
                    name="goal",
                )
            )
        return traces

    def figure(self, width: int = 1400, height: int | None = None) -> go.Figure:
        if height is None:
            height = max(700, 60 * len(self.nodes))

        traces = []
        traces.extend(self._edge_traces("requires", "#6b7280"))
        traces.extend(self._edge_traces("produces", "#2563eb"))
        traces.extend(self._node_traces())

        fig = go.Figure(traces)
        fig.update_layout(
            title=self.title,
            width=width,
            height=height,
            showlegend=True,
            plot_bgcolor="white",
            paper_bgcolor="white",
            margin=dict(l=20, r=20, t=50, b=20),
            dragmode="pan",
        )
        fig.update_xaxes(showgrid=False, zeroline=False, visible=False)
        fig.update_yaxes(showgrid=False, zeroline=False, visible=False, scaleanchor="x", scaleratio=1)
        return fig

    def show(self, width: int = 1400, height: int | None = None) -> go.Figure:
        fig = self.figure(width=width, height=height)
        fig.show()
        return fig


def parse_graph_log_text(
    solver_output: str,
    instance_text: str,
) -> dict[str, object]:
    from graph_tools import extract_answer_atoms, parse_goal_facts

    return {
        "atoms": extract_answer_atoms(solver_output),
        "goals": parse_goal_facts(instance_text),
    }
