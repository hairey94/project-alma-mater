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

50. **Door Placement System** — Added door system via "doors → entrance → Single Door" item. Doors are 1-tile overlays placed at building/classroom edges. Middle-click toggles inward/outward swing direction during placement. Preview shows door symbol (parallel to edge). Placement validates: must be at edge (exactly 1 outside neighbor, not a corner tile), can't overlap other doors.

51. **Door Visuals** — Architectural door symbol drawn using ColorRects under `_door_container` (z=3). Shows door panel line, wall gap frame, swing arc marker, and hinge point. Direction updates in real-time on middle-click. Warm brown (#d4a373) semi-transparent overlay.

52. **Door Editing** — Left-click placed door opens BuildingEditDialog with Move/Rotate, Rename, Demolish actions. Move: click a new valid edge tile to relocate. Rotate: middle-click toggles inward/outward. Same validation as placement. Rename via standard rename dialog. Demolish with confirmation dialog.

53. **Door Cleanup on Demolish** — Building demolish removes all associated doors and adjusts indices. Classroom demolish removes its doors and adjusts remaining door classroom indices.

54. **Corridor Rotation Consistency** — Fixed `_is_corridor_connectivity_ok` using integer truncated centroid while building/classroom/door used floating-point, causing corridor misalignment on rotation. Unified all rotation transforms to use `_building_edit_centroid` (Vector2).

55. **Door Rotation Centroid Fix** — Door rotation was computing `door_centroid` from truncated `Vector2i` centroids, causing displacement. Now passes `_building_edit_centroid` directly to `_transform_door_cell` with floating-point rounding.

56. **Mouse Wheel No-Op** — Mouse wheel events consumed via `set_input_as_handled()` and dropped silently to prevent unintended edit dialog opening.

57. **Dialog Repositioned to Bottom-Right** — Edit dialog positioned at `Vector2i(maxi(0, screen_size.x - window.size.x), maxi(0, screen_size.y - window.size.y))` instead of centered.

58. **"Editing …" HUD Notifications** — All edit start functions (`_start_building_edit`, `_start_classroom_edit`, `_start_door_edit`) now show a `hud_message("Editing %s" …)` call.

59. **Classroom Re-add After Delete** — Fixed `_get_classroom_blocked_cells` to skip current editing classroom's cells, enabling tile re-addition within the same edit session.

60. **Classroom Label Overlap & Style** — Classroom label font: black `Color(0, 0, 0, 1)`, size 26 (was 22), vertical offset -36 (was -20). Missing offset added to `_confirm_classroom_edit`, `_rename_classroom`, `_apply_building_edit_classroom_changes`. White shadow added for readability.

61. **Classroom Overrides Corridors** — On classroom edit confirm, corridor cells overlapping classroom tiles are removed from both `_corridor_data` and `corridor_layer`. Hover indicator shows orange for corridor-override cells, green for valid empty, red for invalid. HUD message updated to: "Left-click to add tiles, right-click to delete. Corridor tiles will be replaced."

---

## Key Files

| File | Lines | Purpose |
|---|---|---|---|
| `src/scripts/game_map.gd` | ~2228 | Main game map — placement, bulldozer, mode switching, building edit (move/rotate/add-delete), classroom placement/edit, labels, collision prevention, rotation math, door system |
| `src/scripts/construction_state.gd` | 358 | Building plan state machine — drag/tiles/staged/preview/confirmed lifecycle, corner snapping, edit/move/rotate logic |
| `src/scripts/in_game_hud.gd` | 868 | HUD — mode buttons, speed controls, tool buttons, rename dialog, floor/speed indicators |
| `src/scripts/camera_2d.gd` | 106 | Camera — WASD, QE rotate, RF floor, ZC zoom, text-focus guard, smoothing disabled |
| `src/scripts/hud/building_edit_dialog.gd` | 105 | Reusable edit dialog for buildings and classrooms (add/delete, move/rotate, rename, demolish) |
| `src/scripts/hud/building_rename_dialog.gd` | 56 | Popup Window for naming buildings/classrooms |
| `src/scripts/hud/floating_confirm_widget.gd` | 83 | Confirm/Continue/Redrag floating bubble |
| `src/scripts/blueprint_grid.gdshader` | 29 | Per-tile uniform white border shader |
| `src/scenes/game_map.tscn` | 297 nodes | Main scene — FieldLayer, RoadLayer, ClassroomLayer, BlueprintGridLayer, Camera2D, InGameHUD |
| `src/scenes/InGameHUD.tscn` | 70 nodes | Full HUD — ModeControlToolbar, DrawerPanel, MainHUDPanel, speed controls |
| `src/scripts/BuildingDatabase.gd` | 251 | Centralized item catalogue — includes `doors/entrance/Single Door` entry |

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
| 3 | `DoorContainer` | Door symbol ColorRects (overlays on building/classroom tiles) |
| 3 | `BuildingLabelsContainer` | Building, classroom, and door name labels (always visible) |

---

## Known Limitations

- `set_cell_modulate` does **not** exist on `TileMapLayer` in this Godot version — ColorRect children used instead.
- `queue_free()` does not immediately remove children — `remove_child()` always called first.
- `set_cell(cell, -1, Vector2i(-1, -1))` silently fails — `set_cell(cell, 0, Vector2i(0, 0))` used to restore original tile.
- `FieldLayer` is a single `TileMapLayer` — all building tiles share it regardless of floor; per-floor separation is data-only (`_building_data.floor_level`).
- Camera zoom is clamped to `MAX_ZOOM = 3.0`; `_zoom_camera()` in `game_map.gd` clamps to 2.0 (unused code path — zoom is handled in `camera_2d.gd`).
- Classroom rectangle fill may produce non-rectangular results if part of the drag area is blocked by existing classrooms — blocked cells are simply skipped.
- Rotating a building with irregular shape may place classroom cells slightly outside the rotated building boundary; no post-rotation clamp is performed.
- Door placement is validated for edge and parallel constraints but does not check that the building has at least one door or that every classroom has one (enforcement is manual).

---

## Project Statistics (2026-06-14)

| Metric | Count |
|---|---|
| **Total .gd scripts** | 13 |
| **Total script lines** | ~3996 |
| **Total .tscn scenes** | 7 |
| **Total scene nodes** (top-level) | ~431 |
| **Key scenes** | game_map.tscn (297), InGameHUD.tscn (70), BuildingEditDialog.tscn (18), BuildingRenameDialog.tscn (9), FloatingConfirmWidget.tscn (11), ItemToolTip.tscn (6) |
| **Most complex script** | `game_map.gd` — ~2228 lines, 52 functions, 300+ variable references |
| **Git commits** (all-time) | 161 |
| **Test files** | 0 (no test framework configured) |

### File Size Distribution (top 5 .gd)
| File | Lines |
|---|---|
| `game_map.gd` | 2228 |
| `in_game_hud.gd` | 868 |
| `construction_state.gd` | 358 |
| `BuildingDatabase.gd` | 251 |
| `camera_2d.gd` | 106 |
