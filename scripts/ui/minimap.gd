class_name Minimap
## Top-right minimap (E8): the arena layout plus player/enemy/portal markers.
##
## CanvasItem draw_* calls are only valid inside _draw(), so this node buffers
## the shapes it is fed and repaints them. The HUD calls clear() at the start of
## every _update_minimap(), then feeds the frame's rects and circles.
extends Node2D

var _rects: Array[Array] = []
var _circles: Array[Array] = []

## Drops every buffered shape and asks for a repaint.
func clear() -> void:
	_rects.clear()
	_circles.clear()
	queue_redraw()

## Queues a filled rectangle (arena floor / wall tile).
func add_rect(rect: Rect2, colour: Color) -> void:
	_rects.append([rect, colour])

## Queues a filled marker circle (portal / enemy / player).
func add_circle(centre: Vector2, radius: float, colour: Color) -> void:
	_circles.append([centre, radius, colour])

func _draw() -> void:
	for entry in _rects:
		draw_rect(entry[0], entry[1])
	for entry in _circles:
		draw_circle(entry[0], entry[1], entry[2])
