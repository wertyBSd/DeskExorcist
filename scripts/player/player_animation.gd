class_name PlayerAnimation
## Code-built animation set for the caster (BlenderInstruction.MD section 4).
##
## The brief's four clips -- idle / run / cast_hold / cast_release -- are
## authored in code as an AnimationPlayer under the caster, animating a pivot
## node (the ModelRoot that holds the hero .glb).  No .tres assets and no
## imported clips are required, so the set still exists when the Blender
## pipeline has not been run.

extends RefCounted

const IDLE := "idle"
const RUN := "run"
const CAST_HOLD := "cast_hold"
const CAST_RELEASE := "cast_release"

## Every clip this builder produces, in creation order.
const CLIPS := [IDLE, RUN, CAST_HOLD, CAST_RELEASE]

## Creates the AnimationPlayer under `host` and returns it.  It animates `pivot`
## (typically the caster's ModelRoot) through the four clips above.  In Godot 4
## clips live in an AnimationLibrary, so the four are packed into the default
## (empty-named) library before being handed to the player.
static func attach(host: Node3D, pivot: Node3D) -> AnimationPlayer:
	var player := AnimationPlayer.new()
	player.name = "Anim"
	host.add_child(player)
	var path := host.get_path_to(pivot)
	var lib := AnimationLibrary.new()
	lib.add_animation(IDLE, _idle(path))
	lib.add_animation(RUN, _run(path))
	lib.add_animation(CAST_HOLD, _cast_hold(path))
	lib.add_animation(CAST_RELEASE, _cast_release(path))
	player.add_animation_library("", lib)
	player.play(IDLE)
	return player

static func _base(length: float, loop: bool = true) -> Animation:
	var anim := Animation.new()
	anim.length = length
	anim.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	return anim

static func _pos_track(anim: Animation, path: NodePath, keys: Array) -> void:
	var t := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(t, NodePath(String(path) + ":position"))
	anim.track_set_interpolation_type(t, Animation.INTERPOLATION_CUBIC)
	for k in keys:
		anim.track_insert_key(t, float(k[0]), k[1])

static func _rot_track(anim: Animation, path: NodePath, keys: Array) -> void:
	var t := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(t, NodePath(String(path) + ":rotation"))
	anim.track_set_interpolation_type(t, Animation.INTERPOLATION_CUBIC)
	for k in keys:
		anim.track_insert_key(t, float(k[0]), k[1])

## A tired office worker's slow breathing sway.
static func _idle(path: NodePath) -> Animation:
	var anim := _base(2.0)
	_pos_track(anim, path, [[0.0, Vector3(0, 0.0, 0)], [1.0, Vector3(0, 0.03, 0)], [2.0, Vector3(0, 0.0, 0)]])
	return anim

## A faster bob with a little lateral lean while moving.
static func _run(path: NodePath) -> Animation:
	var anim := _base(0.6)
	_pos_track(anim, path, [[0.0, Vector3(0, 0.0, 0)], [0.3, Vector3(0, 0.05, 0)], [0.6, Vector3(0, 0.0, 0)]])
	_rot_track(anim, path, [[0.0, Vector3(0, 0, 0.05)], [0.3, Vector3(0, 0, -0.05)], [0.6, Vector3(0, 0, 0.05)]])
	return anim

## Held breath and a fine tremble while a spell is charged (loops).
static func _cast_hold(path: NodePath) -> Animation:
	var anim := _base(0.3)
	_pos_track(anim, path, [[0.0, Vector3(0, 0.06, 0)], [0.15, Vector3(0.01, 0.07, 0)], [0.3, Vector3(0, 0.06, 0)]])
	_rot_track(anim, path, [[0.0, Vector3(0, 0, 0.02)], [0.15, Vector3(0, 0, -0.02)], [0.3, Vector3(0, 0, 0.02)]])
	return anim

## A sharp thrust forward as the spell leaves the hand (one shot).
static func _cast_release(path: NodePath) -> Animation:
	var anim := _base(0.25, false)
	_pos_track(anim, path, [[0.0, Vector3(0, 0.06, 0)], [0.08, Vector3(0, 0.05, -0.15)], [0.25, Vector3(0, 0.0, 0)]])
	return anim