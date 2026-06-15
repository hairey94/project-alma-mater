extends RefCounted
class_name MapRenderer

const TILE_SIZE = 64
const EDGE_LINE_WIDTH = 6.0

var grid_layer: ColorRect
var camera_ref: Camera2D
var edge_container: Node2D
var hover_rect: ColorRect
var door_hover_rect: ColorRect
var field_layer: TileMapLayer
var building_manager = null
var room_manager = null
var corridor_manager = null

func setup(grid: ColorRect, cam: Camera2D, edge: Node2D, hover: ColorRect, door_hover: ColorRect, field: TileMapLayer, bld_mgr, rm_mgr, corr_mgr) -> void:
	grid_layer = grid
	camera_ref = cam
	edge_container = edge
	hover_rect = hover
	door_hover_rect = door_hover
	field_layer = field
	building_manager = bld_mgr
	room_manager = rm_mgr
	corridor_manager = corr_mgr

func sync_grid_shader() -> void:
	if not grid_layer or not grid_layer.visible:
		return
	var mat = grid_layer.material as ShaderMaterial
	if not mat:
		return
	var vp_size: Vector2 = grid_layer.get_viewport_rect().size
	var top_left: Vector2 = camera_ref.position - ((vp_size / 2.0) / camera_ref.zoom.x)
	mat.set_shader_parameter("camera_offset", top_left)
	mat.set_shader_parameter("camera_zoom", camera_ref.zoom.x)
	mat.set_shader_parameter("viewport_size", vp_size)
	mat.set_shader_parameter("field_bounds", Vector4(0, 0, 64 * 64, 64 * 64))

func update_hover(pos: Vector2i, color: Color) -> void:
	hover_rect.visible = true
	hover_rect.position = Vector2(pos.x * TILE_SIZE, pos.y * TILE_SIZE)
	hover_rect.color = color

func hide_hover() -> void:
	hover_rect.visible = false

func show_door_hover(cell: Vector2i, color: Color = Color(1, 0.85, 0, 0.25)) -> void:
	door_hover_rect.visible = true
	door_hover_rect.position = Vector2(cell.x * TILE_SIZE, cell.y * TILE_SIZE)
	door_hover_rect.color = color

func hide_door_hover() -> void:
	door_hover_rect.visible = false

func update_edge_lines() -> void:
	for child in edge_container.get_children():
		edge_container.remove_child(child)
		child.queue_free()

	var lw = EDGE_LINE_WIDTH
	for i in range(building_manager.size()):
		var b = building_manager.get_entry(i)
		var b_cells: Dictionary = {}
		for c in b.cells:
			b_cells[c] = true
		for cell in b.cells:
			for d in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
				var neighbor = cell + d
				if not b_cells.has(neighbor):
					_add_edge_strip(cell, d, lw, Color(1, 1, 1, 0.4))

	for i in range(room_manager.size()):
		var cls = room_manager.get_entry(i)
		var cls_cells: Dictionary = {}
		for c in cls.cells:
			cls_cells[c] = true
		for cell in cls.cells:
			for d in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
				var neighbor = cell + d
				if not cls_cells.has(neighbor):
					_add_edge_strip(cell, d, lw, Color(1, 0.9, 0.5, 0.5))

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
	edge_container.add_child(edge)

func draw_edge_preview(cell: Vector2i, edge_normal: Vector2i, parent: Node2D) -> void:
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

func clear_preview_container(preview: Node2D) -> void:
	for child in preview.get_children():
		preview.remove_child(child)
		child.queue_free()
