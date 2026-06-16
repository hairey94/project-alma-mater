extends CharacterBody2D
class_name StudentAgent

const TILE_SIZE = 64
const AGENT_SIZE = 16
const HALF_AGENT = AGENT_SIZE / 2
const RADIUS = 6

var student_data: StudentData
var _waypoints: Array[Vector2i] = []
var _wp_index: int = 0
var _speed: float = 48.0

var _sprite: Sprite2D
var _label: Label

static var _grade_colors: Dictionary = {
	1: Color("#4A90D9"),
	2: Color("#50C878"),
	3: Color("#FFD700"),
	4: Color("#9B59B6"),
	5: Color("#E74C3C")
}

func setup(data: StudentData) -> void:
	student_data = data
	_generate_sprite(data.grade)
	_label = Label.new()
	_label.text = "G%d" % data.grade
	_label.add_theme_font_size_override("font_size", 10)
	_label.add_theme_color_override("font_color", Color.WHITE)
	_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_label.add_theme_constant_override("shadow_offset_x", 1)
	_label.add_theme_constant_override("shadow_offset_y", 1)
	_label.position = Vector2(-_label.get_theme_font_size("font_size") / 2.0, -18)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)

func set_path(waypoints: Array[Vector2i]) -> void:
	_waypoints = waypoints
	_wp_index = 0

func is_still_walking() -> bool:
	return _waypoints.size() > 1

func has_arrived() -> bool:
	return _waypoints.is_empty() or _wp_index >= _waypoints.size()

func _process(delta: float) -> void:
	if has_arrived():
		return

	var target = _waypoints[_wp_index]
	var target_px = Vector2(target.x * TILE_SIZE + TILE_SIZE / 2, target.y * TILE_SIZE + TILE_SIZE / 2)
	var dist = global_position.distance_to(target_px)

	if dist < 2.0:
		_wp_index += 1
		global_position = target_px
		return

	global_position = global_position.move_toward(target_px, _speed * delta)

func _generate_sprite(grade: int) -> void:
	var color = _grade_colors.get(grade, Color.WHITE)
	var img = Image.create(AGENT_SIZE, AGENT_SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var cx = HALF_AGENT
	var cy = HALF_AGENT
	var r2 = RADIUS * RADIUS
	var r_inner = RADIUS - 1
	var r_inner2 = r_inner * r_inner

	for x in range(AGENT_SIZE):
		for y in range(AGENT_SIZE):
			var dx = x - cx
			var dy = y - cy
			var d2 = dx * dx + dy * dy
			if d2 <= r2:
				img.set_pixel(x, y, color)

	_sprite = Sprite2D.new()
	_sprite.texture = ImageTexture.create_from_image(img)
	_sprite.position = Vector2.ZERO
	add_child(_sprite)
