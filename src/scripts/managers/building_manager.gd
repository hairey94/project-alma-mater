extends RefCounted
class_name BuildingManager

const MapUtils = preload("res://src/scripts/managers/map_utils.gd")

var data: Array[Dictionary] = []
var counter: int = 0
var labels_container: Node2D

func setup(container: Node2D) -> void:
	labels_container = container

func add(name: String, cells: Array[Vector2i], floor_level: int = 0, label: Label = null) -> int:
	data.append({"name": name, "cells": cells.duplicate(), "label": label, "floor_level": floor_level})
	if label and labels_container:
		labels_container.add_child(label)
	return data.size() - 1

func remove(index: int) -> Dictionary:
	var b = data[index]
	data.remove_at(index)
	return b

func get_entry(index: int) -> Dictionary:
	return data[index]

func has_index(index: int) -> bool:
	return index >= 0 and index < data.size()

func get_at_cell(cell: Vector2i) -> int:
	for i in range(data.size()):
		if cell in data[i].cells:
			return i
	return -1

func get_all_cells_except(except_index: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for i in range(data.size()):
		if i == except_index:
			continue
		cells.append_array(data[i].cells)
	return cells

func get_occupied_cells(floor_level: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for b in data:
		if b.get("floor_level", 0) == floor_level:
			cells.append_array(b.cells)
	return cells

func atlas_coord() -> Vector2i:
	return Vector2i(3, 0) if GlobalTransferData.current_mode == GlobalTransferData.GameMode.GAME else Vector2i(1, 0)

func rename(index: int, new_name: String) -> void:
	if index >= 0 and index < data.size():
		data[index].name = new_name
		data[index].label.text = new_name

func update_label_position(index: int) -> void:
	if index >= 0 and index < data.size():
		var b = data[index]
		var label = b.label as Label
		if label:
			MapUtils.position_label(label, b.cells, 0.0)

func size() -> int:
	return data.size()
