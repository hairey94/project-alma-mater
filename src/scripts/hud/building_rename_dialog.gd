extends RefCounted
class_name BuildingRenameDialog

var _window: Window = null
var _callback: Callable
var _dismissed: bool = false

func show(parent: CanvasLayer, default_name: String, callback: Callable) -> void:
	_callback = callback
	_dismissed = false

	_window = Window.new()
	_window.title = "Name Your Building"
	_window.size = Vector2(400, 160)
	_window.exclusive = true
	_window.unresizable = true

	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 12)
	_window.add_child(vbox)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 8)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(margin)

	var inner_vbox = VBoxContainer.new()
	inner_vbox.add_theme_constant_override("separation", 12)
	margin.add_child(inner_vbox)

	var label = Label.new()
	label.text = "Enter a name for this building:"
	inner_vbox.add_child(label)

	var line_edit = LineEdit.new()
	line_edit.text = default_name
	line_edit.select_all()
	line_edit.caret_force_displayed = true
	inner_vbox.add_child(line_edit)

	var hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_END
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner_vbox.add_child(hbox)

	var confirm_btn = Button.new()
	confirm_btn.text = " Confirm "
	confirm_btn.add_theme_color_override("font_color", Color("#4ade80"))
	hbox.add_child(confirm_btn)

	var cancel_btn = Button.new()
	cancel_btn.text = " Cancel "
	cancel_btn.add_theme_color_override("font_color", Color("#f87171"))
	hbox.add_child(cancel_btn)

	confirm_btn.pressed.connect(func(): _dismiss(true, line_edit.text))
	cancel_btn.pressed.connect(func(): _dismiss(false, default_name))
	line_edit.text_submitted.connect(func(text: String): _dismiss(true, text))
	_window.close_requested.connect(func(): _dismiss(false, ""))

	parent.add_child(_window)
	_window.popup_centered()
	line_edit.grab_focus()

func _dismiss(confirmed: bool, value: String) -> void:
	if _dismissed:
		return
	_dismissed = true
	if confirmed and _callback:
		_callback.call(true, value)
	_window.queue_free()
