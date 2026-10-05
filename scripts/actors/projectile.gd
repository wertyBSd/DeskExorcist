class_name Projectile
## A travelling bolt (3D / first-person port).  The player's holy bolt hunts
## demons; a demon's hex bolt hunts the player.  Hits are resolved by distance
## so no physics layer wiring is required.
extends Area3D

const HIT_RADIUS := 0.7

var velocity := Vector3.ZERO
var damage := 10.0
var from_enemy := false

var _life := 0.0
var _mesh: MeshInstance3D = null
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
	_mesh = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.12
	sphere.height = 0.24
	_mesh.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("#a03cff") if from_enemy else Color("#ffe9a8")
	mat.emission_enabled = true
	mat.emission = mat.albedo_color
	mat.emission_energy_multiplier = 2.0
	_mesh.material_override = mat
	add_child(_mesh)

func _physics_process(delta: float) -> void:
	global_position += velocity * delta
	_life += delta
	if _life >= GameConfig.PROJECTILE_LIFETIME:
		queue_free()
		return
	_check_hits()

func _check_hits() -> void:
	if from_enemy:
		for p in get_tree().get_nodes_in_group("player"):
			if p is Node3D and (p as Node3D).global_position.distance_to(global_position) <= HIT_RADIUS:
				if p.has_method("take_damage"):
					p.call("take_damage", damage, global_position)
				queue_free()
				return
	else:
		for e in EffectUtil.enemies(get_tree()):
			if e is Node3D and (e as Node3D).global_position.distance_to(global_position) <= HIT_RADIUS:
				EffectUtil.damage(e, damage, global_position)
				queue_free()
				return
