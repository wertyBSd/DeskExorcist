class_name SpellEffects
## Creates the effect node for every spell (GDD section 3).
##
## Effects are plain code classes extending EffectBase, so no .tscn assets are
## required; SpellEffects just instantiates the right class, adds it to the
## running scene and calls setup().

extends RefCounted

static func _add(tree: SceneTree, fx: EffectBase) -> EffectBase:
	var host := tree.current_scene
	if host != null:
		host.add_child(fx)
	return fx

## 1 - Word of Purification.
static func purifying_wave(tree: SceneTree, origin: Vector3, radius: float, damage: float, colour: Color) -> void:
	var fx := PurifyingWave.new()
	_add(tree, fx)
	fx.setup(origin, radius, damage, colour)

## 2 - Holy Ground.
static func holy_ground(tree: SceneTree, origin: Vector3, radius: float, damage: float, duration: float) -> void:
	var fx := HolyGroundZone.new()
	_add(tree, fx)
	fx.setup(origin, radius, damage, duration)

## 3 - Expulsion of Pride.
static func pride_drain(tree: SceneTree, origin: Vector3, radius: float, damage: float) -> void:
	var fx := PrideDrain.new()
	_add(tree, fx)
	fx.setup(origin, radius, damage)

## 4 - Wrath of Heaven.
static func beam(tree: SceneTree, origin: Vector3, dir: Vector3, length: float, width: float, damage: float) -> void:
	var fx := HolyBeam.new()
	_add(tree, fx)
	fx.setup(origin, dir, length, width, damage)

## 5 - Heavenly Hammer.
static func hammer(tree: SceneTree, target: Vector3, radius: float, damage: float) -> void:
	var fx := HeavenlyHammerFX.new()
	_add(tree, fx)
	fx.setup(target, radius, damage)

## 6 - Chain Lightning.
static func chain_lightning(tree: SceneTree, origin: Vector3, search: float, jump: float, max_jumps: int, damage: float) -> void:
	var fx := ChainLightningFX.new()
	_add(tree, fx)
	fx.setup(origin, search, jump, max_jumps, damage)

## 7 - Censer of Vengeance.
static func censers(tree: SceneTree, count: int, duration: float, damage: float) -> void:
	var fx := CenserSwarm.new()
	_add(tree, fx)
	fx.setup(count, duration, damage)

## 8 - Holy Step.
static func holy_step(tree: SceneTree, origin: Vector3, dir: Vector3, distance: float, damage: float) -> void:
	var fx := HolyStepFX.new()
	_add(tree, fx)
	fx.setup(origin, dir, distance, damage)

## 9 - Mirror of the Soul.
static func mirror_dome(tree: SceneTree, origin: Vector3, radius: float, damage: float) -> void:
	var fx := MirrorDome.new()
	_add(tree, fx)
	fx.setup(origin, radius, damage)

## 0 - Last Judgement.
static func last_judgement(tree: SceneTree, origin: Vector3) -> void:
	var fx := LastJudgementFX.new()
	_add(tree, fx)
	fx.setup(origin)
