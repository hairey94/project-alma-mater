extends Node

const SECONDS_PER_MINUTE_1X : float = 1.0
const SECONDS_PER_MINUTE_2X : float = 0.4
const SECONDS_PER_MINUTE_3X : float = 0.1

const MONTHS : Array[String] = [
	"Jan", "Feb", "Mar", "Apr", "May", "Jun", 
	"Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
]

const DAYS_IN_MONTHS : Array[int] = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]

# =============================================================================
# CALENDAR STATE TRACKING (Configured to start: 1 Sep 2026 at 08:00)
# =============================================================================
var current_minute : int = 0       # 🛑 Changed from 43 to 0
var current_hour : int = 8         # 🛑 Changed from 0 to 8 (08:00 AM)
var current_day : int = 1          # 🛑 Changed from 2 to 1 (1st day of the month)
var current_month_index : int = 8  # Index 8 is September (This remains correct)
var current_year : int = 2026      # 2026 (This remains correct)

var current_speed_multiplier : float = 1.0
var is_paused : bool = false
var time_accumulator : float = 0.0

func _ready() -> void:
	_broadcast_time()

func _process(delta: float) -> void:
	# If paused or multiplier drops to/below 0, freeze calculations completely
	if is_paused or current_speed_multiplier <= 0.0:
		return
		
	time_accumulator += delta
	
	# Determine target interval processing speed tier cleanly
	var target_tick_rate : float = SECONDS_PER_MINUTE_1X
	if is_equal_approx(current_speed_multiplier, 2.0):
		target_tick_rate = SECONDS_PER_MINUTE_2X
	elif is_equal_approx(current_speed_multiplier, 3.0):
		target_tick_rate = SECONDS_PER_MINUTE_3X
		
	# Safe while loop extraction for handling fast engine speeds
	while time_accumulator >= target_tick_rate:
		time_accumulator -= target_tick_rate
		_advance_one_minute()

func _advance_one_minute() -> void:
	current_minute += 1
	if current_minute >= 60:
		current_minute = 0
		current_hour += 1
		
		if current_hour >= 24:
			current_hour = 0
			current_day += 1
			_check_date_rollover()
			
	_broadcast_time()

func _check_date_rollover() -> void:
	var max_days : int = DAYS_IN_MONTHS[current_month_index]
	if current_day > max_days:
		current_day = 1
		current_month_index += 1
		if current_month_index >= 12:
			current_month_index = 0
			current_year += 1

func _get_current_season_index() -> int:
	# 0: Autumn | 1: Spring | 2: Summer | 3: Winter
	match current_month_index:
		2, 3, 4: return 1   # Spring
		5, 6, 7: return 2   # Summer
		8, 9, 10: return 0  # Autumn
		_: return 3         # Winter

func _broadcast_time() -> void:
	var month_text : String = MONTHS[current_month_index]
	var season_index : int = _get_current_season_index()
	
	# 🛑 FIXED: Emitting to the exact signature name defined in your Signal Bus
	GlobalSignalBus.minute_ticked.emit(current_hour, current_minute, current_day, month_text, current_year, season_index)

func set_speed(speed_factor: float) -> void:
	if speed_factor == 0.0:
		is_paused = true
		current_speed_multiplier = 0.0
	else:
		is_paused = false
		current_speed_multiplier = speed_factor
		
	_broadcast_time()
