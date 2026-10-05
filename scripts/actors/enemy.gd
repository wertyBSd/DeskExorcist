class_name Enemy
## A demon (3D / first-person port).  It chases the player and deals contact
## damage on a cooldown.  Two archetypes from the GDD: the tanky WATER_COOLER
## and the fragile PAPERWORK_PHANTOM.  Spells damage it through take_damage().
extends CharacterBody3D

enum Kind { WATER_COOLER, PAPERWORK_PHANTOM }

signal died(enemy: Enemy)

const WATER_COOLER_HEALTH := 90.0
const PHANTOM_HEALTH := 26.0
const WATER_COOLER_XP := 3.0
const PHANTOM_XP := 1.0
const CONTACT_DAMAGE := 8.0
const KNOCKBACK_DECAY := 7.0
const GRAVITY := 24.0

var kind: Kind = Kind.PAPERWORK_PHANTOM
var health := PHANTOM_HEALTH
var max_health := PHANTOM_HEALTH
var speed := GameConfig.ENEMY_CHASE_SPEED
var damage := CONTACT_DAMAGE
var xp_value := PHANTOM_XP

var _slow_ratio := 0.0
var _slow_time := 0.0
var _knockback := Vector3.ZERO
var _attack_timer := 0.0
var _player: Node3D = null
var _placeholder: MeshInstance3D = null
var _model: Node3D = null

func _ready() -> void:
	add_to_group("enemies")
	_build_mesh()
	_apply_kind()

## Sets the demon archetype; safe to call before or after _ready().
func configure(k: Kind) -> void:
	kind = k
	if is_inside_tree():
		_apply_kind()

func _apply_kind() -> void:
	if kind == Kind.WATER_COOLER:
		max_health = WATER_COOLER_HEALTH
		xp_value = WATER_COOLER_XP
		damage = CONTACT_DAMAGE * 1.5
	else:
		max_health = PHANTOM_HEALTH
		xp_value = PHANTOM_XP
		damage = CONTACT_DAMAGE
	health = max_health
	_refresh_model()

## Swaps in the Blender-authored .glb for this archetype (BlenderInstruction.MD
## lot 2 and 3).  Falls back to the code-built placeholder box when the asset
## pipeline has not been run, so headless tests never depend on the .glb files.
func _refresh_model() -> void:
	if _model != null and is_instance_valid(_model):
		_model.queue_free()
		_model = null
	if _placeholder != null and is_instance_valid(_placeholder):
		_placeholder.visible = false
	var path := ModelLibrary.WATER_COOLER if kind == Kind.WATER_COOLER else ModelLibrary.PAPERWORK_PHANTOM
	var height := 1.4 if kind == Kind.WATER_COOLER else 0.7
	_model = ModelLibrary.attach(self, path, height)

func _build_mesh() -> void:
	_placeholder = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.7, 1.4, 0.7)
	_placeholder.mesh = box
	_placeholder.position = Vector3(0.0, 0.7, 0.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("#4c5163") if kind == Kind.WATER_COOLER else Color("#a03cff")
	mat.emission_enabled = true
	mat.emission = mat.albedo_color
	mat.emission_energy_multiplier = 0.4
	_placeholder.material_override = mat
	add_child(_placeholder)

func _physics_process(delta: float) -> void:
	_tick_effects(delta)
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0.0
	_chase(delta)
	velocity += _knockback
	_knockback = _knockback.move_toward(Vector3.ZERO, KNOCKBACK_DECAY * delta)
	move_and_slide()

func _chase(delta: float) -> void:
	_acquire_player()
	if _player == null:
		velocity.x = 0.0
		velocity.z = 0.0
		return
	var to := _player.global_position - global_position
	to.y = 0.0
	var dist := to.length()
	var spd := speed * (1.0 - _slow_ratio)
	if dist > 0.001:
		var dir := to / dist
		velocity.x = dir.x * spd
		velocity.z = dir.z * spd
		if dist <= GameConfig.ENEMY_ATTACK_RANGE:
			_attack(delta)
	else:
		velocity.x = 0.0
		velocity.z = 0.0

func _acquire_player() -> void:
	if _player != null and is_instance_valid(_player):
		return
	var list := get_tree().get_nodes_in_group("player")
	_player = list[0] if not list.is_empty() else null

func _attack(delta: float) -> void:
	_attack_timer -= delta
	if _attack_timer > 0.0:
		return
	_attack_timer = GameConfig.ENEMY_ATTACK_COOLDOWN
	if _player != null and _player.has_method("take_damage"):
		_player.call("take_damage", damage, global_position)

func _tick_effects(delta: float) -> void:
	if _slow_time > 0.0:
		_slow_time = maxf(0.0, _slow_time - delta)
		if _slow_time == 0.0:
			_slow_ratio = 0.0

# --- Damage API used by effects and the auto weapon --------------------------

func take_damage(amount: float, _source: Vector3 = Vector3.INF) -> void:
	health -= amount
	if health <= 0.0:
		_die()

func apply_knockback(from: Vector3, force: float) -> void:
	var dir := global_position - from
	dir.y = 0.0
	if dir.length() > 0.001:
		_knockback = dir.normalized() * force

func apply_slow(ratio: float, duration: float) -> void:
	_slow_ratio = maxf(_slow_ratio, ratio)
	_slow_time = maxf(_slow_time, duration)

func _die() -> void:
	died.emit(self)
	_spawn_soul()
	queue_free()

func _spawn_soul() -> void:
	var host := get_tree().current_scene
	if host == null:
		return
	var orb := SoulOrb.new()
	orb.setup(xp_value)
	host.add_child(orb)
	orb.global_position = global_position
