extends Node

var school_name: String = "Project Alma Mater"
var principal_name: String = "Principal Erin"
var is_sandbox_mode: bool = false

# ---- NEW SYSTEM MODES ----
enum GameMode { GAME, ARCHITECTURAL, MANAGEMENT, BULLDOZER }
var current_mode: GameMode = GameMode.GAME
