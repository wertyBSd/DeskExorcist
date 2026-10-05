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
