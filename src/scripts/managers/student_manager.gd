extends RefCounted
class_name StudentManager

const StudentData = preload("res://src/scripts/student_data.gd")
const StudentAgent = preload("res://src/scripts/student_agent.gd")
const GridPathfinder = preload("res://src/scripts/managers/grid_pathfinder.gd")

const ENERGY_DECAY_RATE = 0.04
const HUNGER_DECAY_RATE = 0.03
const HAPPINESS_RECOVERY_RATE = 0.02
const PENALTY_MULTIPLIER = 2.5
const HAPPINESS_THRESHOLD = 0.3

const SPAWN_POINTS: Array[Vector2i] = [
	Vector2i(0, 64), Vector2i(0, 65),
	Vector2i(63, 64), Vector2i(63, 65)
]

const SCHEDULES: Dictionary = {
	1: [
		{"hour": 8,  "minute": 0,  "state": StudentData.ActivityState.COMMUTING, "room_type": ""},
		{"hour": 8,  "minute": 30, "state": StudentData.ActivityState.IN_CLASS, "room_type": "Classroom"},
		{"hour": 10, "minute": 0,  "state": StudentData.ActivityState.BREAK,    "room_type": ""},
		{"hour": 10, "minute": 15, "state": StudentData.ActivityState.IN_CLASS, "room_type": "Classroom"},
		{"hour": 11, "minute": 45, "state": StudentData.ActivityState.EATING,   "room_type": "Cafeteria"},
		{"hour": 12, "minute": 30, "state": StudentData.ActivityState.IN_CLASS, "room_type": "Classroom"},
		{"hour": 15, "minute": 0,  "state": StudentData.ActivityState.LEAVING,  "room_type": ""},
	],
	2: [
		{"hour": 8,  "minute": 0,  "state": StudentData.ActivityState.COMMUTING, "room_type": ""},
		{"hour": 8,  "minute": 30, "state": StudentData.ActivityState.IN_CLASS, "room_type": "Classroom"},
		{"hour": 10, "minute": 0,  "state": StudentData.ActivityState.BREAK,    "room_type": ""},
		{"hour": 10, "minute": 15, "state": StudentData.ActivityState.IN_CLASS, "room_type": "Classroom"},
		{"hour": 12, "minute": 0,  "state": StudentData.ActivityState.EATING,   "room_type": "Cafeteria"},
		{"hour": 12, "minute": 45, "state": StudentData.ActivityState.IN_CLASS, "room_type": "Classroom"},
		{"hour": 15, "minute": 0,  "state": StudentData.ActivityState.LEAVING,  "room_type": ""},
	],
	3: [
		{"hour": 8,  "minute": 0,  "state": StudentData.ActivityState.COMMUTING, "room_type": ""},
		{"hour": 8,  "minute": 30, "state": StudentData.ActivityState.IN_CLASS, "room_type": "Classroom"},
		{"hour": 10, "minute": 0,  "state": StudentData.ActivityState.BREAK,    "room_type": ""},
		{"hour": 10, "minute": 15, "state": StudentData.ActivityState.IN_CLASS, "room_type": "Classroom"},
		{"hour": 12, "minute": 15, "state": StudentData.ActivityState.EATING,   "room_type": "Cafeteria"},
		{"hour": 13, "minute": 0,  "state": StudentData.ActivityState.IN_CLASS, "room_type": "Classroom"},
		{"hour": 15, "minute": 0,  "state": StudentData.ActivityState.LEAVING,  "room_type": ""},
	],
	4: [
		{"hour": 8,  "minute": 0,  "state": StudentData.ActivityState.COMMUTING, "room_type": ""},
		{"hour": 8,  "minute": 30, "state": StudentData.ActivityState.IN_CLASS, "room_type": "Classroom"},
		{"hour": 10, "minute": 0,  "state": StudentData.ActivityState.BREAK,    "room_type": ""},
		{"hour": 10, "minute": 15, "state": StudentData.ActivityState.IN_CLASS, "room_type": "Classroom"},
		{"hour": 11, "minute": 30, "state": StudentData.ActivityState.EATING,   "room_type": "Cafeteria"},
		{"hour": 12, "minute": 15, "state": StudentData.ActivityState.IN_CLASS, "room_type": "Classroom"},
		{"hour": 15, "minute": 0,  "state": StudentData.ActivityState.LEAVING,  "room_type": ""},
	],
	5: [
		{"hour": 8,  "minute": 0,  "state": StudentData.ActivityState.COMMUTING, "room_type": ""},
		{"hour": 8,  "minute": 30, "state": StudentData.ActivityState.IN_CLASS, "room_type": "Classroom"},
		{"hour": 10, "minute": 0,  "state": StudentData.ActivityState.BREAK,    "room_type": ""},
		{"hour": 10, "minute": 15, "state": StudentData.ActivityState.IN_CLASS, "room_type": "Classroom"},
		{"hour": 12, "minute": 30, "state": StudentData.ActivityState.EATING,   "room_type": "Cafeteria"},
		{"hour": 13, "minute": 15, "state": StudentData.ActivityState.IN_CLASS, "room_type": "Classroom"},
		{"hour": 15, "minute": 0,  "state": StudentData.ActivityState.LEAVING,  "room_type": ""},
	]
}

var _all_students: Array[StudentData] = []
var _active_agents: Dictionary = {}
var _pathfinder: GridPathfinder
var _agent_parent: Node2D
var _corridor_mgr = null
var _door_mgr = null
var _room_mgr = null
var _next_id: int = 1
var _previous_hour: int = -1
var _initialized: bool = false

func setup(parent: Node2D, corridor_mgr = null, door_mgr = null, room_mgr = null) -> void:
	_agent_parent = parent
	_corridor_mgr = corridor_mgr
	_door_mgr = door_mgr
	_room_mgr = room_mgr
	_pathfinder = GridPathfinder.new()

func initialize_students() -> void:
	_clear_all_agents()
	_all_students.clear()
	_next_id = 1

	var classroom_count = RoomRegistry.count_by_type("Classroom")
	if classroom_count == 0:
		return

	for grade in range(1, 6):
		for i in range(2):
			var s = StudentData.new()
			s.student_id = _next_id
			_next_id += 1
			s.first_name = _random_first_name()
			s.last_name = _random_last_name()
			s.grade = grade

			var classroom_idx = (_all_students.size()) % classroom_count
			var entry = RoomRegistry.get_entry("Classroom", classroom_idx)
			s.assigned_classroom_idx = entry.get("room_index", -1)
			s.assigned_building_idx = entry.get("building_index", -1)

			_all_students.append(s)

	_initialized = true
	_previous_hour = -1

	for s in _all_students:
		s.activity_state = StudentData.ActivityState.COMMUTING
		_dispatch_navigation(s, {"state": StudentData.ActivityState.COMMUTING, "room_type": ""})

func on_minute_ticked(hour: int, minute: int, _day: int, _month: String, _year: int, _season: int) -> void:
	if not _initialized:
		return

	if minute == 0 and hour != _previous_hour:
		_previous_hour = hour
		_evaluate_all(hour)
		_process_happiness_pipeline()

func _evaluate_all(hour: int) -> void:
	for s in _all_students:
		var slot = _current_schedule_entry(s.grade, hour)
		if slot.is_empty():
			continue

		if slot["state"] != s.activity_state:
			var agent = _active_agents.get(s.student_id)
			if agent != null and agent.is_still_walking():
				continue
			s.activity_state = slot["state"]
			_apply_decay(s)
			_apply_environmental_modifier(s)
			_dispatch_navigation(s, slot)

func _current_schedule_entry(grade: int, hour: int) -> Dictionary:
	if not SCHEDULES.has(grade):
		return {}
	for entry in SCHEDULES[grade]:
		if entry["hour"] == hour:
			return entry
	return {}

func _apply_decay(s: StudentData) -> void:
	var mult = TimeManager.current_speed_multiplier
	s.energy = max(0.0, s.energy - ENERGY_DECAY_RATE * mult)
	s.hunger = min(1.0, s.hunger + HUNGER_DECAY_RATE * mult)
	if s.activity_state == StudentData.ActivityState.EATING:
		s.hunger = max(0.0, s.hunger - 0.15)
		s.happiness = min(1.0, s.happiness + HAPPINESS_RECOVERY_RATE)
	if s.activity_state == StudentData.ActivityState.IN_CLASS:
		s.happiness = max(0.0, s.happiness - 0.01)

func _apply_environmental_modifier(s: StudentData) -> void:
	if _building_lacks_utilities(s.assigned_building_idx):
		var mult = TimeManager.current_speed_multiplier
		s.energy = max(0.0, s.energy - ENERGY_DECAY_RATE * (PENALTY_MULTIPLIER - 1.0) * mult)
		s.hunger = min(1.0, s.hunger + HUNGER_DECAY_RATE * (PENALTY_MULTIPLIER - 1.0) * mult)

func _building_lacks_utilities(building_idx: int) -> bool:
	return false

func _process_happiness_pipeline() -> void:
	if _all_students.is_empty():
		return
	var sum = 0.0
	for s in _all_students:
		var satisfaction = (s.happiness + (1.0 - s.hunger) + s.energy) / 3.0
		sum += satisfaction
	var avg = sum / _all_students.size()
	GlobalSignalBus.campus_happiness_updated.emit(avg)

func _dispatch_navigation(s: StudentData, slot: Dictionary) -> void:
	var target: Vector2i
	var from: Vector2i = s.target_cell

	match slot["state"]:
		StudentData.ActivityState.IN_CLASS:
			var entry = _find_classroom_entry(s)
			if entry.is_empty():
				target = _random_walkable_cell(s)
			else:
				target = entry.cells[randi() % entry.cells.size()]

		StudentData.ActivityState.EATING:
			if RoomRegistry.has_room_type("Cafeteria"):
				target = RoomRegistry.get_random_cell_in("Cafeteria")
			else:
				target = _random_walkable_cell(s)

		StudentData.ActivityState.COMMUTING:
			from = SPAWN_POINTS[s.student_id % SPAWN_POINTS.size()]
			target = RoomRegistry.get_closest_cell(from, "Classroom")
			if target == Vector2i(-1, -1):
				target = from

		StudentData.ActivityState.BREAK:
			target = _random_walkable_cell(s)

		StudentData.ActivityState.LEAVING:
			target = SPAWN_POINTS[s.student_id % SPAWN_POINTS.size()]

		_:
			target = _random_walkable_cell(s)

	s.target_cell = target
	_navigate_agent(s, from, target)

func _navigate_agent(s: StudentData, from: Vector2i, to: Vector2i) -> void:
	var agent = _get_or_create_agent(s, from)
	if agent == null:
		return

	var start = from
	if _active_agents.has(s.student_id):
		start = Vector2i(
			int(agent.global_position.x) / 64,
			int(agent.global_position.y) / 64
		)

	var blocked = _get_navigation_blocked_dict(start, to)
	var path = _pathfinder.find_path(start, to, blocked)

	if s.activity_state == StudentData.ActivityState.LEAVING and not path.is_empty():
		path.append(to + Vector2i(0, 2))

	agent.set_path(path)

func _get_navigation_blocked_dict(start: Vector2i, to: Vector2i) -> Dictionary:
	var blocked: Dictionary = {}
	var walkable: Dictionary = {}

	# 1. Roads are always walkable
	for x in range(64):
		walkable[Vector2i(x, 64)] = true
		walkable[Vector2i(x, 65)] = true

	# 2. Corridors are always walkable
	if _corridor_mgr:
		for corr in _corridor_mgr.data:
			for cell in corr.cells:
				walkable[cell] = true

	# 3. Doors are always walkable
	if _door_mgr:
		for door in _door_mgr.data:
			walkable[door.cell] = true

	# 4. Start room is walkable
	if _room_mgr:
		var start_room_idx = _room_mgr.get_at_cell(start)
		if start_room_idx >= 0:
			var start_room = _room_mgr.get_entry(start_room_idx)
			for cell in start_room.cells:
				walkable[cell] = true

	# 5. Target room is walkable
	if _room_mgr:
		var to_room_idx = _room_mgr.get_at_cell(to)
		if to_room_idx >= 0:
			var to_room = _room_mgr.get_entry(to_room_idx)
			for cell in to_room.cells:
				walkable[cell] = true

	# Fill blocked
	for x in range(64):
		for y in range(66):
			var cell = Vector2i(x, y)
			if not walkable.has(cell):
				blocked[cell] = true

	return blocked

func _get_or_create_agent(s: StudentData, spawn_cell: Vector2i) -> StudentAgent:
	if _active_agents.has(s.student_id):
		return _active_agents[s.student_id]

	if _agent_parent == null:
		return null

	var agent = StudentAgent.new()
	agent.setup(s)
	_agent_parent.add_child(agent)
	_active_agents[s.student_id] = agent

	if spawn_cell.x >= 0:
		var px = spawn_cell * 64 + Vector2i(32, 32)
		agent.global_position = Vector2(px.x, px.y)

	return agent

func _find_classroom_entry(s: StudentData) -> Dictionary:
	if s.assigned_classroom_idx < 0:
		return {}
	var count = RoomRegistry.count_by_type("Classroom")
	for i in range(count):
		var entry = RoomRegistry.get_entry("Classroom", i)
		if entry.get("room_index", -1) == s.assigned_classroom_idx:
			return entry
	return {}

func _random_walkable_cell(s: StudentData) -> Vector2i:
	var all = RoomRegistry.get_all_room_cells()
	if all.is_empty():
		return s.target_cell if s.target_cell.x >= 0 else Vector2i(32, 32)
	return all[randi() % all.size()]

func despawn_all() -> void:
	_clear_all_agents()
	_initialized = false

func _clear_all_agents() -> void:
	if _agent_parent == null:
		_active_agents.clear()
		return

	for id in _active_agents:
		var agent = _active_agents[id]
		if is_instance_valid(agent):
			_agent_parent.remove_child(agent)
			agent.queue_free()

	_active_agents.clear()

func has_active_students() -> bool:
	return not _active_agents.is_empty()

func get_all_students() -> Array[StudentData]:
	return _all_students.duplicate()

static func _random_first_name() -> String:
	var names = ["Alex","Jordan","Taylor","Morgan","Riley","Avery","Quinn","Dakota","Hayden","Parker","Casey","Skylar","Rowan","Emerson","Reese","Finley","Logan","Sage","Drew","Harper"]
	return names[randi() % names.size()]

static func _random_last_name() -> String:
	var names = ["Smith","Johnson","Williams","Brown","Jones","Garcia","Miller","Davis","Rodriguez","Martinez","Hernandez","Lopez","Gonzalez","Wilson","Anderson","Thomas","Taylor","Moore","Jackson","Martin"]
	return names[randi() % names.size()]
