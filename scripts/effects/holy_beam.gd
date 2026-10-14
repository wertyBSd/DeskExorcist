class_name HolyBeam
## Spell 4 - Wrath of Heaven (3D / first-person port).
## A piercing laser: every enemy whose centre lies within the beam is scorched,
## so the ray burns straight through a whole column of demons.
##
## A beam is not a box with a glow on it. This is a hot white core inside a
## wider sheath, flaring at both ends and throwing sparks along its length --
## the shape says "this line is the damage" from any angle, which a uniform bar
## never did.
extends EffectBase

## Extra slack so an enemy whose centre is just off the line still gets clipped.
const HIT_PADDING := 0.25

func setup(origin: Vector3, dir: Vector3, length: float, width: float, damage: float) -> void:
	global_position = origin
	var aim := dir.normalized()
	if aim == Vector3.ZERO:
		aim = Vector3.FORWARD
	var half := width * 0.5
	for e in EffectUtil.enemies(get_tree()):
		if not (e is Node3D):
			continue
		var rel: Vector3 = (e as Node3D).global_position - origin
		var along := rel.dot(aim)
		if along < 0.0 or along > length:
			continue
		if (rel - aim * along).length() <= half + HIT_PADDING:
			EffectUtil.damage(e, damage, origin)
	var colour := Color(1.0, 0.97, 0.86)
	var tip := origin + aim * length
	# Sheath first, core over it: the core is what makes the middle read hot.
	SpellVfx.streak(self, origin, tip, width * 0.5, colour, 0.3)
	SpellVfx.streak(self, origin + aim * 0.4, tip - aim * 0.4, width * 0.22,
		Color.WHITE, 0.26)
	SpellVfx.burst(self, tip, width * 2.6, colour, 0.26)
	SpellVfx.burst(self, origin + aim * 0.6, width * 1.5, colour, 0.2)
	for i in 5:
		var at := origin.lerp(tip, 0.15 + 0.18 * float(i))
		SpellVfx.motes(self, at, 2, colour, 0.25, 0.5, 0.5, 0.16)
	self_destruct(0.35)
