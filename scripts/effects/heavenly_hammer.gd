class_name HeavenlyHammerFX
## Spell 5 - Heavenly Hammer (3D / first-person port).
## Colossal damage in a circle aimed with the mouse; also smashes portals.
extends EffectBase

## Knockback impulse in metres/second.
const KNOCKBACK := 5.2

func setup(target: Vector3, radius: float, damage: float) -> void:
	global_position = target
	add_aura(target, radius, Color("#ffd166"))
	for e in EffectUtil.enemies_in_radius(get_tree(), target, radius):
		EffectUtil.damage(e, damage, target)
		EffectUtil.knockback(e, target, KNOCKBACK)
	pop_ring(target, radius, Color("#fff3c4"), 0.45)
	self_destruct(0.5)
