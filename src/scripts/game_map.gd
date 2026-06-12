extends Node2D

@onready var field_layer: TileMapLayer = $FieldLayer
@onready var road_layer: TileMapLayer = $RoadLayer
@onready var blueprint_grid_layer: ColorRect = $BlueprintGridLayer
@onready var camera: Camera2D = $Camera2D

var plan_container: Node2D
var confirmed_container: Node2D

const GRID_SIZE = 64
const TILE_SIZE = 64
const FIELD_PX = GRID_SIZE * TILE_SIZE
const ConstructionState = preload("res://src/scripts/construction_state.gd")

var construction: ConstructionState
var _hover_rect: ColorRect
var _is_bulldozing: bool = false
var _last_bulldoze_cell: Vector2i = Vector2i(-1, -1)
var _building_counter: int = 0
var _building_labels_container: Node2D
var _building_data: Array[Dictionary] = []

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

	_hover_rect = ColorRect.new()
	_hover_rect.name = "HoverRect"
	_hover_rect.size = Vector2(TILE_SIZE, TILE_SIZE)
	_hover_rect.color = Color(1, 1, 1, 0.2)
	_hover_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hover_rect.visible = false
	add_child(_hover_rect)
	move_child(_hover_rect, plan_container.get_index())

	construction = ConstructionState.new()
	construction.setup(field_layer, plan_container, confirmed_container)
	construction.grid_bounds = Rect2i(0, 0, GRID_SIZE, GRID_SIZE)
	_generate_map()
	_center_camera_on_road()

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
	camera.position = Vector2((GRID_SIZE * TILE_SIZE) / 2.0, GRID_SIZE * TILE_SIZE)

func _process(delta: float) -> void:
	_update_hover_rect()
	_sync_grid_shader()
	if _is_bulldozing:
		var cell = _cell_under_mouse()
		if cell != _last_bulldoze_cell:
			_bulldoze_cell(cell)
			_last_bulldoze_cell = cell
	if construction.active_item_name != "":
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
	var mode = GlobalTransferData.current_mode
	if mode != GlobalTransferData.GameMode.ARCHITECTURAL and mode != GlobalTransferData.GameMode.BULLDOZER:
		_hover_rect.visible = false
		return

	var corner = _corner_under_mouse()

	if mode == GlobalTransferData.GameMode.ARCHITECTURAL:
		if corner.x < 0 or corner.x >= GRID_SIZE or corner.y < 0 or corner.y >= GRID_SIZE:
			_hover_rect.visible = false
			return
	elif mode == GlobalTransferData.GameMode.BULLDOZER:
		if corner.x < 0 or corner.x >= GRID_SIZE or corner.y < 0 or corner.y >= GRID_SIZE + 2:
			_hover_rect.visible = false
			return

	_hover_rect.visible = true
	_hover_rect.position = Vector2(corner.x * TILE_SIZE, corner.y * TILE_SIZE)

	if mode == GlobalTransferData.GameMode.ARCHITECTURAL:
		var occ = _get_occupied_cells(camera.current_floor)
		_hover_rect.color = Color(1, 0.3, 0.3, 0.35) if corner in occ else Color(1, 1, 1, 0.2)
	elif mode == GlobalTransferData.GameMode.BULLDOZER:
		_hover_rect.color = Color(1, 1, 1, 0.2)

func _cell_under_mouse() -> Vector2i:
	return field_layer.local_to_map(field_layer.get_local_mouse_position())

func _corner_under_mouse() -> Vector2i:
	var local_pos = field_layer.get_local_mouse_position()
	return Vector2i(
		roundi(local_pos.x / TILE_SIZE),
		roundi(local_pos.y / TILE_SIZE)
	)

func set_active_placement_item(_item_name: String) -> void:
	construction.set_active_item(_item_name)

func set_placement_tool(tool_name: String) -> void:
	construction.current_tool = tool_name

func cancel_placement() -> void:
	if construction.current_state == ConstructionState.State.DRAGGING:
		construction.clear_preview_cells()
		construction.current_state = ConstructionState.State.IDLE
	elif construction.current_state == ConstructionState.State.PENDING_APPROVAL:
		construction.clear_staged(true)
	_remove_confirmation_widget()

func _on_game_mode_changed(new_mode: GlobalTransferData.GameMode) -> void:
	_is_bulldozing = false
	blueprint_grid_layer.visible = false
	match new_mode:
		GlobalTransferData.GameMode.GAME:
			field_layer.modulate = Color.WHITE
			construction.clear_staged(false)
			construction.clear_all_confirmed()
		GlobalTransferData.GameMode.ARCHITECTURAL:
			field_layer.modulate = Color("#1e40af")
			blueprint_grid_layer.visible = true
		GlobalTransferData.GameMode.MANAGEMENT:
			field_layer.modulate = Color("#475569")
			construction.clear_staged(false)
			construction.clear_all_confirmed()
		GlobalTransferData.GameMode.BULLDOZER:
			field_layer.modulate = Color("#991b1b")
			blueprint_grid_layer.visible = true
			cancel_placement()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if construction.current_state == ConstructionState.State.PENDING_APPROVAL:
			var cell = _cell_under_mouse()
			construction.remove_cell(cell)
			if construction.current_state == ConstructionState.State.IDLE:
				_remove_confirmation_widget()
		elif construction.current_state == ConstructionState.State.DRAGGING and construction.current_tool == "tiles":
			var cell = _cell_under_mouse()
			construction.remove_cell(cell)
		elif construction.current_state == ConstructionState.State.DRAGGING:
			cancel_placement()
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

		if GlobalTransferData.current_mode != GlobalTransferData.GameMode.ARCHITECTURAL or not construction.can_place():
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
			if construction.current_tool == "tiles" and construction.current_state == ConstructionState.State.PENDING_APPROVAL:
				return
			construction.blocked_cells = _get_occupied_cells(camera.current_floor)
			if use_cell and pos in construction.blocked_cells:
				return
			construction.start_drag(pos)
		elif event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and construction.current_state == ConstructionState.State.DRAGGING:
			construction.blocked_cells = _get_occupied_cells(camera.current_floor)
			construction.end_drag(pos)
			if construction.current_state != ConstructionState.State.PENDING_APPROVAL:
				return
			_spawn_confirmation_widget(event.global_position)

func _process_construction_input() -> void:
	if GlobalTransferData.current_mode != GlobalTransferData.GameMode.ARCHITECTURAL:
		return
	if construction.is_staging():
		return
	if construction.current_state == ConstructionState.State.DRAGGING:
		construction.blocked_cells = _get_occupied_cells(camera.current_floor)
		var use_cell = construction.current_tool == "tiles"
		var pos = _cell_under_mouse() if use_cell else _corner_under_mouse()
		if pos != construction.drag_end_cell:
			construction.drag_end_cell = pos
			if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and use_cell:
				var bounds = Rect2i(0, 0, GRID_SIZE, GRID_SIZE)
				if not pos in construction.painted_preview_cells and not pos in construction.blocked_cells and bounds.has_point(pos):
					construction.painted_preview_cells.append(pos)
					construction.render_preview()
			else:
				construction.render_preview()

func confirm_staged_placement() -> void:
	_building_counter += 1
	var default_name = "Building %d" % _building_counter
	var current_floor = camera.current_floor
	var hud = find_child("InGameHUD", true, false) as CanvasLayer
	if hud and hud.has_method("show_building_rename_dialog"):
		hud.show_building_rename_dialog(default_name, func(confirmed: bool, name: String):
			if not confirmed:
				return
			var cells = construction.staged_cells.duplicate()
			construction.confirm_placement(Vector2i(1, 0))
			_add_building_label(name, cells, current_floor)
			_remove_confirmation_widget()
		)
	else:
		var cells = construction.staged_cells.duplicate()
		construction.confirm_placement(Vector2i(1, 0))
		_add_building_label(default_name, cells, current_floor)
		_remove_confirmation_widget()

func continue_staged_placement() -> void:
	construction.continue_adding()
	_remove_confirmation_widget()

func redrag_staged_placement() -> void:
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
	label.add_theme_color_override("font_color", Color(0.05, 0.05, 0.1))
	label.add_theme_color_override("font_shadow_color", Color(1, 1, 1, 0.6))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.add_theme_font_size_override("font_size", 20)

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

func _bulldoze_cell(cell: Vector2i) -> void:
	if cell.x < 0 or cell.x >= GRID_SIZE or cell.y < 0 or cell.y >= GRID_SIZE + 2:
		return
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

func _zoom_camera(factor: float) -> void:
	var new_zoom = camera.zoom * factor
	camera.zoom = new_zoom.clamp(Vector2(0.1, 0.1), Vector2(2.0, 2.0))
