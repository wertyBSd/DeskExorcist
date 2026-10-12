class_name Boss
## The final boss of the run (GDD Level Design: the Executive Deck's conference
## hall).  A single large demon that appears for the last minute of the run and
## uses a small move set that escalates through three phases as it takes damage:
##   Phase 1 (>66% HP): contact bites + slow hex volleys.
##   Phase 2 (33-66%):  adds a ground slam AoE and summons minions.
##   Phase 3 (<33%):    faster, shorter cooldowns, wider volleys.
## It joins the "enemies" group so every spell and the auto weapon damage it, and
## exposes health_changed()/is_boss() so the HUD can show a boss health bar.

extends CharacterBody3D

signal died(boss: Boss)
signal health_changed(value: float, max_value: float)

const GRAVITY := 24.0
const PREFERRED_RANGE := 6.0    ## backs off if the caster is closer than this

var health := GameConfig.BOSS_HEALTH
var max_health := GameConfig.BOSS_HEALTH
var damage := GameConfig.BOSS_CONTACT_DAMAGE
var xp_value := GameConfig.BOSS_XP

var _player: Node3D = null
var _placeholder: MeshInstance3D = null
var _model: Node3D = null
var _knockback := Vector3.ZERO
var _attack_timer := 0.0
var _slam_timer := 0.0
var _volley_timer := 0.0
var _summon_timer := 0.0
var _phase := 1

func _ready() -> void:
	add_to_group("enemies")
	add_to_group("boss")
	collision_layer = 2
	collision_mask = 18
	_build_collision()
	_build_mesh()
	_refresh_model()
	max_health *= GameConfig.enemy_hp_mult()
	health = max_health
	damage *= GameConfig.enemy_damage_mult()
	health_changed.emit(health, max_health)

func _build_collision() -> void:
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.9
	capsule.height = 3.0
	shape.shape = capsule
	shape.position = Vector3(0.0, 1.5, 0.0)
	add_child(shape)

func _build_mesh() -> void:
	_placeholder = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.6, 3.0, 1.6)
	_placeholder.mesh = box
	_placeholder.position = Vector3(0.0, 1.5, 0.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("#7a1030")
	mat.emission_enabled = true
	mat.emission = Color("#c2364a")
	mat.emission_energy_multiplier = 0.5
	_placeholder.material_override = mat
	add_child(_placeholder)

## Reuses the water-cooler silhouette scaled up until a dedicated boss .glb exists.
func _refresh_model() -> void:
	_model = ModelLibrary.attach(self, ModelLibrary.WATER_COOLER, 3.0)
	if _model != null and _placeholder != null:
		_placeholder.visible = false

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0.0
	_chase(delta)
	velocity += _knockback
	_knockback = _knockback.move_toward(Vector3.ZERO, 6.0 * delta)
	move_and_slide()
	_run_attacks(delta)

func _boss_speed() -> float:
	return GameConfig.BOSS_SPEED * (1.0 + 0.15 * float(_phase - 1))

func _chase(delta: float) -> void:
	_acquire_player()
	if _player == null:
		velocity.x = 0.0
		velocity.z = 0.0
		return
	var to := _player.global_position - global_position
	to.y = 0.0
	var dist := to.length()
	if dist <= 0.001:
		return
	var dir := to / dist
	var spd := _boss_speed()
	# Close in, but keep some spacing so it does not simply body-block the caster.
	if dist > PREFERRED_RANGE:
		velocity.x = dir.x * spd
		velocity.z = dir.z * spd
	else:
		velocity.x = dir.x * spd * 0.15
		velocity.z = dir.z * spd * 0.15
	if dist <= GameConfig.ENEMY_ATTACK_RANGE + 0.4 and _can_reach_player():
		_bite(delta)

func _run_attacks(delta: float) -> void:
	if _player == null:
		return
	# Volley is available from the start; slam + summon from phase 2.
	_volley_timer -= delta
	if _volley_timer <= 0.0:
		_volley_timer = _scaled(GameConfig.BOSS_VOLLEY_INTERVAL)
		_volley()
	if _phase >= 2:
		_slam_timer -= delta
		if _slam_timer <= 0.0:
			_slam_timer = _scaled(GameConfig.BOSS_SLAM_INTERVAL)
			_slam()
		_summon_timer -= delta
		if _summon_timer <= 0.0:
			_summon_timer = _scaled(GameConfig.BOSS_SUMMON_INTERVAL)
			_summon()

## Later phases act more often.
func _scaled(base: float) -> float:
	return base * (1.0 - 0.18 * float(_phase - 1))

func _bite(delta: float) -> void:
	_attack_timer -= delta
	if _attack_timer > 0.0:
		return
	_attack_timer = GameConfig.ENEMY_ATTACK_COOLDOWN
	_hit_player(damage)

## Close-range ground slam: heavy damage to the caster if they stay close.
func _slam() -> void:
	var host := get_tree().current_scene
	var origin := global_position + Vector3.UP * 0.1
	EffectUtil.sound(get_tree(), &"bolt_impact", origin)
	EffectUtil.spawn_debris(get_tree(), origin + Vector3.UP * 0.3, 8, Color("#c2364a"), 4.0)
	if _player != null:
		var d := _player.global_position.distance_to(origin)
		if d <= GameConfig.BOSS_SLAM_RADIUS and _can_reach_player():
			_hit_player(GameConfig.BOSS_SLAM_DAMAGE)

## Fans several hex bolts toward the caster (three, or five in the final phase).
func _volley() -> void:
	var host := get_tree().current_scene
	if host == null or _player == null:
		return
	var count := 3 if _phase < 3 else 5
	var origin := global_position + Vector3.UP * 1.5
	var base_dir := (_player.global_position + Vector3.UP * 0.9 - origin).normalized()
	EffectUtil.sound(get_tree(), &"bolt_fire", origin)
	for i in count:
		var t := 0.0 if count <= 1 else (float(i) / float(count - 1) - 0.5)
		var dir := base_dir.rotated(Vector3.UP, t * 0.6)
		var bolt := Projectile.new()
		bolt.setup(origin, dir, GameConfig.PROJECTILE_SPEED * 0.55, GameConfig.BOSS_SLAM_DAMAGE * 0.4, true)
		host.add_child(bolt)

## Spawns a couple of lesser demons to pressure the caster.
func _summon() -> void:
	var host := get_tree().current_scene
	if host == null:
		return
	for i in 2:
		var minion := Enemy.new()
		minion.configure(Enemy.Kind.PAPERWORK_PHANTOM)
		host.add_child(minion)
		var a := randf_range(0.0, TAU)
		minion.global_position = global_position + Vector3(cos(a), 0.2, sin(a)) * 3.0

func _hit_player(amount: float) -> void:
	if _player != null and _player.has_method("take_damage"):
		_player.call("take_damage", amount, global_position)

func _acquire_player() -> void:
	if _player != null and is_instance_valid(_player):
		return
	var list := get_tree().get_nodes_in_group("player")
	_player = list[0] if not list.is_empty() else null

func _can_reach_player() -> bool:
	if _player == null:
		return false
	if absf(_player.global_position.y - global_position.y) > 2.5:
		return false
	var world := get_world_3d()
	if world == null:
		return true
	var from := global_position + Vector3.UP * 1.0
	var to := _player.global_position + Vector3.UP * 0.9
	var params := PhysicsRayQueryParameters3D.create(from, to, 16)
	params.exclude = [get_rid()]
	return world.direct_space_state.intersect_ray(params).is_empty()

# --- Damage API (spells/auto weapon sweep the "enemies" group) ---------------

func take_damage(amount: float, _source: Vector3 = Vector3.INF) -> void:
	health -= amount
	health_changed.emit(maxf(0.0, health), max_health)
	_update_phase()
	if health <= 0.0:
		_die()

func _update_phase() -> void:
	var ratio := health / max_health
	var next := 1
	if ratio <= 0.33:
		next = 3
	elif ratio <= 0.66:
		next = 2
	if next != _phase:
		_phase = next

func hurt_center() -> Vector3:
	return global_position + Vector3.UP * 1.5

func is_boss() -> bool:
	return true

func apply_knockback(_from: Vector3, _force: float) -> void:
	# The boss shrugs off knockback; it is meant to be a wall you circle.
	pass

func apply_slow(ratio: float, duration: float) -> void:
	# Only lightly slowed, so control spells stay useful but not trivialising.
	velocity *= (1.0 - clampf(ratio, 0.0, 0.5))

func _die() -> void:
	died.emit(self)
	EffectUtil.spawn_debris(get_tree(), global_position + Vector3.UP * 1.5, 24, Color("#c2364a"), 6.0)
	for i in 6:
		var orb := SoulOrb.new()
		orb.setup(xp_value / 6.0)
		var host := get_tree().current_scene
		if host == null:
			break
		host.add_child(orb)
		var a := randf_range(0.0, TAU)
		orb.global_position = global_position + Vector3(cos(a), 0.5, sin(a)) * randf_range(0.5, 2.0)
	queue_free()
