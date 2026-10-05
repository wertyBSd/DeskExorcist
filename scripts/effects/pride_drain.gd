class_name PrideDrain
## Spell 3 - Expulsion of Pride (3D / first-person port).
## Siphons HP from everything in range and heals the caster for 5% of the total.
extends EffectBase

## GDD section 3: vampirism returns 5% of the damage dealt.
const LIFESTEAL := 0.05

func setup(origin: Vector3, radius: float, damage: float) -> void:
	global_position = origin
	var total := 0.0
	for e in EffectUtil.enemies_in_radius(get_tree(), origin, radius):
		EffectUtil.damage(e, damage, origin)
		total += damage
	EffectUtil.heal_player(get_tree(), total * LIFESTEAL)
	pop_ring(origin, radius, Color("#e0567a"), 0.4)
	self_destruct(0.45)
