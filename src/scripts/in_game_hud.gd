extends CanvasLayer

signal mode_changed(new_mode: GlobalTransferData.GameMode)

@onready var water_bar: ProgressBar = %WaterBar
@onready var sewage_bar: ProgressBar = %SewageBar
@onready var electric_bar: ProgressBar = %ElectricBar
@onready var internet_bar: ProgressBar = %InternetBar

@onready var game_mode_btn: Button = %GameModeBtn
@onready var arch_mode_btn: Button = %ArchModeBtn
@onready var management_mode_btn: Button = %ManagementModeBtn
@onready var bulldozer_btn: Button = %BulldozerBtn
@onready var architectural_border: Panel = %ArchitecturalBorder
@onready var bulldozer_border: Panel = %BulldozerBorder

@onready var school_name_label: Label = %SchoolNameLabel
@onready var principal_name_label: Label = %PrincipalNameLabel
@onready var floor_indicator_label: Label = %FloorIndicatorLabel
@onready var speed_indicator_label: Label = %SpeedIndicatorLabel
@onready var mode_notification_label: Label = %ModeNotificationLabel
@onready var pause_play_btn: Button = %PausePlayBtn
@onready var forward_btn: Button = %ForwardBtn
@onready var fast_forward_btn: Button = %FastForwardBtn
@onready var drawer_panel: PanelContainer = %DrawerPanel
@onready var drawer_sub_tab_bar: TabBar = %DrawerSubTabBar
@onready var close_drawer_btn: Button = %CloseDrawerBtn

@onready var time_date_label: RichTextLabel = %TimeDateLabel
@onready var season_label: Label = %SeasonLabel
@onready var days_left_label: Label = %DaysLeftLabel
@onready var level_number_label: Label = %LevelNumberLabel
@onready var level_name_label: Label = %LevelNameLabel
@onready var cash_flow_label: Label = %CashFlowLabel
@onready var happiness_matrix: HBoxContainer = %HappinessMatrix

@onready var services_tab_btn: Button = %ServicesTabBtn
@onready var add_building_btn: Button = %AddBuildingBtn
@onready var facilities_tab_btn: Button = %FacilitiesTabBtn
@onready var residential_tab_btn: Button = %ResidentialTabBtn
@onready var rooms_tab_btn: Button = %RoomsTabBtn
@onready var doors_tab_btn: Button = %DoorsTabBtn
@onready var corridor_btn: Button = %CorridorBtn
@onready var upper_floor_btn: Button = %UpperFloorBtn
@onready var staircase_btn: Button = %StaircaseBtn
@onready var elevator_btn: Button = %ElevatorBtn

@onready var drag_corner_btn: Button = %DragCornerBtn
@onready var pick_individual_btn: Button = %PickIndividualBtn
@onready var services_grid: GridContainer = %ServicesGrid
@onready var scroll_container: ScrollContainer = %ScrollContainer

const TimeDisplay = preload("res://src/scripts/hud/time_display.gd")
const FloatingConfirmWidget = preload("res://src/scripts/hud/floating_confirm_widget.gd")
const BuildingRenameDialog = preload("res://src/scripts/hud/building_rename_dialog.gd")

var time_display: TimeDisplay
var confirm_widget: FloatingConfirmWidget
var rename_dialog: BuildingRenameDialog

var current_input_tool: String = "drag"
var is_game_paused: bool = false
var current_active_tab: String = ""
var current_sub_tab: String = ""
var is_mouse_over_ui: bool = false
var play_icon_x: float = 4 * 64
var pause_icon_x: float = 5 * 64
var _speed_toggle_lock: bool = false

func _ready() -> void:
	time_display = TimeDisplay.new()
	time_display.setup(time_date_label, season_label, days_left_label)

	confirm_widget = FloatingConfirmWidget.new()
	confirm_widget.setup(self)

	rename_dialog = BuildingRenameDialog.new()

	GlobalSignalBus.minute_ticked.connect(time_display.on_time_tick)
	GlobalSignalBus.treasury_changed.connect(_on_treasury_wallet_update)
	GlobalSignalBus.floor_view_swapped.connect(_on_floor_changed)

	pause_play_btn.toggle_mode = true
	pause_play_btn.toggled.connect(_on_pause_play_toggled)
	forward_btn.toggle_mode = true
	fast_forward_btn.toggle_mode = true
	var speed_group := ButtonGroup.new()
	speed_group.allow_unpress = false
	forward_btn.button_group = speed_group
	fast_forward_btn.button_group = speed_group
	forward_btn.toggled.connect(_on_forward_toggled)
	fast_forward_btn.toggled.connect(_on_fast_forward_toggled)

	drawer_sub_tab_bar.tab_changed.connect(_on_drawer_sub_tab_changed)

	services_tab_btn.pressed.connect(func(): _on_toolbar_button_clicked("services", "utilities"))
	add_building_btn.pressed.connect(func(): _on_toolbar_button_clicked("building", "block"))
	facilities_tab_btn.pressed.connect(func(): _on_toolbar_button_clicked("facilities", "general"))
	residential_tab_btn.pressed.connect(func(): _on_toolbar_button_clicked("residential", "housing"))
	rooms_tab_btn.pressed.connect(func(): _on_toolbar_button_clicked("rooms", "general"))
	doors_tab_btn.pressed.connect(func(): _on_toolbar_button_clicked("doors", "entrance"))
	corridor_btn.pressed.connect(func(): _on_toolbar_button_clicked("corridor", "hallway"))
	upper_floor_btn.pressed.connect(func(): _on_toolbar_button_clicked("upper floor", "new floor"))
	staircase_btn.pressed.connect(func(): _on_toolbar_button_clicked("staircase", "stairs"))
	elevator_btn.pressed.connect(func(): _on_toolbar_button_clicked("elevator", "elevator"))

	drag_corner_btn.pressed.connect(func(): _set_input_tool("drag"))
	pick_individual_btn.pressed.connect(func(): _set_input_tool("tiles"))

	if close_drawer_btn:
		close_drawer_btn.pressed.connect(_close_construction_drawer)

	game_mode_btn.pressed.connect(func(): _swap_global_engine_mode(GlobalTransferData.GameMode.GAME))
	arch_mode_btn.pressed.connect(func(): _swap_global_engine_mode(GlobalTransferData.GameMode.ARCHITECTURAL))
	management_mode_btn.pressed.connect(func(): _swap_global_engine_mode(GlobalTransferData.GameMode.MANAGEMENT))
	bulldozer_btn.pressed.connect(_on_bulldozer_pressed)

	var mode_group := ButtonGroup.new()
	game_mode_btn.button_group = mode_group
	arch_mode_btn.button_group = mode_group
	management_mode_btn.button_group = mode_group

	var tool_group := ButtonGroup.new()
	drag_corner_btn.button_group = tool_group
	pick_individual_btn.button_group = tool_group
	drag_corner_btn.toggle_mode = true
	pick_individual_btn.toggle_mode = true
	drag_corner_btn.button_pressed = true

	school_name_label.text = GlobalTransferData.school_name
	principal_name_label.text = GlobalTransferData.principal_name
	floor_indicator_label.text = _floor_display_name(0)
	speed_indicator_label.text = "1×"

	_init_demand_bars()
	_init_finance()
	_init_scrollbar_style()
	_init_hover_safety()

	level_number_label.text = "9"
	level_name_label.text = "Public Large School"
	drawer_panel.visible = false

	game_mode_btn.button_pressed = true
	_swap_global_engine_mode(GlobalTransferData.GameMode.GAME)

func _init_demand_bars() -> void:
	water_bar.max_value = 100.0
	sewage_bar.max_value = 100.0
	electric_bar.max_value = 100.0
	internet_bar.max_value = 100.0
	water_bar.value = 45.0
	sewage_bar.value = 20.0
	electric_bar.value = 65.0
	internet_bar.value = 80.0

func _init_finance() -> void:
	if GlobalTransferData.is_sandbox_mode:
		_on_treasury_wallet_update(99999999)
	else:
		_on_treasury_wallet_update(150000)

func _init_scrollbar_style() -> void:
	if not scroll_container:
		return
	var bar: VScrollBar = scroll_container.get_v_scroll_bar()
	var grabber := StyleBoxFlat.new()
	grabber.bg_color = Color("#475569", 0.8)
	grabber.set_corner_radius_all(4)
	var track := StyleBoxFlat.new()
	track.bg_color = Color("#0f172a", 0.15)
	track.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("grabber", grabber)
	bar.add_theme_stylebox_override("grabber_hover", grabber)
	bar.add_theme_stylebox_override("grabber_pressed", grabber)
	bar.add_theme_stylebox_override("scroll", track)
	bar.add_theme_stylebox_override("scroll_focus", track)
	bar.add_theme_icon_override("decrement", ImageTexture.new())
	bar.add_theme_icon_override("increment", ImageTexture.new())
	bar.add_theme_icon_override("decrement_highlight", ImageTexture.new())
	bar.add_theme_icon_override("increment_highlight", ImageTexture.new())
	bar.custom_minimum_size.x = 6

func _init_hover_safety() -> void:
	var ui_nodes = [drawer_panel, scroll_container, services_grid]
	for node in ui_nodes:
		if node:
			node.mouse_entered.connect(func(): is_mouse_over_ui = true)
			node.mouse_exited.connect(func(): is_mouse_over_ui = false)

func _on_toolbar_button_clicked(category: String, default_sub: String) -> void:
	_swap_global_engine_mode(GlobalTransferData.GameMode.ARCHITECTURAL)
	arch_mode_btn.button_pressed = true

	if drawer_panel.visible and current_active_tab == category:
		_close_construction_drawer()
		return

	current_active_tab = category
	current_sub_tab = default_sub
	_setup_drawer_tabs_for_category(category)
	drawer_sub_tab_bar.current_tab = 0
	_populate_drawer_items(category, default_sub)
	_open_construction_drawer()

func _clear_all_toolbar_highlights() -> void:
	for btn in [services_tab_btn, add_building_btn, facilities_tab_btn, residential_tab_btn,
		rooms_tab_btn, doors_tab_btn, corridor_btn, upper_floor_btn, staircase_btn, elevator_btn]:
		btn.button_pressed = false

func _on_drawer_sub_tab_changed(tab_index: int) -> void:
	if tab_index < 0 or not drawer_sub_tab_bar or drawer_sub_tab_bar.get_tab_count() == 0:
		return
	var raw = drawer_sub_tab_bar.get_tab_metadata(tab_index)
	if raw == null:
		return
	var sub_key: String = str(raw)
	if current_active_tab == "building" and sub_key == "block":
		_auto_select_item("Campus block")

func _setup_drawer_tabs_for_category(category: String) -> void:
	if not drawer_sub_tab_bar:
		return
	drawer_sub_tab_bar.tab_count = 0
	if not BuildingDatabase.BUILDING_DATABASE.has(category):
		return
	for sub_key in BuildingDatabase.BUILDING_DATABASE[category]:
		var data = BuildingDatabase.BUILDING_DATABASE[category][sub_key]
		var tex = load(data["sheet_path"])
		var icon := AtlasTexture.new()
		icon.atlas = tex
		icon.region = data["tab_icon_region"]
		drawer_sub_tab_bar.add_tab("")
		var idx = drawer_sub_tab_bar.tab_count - 1
		drawer_sub_tab_bar.set_tab_metadata(idx, sub_key)
		drawer_sub_tab_bar.set_tab_icon(idx, icon)
		drawer_sub_tab_bar.set_tab_tooltip(idx, data.get("tab_tooltip", sub_key.capitalize()))

func _populate_drawer_items(category: String, sub: String) -> void:
	if not services_grid:
		return
	for child in services_grid.get_children():
		child.queue_free()
	if scroll_container:
		scroll_container.scroll_vertical = 0
	if not BuildingDatabase.BUILDING_DATABASE.has(category):
		return
	var sub_data = BuildingDatabase.BUILDING_DATABASE[category].get(sub)
	if not sub_data:
		return
	var base_tex = load(sub_data["sheet_path"])
	var btn_group = ButtonGroup.new()
	for item in sub_data["items"]:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(72, 72)
		btn.expand_icon = true
		btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		btn.toggle_mode = true
		btn.button_group = btn_group

		var normal_style := StyleBoxFlat.new()
		normal_style.bg_color = Color("#334155", 0.85)
		normal_style.set_corner_radius_all(6)
		btn.add_theme_stylebox_override("normal", normal_style)

		var hover_style := StyleBoxFlat.new()
		hover_style.bg_color = Color("#475569", 0.85)
		hover_style.set_corner_radius_all(6)
		btn.add_theme_stylebox_override("hover", hover_style)

		var pressed_style := StyleBoxFlat.new()
		pressed_style.bg_color = Color("#3b82f6", 0.85)
		pressed_style.set_corner_radius_all(6)
		btn.add_theme_stylebox_override("pressed", pressed_style)

		var hover_pressed_style := StyleBoxFlat.new()
		hover_pressed_style.bg_color = Color("#60a5fa", 0.85)
		hover_pressed_style.set_corner_radius_all(6)
		btn.add_theme_stylebox_override("hover_pressed", hover_pressed_style)

		var slice := AtlasTexture.new()
		slice.atlas = base_tex
		slice.region = item["region"]
		btn.icon = slice
		btn.tooltip_text = "%s\nCost: $%d" % [item["name"], item["cost"]]
		btn.set_meta("item_name", item["name"])
		btn.pressed.connect(func(name = item["name"]): _on_building_selected(name))
		btn.mouse_entered.connect(func(): is_mouse_over_ui = true)
		btn.mouse_exited.connect(func(): is_mouse_over_ui = false)
		services_grid.add_child(btn)
	drawer_sub_tab_bar.get_parent().queue_sort()

func _auto_select_item(item_name: String) -> void:
	for child in services_grid.get_children():
		if child is Button and child.get_meta("item_name", "") == item_name:
			child.button_pressed = true
			return
	_on_building_selected(item_name)

func _open_construction_drawer() -> void:
	drawer_panel.visible = true
	_clear_all_toolbar_highlights()
	var tab_map = {
		"services": services_tab_btn, "building": add_building_btn, "facilities": facilities_tab_btn,
		"residential": residential_tab_btn, "rooms": rooms_tab_btn, "doors": doors_tab_btn,
		"corridor": corridor_btn, "upper floor": upper_floor_btn, "staircase": staircase_btn, "elevator": elevator_btn
	}
	if current_active_tab in tab_map:
		tab_map[current_active_tab].button_pressed = true

	var vp = get_viewport().get_visible_rect().size
	var tx = (vp.x / 2.0) - (drawer_panel.size.x / 2.0)
	var ty = vp.y - 112.0 - drawer_panel.size.y
	drawer_panel.global_position.x = tx
	var tween = create_tween()
	drawer_panel.global_position.y = ty + 40.0
	tween.tween_property(drawer_panel, "global_position:y", ty, 0.15).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func deselect_toolbar() -> void:
	_clear_all_toolbar_highlights()
	current_active_tab = ""
	drawer_panel.visible = false

func _close_construction_drawer() -> void:
	_clear_all_toolbar_highlights()
	current_active_tab = ""
	var vp = get_viewport().get_visible_rect().size
	var tween = create_tween()
	tween.tween_property(drawer_panel, "global_position:y", vp.y + 50.0, 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.finished.connect(func(): drawer_panel.visible = false)

func _on_bulldozer_pressed() -> void:
	if bulldozer_btn.button_pressed:
		_swap_global_engine_mode(GlobalTransferData.GameMode.BULLDOZER)
	else:
		_swap_global_engine_mode(GlobalTransferData.GameMode.ARCHITECTURAL)

func _update_speed_display() -> void:
	if GlobalTransferData.current_mode != GlobalTransferData.GameMode.GAME or is_game_paused:
		speed_indicator_label.text = "⏸"
	elif fast_forward_btn.button_pressed:
		speed_indicator_label.text = "3×"
	elif forward_btn.button_pressed:
		speed_indicator_label.text = "2×"
	else:
		speed_indicator_label.text = "1×"

func _sync_speed_buttons() -> void:
	_speed_toggle_lock = true
	var in_game := GlobalTransferData.current_mode == GlobalTransferData.GameMode.GAME
	if in_game:
		pause_play_btn.button_pressed = not is_game_paused
		if forward_btn.button_pressed:
			pass
		elif fast_forward_btn.button_pressed:
			pass
		else:
			forward_btn.button_pressed = false
			fast_forward_btn.button_pressed = false
	else:
		pause_play_btn.button_pressed = false
		forward_btn.button_pressed = false
		fast_forward_btn.button_pressed = false
	_speed_toggle_lock = false
	_update_speed_display()

func _swap_global_engine_mode(target: GlobalTransferData.GameMode) -> void:
	GlobalTransferData.current_mode = target
	_sync_speed_buttons()
	architectural_border.visible = false
	bulldozer_border.visible = false
	var should_grid = target == GlobalTransferData.GameMode.ARCHITECTURAL or target == GlobalTransferData.GameMode.BULLDOZER
	var grid = _get_blueprint_grid()
	if grid:
		grid.visible = should_grid

	if target != GlobalTransferData.GameMode.ARCHITECTURAL and target != GlobalTransferData.GameMode.BULLDOZER:
		bulldozer_btn.button_pressed = false

	match target:
		GlobalTransferData.GameMode.GAME:
			TimeManager.set_speed(1.0)
			_pause_btn_icon(false)
			is_game_paused = false
		GlobalTransferData.GameMode.ARCHITECTURAL:
			TimeManager.set_speed(0.0)
			_pause_btn_icon(true)
			architectural_border.visible = true
		GlobalTransferData.GameMode.MANAGEMENT:
			TimeManager.set_speed(0.0)
			_pause_btn_icon(true)
		GlobalTransferData.GameMode.BULLDOZER:
			TimeManager.set_speed(0.0)
			_pause_btn_icon(true)
			architectural_border.visible = true
			bulldozer_border.visible = true
			_close_construction_drawer()

	mode_changed.emit(target)

func _set_input_tool(tool_name: String) -> void:
	current_input_tool = tool_name
	var game_map = find_parent("GameMap")
	if not game_map:
		game_map = get_tree().current_scene.find_child("GameMap", true, false)
	if game_map and game_map.has_method("set_placement_tool"):
		game_map.set_placement_tool(tool_name)
		if game_map.has_method("cancel_placement"):
			game_map.cancel_placement()

func _pause_btn_icon(paused: bool) -> void:
	var atlas = pause_play_btn.icon as AtlasTexture
	if atlas:
		var r = atlas.region
		r.position.x = pause_icon_x if paused else play_icon_x
		atlas.region = r

func _get_blueprint_grid() -> ColorRect:
	return get_node_or_null("../BlueprintGridLayer") as ColorRect

func _on_building_selected(item_name: String) -> void:
	var game_map = find_parent("GameMap")
	if not game_map:
		game_map = get_tree().current_scene.find_child("GameMap", true, false)
	if game_map and game_map.has_method("set_active_placement_item"):
		game_map.set_active_placement_item(item_name)
		_close_construction_drawer()

func _on_time_matrix_tick(hour: int, minute: int, day: int, month: String, year: int, season_index: int) -> void:
	time_display.on_time_tick(hour, minute, day, month, year, season_index)

func _floor_display_name(floor: int) -> String:
	return "G" if floor == 0 else str(floor)

func _on_floor_changed(target_floor: int) -> void:
	floor_indicator_label.text = _floor_display_name(target_floor)

func _on_treasury_wallet_update(new_total: float) -> void:
	var label = get_node_or_null("%TreasuryLabel")
	if label:
		label.text = "$%d" % new_total

func _on_pause_play_toggled(pressed: bool) -> void:
	if _speed_toggle_lock:
		return
	if GlobalTransferData.current_mode != GlobalTransferData.GameMode.GAME:
		_speed_toggle_lock = true
		pause_play_btn.button_pressed = false
		_speed_toggle_lock = false
		return
	_speed_toggle_lock = true
	forward_btn.button_pressed = false
	fast_forward_btn.button_pressed = false
	_speed_toggle_lock = false
	is_game_paused = not pressed
	if pressed:
		_pause_btn_icon(false)
		TimeManager.set_speed(1.0)
	else:
		_pause_btn_icon(true)
		TimeManager.set_speed(0.0)
	_update_speed_display()

func _on_forward_toggled(pressed: bool) -> void:
	if _speed_toggle_lock:
		return
	if GlobalTransferData.current_mode != GlobalTransferData.GameMode.GAME:
		_speed_toggle_lock = true
		forward_btn.button_pressed = false
		_speed_toggle_lock = false
		return
	if not pause_play_btn.button_pressed:
		_speed_toggle_lock = true
		forward_btn.button_pressed = false
		_speed_toggle_lock = false
		return
	_speed_toggle_lock = true
	if pressed:
		fast_forward_btn.button_pressed = false
		TimeManager.set_speed(2.0)
		pause_play_btn.button_pressed = true
		_pause_btn_icon(false)
	else:
		pause_play_btn.button_pressed = true
		TimeManager.set_speed(1.0)
		_pause_btn_icon(false)
	_speed_toggle_lock = false
	_update_speed_display()

func _on_fast_forward_toggled(pressed: bool) -> void:
	if _speed_toggle_lock:
		return
	if GlobalTransferData.current_mode != GlobalTransferData.GameMode.GAME:
		_speed_toggle_lock = true
		fast_forward_btn.button_pressed = false
		_speed_toggle_lock = false
		return
	if not pause_play_btn.button_pressed:
		_speed_toggle_lock = true
		fast_forward_btn.button_pressed = false
		_speed_toggle_lock = false
		return
	_speed_toggle_lock = true
	if pressed:
		forward_btn.button_pressed = false
		TimeManager.set_speed(3.0)
		pause_play_btn.button_pressed = true
		_pause_btn_icon(false)
	else:
		pause_play_btn.button_pressed = true
		TimeManager.set_speed(1.0)
		_pause_btn_icon(false)
	_speed_toggle_lock = false
	_update_speed_display()

func set_happiness_highlight(index: int) -> void:
	index = clampi(index, 0, 4)
	for i in happiness_matrix.get_children():
		var smiley = i as TextureRect
		if smiley:
			smiley.modulate = Color(1, 1, 1, 1.0 if i.get_index() == index else 0.25)

func display_floating_approval_bubble(spawn_pos: Vector2, map_node: Node2D) -> void:
	confirm_widget.display(spawn_pos, map_node)

func dismiss_floating_approval_bubble() -> void:
	confirm_widget.dismiss()

func show_building_rename_dialog(default_name: String, callback: Callable) -> void:
	rename_dialog.show(self, default_name, callback)

func show_hud_message(msg: String) -> void:
	if mode_notification_label:
		mode_notification_label.text = msg
		await get_tree().create_timer(3.0).timeout
		mode_notification_label.text = ""
