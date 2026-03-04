#!/usr/bin/env python3
"""Parse clingcon Assignment output to NumPy and render selector-based 3D Plotly subplots."""
# WRITTEN BY CODEX! NOT OWN WORK.
from __future__ import annotations

import argparse
import itertools
import math
import re
from collections import defaultdict
from dataclasses import dataclass
from typing import Any, Dict, Iterable, List, Mapping, Sequence, Tuple

import numpy as np
import plotly.graph_objects as go
from plotly.subplots import make_subplots


SCHEMA: Dict[str, Tuple[str, ...]] = {
    # 2 args
    "cost_build": ("item", "time"),
    "cost_craft": ("item", "time"),
    "global_stock": ("item", "time"),
    "yield_craft": ("item", "time"),
    # 3 args
    "building_count": ("building", "zone", "time"),
    "slot_utilization": ("zone", "slot", "time"),
    "stock": ("item", "zone", "time"),
    # 4 args
    "global_available": ("item", "zone", "available_index", "time"),
    "global_space": ("item", "zone", "available_index", "time"),
    "input_from_global": ("item", "zone", "slot", "time"),
    "input_from_local": ("item", "zone", "slot", "time"),
    "local_available": ("item", "zone", "available_index", "time"),
    "local_space": ("item", "zone", "available_index", "time"),
    "output_to_global": ("item", "zone", "slot", "time"),
    "output_to_local": ("item", "zone", "slot", "time"),
}

INT_FIELDS = {"time", "zone", "slot", "available_index"}
SELECTOR_FIELDS = ("item", "building", "layout", "actions")
PREDICATE_PLOT_ORDER = (
    "global_stock",
    "cost_build",
    "cost_craft",
    "yield_craft",
    "stock",
    "local_available",
    "global_available",
    "local_space",
    "global_space",
    "input_from_local",
    "input_from_global",
    "output_to_local",
    "output_to_global",
    "slot_utilization",
    "building_count",
)
PREDICATE_PLOT_RANK = {name: i for i, name in enumerate(PREDICATE_PLOT_ORDER)}
ASSIGNMENT_TOKEN_RE = re.compile(r"([a-zA-Z_]\w*)\(([^()]*)\)=(-?\d+)")
ASSIGNMENT_END_PREFIXES = (
    "Cost:",
    "Optimization:",
    "SATISFIABLE",
    "UNSATISFIABLE",
    "Answer:",
)


def _semantic_predicate_sort(predicates: Sequence[str]) -> List[str]:
    return sorted(predicates, key=lambda p: (PREDICATE_PLOT_RANK.get(p, 10_000), p))


@dataclass
class PredicateTensor:
    name: str
    arg_names: Tuple[str, ...]
    values: np.ndarray
    coords: Dict[str, List[Any]]
    index: Dict[str, Dict[Any, int]]


@dataclass
class SurfaceData:
    predicate: str
    x_time: np.ndarray
    y_index: np.ndarray
    z_values: np.ndarray
    y_labels: List[str]
    other_names: Tuple[str, ...]
    y_keys: List[Tuple[Any, ...]]


@dataclass
class ActionInterval:
    kind: str
    name: str
    zone: int | None
    start: int
    end: int
    lane: str


class ClingconAssignmentViewer:
    def __init__(
        self,
        tensors: Mapping[str, PredicateTensor],
        slot_map: Mapping[Tuple[int, int], str] | None = None,
        actions: Sequence[ActionInterval] | None = None,
    ):
        self.tensors = dict(tensors)
        self.slot_map = dict(slot_map or {})
        self.actions = list(actions or [])

    @classmethod
    def from_log(cls, log_path: str) -> "ClingconAssignmentViewer":
        grouped = _parse_last_assignment_grouped(log_path)
        tensors = {
            pred: _build_tensor(pred, SCHEMA[pred], rows) for pred, rows in grouped.items()
        }
        slot_map = _parse_last_slot_map(log_path)
        actions = _parse_last_actions(log_path)
        return cls(tensors, slot_map=slot_map, actions=actions)

    def available_values(self, selector_field: str) -> List[Any]:
        if selector_field not in SELECTOR_FIELDS:
            raise ValueError(f"selector_field must be one of {list(SELECTOR_FIELDS)}")
        if selector_field in {"layout", "actions"}:
            return ["all"]
        values = set()
        for tensor in self.tensors.values():
            if selector_field in tensor.coords:
                values.update(tensor.coords[selector_field])
        return sorted(values)

    def relevant_predicates(self, selector_field: str) -> List[str]:
        if selector_field not in SELECTOR_FIELDS:
            raise ValueError(f"selector_field must be one of {list(SELECTOR_FIELDS)}")
        if selector_field == "layout":
            return ["layout_building_count"]
        if selector_field == "actions":
            return ["actions_timeline"]
        return _semantic_predicate_sort(
            pred
            for pred, tensor in self.tensors.items()
            if selector_field in tensor.arg_names and "time" in tensor.arg_names
        )

    def _layout_surface(self) -> SurfaceData:
        bc = self.tensors.get("building_count")
        if bc is None:
            raise ValueError("building_count tensor is not available")
        times = np.asarray(bc.coords["time"], dtype=np.int32)
        time_index = bc.index["time"]
        zone_index = bc.index["zone"]
        building_index = bc.index["building"]

        slot_entries = sorted(self.slot_map.items(), key=lambda kv: (kv[0][0], kv[0][1]))
        if not slot_entries:
            raise ValueError("slot_map is empty; cannot build layout view")

        y_labels = [f"z{z}s{s}" for (z, s), _ in slot_entries]
        y_keys = [(int(z), int(s)) for (z, s), _ in slot_entries]
        z_values = np.zeros((len(slot_entries), len(times)), dtype=np.float64)

        for yi, ((z, _s), bld) in enumerate(slot_entries):
            z_i = zone_index.get(int(z))
            b_i = building_index.get(bld)
            if z_i is None or b_i is None:
                continue
            z_values[yi, :] = bc.values[b_i, z_i, :].astype(np.float64)

        return SurfaceData(
            predicate="layout_building_count",
            x_time=times,
            y_index=np.arange(len(slot_entries), dtype=np.int32),
            z_values=z_values,
            y_labels=y_labels,
            other_names=("zone", "slot"),
            y_keys=[tuple(k) for k in y_keys],
        )

    def _surfaces_for_selector(
        self,
        selector_field: str,
        selector_value: Any,
        predicates: Sequence[str] | None = None,
    ) -> List[SurfaceData]:
        if selector_field == "layout":
            return [self._layout_surface()]
        if selector_field == "actions":
            return []
        if predicates is None:
            predicates = self.relevant_predicates(selector_field)
        else:
            unknown = [p for p in predicates if p not in self.tensors]
            if unknown:
                raise KeyError(f"Unknown predicates: {unknown}")
            predicates = [p for p in predicates if selector_field in self.tensors[p].arg_names]
        return [self.surface_for(pred, selector_field, selector_value) for pred in predicates]

    def _plot_actions_timeline(
        self, full_width: bool = False, figure_width: int | None = None
    ) -> go.Figure:
        fig = go.Figure()
        if not self.actions:
            fig.update_layout(
                title="Actions Timeline (no actions parsed)",
                xaxis={"title": "time", "rangemode": "tozero"},
                yaxis={"title": "action lane"},
                height=420,
                width=(None if full_width else (figure_width or 1250)),
                autosize=full_width,
            )
            return fig

        lanes = sorted({a.lane for a in self.actions})
        by_kind: Dict[str, List[ActionInterval]] = {"craft": [], "build": []}
        for action in self.actions:
            by_kind.setdefault(action.kind, []).append(action)

        colors = {"craft": "#1f77b4", "build": "#ff7f0e"}
        for kind in ("craft", "build"):
            group = by_kind.get(kind, [])
            if not group:
                continue
            x_width = []
            x_base = []
            y_lane = []
            hover = []
            for a in group:
                width = max(0.12, float(a.end - a.start))
                x_width.append(width)
                x_base.append(float(a.start))
                y_lane.append(a.lane)
                hover.append(
                    f"{a.lane}<br>kind={a.kind}<br>start={a.start} end={a.end}"
                    f"<br>duration={a.end - a.start}"
                )
            fig.add_trace(
                go.Bar(
                    name=kind,
                    orientation="h",
                    x=x_width,
                    base=x_base,
                    y=y_lane,
                    marker={"color": colors.get(kind, "#666666")},
                    text=hover,
                    hovertemplate="%{text}<extra></extra>",
                )
            )

        fig.update_layout(
            title="Actions Timeline",
            barmode="overlay",
            xaxis={"title": "time", "rangemode": "tozero"},
            yaxis={
                "title": "zXsY:action",
                "categoryorder": "array",
                "categoryarray": lanes[::-1],
            },
            legend={"title": {"text": "kind"}},
            height=max(420, 28 * len(lanes) + 220),
            width=(None if full_width else (figure_width or 1250)),
            autosize=full_width,
            margin={"l": 40, "r": 20, "t": 70, "b": 30},
        )
        return fig

    def surface_for(self, predicate: str, selector_field: str, selector_value: Any) -> SurfaceData:
        if predicate not in self.tensors:
            raise KeyError(f"Unknown predicate: {predicate}")
        tensor = self.tensors[predicate]
        if selector_field not in tensor.arg_names:
            raise ValueError(f"{predicate} has no '{selector_field}' argument")

        axis_sel = tensor.arg_names.index(selector_field)
        selector_value = _cast_selector_value(selector_value, tensor.coords[selector_field])
        if selector_value not in tensor.index[selector_field]:
            available = ", ".join(map(str, tensor.coords[selector_field][:20]))
            raise KeyError(
                f"Value '{selector_value}' not present for {selector_field} in {predicate}. "
                f"Sample available: {available}"
            )

        selected_idx = tensor.index[selector_field][selector_value]
        sliced = np.take(tensor.values, selected_idx, axis=axis_sel)

        remaining_names = [n for n in tensor.arg_names if n != selector_field]
        if "time" not in remaining_names:
            raise ValueError(f"{predicate} has no time axis after selection")

        t_axis = remaining_names.index("time")
        x_time = np.asarray(tensor.coords["time"], dtype=np.int32)

        other_names = [n for n in remaining_names if n != "time"]
        if len(remaining_names) == 1:
            z_values = np.asarray(sliced, dtype=np.float64).reshape(1, -1)
            y_labels = ["all"]
            y_keys = [tuple()]
        else:
            moved = np.moveaxis(sliced, t_axis, -1)
            y_shape = moved.shape[:-1]
            z_values = moved.reshape(int(np.prod(y_shape)), moved.shape[-1]).astype(np.float64)
            y_labels = _build_y_labels(other_names, tensor.coords)
            y_keys = _build_y_keys(other_names, tensor.coords)

        y_index = np.arange(z_values.shape[0], dtype=np.int32)
        return SurfaceData(
            predicate=predicate,
            x_time=x_time,
            y_index=y_index,
            z_values=z_values,
            y_labels=y_labels,
            other_names=tuple(other_names),
            y_keys=y_keys,
        )

    def _value_at(self, predicate: str, by_arg: Mapping[str, Any]) -> int | None:
        tensor = self.tensors.get(predicate)
        if tensor is None:
            return None
        idx = []
        for arg_name in tensor.arg_names:
            if arg_name not in by_arg:
                return None
            val = by_arg[arg_name]
            if val not in tensor.index[arg_name]:
                return None
            idx.append(tensor.index[arg_name][val])
        return int(tensor.values[tuple(idx)])

    def _build_hover_text(
        self, surface: SurfaceData, y_idx: int, time_val: int, amount_val: float
    ) -> str:
        y_label = surface.y_labels[y_idx]
        key = surface.y_keys[y_idx]
        names = surface.other_names
        if names == ("zone", "slot"):
            zone, slot = int(key[0]), int(key[1])
            building = self.slot_map.get((zone, slot), "none")
            if surface.predicate == "layout_building_count":
                return (
                    f"{y_label}:{building}<br>pred={surface.predicate}"
                    f"<br>t={int(time_val)} count={float(amount_val):g}"
                )
            util = self._value_at(
                "slot_utilization", {"zone": zone, "slot": slot, "time": int(time_val)}
            )
            if building != "none":
                count = self._value_at(
                    "building_count",
                    {"building": building, "zone": zone, "time": int(time_val)},
                )
            else:
                count = None
            util_txt = "na" if util is None else str(util)
            count_txt = "na" if count is None else str(count)
            chain_label = f"{y_label}:{building}:{util_txt}/{count_txt}"
            return (
                f"{chain_label}<br>pred={surface.predicate}"
                f"<br>t={int(time_val)} value={float(amount_val):g}"
            )

        return (
            f"{y_label}<br>pred={surface.predicate}"
            f"<br>t={int(time_val)} value={float(amount_val):g}"
        )

    def plot_selector(
        self,
        selector_field: str,
        selector_value: Any,
        predicates: Sequence[str] | None = None,
        cols: int = 2,
        slice_mode: str = "none",
        slice_index: int = 0,
        show_zeros_3d: bool = False,
        full_width: bool = False,
        figure_width: int | None = None,
    ) -> go.Figure:
        if selector_field not in SELECTOR_FIELDS:
            raise ValueError(f"selector_field must be one of {list(SELECTOR_FIELDS)}")
        if cols < 1:
            raise ValueError("cols must be >= 1")
        if slice_mode not in {"none", "fix_x", "fix_y"}:
            raise ValueError("slice_mode must be one of: none, fix_x, fix_y")
        if selector_field == "actions":
            return self._plot_actions_timeline(full_width=full_width, figure_width=figure_width)

        surfaces = self._surfaces_for_selector(selector_field, selector_value, predicates=predicates)
        if not surfaces:
            raise ValueError(f"No predicates found for selector_field={selector_field}")

        rows = math.ceil(len(surfaces) / cols)
        specs: List[List[Dict[str, str]]] = []
        for r in range(rows):
            row_specs: List[Dict[str, str]] = []
            for c in range(cols):
                i = r * cols + c
                if i >= len(surfaces):
                    row_specs.append({"type": "xy"})
                else:
                    surface = surfaces[i]
                    # Single-chain series is clearer as 2D (time -> amount).
                    if surface.z_values.shape[0] == 1:
                        row_specs.append({"type": "xy"})
                    elif slice_mode == "none":
                        row_specs.append({"type": "scene"})
                    else:
                        row_specs.append({"type": "xy"})
            specs.append(row_specs)

        fig = make_subplots(
            rows=rows,
            cols=cols,
            specs=specs,
            subplot_titles=[s.predicate for s in surfaces],
            horizontal_spacing=0.03,
            vertical_spacing=0.06,
        )
        scene_by_cell: Dict[Tuple[int, int], str] = {}
        scene_count = 0
        for r in range(rows):
            for c in range(cols):
                cell = specs[r][c]
                if cell.get("type") == "scene":
                    scene_count += 1
                    scene_by_cell[(r + 1, c + 1)] = "scene" if scene_count == 1 else f"scene{scene_count}"

        for i, surface in enumerate(surfaces):
            row = i // cols + 1
            col = i % cols + 1
            is_2d = surface.z_values.shape[0] == 1

            if is_2d or slice_mode != "none":
                x_vals: np.ndarray
                y_vals: np.ndarray
                text: List[str]

                if is_2d:
                    x_vals = surface.x_time
                    y_vals = surface.z_values[0]
                    text = [
                        f"pred={surface.predicate}<br>t={int(t)} value={float(v):g}"
                        for t, v in zip(x_vals, y_vals)
                    ]
                    fig.update_xaxes(title_text="time", rangemode="tozero", row=row, col=col)
                elif slice_mode == "fix_x":
                    x_idx = min(max(int(slice_index), 0), len(surface.x_time) - 1)
                    time_val = int(surface.x_time[x_idx])
                    x_vals = surface.y_index
                    y_vals = surface.z_values[:, x_idx]
                    text = [
                        self._build_hover_text(surface, int(y_i), time_val, float(val))
                        for y_i, val in zip(x_vals, y_vals)
                    ]
                    tickvals, ticktext = _sparse_ticks(surface.y_labels)
                    fig.update_xaxes(
                        title_text=f"chain @ t={time_val}",
                        rangemode="tozero",
                        tickmode="array",
                        tickvals=tickvals,
                        ticktext=ticktext,
                        row=row,
                        col=col,
                    )
                else:  # fix_y
                    y_idx = min(max(int(slice_index), 0), len(surface.y_index) - 1)
                    x_vals = surface.x_time
                    y_vals = surface.z_values[y_idx, :]
                    text = [
                        self._build_hover_text(surface, y_idx, int(t), float(val))
                        for t, val in zip(x_vals, y_vals)
                    ]
                    fig.update_xaxes(
                        title_text=f"time @ {surface.y_labels[y_idx]}",
                        rangemode="tozero",
                        row=row,
                        col=col,
                    )

                fig.add_trace(
                    go.Scatter(
                        x=x_vals,
                        y=y_vals,
                        mode="lines+markers",
                        name=surface.predicate,
                        text=text,
                        hovertemplate="%{text}<extra></extra>",
                    ),
                    row=row,
                    col=col,
                )
                fig.update_yaxes(title_text="amount", rangemode="tozero", row=row, col=col)
                continue

            x_grid = np.tile(surface.x_time, len(surface.y_index))
            y_grid = np.repeat(surface.y_index, len(surface.x_time))
            z_grid = surface.z_values.reshape(-1)
            if show_zeros_3d:
                x_plot = x_grid
                y_plot = y_grid
                z_plot = z_grid
            else:
                nonzero = z_grid != 0
                if np.any(nonzero):
                    x_plot = x_grid[nonzero]
                    y_plot = y_grid[nonzero]
                    z_plot = z_grid[nonzero]
                else:
                    x_plot = x_grid
                    y_plot = y_grid
                    z_plot = z_grid

            marker = {
                "size": 3,
                "color": z_plot,
                "colorscale": "Viridis",
                "showscale": i == 0,
                "opacity": 0.85,
            }
            if i == 0:
                marker["colorbar"] = {"title": "amount"}

            hover_text = [
                self._build_hover_text(surface, int(y), int(x), float(z))
                for x, y, z in zip(x_plot, y_plot, z_plot)
            ]

            scene_name = scene_by_cell[(row, col)]
            fig.add_trace(
                go.Scatter3d(
                    x=x_plot,
                    y=y_plot,
                    z=z_plot,
                    mode="markers",
                    marker=marker,
                    name=surface.predicate,
                    text=hover_text,
                    hovertemplate="%{text}<extra></extra>",
                    scene=scene_name,
                ),
                row=row,
                col=col,
            )
            tickvals, ticktext = _sparse_ticks(surface.y_labels)
            fig.update_layout(
                {
                    scene_name: {
                        "xaxis": {"title": "time", "rangemode": "tozero"},
                        "yaxis": {
                            "title": "chain (zone/slot)",
                            "rangemode": "tozero",
                            "tickmode": "array",
                            "tickvals": tickvals,
                            "ticktext": ticktext,
                        },
                        "zaxis": {"title": "amount", "rangemode": "tozero"},
                        "aspectmode": "cube",
                    }
                }
            )

        fig.update_layout(
            title=(
                f"Selector: {selector_field}={selector_value if selector_field != 'layout' else 'all'}"
                if slice_mode == "none"
                else (
                    f"Selector: {selector_field}={selector_value if selector_field != 'layout' else 'all'} "
                    f"({slice_mode}, idx={slice_index})"
                )
            ),
            height=max(450, 430 * rows),
            width=(None if full_width else (figure_width or 1250)),
            autosize=full_width,
            margin={"l": 20, "r": 20, "t": 80, "b": 20},
        )
        return fig

    def interactive_selector_widget(
        self,
        selector_field: str,
        selector_value: Any,
        predicates: Sequence[str] | None = None,
        cols: int = 2,
        show_zeros_3d: bool = False,
        full_width: bool = True,
    ):
        """Notebook widget: fix-x/fix-y checkboxes + slider, else default 3D view."""
        try:
            import ipywidgets as widgets
            from IPython.display import display
        except ImportError as exc:
            raise ImportError("interactive_selector_widget requires ipywidgets in the notebook environment") from exc

        if selector_field not in SELECTOR_FIELDS:
            raise ValueError(f"selector_field must be one of {list(SELECTOR_FIELDS)}")
        surfaces = self._surfaces_for_selector(selector_field, selector_value, predicates=predicates)
        if selector_field != "actions" and not surfaces:
            raise ValueError(f"No predicates found for selector_field={selector_field}")

        fix_x = widgets.Checkbox(value=False, description="fix time")
        fix_y = widgets.Checkbox(value=False, description="fix chain")
        show_zeros = widgets.Checkbox(value=show_zeros_3d, description="show zeros")
        slider = widgets.IntSlider(
            value=0, min=0, max=0, step=1, description="idx", continuous_update=False, disabled=True
        )
        out = widgets.Output()
        busy = {"value": False}

        def mode() -> str:
            if fix_x.value:
                return "fix_x"
            if fix_y.value:
                return "fix_y"
            return "none"

        def max_idx_for(mode_name: str) -> int:
            multi = [s for s in surfaces if s.z_values.shape[0] > 1]
            if not multi:
                return 0
            if mode_name == "fix_x":
                return max(len(s.x_time) - 1 for s in multi)
            if mode_name == "fix_y":
                return max(len(s.y_index) - 1 for s in multi)
            return 0

        def sync_controls() -> None:
            if selector_field == "actions":
                fix_x.disabled = True
                fix_y.disabled = True
                fix_x.value = False
                fix_y.value = False
                show_zeros.disabled = True
                slider.disabled = True
                slider.description = "idx"
                slider.max = 0
                slider.value = 0
                return
            fix_x.disabled = False
            fix_y.disabled = False
            show_zeros.disabled = False
            m = mode()
            if m == "none":
                slider.disabled = True
                slider.description = "idx"
                slider.max = 0
                slider.value = 0
            elif m == "fix_x":
                slider.disabled = False
                slider.description = "time idx"
                slider.max = max_idx_for(m)
                slider.value = min(slider.value, slider.max)
            else:
                slider.disabled = False
                slider.description = "chain idx"
                slider.max = max_idx_for(m)
                slider.value = min(slider.value, slider.max)

        def render() -> None:
            m = mode()
            with out:
                out.clear_output(wait=True)
                try:
                    fig = self.plot_selector(
                        selector_field=selector_field,
                        selector_value=selector_value,
                        predicates=predicates,
                        cols=cols,
                        slice_mode=m,
                        slice_index=slider.value,
                        show_zeros_3d=show_zeros.value,
                        full_width=full_width,
                    )
                    display(fig)
                except Exception as exc:
                    print(f"render error: {type(exc).__name__}: {exc}")

        def on_fix_x(change):
            if change["name"] != "value" or busy["value"]:
                return
            if change["new"]:
                busy["value"] = True
                fix_y.value = False
                busy["value"] = False
            sync_controls()
            render()

        def on_fix_y(change):
            if change["name"] != "value" or busy["value"]:
                return
            if change["new"]:
                busy["value"] = True
                fix_x.value = False
                busy["value"] = False
            sync_controls()
            render()

        def on_slider(change):
            if change["name"] == "value":
                render()

        def on_show_zeros(change):
            if change["name"] == "value":
                render()

        fix_x.observe(on_fix_x, names="value")
        fix_y.observe(on_fix_y, names="value")
        slider.observe(on_slider, names="value")
        show_zeros.observe(on_show_zeros, names="value")

        sync_controls()
        render()
        controls = widgets.HBox([fix_x, fix_y, show_zeros, slider], layout=widgets.Layout(width="100%"))
        out.layout = widgets.Layout(width="100%")
        return widgets.VBox([controls, out], layout=widgets.Layout(width="100%"))

    def interactive_explorer_widget(
        self,
        predicates: Sequence[str] | None = None,
        cols: int = 2,
        default_selector_field: str = "item",
        default_selector_value: Any | None = None,
        show_zeros_3d: bool = False,
        full_width: bool = True,
    ):
        """Notebook widget with selector dropdowns + fix-x/fix-y + slider."""
        try:
            import ipywidgets as widgets
            from IPython.display import display
        except ImportError as exc:
            raise ImportError("interactive_explorer_widget requires ipywidgets in the notebook environment") from exc

        if default_selector_field not in SELECTOR_FIELDS:
            raise ValueError(f"default_selector_field must be one of {list(SELECTOR_FIELDS)}")

        fixed_predicates: List[str] | None = None
        if predicates is not None:
            unknown = [p for p in predicates if p not in self.tensors]
            if unknown:
                raise KeyError(f"Unknown predicates: {unknown}")
            fixed_predicates = list(predicates)

        available_by_field: Dict[str, List[Any]] = {
            field: self.available_values(field) for field in SELECTOR_FIELDS
        }
        selectable_fields = [f for f, values in available_by_field.items() if values]
        if not selectable_fields:
            raise ValueError("No selectable fields have values in current tensors")

        field_value = (
            default_selector_field if default_selector_field in selectable_fields else selectable_fields[0]
        )
        field_dd = widgets.Dropdown(
            options=selectable_fields,
            value=field_value,
            description="type",
            layout=widgets.Layout(width="170px"),
        )

        value_dd = widgets.Dropdown(
            options=[],
            description="value",
            layout=widgets.Layout(width="300px"),
        )
        fix_x = widgets.Checkbox(value=False, description="fix time")
        fix_y = widgets.Checkbox(value=False, description="fix chain")
        show_zeros = widgets.Checkbox(value=show_zeros_3d, description="show zeros")
        slider = widgets.IntSlider(
            value=0,
            min=0,
            max=0,
            step=1,
            description="idx",
            continuous_update=False,
            disabled=True,
            layout=widgets.Layout(width="320px"),
        )
        out = widgets.Output()
        busy = {"value": False}

        def mode() -> str:
            if fix_x.value:
                return "fix_x"
            if fix_y.value:
                return "fix_y"
            return "none"

        def current_predicates(field: str) -> List[str]:
            if field == "layout":
                return ["layout_building_count"]
            if field == "actions":
                return ["actions_timeline"]
            if fixed_predicates is None:
                return self.relevant_predicates(field)
            return [p for p in fixed_predicates if field in self.tensors[p].arg_names]

        def current_surfaces() -> List[SurfaceData]:
            field = field_dd.value
            value = value_dd.value
            if value is None:
                return []
            if field == "actions":
                return []
            preds = current_predicates(field)
            return self._surfaces_for_selector(field, value, predicates=preds)

        def refresh_values(preferred: Any | None = None) -> None:
            values = available_by_field[field_dd.value]
            value_dd.options = values
            value_dd.disabled = field_dd.value in {"layout", "actions"}
            if not values:
                value_dd.value = None
                return
            if preferred is not None and preferred in values:
                value_dd.value = preferred
                return
            value_dd.value = values[0]

        def max_idx_for(mode_name: str) -> int:
            surfaces = current_surfaces()
            multi = [s for s in surfaces if s.z_values.shape[0] > 1]
            if not multi:
                return 0
            if mode_name == "fix_x":
                return max(len(s.x_time) - 1 for s in multi)
            if mode_name == "fix_y":
                return max(len(s.y_index) - 1 for s in multi)
            return 0

        def sync_controls() -> None:
            if field_dd.value == "actions":
                fix_x.disabled = True
                fix_y.disabled = True
                fix_x.value = False
                fix_y.value = False
                show_zeros.disabled = True
                slider.disabled = True
                slider.description = "idx"
                slider.max = 0
                slider.value = 0
                return
            fix_x.disabled = False
            fix_y.disabled = False
            show_zeros.disabled = False
            m = mode()
            if m == "none":
                slider.disabled = True
                slider.description = "idx"
                slider.max = 0
                slider.value = 0
                return
            slider.disabled = False
            if m == "fix_x":
                slider.description = "time idx"
            else:
                slider.description = "chain idx"
            slider.max = max_idx_for(m)
            slider.value = min(slider.value, slider.max)

        def render() -> None:
            field = field_dd.value
            value = value_dd.value
            m = mode()
            with out:
                out.clear_output(wait=True)
                if value is None:
                    print("No selectable value for this field.")
                    return
                try:
                    fig = self.plot_selector(
                        selector_field=field,
                        selector_value=value,
                        predicates=current_predicates(field),
                        cols=cols,
                        slice_mode=m,
                        slice_index=slider.value,
                        show_zeros_3d=show_zeros.value,
                        full_width=full_width,
                    )
                    display(fig)
                except Exception as exc:
                    print(f"render error: {type(exc).__name__}: {exc}")

        def on_field(change):
            if change["name"] != "value" or busy["value"]:
                return
            busy["value"] = True
            preferred = (
                default_selector_value
                if change["new"] == default_selector_field and default_selector_value is not None
                else None
            )
            refresh_values(preferred=preferred)
            busy["value"] = False
            sync_controls()
            render()

        def on_value(change):
            if change["name"] != "value" or busy["value"]:
                return
            sync_controls()
            render()

        def on_fix_x(change):
            if change["name"] != "value" or busy["value"]:
                return
            if change["new"]:
                busy["value"] = True
                fix_y.value = False
                busy["value"] = False
            sync_controls()
            render()

        def on_fix_y(change):
            if change["name"] != "value" or busy["value"]:
                return
            if change["new"]:
                busy["value"] = True
                fix_x.value = False
                busy["value"] = False
            sync_controls()
            render()

        def on_slider(change):
            if change["name"] == "value":
                render()

        def on_show_zeros(change):
            if change["name"] == "value":
                render()

        field_dd.observe(on_field, names="value")
        value_dd.observe(on_value, names="value")
        fix_x.observe(on_fix_x, names="value")
        fix_y.observe(on_fix_y, names="value")
        slider.observe(on_slider, names="value")
        show_zeros.observe(on_show_zeros, names="value")

        refresh_values(
            preferred=default_selector_value if field_value == default_selector_field else None
        )
        sync_controls()
        render()
        controls = widgets.HBox(
            [field_dd, value_dd, fix_x, fix_y, show_zeros, slider],
            layout=widgets.Layout(width="100%"),
        )
        out.layout = widgets.Layout(width="100%")
        return widgets.VBox([controls, out], layout=widgets.Layout(width="100%"))


def _cast_value(field: str, value: str) -> Any:
    if field in INT_FIELDS:
        return int(value)
    return value


def _cast_selector_value(selector_value: Any, domain_values: Sequence[Any]) -> Any:
    if not domain_values:
        return selector_value
    first = domain_values[0]
    if isinstance(first, int) and isinstance(selector_value, str):
        try:
            return int(selector_value)
        except ValueError:
            return selector_value
    return selector_value


def _build_y_labels(other_names: Sequence[str], coords: Mapping[str, Sequence[Any]]) -> List[str]:
    domains = [coords[name] for name in other_names]
    labels = []
    for combo in itertools.product(*domains):
        combo_map = {name: value for name, value in zip(other_names, combo)}
        if "zone" in combo_map and "slot" in combo_map and len(other_names) == 2:
            labels.append(f"z{combo_map['zone']}s{combo_map['slot']}")
        elif "zone" in combo_map and "available_index" in combo_map and len(other_names) == 2:
            labels.append(f"z{combo_map['zone']}i{combo_map['available_index']}")
        elif "zone" in combo_map and len(other_names) == 1:
            labels.append(f"z{combo_map['zone']}")
        elif "slot" in combo_map and len(other_names) == 1:
            labels.append(f"s{combo_map['slot']}")
        elif "available_index" in combo_map and len(other_names) == 1:
            labels.append(f"i{combo_map['available_index']}")
        else:
            parts = [f"{name}={value}" for name, value in zip(other_names, combo)]
            labels.append(", ".join(parts))
    return labels


def _build_y_keys(other_names: Sequence[str], coords: Mapping[str, Sequence[Any]]) -> List[Tuple[Any, ...]]:
    if not other_names:
        return [tuple()]
    domains = [coords[name] for name in other_names]
    return list(itertools.product(*domains))


def _sparse_ticks(labels: Sequence[str], max_ticks: int = 14) -> Tuple[List[int], List[str]]:
    if not labels:
        return [0], [""]
    if len(labels) <= max_ticks:
        return list(range(len(labels))), list(labels)
    step = math.ceil(len(labels) / max_ticks)
    idx = list(range(0, len(labels), step))
    if idx[-1] != len(labels) - 1:
        idx.append(len(labels) - 1)
    return idx, [labels[i] for i in idx]


def _parse_last_assignment_grouped(log_path: str) -> Dict[str, List[Tuple[Tuple[Any, ...], int]]]:
    grouped: Dict[str, List[Tuple[Tuple[Any, ...], int]]] = defaultdict(list)
    current: Dict[str, List[Tuple[Tuple[Any, ...], int]]] = defaultdict(list)
    in_assignment = False

    with open(log_path, "r", encoding="utf-8", errors="ignore") as handle:
        for line in handle:
            if line.startswith("Assignment:"):
                in_assignment = True
                current = defaultdict(list)
                continue

            if in_assignment and line.startswith(ASSIGNMENT_END_PREFIXES):
                in_assignment = False
                grouped = current
                continue

            if not in_assignment:
                continue

            for tok in line.split():
                match = ASSIGNMENT_TOKEN_RE.fullmatch(tok)
                if not match:
                    continue
                pred, args_raw, value_raw = match.groups()
                if pred not in SCHEMA:
                    continue
                fields = SCHEMA[pred]
                args = tuple(a.strip() for a in args_raw.split(",")) if args_raw else tuple()
                if len(args) != len(fields):
                    raise ValueError(
                        f"{pred} expected {len(fields)} args, got {len(args)} in token {tok}"
                    )
                typed_args = tuple(_cast_value(field, arg) for field, arg in zip(fields, args))
                grouped_val = int(value_raw)
                current[pred].append((typed_args, grouped_val))

    if in_assignment:
        grouped = current
    if not grouped:
        raise ValueError(f"No Assignment block parsed from {log_path}")
    return grouped


def _parse_last_answer_tokens(log_path: str) -> List[str]:
    in_answer = False
    current: List[str] = []
    last: List[str] = []
    stop_prefixes = ("Assignment:", "Cost:", "Optimization:", "SATISFIABLE", "UNSATISFIABLE")

    with open(log_path, "r", encoding="utf-8", errors="ignore") as handle:
        for line in handle:
            if line.startswith("Answer:"):
                in_answer = True
                current = []
                tail = line[len("Answer:") :].strip()
                if tail:
                    current.extend(tail.split())
                continue
            if in_answer and line.startswith(stop_prefixes):
                in_answer = False
                if current:
                    last = current
                continue
            if in_answer:
                current.extend(line.split())
    if in_answer and current:
        last = current
    return last


def _parse_last_slot_map(log_path: str) -> Dict[Tuple[int, int], str]:
    slot_re = re.compile(r"slot_map\((\d+),(\d+),([^)]+)\)")
    slot_map: Dict[Tuple[int, int], str] = {}
    for tok in _parse_last_answer_tokens(log_path):
        m = slot_re.fullmatch(tok)
        if not m:
            continue
        z_raw, s_raw, bld = m.groups()
        slot_map[(int(z_raw), int(s_raw))] = bld
    return slot_map


def _pair_intervals(starts: Sequence[int], finishes: Sequence[int]) -> List[Tuple[int, int]]:
    s_sorted = sorted(starts)
    f_sorted = sorted(finishes)
    pairs: List[Tuple[int, int]] = []
    j = 0
    for s in s_sorted:
        while j < len(f_sorted) and f_sorted[j] < s:
            j += 1
        if j < len(f_sorted):
            e = f_sorted[j]
            j += 1
        else:
            e = s
        pairs.append((s, e))
    return pairs


def _parse_last_actions(log_path: str) -> List[ActionInterval]:
    act_craft_re = re.compile(r"act\(craft\(([^)]+)\),(\d+)\)")
    fin_craft_re = re.compile(r"finish\(craft\(([^)]+)\),(\d+)\)")
    act_build_re = re.compile(r"act\(build\(([^,]+),(\d+)\),(\d+)\)")
    fin_build_re = re.compile(r"finish\(build\(([^,]+),(\d+)\),(\d+)\)")

    craft_starts: Dict[str, List[int]] = defaultdict(list)
    craft_finishes: Dict[str, List[int]] = defaultdict(list)
    build_starts: Dict[Tuple[str, int], List[int]] = defaultdict(list)
    build_finishes: Dict[Tuple[str, int], List[int]] = defaultdict(list)

    for tok in _parse_last_answer_tokens(log_path):
        m = act_craft_re.fullmatch(tok)
        if m:
            name, t = m.groups()
            craft_starts[name].append(int(t))
            continue
        m = fin_craft_re.fullmatch(tok)
        if m:
            name, t = m.groups()
            craft_finishes[name].append(int(t))
            continue
        m = act_build_re.fullmatch(tok)
        if m:
            bld, z, t = m.groups()
            build_starts[(bld, int(z))].append(int(t))
            continue
        m = fin_build_re.fullmatch(tok)
        if m:
            bld, z, t = m.groups()
            build_finishes[(bld, int(z))].append(int(t))
            continue

    out: List[ActionInterval] = []
    for name, starts in craft_starts.items():
        pairs = _pair_intervals(starts, craft_finishes.get(name, []))
        for s, e in pairs:
            out.append(
                ActionInterval(
                    kind="craft",
                    name=name,
                    zone=None,
                    start=int(s),
                    end=int(e),
                    lane=f"craft:{name}",
                )
            )

    for (bld, zone), starts in build_starts.items():
        pairs = _pair_intervals(starts, build_finishes.get((bld, zone), []))
        for s, e in pairs:
            out.append(
                ActionInterval(
                    kind="build",
                    name=bld,
                    zone=int(zone),
                    start=int(s),
                    end=int(e),
                    lane=f"z{zone}:{bld}",
                )
            )

    out.sort(key=lambda a: (a.kind, a.lane, a.start, a.end))
    return out


def _build_tensor(
    pred: str, arg_names: Sequence[str], rows: Iterable[Tuple[Tuple[Any, ...], int]]
) -> PredicateTensor:
    rows = list(rows)
    if not rows:
        raise ValueError(f"Predicate {pred} has no rows")

    coords: Dict[str, List[Any]] = {}
    index: Dict[str, Dict[Any, int]] = {}
    for dim, arg_name in enumerate(arg_names):
        values = sorted({args[dim] for args, _ in rows})
        coords[arg_name] = values
        index[arg_name] = {v: i for i, v in enumerate(values)}

    shape = tuple(len(coords[n]) for n in arg_names)
    arr = np.zeros(shape, dtype=np.int32)
    for args, val in rows:
        idx = tuple(index[arg_name][arg] for arg_name, arg in zip(arg_names, args))
        arr[idx] = val

    return PredicateTensor(
        name=pred,
        arg_names=tuple(arg_names),
        values=arr,
        coords=coords,
        index=index,
    )


def _build_arg_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Render selector-based 3D Plotly surfaces from clingcon Assignment logs."
    )
    parser.add_argument("log_path", help="Path to clingcon output log file")
    parser.add_argument(
        "--selector-field",
        choices=list(SELECTOR_FIELDS),
        required=True,
        help="Selector type to filter by",
    )
    parser.add_argument(
        "--selector-value",
        help="Selector value, e.g. iron. Not required with --list-values or selector-field layout/actions.",
    )
    parser.add_argument(
        "--predicates",
        nargs="*",
        help="Optional explicit predicate list. Defaults to all relevant predicates.",
    )
    parser.add_argument(
        "--cols",
        type=int,
        default=2,
        help="Number of subplot columns",
    )
    parser.add_argument(
        "--out-html",
        default="clingcon_selector_view.html",
        help="Output HTML path",
    )
    parser.add_argument(
        "--list-values",
        action="store_true",
        help="List valid values for --selector-field and exit.",
    )
    parser.add_argument(
        "--show-zeros",
        action="store_true",
        help="Show zero-value points in 3D plots.",
    )
    parser.add_argument(
        "--full-width",
        action="store_true",
        help="Use responsive full-width layout instead of fixed pixel width.",
    )
    return parser


def main() -> None:
    parser = _build_arg_parser()
    args = parser.parse_args()

    viewer = ClingconAssignmentViewer.from_log(args.log_path)
    if args.list_values:
        values = viewer.available_values(args.selector_field)
        print(f"Available {args.selector_field} values ({len(values)}):")
        for v in values:
            print(v)
        return

    if args.selector_field not in {"layout", "actions"} and args.selector_value is None:
        parser.error("--selector-value is required unless --list-values is set")

    fig = viewer.plot_selector(
        selector_field=args.selector_field,
        selector_value=args.selector_value if args.selector_value is not None else "all",
        predicates=args.predicates,
        cols=args.cols,
        show_zeros_3d=args.show_zeros,
        full_width=args.full_width,
    )
    fig.write_html(args.out_html, include_plotlyjs="cdn")
    print(f"Wrote: {args.out_html}")
    print(f"Relevant predicates: {viewer.relevant_predicates(args.selector_field)}")


if __name__ == "__main__":
    main()
