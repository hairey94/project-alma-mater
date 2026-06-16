extends RefCounted
class_name GridPathfinder

const GRID_W = 64
const GRID_H = 66
const MAX_ITERATIONS = 4096

var _directions: Array[Vector2i] = [
	Vector2i(0, -1),
	Vector2i(0, 1),
	Vector2i(-1, 0),
	Vector2i(1, 0)
]

func find_path(from: Vector2i, to: Vector2i, blocked: Dictionary) -> Array[Vector2i]:
	if from == to:
		return [from]
	if not _in_bounds(from) or not _in_bounds(to):
		return []
	if blocked.has(to):
		return []

	var open: Array[Vector2i] = [from]
	var came_from: Dictionary = {}
	var g_score: Dictionary = {}
	var f_score: Dictionary = {}

	var key_from = _key(from)
	g_score[key_from] = 0
	f_score[key_from] = _heuristic(from, to)

	var iterations = 0

	while not open.is_empty() and iterations < MAX_ITERATIONS:
		iterations += 1

		var current = open[0]
		var current_f = f_score.get(_key(current), INF)
		var current_idx = 0
		for i in range(1, open.size()):
			var f = f_score.get(_key(open[i]), INF)
			if f < current_f:
				current = open[i]
				current_f = f
				current_idx = i

		if current == to:
			return _reconstruct_path(came_from, current)

		open.remove_at(current_idx)

		for d in _directions:
			var neighbor = current + d
			var key_n = _key(neighbor)
			if not _in_bounds(neighbor) or blocked.has(neighbor):
				continue
			if neighbor == from and from != to:
				continue

			var tentative_g = g_score.get(_key(current), INF) + 1
			if tentative_g < g_score.get(key_n, INF):
				came_from[key_n] = current
				g_score[key_n] = tentative_g
				f_score[key_n] = tentative_g + _heuristic(neighbor, to)
				if not neighbor in open:
					open.append(neighbor)

	return []

func _in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < GRID_W and cell.y >= 0 and cell.y < GRID_H

func _key(cell: Vector2i) -> int:
	return cell.y * GRID_W + cell.x

func _heuristic(a: Vector2i, b: Vector2i) -> int:
	return abs(a.x - b.x) + abs(a.y - b.y)

func _reconstruct_path(came_from: Dictionary, current: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = [current]
	while came_from.has(_key(current)):
		current = came_from[_key(current)]
		path.insert(0, current)
	return path
