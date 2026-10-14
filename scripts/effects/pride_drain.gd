class_name PrideDrain
## Spell 3 - Expulsion of Pride (3D / first-person port).
## Siphons HP from everything in range and heals the caster for 5% of the total.
##
## The only spell that takes instead of deals, so it is drawn as something being
## PULLED: a crimson thread out of every victim into the caster's hands, a ring
## that collapses instead of expanding, and the light sinking rather than
## rising. Pride draining looks exactly like a blast if you draw it like one,
## and the player will take it as damage instead of a heal.
extends EffectBase

## GDD section 3: vampirism returns 5% of the damage dealt.
const LIFESTEAL := 0.05
## Where the threads land: roughly the caster's cupped hands.
const CORE_HEIGHT := 1.1

func setup(origin: Vector3, radius: float, damage: float) -> void:
	global_position = origin
	var colour := Color("#e0567a")
	var core := origin + Vector3(0.0, CORE_HEIGHT, 0.0)
	var total := 0.0
	for e in EffectUtil.enemies_in_radius(get_tree(), origin, radius):
		EffectUtil.damage(e, damage, origin)
		total += damage
		if e is Node3D:
			SpellVfx.bolt(self, (e as Node3D).global_position + Vector3.UP * 0.8,
				core, colour, 0.4, 0.10, 0.3)
	EffectUtil.heal_player(get_tree(), total * LIFESTEAL)
	SpellVfx.implode(self, origin, radius, colour, 0.45)
	# Rising sparks read as "released"; these sink into the caster instead.
	SpellVfx.motes(self, origin, 12, colour, radius * 0.7, -1.4, 0.8, 0.14)
	SpellVfx.burst(self, core, 1.8, colour, 0.35)
	self_destruct(0.5)
