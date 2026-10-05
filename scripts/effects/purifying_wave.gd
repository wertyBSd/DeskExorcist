class_name PurifyingWave
## Spell 1 - Word of Purification.
## Small AoE around the caster that damages and knocks enemies away.
extends EffectBase

## Knockback impulse in metres/second.
const KNOCKBACK := 6.4

func setup(origin: Vector3, radius: float, damage: float, colour: Color) -> void:
	global_position = origin
	for e in EffectUtil.enemies_in_radius(get_tree(), origin, radius):
		EffectUtil.damage(e, damage, origin)
		EffectUtil.knockback(e, origin, KNOCKBACK)
	pop_ring(origin, radius, colour, 0.4)
	self_destruct(0.45)
