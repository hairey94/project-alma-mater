extends RefCounted
class_name FloatingConfirmWidget

var active_bubble: HBoxContainer = null
var _parent: CanvasLayer

func setup(parent: CanvasLayer) -> void:
	_parent = parent

func display(spawn_pos: Vector2, map_node: Node2D) -> void:
	dismiss()
	active_bubble = HBoxContainer.new()
	active_bubble.custom_minimum_size = Vector2(320, 45)
	active_bubble.alignment = BoxContainer.ALIGNMENT_CENTER
	active_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var bg = StyleBoxFlat.new()
	bg.bg_color = Color("#1e293b", 0.95)
	bg.set_corner_radius_all(6)
	bg.set_content_margin_all(8)
	bg.shadow_color = Color(0, 0, 0, 0.3)
	bg.shadow_size = 4
	active_bubble.add_theme_stylebox_override("panel", bg)

	var confirm_btn = Button.new()
	confirm_btn.text = " ✓ Confirm "
	confirm_btn.add_theme_color_override("font_color", Color("#4ade80"))
	confirm_btn.pressed.connect(func(): map_node.confirm_staged_placement())

	var continue_btn = Button.new()
	continue_btn.text = " + Continue "
	continue_btn.add_theme_color_override("font_color", Color("#60a5fa"))
	continue_btn.pressed.connect(func(): map_node.continue_staged_placement())

	var redrag_btn = Button.new()
	redrag_btn.text = " ✗ Redrag "
	redrag_btn.add_theme_color_override("font_color", Color("#f87171"))
	redrag_btn.pressed.connect(func(): map_node.redrag_staged_placement())

	active_bubble.add_child(confirm_btn)
	active_bubble.add_child(continue_btn)
	active_bubble.add_child(redrag_btn)
	_parent.add_child(active_bubble)

	var offset = Vector2(active_bubble.custom_minimum_size.x / 2.0, 60.0)
	active_bubble.global_position = spawn_pos - offset

func dismiss() -> void:
	if is_instance_valid(active_bubble):
		active_bubble.queue_free()
		active_bubble = null
