extends RefCounted
class_name ConstructionState

enum State { IDLE, DRAGGING, PENDING_APPROVAL }

const PASTEL_PREVIEW_COLOR = Color("#a7f3d0")
const PASTEL_STAGED_COLOR = Color("#fef08a")
const PASTEL_BLOCKED_COLOR = Color("#fca5a5")
const CONFIRMED_COLOR = Color("#a7f3d0")
const TILE_SIZE = 64.0

var current_state: State = State.IDLE
var active_item_name: String = ""
var current_tool: String = "drag"
var drag_start_cell: Vector2i = Vector2i.ZERO
var drag_end_cell: Vector2i = Vector2i.ZERO
var painted_preview_cells: Array[Vector2i] = []
var staged_cells: Array[Vector2i] = []
var blocked_cells: Array[Vector2i] = []

var grid_bounds: Rect2i = Rect2i(0, 0, 64, 64)

var _extending: bool = false
var _field_layer: TileMapLayer
var _plan_container: Node2D
var _confirmed_container: Node2D

func setup(field_layer: TileMapLayer, plan_container: Node2D, confirmed_container: Node2D) -> void:
	_field_layer = field_layer
	_plan_container = plan_container
	_confirmed_container = confirmed_container

func set_active_item(item_name: String) -> void:
	if current_state == State.PENDING_APPROVAL:
		clear_staged(false)
	active_item_name = item_name
	current_state = State.IDLE

func is_staging() -> bool:
	return current_state == State.PENDING_APPROVAL

func can_place() -> bool:
	return active_item_name != "" and current_state != State.PENDING_APPROVAL

func continue_adding() -> void:
	if current_state != State.PENDING_APPROVAL:
		return
	_extending = true
	current_state = State.IDLE

func start_drag(pos: Vector2i) -> void:
	if current_tool == "tiles":
		if _is_cell_blocked(pos):
			return
	else:
		if pos.x < 0 or pos.y < 0 or pos.x > grid_bounds.size.x or pos.y > grid_bounds.size.y:
			return
	current_state = State.DRAGGING
	drag_start_cell = pos
	drag_end_cell = pos
	if current_tool == "tiles":
		painted_preview_cells.clear()
		painted_preview_cells.append(pos)
	render_preview()

func update_drag(cell: Vector2i) -> void:
	if cell != drag_end_cell:
		drag_end_cell = cell
		render_preview()

func end_drag(cell: Vector2i) -> void:
	drag_end_cell = cell
	current_state = State.PENDING_APPROVAL
	convert_previews_to_staged()
	if staged_cells.is_empty():
		clear_staged(true)
		return
	_extending = false

func _remove_all_children(node: Node2D) -> void:
	var children = node.get_children()
	for child in children:
		node.remove_child(child)
		child.queue_free()

func _is_cell_blocked(cell: Vector2i) -> bool:
	return cell in blocked_cells or not grid_bounds.has_point(cell)

func _render_cell_rect(cell: Vector2i, color: Color) -> void:
	var rect = ColorRect.new()
	rect.size = Vector2(TILE_SIZE, TILE_SIZE)
	rect.position = Vector2(cell.x * TILE_SIZE, cell.y * TILE_SIZE)
	rect.color = color
	_plan_container.add_child(rect)

func render_preview() -> void:
	_remove_all_children(_plan_container)
	if _extending:
		for cell in staged_cells:
			_render_cell_rect(cell, PASTEL_STAGED_COLOR)
	if current_tool == "tiles":
		for cell in painted_preview_cells:
			var color = PASTEL_BLOCKED_COLOR if _is_cell_blocked(cell) else PASTEL_PREVIEW_COLOR
			_render_cell_rect(cell, color)
		return
	painted_preview_cells.clear()
	var x_min = mini(drag_start_cell.x, drag_end_cell.x)
	var x_max = maxi(drag_start_cell.x, drag_end_cell.x)
	var y_min = mini(drag_start_cell.y, drag_end_cell.y)
	var y_max = maxi(drag_start_cell.y, drag_end_cell.y)
	for x in range(x_min, x_max):
		for y in range(y_min, y_max):
			var cell = Vector2i(x, y)
			var color = PASTEL_BLOCKED_COLOR if _is_cell_blocked(cell) else PASTEL_PREVIEW_COLOR
			_render_cell_rect(cell, color)
			painted_preview_cells.append(cell)

func clear_preview_cells() -> void:
	_remove_all_children(_plan_container)
	painted_preview_cells.clear()

func convert_previews_to_staged() -> void:
	if _extending:
		for cell in painted_preview_cells:
			if not cell in staged_cells and not _is_cell_blocked(cell):
				staged_cells.append(cell)
		painted_preview_cells.clear()
		_remove_all_children(_plan_container)
		for cell in staged_cells:
			_render_cell_rect(cell, PASTEL_STAGED_COLOR)
	else:
		staged_cells = []
		for cell in painted_preview_cells:
			if not _is_cell_blocked(cell):
				staged_cells.append(cell)
		painted_preview_cells.clear()
		_remove_all_children(_plan_container)
		for cell in staged_cells:
			_render_cell_rect(cell, PASTEL_STAGED_COLOR)

func confirm_placement(target_atlas_coord: Vector2i) -> void:
	_remove_all_children(_plan_container)
	for cell in staged_cells:
		_field_layer.set_cell(cell, 0, target_atlas_coord)
		var rect = ColorRect.new()
		rect.size = Vector2(TILE_SIZE, TILE_SIZE)
		rect.position = Vector2(cell.x * TILE_SIZE, cell.y * TILE_SIZE)
		rect.color = CONFIRMED_COLOR
		_confirmed_container.add_child(rect)
	staged_cells.clear()
	current_state = State.IDLE

func clear_staged(keep_tool: bool) -> void:
	_remove_all_children(_plan_container)
	staged_cells.clear()
	painted_preview_cells.clear()
	_extending = false
	if keep_tool:
		current_state = State.IDLE
	else:
		active_item_name = ""
		current_state = State.IDLE

func remove_cell(cell: Vector2i) -> void:
	if current_state == State.PENDING_APPROVAL:
		var idx = staged_cells.find(cell)
		if idx >= 0:
			staged_cells.remove_at(idx)
			_remove_all_children(_plan_container)
			for c in staged_cells:
				_render_cell_rect(c, PASTEL_STAGED_COLOR)
			if staged_cells.is_empty():
				current_state = State.IDLE
	elif current_state == State.DRAGGING and current_tool == "tiles":
		var idx = painted_preview_cells.find(cell)
		if idx >= 0:
			painted_preview_cells.remove_at(idx)
			render_preview()
			if painted_preview_cells.is_empty():
				current_state = State.IDLE

func clear_all_confirmed() -> void:
	_remove_all_children(_confirmed_container)
