extends Resource
class_name StudentData

enum ActivityState { IDLE, COMMUTING, IN_CLASS, BREAK, EATING, LEAVING }

@export var student_id: int
@export var first_name: String
@export var last_name: String
@export var grade: int

var energy: float = 1.0
var hunger: float = 0.0
var happiness: float = 0.5

var activity_state: int = ActivityState.COMMUTING
var target_cell: Vector2i = Vector2i(-1, -1)

var assigned_classroom_idx: int = -1
var assigned_building_idx: int = -1
