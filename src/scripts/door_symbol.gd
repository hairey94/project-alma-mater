extends Node2D

var edge_normal: Vector2i = Vector2i(0, -1)
var is_inward: bool = true
var draw_color: Color = Color.BLACK

func _draw() -> void:
	var ts = 64.0
	var hs = 32.0
	var lw = 3.0
	var c = draw_color
	var hinge: Vector2
	var along_end: Vector2
	var perp_end: Vector2
	var a1: float
	var a2: float
	if edge_normal == Vector2i(0, -1):
		hinge = Vector2(0, 0)
		along_end = Vector2(ts, 0)
		if is_inward:
			perp_end = Vector2(0, hs)
			a1 = 0.0; a2 = PI / 2
		else:
			perp_end = Vector2(0, -hs)
			a1 = -PI / 2; a2 = 0.0
	elif edge_normal == Vector2i(0, 1):
		hinge = Vector2(0, ts)
		along_end = Vector2(ts, ts)
		if is_inward:
			perp_end = Vector2(0, ts - hs)
			a1 = -PI / 2; a2 = 0.0
		else:
			perp_end = Vector2(0, ts + hs)
			a1 = 0.0; a2 = PI / 2
	elif edge_normal == Vector2i(-1, 0):
		hinge = Vector2(0, 0)
		along_end = Vector2(0, ts)
		if is_inward:
			perp_end = Vector2(hs, 0)
			a1 = 0.0; a2 = PI / 2
		else:
			perp_end = Vector2(-hs, 0)
			a1 = PI / 2; a2 = PI
	elif edge_normal == Vector2i(1, 0):
		hinge = Vector2(ts, 0)
		along_end = Vector2(ts, ts)
		if is_inward:
			perp_end = Vector2(ts - hs, 0)
			a1 = PI / 2; a2 = PI
		else:
			perp_end = Vector2(ts + hs, 0)
			a1 = 0.0; a2 = PI / 2
	draw_line(hinge, along_end, c, lw)
	draw_line(hinge, perp_end, c, lw)
	draw_arc(hinge, hs, a1, a2, 20, c, lw)
