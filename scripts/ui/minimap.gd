class_name Minimap
## Top-right minimap (E8): the arena layout plus player/enemy/portal markers and
## the direction the caster is facing.
##
## CanvasItem draw_* calls are only valid inside _draw(), so this node buffers
## the shapes it is fed and repaints them. The HUD calls clear() at the start of
## every _update_minimap(), then feeds the frame's rects and circles.
##
## Everything is in GRID CELLS, not pixels: the HUD scales the node so that the
## arena fills a fixed box on screen. That keeps the marker radii meaningful --
## sizing them in screen pixels instead made every demon a single dot.
##
## The facing cone needs no flipping: the map is drawn as +X right / +Y down,
## which is exactly world +X / +Z seen from above, so a world direction maps
## straight onto the canvas.
extends Node2D

## Half-angle of the view cone, degrees. Matches the camera's FOV closely
## enough to read as "what the caster can see" without being a second crosshair.
const FACING_FOV := 70.0
## How far the cone reaches, in cells. Long enough to point at a doorway a few
## rooms away, short enough not to cover the map.
const FACING_REACH := 2.8
const FACING_FILL := Color(1.0, 0.86, 0.42, 0.15)
const FACING_RAY := Color(1.0, 0.9, 0.5, 0.45)
## Arc segments; the cone is flat-shaded, more would not read any better.
const FACING_STEPS := 10

var _rects: Array[Array] = []
var _circles: Array[Array] = []
var _extent := Vector2.ZERO
## Facing cone: null until the HUD feeds one this frame.
var _facing: Array = []

## Arena size in cells. Drawn as a dark panel with a border so the map still
## reads against a bright office floor.
func set_extent(cells: Vector2) -> void:
	_extent = cells

## Drops every buffered shape and asks for a repaint.
func clear() -> void:
	_rects.clear()
	_circles.clear()
	_facing = []
	queue_redraw()

## Queues a filled rectangle (arena floor / wall tile), in cells.
func add_rect(rect: Rect2, colour: Color) -> void:
	_rects.append([rect, colour])

## Queues a filled marker circle (portal / enemy / player), radius in cells.
func add_circle(centre: Vector2, radius: float, colour: Color) -> void:
	_circles.append([centre, radius, colour])

## Queues the view cone: where the caster is standing and which way they face.
## `dir` is any non-zero 2D direction in map space (only its angle matters).
func set_facing(origin: Vector2, dir: Vector2) -> void:
	if dir.length_squared() < 0.000001:
		_facing = []
		return
	_facing = [origin, dir.normalized()]

## True when this frame has a facing cone queued (the suite checks it tracks the
## camera instead of staying at some default).
func has_facing() -> bool:
	return not _facing.is_empty()

## Angle of the queued facing cone in radians (0 = map +X).
func facing_angle() -> float:
	if _facing.is_empty():
		return 0.0
	return (_facing[1] as Vector2).angle()

func _draw() -> void:
	if _extent.x > 0.0 and _extent.y > 0.0:
		draw_rect(Rect2(Vector2.ZERO, _extent), Color(0.03, 0.03, 0.05, 0.72))
	for entry in _rects:
		draw_rect(entry[0], entry[1])
	# The cone goes under the markers so the player dot stays on top of it.
	_draw_facing()
	for entry in _circles:
		draw_circle(entry[0], entry[1], entry[2])
	if _extent.x > 0.0 and _extent.y > 0.0:
		draw_rect(Rect2(Vector2.ZERO, _extent), Color(0.55, 0.57, 0.66), false, 0.08)

func _draw_facing() -> void:
	if _facing.is_empty():
		return
	var apex: Vector2 = _facing[0]
	var dir: Vector2 = _facing[1]
	var half := deg_to_rad(FACING_FOV) * 0.5
	var base := dir.angle()
	var cone := PackedVector2Array([apex])
	for i in range(FACING_STEPS + 1):
		var a := base - half + (2.0 * half) * float(i) / float(FACING_STEPS)
		cone.append(apex + Vector2.from_angle(a) * FACING_REACH)
	draw_colored_polygon(cone, FACING_FILL)
	# A brighter centre ray down the middle: the cone alone is symmetric, and
	# without it you cannot tell which way the 70 degrees are pointing.
	draw_line(apex, apex + dir * FACING_REACH, FACING_RAY, 0.07)