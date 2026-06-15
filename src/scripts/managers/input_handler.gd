extends RefCounted
class_name InputHandler

var map: Node2D
const MapUtils = preload("res://src/scripts/managers/map_utils.gd")

func setup(game_map: Node2D) -> void:
	map = game_map

func handle_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_MIDDLE and event.pressed:
		if map._is_door_item(map.construction.active_item_name) and map.construction.current_state == ConstructionState.State.IDLE:
			map._toggle_door_direction()
			map.get_viewport().set_input_as_handled()
			return
		if map._is_door_edit and map._door_editing_index >= 0:
			var door = map.door_mgr.get_entry(map._door_editing_index)
			door.is_inward = not door.is_inward
			map.door_mgr.redraw(door)
			map.hud_message("Door direction toggled to %s" % ("inward" if door.is_inward else "outward"))
			map.get_viewport().set_input_as_handled()
			return
		if map.construction.current_state == ConstructionState.State.EDITING and map.construction.editing_building_index >= 0 and map._editing_action in ["rotate", "move_rotate"]:
			_handle_rotate_from_edit(event)
			return
		if map.construction.current_state == ConstructionState.State.DRAGGING and map.construction.editing_building_index >= 0 and map._editing_action in ["rotate", "move_rotate"]:
			_handle_rotate_from_drag(event)
			return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		_handle_right_click(event)
		map.get_viewport().set_input_as_handled()

func _handle_rotate_from_edit(event: InputEvent) -> void:
	var cell = map._cell_under_mouse()
	if cell in map.construction.editing_cells:
		var other_cells = map.building_mgr.get_all_cells_except(map.construction.editing_building_index)
		var new_count = map._building_edit_rotation_count + 1
		var raw_rotated = MapUtils.rotate_cells_around(map._building_edit_original_cells, map._building_edit_centroid, new_count)
		var positioned: Array[Vector2i] = []
		for c in raw_rotated:
			positioned.append(c + map._building_edit_translation)
		var can_rotate = true
		for rc in positioned:
			if rc in other_cells or rc.x < 0 or rc.x >= 64 or rc.y < 0 or rc.y >= 64:
				can_rotate = false
				break
		var dedup: Array[Vector2i] = []
		for rc in positioned:
			if rc not in dedup:
				dedup.append(rc)
		if dedup.size() != positioned.size():
			can_rotate = false
		if can_rotate and map._is_room_edit and map._room_editing_index >= 0:
			var cls = map.room_mgr.get_entry(map._room_editing_index)
			if map.building_mgr.has_index(cls.building_index):
				var building_cells = map.building_mgr.get_entry(cls.building_index).cells
				for rc in positioned:
					if rc not in building_cells:
						can_rotate = false
						break
			else:
				can_rotate = false
		if can_rotate:
			map.construction.editing_cells = positioned
			map._building_edit_rotation_count = new_count
			map.construction.start_drag(map._corner_under_mouse())
		map.get_viewport().set_input_as_handled()

func _handle_rotate_from_drag(event: InputEvent) -> void:
	var other_cells = map.building_mgr.get_all_cells_except(map.construction.editing_building_index)
	var new_count = map._building_edit_rotation_count + 1
	var raw_rotated = MapUtils.rotate_cells_around(map._building_edit_original_cells, map._building_edit_centroid, new_count)
	var positioned: Array[Vector2i] = []
	for c in raw_rotated:
		positioned.append(c + map._building_edit_translation)
	var can_rotate = true
	for rc in positioned:
		if rc in other_cells or rc.x < 0 or rc.x >= 64 or rc.y < 0 or rc.y >= 64:
			can_rotate = false
			break
	var dedup: Array[Vector2i] = []
	for rc in positioned:
		if rc not in dedup:
			dedup.append(rc)
	if dedup.size() != positioned.size():
		can_rotate = false
	if can_rotate and map._is_room_edit and map._room_editing_index >= 0:
		var cls = map.room_mgr.get_entry(map._room_editing_index)
		if map.building_mgr.has_index(cls.building_index):
			var building_cells = map.building_mgr.get_entry(cls.building_index).cells
			for rc in positioned:
				if rc not in building_cells:
					can_rotate = false
					break
		else:
			can_rotate = false
	if can_rotate:
		map.construction.editing_cells = positioned
		map._building_edit_rotation_count = new_count
		map.construction.render_preview()
	map.get_viewport().set_input_as_handled()

func _handle_right_click(event: InputEvent) -> void:
	var cs = map.construction
	if cs.current_state == ConstructionState.State.DRAGGING and cs.editing_building_index >= 0:
		map._clear_building_edit_preview_tiles()
		map._restore_building_edit_original_tiles()
		cs.clear_preview_cells()
		cs.current_state = ConstructionState.State.EDITING
	elif cs.current_state == ConstructionState.State.EDITING:
		if map._editing_action == "add_delete":
			var cell = map._cell_under_mouse()
			var bounds = Rect2i(0, 0, 64, 64)
			if bounds.has_point(cell) and cell in cs.editing_cells:
				cs.remove_cell(cell)
				map._update_confirmed_visuals()
				map.get_viewport().set_input_as_handled()
				return
		if map._is_door_edit:
			var cell = map._cell_under_mouse()
			var bounds = Rect2i(0, 0, 64, 64)
			if bounds.has_point(cell):
				map._close_edit_dialog()
				cs.cancel_edit()
				map.get_viewport().set_input_as_handled()
				return
		map._editing_action = ""
		cs.painted_preview_cells.clear()
		cs.render_preview()
	elif cs.current_state == ConstructionState.State.PENDING_APPROVAL:
		var cell = map._cell_under_mouse()
		cs.remove_cell(cell)
		if map._classroom_placement_building_index >= 0:
			map.classroom_layer.erase_cell(cell)
		if map.corridor_mgr.is_item(map.construction.active_item_name):
			map.corridor_layer.erase_cell(cell)
		if cs.current_state == ConstructionState.State.IDLE:
			map._remove_confirmation_widget()
	elif cs.current_state == ConstructionState.State.DRAGGING and cs.current_tool == "tiles":
		var cell = map._cell_under_mouse()
		cs.remove_cell(cell)
		if map._classroom_placement_building_index >= 0:
			map.classroom_layer.erase_cell(cell)
		if map.corridor_mgr.is_item(map.construction.active_item_name):
			map.corridor_layer.erase_cell(cell)
	elif cs.current_state == ConstructionState.State.DRAGGING:
		map.cancel_placement()
	elif cs.current_state == ConstructionState.State.IDLE:
		if map._is_door_item(map.construction.active_item_name) or map.corridor_mgr.is_item(map.construction.active_item_name):
			_deselect_tool()
			return
		if map.construction.active_item_name == "":
			var cell = map._cell_under_mouse()
			var b_idx = map.building_mgr.get_at_cell(cell)
			if b_idx >= 0:
				map._start_building_edit(b_idx)
				map.get_viewport().set_input_as_handled()
				return
		_deselect_tool()
	map._is_bulldozing = false

func _deselect_tool() -> void:
	map.set_active_placement_item("")
	map.set_placement_tool("drag")
	map._editing_action = ""
	map._clear_hover_door_preview()
	map.corridor_mgr.clear_hover_tile()
	map._reset_door_replacement_state()
	map.construction.painted_preview_cells.clear()
	map.construction.blocked_cells.clear()
	map.construction.clear_preview_cells()
	var hud = map.find_child("InGameHUD", true, false)
	if hud and hud.has_method("deselect_toolbar"):
		hud.deselect_toolbar()
	map.hud_message("Tool deselected")
