static func calc_centroid(cells: Array[Vector2i]) -> Vector2:
	var cx := 0.0
	var cy := 0.0
	for cell in cells:
		cx += cell.x
		cy += cell.y
	return Vector2(cx / cells.size(), cy / cells.size())

static func rotate_cell_around(cell: Vector2i, centroid: Vector2, count: int) -> Vector2i:
	var k = count % 4
	if k == 0:
		return cell
	var local_x = cell.x - centroid.x
	var local_y = cell.y - centroid.y
	match k:
		1:
			return Vector2i(roundi(centroid.x - local_y), roundi(centroid.y + local_x))
		2:
			return Vector2i(roundi(centroid.x - local_x), roundi(centroid.y - local_y))
		3:
			return Vector2i(roundi(centroid.x + local_y), roundi(centroid.y - local_x))
	return cell

static func rotate_cells_around(cells: Array[Vector2i], centroid: Vector2, count: int) -> Array[Vector2i]:
	var k = count % 4
	if k == 0:
		return cells.duplicate()
	var result: Array[Vector2i] = []
	for cell in cells:
		result.append(rotate_cell_around(cell, centroid, count))
	return result

static func rotate_edge_normal(normal: Vector2i, count: int) -> Vector2i:
	var k = count % 4
	match k:
		0:  return normal
		1:  return Vector2i(-normal.y, normal.x)
		2:  return Vector2i(-normal.x, -normal.y)
		3:  return Vector2i(normal.y, -normal.x)
	return normal

const TILE_SIZE = 64

static func position_label(label: Label, cells: Array[Vector2i], offset_y: float = 0.0) -> void:
	var centroid = calc_centroid(cells)
	var world_pos = centroid * TILE_SIZE + Vector2(TILE_SIZE / 2, TILE_SIZE / 2)
	var font = label.get_theme_font("font")
	if not font:
		font = ThemeDB.fallback_font
	var font_size = label.get_theme_font_size("font_size")
	if font_size <= 0:
		font_size = 18
	var text_size = font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	label.position = world_pos - Vector2(text_size.x / 2, text_size.y / 2) + Vector2(0, offset_y)
