extends Control

@onready var school_name_input: LineEdit = %SchoolNameInput
@onready var random_school_btn: Button = %RandomSchoolBtn

@onready var principal_name_input: LineEdit = %PrincipalNameInput
@onready var random_principal_btn: Button = %RandomPrincipalBtn

@onready var male_check_box: CheckBox = %MaleCheckBox
@onready var female_check_box: CheckBox = %FemaleCheckBox
@onready var school_type_option: OptionButton = %SchoolTypeOption
@onready var confirm_setup_btn: Button = %ConfirmSetupBtn

# ---- NEW: Unique Name (%) reference to your back button ----
@onready var back_to_menu_btn: Button = %BackToMenuBtn 

var chosen_gender: String = "Male"
const RANDOM_SCHOOL_PREFIXES = ["Greenwood", "Erin Springs", "Oakridge", "Beacon", "Horizon", "Sterling"]
const RANDOM_SCHOOL_SUFFIXES = ["Academy", "High School", "Institute", "Secondary School"]
const RANDOM_MALE_NAMES = ["James Smith", "Robert Jones", "Michael David", "William Erin"]
const RANDOM_FEMALE_NAMES = ["Mary Johnson", "Patricia Miller", "Jennifer Linda", "Elizabeth Erin"]

func _ready() -> void:
	# Enforce Full Screen Scaling Anchor Metrics
	set_anchors_preset(Control.PRESET_FULL_RECT)
	set_global_position(Vector2.ZERO)
	set_size(get_viewport_rect().size)
	
	# Connect Randomizers and Confirm Interactions
	random_school_btn.pressed.connect(_on_random_school_pressed)
	random_principal_btn.pressed.connect(_on_random_principal_pressed)
	confirm_setup_btn.pressed.connect(_on_confirm_setup_pressed)
	
	# ---- NEW: Back to Main Menu Button Signal Router ----
	if back_to_menu_btn:
		back_to_menu_btn.pressed.connect(_on_back_to_menu_pressed)
	
	# ---- FIXED: Gender selection immediately generates an appropriate name ----
	male_check_box.toggled.connect(func(pressed): 
		if pressed: 
			chosen_gender = "Male"
			_on_random_principal_pressed() # Instantly swap to a male name
	)
	female_check_box.toggled.connect(func(pressed): 
		if pressed: 
			chosen_gender = "Female"
			_on_random_principal_pressed() # Instantly swap to a female name
	)
	
	# Configure the locked School Type dropdown options 
	school_type_option.clear() 
	school_type_option.add_item("Secondary School") 
	school_type_option.add_item("Primary School (Disabled)") 
	school_type_option.add_item("University (Disabled)") 
	school_type_option.set_item_disabled(1, true) 
	school_type_option.set_item_disabled(2, true) 
	school_type_option.select(0) 
	
	# Generate initial placeholders 
	_on_random_school_pressed() 
	_on_random_principal_pressed() 

# Inside your school_setup.gd script:

func _on_random_school_pressed() -> void:
	# Explicitly clear old states out of memory first
	school_name_input.text = ""
	school_name_input.placeholder_text = ""
	
	var prefix = RANDOM_SCHOOL_PREFIXES[randi() % RANDOM_SCHOOL_PREFIXES.size()]
	var suffix = RANDOM_SCHOOL_SUFFIXES[randi() % RANDOM_SCHOOL_SUFFIXES.size()]
	
	# Assign clean text
	school_name_input.text = prefix + " " + suffix


func _on_random_principal_pressed() -> void:
	# Explicitly clear old states out of memory first
	principal_name_input.text = ""
	principal_name_input.placeholder_text = ""
	
	var new_p_name = ""
	if chosen_gender == "Male":
		new_p_name = RANDOM_MALE_NAMES[randi() % RANDOM_MALE_NAMES.size()]
	else:
		new_p_name = RANDOM_FEMALE_NAMES[randi() % RANDOM_FEMALE_NAMES.size()]
		
	principal_name_input.text = new_p_name

func _on_confirm_setup_pressed() -> void:
	var final_school_name = school_name_input.text.strip_edges() 
	var final_principal_name = principal_name_input.text.strip_edges() 
	
	if final_school_name.is_empty() or final_principal_name.is_empty(): 
		return 
		
	# Route the setup data directly through our parent GameManager node hierarchy
	var game_manager = get_parent()
	if game_manager and game_manager.has_method("confirm_setup_and_start_game"):
		game_manager.confirm_setup_and_start_game(final_school_name, final_principal_name)
	else:
		GlobalTransferData.school_name = final_school_name 
		GlobalTransferData.principal_name = final_principal_name 
		get_tree().change_scene_to_packed(GameManager.GAME_MAP_SCENE)

# ---- NEW: Back to Menu Handler ----
func _on_back_to_menu_pressed() -> void:
	GlobalTransferData.is_sandbox_mode = false
	var game_manager = get_parent()
	if game_manager and game_manager.has_method("_transition_to_scene"):
		game_manager._transition_to_scene(GameManager.MAIN_MENU_SCENE)
	else:
		get_tree().change_scene_to_packed(GameManager.MAIN_MENU_SCENE)
