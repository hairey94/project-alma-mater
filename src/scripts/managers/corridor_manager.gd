extends RefCounted
class_name CorridorManager

var data: Array[Dictionary] = []
var counter: int = 0
var corridor_layer: TileMapLayer
var building_manager = null
var room_manager = null
var _hover_tile_cell: Vector2i = Vector2i(-999, -999)

func setup(layer: TileMapLayer, bld_mgr, rm_mgr) -> void:
	corridor_layer = layer
	building_manager = bld_mgr
	room_manager = rm_mgr

func add(name: String, cells: Array[Vector2i], building_idx: int) -> int:
	data.append({"name": name, "cells": cells.duplicate(), "building_index": building_idx})
	set_tiles(cells)
	return data.size() - 1

func remove(index: int) -> Dictionary:
	var corr = data[index]
	data.remove_at(index)
	return corr

func get_entry(index: int) -> Dictionary:
	return data[index]

func has_index(index: int) -> bool:
	return index >= 0 and index < data.size()

func size() -> int:
	return data.size()

func get_at_cell(cell: Vector2i) -> int:
	for i in range(data.size()):
		if cell in data[i].cells:
			return i
	return -1

func get_building_index_at_cell(cell: Vector2i) -> int:
	var idx = get_at_cell(cell)
	if idx >= 0:
		return data[idx].building_index
	return -1

func is_item(item_name: String) -> bool:
	return item_name == "Campus Hallway"

func get_blocked_cells(editing_index: int = -1, current_floor: int = 0) -> Array[Vector2i]:
	var blocked: Array[Vector2i] = []
	var building_cells: Array[Vector2i] = []
	for i in range(building_manager.size()):
		var b = building_manager.get_entry(i)
		if b.get("floor_level", 0) == current_floor:
			building_cells.append_array(b.cells)
	for x in range(64):
		for y in range(66):
			var c = Vector2i(x, y)
			if c not in building_cells:
				blocked.append(c)
	for i in range(room_manager.size()):
		var cls = room_manager.get_entry(i)
		for c in cls.cells:
			if c not in blocked:
				blocked.append(c)
	for i in range(data.size()):
		if editing_index >= 0 and i == editing_index:
			continue
		for c in data[i].cells:
			if c not in blocked:
				blocked.append(c)
	return blocked

func set_tiles(cells: Array[Vector2i]) -> void:
	for cell in cells:
		corridor_layer.set_cell(cell, 0, Vector2i(1, 0))

func clear_tiles(cells: Array[Vector2i]) -> void:
	for cell in cells:
		corridor_layer.erase_cell(cell)

func update_hover_tile(cell: Vector2i) -> void:
	if cell != _hover_tile_cell:
		clear_hover_tile()
		corridor_layer.set_cell(cell, 0, Vector2i(1, 0))
		_hover_tile_cell = cell

func clear_hover_tile() -> void:
	if _hover_tile_cell.x >= 0 and not is_cell_in_any(_hover_tile_cell):
		corridor_layer.erase_cell(_hover_tile_cell)
	_hover_tile_cell = Vector2i(-999, -999)

func is_cell_in_any(cell: Vector2i) -> bool:
	for corr in data:
		if cell in corr.cells:
			return true
	return false

func get_valid_cells(building_idx: int) -> Array[Vector2i]:
	var bld = building_manager.get_entry(building_idx)
	var result: Array[Vector2i] = []
	var all_classroom_cells: Dictionary = {}
	for i in range(room_manager.size()):
		var cls = room_manager.get_entry(i)
		if cls.building_index == building_idx:
			for c in cls.cells:
				all_classroom_cells[c] = true
	for cell in bld.cells:
		if not all_classroom_cells.has(cell) and get_at_cell(cell) < 0:
			result.append(cell)
	return result
