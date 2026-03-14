#!/usr/bin/env python3
"""Render minimal grounded goal hypergraphs as interactive Plotly figures."""
from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import List, Mapping, Sequence, Tuple

import plotly.graph_objects as go

from graph_tools import (
    build_support_graph,
    compute_levels,
    extract_answer_atoms,
    extract_goal_file,
    layered_positions,
    parse_goal_file,
    parse_graph_log,
    run_graph_solver,
)


@dataclass
class GraphNode:
    node_id: str
    label: str
    kind: str
    source: bool
    goal: bool


class GoalHypergraphViewer:
    def __init__(
        self,
        nodes: Mapping[str, Mapping[str, object]],
        edges: Sequence[Tuple[str, str, str]],
        title: str,
    ):
        self.nodes = {node_id: dict(data) for node_id, data in nodes.items()}
        self.edges = list(edges)
        self.title = title
        self.levels = compute_levels(self.nodes, self.edges)
        self.positions = layered_positions(self.nodes, self.levels)

    @classmethod
    def from_goal_file(
        cls,
        goal_file: str | Path,
        root: str | Path = ".",
    ) -> "GoalHypergraphViewer":
        root_path = Path(root).resolve()
        goal_path = Path(goal_file)
        if not goal_path.is_absolute():
            goal_path = (root_path / goal_path).resolve()
        goal_arg = goal_path
        if goal_path.is_relative_to(root_path):
            goal_arg = goal_path.relative_to(root_path)
        output = run_graph_solver(goal_arg, root_path)
        atoms = extract_answer_atoms(output)
        target_items, target_buildings = parse_goal_file(goal_path)
        nodes, edges = build_support_graph(atoms, target_items, target_buildings)
        return cls(nodes, edges, title=f"Minimal grounded hypergraph: {goal_path.stem}")

    @classmethod
    def from_log(cls, log_path: str | Path) -> "GoalHypergraphViewer":
        log = Path(log_path).resolve()
        atoms, target_items, target_buildings = parse_graph_log(log)
        nodes, edges = build_support_graph(atoms, target_items, target_buildings)
        return cls(nodes, edges, title=f"Minimal grounded hypergraph: {log.stem}")

    @classmethod
    def from_instance(
        cls,
        instance_file: str | Path,
        root: str | Path = ".",
    ) -> "GoalHypergraphViewer":
        root_path = Path(root).resolve()
        instance_path = Path(instance_file)
        if not instance_path.is_absolute():
            instance_path = (root_path / instance_path).resolve()
        tmp_goal = extract_goal_file(instance_path)
        viewer = cls.from_goal_file(tmp_goal, root=root_path)
        viewer.title = f"Minimal grounded hypergraph: {instance_path.stem}"
        return viewer

    def _edge_trace(self, kind: str, color: str) -> go.Scatter:
        xs: List[float | None] = []
        ys: List[float | None] = []
        hover_x: List[float] = []
        hover_y: List[float] = []
        hover_text: List[str] = []

        for src, dst, edge_kind in self.edges:
            if edge_kind != kind:
                continue
            x1, y1 = self.positions[src]
            x2, y2 = self.positions[dst]
            xs.extend([x1, x2, None])
            ys.extend([y1, y2, None])
            hover_x.append((x1 + x2) / 2.0)
            hover_y.append((y1 + y2) / 2.0)
            hover_text.append(f"{self.nodes[src]['label']} -> {self.nodes[dst]['label']}<br>kind={kind}")

        line_trace = go.Scatter(
            x=xs,
            y=ys,
            mode="lines",
            line=dict(color=color, width=1.6),
            hoverinfo="skip",
            name=kind,
        )
        hover_trace = go.Scatter(
            x=hover_x,
            y=hover_y,
            mode="markers",
            marker=dict(size=8, color=color, opacity=0.0),
            hovertemplate="%{text}<extra></extra>",
            text=hover_text,
            showlegend=False,
        )
        return line_trace, hover_trace

    def _node_traces(self) -> list[go.Scatter]:
        groups = {
            "source_item": {"nodes": [], "color": "#d1d5db", "symbol": "circle"},
            "item": {"nodes": [], "color": "#93c5fd", "symbol": "circle"},
            "building": {"nodes": [], "color": "#86efac", "symbol": "square"},
            "craft": {"nodes": [], "color": "#fdba74", "symbol": "diamond"},
        }

        for node, data in self.nodes.items():
            if data["kind"] == "item" and data["source"]:
                groups["source_item"]["nodes"].append(node)
            elif data["kind"] == "item":
                groups["item"]["nodes"].append(node)
            elif data["kind"] == "building":
                groups["building"]["nodes"].append(node)
            else:
                groups["craft"]["nodes"].append(node)

        traces: list[go.Scatter] = []
        for name, cfg in groups.items():
            node_ids = cfg["nodes"]
            if not node_ids:
                continue
            traces.append(
                go.Scatter(
                    x=[self.positions[node][0] for node in node_ids],
                    y=[self.positions[node][1] for node in node_ids],
                    mode="markers+text",
                    text=[str(self.nodes[node]["label"]) for node in node_ids],
                    textposition="middle center",
                    hovertemplate="%{customdata}<extra></extra>",
                    customdata=[
                        f"{self.nodes[node]['label']}"
                        f"<br>type={self.nodes[node]['kind']}"
                        f"<br>source={self.nodes[node]['source']}"
                        f"<br>goal={self.nodes[node]['goal']}"
                        f"<br>level={self.levels[node]}"
                        for node in node_ids
                    ],
                    marker=dict(
                        size=28,
                        color=cfg["color"],
                        symbol=cfg["symbol"],
                        line=dict(color="#1f2937", width=1),
                    ),
                    name=name,
                )
            )

        goal_nodes = [node for node, data in self.nodes.items() if data["goal"]]
        if goal_nodes:
            traces.append(
                go.Scatter(
                    x=[self.positions[node][0] for node in goal_nodes],
                    y=[self.positions[node][1] for node in goal_nodes],
                    mode="markers",
                    marker=dict(size=38, color="rgba(0,0,0,0)", line=dict(color="#dc2626", width=3)),
                    hoverinfo="skip",
                    name="goal",
                )
            )
        return traces

    def figure(self, width: int = 1200, height: int | None = None) -> go.Figure:
        if height is None:
            height = max(700, 55 * len(self.nodes))

        req_line, req_hover = self._edge_trace("requires", "#6b7280")
        prod_line, prod_hover = self._edge_trace("produces", "#2563eb")

        fig = go.Figure([req_line, prod_line, req_hover, prod_hover] + self._node_traces())
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

    def show(self, width: int = 1200, height: int | None = None) -> go.Figure:
        fig = self.figure(width=width, height=height)
        fig.show()
        return fig
