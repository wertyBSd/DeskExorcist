class_name PurifyingWave
## Spell 1 - Word of Purification.
## Small AoE around the caster that damages and knocks enemies away.
##
## The blast, not a ring: a flash at the caster, a fringe of spikes thrown out
## across the floor, and the wave itself. A single expanding circle was the
## same picture as Holy Ground and the Mirror, which are all "a radius lights
## up", and only the damage told them apart.
extends EffectBase

## Knockback impulse in metres/second.
const KNOCKBACK := 6.4
## Height above the caster's feet the flash and the wave are centred on.
const CORE_HEIGHT := 0.9

func setup(origin: Vector3, radius: float, damage: float, colour: Color) -> void:
	global_position = origin
	for e in EffectUtil.enemies_in_radius(get_tree(), origin, radius):
		EffectUtil.damage(e, damage, origin)
		EffectUtil.knockback(e, origin, KNOCKBACK)
	SpellVfx.burst(self, origin + Vector3(0.0, CORE_HEIGHT, 0.0), 2.4, colour, 0.3)
	SpellVfx.spikes(self, origin, 14, radius, colour, 0.45)
	SpellVfx.shockwave(self, origin, radius, colour, 0.45)
	SpellVfx.motes(self, origin, 8, colour, radius * 0.6, 1.4, 0.8, 0.14)
	self_destruct(0.5)
