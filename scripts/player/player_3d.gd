class_name Player
## The Desk Exorcist (3D / first-person). Implements the Hold & Release core loop
## (GDD section 2): keys 1-0 charge a spell while rooting the caster in place;
## releasing at 100% casts, releasing early fizzles for free. A hit interrupts
## the charge. All tuning values come from the GameConfig autoload.
extends CharacterBody3D

signal died
signal health_changed(value: float, max_value: float)
signal charge_changed(ratio: float)

@onready var _camera: Camera3D = get_node_or_null("Camera3D") as Camera3D
@onready var _auto_weapon: Node = get_node_or_null("AutoWeapon")
## First-person casting hands, parented to the camera (Viewmodel.attach).
var _viewmodel: Viewmodel = null

# --- Stats (scaled by level-up cards via UpgradePool) -----------------------
var max_health: float = float(GameConfig.PLAYER_MAX_HEALTH)
var health: float = float(GameConfig.PLAYER_MAX_HEALTH)
var move_speed: float = GameConfig.MOVE_SPEED
var damage_multiplier: float = 1.0
var pickup_radius: float = GameConfig.SOUL_PICKUP_RADIUS
var level: int = 1
var soul_gauge: float = 0.0

# --- Roguelike modifiers (ROADMAP Stage C: expanded upgrade pool) ------------
## Multiplies every spell's cooldown (<1 = faster casting).
var cooldown_multiplier: float = 1.0
## Holy bolts fired per click (spread in a small fan).
var projectile_count: int = 1
## Extra enemies a holy bolt can pass through before it dies.
var projectile_pierce: int = 0
## Passive HP restored per second.
var regen: float = 0.0
## Multiplies the soul gauge gained per collected orb.
var soul_gain_multiplier: float = 1.0

## Slot index 0..9 -> spell. Slot 0 is key "1" ... slot 9 is key "0".
var spells: Array[BaseSpell] = []

# --- Hold & Release state ---------------------------------------------------
var _charging_slot: int = -1
## Fraction of walk speed available while a spell is charging. Charging is no
## longer a standstill, but it is still a commitment (BUGS.md #20).
const CHARGE_MOVE_SCALE := 0.45
var _charge_timer: float = 0.0
var _stunned: bool = false
var _stun_time: float = 0.0
var _preview: SpellPreview = null

var _cooldowns: Dictionary = {}   # spell_id -> seconds left
var _shield_time: float = 0.0
var _invuln_time: float = 0.0
var _slow_time: float = 0.0
var _slow_ratio: float = 0.0
## Active paper-pile zones the caster is standing in (Level Design Ур.2).
var _paper_zones: int = 0

var _mouse_captured: bool = true

## Code-built idle / run / cast_hold / cast_release clips (BlenderInstruction 4).
var _anim: AnimationPlayer = null
var _anim_state: String = ""

## Footstep / landing bookkeeping for the audio cues (ROADMAP Stage 4).
var _was_on_floor: bool = true
var _step_timer: float = 0.0

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
		_anim = PlayerAnimation.attach(self, model_root)
		_hide_own_model_from_camera(model_root)
	_viewmodel = Viewmodel.attach(_camera)
	# The body's own shadow falls behind the caster, where the first-person
	# camera can never see it -- this is the patch the caster does see.
	ContactShadow.attach(self)
	# Pre-run terminal perk (Meta overlay, seen in the main menu).
	var meta := get_node_or_null("/root/Meta")
	if meta != null:
		match meta.starting_perk:
			"vigor":
				max_health += 50.0
				health = max_health
			"swiftness":
				move_speed *= 1.2
			"zeal":
				damage_multiplier *= 1.2
		# Permanent post-victory perks accumulate across runs (NG+ loop).
		max_health += meta.perm_hp_bonus
		health = max_health
		damage_multiplier *= meta.perm_dmg_mult
		move_speed *= meta.perm_speed_mult
		# Soul-shop upgrades (E4).
		max_health += 10.0 * meta.upgrade_level("hp")
		health = max_health
		damage_multiplier *= 1.0 + 0.05 * meta.upgrade_level("dmg")
		move_speed *= 1.0 + 0.05 * meta.upgrade_level("speed")
	# Target-zone preview shown while a spell is charged (GDD section 2).
	_preview = SpellPreview.new()
	add_child(_preview)

## Layer reserved for the caster's own body: rendered by every camera *except*
## the first-person one, so the arms/torso cannot clip through the view.
const OWN_BODY_LAYER := 20

func _hide_own_model_from_camera(model_root: Node3D) -> void:
	const BIT := 1 << (OWN_BODY_LAYER - 1)
	for node in model_root.find_children("*", "MeshInstance3D", true, false):
		(node as MeshInstance3D).layers = BIT
	if _camera != null:
		_camera.cull_mask &= ~BIT

# --- Input ------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and _mouse_captured:
		_look(event.relative)
		return
	# Esc is owned by PauseMenu (ROADMAP 1.3): it now freezes the run instead of
	# merely toggling mouse capture.
	if event.is_action_pressed(&"attack") and _auto_weapon != null:
		_fire_auto_weapon()
	if event.is_action_pressed(&"debug_kill_all"):
		_kill_enemy_under_aim()
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
	# The orb in the cupped palms takes the spell's colour, so the charge is
	# identifiable from inside the arena view without reading the HUD.
	if _viewmodel != null:
		_viewmodel.set_spell_colour(spell.colour)
	_show_preview(spell)
	EffectUtil.sound(get_tree(), &"player_charge_start", global_position)

func _release_charging() -> void:
	var slot := _charging_slot
	var spell := _spell_for_slot(slot)
	_charging_slot = -1
	if _viewmodel != null:
		_viewmodel.set_charge(0.0)
	_clear_preview()
	charge_changed.emit(0.0)
	if spell == null:
		return
	# Below full charge the spell fizzles and costs no cooldown.
	if _charge_timer < spell.charge_time:
		EffectUtil.sound(get_tree(), &"player_fizzle", global_position)
		return
	# Casting the ultimate spends the whole soul gauge.
	if spell.spell_id == 0:
		soul_gauge = 0.0
	_cooldowns[spell.spell_id] = spell.effective_cooldown() * cooldown_multiplier
	spell.cast_effect(global_position, aim_point_raycast(), get_tree())
	EffectUtil.spell_cast(get_tree(), spell.spell_id, global_position)
	EffectUtil.sound(get_tree(), &"player_cast_release", global_position)
	# One-shot release flourish, then back to the locomotion clips.
	if _anim != null and _anim.has_animation(PlayerAnimation.CAST_RELEASE):
		_anim_state = PlayerAnimation.CAST_RELEASE
		_anim.play(PlayerAnimation.CAST_RELEASE)
	if _viewmodel != null:
		_viewmodel.play_release()

func _tick_charge(delta: float) -> void:
	if _charging_slot == -1:
		if _viewmodel != null:
			_viewmodel.set_charge(0.0)
		return
	var spell := _spell_for_slot(_charging_slot)
	if spell == null:
		_charging_slot = -1
		return
	_charge_timer = minf(_charge_timer + delta, spell.charge_time)
	var ratio := _charge_timer / spell.charge_time
	charge_changed.emit(ratio)
	# The hands read the charge too: they close on the orb as it fills, which is
	# the only charge feedback that stays inside the arena view.
	if _viewmodel != null:
		_viewmodel.set_charge(ratio)
	# Keep a directional preview pointed where the player is looking.
	if _preview != null and _preview.visible:
		_preview.update_aim(_aim_dir())

## Point ~100 m along the camera's forward axis, used as the spell target.
func _aim_point() -> Vector3:
	return _camera.global_position - _camera.global_transform.basis.z * 100.0

## Horizontal aim direction (from the camera), used to orient spell previews.
## Null-safe: the HUD asks every frame, including while a scene is being torn
## down and the camera has already gone.
func _aim_dir() -> Vector3:
	if _camera == null:
		return Vector3.FORWARD
	return -_camera.global_transform.basis.z

## Where the caster is LOOKING, flattened to the XZ plane and normalised.
## The minimap is a top-down view, so it has no use for the pitch -- and the
## camera pitches all the time (looking up at demons, down from a balcony).
func look_direction() -> Vector3:
	var dir := _aim_dir()
	dir.y = 0.0
	return dir.normalized() if dir.length() > 0.001 else Vector3.FORWARD

## True while a spell is being charged (public for HUD, cards and tests).
func is_charging() -> bool:
	return _charging_slot != -1

## Shows the target-zone hint for the spell now charging.
func _show_preview(spell: BaseSpell) -> void:
	if _preview == null:
		return
	_preview.visible = true
	_preview.configure(spell, _aim_dir())

## Hides and clears the target-zone hint.
func _clear_preview() -> void:
	if _preview == null:
		return
	_preview.visible = false
	_preview.clear()

## Enemy the reticle is actually looking at, or null. Casts a ray from the camera
## down its forward axis against the enemy layer (2), so spells like the Heavenly
## Hammer drop exactly where the player is aiming instead of 100 m away.
func aim_enemy() -> Node3D:
	var world := get_world_3d()
	if world == null or _camera == null:
		return null
	var from := _camera.global_position
	var to := _aim_point()
	var params := PhysicsRayQueryParameters3D.create(from, to, 2)
	params.exclude = [get_rid()]
	var hit := world.direct_space_state.intersect_ray(params)
	if hit.is_empty():
		return null
	return hit.get("collider") as Node3D

## Point where the aim ray first meets world geometry or an enemy, used to place
## ground-targeted spells (e.g. Heavenly Hammer at GDD spell 5). Falls back to
## the 100 m aim point when nothing is hit.
func aim_point_raycast() -> Vector3:
	var world := get_world_3d()
	if world == null or _camera == null:
		return _aim_point()
	var from := _camera.global_position
	var to := _aim_point()
	var params := PhysicsRayQueryParameters3D.create(from, to, 2 | 16)
	params.exclude = [get_rid()]
	var hit := world.direct_space_state.intersect_ray(params)
	if hit.is_empty():
		return to
	return hit["position"] as Vector3

## Debug (K): instantly kills the demon under the reticle, or all demons within
## 2.5 m when the ray misses, so an overrun can be cleared while playtesting.
func _kill_enemy_under_aim() -> void:
	var target := aim_enemy()
	if target != null and target.has_method("take_damage"):
		target.call("take_damage", 99999.0, global_position)
		return
	for e in EffectUtil.enemies_in_radius(get_tree(), global_position, 2.5):
		EffectUtil.damage(e, 99999.0, global_position)

func _spell_for_slot(slot: int) -> BaseSpell:
	if slot < 0 or slot >= spells.size():
		return null
	return spells[slot]

func _fire_auto_weapon() -> void:
	if _viewmodel != null:
		_viewmodel.play_fire()
	if _auto_weapon.has_method("fire"):
		# From the charge in the caster's palms, not from their own head: the
		# bolt is the orb leaving the hands, and a shot that appears at the
		# screen's own origin has nothing to do with anything on screen.
		var muzzle := global_position + Vector3.UP * 1.5
		if _viewmodel != null:
			muzzle = _viewmodel.muzzle_position()
		_auto_weapon.call("fire", _aim_point(), muzzle)

## Camera look.  Sensitivity comes from the Settings autoload (ROADMAP Stage 4)
## and falls back to the GameConfig constant when Settings is absent (tests).
func _look(relative: Vector2) -> void:
	var sens := GameConfig.MOUSE_SENSITIVITY
	var settings := get_node_or_null("/root/Settings")
	if settings != null:
		sens = settings.mouse_sensitivity
	rotate_y(-relative.x * sens)
	_camera.rotate_x(-relative.y * sens)
	_camera.rotation.x = clampf(_camera.rotation.x, -PI * 0.5, PI * 0.5)

func _set_mouse_captured(captured: bool) -> void:
	_mouse_captured = captured
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if captured else Input.MOUSE_MODE_VISIBLE

func _handle_spell_input(event: InputEvent) -> void:
	# Deliberate abort of a charge in progress. Before, the ONLY way out of one
	# was to take a hit, so a mis-cast had to be paid for in health (BUGS.md
	# #21). Right mouse button, bound as "cancel_cast" in InputSetup.
	if event.is_action_pressed(&"cancel_cast"):
		_cancel_charging()
		return
	for slot in InputSetup.SPELL_KEYS.size():
		var action := InputSetup.spell_action(slot)
		if event.is_action_pressed(action):
			_start_charging(slot)
		elif event.is_action_released(action) and _charging_slot == slot:
			_release_charging()
			_pick_up_held_spell()

## After a spell fires, pick up another spell key that is still down.
##
## `_start_charging` refuses while a slot is busy, so pressing "2" before letting
## go of "1" dropped that press on the floor -- and `is_action_pressed` ignores
## key repeat, so holding "2" never re-fired it. Casting two spells back to back
## silently did nothing until the player let go and pressed again (BUGS.md #17).
func _pick_up_held_spell() -> void:
	if _charging_slot != -1:
		return
	for slot in InputSetup.SPELL_KEYS.size():
		if Input.is_action_pressed(InputSetup.spell_action(slot)):
			_start_charging(slot)
			return

## Drops an in-flight charge without casting and without a cooldown.
func _cancel_charging() -> void:
	if _charging_slot == -1:
		return
	_charging_slot = -1
	_charge_timer = 0.0
	if _viewmodel != null:
		_viewmodel.set_charge(0.0)
	_clear_preview()
	charge_changed.emit(0.0)

## Input stops while the tree is paused, so a charge interrupted by the reward
## screen (or Esc) never sees its key-up: `_charging_slot` stays set, and while
## charging the caster moves at `CHARGE_MOVE_SCALE` and no other spell can start,
## so a stuck key leaves him crawling at a third of his speed until he presses and
## releases it again. That was the "hang after casting" (BUGS.md #17), so any
## pause ends the charge it interrupted.
func _notification(what: int) -> void:
	if what == NOTIFICATION_UNPAUSED:
		_cancel_charging()

# --- Physics ----------------------------------------------------------------

func _physics_process(delta: float) -> void:
	_tick_timers(delta)
	_tick_charge(delta)
	_tick_regen(delta)
	_apply_gravity(delta)
	_apply_movement()
	move_and_slide()
	_tick_footsteps(delta)
	_update_animation()

## Passive HP regeneration from level-up cards.
func _tick_regen(delta: float) -> void:
	if regen > 0.0 and health > 0.0 and health < max_health:
		health = minf(max_health, health + regen * delta)
		health_changed.emit(health, max_health)

## Emits a footstep cue at a fixed cadence while running on the floor.
func _tick_footsteps(delta: float) -> void:
	if not is_on_floor() or Vector2(velocity.x, velocity.z).length() <= 0.1:
		_step_timer = 0.0
		return
	_step_timer -= delta
	if _step_timer <= 0.0:
		_step_timer = 0.4
		EffectUtil.sound(get_tree(), &"player_footstep", global_position)

## Picks the clip that matches the current state (BlenderInstruction section 4):
## cast_hold while a spell is charged, run while moving, idle otherwise.
func _update_animation() -> void:
	var want := PlayerAnimation.IDLE
	if _charging_slot != -1:
		want = PlayerAnimation.CAST_HOLD
	elif Vector2(velocity.x, velocity.z).length() > 0.1:
		want = PlayerAnimation.RUN
	_play(want)
	# The hands track the same four states, in their own vocabulary. Updated
	# even when the body has no AnimationPlayer, so the viewmodel never depends
	# on the world-model asset being present.
	if _viewmodel != null:
		_viewmodel.set_state(want)

## Switches clips only when the desired one changes, so looping clips are not
## restarted every physics frame.
func _play(clip: String) -> void:
	if clip == _anim_state or not _anim.has_animation(clip):
		return
	_anim_state = clip
	_anim.play(clip)

func _apply_gravity(delta: float) -> void:
	var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
	if is_on_floor():
		# Grounded: jump if asked, otherwise cancel any residual vertical velocity
		# so the capsule cannot drift upward (mirrors enemy.gd).
		if not _was_on_floor:
			EffectUtil.sound(get_tree(), &"player_land", global_position)
		_was_on_floor = true
		if Input.is_action_just_pressed(&"jump") and not _is_rooted():
			velocity.y = GameConfig.JUMP_VELOCITY
			EffectUtil.sound(get_tree(), &"player_jump", global_position)
		else:
			velocity.y = 0.0
	else:
		_was_on_floor = false
		velocity.y -= gravity * delta

func _apply_movement() -> void:
	# A stun still roots the caster. Charging no longer does: it used to zero the
	# velocity outright, which turned every spell into a standstill with demons
	# closing in -- "I cannot stop and read a spell" and "backing into a corner
	# gets me eaten" were the same bug seen from two sides (BUGS.md #20).
	if _stunned:
		velocity.x = 0.0
		velocity.z = 0.0
		return
	var input := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	var dir := (transform.basis * Vector3(input.x, 0.0, input.y)).normalized()
	var speed := move_speed * (1.0 - maxf(_slow_ratio, _paper_slow_ratio()))
	if _charging_slot != -1:
		speed *= CHARGE_MOVE_SCALE
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed

## True when the caster cannot move at all (only a stun does that now).
func _is_rooted() -> bool:
	return _stunned

func _tick_timers(delta: float) -> void:
	for id in _cooldowns.keys():
		var left: float = float(_cooldowns[id]) - delta
		if left <= 0.0:
			_cooldowns.erase(id)
		else:
			_cooldowns[id] = left
	if _shield_time > 0.0:
		_shield_time = maxf(0.0, _shield_time - delta)
	if _invuln_time > 0.0:
		_invuln_time = maxf(0.0, _invuln_time - delta)
	if _stun_time > 0.0:
		_stun_time = maxf(0.0, _stun_time - delta)
		if _stun_time == 0.0:
			_stunned = false
	if _slow_time > 0.0:
		_slow_time = maxf(0.0, _slow_time - delta)
		if _slow_time == 0.0:
			_slow_ratio = 0.0


# --- Public API used by HUD, enemies, projectiles and spell effects ---------

## Feeds the soul gauge (0..1) from a collected soul. A full gauge unlocks the
## Last Judgement ultimate (spell 0).
func add_soul(amount: float) -> void:
	soul_gauge = clampf(soul_gauge + amount * soul_gain_multiplier, 0.0, 1.0)

## True once the soul gauge is full and Last Judgement is castable.
func is_soul_ready() -> bool:
	return soul_gauge >= 1.0

## Fraction of the spell's cooldown still remaining (0 = ready, 1 = just cast).
func cooldown_ratio(id: int) -> float:
	if not _cooldowns.has(id):
		return 0.0
	var spell := _spell_for_id(id)
	var total := spell.effective_cooldown() * cooldown_multiplier if spell != null else 1.0
	if total <= 0.0:
		return 0.0
	return clampf(float(_cooldowns[id]) / total, 0.0, 1.0)

## True while the caster still has HP.
func is_alive() -> bool:
	return health > 0.0

## World-space centre of the caster's torso, used for projectile hit tests.
## The node origin is at the feet; bolts travel near eye height.
func hurt_center() -> Vector3:
	return global_position + Vector3.UP * 0.9

## Called by paper-pile Area3Ds while the caster stands on loose papers.
func paper_zone_enter() -> void:
	_paper_zones += 1

func paper_zone_exit() -> void:
	_paper_zones = maxi(0, _paper_zones - 1)

## Slow ratio applied while on loose papers (Ур.2): 50% speed.
func _paper_slow_ratio() -> float:
	return 0.5 if _paper_zones > 0 else 0.0

## Applies incoming damage, absorbed entirely while the mirror shield is up.
## A short invulnerability window after each hit keeps a pack of demons from
## stacking several contacts into one instant.
func take_damage(amount: float, source: Vector3 = Vector3.INF) -> void:
	if _shield_time > 0.0 or health <= 0.0 or _invuln_time > 0.0:
		return
	_invuln_time = GameConfig.PLAYER_HIT_INVULN
	health = maxf(0.0, health - amount)
	_interrupt_charge()
	# Shove the pack off the caster. Being caught against a wall used to be a
	# death sentence: six demons inside a 1.8 m reach, one hit every cooldown,
	# and no room to back out of (BUGS.md #20). The hit now buys space.
	_shove_demons(source)
	EffectUtil.sound(get_tree(), &"player_hurt", global_position)
	health_changed.emit(health, max_health)
	# Screen shake on every hit (ROADMAP Stage 3 VFX).
	for h in get_tree().get_nodes_in_group("hud"):
		if h.has_method("shake"):
			h.call("shake")
		if h.has_method("flash_damage"):
			h.call("flash_damage")
	if health <= 0.0:
		EffectUtil.sound(get_tree(), &"player_death", global_position)
		died.emit()

## Pushes every demon in melee range away, hardest for the one that hit. Gives
## the caster one beat to break contact instead of being held in place by the
## bodies he is trying to walk out of.
##
## The boss is deliberately not on this list: it is a separate class (`Boss` is
## not an `Enemy`) and shoving it would walk its slam telegraph out from under
## itself. The demons escorting it still get pushed.
func _shove_demons(source: Vector3) -> void:
	for node in get_tree().get_nodes_in_group("enemies"):
		if not (node is Enemy) or not is_instance_valid(node):
			continue
		var enemy := node as Enemy
		var away := enemy.global_position - global_position
		away.y = 0.0
		var dist := away.length()
		if dist > GameConfig.ENEMY_ATTACK_RANGE + 1.2:
			continue
		var strength := GameConfig.PLAYER_HIT_SHOVE
		if source != Vector3.INF and enemy.global_position.distance_to(source) < 0.6:
			strength *= 1.4
		enemy.shove(away.normalized() if dist > 0.01 else Vector3.BACK, strength)

## Restores HP, clamped to the current maximum (Pride's lifesteal).
func heal(amount: float) -> void:
	if amount <= 0.0 or health <= 0.0:
		return
	health = minf(max_health, health + amount)
	health_changed.emit(health, max_health)

## Raises the Mirror of the Soul dome for `duration` seconds.
func grant_shield(duration: float) -> void:
	_shield_time = maxf(_shield_time, duration)

## True while the Mirror of the Soul shield is up. Enemy bolts that touch a
## shielded caster are reflected back instead of absorbed (GDD spell 9).
func is_shielded() -> bool:
	return _shield_time > 0.0

## Furthest point along `dir` (up to `distance`) that is not blocked by level
## geometry, so Holy Step never blinks through a wall (GDD spell 8). The probe
## ray is cast at chest height against the level collision layer (16).
func blink_target(dir: Vector3, distance: float) -> Vector3:
	var aim := dir.normalized()
	if aim == Vector3.ZERO:
		aim = -global_transform.basis.z
	var full := global_position + aim * distance
	var world := get_world_3d()
	if world == null:
		return full
	var space := world.direct_space_state
	if space == null:
		return full
	var chest := global_position + Vector3.UP * 0.9
	var params := PhysicsRayQueryParameters3D.create(chest, chest + aim * distance, 16)
	params.exclude = [get_rid()]
	var hit := space.intersect_ray(params)
	if hit.is_empty():
		return full
	var safe: Vector3 = (hit["position"] as Vector3) - aim * 0.6
	safe.y = global_position.y
	return safe

## Teleports the caster to `destination` (Holy Step).
func blink_to(destination: Vector3) -> void:
	global_position = destination

func _spell_for_id(id: int) -> BaseSpell:
	for spell in spells:
		if spell.spell_id == id:
			return spell
	return null

## A hit while charging breaks the cast. Per GDD section 2 the interrupted spell
## goes on a short penalty cooldown and the caster is briefly stunned, so you
## cannot simply re-charge under a rain of hits.
func _interrupt_charge() -> void:
	if _charging_slot == -1:
		return
	var spell := _spell_for_slot(_charging_slot)
	_charging_slot = -1
	_charge_timer = 0.0
	_clear_preview()
	charge_changed.emit(0.0)
	# Penalty cooldown proportional to the charge, capped so long casts are not
	# locked out for their whole cooldown.
	if spell != null:
		var penalty := minf(spell.charge_time * 0.5, 2.0)
		_cooldowns[spell.spell_id] = maxf(float(_cooldowns.get(spell.spell_id, 0.0)), penalty)
	_stun(GameConfig.INTERRUPT_STUN)

## Briefly roots and disables casting; the caster cannot act until it expires.
func _stun(duration: float) -> void:
	_stunned = true
	_stun_time = maxf(_stun_time, duration)

## True while the caster is stunned (cannot move or cast).
func is_stunned() -> bool:
	return _stunned


