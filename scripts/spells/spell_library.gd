class_name SpellLibrary
## The ten concrete spells from GDD section 3, plus the registry the player and
## the ability bar read from.
##
## Each spell is a small BaseSpell subclass whose only job is to spawn its own
## effect node (see SpellEffects).  Spells stay stateless so they can be shared
## between the player, the HUD and the upgrade cards.

extends RefCounted

# --- Concrete spells ---------------------------------------------------------

## 1 - Word of Purification: small AoE that knocks enemies away from the caster.
class WordOfPurification extends BaseSpell:
	func _init() -> void:
		spell_id = 1
		display_name = "Слово Очищения"
		charge_time = 0.8
		cooldown = 3.0
		base_damage = 12.0
		radius = 5.0
		colour = Color("#ffe9a8")

	func cast_effect(player_position: Vector3, _target_position: Vector3, tree: SceneTree) -> void:
		SpellEffects.purifying_wave(tree, player_position, radius, base_damage, colour)

## 2 - Holy Ground: static zone that slows by 70% and ticks damage for 5s.
class HolyGround extends BaseSpell:
	func _init() -> void:
		spell_id = 2
		display_name = "Святая Земля"
		charge_time = 1.2
		cooldown = 6.0
		base_damage = 6.0
		radius = 6.5
		colour = Color("#fff2b0")

	func cast_effect(player_position: Vector3, _target_position: Vector3, tree: SceneTree) -> void:
		SpellEffects.holy_ground(tree, player_position, radius, base_damage, 5.0)

## 3 - Expulsion of Pride: drains HP from everything in range (5% lifesteal).
class ExpulsionOfPride extends BaseSpell:
	func _init() -> void:
		spell_id = 3
		display_name = "Изгнание Гордыни"
		charge_time = 1.5
		cooldown = 12.0
		base_damage = 26.0
		radius = 3.5
		colour = Color("#e0567a")

	func cast_effect(player_position: Vector3, _target_position: Vector3, tree: SceneTree) -> void:
		SpellEffects.pride_drain(tree, player_position, radius, base_damage)

## 4 - Wrath of Heaven: piercing beam along the aim line.
class WrathOfHeaven extends BaseSpell:
	const LENGTH := 20.0
	const WIDTH := 1.5

	func _init() -> void:
		spell_id = 4
		display_name = "Гнев Небес"
		charge_time = 1.0
		cooldown = 4.0
		base_damage = 30.0
		colour = Color("#fff8dd")

	func cast_effect(player_position: Vector3, target_position: Vector3, tree: SceneTree) -> void:
		var dir := (target_position - player_position).normalized()
		SpellEffects.beam(tree, player_position, dir, LENGTH, WIDTH, base_damage)

## 5 - Heavenly Hammer: massive damage in a circle aimed with the mouse.
class HeavenlyHammer extends BaseSpell:
	func _init() -> void:
		spell_id = 5
		display_name = "Небесный Молот"
		charge_time = 1.6
		cooldown = 8.0
		base_damage = 90.0
		radius = 4.0
		colour = Color("#ffd166")

	func cast_effect(_player_position: Vector3, target_position: Vector3, tree: SceneTree) -> void:
		SpellEffects.hammer(tree, target_position, radius, base_damage)

## 6 - Chain Lightning: auto-targets the nearest enemy and arcs to 5 more.
class ChainLightning extends BaseSpell:
	const SEARCH_RADIUS := 14.0
	const JUMP_RADIUS := 4.0
	const MAX_JUMPS := 5

	func _init() -> void:
		spell_id = 6
		display_name = "Цепная Молния"
		charge_time = 0.5
		cooldown = 2.0
		base_damage = 18.0
		colour = Color("#bde3ff")

	func cast_effect(player_position: Vector3, _target_position: Vector3, tree: SceneTree) -> void:
		SpellEffects.chain_lightning(tree, player_position, SEARCH_RADIUS, JUMP_RADIUS, MAX_JUMPS, base_damage)

## 7 - Censer of Vengeance: three censers orbit the player for 10s.
class CenserOfVengeance extends BaseSpell:
	func _init() -> void:
		spell_id = 7
		display_name = "Кадило Возмездия"
		charge_time = 1.4
		cooldown = 15.0
		base_damage = 14.0
		colour = Color("#c58bff")

	func cast_effect(_player_position: Vector3, _target_position: Vector3, tree: SceneTree) -> void:
		SpellEffects.censers(tree, 3, 10.0, base_damage)

## 8 - Holy Step: blink 8 m along the aim vector, damaging the path.
class HolyStep extends BaseSpell:
	const DISTANCE := 8.0

	func _init() -> void:
		spell_id = 8
		display_name = "Святой Шаг"
		charge_time = 0.4
		cooldown = 4.0
		base_damage = 20.0
		colour = Color("#ffe9a8")

	func cast_effect(player_position: Vector3, target_position: Vector3, tree: SceneTree) -> void:
		var dir := (target_position - player_position).normalized()
		SpellEffects.holy_step(tree, player_position, dir, DISTANCE, base_damage)

## 9 - Mirror of the Soul: reflecting dome.  Handled as an instant shield burst.
class MirrorOfSoul extends BaseSpell:
	func _init() -> void:
		spell_id = 9
		display_name = "Зеркало Души"
		charge_time = 1.0
		cooldown = 10.0
		base_damage = 8.0
		radius = 4.0
		colour = Color("#9fd8ff")

	func cast_effect(player_position: Vector3, _target_position: Vector3, tree: SceneTree) -> void:
		SpellEffects.mirror_dome(tree, player_position, radius, base_damage)

## 0 - Last Judgement: screen-wide purge, only castable at 100% soul gauge.
class LastJudgement extends BaseSpell:
	func _init() -> void:
		spell_id = 0
		display_name = "Страшный Суд"
		charge_time = 3.5
		cooldown = 0.0  # GDD: the "cooldown" is a full soul-gauge reset, done by the player.
		base_damage = 999.0
		colour = Color("#c2364a")

	func cast_effect(player_position: Vector3, _target_position: Vector3, tree: SceneTree) -> void:
		SpellEffects.last_judgement(tree, player_position)

# --- Registry ----------------------------------------------------------------

## Slot index 0..9 -> spell.  Slot 0 is key "1", slot 9 is key "0".
static func build_all() -> Array[BaseSpell]:
	var spells: Array[BaseSpell] = [
		WordOfPurification.new(),
		HolyGround.new(),
		ExpulsionOfPride.new(),
		WrathOfHeaven.new(),
		HeavenlyHammer.new(),
		ChainLightning.new(),
		CenserOfVengeance.new(),
		HolyStep.new(),
		MirrorOfSoul.new(),
		LastJudgement.new(),
	]
	# Only the first three are unlocked at the start; the rest come from cards.
	for i in spells.size():
		spells[i].is_locked = i >= 3
	return spells

## Looks a spell up by its GDD spell_id (1..9, 0).
static func find_by_id(spells: Array[BaseSpell], id: int) -> BaseSpell:
	for s in spells:
		if s.spell_id == id:
			return s
	return null
