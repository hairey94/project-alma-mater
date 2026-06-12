extends Node

const MAIN_MENU_SCENE: PackedScene = preload("res://src/scenes/menus/main_menu.tscn")
const SCHOOL_SETUP_SCENE: PackedScene = preload("res://src/scenes/school_setup.tscn")
const GAME_MAP_SCENE: PackedScene = preload("res://src/scenes/game_map.tscn")

func _ready() -> void:
	_transition_to_scene(MAIN_MENU_SCENE)

func launch_sandbox_setup() -> void:
	GlobalTransferData.is_sandbox_mode = true
	_transition_to_scene(SCHOOL_SETUP_SCENE)

func confirm_setup_and_start_game(school_name: String, principal_name: String) -> void:
	if school_name.is_empty() or principal_name.is_empty():
		push_warning("GameManager: school_name or principal_name cannot be empty.")
		return
	GlobalTransferData.school_name = school_name
	GlobalTransferData.principal_name = principal_name
	_transition_to_scene(GAME_MAP_SCENE)

func _transition_to_scene(scene: PackedScene) -> void:
	var instance = scene.instantiate()
	for child in get_children():
		child.queue_free()
	add_child(instance)
	_connect_scene_signals(instance)

func _connect_scene_signals(node: Node) -> void:
	if node.has_signal("sandbox_mode_started") and not node.sandbox_mode_started.is_connected(launch_sandbox_setup):
		node.sandbox_mode_started.connect(launch_sandbox_setup)
