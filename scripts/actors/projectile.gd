class_name Projectile
## A travelling bolt (3D / first-person port).  The player's holy bolt hunts
## demons; a demon's hex bolt hunts the player.  Hits are resolved by distance
## so no physics layer wiring is required.
extends Area3D

const HIT_RADIUS := 0.9

var velocity := Vector3.ZERO
var damage := 10.0
var from_enemy := false
## Extra enemies this bolt can pass through before it dies (level-up card).
var pierce := 0

var _life := 0.0
var _mesh: MeshInstance3D = null
var _mat: StandardMaterial3D = null
var _spawn_origin := Vector3.ZERO
## A short stretched trail so fast bolts read clearly and their source is obvious.
var _trail: MeshInstance3D = null

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
	_mesh = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.12
	sphere.height = 0.24
	_mesh.mesh = sphere
	_mat = StandardMaterial3D.new()
	_mat.emission_enabled = true
	_mat.emission_energy_multiplier = 2.0
	_apply_colour()
	_mesh.material_override = _mat
	add_child(_mesh)
	# Stretched trail oriented along the velocity.
	_trail = MeshInstance3D.new()
	var trail_mesh := BoxMesh.new()
	trail_mesh.size = Vector3(0.08, 0.08, 1.6)
	_trail.mesh = trail_mesh
	_trail.material_override = _mat
	add_child(_trail)

## Tints the bolt gold for the player and violet for a demon; re-used when an
## enemy bolt is reflected back on its sender (GDD spell 9).
func _apply_colour() -> void:
	if _mat == null:
		return
	var c := Color("#a03cff") if from_enemy else Color("#ffe9a8")
	_mat.albedo_color = c
	_mat.emission = c

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

## Points the trail behind the bolt along its direction of travel.
func _orient_trail() -> void:
	if _trail == null or velocity.length_squared() <= 0.0001:
		return
	var dir := velocity.normalized()
	var up := Vector3.UP
	if absf(dir.dot(up)) > 0.99:
		up = Vector3.RIGHT
	_trail.look_at(global_position - dir, up)
	_trail.position = -dir * 0.8

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
	EffectUtil.sound(get_tree(), &"bolt_reflect", global_position)
	return true
