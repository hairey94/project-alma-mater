extends Node2D

@onready var field_layer: TileMapLayer = $FieldLayer
@onready var road_layer: TileMapLayer = $RoadLayer
@onready var classroom_layer: TileMapLayer = $ClassroomLayer
@onready var corridor_layer: TileMapLayer = $CorridorLayer
@onready var blueprint_grid_layer: ColorRect = $BlueprintGridLayer
@onready var camera: Camera2D = $Camera2D

var plan_container: Node2D
var confirmed_container: Node2D

const GRID_SIZE = 64
const TILE_SIZE = 64
const FIELD_PX = GRID_SIZE * TILE_SIZE
const BuildingEditDialog = preload("res://src/scripts/hud/building_edit_dialog.gd")
const DoorSymbol = preload("res://src/scripts/door_symbol.gd")

var construction: ConstructionState

var _hover_rect: ColorRect
var _is_bulldozing: bool = false
var _last_bulldoze_cell: Vector2i = Vector2i(-1, -1)
var _building_counter: int = 0
var _building_labels_container: Node2D
var _building_data: Array[Dictionary] = []
var _building_edit_dialog: BuildingEditDialog
var _editing_action: String = ""
var _classroom_data: Array[Dictionary] = []
var _classroom_counter: int = 0
var _classroom_placement_building_index: int = -1
var _classroom_container: Node2D
var _is_classroom_edit: bool = false
var _classroom_editing_index: int = -1
var _hover_classroom_tile_cell: Vector2i = Vector2i(-999, -999)
var _building_edit_original_cells: Array[Vector2i] = []
var _building_edit_classroom_entries: Array[Dictionary] = []
var _building_edit_cleared_originals: bool = false
var _building_edit_rotation_count: int = 0
var _building_edit_centroid: Vector2 = Vector2.ZERO
var _building_edit_translation: Vector2i = Vector2i.ZERO

var _door_data: Array[Dictionary] = []
var _door_counter: int = 0
var _door_container: Node2D
var _door_placement_is_inward: bool = true
var _door_placement_preview_node: Node2D
var _door_placement_cell: Vector2i = Vector2i(-1, -1)
var _door_placement_edge_normal: Vector2i = Vector2i.ZERO
var _door_placement_building_index: int = -1
var _door_placement_classroom_index: int = -1
var _is_door_edit: bool = false
var _door_editing_index: int = -1
var _hover_door_cell: Vector2i = Vector2i(-999, -999)

var _door_hover_tile_rect: ColorRect

var _corridor_data: Array[Dictionary] = []
var _corridor_counter: int = 0
var _is_corridor_edit: bool = false
var _corridor_editing_index: int = -1
var _hover_corridor_tile_cell: Vector2i = Vector2i(-999, -999)
var _corridor_edit_overlay_cells: Array[Vector2i] = []

var _edge_line_container: Node2D

func _ready() -> void:
	plan_container = Node2D.new()
	plan_container.name = "PlanContainer"
	add_child(plan_container)
	move_child(plan_container, get_child_count())

	confirmed_container = Node2D.new()
	confirmed_container.name = "ConfirmedContainer"
	confirmed_container.z_index = 1
	add_child(confirmed_container)
	move_child(confirmed_container, get_child_count())

	_building_labels_container = Node2D.new()
	_building_labels_container.name = "BuildingLabelsContainer"
	_building_labels_container.z_index = 2
	add_child(_building_labels_container)
	move_child(_building_labels_container, get_child_count())

	_classroom_container = Node2D.new()
	_classroom_container.name = "ClassroomContainer"
	_classroom_container.z_index = 1
	add_child(_classroom_container)
	move_child(_classroom_container, get_child_count())

	classroom_layer.z_index = 2
	corridor_layer.z_index = 2

	_door_container = Node2D.new()
	_door_container.name = "DoorContainer"
	_door_container.z_index = 3
	add_child(_door_container)
	move_child(_door_container, get_child_count())

	_door_placement_preview_node = Node2D.new()
	_door_placement_preview_node.name = "DoorPlacementPreview"
	_door_placement_preview_node.visible = false
	_door_placement_preview_node.z_index = 4
	add_child(_door_placement_preview_node)
	move_child(_door_placement_preview_node, _door_container.get_index())

	_hover_rect = ColorRect.new()
	_hover_rect.name = "HoverRect"
	_hover_rect.size = Vector2(TILE_SIZE, TILE_SIZE)
	_hover_rect.color = Color(1, 1, 1, 0.2)
	_hover_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hover_rect.visible = false
	add_child(_hover_rect)
	move_child(_hover_rect, plan_container.get_index())

	_edge_line_container = Node2D.new()
	_edge_line_container.name = "EdgeLineContainer"
	_edge_line_container.z_index = 2
	add_child(_edge_line_container)
	move_child(_edge_line_container, _door_container.get_index())

	_door_hover_tile_rect = ColorRect.new()
	_door_hover_tile_rect.name = "DoorHoverTileRect"
	_door_hover_tile_rect.size = Vector2(TILE_SIZE, TILE_SIZE)
	_door_hover_tile_rect.color = Color(1, 1, 0, 0.3)
	_door_hover_tile_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_door_hover_tile_rect.visible = false
	_door_hover_tile_rect.z_index = 4
	add_child(_door_hover_tile_rect)
	move_child(_door_hover_tile_rect, _door_placement_preview_node.get_index() + 1)

	construction = ConstructionState.new()
	construction.setup(field_layer, plan_container, confirmed_container)
	construction.grid_bounds = Rect2i(0, 0, GRID_SIZE, GRID_SIZE)
	_generate_map()
	_center_camera_on_road()
	_update_edge_lines()

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
	_sync_grid_shader()
	if _is_bulldozing:
		var cell = _cell_under_mouse()
		if cell != _last_bulldoze_cell:
			_bulldoze_cell(cell)
			_last_bulldoze_cell = cell
	if construction.active_item_name != "" or construction.current_state in [ConstructionState.State.EDITING, ConstructionState.State.DRAGGING]:
		_process_construction_input()

func _sync_grid_shader() -> void:
	if not blueprint_grid_layer or not blueprint_grid_layer.visible:
		return
	var mat = blueprint_grid_layer.material as ShaderMaterial
	if not mat:
		return
	var vp_size: Vector2 = get_viewport_rect().size
	var top_left: Vector2 = camera.position - ((vp_size / 2.0) / camera.zoom.x)
	mat.set_shader_parameter("camera_offset", top_left)
	mat.set_shader_parameter("camera_zoom", camera.zoom.x)
	mat.set_shader_parameter("viewport_size", vp_size)
	mat.set_shader_parameter("field_bounds", Vector4(0, 0, FIELD_PX, FIELD_PX))

func _update_hover_rect() -> void:
	_door_hover_tile_rect.visible = false
	_clear_hover_corridor_tile()
	var mode = GlobalTransferData.current_mode
	if mode != GlobalTransferData.GameMode.ARCHITECTURAL and mode != GlobalTransferData.GameMode.BULLDOZER:
		_hover_rect.visible = false
		_clear_hover_classroom_tile()
		_clear_hover_door_preview()
		return

	var use_cell = construction.current_tool == "tiles"
	var pos = _cell_under_mouse() if use_cell else _corner_under_mouse()

	if mode == GlobalTransferData.GameMode.ARCHITECTURAL:
		if pos.x < 0 or pos.x >= GRID_SIZE or pos.y < 0 or pos.y >= GRID_SIZE:
			_hover_rect.visible = false
			_clear_hover_classroom_tile()
			return
	elif mode == GlobalTransferData.GameMode.BULLDOZER:
		if pos.x < 0 or pos.x >= GRID_SIZE or pos.y < 0 or pos.y >= GRID_SIZE + 2:
			_hover_rect.visible = false
			_clear_hover_classroom_tile()
			return

	_hover_rect.visible = true
	_hover_rect.position = Vector2(pos.x * TILE_SIZE, pos.y * TILE_SIZE)

	if mode == GlobalTransferData.GameMode.ARCHITECTURAL:
		if _is_classroom_item(construction.active_item_name):
			var cell = _cell_under_mouse()
			var building_idx = _get_building_at_cell(cell)
			if building_idx >= 0:
				var blocked = _get_classroom_blocked_cells(building_idx)
				if cell in blocked:
					_hover_rect.color = Color(1, 0.3, 0.3, 0.55)
					_clear_hover_classroom_tile()
				else:
					_hover_rect.color = Color(0.4, 0.85, 0.5, 0.5)
					if construction.current_state == ConstructionState.State.IDLE:
						_update_hover_classroom_tile(cell)
					else:
						_clear_hover_classroom_tile()
			else:
				_hover_rect.color = Color(1, 0.3, 0.3, 0.55)
				_clear_hover_classroom_tile()
		elif _is_classroom_edit and _classroom_editing_index >= 0:
			var cell = _cell_under_mouse()
			var cls = _classroom_data[_classroom_editing_index]
			var building = _building_data[cls.building_index] if cls.building_index >= 0 and cls.building_index < _building_data.size() else null
			if building and cell in building.cells and cell not in construction.editing_cells:
				if _get_corridor_at_cell(cell) >= 0:
					_hover_rect.color = Color(1, 0.65, 0, 0.6)
				else:
					_hover_rect.color = Color(0.3, 0.8, 0.3, 0.55)
			else:
				_hover_rect.color = Color(1, 0.3, 0.3, 0.55)
		elif _is_corridor_item(construction.active_item_name):
			var cell = _cell_under_mouse()
			_clear_hover_classroom_tile()
			_clear_hover_door_preview()
			var building_idx = _get_building_at_cell(cell)
			if building_idx >= 0 and _get_classroom_at_cell(cell) < 0 and _get_corridor_at_cell(cell) < 0:
				_hover_rect.color = Color(0.4, 0.85, 0.5, 0.5)
				if construction.current_state == ConstructionState.State.IDLE:
					_update_hover_corridor_tile(cell)
				else:
					_clear_hover_corridor_tile()
			else:
				_hover_rect.color = Color(1, 0.3, 0.3, 0.55)
				_clear_hover_corridor_tile()
		elif _is_door_item(construction.active_item_name):
			var cell = _cell_under_mouse()
			var info = _get_valid_door_placement(cell)
			if info.valid:
				_hover_rect.color = Color(1, 0.85, 0, 0.5)
				_clear_hover_classroom_tile()
				_door_hover_tile_rect.position = Vector2(cell.x * TILE_SIZE, cell.y * TILE_SIZE)
				_door_hover_tile_rect.color = Color(1, 0.85, 0, 0.25)
				if construction.current_state == ConstructionState.State.IDLE:
					_hover_door_preview(cell, info.edge_normal)
				else:
					_clear_hover_door_preview()
				_door_hover_tile_rect.visible = true
			else:
				_hover_rect.color = Color(1, 0.3, 0.3, 0.55)
				_door_hover_tile_rect.visible = false
				_clear_hover_door_preview()
		else:
			var occ = _get_occupied_cells(camera.current_floor)
			_hover_rect.color = Color(1, 0.3, 0.3, 0.35) if pos in occ else Color(1, 1, 1, 0.2)
	elif mode == GlobalTransferData.GameMode.BULLDOZER:
		_hover_rect.color = Color(1, 1, 1, 0.2)
		_clear_hover_door_preview()

func _clear_hover_classroom_tile() -> void:
	if _hover_classroom_tile_cell.x >= 0:
		if _hover_classroom_tile_cell not in construction.painted_preview_cells and _hover_classroom_tile_cell not in construction.staged_cells and _get_classroom_at_cell(_hover_classroom_tile_cell) < 0:
			classroom_layer.erase_cell(_hover_classroom_tile_cell)
		_hover_classroom_tile_cell = Vector2i(-999, -999)

func _update_hover_classroom_tile(cell: Vector2i) -> void:
	if cell != _hover_classroom_tile_cell:
		_clear_hover_classroom_tile()
		classroom_layer.set_cell(cell, 0, Vector2i(1, 0))
		_hover_classroom_tile_cell = cell

func _clear_hover_corridor_tile() -> void:
	if _hover_corridor_tile_cell.x >= 0:
		if _hover_corridor_tile_cell not in construction.painted_preview_cells and _hover_corridor_tile_cell not in construction.staged_cells and _get_corridor_at_cell(_hover_corridor_tile_cell) < 0:
			corridor_layer.erase_cell(_hover_corridor_tile_cell)
		_hover_corridor_tile_cell = Vector2i(-999, -999)

func _update_hover_corridor_tile(cell: Vector2i) -> void:
	if cell != _hover_corridor_tile_cell:
		_clear_hover_corridor_tile()
		corridor_layer.set_cell(cell, 0, Vector2i(1, 0))
		_hover_corridor_tile_cell = cell

func _cell_under_mouse() -> Vector2i:
	return field_layer.local_to_map(field_layer.get_local_mouse_position())

func _corner_under_mouse() -> Vector2i:
	var local_pos = field_layer.get_local_mouse_position()
	return Vector2i(
		roundi(local_pos.x / TILE_SIZE),
		roundi(local_pos.y / TILE_SIZE)
	)

func set_active_placement_item(_item_name: String) -> void:
	_clear_hover_door_preview()
	_clear_hover_corridor_tile()
	_reset_door_replacement_state()
	construction.set_active_item(_item_name)

func set_placement_tool(tool_name: String) -> void:
	construction.current_tool = tool_name

func cancel_placement() -> void:
	if _classroom_placement_building_index >= 0:
		var cells_to_clear = construction.painted_preview_cells if construction.current_state == ConstructionState.State.DRAGGING else construction.staged_cells
		for cell in cells_to_clear:
			classroom_layer.erase_cell(cell)
	if _is_corridor_item(construction.active_item_name):
		var cells_to_clear = construction.painted_preview_cells if construction.current_state == ConstructionState.State.DRAGGING else construction.staged_cells
		for cell in cells_to_clear:
			corridor_layer.erase_cell(cell)
	_classroom_placement_building_index = -1
	_clear_hover_classroom_tile()
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
		elif _is_classroom_edit:
			_cancel_classroom_edit()
		else:
			_cancel_building_edit()
	elif construction.current_state in [ConstructionState.State.DRAGGING, ConstructionState.State.PENDING_APPROVAL]:
		cancel_placement()

func _on_game_mode_changed(new_mode: GlobalTransferData.GameMode) -> void:
	_is_bulldozing = false
	blueprint_grid_layer.visible = false
	_cancel_any_active_edit()
	_clear_hover_classroom_tile()
	_clear_hover_corridor_tile()
	_clear_hover_door_preview()
	# Switch building tiles between arch (tan) and game (concrete) modes
	for b in _building_data:
		for cell in b.cells:
			var atlas_coord = Vector2i(3, 0) if new_mode == GlobalTransferData.GameMode.GAME else Vector2i(1, 0)
			field_layer.set_cell(cell, 0, atlas_coord)
	match new_mode:
		GlobalTransferData.GameMode.GAME:
			field_layer.modulate = Color.WHITE
			classroom_layer.modulate = Color(0.82, 0.58, 0.28, 1.0)
			corridor_layer.modulate = Color(0.75, 0.75, 0.75, 1.0)
			construction.clear_staged(false)
			confirmed_container.visible = false
		GlobalTransferData.GameMode.ARCHITECTURAL:
			field_layer.modulate = Color("#3057e1")
			classroom_layer.modulate = Color(0.4, 0.85, 0.5, 0.85)
			corridor_layer.modulate = Color(0.8, 0.8, 0.8, 1.0)
			blueprint_grid_layer.visible = true
			confirmed_container.visible = true
		GlobalTransferData.GameMode.MANAGEMENT:
			field_layer.modulate = Color("#475569")
			classroom_layer.modulate = Color("#475569")
			corridor_layer.modulate = Color(0.75, 0.75, 0.75, 1.0)
			construction.clear_staged(false)
			confirmed_container.visible = false
		GlobalTransferData.GameMode.BULLDOZER:
			field_layer.modulate = Color("#991b1b")
			classroom_layer.modulate = Color("#991b1b")
			corridor_layer.modulate = Color(0.75, 0.75, 0.75, 1.0)
			blueprint_grid_layer.visible = true
			confirmed_container.visible = false
	if confirmed_container.visible:
		_update_confirmed_visuals()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_MIDDLE and event.pressed:
		if _is_door_item(construction.active_item_name) and construction.current_state == ConstructionState.State.IDLE:
			_toggle_door_direction()
			get_viewport().set_input_as_handled()
			return
		if _is_door_edit and _door_editing_index >= 0:
			var door = _door_data[_door_editing_index]
			door.is_inward = not door.is_inward
			_redraw_door(door)
			hud_message("Door direction toggled to %s" % ("inward" if door.is_inward else "outward"))
			get_viewport().set_input_as_handled()
			return
		if construction.current_state == ConstructionState.State.EDITING and construction.editing_building_index >= 0 and _editing_action in ["rotate", "move_rotate"]:
			var cell = _cell_under_mouse()
			if cell in construction.editing_cells:
				var other_cells = _get_all_cells_except(construction.editing_building_index)
				var new_count = _building_edit_rotation_count + 1
				var raw_rotated = _rotate_cells_around(_building_edit_original_cells, _building_edit_centroid, new_count)
				var positioned: Array[Vector2i] = []
				for c in raw_rotated:
					positioned.append(c + _building_edit_translation)
				var can_rotate = true
				for rc in positioned:
					if rc in other_cells or rc.x < 0 or rc.x >= GRID_SIZE or rc.y < 0 or rc.y >= GRID_SIZE:
						can_rotate = false
						break
				var dedup: Array[Vector2i] = []
				for rc in positioned:
					if rc not in dedup:
						dedup.append(rc)
				if dedup.size() != positioned.size():
					can_rotate = false
				if can_rotate and _is_classroom_edit and _classroom_editing_index >= 0:
					var cls_building_idx = _classroom_data[_classroom_editing_index].building_index
					if cls_building_idx >= 0 and cls_building_idx < _building_data.size():
						var building_cells = _building_data[cls_building_idx].cells
						for rc in positioned:
							if rc not in building_cells:
								can_rotate = false
								break
					else:
						can_rotate = false
				if can_rotate:
					construction.editing_cells = positioned
					_building_edit_rotation_count = new_count
					construction.start_drag(_corner_under_mouse())
				get_viewport().set_input_as_handled()
				return
		if construction.current_state == ConstructionState.State.DRAGGING and construction.editing_building_index >= 0 and _editing_action in ["rotate", "move_rotate"]:
			var other_cells = _get_all_cells_except(construction.editing_building_index)
			var new_count = _building_edit_rotation_count + 1
			var raw_rotated = _rotate_cells_around(_building_edit_original_cells, _building_edit_centroid, new_count)
			var positioned: Array[Vector2i] = []
			for c in raw_rotated:
				positioned.append(c + _building_edit_translation)
			var can_rotate = true
			for rc in positioned:
				if rc in other_cells or rc.x < 0 or rc.x >= GRID_SIZE or rc.y < 0 or rc.y >= GRID_SIZE:
					can_rotate = false
					break
			var dedup: Array[Vector2i] = []
			for rc in positioned:
				if rc not in dedup:
					dedup.append(rc)
			if dedup.size() != positioned.size():
				can_rotate = false
			if can_rotate and _is_classroom_edit and _classroom_editing_index >= 0:
				var cls_building_idx = _classroom_data[_classroom_editing_index].building_index
				if cls_building_idx >= 0 and cls_building_idx < _building_data.size():
					var building_cells = _building_data[cls_building_idx].cells
					for rc in positioned:
						if rc not in building_cells:
							can_rotate = false
							break
				else:
					can_rotate = false
			if can_rotate:
				construction.editing_cells = positioned
				_building_edit_rotation_count = new_count
				construction.render_preview()
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if construction.current_state == ConstructionState.State.DRAGGING and construction.editing_building_index >= 0:
			_clear_building_edit_preview_tiles()
			_restore_building_edit_original_tiles()
			construction.clear_preview_cells()
			construction.current_state = ConstructionState.State.EDITING
		elif construction.current_state == ConstructionState.State.EDITING:
			if _editing_action == "add_delete":
				var cell = _cell_under_mouse()
				var bounds = Rect2i(0, 0, GRID_SIZE, GRID_SIZE)
				if bounds.has_point(cell) and cell in construction.editing_cells:
					construction.remove_cell(cell)
					_update_confirmed_visuals()
					get_viewport().set_input_as_handled()
					return
			_editing_action = ""
			construction.painted_preview_cells.clear()
			construction.render_preview()
		elif construction.current_state == ConstructionState.State.PENDING_APPROVAL:
			var cell = _cell_under_mouse()
			construction.remove_cell(cell)
			if _classroom_placement_building_index >= 0:
				classroom_layer.erase_cell(cell)
			if _is_corridor_item(construction.active_item_name):
				corridor_layer.erase_cell(cell)
			if construction.current_state == ConstructionState.State.IDLE:
				_remove_confirmation_widget()
		elif construction.current_state == ConstructionState.State.DRAGGING and construction.current_tool == "tiles":
			var cell = _cell_under_mouse()
			construction.remove_cell(cell)
			if _classroom_placement_building_index >= 0:
				classroom_layer.erase_cell(cell)
			if _is_corridor_item(construction.active_item_name):
				corridor_layer.erase_cell(cell)
		elif construction.current_state == ConstructionState.State.DRAGGING:
			cancel_placement()
		elif construction.current_state == ConstructionState.State.IDLE:
			if _is_door_item(construction.active_item_name) or _is_corridor_item(construction.active_item_name):
				set_active_placement_item("")
				set_placement_tool("drag")
				_editing_action = ""
				_clear_hover_door_preview()
				_clear_hover_corridor_tile()
				_reset_door_replacement_state()
				var hud = find_child("InGameHUD", true, false)
				if hud and hud.has_method("deselect_toolbar"):
					hud.deselect_toolbar()
				hud_message("Tool deselected")
				get_viewport().set_input_as_handled()
				return
			if construction.active_item_name != "":
				set_active_placement_item("")
				set_placement_tool("drag")
				_editing_action = ""
				_clear_hover_classroom_tile()
				_clear_hover_door_preview()
				construction.painted_preview_cells.clear()
				construction.blocked_cells.clear()
				construction.clear_preview_cells()
				var hud = find_child("InGameHUD", true, false)
				if hud and hud.has_method("deselect_toolbar"):
					hud.deselect_toolbar()
				hud_message("Tool deselected")
		_is_bulldozing = false
		get_viewport().set_input_as_handled()

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
			if _is_door_edit and _door_editing_index >= 0 and use_cell:
				var cell = _cell_under_mouse()
				var bounds = Rect2i(0, 0, GRID_SIZE, GRID_SIZE)
				if bounds.has_point(cell):
					_relocate_door_to(cell)
					get_viewport().set_input_as_handled()
					return

			if construction.current_state == ConstructionState.State.EDITING:
				var cell = _cell_under_mouse()
				var bounds = Rect2i(0, 0, GRID_SIZE, GRID_SIZE)
				if use_cell and bounds.has_point(cell):
					if _editing_action == "add_delete":
						if _is_classroom_edit and _classroom_editing_index >= 0:
							var cls_building_idx = _classroom_data[_classroom_editing_index].building_index
							if cls_building_idx >= 0 and cls_building_idx < _building_data.size() and cell not in _building_data[cls_building_idx].cells:
								get_viewport().set_input_as_handled()
								return
						construction.toggle_edit_cell(cell)
					_update_confirmed_visuals()
					get_viewport().set_input_as_handled()
					return
			if not use_cell and _editing_action == "move_rotate":
				construction.blocked_cells = _get_all_cells_except(construction.editing_building_index) if construction.editing_building_index >= 0 else _get_occupied_cells(camera.current_floor)
				construction.start_drag(pos)
				get_viewport().set_input_as_handled()
				return

		elif event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and construction.current_state == ConstructionState.State.DRAGGING:
			if _classroom_placement_building_index >= 0:
				construction.blocked_cells = _get_classroom_blocked_cells(_classroom_placement_building_index)
			elif _is_corridor_item(construction.active_item_name):
				construction.blocked_cells = _get_blocked_cells_for_corridor()
			else:
				construction.blocked_cells = _get_all_cells_except(construction.editing_building_index) if construction.editing_building_index >= 0 else _get_occupied_cells(camera.current_floor)
			if construction.current_tool in ["move", "rotate", "move_rotate"] and construction.editing_building_index >= 0:
				var offset = construction.drag_end_cell - construction.drag_start_cell
				if offset == Vector2i.ZERO:
					construction.current_state = ConstructionState.State.EDITING
					return
				var other_cells = _get_all_cells_except(construction.editing_building_index)
				if construction.move_cells(offset, other_cells).is_empty():
					construction.begin_edit(construction.editing_building_index, _building_data[construction.editing_building_index].cells)
					hud_message("Cannot place here - blocked")
				else:
					_building_edit_translation += offset
					if _is_classroom_edit and _classroom_editing_index >= 0:
						var cls_building_idx = _classroom_data[_classroom_editing_index].building_index
						var all_inside = true
						if cls_building_idx >= 0 and cls_building_idx < _building_data.size():
							var building_cells = _building_data[cls_building_idx].cells
							for cell in construction.editing_cells:
								if cell not in building_cells:
									all_inside = false
									break
						else:
							all_inside = false
						if not all_inside:
							var cls = _classroom_data[_classroom_editing_index]
							construction.begin_edit(cls.building_index, cls.cells)
							_building_edit_original_cells = cls.cells.duplicate()
							_building_edit_centroid = _calc_centroid(cls.cells)
							_building_edit_rotation_count = 0
							_building_edit_translation = Vector2i.ZERO
							hud_message("Classroom must stay inside building")
				construction.current_state = ConstructionState.State.EDITING
				_update_confirmed_visuals()
			else:
				construction.end_drag(pos)
				_update_confirmed_visuals()
				if construction.current_state == ConstructionState.State.EDITING:
					_classroom_placement_building_index = -1
					return
				if construction.current_state != ConstructionState.State.PENDING_APPROVAL:
					_classroom_placement_building_index = -1
					return
				_spawn_confirmation_widget(event.global_position)

		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			if construction.current_state == ConstructionState.State.EDITING:
				var cell = _cell_under_mouse()
				var bounds = Rect2i(0, 0, GRID_SIZE, GRID_SIZE)
				if use_cell and bounds.has_point(cell):
					if _editing_action == "add_delete" and cell in construction.editing_cells:
						construction.remove_cell(cell)
						_update_confirmed_visuals()
						get_viewport().set_input_as_handled()
						return
			if _is_door_edit and use_cell:
				var cell = _cell_under_mouse()
				var bounds = Rect2i(0, 0, GRID_SIZE, GRID_SIZE)
				if bounds.has_point(cell):
					_close_edit_dialog()
					construction.cancel_edit()
					get_viewport().set_input_as_handled()
					return

		if event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			get_viewport().set_input_as_handled()
			return

		if GlobalTransferData.current_mode == GlobalTransferData.GameMode.ARCHITECTURAL:
			var cell = _cell_under_mouse()
			var door_idx = _get_door_at_cell(cell)
			if door_idx >= 0 and construction.current_state == ConstructionState.State.IDLE:
				if not _is_door_item(construction.active_item_name) or _get_valid_door_placement(cell).valid == false:
					_start_door_edit(door_idx)
					get_viewport().set_input_as_handled()
					return
			if _is_door_item(construction.active_item_name) and construction.current_state == ConstructionState.State.IDLE:
				var info = _get_valid_door_placement(cell)
				if info.valid:
					_start_door_placement(cell)
				get_viewport().set_input_as_handled()
				return
			var corridor_idx = _get_corridor_at_cell(cell)
			if corridor_idx >= 0 and construction.current_state == ConstructionState.State.IDLE and not _is_corridor_item(construction.active_item_name):
				_start_corridor_edit(corridor_idx)
				get_viewport().set_input_as_handled()
				return
			var building_idx = _get_building_at_cell(cell)
			if building_idx >= 0:
				var can_edit = construction.current_state in [ConstructionState.State.IDLE, ConstructionState.State.PENDING_APPROVAL]
				if can_edit and not _is_classroom_item(construction.active_item_name) and not _is_corridor_item(construction.active_item_name):
					var classroom_idx = _get_classroom_at_cell(cell)
					if classroom_idx >= 0:
						_start_classroom_edit(classroom_idx)
					else:
						_start_building_edit(building_idx)
					get_viewport().set_input_as_handled()
					return
			if construction.current_state == ConstructionState.State.PENDING_APPROVAL:
				return
			if construction.current_state == ConstructionState.State.IDLE:
				if construction.active_item_name == "":
					return
				if _is_classroom_item(construction.active_item_name):
					var existing_classroom = _get_classroom_at_cell(cell)
					if existing_classroom >= 0:
						_start_classroom_edit(existing_classroom)
						get_viewport().set_input_as_handled()
						return
					building_idx = _get_building_at_cell(cell)
					if building_idx < 0:
						hud_message("Select a building to add a classroom.")
						return
					_start_classroom_placement(building_idx, cell)
					get_viewport().set_input_as_handled()
					return
				if _is_corridor_item(construction.active_item_name):
					var existing_corridor = _get_corridor_at_cell(cell)
					if existing_corridor >= 0:
						_start_corridor_edit(existing_corridor)
						get_viewport().set_input_as_handled()
						return
					building_idx = _get_building_at_cell(cell)
					if building_idx < 0:
						hud_message("Select a building to add a corridor.")
						return
					if _get_classroom_at_cell(cell) >= 0:
						hud_message("Cannot place corridor inside a classroom.")
						return
					construction.blocked_cells = _get_blocked_cells_for_corridor()
					if cell in construction.blocked_cells:
						hud_message("Cannot place corridor here - already occupied or outside building")
						return
					construction.current_tool = "tiles"
					construction.start_drag(cell)
					hud_message("Drag to paint corridor tiles inside the building, right-click to remove")
					get_viewport().set_input_as_handled()
					return
				construction.blocked_cells = _get_occupied_cells(camera.current_floor)
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
			var corridor_building_idx = _corridor_data[_corridor_editing_index].building_index if _corridor_editing_index >= 0 else -1
			if corridor_building_idx >= 0:
				construction.blocked_cells = _get_blocked_cells_for_corridor()
			else:
				construction.blocked_cells = _get_occupied_cells(camera.current_floor)
		elif _is_classroom_edit:
			var cls_building_idx = _classroom_data[_classroom_editing_index].building_index if _classroom_editing_index >= 0 else -1
			if cls_building_idx >= 0:
				construction.blocked_cells = _get_all_cells_except(cls_building_idx)
				for i in range(_classroom_data.size()):
					if i != _classroom_editing_index and _classroom_data[i].building_index == cls_building_idx:
						construction.blocked_cells.append_array(_classroom_data[i].cells)
			else:
				construction.blocked_cells = _get_occupied_cells(camera.current_floor)
		else:
			construction.blocked_cells = _get_all_cells_except(construction.editing_building_index) if construction.editing_building_index >= 0 else _get_occupied_cells(camera.current_floor)
		var pos = _cell_under_mouse()
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and _editing_action in ["add", "add_delete"]:
			var bounds = Rect2i(0, 0, GRID_SIZE, GRID_SIZE)
			if bounds.has_point(pos) and not pos in construction.editing_cells and not pos in construction.blocked_cells:
				if _is_classroom_edit and _classroom_editing_index >= 0:
					var b_idx = _classroom_data[_classroom_editing_index].building_index
					if b_idx >= 0 and b_idx < _building_data.size() and pos not in _building_data[b_idx].cells:
						return
				if _is_corridor_edit and _corridor_editing_index >= 0:
					var b_idx = _corridor_data[_corridor_editing_index].building_index
					if b_idx >= 0 and b_idx < _building_data.size() and pos not in _building_data[b_idx].cells:
						return
				construction.add_edit_cell(pos)
				_update_confirmed_visuals()
		return
	if construction.current_state == ConstructionState.State.DRAGGING:
		if _classroom_placement_building_index >= 0:
			construction.blocked_cells = _get_classroom_blocked_cells(_classroom_placement_building_index)
		elif _is_corridor_item(construction.active_item_name):
			construction.blocked_cells = _get_blocked_cells_for_corridor()
		else:
			construction.blocked_cells = _get_all_cells_except(construction.editing_building_index) if construction.editing_building_index >= 0 else _get_occupied_cells(camera.current_floor)
		var use_cell = construction.current_tool == "tiles"
		var pos = _cell_under_mouse() if use_cell else _corner_under_mouse()
		if pos != construction.drag_end_cell:
			construction.drag_end_cell = pos
			if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and use_cell:
				var bounds = Rect2i(0, 0, GRID_SIZE, GRID_SIZE)
				if _classroom_placement_building_index >= 0:
					var building = _building_data[_classroom_placement_building_index]
					if pos not in building.cells:
						construction.render_preview()
						return
					# Fill rectangle from drag_start to current pos for closed room shape
					var x_min = mini(construction.drag_start_cell.x, pos.x)
					var x_max = maxi(construction.drag_start_cell.x, pos.x)
					var y_min = mini(construction.drag_start_cell.y, pos.y)
					var y_max = maxi(construction.drag_start_cell.y, pos.y)
					var new_painted: Array[Vector2i] = []
					for x in range(x_min, x_max + 1):
						for y in range(y_min, y_max + 1):
							var c = Vector2i(x, y)
							if c in building.cells and c not in construction.blocked_cells:
								new_painted.append(c)
					for cell in construction.painted_preview_cells:
						if cell not in new_painted:
							classroom_layer.erase_cell(cell)
					for cell in new_painted:
						if cell not in construction.painted_preview_cells:
							classroom_layer.set_cell(cell, 0, Vector2i(1, 0))
					construction.painted_preview_cells = new_painted
					construction.render_preview()
					return
				if _is_corridor_item(construction.active_item_name):
					if not pos in construction.painted_preview_cells and not pos in construction.blocked_cells and bounds.has_point(pos):
						construction.painted_preview_cells.append(pos)
						corridor_layer.set_cell(pos, 0, Vector2i(1, 0))
						construction.render_preview()
					return
				if not pos in construction.painted_preview_cells and not pos in construction.blocked_cells and bounds.has_point(pos):
					construction.painted_preview_cells.append(pos)
					construction.render_preview()
			else:
				construction.render_preview()
				if construction.editing_building_index >= 0 and _building_edit_original_cells.size() > 0:
					var offset = construction.drag_end_cell - construction.drag_start_cell
					_update_building_edit_classroom_preview(offset)

func _start_classroom_placement(building_idx: int, cell: Vector2i) -> void:
	_hover_classroom_tile_cell = Vector2i(-999, -999)
	_classroom_placement_building_index = building_idx
	_editing_action = "classroom_add"
	construction.current_tool = "tiles"
	construction.blocked_cells = _get_classroom_blocked_cells(building_idx)
	construction.start_drag(cell)
	classroom_layer.set_cell(cell, 0, Vector2i(1, 0))
	hud_message("Click inside the building to add classroom tiles.")

func _confirm_classroom_placement() -> void:
	_classroom_counter += 1
	var default_name = "Classroom #%d" % _classroom_counter
	var building_idx = _classroom_placement_building_index
	var hud = find_child("InGameHUD", true, false) as CanvasLayer
	if hud and hud.has_method("show_building_rename_dialog"):
		hud.show_building_rename_dialog(default_name, func(confirmed: bool, name: String):
			if not confirmed:
				return
			var cells = construction.staged_cells.duplicate()
			_add_classroom_label(name, cells, building_idx)
			construction.staged_cells.clear()
			construction.current_state = ConstructionState.State.IDLE
			_remove_confirmation_widget()
			_classroom_placement_building_index = -1
		)
	else:
		var cells = construction.staged_cells.duplicate()
		_add_classroom_label(default_name, cells, building_idx)
		construction.staged_cells.clear()
		construction.current_state = ConstructionState.State.IDLE
		_remove_confirmation_widget()
		_classroom_placement_building_index = -1

func _set_classroom_tiles(cells: Array[Vector2i]) -> void:
	for cell in cells:
		classroom_layer.set_cell(cell, 0, Vector2i(1, 0))

func _clear_classroom_tiles(cells: Array[Vector2i]) -> void:
	for cell in cells:
		classroom_layer.erase_cell(cell)

func _add_classroom_label(name: String, cells: Array[Vector2i], building_idx: int) -> void:
	var centroid = Vector2.ZERO
	for cell in cells:
		centroid += Vector2(cell.x, cell.y)
	centroid /= cells.size()
	var world_pos = centroid * TILE_SIZE + Vector2(TILE_SIZE / 2, TILE_SIZE / 2)

	var label = Label.new()
	label.text = name
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color", Color(0, 0, 0, 1))
	label.add_theme_color_override("font_shadow_color", Color(1, 1, 1, 0.6))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.add_theme_font_size_override("font_size", 26)

	var font = label.get_theme_font("font")
	if not font:
		font = ThemeDB.fallback_font
	var font_size = label.get_theme_font_size("font_size")
	if font_size <= 0:
		font_size = 18
	var text_size = font.get_string_size(name, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	label.position = world_pos - Vector2(text_size.x / 2, text_size.y / 2) + Vector2(0, -36)

	_building_labels_container.add_child(label)
	_classroom_data.append({"name": name, "cells": cells.duplicate(), "building_index": building_idx, "label": label})
	_set_classroom_tiles(cells)

func _building_atlas_coord() -> Vector2i:
	return Vector2i(3, 0) if GlobalTransferData.current_mode == GlobalTransferData.GameMode.GAME else Vector2i(1, 0)

func confirm_staged_placement() -> void:
	if _classroom_placement_building_index >= 0:
		_confirm_classroom_placement()
		return
	if _is_corridor_item(construction.active_item_name):
		_confirm_corridor_placement()
		return
	_building_counter += 1
	var default_name = "Building %d" % _building_counter
	var current_floor = camera.current_floor
	var atlas = _building_atlas_coord()
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
	if _is_corridor_item(construction.active_item_name):
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

func _add_building_label(name: String, cells: Array[Vector2i], floor_level: int = 0) -> void:
	var centroid = Vector2.ZERO
	for cell in cells:
		centroid += Vector2(cell.x, cell.y)
	centroid /= cells.size()
	var world_pos = centroid * TILE_SIZE + Vector2(TILE_SIZE / 2, TILE_SIZE / 2)

	var label = Label.new()
	label.text = name
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color", Color(0.05, 0.05, 0.1))
	label.add_theme_color_override("font_shadow_color", Color(1, 1, 1, 0.6))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.add_theme_font_size_override("font_size", 30)

	var font = label.get_theme_font("font")
	if not font:
		font = ThemeDB.fallback_font
	var font_size = label.get_theme_font_size("font_size")
	if font_size <= 0:
		font_size = 20
	var text_size = font.get_string_size(name, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	label.position = world_pos - Vector2(text_size.x / 2, text_size.y / 2)

	_building_labels_container.add_child(label)
	_building_data.append({"name": name, "cells": cells.duplicate(), "label": label, "floor_level": floor_level})

func _get_occupied_cells(floor_level: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for b in _building_data:
		if b.get("floor_level", 0) == floor_level:
			cells.append_array(b.cells)
	return cells

func _get_blocked_cells_for_corridor() -> Array[Vector2i]:
	var blocked: Array[Vector2i] = []
	var current_floor = camera.current_floor
	# Block cells outside any building on this floor
	var building_cells: Array[Vector2i] = []
	for b in _building_data:
		if b.get("floor_level", 0) == current_floor:
			building_cells.append_array(b.cells)
	# Everything not in a building is blocked
	for x in range(GRID_SIZE):
		for y in range(GRID_SIZE + 2):
			var c = Vector2i(x, y)
			if c not in building_cells:
				blocked.append(c)
	# Classroom cells are blocked
	for cls in _classroom_data:
		for c in cls.cells:
			if c not in blocked:
				blocked.append(c)
	# Existing corridor cells are blocked (except the one being edited)
	for i in range(_corridor_data.size()):
		if _is_corridor_edit and i == _corridor_editing_index:
			continue
		for c in _corridor_data[i].cells:
			if c not in blocked:
				blocked.append(c)
	return blocked

func _bulldoze_cell(cell: Vector2i) -> void:
	if cell.x < 0 or cell.x >= GRID_SIZE or cell.y < 0 or cell.y >= GRID_SIZE + 2:
		return
	# Check classroom first — only remove one classroom tile
	for i in range(_classroom_data.size() - 1, -1, -1):
		var cls = _classroom_data[i]
		var idx = cls.cells.find(cell)
		if idx >= 0:
			classroom_layer.erase_cell(cell)
			cls.cells.remove_at(idx)
			if cls.cells.is_empty():
				cls.label.queue_free()
				_classroom_data.remove_at(i)
			return
	# Otherwise remove building tile
	field_layer.set_cell(cell, 0, Vector2i(0, 0))
	for child in confirmed_container.get_children():
		var rect := child as ColorRect
		if rect and rect.position == Vector2(cell.x * TILE_SIZE, cell.y * TILE_SIZE):
			confirmed_container.remove_child(rect)
			rect.queue_free()
	for i in range(_building_data.size() - 1, -1, -1):
		var b = _building_data[i]
		var idx = b.cells.find(cell)
		if idx >= 0:
			b.cells.remove_at(idx)
			if b.cells.is_empty():
				b.label.queue_free()
				_building_data.remove_at(i)
			break

func _get_all_cells_except(except_index: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for i in range(_building_data.size()):
		if i == except_index:
			continue
		cells.append_array(_building_data[i].cells)
	return cells

func _zoom_camera(factor: float) -> void:
	var new_zoom = camera.zoom * factor
	camera.zoom = new_zoom.clamp(Vector2(0.1, 0.1), Vector2(2.0, 2.0))

func _get_building_at_cell(cell: Vector2i) -> int:
	for i in range(_building_data.size()):
		if cell in _building_data[i].cells:
			return i
	return -1

func _is_classroom_item(item_name: String) -> bool:
	return item_name == "Classroom"

func _get_classroom_at_cell(cell: Vector2i) -> int:
	for i in range(_classroom_data.size()):
		if cell in _classroom_data[i].cells:
			return i
	return -1

func _get_classroom_blocked_cells(building_idx: int) -> Array[Vector2i]:
	var blocked = _get_all_cells_except(building_idx)
	for i in range(_classroom_data.size()):
		var cls = _classroom_data[i]
		if cls.building_index == building_idx:
			if _is_classroom_edit and i == _classroom_editing_index:
				continue
			blocked.append_array(cls.cells)
	return blocked

func _start_classroom_edit(index: int) -> void:
	_close_edit_dialog()
	var cls = _classroom_data[index]
	_is_corridor_edit = false
	_corridor_editing_index = -1
	_is_classroom_edit = true
	_classroom_editing_index = index
	construction.begin_edit(cls.building_index, cls.cells)
	_building_edit_original_cells = cls.cells.duplicate()
	_building_edit_centroid = _calc_centroid(cls.cells)
	_building_edit_rotation_count = 0
	_building_edit_translation = Vector2i.ZERO
	_editing_action = ""
	_update_confirmed_visuals()

	_building_edit_dialog = BuildingEditDialog.new()
	_building_edit_dialog.show(
		self,
		cls.name,
		_on_classroom_edit_action,
		_confirm_classroom_edit,
		_cancel_classroom_edit
	)
	hud_message("Editing %s" % cls.name)

func _on_classroom_edit_action(action: String) -> void:
	_editing_action = action
	match action:
		"add_delete":
			_building_edit_original_cells = construction.editing_cells.duplicate()
			_building_edit_centroid = _calc_centroid(construction.editing_cells)
			_building_edit_rotation_count = 0
			_building_edit_translation = Vector2i.ZERO
			construction.current_tool = "tiles"
			var cls_building_idx = _classroom_data[_classroom_editing_index].building_index if _classroom_editing_index >= 0 and _classroom_editing_index < _classroom_data.size() else -1
			construction.blocked_cells = _get_classroom_blocked_cells(cls_building_idx) if cls_building_idx >= 0 else _get_occupied_cells(camera.current_floor)
			construction.render_preview()
			construction.painted_preview_cells.clear()
			hud_message("Left-click to add tiles, right-click to delete. Corridor tiles will be replaced.")
		"move_rotate":
			_building_edit_original_cells = construction.editing_cells.duplicate()
			_building_edit_centroid = _calc_centroid(construction.editing_cells)
			_building_edit_rotation_count = 0
			_building_edit_translation = Vector2i.ZERO
			construction.current_tool = "move_rotate"
			construction.render_preview()
			hud_message("Left-click & drag to move, middle-click to rotate.")
		"rename":
			_rename_classroom()
		"demolish":
			_demolish_classroom()

func _transform_door_cell(cell: Vector2i, centroid: Vector2, rotation_count: int) -> Vector2i:
	var k = rotation_count % 4
	if k == 0:
		return cell
	var lx = cell.x - centroid.x
	var ly = cell.y - centroid.y
	match k:
		1:
			return Vector2i(roundi(centroid.x - ly), roundi(centroid.y + lx))
		2:
			return Vector2i(roundi(centroid.x - lx), roundi(centroid.y - ly))
		3:
			return Vector2i(roundi(centroid.x + ly), roundi(centroid.y - lx))
	return cell

func _rotate_edge_normal(normal: Vector2i, rotation_count: int) -> Vector2i:
	var k = rotation_count % 4
	match k:
		0:
			return normal
		1:
			return Vector2i(-normal.y, normal.x)
		2:
			return Vector2i(-normal.x, -normal.y)
		3:
			return Vector2i(normal.y, -normal.x)
	return normal

func _confirm_classroom_edit() -> void:
	_editing_action = ""
	construction.blocked_cells.clear()
	if _classroom_editing_index < 0 or _classroom_editing_index >= _classroom_data.size():
		return
	var idx = _classroom_editing_index
	var final_cells = construction.apply_edit()
	var cls = _classroom_data[idx]
	_clear_classroom_tiles(cls.cells)
	cls.cells = final_cells
	_set_classroom_tiles(final_cells)
	# Remove corridor tiles that overlap with the new classroom cells
	for i in range(_corridor_data.size()):
		var corr = _corridor_data[i]
		var to_remove: Array[Vector2i] = []
		for c in corr.cells:
			if c in final_cells:
				to_remove.append(c)
		if to_remove.size() > 0:
			for c in to_remove:
				corr.cells.erase(c)
			_clear_corridor_tiles(to_remove)
	var label = cls.label
	if label:
		var centroid = Vector2.ZERO
		for cell in final_cells:
			centroid += Vector2(cell.x, cell.y)
		centroid /= final_cells.size()
		var world_pos = centroid * TILE_SIZE + Vector2(TILE_SIZE / 2, TILE_SIZE / 2)
		var font = label.get_theme_font("font")
		if not font:
			font = ThemeDB.fallback_font
		var font_size = label.get_theme_font_size("font_size")
		if font_size <= 0:
			font_size = 18
		var text_size = font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		label.position = world_pos - Vector2(text_size.x / 2, text_size.y / 2) + Vector2(0, -36)
	for d in range(_door_data.size()):
		var door = _door_data[d]
		if door.classroom_index == idx and door.building_index == cls.building_index:
			var old_cell = door.cell
			door.cell = _transform_door_cell(door.cell, _building_edit_centroid, _building_edit_rotation_count) + _building_edit_translation
			door.edge_normal = _rotate_edge_normal(door.edge_normal, _building_edit_rotation_count)
			if old_cell != door.cell:
				_clear_door_visual_by_cell(old_cell)
	_is_classroom_edit = false
	_classroom_editing_index = -1
	_update_door_visuals()
	_update_edge_lines()
	_update_confirmed_visuals()
	_close_edit_dialog()

func _cancel_classroom_edit() -> void:
	_editing_action = ""
	construction.blocked_cells.clear()
	construction.cancel_edit()
	_is_classroom_edit = false
	_classroom_editing_index = -1
	_update_confirmed_visuals()
	_close_edit_dialog()

func _rename_classroom() -> void:
	var idx = _classroom_editing_index
	if idx < 0 or idx >= _classroom_data.size():
		return
	var cls = _classroom_data[idx]
	var hud = find_child("InGameHUD", true, false) as CanvasLayer
	if hud and hud.has_method("show_building_rename_dialog"):
		hud.show_building_rename_dialog(cls.name, func(confirmed: bool, new_name: String):
			if not confirmed:
				return
			cls.name = new_name
			cls.label.text = new_name
			var centroid = Vector2.ZERO
			for cell in cls.cells:
				centroid += Vector2(cell.x, cell.y)
			centroid /= cls.cells.size()
			var world_pos = centroid * TILE_SIZE + Vector2(TILE_SIZE / 2, TILE_SIZE / 2)
			var font = cls.label.get_theme_font("font")
			if not font:
				font = ThemeDB.fallback_font
			var font_size = cls.label.get_theme_font_size("font_size")
			if font_size <= 0:
				font_size = 18
			var text_size = font.get_string_size(cls.label.text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
			cls.label.position = world_pos - Vector2(text_size.x / 2, text_size.y / 2) + Vector2(0, -36)
		)

func _demolish_classroom() -> void:
	var idx = _classroom_editing_index
	if idx < 0 or idx >= _classroom_data.size():
		return
	var confirm = ConfirmationDialog.new()
	confirm.dialog_text = "Demolish this classroom? This cannot be undone."
	confirm.confirmed.connect(func():
		_do_demolish_classroom(idx)
		if is_instance_valid(confirm):
			confirm.queue_free()
	)
	confirm.canceled.connect(func():
		if is_instance_valid(confirm):
			confirm.queue_free()
	)
	add_child(confirm)
	confirm.popup_centered()

func _do_demolish_classroom(idx: int) -> void:
	if idx >= _classroom_data.size():
		return
	var cls = _classroom_data[idx]
	_remove_doors_for_classroom(idx, cls.building_index)
	cls.label.queue_free()
	_clear_classroom_tiles(cls.cells)
	_classroom_data.remove_at(idx)
	construction.blocked_cells.clear()
	construction.cancel_edit()
	_is_classroom_edit = false
	_classroom_editing_index = -1
	_close_edit_dialog()
	_update_edge_lines()
	_update_confirmed_visuals()

func _start_building_edit(index: int) -> void:
	_close_edit_dialog()
	var b = _building_data[index]
	_building_edit_original_cells = b.cells.duplicate()
	_building_edit_classroom_entries.clear()
	for cls in _classroom_data:
		if cls.building_index == index:
			_building_edit_classroom_entries.append({"original_cells": cls.cells.duplicate(), "ref": cls, "prev_preview_cells": []})
	_building_edit_cleared_originals = false
	_building_edit_rotation_count = 0
	_building_edit_centroid = _calc_centroid(b.cells)
	_building_edit_translation = Vector2i.ZERO
	construction.begin_edit(index, b.cells)
	_editing_action = ""
	_is_classroom_edit = false
	_classroom_editing_index = -1
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
			_building_edit_centroid = _calc_centroid(construction.editing_cells)
			_building_edit_rotation_count = 0
			_building_edit_translation = Vector2i.ZERO
			construction.current_tool = "tiles"
			construction.blocked_cells = _get_all_cells_except(construction.editing_building_index) if construction.editing_building_index >= 0 else _get_occupied_cells(camera.current_floor)
			construction.render_preview()
			construction.painted_preview_cells.clear()
			hud_message("Left-click to add tiles, right-click to delete.")
		"move_rotate":
			_building_edit_original_cells = construction.editing_cells.duplicate()
			_building_edit_centroid = _calc_centroid(construction.editing_cells)
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
	if idx < 0 or idx >= _building_data.size():
		return
	var b = _building_data[idx]
	var hud = find_child("InGameHUD", true, false) as CanvasLayer
	if hud and hud.has_method("show_building_rename_dialog"):
		hud.show_building_rename_dialog(b.name, func(confirmed: bool, new_name: String):
			if not confirmed:
				return
			b.name = new_name
			b.label.text = new_name
			var centroid = Vector2.ZERO
			for cell in b.cells:
				centroid += Vector2(cell.x, cell.y)
			centroid /= b.cells.size()
			var world_pos = centroid * TILE_SIZE + Vector2(TILE_SIZE / 2, TILE_SIZE / 2)
			var font = b.label.get_theme_font("font")
			if not font:
				font = ThemeDB.fallback_font
			var font_size = b.label.get_theme_font_size("font_size")
			if font_size <= 0:
				font_size = 20
			var text_size = font.get_string_size(b.label.text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
			b.label.position = world_pos - Vector2(text_size.x / 2, text_size.y / 2)
		)

func _demolish_building() -> void:
	var idx = construction.editing_building_index
	if idx < 0 or idx >= _building_data.size():
		return
	var confirm = ConfirmationDialog.new()
	confirm.dialog_text = "Demolish this building? This cannot be undone."
	confirm.confirmed.connect(func():
		_do_demolish(idx)
		if is_instance_valid(confirm):
			confirm.queue_free()
	)
	confirm.canceled.connect(func():
		if is_instance_valid(confirm):
			confirm.queue_free()
	)
	add_child(confirm)
	confirm.popup_centered()

func _do_demolish(idx: int) -> void:
	if idx >= _building_data.size():
		return
	var b = _building_data[idx]
	for cell in b.cells:
		field_layer.set_cell(cell, 0, Vector2i(0, 0))
	b.label.queue_free()

	_remove_doors_for_building(idx)
	var i = 0
	while i < _classroom_data.size():
		if _classroom_data[i].building_index == idx:
			_classroom_data[i].label.queue_free()
			_clear_classroom_tiles(_classroom_data[i].cells)
			_classroom_data.remove_at(i)
		else:
			if _classroom_data[i].building_index > idx:
				_classroom_data[i].building_index -= 1
			i += 1

	i = 0
	while i < _corridor_data.size():
		if _corridor_data[i].building_index == idx:
			_clear_corridor_tiles(_corridor_data[i].cells)
			_corridor_data.remove_at(i)
		else:
			if _corridor_data[i].building_index > idx:
				_corridor_data[i].building_index -= 1
			i += 1

	_building_data.remove_at(idx)
	construction.blocked_cells.clear()
	construction.cancel_edit()
	_close_edit_dialog()
	_update_edge_lines()
	_update_confirmed_visuals()

func _calc_centroid(cells: Array[Vector2i]) -> Vector2:
	var cx := 0.0
	var cy := 0.0
	for cell in cells:
		cx += cell.x
		cy += cell.y
	return Vector2(cx / cells.size(), cy / cells.size())

func _rotate_cells_around(cells: Array[Vector2i], centroid: Vector2, count: int) -> Array[Vector2i]:
	var k = count % 4
	if k == 0:
		return cells.duplicate()
	var result: Array[Vector2i] = []
	for cell in cells:
		var local_x = cell.x - centroid.x
		var local_y = cell.y - centroid.y
		var tx: float
		var ty: float
		match k:
			1:
				tx = centroid.x - local_y
				ty = centroid.y + local_x
			2:
				tx = centroid.x - local_x
				ty = centroid.y - local_y
			3:
				tx = centroid.x + local_y
				ty = centroid.y - local_x
		result.append(Vector2i(roundi(tx), roundi(ty)))
	return result

func _transform_building_edit_classroom_cell(cell: Vector2i) -> Vector2i:
	var k = _building_edit_rotation_count % 4
	if k == 0:
		return cell
	var local_x = cell.x - _building_edit_centroid.x
	var local_y = cell.y - _building_edit_centroid.y
	match k:
		1:
			return Vector2i(roundi(_building_edit_centroid.x - local_y), roundi(_building_edit_centroid.y + local_x))
		2:
			return Vector2i(roundi(_building_edit_centroid.x - local_x), roundi(_building_edit_centroid.y - local_y))
		3:
			return Vector2i(roundi(_building_edit_centroid.x + local_y), roundi(_building_edit_centroid.y - local_x))
	return cell

func _clear_building_edit_preview_tiles() -> void:
	for entry in _building_edit_classroom_entries:
		for cell in entry.prev_preview_cells:
			classroom_layer.erase_cell(cell)
		entry.prev_preview_cells.clear()

func _restore_building_edit_original_tiles() -> void:
	if _building_edit_cleared_originals:
		for entry in _building_edit_classroom_entries:
			for cell in entry.original_cells:
				classroom_layer.set_cell(cell, 0, Vector2i(1, 0))
		_building_edit_cleared_originals = false

func _update_building_edit_classroom_preview(offset: Vector2i) -> void:
	if _building_edit_classroom_entries.is_empty():
		return
	_clear_building_edit_preview_tiles()
	if not _building_edit_cleared_originals:
		for entry in _building_edit_classroom_entries:
			for cell in entry.original_cells:
				classroom_layer.erase_cell(cell)
		_building_edit_cleared_originals = true
	for entry in _building_edit_classroom_entries:
		for cell in entry.original_cells:
			var transformed = _transform_building_edit_classroom_cell(cell) + offset
			classroom_layer.set_cell(transformed, 0, Vector2i(1, 0))
			entry.prev_preview_cells.append(transformed)

func _apply_building_edit_classroom_changes(offset: Vector2i) -> void:
	_clear_building_edit_preview_tiles()
	for entry in _building_edit_classroom_entries:
		var new_cells: Array[Vector2i] = []
		for cell in entry.original_cells:
			new_cells.append(_transform_building_edit_classroom_cell(cell) + offset)
		entry.ref.cells = new_cells
		_set_classroom_tiles(new_cells)
		var label = entry.ref.label as Label
		if label:
			var centroid = Vector2.ZERO
			for cell in new_cells:
				centroid += Vector2(cell.x, cell.y)
			centroid /= new_cells.size()
			var world_pos = centroid * TILE_SIZE + Vector2(TILE_SIZE / 2, TILE_SIZE / 2)
			var font = label.get_theme_font("font")
			if not font:
				font = ThemeDB.fallback_font
			var font_size = label.get_theme_font_size("font_size")
			if font_size <= 0:
				font_size = 18
			var text_size = font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
			label.position = world_pos - Vector2(text_size.x / 2, text_size.y / 2) + Vector2(0, -36)
	_building_edit_classroom_entries.clear()
	_building_edit_rotation_count = 0
	_building_edit_cleared_originals = false

func hud_message(msg: String) -> void:
	var hud = find_child("InGameHUD", true, false) as CanvasLayer
	if hud and hud.has_method("show_hud_message"):
		hud.show_hud_message(msg)

func _close_edit_dialog() -> void:
	if _building_edit_dialog and is_instance_valid(_building_edit_dialog.window):
		_building_edit_dialog.window.queue_free()

func _confirm_building_edit() -> void:
	_editing_action = ""
	construction.blocked_cells.clear()
	if construction.editing_building_index == -1:
		return
	var idx = construction.editing_building_index
	var final_cells = construction.apply_edit()

	# Clear old tiles from field_layer and place new ones
	var old_cells = _building_data[idx].cells
	var atlas = _building_atlas_coord()
	for cell in old_cells:
		field_layer.set_cell(cell, 0, Vector2i(0, 0))
	for cell in final_cells:
		field_layer.set_cell(cell, 0, atlas)

	_building_data[idx].cells = final_cells

	# Transform doors attached to this building (before classroom changes reset rotation_count)
	var door_rotation = _building_edit_rotation_count
	var door_translation = _building_edit_translation
	for d in range(_door_data.size()):
		var door = _door_data[d]
		if door.building_index == idx:
			var old_cell = door.cell
			door.cell = _transform_door_cell(door.cell, _building_edit_centroid, door_rotation) + door_translation
			door.edge_normal = _rotate_edge_normal(door.edge_normal, door_rotation)
			if old_cell != door.cell:
				_clear_door_visual_by_cell(old_cell)

	# Transform corridors attached to this building
	for c in range(_corridor_data.size()):
		var corr = _corridor_data[c]
		if corr.building_index == idx:
			var corr_old_cells = corr.cells.duplicate()
			_clear_corridor_tiles(corr_old_cells)
			var new_cells = _rotate_cells_around(corr_old_cells, _building_edit_centroid, door_rotation)
			for i in range(new_cells.size()):
				new_cells[i] += door_translation
			corr.cells = new_cells
			_set_corridor_tiles(new_cells)

	# Apply same transformation to classrooms in this building
	if _building_edit_original_cells.size() > 0:
		_apply_building_edit_classroom_changes(_building_edit_translation)
	_building_edit_original_cells.clear()

	_update_door_visuals()

	# Update building label position to new centroid
	var label = _building_data[idx].label as Label
	if label:
		var centroid = Vector2.ZERO
		for cell in final_cells:
			centroid += Vector2(cell.x, cell.y)
		centroid /= final_cells.size()
		var world_pos = centroid * TILE_SIZE + Vector2(TILE_SIZE / 2, TILE_SIZE / 2)
		var font = label.get_theme_font("font")
		if not font:
			font = ThemeDB.fallback_font
		var font_size = label.get_theme_font_size("font_size")
		if font_size <= 0:
			font_size = 20
		var text_size = font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		label.position = world_pos - Vector2(text_size.x / 2, text_size.y / 2)

	_update_edge_lines()
	_update_confirmed_visuals()
	_close_edit_dialog()

func _cancel_building_edit() -> void:
	_editing_action = ""
	construction.blocked_cells.clear()
	_clear_building_edit_preview_tiles()
	_restore_building_edit_original_tiles()
	_building_edit_classroom_entries.clear()
	_building_edit_original_cells.clear()
	_building_edit_rotation_count = 0
	_building_edit_translation = Vector2i.ZERO
	construction.cancel_edit()
	_update_confirmed_visuals()
	_close_edit_dialog()

func _update_confirmed_visuals() -> void:
	for child in confirmed_container.get_children():
		child.queue_free()
	for child in _classroom_container.get_children():
		child.queue_free()

	for i in range(_building_data.size()):
		var b = _building_data[i]
		var cells_to_show = b.cells
		if not _is_classroom_edit and construction.current_state == ConstructionState.State.EDITING and construction.editing_building_index == i:
			cells_to_show = construction.editing_cells
		for cell in cells_to_show:
			var has_classroom = _get_classroom_at_cell(cell) >= 0
			if GlobalTransferData.current_mode == GlobalTransferData.GameMode.ARCHITECTURAL and has_classroom:
				continue
			var color = Color("#94a3b8") if GlobalTransferData.current_mode == GlobalTransferData.GameMode.ARCHITECTURAL else ConstructionState.CONFIRMED_COLOR
			construction._make_tile_rect(cell, color, confirmed_container)

	for i in range(_classroom_data.size()):
		var cls = _classroom_data[i]
		if _is_classroom_edit and construction.current_state == ConstructionState.State.EDITING and _classroom_editing_index == i:
			for cell in construction.editing_cells:
				construction._make_tile_rect(cell, Color(0.3, 0.8, 0.3, 0.4), _classroom_container)
	if _is_corridor_edit and construction.current_state == ConstructionState.State.EDITING and _corridor_editing_index >= 0:
		for cell in _corridor_edit_overlay_cells:
			corridor_layer.erase_cell(cell)
		_corridor_edit_overlay_cells = construction.editing_cells.duplicate()
		for cell in _corridor_edit_overlay_cells:
			corridor_layer.set_cell(cell, 0, Vector2i(1, 0))
	_update_edge_lines()

# ========== EDGE LINE VISUALS ==========

func _add_edge_strip(cell: Vector2i, d: Vector2i, lw: float, color: Color) -> void:
	var cell_pos = Vector2(cell.x * TILE_SIZE, cell.y * TILE_SIZE)
	var edge = ColorRect.new()
	edge.color = color
	edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	edge.position = cell_pos
	if d.y != 0:
		var y = 0.0 if d.y < 0 else TILE_SIZE as float - lw + 1
		edge.position.y += y
		edge.size = Vector2(TILE_SIZE, lw)
	else:
		var x = 0.0 if d.x < 0 else TILE_SIZE as float - lw + 1
		edge.position.x += x
		edge.size = Vector2(lw, TILE_SIZE)
	_edge_line_container.add_child(edge)

func _update_edge_lines() -> void:
	for child in _edge_line_container.get_children():
		_edge_line_container.remove_child(child)
		child.queue_free()

	var lw = 6.0

	# Building exterior edges
	for b in _building_data:
		var b_cells: Dictionary = {}
		for c in b.cells:
			b_cells[c] = true
		for cell in b.cells:
			for d in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
				var neighbor = cell + d
				if not b_cells.has(neighbor):
					_add_edge_strip(cell, d, lw, Color(1, 1, 1, 0.4))

	# Classroom interior edges
	for cls in _classroom_data:
		var cls_cells: Dictionary = {}
		for c in cls.cells:
			cls_cells[c] = true
		for cell in cls.cells:
			for d in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
				var neighbor = cell + d
				if not cls_cells.has(neighbor):
					_add_edge_strip(cell, d, lw, Color(1, 0.9, 0.5, 0.5))

# ========== DOOR SYSTEM ==========

func _is_door_item(item_name: String) -> bool:
	return item_name == "Single Door"

func _is_corridor_item(item_name: String) -> bool:
	return item_name == "Campus Hallway"

func _get_corridor_at_cell(cell: Vector2i) -> int:
	for i in range(_corridor_data.size()):
		if cell in _corridor_data[i].cells:
			return i
	return -1

func _get_corridor_building_index(cell: Vector2i) -> int:
	var idx = _get_corridor_at_cell(cell)
	if idx >= 0:
		return _corridor_data[idx].building_index
	return -1

func _get_valid_corridor_cells(building_idx: int) -> Array[Vector2i]:
	var bld = _building_data[building_idx]
	var result: Array[Vector2i] = []
	var all_classroom_cells: Dictionary = {}
	for cls in _classroom_data:
		if cls.building_index == building_idx:
			for c in cls.cells:
				all_classroom_cells[c] = true
	for cell in bld.cells:
		if not all_classroom_cells.has(cell) and _get_corridor_at_cell(cell) < 0:
			result.append(cell)
	return result

func _set_corridor_tiles(cells: Array[Vector2i]) -> void:
	for cell in cells:
		corridor_layer.set_cell(cell, 0, Vector2i(1, 0))

func _clear_corridor_tiles(cells: Array[Vector2i]) -> void:
	for cell in cells:
		corridor_layer.erase_cell(cell)

func _restore_building_tiles(cells: Array[Vector2i]) -> void:
	var atlas = _building_atlas_coord()
	for cell in cells:
		if _get_building_at_cell(cell) >= 0:
			field_layer.set_cell(cell, 0, atlas)

func _is_cell_in_any_corridor(cell: Vector2i) -> bool:
	for corr in _corridor_data:
		if cell in corr.cells:
			return true
	return false

func _get_door_at_cell(cell: Vector2i) -> int:
	for i in range(_door_data.size()):
		if _door_data[i].cell == cell:
			return i
	return -1

func _get_valid_door_placement(cell: Vector2i) -> Dictionary:
	var result = {"valid": false, "edge_normal": Vector2i.ZERO, "building_index": -1, "classroom_index": -1}
	if _get_door_at_cell(cell) >= 0:
		return result
	var cls_idx = _get_classroom_at_cell(cell)
	if cls_idx >= 0:
		var cls = _classroom_data[cls_idx]
		var bld = _building_data[cls.building_index]
		for d in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
			var neighbor = cell + d
			if neighbor not in cls.cells and neighbor in bld.cells:
				var outside_count = 0
				for d2 in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
					if cell + d2 not in cls.cells:
						outside_count += 1
				if outside_count == 1:
					result.valid = true
					result.edge_normal = d
					result.building_index = cls.building_index
					result.classroom_index = cls_idx
					return result
	var bld_idx = _get_building_at_cell(cell)
	if bld_idx >= 0 and cls_idx < 0:
		var bld = _building_data[bld_idx]
		for d in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
			if cell + d not in bld.cells:
				var outside_count = 0
				for d2 in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
					if cell + d2 not in bld.cells:
						outside_count += 1
				if outside_count == 1:
					result.valid = true
					result.edge_normal = d
					result.building_index = bld_idx
					result.classroom_index = -1
					return result
	return result

func _hover_door_preview(cell: Vector2i, edge_normal: Vector2i) -> void:
	if cell == _hover_door_cell:
		return
	_clear_hover_door_preview()
	_door_placement_preview_node.visible = true
	_draw_edge_preview(cell, edge_normal, _door_placement_preview_node)
	_hover_door_cell = cell

func _clear_hover_door_preview() -> void:
	_door_hover_tile_rect.visible = false
	_door_placement_preview_node.visible = false
	_hover_door_cell = Vector2i(-999, -999)
	for child in _door_placement_preview_node.get_children():
		_door_placement_preview_node.remove_child(child)
		child.queue_free()

func _draw_edge_preview(cell: Vector2i, edge_normal: Vector2i, parent: Node2D) -> void:
	var edge_node = Node2D.new()
	edge_node.position = Vector2(cell.x * TILE_SIZE, cell.y * TILE_SIZE)
	parent.add_child(edge_node)
	var strip_width = 12
	if edge_normal.y != 0:
		var strip = ColorRect.new()
		strip.size = Vector2(TILE_SIZE, strip_width)
		strip.color = Color(1, 1, 1, 0.9)
		strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if edge_normal.y > 0:
			strip.position = Vector2(0, TILE_SIZE - strip_width)
		else:
			strip.position = Vector2(0, 0)
		edge_node.add_child(strip)
	else:
		var strip = ColorRect.new()
		strip.size = Vector2(strip_width, TILE_SIZE)
		strip.color = Color(1, 1, 1, 0.9)
		strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if edge_normal.x > 0:
			strip.position = Vector2(TILE_SIZE - strip_width, 0)
		else:
			strip.position = Vector2(0, 0)
		edge_node.add_child(strip)

func _toggle_door_direction() -> void:
	_door_placement_is_inward = not _door_placement_is_inward
	var cell = _cell_under_mouse()
	var info = _get_valid_door_placement(cell)
	if info.valid:
		_clear_hover_door_preview()
		_door_hover_tile_rect.visible = true
		_door_placement_preview_node.visible = true
		_draw_edge_preview(cell, info.edge_normal, _door_placement_preview_node)
		_hover_door_cell = cell

func _start_door_placement(cell: Vector2i) -> void:
	var info = _get_valid_door_placement(cell)
	if not info.valid:
		return
	_door_counter += 1
	var name = "Door #%d" % _door_counter
	_clear_hover_door_preview()
	_finalize_door(name, cell, info.edge_normal, _door_placement_is_inward, info.building_index, info.classroom_index)
	hud_message("Placed %s" % name)

func _finalize_door(name: String, cell: Vector2i, edge_normal: Vector2i, is_inward: bool, building_idx: int, classroom_idx: int) -> void:
	var label = _create_door_label(name, cell)
	_door_data.append({
		"name": name,
		"cell": cell,
		"edge_normal": edge_normal,
		"is_inward": is_inward,
		"building_index": building_idx,
		"classroom_index": classroom_idx,
		"label": label
	})
	_draw_door_symbol(cell, edge_normal, is_inward, _door_container, Color.BLACK)

func _create_door_label(name: String, cell: Vector2i) -> Label:
	return null

func _draw_door_symbol(cell: Vector2i, edge_normal: Vector2i, is_inward: bool, parent: Node2D, color: Color = Color.BLACK) -> void:
	var s = DoorSymbol.new()
	s.position = Vector2(cell.x * TILE_SIZE, cell.y * TILE_SIZE)
	s.edge_normal = edge_normal
	s.is_inward = is_inward
	s.draw_color = color
	parent.add_child(s)
	s.queue_redraw()

func _start_door_edit(index: int) -> void:
	_close_edit_dialog()
	var door = _door_data[index]
	_is_door_edit = true
	_door_editing_index = index
	_building_edit_dialog = BuildingEditDialog.new()
	_building_edit_dialog.show(
		self,
		door.name,
		_on_door_edit_action,
		_confirm_door_edit,
		_cancel_door_edit,
		"door"
	)
	hud_message("Editing %s" % door.name)

func _start_corridor_placement(cells: Array[Vector2i]) -> void:
	if cells.is_empty():
		return
	var building_idx = _get_building_at_cell(cells[0])
	if building_idx < 0:
		return
	_corridor_counter += 1
	var name = "Corridor #%d" % _corridor_counter
	_corridor_data.append({"name": name, "cells": cells.duplicate(), "building_index": building_idx})
	_set_corridor_tiles(cells)
	hud_message("Placed %s" % name)

func _confirm_corridor_placement() -> void:
	var cells = construction.staged_cells.duplicate()
	var filtered: Array[Vector2i] = []
	var building_idx = -1
	for cell in cells:
		var b_idx = _get_building_at_cell(cell)
		if b_idx >= 0 and _get_classroom_at_cell(cell) < 0:
			var corr_idx = _get_corridor_at_cell(cell)
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
	_set_corridor_tiles(filtered)
	_corridor_counter += 1
	var name = "Corridor #%d" % _corridor_counter
	_corridor_data.append({"name": name, "cells": filtered, "building_index": building_idx})
	construction.staged_cells.clear()
	construction.current_state = ConstructionState.State.IDLE
	_remove_confirmation_widget()
	_update_edge_lines()
	hud_message("Placed %s" % name)

func _start_corridor_edit(index: int) -> void:
	_close_edit_dialog()
	var corr = _corridor_data[index]
	_is_classroom_edit = false
	_classroom_editing_index = -1
	_is_corridor_edit = true
	_corridor_editing_index = index
	var building_idx = corr.building_index
	_building_edit_dialog = BuildingEditDialog.new()
	_building_edit_dialog.show(
		self,
		corr.name,
		_on_corridor_edit_action,
		_confirm_corridor_edit,
		_cancel_corridor_edit,
		"corridor"
	)
	construction.begin_edit(building_idx, corr.cells)
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
			var corr = _corridor_data[_corridor_editing_index]
			construction.blocked_cells = _get_blocked_cells_for_corridor()
			construction.render_preview()
			hud_message("Click to add tiles, right-click to remove")
		"demolish":
			_demolish_corridor()

func _confirm_corridor_edit() -> void:
	_editing_action = ""
	construction.blocked_cells.clear()
	_corridor_edit_overlay_cells.clear()
	if _corridor_editing_index < 0 or _corridor_editing_index >= _corridor_data.size():
		return
	var idx = _corridor_editing_index
	var final_cells = construction.apply_edit()
	var corr = _corridor_data[idx]
	_clear_corridor_tiles(corr.cells)
	corr.cells = final_cells
	_set_corridor_tiles(final_cells)
	_is_corridor_edit = false
	_corridor_editing_index = -1
	_update_edge_lines()
	_update_confirmed_visuals()
	_close_edit_dialog()

func _cancel_corridor_edit() -> void:
	_editing_action = ""
	construction.blocked_cells.clear()
	_corridor_edit_overlay_cells.clear()
	if _corridor_editing_index >= 0 and _corridor_editing_index < _corridor_data.size():
		var corr = _corridor_data[_corridor_editing_index]
		var current = construction.editing_cells.duplicate()
		construction.cancel_edit()
		for cell in current:
			if cell not in corr.cells:
				corridor_layer.erase_cell(cell)
		_clear_corridor_tiles(corr.cells)
		_set_corridor_tiles(corr.cells)
	else:
		construction.cancel_edit()
	_is_corridor_edit = false
	_corridor_editing_index = -1
	_update_confirmed_visuals()
	_close_edit_dialog()

func _demolish_corridor() -> void:
	var idx = _corridor_editing_index
	if idx < 0 or idx >= _corridor_data.size():
		return
	var confirm = ConfirmationDialog.new()
	confirm.dialog_text = "Remove this corridor? This cannot be undone."
	confirm.confirmed.connect(func():
		_do_demolish_corridor(idx)
		if is_instance_valid(confirm):
			confirm.queue_free()
	)
	confirm.canceled.connect(func():
		if is_instance_valid(confirm):
			confirm.queue_free()
	)
	add_child(confirm)
	confirm.popup_centered()

func _do_demolish_corridor(idx: int) -> void:
	if idx >= _corridor_data.size():
		return
	var corr = _corridor_data[idx]
	_is_corridor_edit = false
	_corridor_editing_index = -1
	_corridor_edit_overlay_cells.clear()
	_editing_action = ""
	construction.cancel_edit()
	construction.blocked_cells.clear()
	_clear_corridor_tiles(corr.cells)
	_corridor_data.remove_at(idx)
	_close_edit_dialog()
	_update_edge_lines()
	_update_confirmed_visuals()
	hud_message("Corridor removed")

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
	_update_door_visuals()
	_update_confirmed_visuals()
	_close_edit_dialog()

func _cancel_door_edit() -> void:
	_editing_action = ""
	construction.blocked_cells.clear()
	_reset_door_replacement_state()
	if _door_editing_index >= 0 and _door_editing_index < _door_data.size():
		var door = _door_data[_door_editing_index]
		_redraw_door(door)
	_is_door_edit = false
	_door_editing_index = -1
	_close_edit_dialog()

func _rename_door() -> void:
	var idx = _door_editing_index
	if idx < 0 or idx >= _door_data.size():
		return
	var door = _door_data[idx]
	var hud = find_child("InGameHUD", true, false) as CanvasLayer
	if hud and hud.has_method("show_building_rename_dialog"):
		hud.show_building_rename_dialog(door.name, func(confirmed: bool, new_name: String):
			if not confirmed:
				return
			door.name = new_name
			if door.label:
				door.label.text = new_name
				_redraw_door_label(door)
		)

func _demolish_door() -> void:
	var idx = _door_editing_index
	if idx < 0 or idx >= _door_data.size():
		return
	var confirm = ConfirmationDialog.new()
	confirm.dialog_text = "Remove this door? This cannot be undone."
	confirm.confirmed.connect(func():
		_do_demolish_door(idx)
		if is_instance_valid(confirm):
			confirm.queue_free()
	)
	confirm.canceled.connect(func():
		if is_instance_valid(confirm):
			confirm.queue_free()
	)
	add_child(confirm)
	confirm.popup_centered()

func _do_demolish_door(idx: int) -> void:
	if idx >= _door_data.size():
		return
	_is_door_edit = false
	_door_editing_index = -1
	var door = _door_data[idx]
	if door.label:
		door.label.queue_free()
	_clear_door_visual(door)
	_door_data.remove_at(idx)
	_reset_door_replacement_state()
	_close_edit_dialog()
	_update_door_visuals()
	_update_confirmed_visuals()

func _clear_door_visual(door: Dictionary) -> void:
	_clear_door_visual_by_cell(door.cell)

func _clear_door_visual_by_cell(cell: Vector2i) -> void:
	for child in _door_container.get_children():
		if child is Node2D and child.position == Vector2(cell.x * TILE_SIZE, cell.y * TILE_SIZE):
			_door_container.remove_child(child)
			child.queue_free()

func _redraw_door(door: Dictionary) -> void:
	_clear_door_visual(door)
	_draw_door_symbol(door.cell, door.edge_normal, door.is_inward, _door_container, Color.BLACK)

func _redraw_door_label(door: Dictionary) -> void:
	var cell = door.cell
	var world_pos = Vector2(cell.x * TILE_SIZE + TILE_SIZE / 2, cell.y * TILE_SIZE + TILE_SIZE / 2)
	var label = door.label as Label
	if not label:
		return
	var font = label.get_theme_font("font")
	if not font:
		font = ThemeDB.fallback_font
	var font_size = label.get_theme_font_size("font_size")
	if font_size <= 0:
		font_size = 14
	var text_size = font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	label.position = world_pos - Vector2(text_size.x / 2, text_size.y / 2) + Vector2(0, -30)

func _relocate_door_to(cell: Vector2i) -> void:
	var idx = _door_editing_index
	if idx < 0 or idx >= _door_data.size():
		return
	var door = _door_data[idx]
	if cell == door.cell:
		return
	var info = _get_valid_door_placement(cell)
	if not info.valid:
		hud_message("Door must be placed at the edge of a building or classroom")
		return
	_clear_door_visual(door)
	door.cell = cell
	door.edge_normal = info.edge_normal
	door.building_index = info.building_index
	door.classroom_index = info.classroom_index
	_redraw_door(door)
	_redraw_door_label(door)
	_update_confirmed_visuals()
	_reset_door_replacement_state()

func _reset_door_replacement_state() -> void:
	_door_placement_cell = Vector2i(-1, -1)
	for child in _door_placement_preview_node.get_children():
		_door_placement_preview_node.remove_child(child)
		child.queue_free()

func _update_door_visuals() -> void:
	for child in _door_container.get_children():
		_door_container.remove_child(child)
		child.queue_free()
	for door in _door_data:
		_draw_door_symbol(door.cell, door.edge_normal, door.is_inward, _door_container, Color.BLACK)

func _remove_doors_for_building(building_idx: int) -> void:
	var i = 0
	while i < _door_data.size():
		if _door_data[i].building_index == building_idx:
			if _door_data[i].label:
				_door_data[i].label.queue_free()
			_clear_door_visual(_door_data[i])
			_door_data.remove_at(i)
		else:
			if _door_data[i].building_index > building_idx:
				_door_data[i].building_index -= 1
			i += 1

func _remove_doors_for_classroom(classroom_idx: int, building_idx: int) -> void:
	var i = 0
	while i < _door_data.size():
		if _door_data[i].classroom_index == classroom_idx and _door_data[i].building_index == building_idx:
			if _door_data[i].label:
				_door_data[i].label.queue_free()
			_clear_door_visual(_door_data[i])
			_door_data.remove_at(i)
		else:
			if _door_data[i].classroom_index > classroom_idx:
				_door_data[i].classroom_index -= 1
			i += 1
