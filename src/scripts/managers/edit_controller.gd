extends RefCounted
class_name EditController

var map: Node2D
var _dialog = null
var _active_type: String = ""
var _active_index: int = -1
var _callbacks: Dictionary = {}

func setup(game_map: Node2D) -> void:
	map = game_map

func is_editing() -> bool:
	return _active_type != ""

func get_edit_type() -> String:
	return _active_type

func get_edit_index() -> int:
	return _active_index

func start_edit(edit_type: String, index: int, title: String, callbacks: Dictionary) -> void:
	_discard()
	_active_type = edit_type
	_active_index = index
	_callbacks = callbacks
	_dialog = preload("res://src/scripts/hud/building_edit_dialog.gd").new()
	_dialog.show(
		map,
		title,
		func(action: String): _on_action(action),
		func(): _on_confirm(),
		func(): _on_cancel(),
		edit_type
	)

func trigger_cancel() -> void:
	if _callbacks.has("cancel"):
		_callbacks["cancel"].call()
	_discard()

func discard() -> void:
	_discard()

func _on_action(action: String) -> void:
	if _callbacks.has(action):
		_callbacks[action].call()

func _on_confirm() -> void:
	if _callbacks.has("confirm"):
		_callbacks["confirm"].call()
	_discard()

func _on_cancel() -> void:
	if _callbacks.has("cancel"):
		_callbacks["cancel"].call()
	_discard()

func _discard() -> void:
	if _dialog and is_instance_valid(_dialog.window):
		_dialog.window.queue_free()
	_dialog = null
	_active_type = ""
	_active_index = -1
	_callbacks.clear()
