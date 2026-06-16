extends Node
class_name RoomRegistry

static var _rooms: Dictionary = {}

static func register_room(room_type: String, cells: Array[Vector2i], name: String, building_idx: int, room_idx: int) -> void:
	if not _rooms.has(room_type):
		_rooms[room_type] = []
	_rooms[room_type].append({
		"cells": cells.duplicate(),
		"name": name,
		"building_index": building_idx,
		"room_index": room_idx
	})

static func unregister_room(room_idx: int, room_type: String) -> void:
	if not _rooms.has(room_type):
		return
	for i in range(_rooms[room_type].size() - 1, -1, -1):
		if _rooms[room_type][i].room_index == room_idx:
			_rooms[room_type].remove_at(i)
			return

static func get_all_cells_of_type(room_type: String) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if not _rooms.has(room_type):
		return result
	for entry in _rooms[room_type]:
		result.append_array(entry.cells)
	return result

static func get_random_cell_in(room_type: String) -> Vector2i:
	var cells = get_all_cells_of_type(room_type)
	if cells.is_empty():
		return Vector2i(-1, -1)
	return cells[randi() % cells.size()]

static func get_closest_cell(from_pos: Vector2i, room_type: String) -> Vector2i:
	var cells = get_all_cells_of_type(room_type)
	if cells.is_empty():
		return from_pos
	var best = cells[0]
	var best_dist = abs(from_pos.x - best.x) + abs(from_pos.y - best.y)
	for i in range(1, cells.size()):
		var c = cells[i]
		var d = abs(from_pos.x - c.x) + abs(from_pos.y - c.y)
		if d < best_dist:
			best_dist = d
			best = c
	return best

static func count_by_type(room_type: String) -> int:
	if not _rooms.has(room_type):
		return 0
	return _rooms[room_type].size()

static func has_room_type(room_type: String) -> bool:
	return _rooms.has(room_type) and not _rooms[room_type].is_empty()

static func get_all_room_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for room_type in _rooms:
		for entry in _rooms[room_type]:
			result.append_array(entry.cells)
	return result

static func get_entry(room_type: String, index: int) -> Dictionary:
	if not _rooms.has(room_type) or index < 0 or index >= _rooms[room_type].size():
		return {}
	return _rooms[room_type][index]

static func get_all_room_types() -> Array[String]:
	var types: Array[String] = []
	for room_type in _rooms:
		types.append(room_type)
	return types

static func get_all_cells_except_room_type(except_type: String) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for room_type in _rooms:
		if room_type == except_type:
			continue
		for entry in _rooms[room_type]:
			result.append_array(entry.cells)
	return result

static func clear_all() -> void:
	_rooms.clear()
