class_name HolyBeam
## Spell 4 - Wrath of Heaven (3D / first-person port).
## A piercing laser: every enemy whose centre lies within the beam is scorched,
## so the ray burns straight through a whole column of demons.
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
	var bar := add_bar(origin, origin + aim * length, width, Color(1.0, 0.97, 0.86, 0.8))
	fade_bar(bar, 0.3)
	self_destruct(0.35)
