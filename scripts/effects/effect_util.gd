class_name EffectUtil
## Shared helpers for every spell effect: target lookup and damage delivery.
##
## Effects live on the current scene tree and query the "enemies" group, which
## both Enemy and SpawnerPortal join, so a spell sweeps demons and portals alike.
## 3D (FPS): all distances are measured in world space on Node3D nodes.

extends RefCounted

## All live enemies in the tree.
static func enemies(tree: SceneTree) -> Array:
	return tree.get_nodes_in_group("enemies")

## Enemies whose centre is inside `radius` of `centre`.
static func enemies_in_radius(tree: SceneTree, centre: Vector3, radius: float) -> Array:
	var out: Array = []
	for e in enemies(tree):
		if e is Node3D and (e as Node3D).global_position.distance_to(centre) <= radius:
			out.append(e)
	return out

## Nearest enemy within `radius`, or null.
static func nearest_enemy(tree: SceneTree, centre: Vector3, radius: float) -> Node3D:
	var best: Node3D = null
	var best_d := radius
	for e in enemies(tree):
		if not (e is Node3D):
			continue
		var d: float = (e as Node3D).global_position.distance_to(centre)
		if d <= best_d:
			best_d = d
			best = e
	return best

## Applies damage to a single enemy if it exposes take_damage().
static func damage(node: Node, amount: float, source_position: Vector3 = Vector3.INF) -> void:
	if node != null and node.has_method("take_damage"):
		node.call("take_damage", amount, source_position)

## Knocks an enemy back along the direction away from `from`.
static func knockback(node: Node, from: Vector3, force: float) -> void:
	if node != null and node.has_method("apply_knockback"):
		node.call("apply_knockback", from, force)

## Applies a slow to an enemy if it supports one (Holy Ground).
static func slow(node: Node, ratio: float, duration: float) -> void:
	if node != null and node.has_method("apply_slow"):
		node.call("apply_slow", ratio, duration)

## Heals the player, used by Pride's lifesteal.
static func heal_player(tree: SceneTree, amount: float) -> void:
	for p in tree.get_nodes_in_group("player"):
		if p.has_method("heal"):
			p.call("heal", amount)

## The live player node, or null.
static func player(tree: SceneTree) -> Node3D:
	var list := tree.get_nodes_in_group("player")
	return list[0] if not list.is_empty() else null

## Flings a burst of physics debris from a demon death or an explosion
## (ROADMAP Stage 3: physics-razlyot musora).  Each chunk is a RigidBody3D that
## tumbles and bounces off the level before fading out.  No-op off-tree.
static func spawn_debris(tree: SceneTree, centre: Vector3, count: int, colour: Color, speed: float = 4.0) -> void:
	var host := tree.current_scene
	if host == null:
		return
	for _i in count:
		var chunk := DebrisChunk.new()
		host.add_child(chunk)
		chunk.global_position = centre + Vector3(randf_range(-0.3, 0.3), randf_range(0.2, 0.8), randf_range(-0.3, 0.3))
		var dir := Vector3(randf_range(-1.0, 1.0), randf_range(0.3, 1.0), randf_range(-1.0, 1.0))
		chunk.launch(dir, speed * randf_range(0.6, 1.4), colour)

## Asks the HUD to flash its hit marker (ROADMAP Stage 3 VFX: hitmarkers).
static func hitmarker(tree: SceneTree) -> void:
	for h in tree.get_nodes_in_group("hud"):
		if h.has_method("flash_hitmarker"):
			h.call("flash_hitmarker")

## Plays a one-shot cue through the SoundManager autoload.  Null-safe: isolated
## test scenes and the headless suite run without the autoload present.
static func sound(tree: SceneTree, key: StringName, position: Vector3 = Vector3.INF) -> void:
	var sm := _sound_manager(tree)
	if sm != null and sm.has_method("play"):
		sm.call("play", key, position)

## Starts or switches the looping music track through the SoundManager autoload.
static func music(tree: SceneTree, key: StringName) -> void:
	var sm := _sound_manager(tree)
	if sm != null and sm.has_method("play_music"):
		sm.call("play_music", key)

## Plays the cast cue for a GDD spell id (1..9, 0).  No-op when that spell has no
## dedicated file yet, so callers never have to check.
static func spell_cast(tree: SceneTree, spell_id: int, position: Vector3 = Vector3.INF) -> void:
	var sm := _sound_manager(tree)
	if sm == null or not sm.has_method("spell_cast_key"):
		return
	var key: StringName = sm.call("spell_cast_key", spell_id)
	if key != &"" and sm.has_method("play"):
		sm.call("play", key, position)

## The SoundManager autoload node, or null when it is not registered.
static func _sound_manager(tree: SceneTree) -> Node:
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null("SoundManager")
