class_name Viewmodel
## First-person casting hands (BlenderInstruction.MD lot 1b).
##
## Parented to the Camera3D, so the pose is locked to the view and costs no
## per-frame transform work. The .glb is cropped at the forearm: the far end is
## pushed behind the eye and clipped by the near plane, leaving a hand and a
## stub of sleeve on screen. Authoring a full arm from the shoulder instead puts
## the forearm 4 cm from the lens, where it reads as a black pillar.
##
## The hands stay inside the caster's 0.4 m capsule radius, so they can never
## poke through a wall no matter where the player stands.
##
## Animation is procedural rather than clip-based (the rest of the cast uses
## PlayerAnimation): a viewmodel has to react to movement, charge and recoil
## every frame, and a four-key AnimationPlayer fights that. The state vocabulary
## is kept identical to PlayerAnimation so the two read the same at the call site.
extends Node3D

## Rest transform in camera space. The .glb runs from about -0.24 (below the
## palms) to +0.01 (above them) vertically, and -0.22..+0.24 along the view axis.
## A -0.20 m Z puts the palms about 0.30 m out -- close enough to read as "his
## hands" rather than "arms reaching out of the screen" -- while still leaving the
## cut ends 0.04 m behind the eye. Keeping REST.y at 0 is what holds the
## forearms down at the bottom corners; raise it and they climb past the eye line,
## which is the outstretched-arms look all over again.
const REST := Vector3(0.0, 0.0, -0.20)

const IDLE := "idle"
const RUN := "run"
const CAST_HOLD := "cast_hold"
const CAST_RELEASE := "cast_release"

## Hands drawn in and up while a spell is charged, scaled by charge progress.
const CHARGE_REACH := Vector3(0.0, 0.045, 0.05)
## The release throw: forward, and back down out of the way.
const RELEASE_REACH := Vector3(0.0, -0.015, -0.11)
const RELEASE_TIME := 0.22
## Recoil when a holy bolt is fired -- smaller than a cast, but it fires often.
const FIRE_REACH := Vector3(0.0, 0.012, -0.035)
const FIRE_TIME := 0.10
## Charge orb: how far it grows between an empty palm and a fully charged one.
const ORB_MIN := 0.55
const ORB_MAX := 1.35
## Radius of the orb's glowing core, in metres at scale 1. Everything else about
## it is relative to that (see ChargeOrb), so this is the only size to set.
const ORB_RADIUS := 0.040
## How fast the rings and motes turn. Both are driven by the charge so an empty
## palm is nearly still and a full one is visibly seeping.
const SPIN_IDLE := 0.25
const SPIN_CHARGED := 2.6
## How long the orb takes to sweep from one spell's colour to the next.
const COLOUR_SWITCH := 0.18

## Colour the charge takes when nothing has been charged yet: the same warm
## white the GDD uses for holy magic.
const NEUTRAL_CHARGE := ChargeOrb.NEUTRAL

## Where the orb hangs in the .glb's own space: the gap between the two palms,
## at their depth, so it sits in front of the hands rather than out in the
## arena. This is copied rather than derived -- the .glb bakes every transform
## into its meshes, so the value only exists inside the model file.
const ORB_AT := Vector3(0.0, -0.10, -0.17)

var state: String = IDLE
## 0..1 while a spell is charging; drives the orb and how far the hands close.
var charge: float = 0.0
## The spell currently held, so the orb is the colour of what is being charged.
var _colour := NEUTRAL_CHARGE
var _want_colour := NEUTRAL_CHARGE

var _release_left := 0.0
var _fire_left := 0.0
var _bob := 0.0
var _target := REST
var _current := REST
var _tilt := Vector3.ZERO
var _orb: ChargeOrb = null
var _model: Node3D = null

## Builds the viewmodel under `camera` and returns it (null when the asset is
## missing, so the game still runs -- see ModelLibrary's null-safe contract).
static func attach(camera: Camera3D) -> Viewmodel:
	if camera == null:
		return null
	var view := Viewmodel.new()
	view.name = "Viewmodel"
	camera.add_child(view)
	view.position = REST
	# No scaling and no grounding: the pose is authored in place and the node
	# above is what places it relative to the eye.
	var model := ModelLibrary.instantiate(ModelLibrary.VIEWMODEL_ARMS, 0.0, false)
	if model == null:
		return null
	view.add_child(model)
	view.add_to_group("viewmodel")
	view._model = model
	view._build_charge()
	return view

## Puts the charge in the gap between the palms.
##
## The orb is NOT part of the .glb: it is a ChargeOrb, the same object the holy
## bolt is built from, hung at ORB_AT inside the model. Modelling it separately
## would guarantee the two drifted apart, and it would put a light effect in a
## file whose job is to be a pair of hands.
func _build_charge() -> void:
	if _model == null:
		return
	_orb = ChargeOrb.build(ORB_RADIUS, true)
	_orb.name = "Charge"
	_model.add_child(_orb)
	_orb.position = ORB_AT
	_paint_charge()

## Where a projectile should start. The muzzle is nudged out of the glow along
## the orb's own facing, or the bolt spawns inside the light that is meant to
## be launching it.
func muzzle_position() -> Vector3:
	if _orb == null:
		return global_position
	return _orb.muzzle()

func _tint(mesh: MeshInstance3D, material: Material) -> void:
	if mesh != null:
		mesh.material_override = material

## Pushes the current charge colour into the orb. Reads `_colour` and never
## writes it: `_tick_colour` owns the easing, so there is exactly one place that
## decides what colour the orb is.
func _paint_charge() -> void:
	if _orb != null:
		_orb.set_colour(_colour)

## Switches the pose. Unknown names fall back to idle rather than freezing.
func set_state(next: String) -> void:
	state = next if next in [IDLE, RUN, CAST_HOLD, CAST_RELEASE] else IDLE

## Charge progress of the spell currently held, 0..1. Also grows the orb in the
## cupped palms, which is the only place the player can see the spell charging
## without looking away from the arena.
func set_charge(ratio: float) -> void:
	charge = clampf(ratio, 0.0, 1.0)

## Colour of the spell now held. The orb takes it, which turns a white ball into
## the one readout that answers "which of these nine am I charging?" without
## looking at the HUD. Called when a charge starts, not per frame.
func set_spell_colour(colour: Color) -> void:
	_want_colour = colour

## One-shot flourish when a spell actually leaves the hand.
func play_release() -> void:
	_release_left = RELEASE_TIME

## One-shot kick when a holy bolt leaves the flask.
func play_fire() -> void:
	_fire_left = FIRE_TIME

func _process(delta: float) -> void:
	_tick_bob(delta)
	_current = _current.lerp(_target, clampf(delta * 12.0, 0.0, 1.0))
	position = _current
	rotation = _tilt
	_apply_orb()
	_tick_charge_look(delta)

## Grows the orb with the charge and pulses it while a spell is held, so a long
## charge reads as building pressure rather than a static prop.
##
## The whole orb scales, glow included: it is one node, so the bloom grows with
## the rings instead of sliding off them at the top of the charge.
func _apply_orb() -> void:
	var grow := lerpf(ORB_MIN, ORB_MAX, charge)
	var pulse := 1.0
	if state == CAST_HOLD and charge > 0.0:
		pulse = 1.0 + sin(_bob * 1.7) * 0.06
	if _orb != null:
		_orb.scale = _orb.scale.normalized() * grow * pulse

## Drives the orb's spin and eases its colour towards the spell.
##
## A still orb is a prop. The spin is what says "this is filling up", and it is
## driven by the charge rather than run at a constant rate so that an idle palm
## is nearly quiet and a nearly-full one is visibly seeping.
func _tick_charge_look(delta: float) -> void:
	if _orb != null:
		_orb.spin = lerpf(SPIN_IDLE, SPIN_CHARGED, charge)
	_tick_colour(delta)

## Eases the orb towards the spell's colour.
##
## Writing the TARGET back as the current colour -- which is the obvious way to
## do this -- jumps most of the way on the first frame and then has nothing left
## to ease from, so the sweep never happens and every colour change reads as a
## snap.
func _tick_colour(delta: float) -> void:
	if _want_colour == _colour:
		return
	_colour = _colour.lerp(_want_colour, clampf(delta / COLOUR_SWITCH, 0.0, 1.0))
	# A lerp closes the gap geometrically, so the last sliver of colour crawls
	# for the better part of a second. A difference under one 8-bit step is
	# invisible, so take it and stop.
	var gap := maxf(absf(_colour.r - _want_colour.r),
		maxf(absf(_colour.g - _want_colour.g), absf(_colour.b - _want_colour.b)))
	if gap < 0.004:
		_colour = _want_colour
	_paint_charge()

func _tick_bob(delta: float) -> void:
	if _release_left > 0.0:
		_release_left = maxf(0.0, _release_left - delta)
	if _fire_left > 0.0:
		_fire_left = maxf(0.0, _fire_left - delta)

	var target := REST
	match state:
		RUN:
			_bob += delta * 9.5
			target += Vector3(sin(_bob) * 0.016, absf(cos(_bob)) * -0.020, 0.0)
			_tilt = Vector3(cos(_bob) * 0.03, sin(_bob) * 0.02, 0.0)
		CAST_HOLD:
			# Palms close on the charge and rise, with a fine tremble that gets
			# stronger the closer the spell is to full.
			_bob += delta * lerpf(14.0, 30.0, charge)
			var pull := CHARGE_REACH * (0.35 + 0.65 * charge)
			target += pull
			var shake := 0.002 + 0.004 * charge
			target += Vector3(sin(_bob) * shake, sin(_bob * 1.7) * shake, 0.0)
			_tilt = Vector3(-0.05 - 0.05 * charge, sin(_bob * 0.7) * 0.01, 0.0)
		CAST_RELEASE:
			_tilt = Vector3(-0.09, 0.0, 0.0)
		_:
			# Tired office clerk: a slow breath, hands drifting back down from a
			# cast over about a second.
			_bob += delta * 1.6
			target += Vector3(0.0, sin(_bob) * 0.007, 0.0)
			_tilt = Vector3.ZERO
	# Both one-shots ease out quadratically so nothing stops hard.
	if _release_left > 0.0:
		var k := _release_left / RELEASE_TIME
		target += RELEASE_REACH * k * k
	if _fire_left > 0.0:
		var f := _fire_left / FIRE_TIME
		target += FIRE_REACH * f * f
	_target = target
