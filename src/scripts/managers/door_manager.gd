extends RefCounted
class_name DoorManager

var data: Array[Dictionary] = []
var counter: int = 0
var door_container: Node2D
var door_preview_container: Node2D
var building_manager = null
var room_manager = null
var _hover_cell: Vector2i = Vector2i(-999, -999)
var _is_inward: bool = true

func setup(container: Node2D, preview: Node2D, bld_mgr, rm_mgr) -> void:
	door_container = container
	door_preview_container = preview
	building_manager = bld_mgr
	room_manager = rm_mgr

func is_item(item_name: String) -> bool:
	return item_name == "Single Door"

func get_at_cell(cell: Vector2i) -> int:
	for i in range(data.size()):
		if data[i].cell == cell:
			return i
	return -1

func get_valid_placement(cell: Vector2i) -> Dictionary:
	var result = {"valid": false, "edge_normal": Vector2i.ZERO, "building_index": -1, "room_index": -1}
	if get_at_cell(cell) >= 0:
		return result
	var cls_idx = room_manager.get_at_cell(cell) if room_manager else -1
	if cls_idx >= 0:
		var cls = room_manager.get_entry(cls_idx)
		var bld = building_manager.get_entry(cls.building_index)
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
					result.room_index = cls_idx
					return result
	var bld_idx = building_manager.get_at_cell(cell)
	if bld_idx >= 0 and cls_idx < 0:
		var bld = building_manager.get_entry(bld_idx)
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
					result.room_index = -1
					return result
	return result

func toggle_direction() -> void:
	_is_inward = not _is_inward

func get_direction() -> bool:
	return _is_inward

func start_placement(cell: Vector2i, name: String, is_inward: bool, building_idx: int, room_idx: int) -> void:
	var info = get_valid_placement(cell)
	if not info.valid:
		return
	counter += 1
	var door_name = name if name != "" else "Door #%d" % counter
	finalize(door_name, cell, info.edge_normal, is_inward, info.building_index, info.room_index)

func finalize(name: String, cell: Vector2i, edge_normal: Vector2i, is_inward: bool, building_idx: int, room_idx: int) -> void:
	var label = null
	data.append({
		"name": name,
		"cell": cell,
		"edge_normal": edge_normal,
		"is_inward": is_inward,
		"building_index": building_idx,
		"room_index": room_idx,
		"label": label
	})
	draw_symbol(cell, edge_normal, is_inward, door_container, Color.BLACK)

func get_entry(index: int) -> Dictionary:
	return data[index]

func rename(index: int, new_name: String) -> void:
	if index >= 0 and index < data.size():
		data[index].name = new_name
		if data[index].label:
			data[index].label.text = new_name

func remove(index: int) -> Dictionary:
	var door = data[index]
	data.remove_at(index)
	return door

func remove_for_building(building_idx: int) -> void:
	var i = 0
	while i < data.size():
		if data[i].building_index == building_idx:
			var door = data[i]
			clear_visual(door)
			data.remove_at(i)
		else:
			if data[i].building_index > building_idx:
				data[i].building_index -= 1
			i += 1

func remove_for_room(room_idx: int, building_idx: int) -> void:
	var i = 0
	while i < data.size():
		if data[i].room_index == room_idx and data[i].building_index == building_idx:
			var door = data[i]
			clear_visual(door)
			data.remove_at(i)
		else:
			if data[i].room_index > room_idx:
				data[i].room_index -= 1
			i += 1

func draw_symbol(cell: Vector2i, edge_normal: Vector2i, is_inward: bool, parent: Node2D, color: Color) -> void:
	var s = preload("res://src/scripts/door_symbol.gd").new()
	s.position = Vector2(cell.x * 64, cell.y * 64)
	s.edge_normal = edge_normal
	s.is_inward = is_inward
	s.draw_color = color
	parent.add_child(s)
	s.queue_redraw()

func clear_visual(door: Dictionary) -> void:
	clear_visual_by_cell(door.cell)

func clear_visual_by_cell(cell: Vector2i) -> void:
	for child in door_container.get_children():
		if child is Node2D and child.position == Vector2(cell.x * 64, cell.y * 64):
			door_container.remove_child(child)
			child.queue_free()

func redraw(door: Dictionary) -> void:
	clear_visual(door)
	draw_symbol(door.cell, door.edge_normal, door.is_inward, door_container, Color.BLACK)

func redraw_all() -> void:
	for child in door_container.get_children():
		door_container.remove_child(child)
		child.queue_free()
	for door in data:
		draw_symbol(door.cell, door.edge_normal, door.is_inward, door_container, Color.BLACK)

func size() -> int:
	return data.size()
