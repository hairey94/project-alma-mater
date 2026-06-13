# Project Progress — Campus Building & Classroom System

## Overview
Campus-block building placement system for Project Alma Mater (Godot 4). Supports drag-to-select and pick-individual-tile placement, right-click removal, bulldozer mode, camera/speed controls, building rename dialog with persistent labels, per-floor tracking, corner-to-corner grid snapping, **building editing (move/rotate/add-delete tiles)**, and **classroom placement/editing with named labels**.

---

## Scene Node Trees

### GameMap.tscn (and programmatic children)
```
GameMap (Node2D) — game_map.gd
├── FieldLayer (TileMapLayer)           — tile_set=blueprint tiles (64×64 grid)
├── RoadLayer (TileMapLayer)            — tile_set=road tiles (y=64, y=65)
├── BlueprintGridLayer (ColorRect)      — ShaderMaterial, uniform white border per tile
├── ClassroomLayer (TileMapLayer)       — z_index=2, mint green classroom tiles (atlas 1,0)
├── Camera2D                            — camera_2d.gd (WASD/QE/RF/ZC)
├── InGameHUD (CanvasLayer)             — packed scene InGameHUD.tscn
├── [HoverRect] (ColorRect)             — programmatic, semi-transparent hover indicator
├── [PlanContainer] (Node2D)            — programmatic, z=0, preview/staged ColorRects
├── [ConfirmedContainer] (Node2D)       — programmatic, z=1, permanent placed ColorRects
├── [BuildingLabelsContainer] (Node2D)  — programmatic, z=3, building name labels
└── [ClassroomContainer] (Node2D)       — programmatic, z_index=1, classroom edit visual rects
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
│   └── Classroom item toggles classroom placement tool
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

EDITING ──start_drag──→ DRAGGING ──end_drag──→ EDITING
   (begin_edit)          (middle-click)         (move_cells / end_drag)
                          rotate preview
                          
Classroom placement uses "tiles" tool + DRAGGING state with rectangle fill.
Classroom editing uses EDITING state with tile add/delete.
```

---

## Feature Status

### ✅ Completed (Chronological)

1—36. *(previous items 1–36 — see archived notes)*

37. **Classroom Placement System** — Players can select a "Classroom" tool from the toolbar, click inside a building, and drag to fill a **solid rectangle** (closed room shape). Classroom tiles render in mint green on `ClassroomLayer` (z=2). Placement respects building boundaries and doesn't overlap existing classrooms or other buildings.

38. **Classroom Tile Preview During Drag** — While dragging to place a classroom, mint-green tiles appear on `ClassroomLayer` in real-time. Cells outside the building or blocked by existing classrooms are excluded from the rectangle fill.

39. **Classroom Layers & Z-Ordering** — `ClassroomLayer` (TileMapLayer, z=2) renders classroom tiles above building tiles. `ClassroomContainer` (Node2D, z=1) shows edit preview rects. Labels remain at z=3.

40. **Hover Indicator for Classroom Tiles** — When hovering over building cells in ARCHITECTURAL mode, the hover rect shows. Classroom cells additionally highlight to indicate click-to-edit.

41. **Classroom Labels** — Each classroom gets a named `Label` at its centroid (font_size=22, warm brown #d19447). Labels reposition dynamically when the classroom is moved/resized. Labels stored in `_classroom_data[]` alongside cells and building index.

42. **Classroom Bulldoze on Building Demolish** — When a building is demolished, all classrooms belonging to that building are removed (tiles cleared via `erase_cell`, labels freed, `_classroom_data` entries removed). Building indices of remaining classrooms are adjusted.

43. **Building Move with Classrooms** — Moving a building (`move_rotate` tool) also moves its classrooms. Offset is tracked via `_building_edit_translation` and applied to classroom cells on confirm. Preview updates during drag.

44. **Building Rotation with Classrooms** — Middle-click rotation of a building rotates its classrooms around the same fixed centroid. Uses **non-iterative** rotation formula (direct 90°/180°/270° in one step) to prevent cumulative rounding errors. Translation offset preserved after rotation.

45. **Classroom Boundary & Clash Prevention** — New classroom rectangle fill checks `c in building.cells` (boundary) and `c not in construction.blocked_cells` (existing classrooms + other buildings). `_get_classroom_blocked_cells()` returns all other-building cells + same-building classroom cells.

46. **Classroom & Building Tile Edit Clash Prevention** — When editing a building/classroom (`add_delete` mode), `_process_construction_input` updates `blocked_cells` every frame: for classroom edits, blocks other classrooms in same building; for building edits, blocks other buildings' cells. `add_edit_cell()` re-checks via `_is_cell_blocked()`.

47. **Classroom Edit Dialog** — Clicking an existing classroom opens `BuildingEditDialog` with add/delete, move/rotate, rename, and demolish actions. Same flow as building editing but targets classroom data.

48. **State Cleanup After Classroom Confirmation** — On classroom placement confirm: `construction.staged_cells` cleared, `current_state` reset to `IDLE`, `_classroom_placement_building_index` reset to -1.

49. **Edit Mode Sync** — When switching between `add_delete` and `move_rotate` modes during building edit, `_building_edit_original_cells` is synced to current `editing_cells`, and rotation/translation state is reset. Prevents stale-base drift.

---

## Key Files

| File | Purpose |
|---|---|
| `src/scripts/game_map.gd` | Main game map — placement, bulldozer, mode switching, building edit (move/rotate/add-delete), classroom placement/edit, labels, collision prevention, rotation math |
| `src/scripts/construction_state.gd` | Building plan state machine — drag/tiles/staged/preview/confirmed lifecycle, corner snapping, edit/move/rotate logic |
| `src/scripts/in_game_hud.gd` | HUD — mode buttons, speed controls, tool buttons, rename dialog, floor/speed indicators |
| `src/scripts/camera_2d.gd` | Camera — WASD, QE rotate, RF floor, ZC zoom, text-focus guard, smoothing disabled |
| `src/scripts/hud/building_edit_dialog.gd` | Reusable edit dialog for buildings and classrooms (add/delete, move/rotate, rename, demolish) |
| `src/scripts/hud/building_rename_dialog.gd` | Popup Window for naming buildings/classrooms |
| `src/scripts/hud/floating_confirm_widget.gd` | Confirm/Continue/Redrag floating bubble |
| `src/scripts/blueprint_grid.gdshader` | Per-tile uniform white border shader |
| `src/scenes/game_map.tscn` | Main scene — FieldLayer, RoadLayer, ClassroomLayer, BlueprintGridLayer, Camera2D, InGameHUD |
| `src/scenes/InGameHUD.tscn` | Full HUD — ModeControlToolbar, DrawerPanel, MainHUDPanel, speed controls |

---

## Key Architecture Decisions

- Plan overlay uses `Node2D` + `ColorRect` children — avoids missing `set_cell_modulate`.
- Building placement writes to `FieldLayer` + permanent `ColorRect` in `confirmed_container`.
- Classroom tiles use `ClassroomLayer` (TileMapLayer) with `erase_cell` for cleanup (not `set_cell` with empty atlas).
- Grid shader uses `field_bounds` uniform with `>=` on right/bottom — excludes road rows.
- `_cell_under_mouse()`: tiles/bulldozer use `local_to_map()` (floor-based). `_corner_under_mouse()`: drag tool uses `roundi` (corner-to-corner).
- Drag selection uses **exclusive** range `range(x_min, x_max)` — corners define the selection bounds, tiles strictly between are filled.
- Right-click handled in `_input` with `set_input_as_handled()` — fires before GUI processing.
- Bulldozer uses `set_cell(cell, 0, Vector2i(0, 0))` — `erase_cell` left empty holes.
- Building/classroom labels are separate from confirmed ColorRects and persist across all modes.
- `position_smoothing_enabled = false` — WASD movement is already frame-rate smooth; smoothing caused visual/calculation misalignment at high zoom.
- Classroom placement uses **rectangle fill** (closed room) instead of individual cell painting — drag defines a rectangle, interior cells within building boundary are filled.
- Building rotation uses **non-iterative** formula (`match k {1,2,3}`) applied directly to original cells around a fixed centroid, avoiding cumulative rounding errors.
- Translation and rotation are tracked separately (`_building_edit_translation` + `_building_edit_rotation_count`) and composed on confirm.
- Edit mode switching syncs `_building_edit_original_cells` to current editing state to prevent stale-base drift after add/delete operations.

---

## Z-Index Order

| z_index | Container | Content |
|---|---|---|
| 0 (default) | `PlanContainer` | Preview/staged ColorRects during placement |
| 0 (default) | `[HoverRect]` | Semi-transparent hover indicator (behind PlanContainer) |
| 1 | `ConfirmedContainer` | Permanent ColorRects after confirmation |
| 1 | `ClassroomContainer` | Classroom edit preview rects |
| 2 | `ClassroomLayer` | Mint green classroom tilemap tiles |
| 3 | `BuildingLabelsContainer` | Building and classroom name labels (always visible) |

---

## Known Limitations

- `set_cell_modulate` does **not** exist on `TileMapLayer` in this Godot version — ColorRect children used instead.
- `queue_free()` does not immediately remove children — `remove_child()` always called first.
- `set_cell(cell, -1, Vector2i(-1, -1))` silently fails — `set_cell(cell, 0, Vector2i(0, 0))` used to restore original tile.
- `FieldLayer` is a single `TileMapLayer` — all building tiles share it regardless of floor; per-floor separation is data-only (`_building_data.floor_level`).
- Camera zoom is clamped to `MAX_ZOOM = 3.0`; `_zoom_camera()` in `game_map.gd` clamps to 2.0 (unused code path — zoom is handled in `camera_2d.gd`).
- Classroom rectangle fill may produce non-rectangular results if part of the drag area is blocked by existing classrooms — blocked cells are simply skipped.
- Rotating a building with irregular shape may place classroom cells slightly outside the rotated building boundary; no post-rotation clamp is performed.
