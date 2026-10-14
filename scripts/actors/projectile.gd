class_name Projectile
## A travelling bolt (3D / first-person port).  The player's holy bolt hunts
## demons; a demon's hex bolt hunts the player.  Hits are resolved by distance
## so no physics layer wiring is required.
##
## The bolt IS the charge orb, at flight size: same lit core, same cage of rings,
## same glow, so a shot reads as leaving the thing that was being gathered in the
## caster's palms. What it adds is a streak behind it -- a tapered cone of light
## that fades along its length, which is the difference between a moving dot and
## something travelling.
extends Area3D

const HIT_RADIUS := 0.9
## Radius of the glowing core. Matches the palm orb's proportions, not its size:
## at 0.11 the lit ball is the same 0.22 m across as the sphere the bolt used to
## be, so this is a rebuild of what was there rather than a change of scale.
const CORE_RADIUS := 0.11
## How fast the rings turn, relative to the orb's calm idle.
const SPIN := 7.0

var velocity := Vector3.ZERO
var damage := 10.0
var from_enemy := false
## Extra enemies this bolt can pass through before it dies (level-up card).
var pierce := 0

var _life := 0.0
var _orb: ChargeOrb = null
var _trail: MeshInstance3D = null
var _trail_mat: StandardMaterial3D = null
var _spawn_origin := Vector3.ZERO

## Configures the bolt.  Call before adding it to the tree; the spawn origin is
## stored here and applied in _ready(), once the node is actually inside the
## scene tree (setting global_position on a detached Node3D is an error).
func setup(origin: Vector3, dir: Vector3, speed: float, dmg: float, enemy_shot: bool) -> void:
	_spawn_origin = origin
	velocity = dir.normalized() * speed
	damage = dmg
	from_enemy = enemy_shot

func _ready() -> void:
	global_position = _spawn_origin
	_orb = ChargeOrb.build(CORE_RADIUS, false)
	_orb.spin = SPIN
	add_child(_orb)
	# The streak: wide at the back, pointed at the head, fading to nothing.
	# A box of solid colour reads as a plank travelling through the room.
	_trail_mat = StandardMaterial3D.new()
	_trail_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_trail_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_trail_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_trail_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_trail_mat.albedo_texture = TextureLibrary.surface("glow")
	# The glow ramp fades at both its left and right ends, because on a wall that
	# is what stops the strip having a hard edge. Around a cylinder those same
	# two ends wrap onto each other and the streak goes dark down one side, so
	# only the flat middle of the ramp is sampled: v (along the streak) keeps its
	# fade, u contributes nothing.
	_trail_mat.uv1_scale = Vector3(0.5, 1.0, 1.0)
	_trail_mat.uv1_offset = Vector3(0.25, 0.0, 0.0)
	# A cylinder is built along +Y; the bolt's own +Z is the direction of travel,
	# so the streak is turned a quarter and then simply pushed back along it.
	# Leaving it upright instead hangs a 1.5 m pole off the side of every bolt.
	var cone := CylinderMesh.new()
	cone.top_radius = CORE_RADIUS * 0.15
	cone.bottom_radius = CORE_RADIUS * 0.9
	cone.height = TRAIL_LENGTH
	cone.radial_segments = 10
	cone.rings = 1
	_trail = MeshInstance3D.new()
	_trail.name = "Streak"
	_trail.mesh = cone
	_trail.material_override = _trail_mat
	_trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_trail.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	add_child(_trail)
	_apply_colour()
	_face_travel()

## Length of the streak, in metres. Long enough to read the shot's line over a
## few metres of floor, short enough not to lie about where the bolt is.
const TRAIL_LENGTH := 1.6

## Tints the bolt gold for the player and violet for a demon; re-used when an
## enemy bolt is reflected back on its sender (GDD spell 9).
func _apply_colour() -> void:
	if _orb == null:
		return
	var c := ENEMY_COLOUR if from_enemy else PLAYER_COLOUR
	_orb.set_colour(c)
	if _trail_mat != null:
		_trail_mat.albedo_color = Color(c.r * TRAIL_GAIN, c.g * TRAIL_GAIN,
			c.b * TRAIL_GAIN, 1.0)

const ENEMY_COLOUR := Color("#a03cff")
const PLAYER_COLOUR := Color("#ffe9a8")
const TRAIL_GAIN := 0.40

## Points the node's +Z along the flight direction.
##
## `look_at()` aims a node's **-Z** at its target, so aiming it one step BEHIND
## is what puts +Z down the barrel -- and +Z is the axis ChargeOrb's rings are
## built around, so they end up circling the way the bolt is going. Getting this
## backwards is not subtle: the streak is parented to the bolt, so it hangs off
## whichever end points the wrong way, and a bolt fired away from the camera
## shows its trail as nothing at all.
func _face_travel() -> void:
	if velocity.length_squared() <= 0.0001:
		return
	var dir := velocity.normalized()
	var up := Vector3.UP
	if absf(dir.dot(up)) > 0.99:
		up = Vector3.RIGHT
	look_at(global_position - dir, up)

func _physics_process(delta: float) -> void:
	var previous := global_position
	global_position += velocity * delta
	_life += delta
	_orient_trail()
	if _life >= GameConfig.PROJECTILE_LIFETIME:
		queue_free()
		return
	# Bolts are stopped by level geometry (walls/pillars, layer 5 = value 16).
	# Without this, ranged demons shot the player straight through cover.
	if _blocked_by_wall(previous):
		EffectUtil.sound(get_tree(), &"bolt_impact", global_position)
		queue_free()
		return
	_check_hits()

## True when the segment travelled this frame crosses level geometry.
func _blocked_by_wall(from: Vector3) -> bool:
	var world := get_world_3d()
	if world == null:
		return false
	var params := PhysicsRayQueryParameters3D.create(from, global_position, 16)
	params.exclude = [get_rid()]
	return not world.direct_space_state.intersect_ray(params).is_empty()

## Pulls the streak back along the bolt. It is a child, so this is just the
## offset behind the head -- the direction comes from the bolt's own transform,
## which `_face_travel` points along the velocity.
func _orient_trail() -> void:
	if _trail == null:
		return
	_trail.position = Vector3(0.0, 0.0, -TRAIL_LENGTH * 0.5)

func _check_hits() -> void:
	if from_enemy:
		for p in get_tree().get_nodes_in_group("player"):
			if not (p is Node3D):
				continue
			# Aimed at the torso: enemy bolts also fly near eye height, while the
			# player's node origin sits at the feet.
			var centre: Vector3 = p.global_position + Vector3.UP * 0.9
			if p.has_method("hurt_center"):
				centre = p.call("hurt_center")
			if centre.distance_to(global_position) <= HIT_RADIUS:
				if _try_reflect(p):
					return
				if p.has_method("take_damage"):
					p.call("take_damage", damage, global_position)
				EffectUtil.sound(get_tree(), &"bolt_impact", global_position)
				queue_free()
				return
	else:
		for e in EffectUtil.enemies(get_tree()):
			if not (e is Node3D):
				continue
			# Aimed at the body centre, not the feet: bolts travel at eye height.
			var centre: Vector3 = e.global_position + Vector3.UP * 0.8
			if e.has_method("hurt_center"):
				centre = e.call("hurt_center")
			if centre.distance_to(global_position) <= HIT_RADIUS:
				EffectUtil.damage(e, damage, global_position)
				EffectUtil.hitmarker(get_tree())
				EffectUtil.sound(get_tree(), &"bolt_impact", global_position)
				# Piercing: pass through and keep flying until charges run out.
				if pierce > 0:
					pierce -= 1
					global_position += velocity.normalized() * (HIT_RADIUS + 0.15)
					return
				queue_free()
				return

## Mirror of the Soul (GDD spell 9): if the caster has the dome up, the demon
## bolt is turned back on its sender rather than hurting the player. Returns
## true when the bolt was reflected (the caller must not free it).
func _try_reflect(p: Node) -> bool:
	if not p.has_method("is_shielded") or not p.call("is_shielded"):
		return false
	from_enemy = false
	velocity = -velocity
	# Step the bolt clear of the hit radius so it does not re-trigger next frame.
	global_position += velocity.normalized() * (HIT_RADIUS + 0.1)
	_life = 0.0
	_apply_colour()
	_face_travel()
	EffectUtil.sound(get_tree(), &"bolt_reflect", global_position)
	return true
