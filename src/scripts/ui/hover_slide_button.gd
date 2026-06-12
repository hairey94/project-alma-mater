extends Button
class_name HoverSlideButton

const HOVER_LEFT_MARGIN: float = 16.0
const NORMAL_LEFT_MARGIN: float = 24.0
const TWEEN_DURATION: float = 0.15

var margin_tween: Tween

func _ready() -> void:
	mouse_entered.connect(_on_mouse_hover_start)
	mouse_exited.connect(_on_mouse_hover_end)
	add_theme_stylebox_override("normal", get_theme_stylebox("normal").duplicate())
	add_theme_stylebox_override("hover", get_theme_stylebox("hover").duplicate())

func _on_mouse_hover_start() -> void:
	if margin_tween:
		margin_tween.kill()
	var active_stylebox = get_theme_stylebox("hover") as StyleBoxFlat
	margin_tween = create_tween()
	margin_tween.tween_property(active_stylebox, "content_margin_left", HOVER_LEFT_MARGIN, TWEEN_DURATION)\
		.set_trans(Tween.TRANS_CUBIC)\
		.set_ease(Tween.EASE_OUT)

func _on_mouse_hover_end() -> void:
	if margin_tween:
		margin_tween.kill()
	var active_stylebox = get_theme_stylebox("hover") as StyleBoxFlat
	margin_tween = create_tween()
	margin_tween.tween_property(active_stylebox, "content_margin_left", NORMAL_LEFT_MARGIN, TWEEN_DURATION)\
		.set_trans(Tween.TRANS_CUBIC)\
		.set_ease(Tween.EASE_IN_OUT)
