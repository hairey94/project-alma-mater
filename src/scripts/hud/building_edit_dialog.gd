extends RefCounted
class_name BuildingEditDialog

var window: Window
var callback_confirm: Callable
var callback_cancel: Callable
var callback_action: Callable

func show(parent: Node, building_name: String, action_callback: Callable, confirm_callback: Callable, cancel_callback: Callable, mode: String = "building") -> void:
	callback_action = action_callback
	callback_confirm = confirm_callback
	callback_cancel = cancel_callback

	window = Window.new()
	if mode == "door":
		window.title = "Edit Door: " + building_name
	elif mode == "corridor":
		window.title = "Edit Corridor: " + building_name
	else:
		window.title = "Edit Building: " + building_name
	window.size = Vector2i(300, 320)
	window.transient = true
	window.exclusive = false
	window.close_requested.connect(_on_cancel)

	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	window.add_child(vbox)

	var title_label = Label.new()
	title_label.text = "Select Action"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title_label)

	if mode != "door" and mode != "corridor":
		var btn_add_delete = Button.new()
		btn_add_delete.text = "Add / Delete Tiles"
		btn_add_delete.pressed.connect(func(): _on_action_selected("add_delete"))
		btn_add_delete.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
				_on_action_selected("add_delete")
		)
		vbox.add_child(btn_add_delete)

		var btn_rename = Button.new()
		btn_rename.text = "Rename"
		btn_rename.pressed.connect(func(): _on_action_selected("rename"))
		vbox.add_child(btn_rename)

	if mode == "corridor":
		var btn_add_delete = Button.new()
		btn_add_delete.text = "Add / Delete Tiles"
		btn_add_delete.pressed.connect(func(): _on_action_selected("add_delete"))
		btn_add_delete.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
				_on_action_selected("add_delete")
		)
		vbox.add_child(btn_add_delete)

	if mode != "corridor":
		var btn_move_rotate = Button.new()
		btn_move_rotate.text = "Move / Rotate"
		btn_move_rotate.pressed.connect(func(): _on_action_selected("move_rotate"))
		vbox.add_child(btn_move_rotate)

	var btn_demolish = Button.new()
	btn_demolish.text = "Demolish"
	btn_demolish.pressed.connect(func(): _on_action_selected("demolish"))
	vbox.add_child(btn_demolish)

	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	var h_bottom = HBoxContainer.new()
	vbox.add_child(h_bottom)

	var btn_cancel = Button.new()
	btn_cancel.text = "Cancel"
	btn_cancel.size_flags_stretch_ratio = 1
	btn_cancel.pressed.connect(func(): _on_cancel())
	h_bottom.add_child(btn_cancel)

	var btn_confirm = Button.new()
	btn_confirm.text = "Confirm"
	btn_confirm.size_flags_stretch_ratio = 1
	btn_confirm.pressed.connect(func(): _on_confirm())
	h_bottom.add_child(btn_confirm)

	parent.add_child(window)
	window.popup()
	var screen_size = DisplayServer.window_get_size()
	window.position = Vector2i(maxi(0, screen_size.x - window.size.x), maxi(0, screen_size.y - window.size.y))

func _on_action_selected(action: String) -> void:
	if callback_action:
		callback_action.call(action)

func _on_confirm() -> void:
	if callback_confirm:
		callback_confirm.call()

func _on_cancel() -> void:
	if callback_cancel:
		callback_cancel.call()
