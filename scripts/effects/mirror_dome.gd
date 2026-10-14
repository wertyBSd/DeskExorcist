class_name MirrorDome
## Spell 9 - Mirror of the Soul (3D / first-person port).
## A reflective dome: it scorches everything around the caster and raises a
## short shield that turns incoming damage away.
##
## Drawn as the dome it is. The shield is the whole point of the spell, and it
## was previously a flat disc on the floor -- which is exactly what spell 2 and
## spell 5 already looked like, and says nothing about being enclosed.
extends EffectBase

const SHIELD_TIME := 2.0

func setup(origin: Vector3, radius: float, damage: float) -> void:
	global_position = origin
	var colour := Color("#9fd8ff")
	for e in EffectUtil.enemies_in_radius(get_tree(), origin, radius):
		EffectUtil.damage(e, damage, origin)
	var player := EffectUtil.player(get_tree())
	if player != null and player.has_method("grant_shield"):
		player.call("grant_shield", SHIELD_TIME)
	SpellVfx.dome(self, origin, radius, colour, 0.7)
	SpellVfx.shockwave(self, origin, radius, Color("#cfefff"), 0.5)
	# The bright cap is what makes it read as a dome rather than as a ring seen
	# edge-on: the eye needs somewhere for the shape to close.
	SpellVfx.burst(self, origin + Vector3(0.0, radius * 0.92, 0.0), radius * 0.7,
		Color("#dff2ff"), 0.4)
	SpellVfx.motes(self, origin, 10, colour, radius * 0.8, 1.8, 1.0, 0.14)
	self_destruct(0.75)
