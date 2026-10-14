class_name HolyStepFX
## Spell 8 - Holy Step (3D / first-person port).
## Blinks the caster forward along the aim vector, burning everything on the path.
##
## A blink is two events, so it is drawn as two events: the caster's outline
## collapsing where they were, and the same flash opening where they arrive,
## with the path between them drawn as a tapered streak. One bar between two
## points said "these two places are connected"; it did not say the caster is
## now at the far end.
extends EffectBase

## Half-width of the damaging corridor swept by the blink, in metres.
const PATH_HALF_WIDTH := 0.7
## Height of the caster's chest, where the marks land.
const CORE_HEIGHT := 1.1

func setup(origin: Vector3, dir: Vector3, distance: float, damage: float) -> void:
	global_position = origin
	var aim := dir.normalized()
	if aim == Vector3.ZERO:
		aim = Vector3.FORWARD
	var colour := Color(1.0, 0.93, 0.7)
	var player := EffectUtil.player(get_tree())
	var destination := origin + aim * distance
	# A wall stops the blink (GDD spell 8): ask the caster to clip the target so
	# it never teleports through geometry, then sweep only the real path.
	if player != null and player.has_method("blink_target"):
		destination = player.call("blink_target", aim, distance)
	var travelled := (destination - origin).length()
	for e in EffectUtil.enemies(get_tree()):
		if not (e is Node3D):
			continue
		var rel: Vector3 = (e as Node3D).global_position - origin
		var along := rel.dot(aim)
		if along < 0.0 or along > travelled:
			continue
		if (rel - aim * along).length() <= PATH_HALF_WIDTH:
			EffectUtil.damage(e, damage, origin)
	# Departure is drawn before the blink, so the flash is still at the old spot
	# when the caster moves.
	SpellVfx.burst(self, origin + Vector3(0.0, CORE_HEIGHT, 0.0), 1.3, colour, 0.3)
	if player != null and player.has_method("blink_to"):
		player.call("blink_to", destination)
	SpellVfx.streak(self, origin + Vector3(0.0, CORE_HEIGHT, 0.0),
		destination + Vector3(0.0, CORE_HEIGHT, 0.0), 0.55, colour, 0.25)
	SpellVfx.burst(self, destination + Vector3(0.0, CORE_HEIGHT, 0.0), 1.5,
		Color.WHITE, 0.26)
	SpellVfx.shockwave(self, destination, 1.5, colour, 0.4)
	self_destruct(0.45)
