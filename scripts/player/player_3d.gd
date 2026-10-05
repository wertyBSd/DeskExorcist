class_name Player
## The Desk Exorcist (3D / first-person). Implements the Hold & Release core loop
## (GDD section 2): keys 1-0 charge a spell while rooting the caster in place;
## releasing at 100% casts, releasing early fizzles for free. A hit interrupts
## the charge. All tuning values come from the GameConfig autoload.
extends CharacterBody3D

signal died
signal health_changed(value: float, max_value: float)
signal charge_changed(ratio: float)

@onready var _camera: Camera3D = $Camera3D
@onready var _auto_weapon: Node = get_node_or_null("AutoWeapon")

# --- Stats (scaled by level-up cards via UpgradePool) -----------------------
var max_health: float = float(GameConfig.PLAYER_MAX_HEALTH)
var health: float = float(GameConfig.PLAYER_MAX_HEALTH)
var move_speed: float = GameConfig.MOVE_SPEED
var damage_multiplier: float = 1.0
var pickup_radius: float = GameConfig.SOUL_PICKUP_RADIUS
var level: int = 1
var soul_gauge: float = 0.0

## Slot index 0..9 -> spell. Slot 0 is key "1" ... slot 9 is key "0".
var spells: Array[BaseSpell] = []

# --- Hold & Release state ---------------------------------------------------
var _charging_slot: int = -1
var _charge_timer: float = 0.0
var _stunned: bool = false

var _cooldowns: Dictionary = {}   # spell_id -> seconds left
var _shield_time: float = 0.0
var _slow_time: float = 0.0
var _slow_ratio: float = 0.0

var _mouse_captured: bool = true

func _ready() -> void:
	add_to_group("player")
	spells = SpellLibrary.build_all()
	health = max_health
	_set_mouse_captured(true)
	health_changed.emit(health, max_health)
	# First-person view never sees the caster's own body, but the model is
	# attached under a dedicated node so the collision capsule keeps owning
	# the origin (and third-person/debug cameras still show the hero).
	var model_root := get_node_or_null("ModelRoot") as Node3D
	if model_root != null:
		ModelLibrary.attach(model_root, ModelLibrary.EXORCIST, 1.7)

# --- Input ------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and _mouse_captured:
		_look(event.relative)
		return
	if event.is_action_pressed(&"pause"):
		_set_mouse_captured(not _mouse_captured)
		return
	if event.is_action_pressed(&"attack") and _auto_weapon != null:
		_fire_auto_weapon()
	_handle_spell_input(event)


# --- Spell lifecycle --------------------------------------------------------

func _start_charging(slot: int) -> void:
	if _stunned or _charging_slot != -1:
		return
	var spell := _spell_for_slot(slot)
	if spell == null or spell.is_locked:
		return
	if cooldown_ratio(spell.spell_id) > 0.0:
		return
	# Last Judgement (spell 0) is gated on a full soul gauge (GDD section 3).
	if spell.spell_id == 0 and soul_gauge < 1.0:
		return
	_charging_slot = slot
	_charge_timer = 0.0

func _release_charging() -> void:
	var slot := _charging_slot
	var spell := _spell_for_slot(slot)
	_charging_slot = -1
	charge_changed.emit(0.0)
	if spell == null:
		return
	# Below full charge the spell fizzles and costs no cooldown.
	if _charge_timer < spell.charge_time:
		return
	# Casting the ultimate spends the whole soul gauge.
	if spell.spell_id == 0:
		soul_gauge = 0.0
	_cooldowns[spell.spell_id] = spell.effective_cooldown()
	spell.cast_effect(global_position, _aim_point(), get_tree())

func _tick_charge(delta: float) -> void:
	if _charging_slot == -1:
		return
	var spell := _spell_for_slot(_charging_slot)
	if spell == null:
		_charging_slot = -1
		return
	_charge_timer = minf(_charge_timer + delta, spell.charge_time)
	charge_changed.emit(_charge_timer / spell.charge_time)

## Point ~100 m along the camera's forward axis, used as the spell target.
func _aim_point() -> Vector3:
	return _camera.global_position - _camera.global_transform.basis.z * 100.0

func _spell_for_slot(slot: int) -> BaseSpell:
	if slot < 0 or slot >= spells.size():
		return null
	return spells[slot]

func _fire_auto_weapon() -> void:
	if _auto_weapon.has_method("fire"):
		_auto_weapon.call("fire", _aim_point())

func _look(relative: Vector2) -> void:
	rotate_y(-relative.x * GameConfig.MOUSE_SENSITIVITY)
	_camera.rotate_x(-relative.y * GameConfig.MOUSE_SENSITIVITY)
	_camera.rotation.x = clampf(_camera.rotation.x, -PI * 0.5, PI * 0.5)

func _set_mouse_captured(captured: bool) -> void:
	_mouse_captured = captured
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if captured else Input.MOUSE_MODE_VISIBLE

func _handle_spell_input(event: InputEvent) -> void:
	for slot in InputSetup.SPELL_KEYS.size():
		var action := InputSetup.spell_action(slot)
		if event.is_action_pressed(action):
			_start_charging(slot)
		elif event.is_action_released(action) and _charging_slot == slot:
			_release_charging()

# --- Physics ----------------------------------------------------------------

func _physics_process(delta: float) -> void:
	_tick_timers(delta)
	_tick_charge(delta)
	_apply_gravity(delta)
	_apply_movement()
	move_and_slide()

func _apply_gravity(delta: float) -> void:
	var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
	if is_on_floor():
		# Grounded: jump if asked, otherwise cancel any residual vertical velocity
		# so the capsule cannot drift upward (mirrors enemy.gd).
		if Input.is_action_just_pressed(&"jump") and not _is_rooted():
			velocity.y = GameConfig.JUMP_VELOCITY
		else:
			velocity.y = 0.0
	else:
		velocity.y -= gravity * delta

func _apply_movement() -> void:
	# Holding a charge (or being stunned) roots the caster in place.
	if _is_rooted():
		velocity.x = 0.0
		velocity.z = 0.0
		return
	var input := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	var dir := (transform.basis * Vector3(input.x, 0.0, input.y)).normalized()
	var speed := move_speed * (1.0 - _slow_ratio)
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed

func _is_rooted() -> bool:
	return _charging_slot != -1 or _stunned

func _tick_timers(delta: float) -> void:
	for id in _cooldowns.keys():
		var left: float = float(_cooldowns[id]) - delta
		if left <= 0.0:
			_cooldowns.erase(id)
		else:
			_cooldowns[id] = left
	if _shield_time > 0.0:
		_shield_time = maxf(0.0, _shield_time - delta)
	if _slow_time > 0.0:
		_slow_time = maxf(0.0, _slow_time - delta)
		if _slow_time == 0.0:
			_slow_ratio = 0.0


# --- Public API used by HUD, enemies, projectiles and spell effects ---------

## Feeds the soul gauge (0..1) from a collected soul. A full gauge unlocks the
## Last Judgement ultimate (spell 0).
func add_soul(amount: float) -> void:
	soul_gauge = clampf(soul_gauge + amount, 0.0, 1.0)

## True once the soul gauge is full and Last Judgement is castable.
func is_soul_ready() -> bool:
	return soul_gauge >= 1.0

## Fraction of the spell's cooldown still remaining (0 = ready, 1 = just cast).
func cooldown_ratio(id: int) -> float:
	if not _cooldowns.has(id):
		return 0.0
	var spell := _spell_for_id(id)
	var total := spell.effective_cooldown() if spell != null else 1.0
	if total <= 0.0:
		return 0.0
	return clampf(float(_cooldowns[id]) / total, 0.0, 1.0)

## True while the caster still has HP.
func is_alive() -> bool:
	return health > 0.0

## Applies incoming damage, absorbed entirely while the mirror shield is up.
func take_damage(amount: float, _source: Vector3 = Vector3.INF) -> void:
	if _shield_time > 0.0 or health <= 0.0:
		return
	health = maxf(0.0, health - amount)
	_interrupt_charge()
	health_changed.emit(health, max_health)
	if health <= 0.0:
		died.emit()

## Restores HP, clamped to the current maximum (Pride's lifesteal).
func heal(amount: float) -> void:
	if amount <= 0.0 or health <= 0.0:
		return
	health = minf(max_health, health + amount)
	health_changed.emit(health, max_health)

## Raises the Mirror of the Soul dome for `duration` seconds.
func grant_shield(duration: float) -> void:
	_shield_time = maxf(_shield_time, duration)

## Teleports the caster to `destination` (Holy Step).
func blink_to(destination: Vector3) -> void:
	global_position = destination

func _spell_for_id(id: int) -> BaseSpell:
	for spell in spells:
		if spell.spell_id == id:
			return spell
	return null

## A hit while charging breaks the cast without spending a cooldown.
func _interrupt_charge() -> void:
	if _charging_slot != -1:
		_charging_slot = -1
		_charge_timer = 0.0
		charge_changed.emit(0.0)

