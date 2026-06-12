extends Node

## =============================================================================
##                         PROJECT ALMA MATER - GLOBAL SIGNAL BUS
## =============================================================================
## This node acts as a centralized event broker (Observer Pattern). 
## Register this file under Project Settings -> Globals (Autoload) as 'GlobalSignalBus'.
## =============================================================================

# -----------------------------------------------------------------------------
# 1. TIME & CALENDAR ENGINE SIGNALS
# -----------------------------------------------------------------------------
## Emitted by TimeManager every time an in-game minute advances.
# Signal updated to carry precise time strings, days, names, and years
signal minute_ticked(hour: int, minute: int, day: int, month: String, year: int, season_index: int)

# -----------------------------------------------------------------------------
# 2. FINANCIAL & DEMOGRAPHIC PERFORMANCE SIGNALS
# -----------------------------------------------------------------------------
## Emitted whenever the school treasury wallet balance increases or decreases.
## Connected to by: Container 5 Finance HUD counters, building placement budget checkers.
signal treasury_changed(current_balance: float)

## Emitted when the overall student satisfaction factor shifts on campus.
## Connected to by: Container 6 Smiley Matrix array displays, principal alert panels.
signal campus_happiness_updated(happiness_index: int)


# -----------------------------------------------------------------------------
# 3. INTERACTIVE PLACEMENT & MODIFIER TOOL PIPELINES
# -----------------------------------------------------------------------------
## Emitted when a category button in the Row 1 Toolbar is pressed.
## Tells the map controller which system blueprint to prepare for mouse operations.
## Common modes: "WATER_TANK", "SEWAGE_PLANT", "CLEAR" (Bulldozer), "ROAD_LINE", "NONE"
signal build_mode_selected(mode_name: String)

## Emitted when the player alters the build filter layout tool state.
## Toggles whether drawing actions stick to grid snapping or drag corner-to-corner.
signal placement_modifier_changed(modifier_type: String, is_enabled: bool)


# -----------------------------------------------------------------------------
# 4. ARCHITECTURAL & VIEWER LAYER SIGNALS
# -----------------------------------------------------------------------------
## Emitted when the player changes the visual perspective to a different floor height.
## Connected to by: Map grid tile visibility layers, room boundaries, interior cameras.
signal floor_view_swapped(target_floor_level: int)


func _ready() -> void:
	print("Project Event Core: GlobalSignalBus event broker loaded and monitoring active.")
