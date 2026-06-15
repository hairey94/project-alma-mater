extends Node2D

@onready var field_layer: TileMapLayer = $FieldLayer
@onready var road_layer: TileMapLayer = $RoadLayer
@onready var classroom_layer: TileMapLayer = $ClassroomLayer
@onready var corridor_layer: TileMapLayer = $CorridorLayer
@onready var blueprint_grid_layer: ColorRect = $BlueprintGridLayer
var principal_office_layer: TileMapLayer
@onready var camera: Camera2D = $Camera2D

const GRID_SIZE = 64
const TILE_SIZE = 64
const FIELD_PX = GRID_SIZE * TILE_SIZE
const BuildingEditDialog = preload("res://src/scripts/hud/building_edit_dialog.gd")
const BuildingManager = preload("res://src/scripts/managers/building_manager.gd")
const RoomManager = preload("res://src/scripts/managers/classroom_manager.gd")
const CorridorManager = preload("res://src/scripts/managers/corridor_manager.gd")
const DoorManager = preload("res://src/scripts/managers/door_manager.gd")
const MapRenderer = preload("res://src/scripts/map_renderer.gd")
const InputHandler = preload("res://src/scripts/managers/input_handler.gd")
const MapUtils = preload("res://src/scripts/managers/map_utils.gd")

var plan_container: Node2D
var confirmed_container: Node2D
var construction: ConstructionState
var building_mgr
var room_mgr
var corridor_mgr
var door_mgr
var renderer
var input_handler

var _building_edit_dialog
var _building_labels_container: Node2D
var _room_container: Node2D
var _door_container: Node2D
var _door_placement_preview_node: Node2D
var _edge_line_container: Node2D
var _hover_rect: ColorRect
var _door_hover_tile_rect: ColorRect

var _is_bulldozing: bool = false
var _last_bulldoze_cell: Vector2i = Vector2i(-1, -1)
var _editing_action: String = ""
var _building_edit_original_cells: Array[Vector2i] = []
var _building_edit_room_entries: Array[Dictionary] = []
var _building_edit_cleared_originals: bool = false
var _building_edit_rotation_count: int = 0
var _building_edit_centroid: Vector2 = Vector2.ZERO
var _building_edit_translation: Vector2i = Vector2i.ZERO
var _room_placement_building_index: int = -1
var _is_room_edit: bool = false
var _room_editing_index: int = -1
var _is_door_edit: bool = false
var _door_editing_index: int = -1
var _is_corridor_edit: bool = false
var _corridor_editing_index: int = -1
var _corridor_edit_overlay_cells: Array[Vector2i] = []

var _hover_room_tile_cell: Vector2i = Vector2i(-999, -999)

func _ready() -> void:
	plan_container = Node2D.new()
	plan_container.name = "PlanContainer"
	add_child(plan_container)

	confirmed_container = Node2D.new()
	confirmed_container.name = "ConfirmedContainer"
	confirmed_container.z_index = 1
	add_child(confirmed_container)

	_building_labels_container = Node2D.new()
	_building_labels_container.name = "BuildingLabelsContainer"
	_building_labels_container.z_index = 5
	add_child(_building_labels_container)

	_room_container = Node2D.new()
	_room_container.name = "ClassroomContainer"
	_room_container.z_index = 1
	add_child(_room_container)

	classroom_layer.z_index = 2
	corridor_layer.z_index = 2

	_door_container = Node2D.new()
	_door_container.name = "DoorContainer"
	_door_container.z_index = 3
	add_child(_door_container)

	_door_placement_preview_node = Node2D.new()
	_door_placement_preview_node.name = "DoorPlacementPreview"
	_door_placement_preview_node.visible = false
	_door_placement_preview_node.z_index = 4
	add_child(_door_placement_preview_node)

	_hover_rect = ColorRect.new()
	_hover_rect.name = "HoverRect"
	_hover_rect.size = Vector2(TILE_SIZE, TILE_SIZE)
	_hover_rect.color = Color(1, 1, 1, 0.2)
	_hover_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hover_rect.visible = false
	add_child(_hover_rect)

	_edge_line_container = Node2D.new()
	_edge_line_container.name = "EdgeLineContainer"
	_edge_line_container.z_index = 4
	add_child(_edge_line_container)

	_door_hover_tile_rect = ColorRect.new()
	_door_hover_tile_rect.name = "DoorHoverTileRect"
	_door_hover_tile_rect.size = Vector2(TILE_SIZE, TILE_SIZE)
	_door_hover_tile_rect.color = Color(1, 1, 0, 0.3)
	_door_hover_tile_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_door_hover_tile_rect.visible = false
	_door_hover_tile_rect.z_index = 4
	add_child(_door_hover_tile_rect)

	construction = ConstructionState.new()
	construction.setup(field_layer, plan_container, confirmed_container)
	construction.grid_bounds = Rect2i(0, 0, GRID_SIZE, GRID_SIZE)

	building_mgr = BuildingManager.new()
	building_mgr.setup(_building_labels_container)
	room_mgr = RoomManager.new()
	principal_office_layer = TileMapLayer.new()
	principal_office_layer.tile_set = classroom_layer.tile_set
	principal_office_layer.z_index = 3
	add_child(principal_office_layer)
	room_mgr.setup(_building_labels_container, classroom_layer, building_mgr, principal_office_layer)
	_door_container.z_index = 4

	corridor_mgr = CorridorManager.new()
	corridor_mgr.setup(corridor_layer, building_mgr, room_mgr)
	door_mgr = DoorManager.new()
	door_mgr.setup(_door_container, _door_placement_preview_node, building_mgr, room_mgr)
	renderer = MapRenderer.new()
	renderer.setup(blueprint_grid_layer, camera, _edge_line_container, _hover_rect, _door_hover_tile_rect, field_layer, building_mgr, room_mgr, corridor_mgr)
	input_handler = InputHandler.new()
	input_handler.setup(self)

	_generate_map()
	_center_camera_on_road()
	renderer.update_edge_lines()

	blueprint_grid_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	blueprint_grid_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	blueprint_grid_layer.visible = false

	var hud = find_child("InGameHUD", true, false)
	if hud and hud.has_signal("mode_changed"):
		hud.mode_changed.connect(_on_game_mode_changed)

func _generate_map() -> void:
	for x in range(GRID_SIZE):
		for y in range(GRID_SIZE):
			field_layer.set_cell(Vector2i(x, y), 0, Vector2i(0, 0))
	for x in range(GRID_SIZE):
		road_layer.set_cell(Vector2i(x, GRID_SIZE), 0, Vector2i(1, 0))
		road_layer.set_cell(Vector2i(x, GRID_SIZE + 1), 0, Vector2i(1, 0))

func _center_camera_on_road() -> void:
	camera.position = Vector2((GRID_SIZE * TILE_SIZE) / 2.0, (GRID_SIZE * TILE_SIZE) / 1.4)

func _process(delta: float) -> void:
	_update_hover_rect()
	renderer.sync_grid_shader()
	if _is_bulldozing:
		var cell = _cell_under_mouse()
		if cell != _last_bulldoze_cell:
			_bulldoze_cell(cell)
			_last_bulldoze_cell = cell
	if construction.active_item_name != "" or construction.current_state in [ConstructionState.State.EDITING, ConstructionState.State.DRAGGING]:
		_process_construction_input()

func _update_hover_rect() -> void:
	_door_hover_tile_rect.visible = false
	corridor_mgr.clear_hover_tile()
	var mode = GlobalTransferData.current_mode
	if mode != GlobalTransferData.GameMode.ARCHITECTURAL and mode != GlobalTransferData.GameMode.BULLDOZER:
		renderer.hide_hover()
		room_mgr.clear_hover_tile()
		_clear_hover_door_preview()
		return

	var use_cell = construction.current_tool == "tiles"
	var pos = _cell_under_mouse() if use_cell else _corner_under_mouse()

	if mode == GlobalTransferData.GameMode.ARCHITECTURAL:
		if pos.x < 0 or pos.x >= GRID_SIZE or pos.y < 0 or pos.y >= GRID_SIZE:
			renderer.hide_hover()
			room_mgr.clear_hover_tile()
			return
	elif mode == GlobalTransferData.GameMode.BULLDOZER:
		if pos.x < 0 or pos.x >= GRID_SIZE or pos.y < 0 or pos.y >= GRID_SIZE + 2:
			renderer.hide_hover()
			room_mgr.clear_hover_tile()
			return

	renderer.update_hover(pos, Color(1, 1, 1, 0.2))

	if mode == GlobalTransferData.GameMode.ARCHITECTURAL:
		if _is_room_item(construction.active_item_name):
			var cell = _cell_under_mouse()
			var b_idx = building_mgr.get_at_cell(cell)
			if b_idx >= 0:
				var blocked = room_mgr.get_blocked_cells(b_idx, _room_editing_index if _is_room_edit else -1)
				if construction.active_item_name == "Principal Office" and construction.current_state == ConstructionState.State.IDLE:
					var admin_idx = room_mgr.get_admin_area_in_building(b_idx)
					if admin_idx >= 0:
						for c in room_mgr.get_entry(admin_idx).cells:
							var bi = blocked.find(c)
							if bi >= 0:
								blocked.remove_at(bi)
				if cell in blocked:
					renderer.update_hover(pos, Color(1, 0.3, 0.3, 0.55))
					room_mgr.clear_hover_tile()
				else:
					renderer.update_hover(pos, Color(0.4, 0.85, 0.5, 0.5))
					if construction.current_state == ConstructionState.State.IDLE:
						_update_hover_room_tile(cell)
					else:
						room_mgr.clear_hover_tile()
			else:
				renderer.update_hover(pos, Color(1, 0.3, 0.3, 0.55))
				room_mgr.clear_hover_tile()
		elif _is_room_edit and _room_editing_index >= 0:
			var cell = _cell_under_mouse()
			var cls = room_mgr.get_entry(_room_editing_index)
			if building_mgr.has_index(cls.building_index) and cell in building_mgr.get_entry(cls.building_index).cells and cell not in construction.editing_cells:
				if corridor_mgr.get_at_cell(cell) >= 0:
					renderer.update_hover(pos, Color(1, 0.65, 0, 0.6))
				else:
					renderer.update_hover(pos, Color(0.3, 0.8, 0.3, 0.55))
			else:
				renderer.update_hover(pos, Color(1, 0.3, 0.3, 0.55))
		elif corridor_mgr.is_item(construction.active_item_name):
			var cell = _cell_under_mouse()
			room_mgr.clear_hover_tile()
			_clear_hover_door_preview()
			var b_idx = building_mgr.get_at_cell(cell)
			if b_idx >= 0 and room_mgr.get_at_cell(cell) < 0 and corridor_mgr.get_at_cell(cell) < 0:
				renderer.update_hover(pos, Color(0.4, 0.85, 0.5, 0.5))
				if construction.current_state == ConstructionState.State.IDLE:
					corridor_mgr.update_hover_tile(cell)
				else:
					corridor_mgr.clear_hover_tile()
			else:
				renderer.update_hover(pos, Color(1, 0.3, 0.3, 0.55))
				corridor_mgr.clear_hover_tile()
		elif door_mgr.is_item(construction.active_item_name):
			var cell = _cell_under_mouse()
			var info = door_mgr.get_valid_placement(cell)
			if info.valid:
				renderer.update_hover(pos, Color(1, 0.85, 0, 0.5))
				room_mgr.clear_hover_tile()
				renderer.show_door_hover(cell)
				if construction.current_state == ConstructionState.State.IDLE:
					_hover_door_preview(cell, info.edge_normal)
				else:
					_clear_hover_door_preview()
			else:
				renderer.update_hover(pos, Color(1, 0.3, 0.3, 0.55))
				renderer.hide_door_hover()
				_clear_hover_door_preview()
		else:
			var occ = building_mgr.get_occupied_cells(camera.current_floor)
			var color = Color(1, 0.3, 0.3, 0.35) if pos in occ else Color(1, 1, 1, 0.2)
			renderer.update_hover(pos, color)
	elif mode == GlobalTransferData.GameMode.BULLDOZER:
		_clear_hover_door_preview()

func _cell_under_mouse() -> Vector2i:
	return field_layer.local_to_map(field_layer.get_local_mouse_position())

func _corner_under_mouse() -> Vector2i:
	var local_pos = field_layer.get_local_mouse_position()
	return Vector2i(roundi(local_pos.x / TILE_SIZE), roundi(local_pos.y / TILE_SIZE))

func _clear_hover_room_tile() -> void:
	room_mgr.clear_hover_tile()

func _update_hover_room_tile(cell: Vector2i) -> void:
	var room_type = construction.active_item_name
	room_mgr.update_hover_tile(cell, room_type)

func _clear_hover_door_preview() -> void:
	renderer.hide_door_hover()
	_door_placement_preview_node.visible = false
	renderer.clear_preview_container(_door_placement_preview_node)

func _hover_door_preview(cell: Vector2i, edge_normal: Vector2i) -> void:
	_clear_hover_door_preview()
	_door_placement_preview_node.visible = true
	renderer.draw_edge_preview(cell, edge_normal, _door_placement_preview_node)

func _reset_door_replacement_state() -> void:
	renderer.clear_preview_container(_door_placement_preview_node)

func get_room_mgr():
	return room_mgr

func set_active_placement_item(item_name: String) -> void:
	_clear_hover_door_preview()
	corridor_mgr.clear_hover_tile()
	_reset_door_replacement_state()
	construction.set_active_item(item_name)
	if corridor_mgr.is_item(item_name):
		construction.current_tool = "tiles"

func set_placement_tool(tool_name: String) -> void:
	construction.current_tool = tool_name

func cancel_placement() -> void:
	if _room_placement_building_index >= 0:
		var cells = construction.painted_preview_cells if construction.current_state == ConstructionState.State.DRAGGING else construction.staged_cells
		var room_type = construction.active_item_name
		var cancel_layer = principal_office_layer if room_type == "Principal Office" and principal_office_layer else classroom_layer
		for cell in cells:
			cancel_layer.erase_cell(cell)
	if corridor_mgr.is_item(construction.active_item_name):
		var cells = construction.painted_preview_cells if construction.current_state == ConstructionState.State.DRAGGING else construction.staged_cells
		for cell in cells:
			corridor_layer.erase_cell(cell)
	_room_placement_building_index = -1
	room_mgr.clear_hover_tile()
	if construction.current_state == ConstructionState.State.DRAGGING:
		construction.clear_preview_cells()
		construction.current_state = ConstructionState.State.IDLE
	elif construction.current_state == ConstructionState.State.PENDING_APPROVAL:
		construction.clear_staged(true)
	_remove_confirmation_widget()

func _cancel_any_active_edit() -> void:
	if construction.current_state == ConstructionState.State.EDITING:
		if _is_door_edit:
			_cancel_door_edit()
		elif _is_corridor_edit:
			_cancel_corridor_edit()
		elif _is_room_edit:
			_cancel_room_edit()
		else:
			_cancel_building_edit()
	elif construction.current_state in [ConstructionState.State.DRAGGING, ConstructionState.State.PENDING_APPROVAL]:
		cancel_placement()

func _on_game_mode_changed(new_mode: GlobalTransferData.GameMode) -> void:
	_is_bulldozing = false
	blueprint_grid_layer.visible = false
	_cancel_any_active_edit()
	room_mgr.clear_hover_tile()
	corridor_mgr.clear_hover_tile()
	_clear_hover_door_preview()
	for i in range(building_mgr.size()):
		var b = building_mgr.get_entry(i)
		for cell in b.cells:
			var atlas_coord = Vector2i(3, 0) if new_mode == GlobalTransferData.GameMode.GAME else Vector2i(1, 0)
			field_layer.set_cell(cell, 0, atlas_coord)
	if principal_office_layer:
		principal_office_layer.clear()
		for i in range(room_mgr.size()):
			var cls = room_mgr.get_entry(i)
			if cls.room_type == "Principal Office":
				for cell in cls.cells:
					classroom_layer.erase_cell(cell)
	for i in range(room_mgr.size()):
		var cls = room_mgr.get_entry(i)
		var atlas = room_mgr.get_atlas_for_room(cls.room_type)
		var redraw_layer = principal_office_layer if cls.room_type == "Principal Office" and principal_office_layer else classroom_layer
		for cell in cls.cells:
			redraw_layer.set_cell(cell, 0, atlas)
	match new_mode:
		GlobalTransferData.GameMode.GAME:
			field_layer.modulate = Color.WHITE
			classroom_layer.modulate = Color.WHITE
			corridor_layer.modulate = Color(0.75, 0.75, 0.75, 1.0)
			construction.clear_staged(false)
			confirmed_container.visible = false
		GlobalTransferData.GameMode.ARCHITECTURAL:
			field_layer.modulate = Color("#3057e1")
			classroom_layer.modulate = Color.WHITE
			corridor_layer.modulate = Color(0.8, 0.8, 0.8, 1.0)
			blueprint_grid_layer.visible = true
			confirmed_container.visible = true
		GlobalTransferData.GameMode.MANAGEMENT:
			field_layer.modulate = Color("#475569")
			classroom_layer.modulate = Color.WHITE
			corridor_layer.modulate = Color(0.75, 0.75, 0.75, 1.0)
			construction.clear_staged(false)
			confirmed_container.visible = false
		GlobalTransferData.GameMode.BULLDOZER:
			field_layer.modulate = Color("#991b1b")
			classroom_layer.modulate = Color.WHITE
			corridor_layer.modulate = Color(0.75, 0.75, 0.75, 1.0)
			blueprint_grid_layer.visible = true
			confirmed_container.visible = false
	if confirmed_container.visible:
		_update_confirmed_visuals()

func _input(event: InputEvent) -> void:
	input_handler.handle_input(event)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if GlobalTransferData.current_mode == GlobalTransferData.GameMode.BULLDOZER:
			if event.button_index == MOUSE_BUTTON_LEFT:
				var cell = _cell_under_mouse()
				if event.pressed:
					_bulldoze_cell(cell)
					_last_bulldoze_cell = cell
					_is_bulldozing = true
				else:
					_is_bulldozing = false
			return

		if GlobalTransferData.current_mode != GlobalTransferData.GameMode.ARCHITECTURAL:
			return

		var use_cell = construction.current_tool == "tiles"
		var pos = _cell_under_mouse() if use_cell else _corner_under_mouse()

		if use_cell:
			if not Rect2i(0, 0, GRID_SIZE, GRID_SIZE).has_point(pos):
				return
		else:
			if pos.x < 0 or pos.x > GRID_SIZE or pos.y < 0 or pos.y > GRID_SIZE:
				return

		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_handle_left_click_pressed(pos, use_cell)
		elif event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and construction.current_state == ConstructionState.State.DRAGGING:
			_handle_left_click_released(pos, use_cell, event)
		if event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			get_viewport().set_input_as_handled()
			return
		if GlobalTransferData.current_mode == GlobalTransferData.GameMode.ARCHITECTURAL:
			_handle_arch_click(pos, use_cell)

func _handle_left_click_pressed(pos: Vector2i, use_cell: bool) -> void:
	if _is_door_edit and _door_editing_index >= 0 and use_cell:
		var cell = _cell_under_mouse()
		if Rect2i(0, 0, GRID_SIZE, GRID_SIZE).has_point(cell):
			_relocate_door_to(cell)
			get_viewport().set_input_as_handled()
			return

	if construction.current_state == ConstructionState.State.EDITING:
		var cell = _cell_under_mouse()
		var bounds = Rect2i(0, 0, GRID_SIZE, GRID_SIZE)
		if use_cell and bounds.has_point(cell):
			if _editing_action == "add_delete":
				if _is_room_edit and _room_editing_index >= 0:
					var cls = room_mgr.get_entry(_room_editing_index)
					if building_mgr.has_index(cls.building_index) and cell not in building_mgr.get_entry(cls.building_index).cells:
						get_viewport().set_input_as_handled()
						return
				construction.toggle_edit_cell(cell)
			_update_confirmed_visuals()
			get_viewport().set_input_as_handled()
			return
	if not use_cell and _editing_action == "move_rotate":
		construction.blocked_cells = building_mgr.get_all_cells_except(construction.editing_building_index) if construction.editing_building_index >= 0 else building_mgr.get_occupied_cells(camera.current_floor)
		construction.start_drag(pos)
		get_viewport().set_input_as_handled()

func _handle_left_click_released(pos: Vector2i, use_cell: bool, event: InputEvent) -> void:
	if _room_placement_building_index >= 0:
		construction.blocked_cells = room_mgr.get_blocked_cells(_room_placement_building_index, _room_editing_index if _is_room_edit else -1)
		if construction.active_item_name == "Principal Office":
			var admin_idx = room_mgr.get_admin_area_in_building(_room_placement_building_index)
			if admin_idx >= 0:
				for c in room_mgr.get_entry(admin_idx).cells:
					var idx = construction.blocked_cells.find(c)
					if idx >= 0:
						construction.blocked_cells.remove_at(idx)
	elif corridor_mgr.is_item(construction.active_item_name):
		construction.blocked_cells = corridor_mgr.get_blocked_cells(-1, camera.current_floor)
	else:
		construction.blocked_cells = building_mgr.get_all_cells_except(construction.editing_building_index) if construction.editing_building_index >= 0 else building_mgr.get_occupied_cells(camera.current_floor)
	if construction.current_tool in ["move", "rotate", "move_rotate"] and construction.editing_building_index >= 0:
		var offset = construction.drag_end_cell - construction.drag_start_cell
		if offset == Vector2i.ZERO:
			construction.current_state = ConstructionState.State.EDITING
			return
		var other_cells = building_mgr.get_all_cells_except(construction.editing_building_index)
		if construction.move_cells(offset, other_cells).is_empty():
			construction.begin_edit(construction.editing_building_index, building_mgr.get_entry(construction.editing_building_index).cells)
			hud_message("Cannot place here - blocked")
		else:
			_building_edit_translation += offset
			if _is_room_edit and _room_editing_index >= 0:
				var cls = room_mgr.get_entry(_room_editing_index)
				var all_inside = true
				if building_mgr.has_index(cls.building_index):
					var building_cells = building_mgr.get_entry(cls.building_index).cells
					for cell in construction.editing_cells:
						if cell not in building_cells:
							all_inside = false
							break
				else:
					all_inside = false
				if not all_inside:
					construction.begin_edit(cls.building_index, cls.cells)
					_building_edit_original_cells = cls.cells.duplicate()
					_building_edit_centroid = MapUtils.calc_centroid(cls.cells)
					_building_edit_rotation_count = 0
					_building_edit_translation = Vector2i.ZERO
					hud_message("Classroom must stay inside building")
		construction.current_state = ConstructionState.State.EDITING
		_update_confirmed_visuals()
	else:
		construction.end_drag(pos)
		_update_confirmed_visuals()
		if construction.current_state == ConstructionState.State.EDITING:
			_room_placement_building_index = -1
			return
		if construction.current_state != ConstructionState.State.PENDING_APPROVAL:
			_room_placement_building_index = -1
			return
		_spawn_confirmation_widget(event.global_position)

func _handle_arch_click(pos: Vector2i, use_cell: bool) -> void:
	var cell = _cell_under_mouse()
	var door_idx = door_mgr.get_at_cell(cell)
	if door_idx >= 0 and construction.current_state == ConstructionState.State.IDLE:
		if not door_mgr.is_item(construction.active_item_name) or door_mgr.get_valid_placement(cell).valid == false:
			_start_door_edit(door_idx)
			get_viewport().set_input_as_handled()
			return
	if door_mgr.is_item(construction.active_item_name) and construction.current_state == ConstructionState.State.IDLE:
		var info = door_mgr.get_valid_placement(cell)
		if info.valid:
			start_door_placement(cell)
		get_viewport().set_input_as_handled()
		return
	var corridor_idx = corridor_mgr.get_at_cell(cell)
	if corridor_idx >= 0 and construction.current_state == ConstructionState.State.IDLE and not corridor_mgr.is_item(construction.active_item_name):
		_start_corridor_edit(corridor_idx)
		get_viewport().set_input_as_handled()
		return
	var building_idx = building_mgr.get_at_cell(cell)
	if building_idx >= 0:
		var can_edit = construction.current_state in [ConstructionState.State.IDLE, ConstructionState.State.PENDING_APPROVAL]
		if can_edit and not _is_room_item(construction.active_item_name) and not corridor_mgr.is_item(construction.active_item_name):
			var room_idx = room_mgr.get_at_cell(cell)
			if room_idx >= 0:
				_start_room_edit(room_idx)
			else:
				_start_building_edit(building_idx)
			get_viewport().set_input_as_handled()
			return
	if construction.current_state == ConstructionState.State.PENDING_APPROVAL:
		return
	if construction.current_state == ConstructionState.State.IDLE:
		if construction.active_item_name == "":
			return
		if _is_room_item(construction.active_item_name):
			var existing = room_mgr.get_at_cell(cell)
			if existing >= 0:
				var existing_type = room_mgr.get_entry(existing).room_type
				if construction.active_item_name == "Principal Office" and existing_type == "Administration Area" and not room_mgr.has_principal_office():
					pass
				else:
					_start_room_edit(existing)
					get_viewport().set_input_as_handled()
					return
			building_idx = building_mgr.get_at_cell(cell)
			if building_idx < 0:
				hud_message("Select a building to add a room.")
				return
			if construction.active_item_name == "Principal Office":
				if room_mgr.has_principal_office():
					hud_message("Only one Principal Office is allowed.")
					return
				if room_mgr.get_admin_area_in_building(building_idx) < 0:
					hud_message("Principal Office must be placed inside an Administration Area.")
					return
			_start_room_placement(building_idx, cell)
			get_viewport().set_input_as_handled()
			return
		if corridor_mgr.is_item(construction.active_item_name):
			var click_cell = _cell_under_mouse()
			var existing = corridor_mgr.get_at_cell(click_cell)
			if existing >= 0:
				_start_corridor_edit(existing)
				get_viewport().set_input_as_handled()
				return
			building_idx = building_mgr.get_at_cell(click_cell)
			if building_idx < 0:
				hud_message("Select a building to add a corridor.")
				return
			if room_mgr.get_at_cell(click_cell) >= 0:
				hud_message("Cannot place corridor inside a room.")
				return
			construction.blocked_cells = corridor_mgr.get_blocked_cells(-1, camera.current_floor)
			if click_cell in construction.blocked_cells:
				hud_message("Cannot place corridor here - already occupied or outside building")
				return
			construction.start_drag(click_cell)
			hud_message("Drag to paint corridor tiles inside the building, right-click to remove")
			get_viewport().set_input_as_handled()
			return
		construction.blocked_cells = building_mgr.get_occupied_cells(camera.current_floor)
		if use_cell and pos in construction.blocked_cells:
			return
		construction.start_drag(pos)

func _process_construction_input() -> void:
	if GlobalTransferData.current_mode != GlobalTransferData.GameMode.ARCHITECTURAL:
		return
	if construction.is_staging():
		return
	if construction.current_state == ConstructionState.State.EDITING and construction.current_tool == "tiles":
		if _is_corridor_edit:
			var b_idx = corridor_mgr.get_entry(_corridor_editing_index).building_index if _corridor_editing_index >= 0 and corridor_mgr.has_index(_corridor_editing_index) else -1
			construction.blocked_cells = corridor_mgr.get_blocked_cells(_corridor_editing_index, camera.current_floor) if b_idx >= 0 else building_mgr.get_occupied_cells(camera.current_floor)
		elif _is_room_edit:
			var cls = room_mgr.get_entry(_room_editing_index) if _room_editing_index >= 0 and room_mgr.has_index(_room_editing_index) else null
			if cls and building_mgr.has_index(cls.building_index):
				construction.blocked_cells = building_mgr.get_all_cells_except(cls.building_index)
				for i in range(room_mgr.size()):
					if i != _room_editing_index and room_mgr.get_entry(i).building_index == cls.building_index:
						construction.blocked_cells.append_array(room_mgr.get_entry(i).cells)
			else:
				construction.blocked_cells = building_mgr.get_occupied_cells(camera.current_floor)
		else:
			construction.blocked_cells = building_mgr.get_all_cells_except(construction.editing_building_index) if construction.editing_building_index >= 0 else building_mgr.get_occupied_cells(camera.current_floor)
		var pos = _cell_under_mouse()
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and _editing_action in ["add", "add_delete"]:
			var bounds = Rect2i(0, 0, GRID_SIZE, GRID_SIZE)
			if bounds.has_point(pos) and not pos in construction.editing_cells and not pos in construction.blocked_cells:
				if _is_room_edit and _room_editing_index >= 0:
					var cls = room_mgr.get_entry(_room_editing_index)
					if building_mgr.has_index(cls.building_index) and pos not in building_mgr.get_entry(cls.building_index).cells:
						return
				if _is_corridor_edit and _corridor_editing_index >= 0:
					var corr = corridor_mgr.get_entry(_corridor_editing_index)
					if building_mgr.has_index(corr.building_index) and pos not in building_mgr.get_entry(corr.building_index).cells:
						return
				construction.add_edit_cell(pos)
				_update_confirmed_visuals()
		return
	if construction.current_state == ConstructionState.State.DRAGGING:
		if _room_placement_building_index >= 0:
			construction.blocked_cells = room_mgr.get_blocked_cells(_room_placement_building_index, _room_editing_index if _is_room_edit else -1)
			if construction.active_item_name == "Principal Office":
				var admin_idx = room_mgr.get_admin_area_in_building(_room_placement_building_index)
				if admin_idx >= 0:
					for c in room_mgr.get_entry(admin_idx).cells:
						var idx = construction.blocked_cells.find(c)
						if idx >= 0:
							construction.blocked_cells.remove_at(idx)
		elif corridor_mgr.is_item(construction.active_item_name):
			construction.blocked_cells = corridor_mgr.get_blocked_cells(-1, camera.current_floor)
		else:
			construction.blocked_cells = building_mgr.get_all_cells_except(construction.editing_building_index) if construction.editing_building_index >= 0 else building_mgr.get_occupied_cells(camera.current_floor)
		var use_cell = construction.current_tool == "tiles"
		var pos = _cell_under_mouse() if use_cell else _corner_under_mouse()
		if pos != construction.drag_end_cell:
			construction.drag_end_cell = pos
			if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and use_cell:
				var bounds = Rect2i(0, 0, GRID_SIZE, GRID_SIZE)
				if _room_placement_building_index >= 0:
					var building = building_mgr.get_entry(_room_placement_building_index)
					if pos not in building.cells:
						construction.render_preview()
						return
					var x_min = mini(construction.drag_start_cell.x, pos.x)
					var x_max = maxi(construction.drag_start_cell.x, pos.x)
					var y_min = mini(construction.drag_start_cell.y, pos.y)
					var y_max = maxi(construction.drag_start_cell.y, pos.y)
					var admin_cells: Array[Vector2i] = []
					if construction.active_item_name == "Principal Office":
						var admin_idx = room_mgr.get_admin_area_in_building(_room_placement_building_index)
						if admin_idx >= 0:
							admin_cells = room_mgr.get_entry(admin_idx).cells
					var new_painted: Array[Vector2i] = []
					for x in range(x_min, x_max + 1):
						for y in range(y_min, y_max + 1):
							var c = Vector2i(x, y)
							if c in building.cells and c not in construction.blocked_cells:
								if admin_cells.size() > 0 and c not in admin_cells:
									continue
								new_painted.append(c)
					var paint_atlas = room_mgr.get_atlas_for_room(construction.active_item_name)
					var paint_layer = principal_office_layer if construction.active_item_name == "Principal Office" and principal_office_layer else classroom_layer
					for cell in construction.painted_preview_cells:
						if cell not in new_painted:
							paint_layer.erase_cell(cell)
					for cell in new_painted:
						if cell not in construction.painted_preview_cells:
							paint_layer.set_cell(cell, 0, paint_atlas)
					construction.painted_preview_cells = new_painted
					construction.render_preview()
					return
				if corridor_mgr.is_item(construction.active_item_name) and _room_placement_building_index < 0:
					var x_min = mini(construction.drag_start_cell.x, pos.x)
					var x_max = maxi(construction.drag_start_cell.x, pos.x)
					var y_min = mini(construction.drag_start_cell.y, pos.y)
					var y_max = maxi(construction.drag_start_cell.y, pos.y)
					var new_painted: Array[Vector2i] = []
					for x in range(x_min, x_max + 1):
						for y in range(y_min, y_max + 1):
							var c = Vector2i(x, y)
							if c not in construction.blocked_cells and bounds.has_point(c):
								new_painted.append(c)
					for cell in construction.painted_preview_cells:
						if cell not in new_painted:
							corridor_layer.erase_cell(cell)
					for cell in new_painted:
						if cell not in construction.painted_preview_cells:
							corridor_layer.set_cell(cell, 0, Vector2i(1, 0))
					construction.painted_preview_cells = new_painted
					construction.render_preview()
					return
				if not pos in construction.painted_preview_cells and not pos in construction.blocked_cells and bounds.has_point(pos):
					construction.painted_preview_cells.append(pos)
					construction.render_preview()
		else:
				construction.render_preview()
				if construction.editing_building_index >= 0 and _building_edit_original_cells.size() > 0:
					var offset = construction.drag_end_cell - construction.drag_start_cell
					_update_building_edit_room_preview(offset)

func _start_room_placement(building_idx: int, cell: Vector2i) -> void:
	_room_placement_building_index = building_idx
	_editing_action = "room_add"
	construction.current_tool = "tiles"
	construction.blocked_cells = room_mgr.get_blocked_cells(building_idx)
	var room_type = construction.active_item_name
	if room_type == "Principal Office":
		var admin_idx = room_mgr.get_admin_area_in_building(building_idx)
		if admin_idx >= 0:
			for c in room_mgr.get_entry(admin_idx).cells:
				var idx = construction.blocked_cells.find(c)
				if idx >= 0:
					construction.blocked_cells.remove_at(idx)
	var atlas = room_mgr.get_atlas_for_room(room_type)
	var layer = principal_office_layer if room_type == "Principal Office" and principal_office_layer else classroom_layer
	layer.set_cell(cell, 0, atlas)
	construction.start_drag(cell)
	if construction.current_state != ConstructionState.State.DRAGGING:
		layer.erase_cell(cell)
	if room_type == "Principal Office":
		hud_message("Drag inside the Administration Area to define Principal Office.")
	elif room_type == "Administration Area":
		hud_message("Drag inside the building to define Administration Area.")
	else:
		hud_message("Drag inside the building to add tiles.")

func _confirm_room_placement() -> void:
	var room_type = construction.active_item_name
	var default_name = room_mgr.default_name(room_type)
	var building_idx = _room_placement_building_index
	if room_type == "Principal Office":
		var cells = construction.staged_cells.duplicate()
		var admin_idx = room_mgr.get_admin_area_in_building(building_idx)
		if admin_idx < 0:
			hud_message("Principal Office must be inside an Administration Area.")
			return
		var admin_cells = room_mgr.get_entry(admin_idx).cells
		for c in cells:
			if c not in admin_cells:
				hud_message("All Principal Office tiles must be inside an Administration Area.")
				return
		_add_room_label(default_name, cells, building_idx, room_type)
		room_mgr.set_principal_office_placed(true)
		construction.staged_cells.clear()
		construction.current_state = ConstructionState.State.IDLE
		_remove_confirmation_widget()
		_room_placement_building_index = -1
		var hud = find_child("InGameHUD", true, false) as CanvasLayer
		if hud and hud.has_method("disable_principal_office_button"):
			hud.disable_principal_office_button(true)
		return
	room_mgr.increment_counter(room_type)
	var hud = find_child("InGameHUD", true, false) as CanvasLayer
	if hud and hud.has_method("show_building_rename_dialog"):
		hud.show_building_rename_dialog(default_name, func(confirmed: bool, name: String):
			if not confirmed:
				return
			var cells = construction.staged_cells.duplicate()
			_add_room_label(name, cells, building_idx, room_type)
			construction.staged_cells.clear()
			construction.current_state = ConstructionState.State.IDLE
			_remove_confirmation_widget()
			_room_placement_building_index = -1
		)
	else:
		var cells = construction.staged_cells.duplicate()
		_add_room_label(default_name, cells, building_idx, room_type)
		construction.staged_cells.clear()
		construction.current_state = ConstructionState.State.IDLE
		_remove_confirmation_widget()
		_room_placement_building_index = -1

func _add_room_label(name: String, cells: Array[Vector2i], building_idx: int, room_type: String) -> void:
	var label = _create_room_label(name)
	var offset_y = 36 if room_type == "Principal Office" else -36
	MapUtils.position_label(label, cells, offset_y)
	room_mgr.add(name, cells, building_idx, room_type, label)

func _create_room_label(name: String) -> Label:
	var label = Label.new()
	label.text = name
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color", Color(0, 0, 0, 1))
	label.add_theme_color_override("font_shadow_color", Color(1, 1, 1, 0.6))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.add_theme_font_size_override("font_size", 26)
	return label

func _add_building_label(name: String, cells: Array[Vector2i], floor_level: int = 0) -> void:
	var label = Label.new()
	label.text = name
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color", Color(0.05, 0.05, 0.1))
	label.add_theme_color_override("font_shadow_color", Color(1, 1, 1, 0.6))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.add_theme_font_size_override("font_size", 30)
	label = label
	building_mgr.add(name, cells, floor_level, label)
	MapUtils.position_label(label, cells, 0.0)

func confirm_staged_placement() -> void:
	if _room_placement_building_index >= 0:
		_confirm_room_placement()
		return
	if corridor_mgr.is_item(construction.active_item_name):
		_confirm_corridor_placement()
		return
	building_mgr.counter += 1
	var default_name = "Building %d" % building_mgr.counter
	var current_floor = camera.current_floor
	var atlas = building_mgr.atlas_coord()
	var hud = find_child("InGameHUD", true, false) as CanvasLayer
	if hud and hud.has_method("show_building_rename_dialog"):
		hud.show_building_rename_dialog(default_name, func(confirmed: bool, name: String):
			if not confirmed:
				return
			var cells = construction.staged_cells.duplicate()
			construction.confirm_placement(atlas)
			_add_building_label(name, cells, current_floor)
			_remove_confirmation_widget()
		)
	else:
		var cells = construction.staged_cells.duplicate()
		construction.confirm_placement(atlas)
		_add_building_label(default_name, cells, current_floor)
		_remove_confirmation_widget()

func continue_staged_placement() -> void:
	construction.continue_adding()
	_remove_confirmation_widget()

func redrag_staged_placement() -> void:
	if corridor_mgr.is_item(construction.active_item_name):
		for cell in construction.staged_cells:
			corridor_layer.erase_cell(cell)
	construction.clear_staged(true)
	_remove_confirmation_widget()

func _spawn_confirmation_widget(spawn_pos: Vector2) -> void:
	var hud = find_child("InGameHUD", true, false) as CanvasLayer
	if hud and hud.has_method("display_floating_approval_bubble"):
		hud.display_floating_approval_bubble(spawn_pos, self)

func _remove_confirmation_widget() -> void:
	var hud = find_child("InGameHUD", true, false) as CanvasLayer
	if hud and hud.has_method("dismiss_floating_approval_bubble"):
		hud.dismiss_floating_approval_bubble()

func _is_room_item(item_name: String) -> bool:
	return item_name == "Classroom" or item_name == "Male Student Washroom" or item_name == "Female Student Washroom" or item_name == "Administration Area" or item_name == "Principal Office" or item_name == "Cafeteria"

func _is_door_item(item_name: String) -> bool:
	return door_mgr.is_item(item_name)

func _toggle_door_direction() -> void:
	var cell = _cell_under_mouse()
	var info = door_mgr.get_valid_placement(cell)
	if info.valid:
		door_mgr.toggle_direction()
		_clear_hover_door_preview()
		renderer.show_door_hover(cell)
		_door_placement_preview_node.visible = true
		renderer.draw_edge_preview(cell, info.edge_normal, _door_placement_preview_node)
		_hover_door_cell = cell

var _hover_door_cell: Vector2i = Vector2i(-999, -999)

func start_door_placement(cell: Vector2i) -> void:
	var info = door_mgr.get_valid_placement(cell)
	if not info.valid:
		return
	door_mgr.counter += 1
	var name = "Door #%d" % door_mgr.counter
	_clear_hover_door_preview()
	door_mgr.finalize(name, cell, info.edge_normal, door_mgr.get_direction(), info.building_index, info.room_index)
	hud_message("Placed %s" % name)

func _start_door_edit(index: int) -> void:
	_close_edit_dialog()
	var door = door_mgr
	_is_door_edit = true
	_door_editing_index = index
	_building_edit_dialog = BuildingEditDialog.new()
	_building_edit_dialog.show(
		self,
		door.get_entry(index).name,
		_on_door_edit_action,
		_confirm_door_edit,
		_cancel_door_edit,
		"door"
	)
	hud_message("Editing %s" % door.get_entry(index).name)

func _on_door_edit_action(action: String) -> void:
	match action:
		"add_delete":
			hud_message("Doors are single-tile; use Move/Rotate to relocate")
		"move_rotate":
			_editing_action = "move_rotate"
			construction.current_tool = "tiles"
			construction.render_preview()
			hud_message("Click a valid edge tile to move the door, middle-click to toggle direction")
		"rename":
			_rename_door()
		"demolish":
			_demolish_door()

func _confirm_door_edit() -> void:
	_editing_action = ""
	construction.blocked_cells.clear()
	_reset_door_replacement_state()
	_is_door_edit = false
	_door_editing_index = -1
	door_mgr.redraw_all()
	_update_confirmed_visuals()
	_close_edit_dialog()

func _cancel_door_edit() -> void:
	_editing_action = ""
	construction.blocked_cells.clear()
	_reset_door_replacement_state()
	if _door_editing_index >= 0 and _door_editing_index < door_mgr.size():
		var door = door_mgr.get_entry(_door_editing_index)
		door_mgr.redraw(door)
	_is_door_edit = false
	_door_editing_index = -1
	_close_edit_dialog()

func _rename_door() -> void:
	var idx = _door_editing_index
	if idx < 0 or idx >= door_mgr.size():
		return
	var door = door_mgr.get_entry(idx)
	var hud = find_child("InGameHUD", true, false) as CanvasLayer
	if hud and hud.has_method("show_building_rename_dialog"):
		hud.show_building_rename_dialog(door.name, func(confirmed: bool, new_name: String):
			if not confirmed:
				return
			door_mgr.rename(idx, new_name)
		)

func _demolish_door() -> void:
	var idx = _door_editing_index
	if idx < 0 or idx >= door_mgr.size():
		return
	_do_demolish_door(idx)

func _do_demolish_door(idx: int) -> void:
	if idx >= door_mgr.size():
		return
	_is_door_edit = false
	_door_editing_index = -1
	var door = door_mgr.get_entry(idx)
	door_mgr.remove(idx)
	_reset_door_replacement_state()
	_close_edit_dialog()
	door_mgr.redraw_all()
	_update_confirmed_visuals()

func _relocate_door_to(cell: Vector2i) -> void:
	var idx = _door_editing_index
	if idx < 0 or idx >= door_mgr.size():
		return
	var door = door_mgr.get_entry(idx)
	if cell == door.cell:
		return
	var info = door_mgr.get_valid_placement(cell)
	if not info.valid:
		hud_message("Door must be placed at the edge of a building or room")
		return
	door_mgr.clear_visual(door)
	door.cell = cell
	door.edge_normal = info.edge_normal
	door.building_index = info.building_index
	door.room_index = info.room_index
	door_mgr.redraw(door)
	_update_confirmed_visuals()
	_reset_door_replacement_state()

func _bulldoze_cell(cell: Vector2i) -> void:
	if cell.x < 0 or cell.x >= GRID_SIZE or cell.y < 0 or cell.y >= GRID_SIZE + 2:
		return
	for i in range(room_mgr.size() - 1, -1, -1):
		var cls = room_mgr.get_entry(i)
		var idx = cls.cells.find(cell)
		if idx >= 0:
			var erase_layer = principal_office_layer if cls.room_type == "Principal Office" and principal_office_layer else classroom_layer
			erase_layer.erase_cell(cell)
			cls.cells.remove_at(idx)
			if cls.cells.is_empty():
				cls.label.queue_free()
				room_mgr.remove(i)
			return
	field_layer.set_cell(cell, 0, Vector2i(0, 0))
	for child in confirmed_container.get_children():
		var rect := child as ColorRect
		if rect and rect.position == Vector2(cell.x * TILE_SIZE, cell.y * TILE_SIZE):
			confirmed_container.remove_child(rect)
			rect.queue_free()
	for i in range(building_mgr.size() - 1, -1, -1):
		var b = building_mgr.get_entry(i)
		var idx = b.cells.find(cell)
		if idx >= 0:
			b.cells.remove_at(idx)
			if b.cells.is_empty():
				b.label.queue_free()
				building_mgr.remove(i)
			break

func _start_building_edit(index: int) -> void:
	_close_edit_dialog()
	var b = building_mgr.get_entry(index)
	_building_edit_original_cells = b.cells.duplicate()
	_building_edit_room_entries.clear()
	for i in range(room_mgr.size()):
		var cls = room_mgr.get_entry(i)
		if cls.building_index == index:
			_building_edit_room_entries.append({"original_cells": cls.cells.duplicate(), "ref": cls, "prev_preview_cells": []})
	_building_edit_cleared_originals = false
	_building_edit_rotation_count = 0
	_building_edit_centroid = MapUtils.calc_centroid(b.cells)
	_building_edit_translation = Vector2i.ZERO
	construction.begin_edit(index, b.cells)
	_editing_action = ""
	_is_room_edit = false
	_room_editing_index = -1
	_is_corridor_edit = false
	_corridor_editing_index = -1
	_update_confirmed_visuals()

	_building_edit_dialog = BuildingEditDialog.new()
	_building_edit_dialog.show(
		self,
		b.name,
		_on_edit_action,
		_confirm_building_edit,
		_cancel_building_edit
	)
	hud_message("Editing %s" % b.name)

func _on_edit_action(action: String) -> void:
	_editing_action = action
	match action:
		"add_delete":
			_building_edit_original_cells = construction.editing_cells.duplicate()
			_building_edit_centroid = MapUtils.calc_centroid(construction.editing_cells)
			_building_edit_rotation_count = 0
			_building_edit_translation = Vector2i.ZERO
			construction.current_tool = "tiles"
			construction.blocked_cells = building_mgr.get_all_cells_except(construction.editing_building_index) if construction.editing_building_index >= 0 else building_mgr.get_occupied_cells(camera.current_floor)
			construction.render_preview()
			construction.painted_preview_cells.clear()
			hud_message("Left-click to add tiles, right-click to delete.")
		"move_rotate":
			_building_edit_original_cells = construction.editing_cells.duplicate()
			_building_edit_centroid = MapUtils.calc_centroid(construction.editing_cells)
			_building_edit_rotation_count = 0
			_building_edit_translation = Vector2i.ZERO
			construction.current_tool = "move_rotate"
			construction.render_preview()
			hud_message("Left-click & drag to move, middle-click to rotate.")
		"rename":
			_rename_building()
		"demolish":
			_demolish_building()

func _rename_building() -> void:
	var idx = construction.editing_building_index
	if idx < 0 or idx >= building_mgr.size():
		return
	var b = building_mgr.get_entry(idx)
	var hud = find_child("InGameHUD", true, false) as CanvasLayer
	if hud and hud.has_method("show_building_rename_dialog"):
		hud.show_building_rename_dialog(b.name, func(confirmed: bool, new_name: String):
			if not confirmed:
				return
			building_mgr.rename(idx, new_name)
			building_mgr.update_label_position(idx)
		)

func _demolish_building() -> void:
	var idx = construction.editing_building_index
	if idx < 0 or idx >= building_mgr.size():
		return
	_do_demolish(idx)

func _do_demolish(idx: int) -> void:
	if idx >= building_mgr.size():
		return
	var b = building_mgr.get_entry(idx)
	for cell in b.cells:
		field_layer.set_cell(cell, 0, Vector2i(0, 0))
	b.label.queue_free()
	door_mgr.remove_for_building(idx)
	var i = 0
	while i < room_mgr.size():
		var cls = room_mgr.get_entry(i)
		if cls.building_index == idx:
			cls.label.queue_free()
			room_mgr.clear_tiles(cls.cells, cls.room_type)
			room_mgr.remove(i)
		else:
			if cls.building_index > idx:
				cls.building_index -= 1
			i += 1
	i = 0
	while i < corridor_mgr.size():
		var corr = corridor_mgr.get_entry(i)
		if corr.building_index == idx:
			corridor_mgr.clear_tiles(corr.cells)
			corridor_mgr.remove(i)
		else:
			if corr.building_index > idx:
				corr.building_index -= 1
			i += 1
	building_mgr.remove(idx)
	construction.blocked_cells.clear()
	construction.cancel_edit()
	_close_edit_dialog()
	renderer.update_edge_lines()
	_update_confirmed_visuals()

func _confirm_building_edit() -> void:
	_editing_action = ""
	construction.blocked_cells.clear()
	if construction.editing_building_index == -1:
		return
	var idx = construction.editing_building_index
	var final_cells = construction.apply_edit()
	var old_cells = building_mgr.get_entry(idx).cells
	var atlas = building_mgr.atlas_coord()
	for cell in old_cells:
		field_layer.set_cell(cell, 0, Vector2i(0, 0))
	for cell in final_cells:
		field_layer.set_cell(cell, 0, atlas)
	building_mgr.get_entry(idx).cells = final_cells

	var door_rotation = _building_edit_rotation_count
	var door_translation = _building_edit_translation
	for d in range(door_mgr.size()):
		var door = door_mgr.get_entry(d)
		if door.building_index == idx:
			var old_cell = door.cell
			door.cell = MapUtils.rotate_cell_around(door.cell, _building_edit_centroid, door_rotation) + door_translation
			door.edge_normal = MapUtils.rotate_edge_normal(door.edge_normal, door_rotation)
			if old_cell != door.cell:
				door_mgr.clear_visual_by_cell(old_cell)

	for c in range(corridor_mgr.size()):
		var corr = corridor_mgr.get_entry(c)
		if corr.building_index == idx:
			var corr_old = corr.cells.duplicate()
			corridor_mgr.clear_tiles(corr_old)
			var new_cells = MapUtils.rotate_cells_around(corr_old, _building_edit_centroid, door_rotation)
			for i in range(new_cells.size()):
				new_cells[i] += door_translation
			corr.cells = new_cells
			corridor_mgr.set_tiles(new_cells)

	if _building_edit_original_cells.size() > 0:
		_apply_building_edit_room_changes(_building_edit_translation)
	_building_edit_original_cells.clear()
	door_mgr.redraw_all()
	building_mgr.update_label_position(idx)
	renderer.update_edge_lines()
	_update_confirmed_visuals()
	_close_edit_dialog()

func _cancel_building_edit() -> void:
	_editing_action = ""
	construction.blocked_cells.clear()
	_clear_building_edit_preview_tiles()
	_restore_building_edit_original_tiles()
	_building_edit_room_entries.clear()
	_building_edit_original_cells.clear()
	_building_edit_rotation_count = 0
	_building_edit_translation = Vector2i.ZERO
	construction.cancel_edit()
	_update_confirmed_visuals()
	_close_edit_dialog()

func _clear_building_edit_preview_tiles() -> void:
	for entry in _building_edit_room_entries:
		var layer = principal_office_layer if entry.ref.room_type == "Principal Office" and principal_office_layer else classroom_layer
		for cell in entry.prev_preview_cells:
			layer.erase_cell(cell)
		entry.prev_preview_cells.clear()

func _restore_building_edit_original_tiles() -> void:
	if _building_edit_cleared_originals:
		for entry in _building_edit_room_entries:
			var atlas = room_mgr.get_atlas_for_room(entry.ref.room_type)
			var layer = principal_office_layer if entry.ref.room_type == "Principal Office" and principal_office_layer else classroom_layer
			for cell in entry.original_cells:
				layer.set_cell(cell, 0, atlas)
		_building_edit_cleared_originals = false

func _update_building_edit_room_preview(offset: Vector2i) -> void:
	if _building_edit_room_entries.is_empty():
		return
	_clear_building_edit_preview_tiles()
	if not _building_edit_cleared_originals:
		for entry in _building_edit_room_entries:
			var erase_layer = principal_office_layer if entry.ref.room_type == "Principal Office" and principal_office_layer else classroom_layer
			for cell in entry.original_cells:
				erase_layer.erase_cell(cell)
		_building_edit_cleared_originals = true
	for entry in _building_edit_room_entries:
		var atlas = room_mgr.get_atlas_for_room(entry.ref.room_type)
		var draw_layer = principal_office_layer if entry.ref.room_type == "Principal Office" and principal_office_layer else classroom_layer
		for cell in entry.original_cells:
			var transformed = MapUtils.rotate_cell_around(cell, _building_edit_centroid, _building_edit_rotation_count) + offset
			draw_layer.set_cell(transformed, 0, atlas)
			entry.prev_preview_cells.append(transformed)

func _apply_building_edit_room_changes(offset: Vector2i) -> void:
	_clear_building_edit_preview_tiles()
	for entry in _building_edit_room_entries:
		var new_cells: Array[Vector2i] = []
		for cell in entry.original_cells:
			new_cells.append(MapUtils.rotate_cell_around(cell, _building_edit_centroid, _building_edit_rotation_count) + offset)
		entry.ref.cells = new_cells
		room_mgr.set_tiles(new_cells, entry.ref.room_type)
		var label = entry.ref.label as Label
		if label:
			MapUtils.position_label(label, new_cells, -36)
	_building_edit_room_entries.clear()
	_building_edit_rotation_count = 0
	_building_edit_cleared_originals = false

func _start_room_edit(index: int) -> void:
	_close_edit_dialog()
	var cls = room_mgr.get_entry(index)
	var room_type = cls.room_type
	_is_corridor_edit = false
	_corridor_editing_index = -1
	_is_room_edit = true
	_room_editing_index = index
	construction.begin_edit(cls.building_index, cls.cells)
	_building_edit_original_cells = cls.cells.duplicate()
	_building_edit_centroid = MapUtils.calc_centroid(cls.cells)
	_building_edit_rotation_count = 0
	_building_edit_translation = Vector2i.ZERO
	_editing_action = ""
	_update_confirmed_visuals()

	_building_edit_dialog = BuildingEditDialog.new()
	var edit_title = room_mgr.edit_title(room_type)
	if room_type != "Principal Office":
		edit_title += " #" + str(index + 1)
	_building_edit_dialog.show(
		self,
		edit_title,
		_on_room_edit_action,
		_confirm_room_edit,
		_cancel_room_edit
	)
	hud_message("Editing %s" % cls.name)

func _on_room_edit_action(action: String) -> void:
	_editing_action = action
	match action:
		"add_delete":
			_building_edit_original_cells = construction.editing_cells.duplicate()
			_building_edit_centroid = MapUtils.calc_centroid(construction.editing_cells)
			_building_edit_rotation_count = 0
			_building_edit_translation = Vector2i.ZERO
			construction.current_tool = "tiles"
			var room_building_idx = room_mgr.get_entry(_room_editing_index).building_index if _room_editing_index >= 0 and _room_editing_index < room_mgr.size() else -1
			construction.blocked_cells = room_mgr.get_blocked_cells(room_building_idx, _room_editing_index) if room_building_idx >= 0 else building_mgr.get_occupied_cells(camera.current_floor)
			construction.render_preview()
			construction.painted_preview_cells.clear()
			hud_message("Left-click to add tiles, right-click to delete. Corridor tiles will be replaced.")
		"move_rotate":
			_building_edit_original_cells = construction.editing_cells.duplicate()
			_building_edit_centroid = MapUtils.calc_centroid(construction.editing_cells)
			_building_edit_rotation_count = 0
			_building_edit_translation = Vector2i.ZERO
			construction.current_tool = "move_rotate"
			construction.render_preview()
			hud_message("Left-click & drag to move, middle-click to rotate.")
		"rename":
			_rename_room()
		"demolish":
			_demolish_room()

func _rename_room() -> void:
	var idx = _room_editing_index
	if idx < 0 or idx >= room_mgr.size():
		return
	var cls = room_mgr.get_entry(idx)
	if cls.room_type == "Principal Office":
		return
	var hud = find_child("InGameHUD", true, false) as CanvasLayer
	if hud and hud.has_method("show_building_rename_dialog"):
		hud.show_building_rename_dialog(cls.name, func(confirmed: bool, new_name: String):
			if not confirmed:
				return
			room_mgr.rename(idx, new_name)
			room_mgr.update_label_position(idx)
		)

func _demolish_room() -> void:
	var idx = _room_editing_index
	if idx < 0 or idx >= room_mgr.size():
		return
	_do_demolish_room(idx)

func _do_demolish_room(idx: int) -> void:
	if idx >= room_mgr.size():
		return
	var cls = room_mgr.get_entry(idx)
	var was_principal = cls.room_type == "Principal Office"
	door_mgr.remove_for_room(idx, cls.building_index)
	cls.label.queue_free()
	room_mgr.clear_tiles(cls.cells, cls.room_type)
	room_mgr.remove(idx)
	construction.blocked_cells.clear()
	construction.cancel_edit()
	_is_room_edit = false
	if was_principal:
		var hud = find_child("InGameHUD", true, false) as CanvasLayer
		if hud and hud.has_method("disable_principal_office_button"):
			hud.disable_principal_office_button(false)
	_room_editing_index = -1
	_close_edit_dialog()
	renderer.update_edge_lines()
	_update_confirmed_visuals()

func _confirm_room_edit() -> void:
	_editing_action = ""
	construction.blocked_cells.clear()
	if _room_editing_index < 0 or _room_editing_index >= room_mgr.size():
		return
	var idx = _room_editing_index
	var final_cells = construction.apply_edit()
	var cls = room_mgr.get_entry(idx)
	if cls.room_type == "Principal Office":
		var admin_idx = room_mgr.get_admin_area_in_building(cls.building_index)
		if admin_idx < 0:
			hud_message("Principal Office must be inside an Administration Area.")
			construction.begin_edit(cls.building_index, cls.cells)
			_restore_building_edit_original_tiles()
			return
		var admin_cells = room_mgr.get_entry(admin_idx).cells
		for c in final_cells:
			if c not in admin_cells:
				hud_message("All Principal Office tiles must be inside an Administration Area.")
				construction.begin_edit(cls.building_index, cls.cells)
				_restore_building_edit_original_tiles()
				return
	room_mgr.clear_tiles(cls.cells, cls.room_type)
	cls.cells = final_cells
	room_mgr.set_tiles(final_cells, cls.room_type)
	for i in range(corridor_mgr.size()):
		var corr = corridor_mgr.get_entry(i)
		var to_remove: Array[Vector2i] = []
		for c in corr.cells:
			if c in final_cells:
				to_remove.append(c)
		if to_remove.size() > 0:
			for c in to_remove:
				corr.cells.erase(c)
			corridor_mgr.clear_tiles(to_remove)
	room_mgr.update_label_position(idx)
	for d in range(door_mgr.size()):
		var door = door_mgr.get_entry(d)
		if door.room_index == idx and door.building_index == cls.building_index:
			var old_cell = door.cell
			door.cell = MapUtils.rotate_cell_around(door.cell, _building_edit_centroid, _building_edit_rotation_count) + _building_edit_translation
			door.edge_normal = MapUtils.rotate_edge_normal(door.edge_normal, _building_edit_rotation_count)
			if old_cell != door.cell:
				door_mgr.clear_visual_by_cell(old_cell)
	_is_room_edit = false
	_room_editing_index = -1
	door_mgr.redraw_all()
	renderer.update_edge_lines()
	_update_confirmed_visuals()
	_close_edit_dialog()

func _cancel_room_edit() -> void:
	_editing_action = ""
	construction.blocked_cells.clear()
	construction.cancel_edit()
	_is_room_edit = false
	_room_editing_index = -1
	_update_confirmed_visuals()
	_close_edit_dialog()

func _confirm_corridor_placement() -> void:
	var cells = construction.staged_cells.duplicate()
	var filtered: Array[Vector2i] = []
	var building_idx = -1
	for cell in cells:
		var b_idx = building_mgr.get_at_cell(cell)
		if b_idx >= 0 and room_mgr.get_at_cell(cell) < 0:
			var corr_idx = corridor_mgr.get_at_cell(cell)
			if corr_idx < 0:
				filtered.append(cell)
				if building_idx < 0:
					building_idx = b_idx
	if filtered.is_empty():
		for cell in cells:
			corridor_layer.erase_cell(cell)
		construction.staged_cells.clear()
		construction.current_state = ConstructionState.State.IDLE
		_remove_confirmation_widget()
		hud_message("No valid corridor tiles selected")
		return
	for cell in cells:
		corridor_layer.erase_cell(cell)
	corridor_mgr.set_tiles(filtered)
	corridor_mgr.counter += 1
	var name = "Corridor #%d" % corridor_mgr.counter
	corridor_mgr.add(name, filtered, building_idx)
	construction.staged_cells.clear()
	construction.current_state = ConstructionState.State.IDLE
	_remove_confirmation_widget()
	renderer.update_edge_lines()
	hud_message("Placed %s" % name)

func _start_corridor_edit(index: int) -> void:
	_close_edit_dialog()
	var corr = corridor_mgr.get_entry(index)
	_is_room_edit = false
	_room_editing_index = -1
	_is_corridor_edit = true
	_corridor_editing_index = index
	_building_edit_dialog = BuildingEditDialog.new()
	_building_edit_dialog.show(
		self,
		corr.name,
		_on_corridor_edit_action,
		_confirm_corridor_edit,
		_cancel_corridor_edit,
		"corridor"
	)
	construction.begin_edit(corr.building_index, corr.cells)
	_building_edit_original_cells = corr.cells.duplicate()
	_building_edit_rotation_count = 0
	_building_edit_translation = Vector2i.ZERO
	_editing_action = ""
	_update_confirmed_visuals()
	hud_message("Editing %s" % corr.name)

func _on_corridor_edit_action(action: String) -> void:
	match action:
		"add_delete":
			_editing_action = "add_delete"
			construction.current_tool = "tiles"
			construction.blocked_cells = corridor_mgr.get_blocked_cells(_corridor_editing_index, camera.current_floor)
			construction.render_preview()
			hud_message("Click to add tiles, right-click to remove")
		"demolish":
			_demolish_corridor()

func _confirm_corridor_edit() -> void:
	_editing_action = ""
	construction.blocked_cells.clear()
	_corridor_edit_overlay_cells.clear()
	if _corridor_editing_index < 0 or _corridor_editing_index >= corridor_mgr.size():
		return
	var idx = _corridor_editing_index
	var final_cells = construction.apply_edit()
	var corr = corridor_mgr.get_entry(idx)
	corridor_mgr.clear_tiles(corr.cells)
	corr.cells = final_cells
	corridor_mgr.set_tiles(final_cells)
	_is_corridor_edit = false
	_corridor_editing_index = -1
	renderer.update_edge_lines()
	_update_confirmed_visuals()
	_close_edit_dialog()

func _cancel_corridor_edit() -> void:
	_editing_action = ""
	construction.blocked_cells.clear()
	_corridor_edit_overlay_cells.clear()
	if _corridor_editing_index >= 0 and _corridor_editing_index < corridor_mgr.size():
		var corr = corridor_mgr.get_entry(_corridor_editing_index)
		var current = construction.editing_cells.duplicate()
		construction.cancel_edit()
		for cell in current:
			if cell not in corr.cells:
				corridor_layer.erase_cell(cell)
		corridor_mgr.clear_tiles(corr.cells)
		corridor_mgr.set_tiles(corr.cells)
	else:
		construction.cancel_edit()
	_is_corridor_edit = false
	_corridor_editing_index = -1
	_update_confirmed_visuals()
	_close_edit_dialog()

func _demolish_corridor() -> void:
	var idx = _corridor_editing_index
	if idx < 0 or idx >= corridor_mgr.size():
		return
	_do_demolish_corridor(idx)

func _do_demolish_corridor(idx: int) -> void:
	if idx >= corridor_mgr.size():
		return
	_is_corridor_edit = false
	_corridor_editing_index = -1
	_corridor_edit_overlay_cells.clear()
	_editing_action = ""
	construction.cancel_edit()
	construction.blocked_cells.clear()
	var corr = corridor_mgr.get_entry(idx)
	corridor_mgr.clear_tiles(corr.cells)
	corridor_mgr.remove(idx)
	_close_edit_dialog()
	renderer.update_edge_lines()
	_update_confirmed_visuals()
	hud_message("Corridor removed")

func _update_confirmed_visuals() -> void:
	for child in confirmed_container.get_children():
		child.queue_free()
	for child in _room_container.get_children():
		child.queue_free()

	for i in range(building_mgr.size()):
		var b = building_mgr.get_entry(i)
		var cells_to_show = b.cells
		if not _is_room_edit and not _is_corridor_edit and construction.current_state == ConstructionState.State.EDITING and construction.editing_building_index == i:
			cells_to_show = construction.editing_cells
		for cell in cells_to_show:
			var has_room = room_mgr.get_at_cell(cell) >= 0
			if GlobalTransferData.current_mode == GlobalTransferData.GameMode.ARCHITECTURAL and has_room:
				continue
			var color = Color("#94a3b8") if GlobalTransferData.current_mode == GlobalTransferData.GameMode.ARCHITECTURAL else ConstructionState.CONFIRMED_COLOR
			construction._make_tile_rect(cell, color, confirmed_container)

	for i in range(room_mgr.size()):
		var cls = room_mgr.get_entry(i)
		if _is_room_edit and construction.current_state == ConstructionState.State.EDITING and _room_editing_index == i:
			for cell in construction.editing_cells:
				construction._make_tile_rect(cell, Color(0.3, 0.8, 0.3, 0.4), _room_container)
	if _is_corridor_edit and construction.current_state == ConstructionState.State.EDITING and _corridor_editing_index >= 0:
		for cell in _corridor_edit_overlay_cells:
			corridor_layer.erase_cell(cell)
		_corridor_edit_overlay_cells = construction.editing_cells.duplicate()
		for cell in _corridor_edit_overlay_cells:
			corridor_layer.set_cell(cell, 0, Vector2i(1, 0))
	renderer.update_edge_lines()

func hud_message(msg: String) -> void:
	var hud = find_child("InGameHUD", true, false) as CanvasLayer
	if hud and hud.has_method("show_hud_message"):
		hud.show_hud_message(msg)

func _close_edit_dialog() -> void:
	if _building_edit_dialog and is_instance_valid(_building_edit_dialog.window):
		_building_edit_dialog.window.queue_free()
