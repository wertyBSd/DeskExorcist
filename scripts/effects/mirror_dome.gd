class_name MirrorDome
## Spell 9 - Mirror of the Soul (3D / first-person port).
## A reflective dome: it scorches everything around the caster and raises a
## short shield that turns incoming damage away.
extends EffectBase

const SHIELD_TIME := 2.0

func setup(origin: Vector3, radius: float, damage: float) -> void:
	global_position = origin
	for e in EffectUtil.enemies_in_radius(get_tree(), origin, radius):
		EffectUtil.damage(e, damage, origin)
	var player := EffectUtil.player(get_tree())
	if player != null and player.has_method("grant_shield"):
		player.call("grant_shield", SHIELD_TIME)
	add_aura(origin, radius, Color("#9fd8ff"))
	pop_ring(origin, radius, Color("#cfefff"), 0.45)
	self_destruct(0.55)
