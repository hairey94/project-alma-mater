extends Control

signal sandbox_mode_started

func _ready():
	if check_for_save_files():
		%LoadBtn.disabled = false
	
	# Connect your unique Sandbox Button via its Scene Unique Name (%) 
	%SandboxBtn.pressed.connect(_on_sandbox_pressed)
	
func check_for_save_files() -> bool:
	var dir = DirAccess.open("user://saves/")
	if dir == null:
		print("Save directory not found.")
		return false
	var files = dir.get_files()
	return files.size() > 0

func _on_sandbox_pressed():
	sandbox_mode_started.emit()

func _on_exit_pressed():
	get_tree().quit()
