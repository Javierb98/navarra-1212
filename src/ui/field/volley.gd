class_name Volley
extends Node2D
## A flight of bolts arcing from one company to another.
##
## Short-lived: it fires, draws itself for half a second, and frees itself. The
## shafts are staggered so the volley reads as a ragged flight rather than a
## single object sliding across the screen.

var _from := Vector2.ZERO
var _to := Vector2.ZERO
var _count := 10
var _color := Color("3a2f22")
var _arc := 90.0
var _progress := 0.0
var _spread: Array[Vector2] = []


func fire(from_pos: Vector2, to_pos: Vector2, shafts: int, color: Color,
		duration := 0.55) -> void:
	_from = from_pos
	_to = to_pos
	_count = clampi(shafts, 4, 18)
	_color = color
	_arc = clampf(absf(to_pos.x - from_pos.x) * 0.22, 40.0, 120.0)

	# Each shaft lands a little off from the others.
	_spread.clear()
	for i in _count:
		_spread.append(Vector2(
			CompanyBlock._hash(i, 11) * 34.0 - 17.0,
			CompanyBlock._hash(i, 12) * 26.0 - 13.0))

	set_process(true)
	var t := create_tween()
	t.tween_property(self, "_progress", 1.0, duration)
	t.tween_callback(queue_free)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	for i in _count:
		# Stagger the launches across the first part of the flight.
		var launch := float(i) / float(_count) * 0.35
		var phase := (_progress - launch) / 0.65
		if phase <= 0.0 or phase >= 1.0:
			continue

		var target := _to + _spread[i]
		var here := _bezier(_from, target, phase)
		var ahead := _bezier(_from, target, minf(1.0, phase + 0.06))
		var dir := (ahead - here).normalized()
		if dir == Vector2.ZERO:
			continue

		# Fade in on launch and out on landing so nothing pops.
		var alpha := clampf(minf(phase * 6.0, (1.0 - phase) * 5.0), 0.0, 1.0)
		draw_line(here - dir * 6.5, here + dir * 6.5, Color(_color, alpha), 2.2)


## Quadratic arc with the control point lifted above the midpoint.
func _bezier(a: Vector2, b: Vector2, t: float) -> Vector2:
	var control := (a + b) * 0.5 + Vector2(0, -_arc)
	var u := 1.0 - t
	return a * (u * u) + control * (2.0 * u * t) + b * (t * t)
