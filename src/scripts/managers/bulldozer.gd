extends RefCounted
class_name Bulldozer

var map: Node2D
var _is_bulldozing: bool = false
var _last_cell: Vector2i = Vector2i(-1, -1)

const GRID_SIZE = 64

var field_layer: TileMapLayer
var classroom_layer: TileMapLayer
var principal_office_layer: TileMapLayer
var corridor_layer: TileMapLayer
var confirmed_container: Node2D
var building_mgr
var room_mgr

func setup(game_map: Node2D, fld: TileMapLayer, cls: TileMapLayer, pol: TileMapLayer, corr: TileMapLayer, confirmed: Node2D, bld_mgr, rm_mgr) -> void:
	map = game_map
	field_layer = fld
	classroom_layer = cls
	principal_office_layer = pol
	corridor_layer = corr
	confirmed_container = confirmed
	building_mgr = bld_mgr
	room_mgr = rm_mgr

func is_active() -> bool:
	return _is_bulldozing

func activate() -> void:
	_is_bulldozing = true
	_last_cell = Vector2i(-1, -1)

func deactivate() -> void:
	_is_bulldozing = false
	_last_cell = Vector2i(-1, -1)

func bulldoze(cell: Vector2i) -> void:
	if cell == _last_cell:
		return
	_last_cell = cell
	_do_bulldoze(cell)

func _do_bulldoze(cell: Vector2i) -> void:
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
		if rect and rect.position == Vector2(cell.x * 64, cell.y * 64):
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
