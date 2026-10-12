class_name Enemy
## A demon (3D / first-person port).  It chases the player and deals contact
## damage on a cooldown.  Two archetypes from the GDD: the tanky WATER_COOLER
## and the fragile PAPERWORK_PHANTOM.  Spells damage it through take_damage().
extends CharacterBody3D

enum Kind { WATER_COOLER, PAPERWORK_PHANTOM, EMAIL_WRAITH, WIRE_RUNNER, FILING_CABINET_TANK, PAPER_BOMBER }

signal died(enemy: Enemy)

const WATER_COOLER_HEALTH := 90.0
const PHANTOM_HEALTH := 26.0
const WRAITH_HEALTH := 40.0
const WATER_COOLER_XP := 3.0
const PHANTOM_XP := 1.0
const WRAITH_XP := 2.0
const CONTACT_DAMAGE := 8.0
## Ranged archetype: fires a hex bolt from range and keeps its distance.
const WRAITH_DAMAGE := 7.0
const WRAITH_PREFERRED_RANGE := 9.0   ## it backs off when closer than this
const WRAITH_FIRE_RANGE := 16.0       ## stops and shoots inside this
const KNOCKBACK_DECAY := 7.0
const GRAVITY := 24.0
## New archetypes (E1): WIRE_RUNNER — хрупкий, но очень быстрый; 
## FILING_CABINET_TANK — медленный и очень живучий, бьёт тяжело;
## PAPER_BOMBER — взрывается рядом с кастером, нанося урон по площади.
const RUNNER_HEALTH := 22.0
const RUNNER_XP := 2.0
const RUNNER_SPEED := 5.5
const RUNNER_DAMAGE := 6.0
const TANK1_HEALTH := 170.0
const TANK1_XP := 6.0
const TANK1_SPEED := 1.6
const TANK1_DAMAGE := 18.0
const BOMBER_HEALTH := 20.0
const BOMBER_XP := 4.0
const BOMBER_SPEED := 3.2
const BOMBER_DAMAGE := 16.0
const BOMBER_FUSE := 1.4
const BOMBER_RADIUS := 4.0
## A melee demon may only bite the caster when their bodies are this close in
## height (metres). Without it, a demon on the floor under a balcony would bite
## a caster standing on top of it -- "invisible" damage through the deck.
const REACH_HEIGHT := 1.3

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
var _fire_timer := 0.0
var _player: Node3D = null
var _placeholder: MeshInstance3D = null
var _model: Node3D = null
## Floating HP bar (E8): billboard sprite shown when the demon is damaged.
var _hp_bar: Sprite3D = null
var _hp_texture: ImageTexture = null
var _level: Node = null
## Unstuck aid: when the demon intends to move but makes no progress (pinned
## on a column edge or concave corner), it sidesteps for a short while instead
## of pushing straight into the wall forever.
var _sidestep_time := 0.0
var _sidestep_sign := 1.0
var _progress_timer := 0.0
var _progress_position := Vector3.ZERO

func _ready() -> void:
	add_to_group("enemies")
	_build_hp_bar()
	_configure_physics()
	_build_collision()
	_build_mesh()
	_apply_kind()

func _build_hp_bar() -> void:
	_hp_bar = Sprite3D.new()
	_hp_bar.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_hp_bar.no_depth_test = true
	_hp_bar.pixel_size = 0.005
	_hp_bar.position = Vector3(0.0, 1.6, 0.0)
	_hp_bar.visible = false
	var img := Image.create(32, 4, false, Image.FORMAT_RGBA8)
	_hp_texture = ImageTexture.create_from_image(img)
	_hp_bar.texture = _hp_texture
	add_child(_hp_bar)
	_update_hp_bar()

func _update_hp_bar() -> void:
	if _hp_bar == null or _hp_texture == null:
		return
	var ratio := clampf(health / max_health, 0.0, 1.0)
	var img := Image.create(32, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0.6))
	for x in 32:
		for y in 4:
			if x < int(32.0 * ratio):
				img.set_pixel(x, y, Color(0.9, 0.2, 0.2, 1.0))
	_hp_texture = ImageTexture.create_from_image(img)
	_hp_bar.texture = _hp_texture
	_hp_bar.visible = ratio < 1.0

func _configure_physics() -> void:
	collision_layer = 2    # "enemy"
	collision_mask = 18    # walls (16) + enemy (2), as declared in enemy.tscn

## Builds the capsule that enemy.tscn declares. Without it move_and_slide() has
## no floor contact and the demon drops out of the world. Matches the scene
## (capsule r=0.4 h=1.6, centred at 0.8).
func _build_collision() -> void:
	for c in get_children():
		if c is CollisionShape3D:
			return
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.6
	shape.shape = capsule
	shape.position = Vector3(0.0, 0.8, 0.0)
	add_child(shape)

## Sets the demon archetype; safe to call before or after _ready().
func configure(k: Kind) -> void:
	kind = k
	if is_inside_tree():
		_apply_kind()

func _apply_kind() -> void:
	match kind:
		Kind.WATER_COOLER:
			max_health = WATER_COOLER_HEALTH
			xp_value = WATER_COOLER_XP
			damage = CONTACT_DAMAGE * 1.5
		Kind.EMAIL_WRAITH:
			max_health = WRAITH_HEALTH
			xp_value = WRAITH_XP
			damage = CONTACT_DAMAGE
			speed = GameConfig.ENEMY_CHASE_SPEED
		Kind.WIRE_RUNNER:
			max_health = RUNNER_HEALTH
			xp_value = RUNNER_XP
			damage = RUNNER_DAMAGE
			speed = RUNNER_SPEED
		Kind.FILING_CABINET_TANK:
			max_health = TANK1_HEALTH
			xp_value = TANK1_XP
			damage = TANK1_DAMAGE
			speed = TANK1_SPEED
		Kind.PAPER_BOMBER:
			max_health = BOMBER_HEALTH
			xp_value = BOMBER_XP
			damage = BOMBER_DAMAGE
			speed = BOMBER_SPEED
		_:
			max_health = PHANTOM_HEALTH
			xp_value = PHANTOM_XP
			damage = CONTACT_DAMAGE
			speed = GameConfig.ENEMY_CHASE_SPEED
	# NG+ loop: every victory permanently scales enemy pressure.
	max_health *= GameConfig.enemy_hp_mult()
	damage *= GameConfig.enemy_damage_mult()
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
	# Every archetype gets its own export so the six silhouettes are told apart at
	# a glance (BlenderInstruction.MD lots 2-3, ASSETS_MODELS.md #2). Missing
	# exports fall back to the phantom silhouette rather than leaving a hole.
	var path := ModelLibrary.PAPERWORK_PHANTOM
	var height := 0.7
	match kind:
		Kind.WATER_COOLER:
			path = ModelLibrary.WATER_COOLER
			height = 1.4
		Kind.EMAIL_WRAITH:
			path = ModelLibrary.EMAIL_WRAITH
			height = 1.1
		Kind.WIRE_RUNNER:
			path = ModelLibrary.WIRE_RUNNER
			height = 1.3
		Kind.FILING_CABINET_TANK:
			path = ModelLibrary.FILING_CABINET_TANK
			height = 1.7
		Kind.PAPER_BOMBER:
			path = ModelLibrary.PAPER_BOMBER
			height = 1.2
	if not ModelLibrary.has_model(path):
		path = ModelLibrary.PAPERWORK_PHANTOM
		height = 0.7
	_model = ModelLibrary.attach(self, path, height)

func _build_mesh() -> void:
	_placeholder = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.7, 1.4, 0.7)
	_placeholder.mesh = box
	_placeholder.position = Vector3(0.0, 0.7, 0.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = _placeholder_colour()
	mat.emission_enabled = true
	mat.emission = mat.albedo_color
	mat.emission_energy_multiplier = 0.4
	_placeholder.material_override = mat
	add_child(_placeholder)

## Colour of the code-built placeholder box when no .glb is available.
func _placeholder_colour() -> Color:
	match kind:
		Kind.WATER_COOLER:
			return Color("#4c5163")
		Kind.EMAIL_WRAITH:
			return Color("#2f7dff")
		Kind.WIRE_RUNNER:
			return Color("#ff5733")
		Kind.FILING_CABINET_TANK:
			return Color("#7a4a2b")
		Kind.PAPER_BOMBER:
			return Color("#ffd166")
		_:
			return Color("#a03cff")

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
	_tick_unstuck(delta)

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
	if dist <= 0.001:
		velocity.x = 0.0
		velocity.z = 0.0
		return
	var dir := _steer(to, dist)
	if kind == Kind.EMAIL_WRAITH:
		_chase_ranged(delta, dir, dist, spd)
		return
	if kind == Kind.PAPER_BOMBER and dist <= BOMBER_FUSE:
		_explode()
		return
	velocity.x = dir.x * spd
	velocity.z = dir.z * spd
	# Melee only lands within reach *and* line of sight: a demon directly under
	# or above the caster must not bite through a floor/deck.
	if dist <= GameConfig.ENEMY_ATTACK_RANGE and _can_reach_player():
		_attack(delta)

## Direction to move so the demon reaches the caster without pinning itself on a
## wall or pillar. Uses a direct line when it is clear, otherwise asks the level
## for the next waypoint of a grid path (ROADMAP Stage C: demon navigation).
func _steer(to: Vector3, dist: float) -> Vector3:
	var direct := to / dist
	var here := global_position + Vector3.UP * 0.8
	var target := _player.global_position + Vector3.UP * 0.8
	var space := get_world_3d().direct_space_state if get_world_3d() != null else null
	if space == null:
		return direct
	var params := PhysicsRayQueryParameters3D.create(here, target, 16)
	params.exclude = [get_rid()]
	if space.intersect_ray(params).is_empty():
		if _sidestep_time > 0.0:
			return direct.rotated(Vector3.UP, _sidestep_sign * PI * 0.5)
		return direct
	_acquire_level()
	if _level == null or not _level.has_method("next_path_point"):
		return direct
	var waypoint: Vector3 = _level.call("next_path_point", global_position, _player.global_position)
	var step := waypoint - global_position
	step.y = 0.0
	if step.length() <= 0.1:
		if _sidestep_time <= 0.0:
			return direct
		# Sidestep even when the waypoint says "go straight": we are stuck.
		return direct.rotated(Vector3.UP, _sidestep_sign * PI * 0.5)
	var dir := step.normalized()
	if _sidestep_time > 0.0:
		dir = dir.rotated(Vector3.UP, _sidestep_sign * PI * 0.5)
	return dir

## Caches the LevelBuilder so demons can path around the arena geometry.
func _acquire_level() -> void:
	if _level != null and is_instance_valid(_level):
		return
	var levels := get_tree().get_nodes_in_group("level")
	_level = levels[0] if not levels.is_empty() else null

## Lateral sidestep when the demon wants to move but keeps hitting geometry,
## so it slides around pillars and concave wall corners instead of pinning
## itself forever (Level Design: demons must not get stuck).
func _tick_unstuck(delta: float) -> void:
	if _sidestep_time > 0.0:
		_sidestep_time -= delta
	var wants_move := _player != null and Vector2(velocity.x, velocity.z).length() > 0.5
	if not wants_move:
		_progress_timer = 0.0
		_progress_position = global_position
		return
	_progress_timer += delta
	if _progress_timer >= 0.5:
		var moved := global_position.distance_to(_progress_position)
		if moved < 0.3:
			_sidestep_time = 0.6
			_sidestep_sign = 1.0 if randf() < 0.5 else -1.0
		_progress_timer = 0.0
		_progress_position = global_position

func _explode() -> void:
	if health <= 0.0:
		return
	EffectUtil.spawn_debris(get_tree(), global_position + Vector3.UP * 0.5, 10, Color("#ffd166"), 5.0)
	var player := EffectUtil.player(get_tree())
	if player != null and player.global_position.distance_to(global_position) <= BOMBER_RADIUS:
		if player.has_method("take_damage"):
			player.call("take_damage", damage, global_position)
	_die()

## True when the caster is at a similar height and has clear line of sight from
## this demon's chest. Stops floor-through melee bites.
func _can_reach_player() -> bool:
	if _player == null:
		return false
	if absf(_player.global_position.y - global_position.y) > REACH_HEIGHT:
		return false
	var world := get_world_3d()
	if world == null:
		return true
	var from := global_position + Vector3.UP * 0.7
	var to := _player.global_position + Vector3.UP * 0.9
	var params := PhysicsRayQueryParameters3D.create(from, to, 16)
	params.exclude = [get_rid()]
	return world.direct_space_state.intersect_ray(params).is_empty()

## Ranged archetype: closes to firing range, holds there and shoots hex bolts.
## Backs away when the caster gets closer than its preferred stand-off distance.
func _chase_ranged(delta: float, dir: Vector3, dist: float, spd: float) -> void:
	if dist > WRAITH_FIRE_RANGE:
		velocity.x = dir.x * spd
		velocity.z = dir.z * spd
	elif dist < WRAITH_PREFERRED_RANGE:
		velocity.x = -dir.x * spd
		velocity.z = -dir.z * spd
	else:
		velocity.x = 0.0
		velocity.z = 0.0
	if dist <= WRAITH_FIRE_RANGE and _has_line_of_sight():
		_fire(delta, dir)

## True when nothing solid (layer 16) sits between this demon and the caster, so
## hex bolts are not fired straight through a wall.
func _has_line_of_sight() -> bool:
	if _player == null:
		return false
	var world := get_world_3d()
	if world == null:
		return true
	var from := global_position + Vector3.UP * 0.9
	var to := _player.global_position + Vector3.UP * 0.9
	var params := PhysicsRayQueryParameters3D.create(from, to, 16)
	params.exclude = [get_rid()]
	return world.direct_space_state.intersect_ray(params).is_empty()

## Launches a hex bolt toward the caster (GDD spell 9 reflects these back).
func _fire(delta: float, dir: Vector3) -> void:
	_fire_timer -= delta
	if _fire_timer > 0.0:
		return
	_fire_timer = GameConfig.ENEMY_ATTACK_COOLDOWN
	var host := get_tree().current_scene
	if host == null:
		return
	var bolt := Projectile.new()
	var origin := global_position + Vector3.UP * 0.9
	EffectUtil.sound(get_tree(), &"bolt_fire", origin)
	bolt.setup(origin, dir, GameConfig.PROJECTILE_SPEED * 0.6, WRAITH_DAMAGE * GameConfig.enemy_damage_mult(), true)
	host.add_child(bolt)

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
	_update_hp_bar()
	if health <= 0.0:
		_die()

## World-space centre of the demon's body, used for projectile hit tests. The
## node origin sits at the feet, so comparing a bolt (which flies at eye height)
## against it made shots whiff when aimed at anything but the floor.
func hurt_center() -> Vector3:
	return global_position + Vector3.UP * 0.8

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
	# Physics debris burst on death (ROADMAP Stage 3).
	EffectUtil.spawn_debris(get_tree(), global_position + Vector3.UP * 0.7, 6, _placeholder_colour(), 3.5)
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
