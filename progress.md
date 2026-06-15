# Project Progress — Campus Building & Room System

## Overview
Campus-block building and room placement system for Project Alma Mater (Godot 4). Supports drag-to-select and pick-individual-tile placement, right-click removal, bulldozer mode, camera/speed controls, building rename dialog with persistent labels, per-floor tracking, corner-to-corner grid snapping, **building editing (move/rotate/add-delete tiles)**, **corridor placement with rectangular drag**, **door placement/editing**, and **generic room system** supporting multiple room types: Classroom, Male/Female Student Washrooms, Administration Area, Principal Office, and Cafeteria. Rooms share a unified placement/edit/demolish/door-attachment pipeline with per-type tile styling.

---

## Scene Node Trees

### GameMap.tscn (and programmatic children)
```
GameMap (Node2D) — game_map.gd
├── FieldLayer (TileMapLayer)           — tile_set=blueprint tiles (64×64 grid)
├── RoadLayer (TileMapLayer)            — tile_set=road tiles (y=64, y=65)
├── BlueprintGridLayer (ColorRect)      — ShaderMaterial, uniform white border per tile
├── ClassroomLayer (TileMapLayer)       — z_index=2, shared room tile layer (all room types)
├── PrincipalOfficeLayer (TileMapLayer) — z_index=3 (programmatic), Principal Office tiles only
├── CorridorLayer (TileMapLayer)        — z_index=2 (programmatic), corridor tiles
├── Camera2D                            — camera_2d.gd (WASD/QE/RF/ZC)
├── InGameHUD (CanvasLayer)             — packed scene InGameHUD.tscn
├── [HoverRect] (ColorRect)             — programmatic, semi-transparent hover indicator
├── [PlanContainer] (Node2D)            — programmatic, z=0, preview/staged ColorRects
├── [ConfirmedContainer] (Node2D)       — programmatic, z=1, permanent placed ColorRects
├── [BuildingLabelsContainer] (Node2D)  — programmatic, z=5, building name labels
├── [EdgeLineContainer] (Node2D)        — programmatic, z=4, room perimeter border lines
├── [DoorContainer] (Node2D)            — programmatic, z=4, door overlay symbols
└── [ClassroomContainer] (Node2D)       — programmatic, z_index=1, room edit visual rects
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
├── DrawerPanel — item drawer (services/buildings/rooms/admin/business)
│   └── Room items toggle room placement tool; Principal Office auto-disabled after placement
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
                          
Room placement uses "tiles" tool + DRAGGING state with rectangle fill.
Room editing uses EDITING state with tile add/delete.
Corridor defaults to "tiles" tool (rectangular drag) instead of freeform.
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

62. **Room System Refactor** — Refactored `classroom_manager.gd` → `RoomManager` (class_name) with generic room type support. Room types: Classroom, Male Student Washroom, Female Student Washroom, Administration Area, Principal Office, Cafeteria. Per-type counters, atlas coordinates, naming, and edit dialog titles via dispatch functions.

63. **Washroom Room Types** — Male Student Washroom (white tiles with blue border, atlas 2,0) and Female Student Washroom (white tiles with pink border, atlas 2,1). Same mechanics as classrooms: placement, edit, rename, demolish, door attachment, building transformation. Registered under BuildingDatabase `rooms → public`.

64. **Administration Area** — Cream-colored tiles with black border (atlas 0,2). Same placement/door/transform mechanics as classrooms. Registered under BuildingDatabase `rooms → admin`. Label positioned above cells (-36 offset).

65. **Principal Office** — Dark red carpet with full perimeter wall (atlas 1,2). Special room type: singleton (only one per map), must be placed inside an Administration Area, no rename capability, no `#N` suffix. Uses **separate** `principal_office_layer` (TileMapLayer, z=3) so underlying Admin Area tiles are preserved and restored on demolish. Label positioned below cells (+36 offset) to avoid overlapping Admin Area label. Button auto-disables after placement and re-enables on demolish.

66. **Cafeteria Room Type** — Warm beige/dining tiles (atlas 2,2 normal, 3,2 game mode). Same mechanics as classrooms. Registered under BuildingDatabase `rooms → business`. Per-type counter and edit dialog title.

67. **Door Attachment for All Room Types** — Door tracking uses generic `room_index` (renamed from `classroom_index`). Doors attach/detach correctly during room transformations and building whole transformations. `get_at_cell` in RoomManager returns Principal Office entries first to ensure door placement finds PO edges over underlying Admin Area.

68. **Corridor Rectangle Drag Mode** — Corridor defaults to "tiles" tool (rectangular drag) instead of freeform painting. `set_active_placement_item()` sets `construction.current_tool = "tiles"` when a corridor item is selected. Drag paints bounding rectangle; confirm handles rectangle-generated cells.

69. **Building Rotation Access Through Rooms** — Right-click on any building cell (even when fully covered by rooms) with no active tool starts building edit, providing access to rotate/move when all building cells are room-occupied.

70. **Principal Office Perimeter & Labels Z-Ordering** — Door container z=4, edge line container z=4, building labels container z=5 to ensure Principal Office perimeter border, doors, and labels render above `principal_office_layer` (z=3).

71. **Game Mode Tile Styling** — Room tiles switch atlas coordinates in game mode via `get_atlas_for_room()`. `classroom_layer.modulate` set to `Color.WHITE` in all modes (per-mode variation is handled via atlas). Game mode tiles: classroom (3,1), cafeteria (3,2).

72. **Admin/P.O. Label Non-Overlap** — Principal Office label uses +36 offset (below cells) while all other rooms use -36 (above cells), preventing label overlap since PO is always inside an Admin Area.

---

## Key Files

| File | Lines | Purpose |
|---|---|---|
| `src/scripts/game_map.gd` | 1581 | Main game map — placement, bulldozer, mode switching, building edit (move/rotate/add-delete), room placement/edit, labels, collision prevention, rotation math, door system, corridor drag |
| `src/scripts/in_game_hud.gd` | 481 | HUD — mode buttons, speed controls, item drawer, rename dialog, Principal Office button disable |
| `src/scripts/construction_state.gd` | 315 | Building plan state machine — drag/tiles/staged/preview/confirmed lifecycle, corner snapping, edit/move/rotate logic |
| `src/scripts/BuildingDatabase.gd` | 268 | Centralized item catalogue — buildings, rooms (public/admin/business), doors, corridors |
| `src/scripts/managers/classroom_manager.gd` | 199 | RoomManager (class_name) — room type dispatch, atlas mapping, naming, counters, layer routing, Principal Office singleton |
| `src/scripts/managers/input_handler.gd` | 168 | Input routing — click/hover dispatch, building edit start, room placement flow |
| `src/scripts/managers/door_manager.gd` | 141 | Door placement/editing/validation with generic room_index support |
| `src/scripts/map_renderer.gd` | 116 | Grid shader sync, edge line drawing for all room types, hover rect updates |
| `src/scripts/school_setup.gd` | 101 | School setup wizard scene logic |
| `src/scripts/managers/corridor_manager.gd` | 95 | Corridor placement/editing with connectivity checks |
| `src/scripts/TimeManager.gd` | 82 | Time/duration tracking |
| `src/scripts/camera_2d.gd` | 74 | Camera — WASD, QE rotate, RF floor, ZC zoom, text-focus guard |
| `src/scripts/managers/building_manager.gd` | 53 | Building data management — add/remove/get/label positioning |
| `src/scripts/managers/map_utils.gd` | 49 | Utility functions — centroid, label positioning, cell rotation |
| `src/scripts/hud/building_edit_dialog.gd` | 87 | Reusable edit dialog for buildings and rooms (add/delete, move/rotate, rename, demolish) |
| `src/scripts/hud/building_rename_dialog.gd` | 63 | Popup Window for naming buildings/rooms |
| `src/scripts/hud/floating_confirm_widget.gd` | 41 | Confirm/Continue/Redrag floating bubble |
| `src/scripts/blueprint_grid.gdshader` | 29 | Per-tile uniform white border shader |

---

## Key Architecture Decisions

- **Room System Refactor**: `ClassroomManager` refactored into `RoomManager` with type constants (`ROOM_TYPE_CLASSROOM`, `ROOM_TYPE_MALE_WASHROOM`, `ROOM_TYPE_FEMALE_WASHROOM`, `ROOM_TYPE_ADMIN_AREA`, `ROOM_TYPE_PRINCIPAL_OFFICE`, `ROOM_TYPE_CAFETERIA`). Dispatch functions (`default_name`, `edit_title`, `get_atlas_for_room`) centralize per-type logic. Counters are per-type in a `Dictionary`.
- **Principal Office Separate Layer**: Uses a separate `principal_office_layer` (TileMapLayer, z=3) instead of overwriting Admin Area tiles on `room_layer`, so demolishing PO restores the underlying Admin Area tiles automatically.
- **Label Positioning**: Principal Office label uses +36 (below cells) to avoid overlapping Admin Area label (-36 above cells). All other rooms use -36.
- **Layer Z-Ordering**: `room_layer` z=2, `principal_office_layer` z=3, `door_container` z=4, `edge_line_container` z=4, `building_labels_container` z=5.
- **Corridor Rectangle Default**: Corridor sets `construction.current_tool = "tiles"` on selection, defaulting to rectangular drag instead of freeform painting.
- **Building Rotation Through Rooms**: Right-click on any building cell (even room-covered) with no active tool starts building edit via `_handle_right_click`.
- **Door Generic Indexing**: Doors track via `room_index` (renamed from `classroom_index`) to support all room types.
- **`get_at_cell` Priority**: RoomManager returns Principal Office entries first, ensuring door placement finds PO edges over underlying Admin Area.
- **Per-Mode Tile Variation**: Game mode tile variation handled via `get_atlas_for_room()` returning different atlas coordinates; `classroom_layer.modulate` is `Color.WHITE` in all modes.
- **Plan overlay uses `Node2D` + `ColorRect` children** — avoids missing `set_cell_modulate`.
- **Building placement writes to `FieldLayer` + permanent `ColorRect`** in `confirmed_container`.
- **Room tiles use shared `ClassroomLayer`** with `erase_cell` for cleanup (not `set_cell` with empty atlas).
- **Grid shader** uses `field_bounds` uniform with `>=` on right/bottom — excludes road rows.
- **`_cell_under_mouse()`**: tiles/bulldozer use `local_to_map()` (floor-based). `_corner_under_mouse()`: drag tool uses `roundi` (corner-to-corner).
- **Drag selection** uses **exclusive** range `range(x_min, x_max)` — corners define the selection bounds, tiles strictly between are filled.
- **Right-click** handled in `_input` with `set_input_as_handled()` — fires before GUI processing.
- **Bulldozer** uses `set_cell(cell, 0, Vector2i(0, 0))` — `erase_cell` left empty holes.
- **Labels** are separate from confirmed ColorRects and persist across all modes.
- **`position_smoothing_enabled = false`** — WASD movement is already frame-rate smooth; smoothing caused visual/calculation misalignment at high zoom.
- **Building rotation** uses **non-iterative** formula (`match k {1,2,3}`) applied directly to original cells around a fixed centroid, avoiding cumulative rounding errors.
- **Translation and rotation** are tracked separately (`_building_edit_translation` + `_building_edit_rotation_count`) and composed on confirm.
- **Edit mode switching** syncs `_building_edit_original_cells` to current editing state to prevent stale-base drift after add/delete operations.

---

## Z-Index Order

| z_index | Container | Content |
|---|---|---|
| 0 (default) | `PlanContainer` | Preview/staged ColorRects during placement |
| 0 (default) | `[HoverRect]` | Semi-transparent hover indicator (behind PlanContainer) |
| 0 (default) | `CorridorLayer` | Corridor tiles |
| 1 | `ConfirmedContainer` | Permanent ColorRects after confirmation |
| 1 | `ClassroomContainer` | Room edit preview rects |
| 2 | `ClassroomLayer` | All room tiles (shared) |
| 3 | `PrincipalOfficeLayer` | Principal Office tiles only (programmatic) |
| 4 | `DoorContainer` | Door symbol ColorRects |
| 4 | `EdgeLineContainer` | Room perimeter border lines |
| 5 | `BuildingLabelsContainer` | Building, room, and door name labels (always visible) |

---

## Known Limitations

- `set_cell_modulate` does **not** exist on `TileMapLayer` in this Godot version — ColorRect children used instead.
- `queue_free()` does not immediately remove children — `remove_child()` always called first.
- `set_cell(cell, -1, Vector2i(-1, -1))` silently fails — `set_cell(cell, 0, Vector2i(0, 0))` used to restore original tile.
- `FieldLayer` is a single `TileMapLayer` — all building tiles share it regardless of floor; per-floor separation is data-only (`_building_data.floor_level`).
- Camera zoom is clamped to `MAX_ZOOM = 3.0`; `_zoom_camera()` in `game_map.gd` clamps to 2.0 (unused code path — zoom is handled in `camera_2d.gd`).
- Room rectangle fill may produce non-rectangular results if part of the drag area is blocked by existing rooms — blocked cells are simply skipped.
- Rotating a building with irregular shape may place room cells slightly outside the rotated building boundary; no post-rotation clamp is performed.
- Door placement is validated for edge and parallel constraints but does not check that the building has at least one door or that every room has one (enforcement is manual).
- Principal Office label offset (+36 below centroid) may overlap building interior detail if PO is in a very small area; fine for typical use.
- Cafeteria, washrooms, and other business/public rooms have no game-mode-specific visual behavior beyond atlas swap — all use the same generic tile system.

---

## Project Statistics (2026-06-15)

| Metric | Count |
|---|---|
| **Total .gd scripts** | 30 |
| **Total script lines** | ~3977 |
| **Total .tscn scenes** | 6 |
| **Total scene nodes** (top-level) | 167 |
| **Key scenes** | InGameHUD.tscn (112 nodes), school_setup.tscn (27), main_menu.tscn (18), game_map.tscn (8) |
| **Most complex script** | `game_map.gd` — 1581 lines, 40+ functions, room/door/corridor/building management |
| **Git commits** (all-time) | 3 |
| **Test files** | 0 (no test framework configured) |

### File Size Distribution (top 10 .gd)
| File | Lines |
|---|---|
| `game_map.gd` | 1581 |
| `in_game_hud.gd` | 481 |
| `construction_state.gd` | 315 |
| `BuildingDatabase.gd` | 268 |
| `classroom_manager.gd` | 199 |
| `input_handler.gd` | 168 |
| `door_manager.gd` | 141 |
| `map_renderer.gd` | 116 |
| `school_setup.gd` | 101 |
| `corridor_manager.gd` | 95 |
