# Project Progress — Campus Building Placement

## Overview
Campus-block building placement system for Project Alma Mater (Godot 4). Supports drag-to-select and pick-individual-tile placement, right-click removal, bulldozer mode, camera/speed controls, building rename dialog with persistent labels, per-floor tracking, and corner-to-corner grid snapping.

---

## Scene Node Trees

### GameMap.tscn (and programmatic children)
```
GameMap (Node2D) — game_map.gd
├── FieldLayer (TileMapLayer)           — tile_set=blueprint tiles (64×64 grid)
├── RoadLayer (TileMapLayer)            — tile_set=road tiles (y=64, y=65)
├── BlueprintGridLayer (ColorRect)      — ShaderMaterial, uniform white border per tile
├── Camera2D                            — camera_2d.gd (WASD/QE/RF/ZC)
├── InGameHUD (CanvasLayer)             — packed scene InGameHUD.tscn
├── [HoverRect] (ColorRect)             — programmatic, semi-transparent hover indicator
├── [PlanContainer] (Node2D)            — programmatic, z=0, preview/staged ColorRects
├── [ConfirmedContainer] (Node2D)       — programmatic, z=1, permanent placed ColorRects
└── [BuildingLabelsContainer] (Node2D)  — programmatic, z=2, building name labels
```

### InGameHUD.tscn (simplified tree)
```
InGameHUD (CanvasLayer) — in_game_hud.gd
├── ModeControlToolbar (VBoxContainer)  — top-left, mode + indicators
│   ├── Buttons (HBoxContainer)
│   │   ├── GameModeBtn (Button)
│   │   ├── ArchModeBtn (Button)
│   │   ├── ManagementModeBtn (Button)
│   │   └── BulldozeBtn → packed scene
│   └── Indicators (HBoxContainer)
│       ├── SpeedIndicatorLabel (Label)  — amber (#f5b159), size 24
│       └── FloorIndicatorLabel (Label)  — cyan (#b1e5f5), size 24
├── DrawerPanel — item drawer (services/buildings/etc)
├── MainHUDPanel (PanelContainer)       — bottom HUD bar
│   └── MasterHorizontalSplit (HBoxContainer)
│       ├── MergedContainer1 — demand bars (water/sewage/electric/internet)
│       ├── TwoRowMatrix (VBoxContainer)
│       │   ├── TopRowToolbar — level badge, mode/tool buttons, right-side controls
│       │   └── BottomRowToolbar — item category toggles
│       └── (right side) — speed controls
├── ArchitecturalBorder (Panel)         — visible in ARCHITECTURAL mode
├── BulldozerBorder (Panel)             — visible in BULLDOZER mode
└── floating_bubble_control (Control)   — Confirm/Continue/Redrag widget
```

### Camera2D Control Scheme
```
Camera2D — camera_2d.gd
  _process → WASD movement (guarded by _is_text_input_focused)
  _unhandled_input → QE 30° rotation, RF floor toggle, ZC zoom (guarded)
  _calibrate_viewport_view → offset.y adjusts for HUD height
  position_smoothing_enabled = false  (disabled to fix tile alignment at max zoom)
```

### ConstructionState State Machine
```
IDLE ──start_drag──→ DRAGGING ──end_drag──→ PENDING_APPROVAL ──confirm→ IDLE
                    ↑                              │
                    └─────── clear_preview ────────┘
                         (cancel / right-click)
```

---

## Feature Status

### ✅ Completed (Chronological)

1. **Project Structure Cleanup** — Deleted stale root-level files. Moved `school_setup.gd` → `src/scripts/`. Removed duplicate `GameManager` autoload.

2. **Main Menu** — Fixed redundant dual signal/direct-call bug.

3. **GameMap / HUD Refactor** — Extracted `ConstructionState`, replaced `/root/GameMap` lookups with `find_parent`/`find_child`. Split components into `class_name` files. Replaced 6 button scripts with `HoverSlideButton`.

4. **GameManager** — Uses `preload` instead of `load` strings. Fixed `_ready()` timing bug.

5. **Building Plan Placement** — Plan preview using `Node2D` + `ColorRect` children (green preview → yellow staged → green confirmed).

6. **Cell Gap Fix** — `remove_child` + `queue_free` in `_remove_all_children()`.

7. **Grid Alignment** — Removed half-tile offset. Grid lines align with tile boundaries.

8. **Grid Constrained to FieldLayer** — `field_bounds` uniform excludes road area.

9. **Solid Pastel Colors** — Alpha 1.0 overlays completely hide field tiles.

10. **Separate Confirmed Container** — `confirmed_container` (z=1) for permanent rects; `plan_container` (z=0) for preview/staged.

11. **Mouse Input** — Replaced `is_action_pressed` with `event.button_index == MOUSE_BUTTON_LEFT`.

12. **Button Visual States** — `normal`/`hover`/`pressed`/`hover_pressed` style overrides + `toggle_mode` + `ButtonGroup`.

13. **Camera Controls** — WASD move, QE 30° rotation snap, RF floor toggle, ZC zoom (0.3–3.0×) with viewport recalibration.

14. **Speed Buttons** — PausePlay standalone toggle; Forward/FastForward share `ButtonGroup(allow_unpress=false)`. `_speed_toggle_lock` prevents recursion. Mode guards block speed changes in non-GAME modes.

15. **Mode Switching** — `_sync_speed_buttons()`. Mode borders, grid, and field modulate per mode.

16. **Continue Adjacent Tile** — `continue_adding()`, `_extending` flag, merges in `convert_previews_to_staged()`.

17. **Pick Individual Tile Mode** — Tool buttons wired via `_set_input_tool()`. Tiles paint on mouse move.

18. **Right-Click Targeted Removal** — `remove_cell(cell)` for staged/painted cells; drag-tool cancels entire placement.

19. **Bulldozer Restores Original Tiles** — `set_cell(cell, 0, Vector2i(0, 0))`.

20. **Cursor-Tile Mapping** — `_cell_under_mouse()` uses `field_layer.get_local_mouse_position()`.

21. **Confirmation Widget Passes Right-Click** — `mouse_filter = MOUSE_FILTER_IGNORE`.

22. **ARCHITECTURAL Mode Guards** — Checked in `_process_construction_input()` and `_unhandled_input()`.

23. **Building Rename Dialog** — `BuildingRenameDialog` (RefCounted) shows `Window` popup with LineEdit, Confirm/Cancel/Enter.

24. **Building Name Labels** — `_add_building_label()` with font_size=20, near-black text, white shadow. Labels in z=2, persist across modes. Bulldozer tracks cell ownership.

25. **X-Button Dismiss on Rename Dialog** — `close_requested` -> true-cancel path. Callback `func(confirmed, name)`.

26. **Toolbar Name Labels from Setup** — `school_name_label` and `principal_name_label` wired to `GlobalTransferData`.

27. **Rename Dialog Keyboard Guard** — `_is_text_input_focused()` checks all `Window` nodes recursively; gates WASD/QE/RF/ZC in `camera_2d.gd`.

28. **Per-Floor Building Tracking** — `_building_data` entries store `floor_level`. `_get_occupied_cells(floor)` filters by floor. Placement blocked on occupied cells + same-floor.

29. **Road/Grid Boundary Blocking** — `blocked_cells` and `grid_bounds` in `construction_state`. Road tiles (y=64,65) and out-of-bounds cells are blocked. Blocked preview shown in red (`PASTEL_BLOCKED_COLOR`).

30. **Toolbar Restructure** — `ModeControlToolbar` changed from `HBoxContainer` → `VBoxContainer` with inner `Buttons` + `Indicators` HBox. Floor/Speed labels at size 24.

31. **BlueGrid Shader Rewrite** — Uniform white border (#ffffff 0.5 alpha, 1.5px) per tile. Removed minor/major grid distinction. Updated `ShaderMaterial` params.

32. **Floor View Signal** — `GlobalSignalBus.floor_view_swapped` emitted from `camera_2d.gd` on R/F; connected in HUD to update floor label.

33. **Speed Display** — `_update_speed_display()` reads button state, shows ⏸ / 1× / 2× / 3×.

34. **Camera Smoothing Disabled** — `position_smoothing_enabled = false` fixes tile alignment at max zoom (visual lag caused half-tile offset).

35. **Mouse Hover Indicator** — Semi-transparent `ColorRect` tracks `_corner_under_mouse()` in ARCHITECTURAL and BULLDOZER modes. Red tint (0.35) on occupied tiles, white (0.2) on free tiles.

36. **Corner-to-Corner Grid Snapping** — Two mouse-mapping functions: `_cell_under_mouse()` (floor via `local_to_map` for tiles/bulldozer) and `_corner_under_mouse()` (round-to-nearest-grid-intersection for drag tool). Drag uses exclusive range `range(x_min, x_max)`, corners at `[0, GRID_SIZE]`. Tiles tool stays cell-based.

---

## Key Files

| File | Purpose |
|---|---|
| `src/scripts/game_map.gd` | Main game map — placement, bulldozer, mode switching, right-click, building labels, hover, corner/cell mouse mapping |
| `src/scripts/construction_state.gd` | Building plan state machine — drag/tiles/staged/preview/confirmed lifecycle, corner snapping |
| `src/scripts/in_game_hud.gd` | HUD — mode buttons, speed controls, tool buttons, rename dialog, floor/speed indicators |
| `src/scripts/camera_2d.gd` | Camera — WASD, QE rotate, RF floor, ZC zoom, text-focus guard, smoothing disabled |
| `src/scripts/hud/building_rename_dialog.gd` | Popup Window for naming buildings |
| `src/scripts/hud/floating_confirm_widget.gd` | Confirm/Continue/Redrag floating bubble |
| `src/scripts/blueprint_grid.gdshader` | Per-tile uniform white border shader |
| `src/scenes/game_map.tscn` | Main scene — FieldLayer, RoadLayer, BlueprintGridLayer, Camera2D, InGameHUD |
| `src/scenes/InGameHUD.tscn` | Full HUD — ModeControlToolbar, DrawerPanel, MainHUDPanel, speed controls |

---

## Key Architecture Decisions

- Plan overlay uses `Node2D` + `ColorRect` children — avoids missing `set_cell_modulate`.
- Building placement writes to `FieldLayer` + permanent `ColorRect` in `confirmed_container`.
- Grid shader uses `field_bounds` uniform with `>=` on right/bottom — excludes road rows.
- `_cell_under_mouse()`: tiles/bulldozer use `local_to_map()` (floor-based). `_corner_under_mouse()`: drag tool uses `roundi` (corner-to-corner).
- Drag selection uses **exclusive** range `range(x_min, x_max)` — corners define the selection bounds, tiles strictly between are filled.
- Right-click handled in `_input` with `set_input_as_handled()` — fires before GUI processing.
- Bulldozer uses `set_cell(cell, 0, Vector2i(0, 0))` — `erase_cell` left empty holes.
- Building labels are separate from confirmed ColorRects and persist across all modes.
- `position_smoothing_enabled = false` — WASD movement is already frame-rate smooth; smoothing caused visual/calculation misalignment at high zoom.
- Hover indicator uses same `_corner_under_mouse()` function as drag tool — consistent corner-based feedback.

---

## Z-Index Order

| z_index | Container | Content |
|---|---|---|
| 0 (default) | `PlanContainer` | Preview/staged ColorRects during placement |
| 0 (default) | `[HoverRect]` | Semi-transparent hover indicator (behind PlanContainer) |
| 1 | `ConfirmedContainer` | Permanent ColorRects after confirmation |
| 2 | `BuildingLabelsContainer` | Building name labels (always visible) |

---

## Known Limitations

- `set_cell_modulate` does **not** exist on `TileMapLayer` in this Godot version — ColorRect children used instead.
- `queue_free()` does not immediately remove children — `remove_child()` always called first.
- `set_cell(cell, -1, Vector2i(-1, -1))` silently fails — `set_cell(cell, 0, Vector2i(0, 0))` used to restore original tile.
- `FieldLayer` is a single `TileMapLayer` — all building tiles share it regardless of floor; per-floor separation is data-only (`_building_data.floor_level`).
- Camera zoom is clamped to `MAX_ZOOM = 3.0`; `_zoom_camera()` in `game_map.gd` clamps to 2.0 (unused code path — zoom is handled in `camera_2d.gd`).
