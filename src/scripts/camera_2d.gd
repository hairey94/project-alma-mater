extends Camera2D

const HUD_PANEL_HEIGHT: float = 112.0
const MOVE_SPEED: float = 600.0
const ROTATION_SNAP_DEG: float = 30.0
const ZOOM_SENSITIVITY: float = 0.2
const MIN_ZOOM: float = 0.3
const MAX_ZOOM: float = 3.0

var current_floor: int = 0

func _ready() -> void:
	position_smoothing_enabled = false
	_calibrate_viewport_view()
	get_tree().root.size_changed.connect(_calibrate_viewport_view)

func _calibrate_viewport_view() -> void:
	var window_height: float = get_viewport_rect().size.y
	var hud_screen_ratio: float = HUD_PANEL_HEIGHT / window_height
	var vertical_pixel_shift: float = (window_height * hud_screen_ratio) / (2.0 * zoom.y)
	offset.y = vertical_pixel_shift

func _is_text_input_focused() -> bool:
	var tree = get_tree()
	if not tree:
		return false
	return _check_window_text_focus(tree.root)

func _check_window_text_focus(node: Node) -> bool:
	if node is Window and node.visible:
		var focus = node.gui_get_focus_owner()
		if focus and (focus is LineEdit or focus is TextEdit):
			return true
	for child in node.get_children():
		if _check_window_text_focus(child):
			return true
	return false

func _process(delta: float) -> void:
	if _is_text_input_focused():
		return
	var move := Vector2.ZERO
	if Input.is_key_pressed(KEY_W):
		move.y -= 1
	if Input.is_key_pressed(KEY_S):
		move.y += 1
	if Input.is_key_pressed(KEY_A):
		move.x -= 1
	if Input.is_key_pressed(KEY_D):
		move.x += 1
	if move != Vector2.ZERO:
		position += move.normalized() * MOVE_SPEED * delta

func _unhandled_input(event: InputEvent) -> void:
	if _is_text_input_focused():
		return
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		match event.keycode:
			KEY_Q:
				rotation_degrees = round(rotation_degrees / ROTATION_SNAP_DEG) * ROTATION_SNAP_DEG - ROTATION_SNAP_DEG
			KEY_E:
				rotation_degrees = round(rotation_degrees / ROTATION_SNAP_DEG) * ROTATION_SNAP_DEG + ROTATION_SNAP_DEG
			KEY_R:
				current_floor += 1
				GlobalSignalBus.floor_view_swapped.emit(current_floor)
			KEY_F:
				current_floor = maxi(0, current_floor - 1)
				GlobalSignalBus.floor_view_swapped.emit(current_floor)
			KEY_Z:
				var old_zoom = zoom
				zoom += Vector2(ZOOM_SENSITIVITY, ZOOM_SENSITIVITY)
				zoom.x = clamp(zoom.x, MIN_ZOOM, MAX_ZOOM)
				zoom.y = clamp(zoom.y, MIN_ZOOM, MAX_ZOOM)
				if old_zoom != zoom:
					_calibrate_viewport_view()
			KEY_C:
				var old_zoom = zoom
				zoom -= Vector2(ZOOM_SENSITIVITY, ZOOM_SENSITIVITY)
				zoom.x = clamp(zoom.x, MIN_ZOOM, MAX_ZOOM)
				zoom.y = clamp(zoom.y, MIN_ZOOM, MAX_ZOOM)
				if old_zoom != zoom:
					_calibrate_viewport_view()
