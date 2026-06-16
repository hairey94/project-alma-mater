extends RefCounted
class_name RoomManager

const MapUtils = preload("res://src/scripts/managers/map_utils.gd")

const ROOM_TYPE_CLASSROOM = "Classroom"
const ROOM_TYPE_MALE_WASHROOM = "Male Student Washroom"
const ROOM_TYPE_FEMALE_WASHROOM = "Female Student Washroom"
const ROOM_TYPE_ADMIN_AREA = "Administration Area"
const ROOM_TYPE_PRINCIPAL_OFFICE = "Principal Office"
const ROOM_TYPE_CAFETERIA = "Cafeteria"

var data: Array[Dictionary] = []
var counters: Dictionary = {}
var labels_container: Node2D
var room_layer: TileMapLayer
var building_manager = null
var _principal_office_layer: TileMapLayer
var _principal_office_placed: bool = false
var _hover_tile_cell: Vector2i = Vector2i(-999, -999)

func setup(container: Node2D, layer: TileMapLayer, bld_mgr, principal_layer: TileMapLayer = null) -> void:
	labels_container = container
	room_layer = layer
	building_manager = bld_mgr
	_principal_office_layer = principal_layer

func add(name: String, cells: Array[Vector2i], building_idx: int, room_type: String, label: Label = null) -> int:
	data.append({"name": name, "cells": cells.duplicate(), "building_index": building_idx, "room_type": room_type, "label": label})
	if label and labels_container:
		labels_container.add_child(label)
	set_tiles(cells, room_type)
	return data.size() - 1

func remove(index: int) -> Dictionary:
	var cls = data[index]
	if cls.room_type == ROOM_TYPE_PRINCIPAL_OFFICE:
		_principal_office_placed = false
	data.remove_at(index)
	return cls

func get_entry(index: int) -> Dictionary:
	return data[index]

func has_index(index: int) -> bool:
	return index >= 0 and index < data.size()

func size() -> int:
	return data.size()

func get_at_cell(cell: Vector2i) -> int:
	for i in range(data.size()):
		if data[i].room_type == ROOM_TYPE_PRINCIPAL_OFFICE and cell in data[i].cells:
			return i
	for i in range(data.size()):
		if data[i].room_type != ROOM_TYPE_PRINCIPAL_OFFICE and cell in data[i].cells:
			return i
	return -1

func get_room_type_at_cell(cell: Vector2i) -> String:
	var idx = get_at_cell(cell)
	if idx >= 0:
		return data[idx].room_type
	return ""

func get_blocked_cells(building_idx: int, editing_index: int = -1) -> Array[Vector2i]:
	var blocked = building_manager.get_all_cells_except(building_idx) if building_manager else []
	for i in range(data.size()):
		var cls = data[i]
		if cls.building_index == building_idx:
			if editing_index >= 0 and i == editing_index:
				continue
			blocked.append_array(cls.cells)
	return blocked

func rename(index: int, new_name: String) -> void:
	if index >= 0 and index < data.size():
		data[index].name = new_name
		data[index].label.text = new_name

func update_label_position(index: int) -> void:
	if index >= 0 and index < data.size():
		var cls = data[index]
		var label = cls.label as Label
		if label:
			var offset_y = 36 if cls.room_type == ROOM_TYPE_PRINCIPAL_OFFICE else -36
			MapUtils.position_label(label, cls.cells, offset_y)

func get_admin_area_in_building(building_idx: int) -> int:
	for i in range(data.size()):
		if data[i].room_type == ROOM_TYPE_ADMIN_AREA and data[i].building_index == building_idx:
			return i
	return -1

func has_principal_office() -> bool:
	return _principal_office_placed

func set_principal_office_placed(placed: bool) -> void:
	_principal_office_placed = placed

func get_counter(room_type: String) -> int:
	if not counters.has(room_type):
		counters[room_type] = 0
	return counters[room_type]

func increment_counter(room_type: String) -> int:
	if not counters.has(room_type):
		counters[room_type] = 0
	counters[room_type] += 1
	return counters[room_type]

func default_name(room_type: String) -> String:
	if room_type == ROOM_TYPE_PRINCIPAL_OFFICE:
		return "Principal Office"
	var ct = get_counter(room_type) + 1
	match room_type:
		ROOM_TYPE_MALE_WASHROOM:
			return "Male Student Washroom #%d" % ct
		ROOM_TYPE_FEMALE_WASHROOM:
			return "Female Student Washroom #%d" % ct
		ROOM_TYPE_ADMIN_AREA:
			return "Administration Area #%d" % ct
		ROOM_TYPE_CAFETERIA:
			return "Cafeteria #%d" % ct
		_:
			return "Classroom #%d" % ct

func edit_title(room_type: String) -> String:
	match room_type:
		ROOM_TYPE_MALE_WASHROOM:
			return "Edit Male Student Washroom"
		ROOM_TYPE_FEMALE_WASHROOM:
			return "Edit Female Student Washroom"
		ROOM_TYPE_ADMIN_AREA:
			return "Edit Administration Area"
		ROOM_TYPE_PRINCIPAL_OFFICE:
			return "Edit Principal Office"
		ROOM_TYPE_CAFETERIA:
			return "Edit Cafeteria"
		_:
			return "Edit Classroom"

func get_atlas_for_room(room_type: String) -> Vector2i:
	match room_type:
		ROOM_TYPE_MALE_WASHROOM:
			return Vector2i(2, 0)
		ROOM_TYPE_FEMALE_WASHROOM:
			return Vector2i(2, 1)
		ROOM_TYPE_ADMIN_AREA:
			return Vector2i(0, 2)
		ROOM_TYPE_PRINCIPAL_OFFICE:
			return Vector2i(1, 2)
		ROOM_TYPE_CAFETERIA:
			var is_game = GlobalTransferData.current_mode == GlobalTransferData.GameMode.GAME
			return Vector2i(3, 2) if is_game else Vector2i(2, 2)
		_:
			var is_game = GlobalTransferData.current_mode == GlobalTransferData.GameMode.GAME
			return Vector2i(3, 1) if is_game else Vector2i(1, 0)

func set_tiles(cells: Array[Vector2i], room_type: String) -> void:
	var atlas = get_atlas_for_room(room_type)
	var layer = _principal_office_layer if room_type == ROOM_TYPE_PRINCIPAL_OFFICE and _principal_office_layer else room_layer
	for cell in cells:
		layer.set_cell(cell, 0, atlas)

func set_tiles_atlas(cells: Array[Vector2i], atlas: Vector2i) -> void:
	for cell in cells:
		room_layer.set_cell(cell, 0, atlas)

func clear_tiles(cells: Array[Vector2i], room_type: String = "") -> void:
	if room_type == ROOM_TYPE_PRINCIPAL_OFFICE and _principal_office_layer:
		for cell in cells:
			_principal_office_layer.erase_cell(cell)
	else:
		for cell in cells:
			room_layer.erase_cell(cell)

func update_hover_tile(cell: Vector2i, room_type: String) -> void:
	if cell != _hover_tile_cell:
		clear_hover_tile()
		var atlas = get_atlas_for_room(room_type)
		var layer = _principal_office_layer if room_type == ROOM_TYPE_PRINCIPAL_OFFICE and _principal_office_layer else room_layer
		layer.set_cell(cell, 0, atlas)
		_hover_tile_cell = cell

func clear_hover_tile() -> void:
	if _hover_tile_cell.x >= 0 and get_at_cell(_hover_tile_cell) < 0:
		room_layer.erase_cell(_hover_tile_cell)
		if _principal_office_layer:
			_principal_office_layer.erase_cell(_hover_tile_cell)
	_hover_tile_cell = Vector2i(-999, -999)

func switch_mode(mode: int, classroom_layer: TileMapLayer) -> void:
	if _principal_office_layer:
		_principal_office_layer.clear()
		for cls in data:
			if cls.room_type == ROOM_TYPE_PRINCIPAL_OFFICE:
				for cell in cls.cells:
					classroom_layer.erase_cell(cell)
	for cls in data:
		var atlas = get_atlas_for_room(cls.room_type)
		var redraw_layer = _principal_office_layer if cls.room_type == ROOM_TYPE_PRINCIPAL_OFFICE and _principal_office_layer else classroom_layer
		for cell in cls.cells:
			redraw_layer.set_cell(cell, 0, atlas)

func remove_doors_for_room(door_manager, room_idx: int, building_idx: int) -> void:
	if door_manager:
		door_manager.remove_for_room(room_idx, building_idx)

func remove_doors_for_classroom(door_manager, classroom_idx: int, building_idx: int) -> void:
	if door_manager:
		door_manager.remove_for_room(classroom_idx, building_idx)
