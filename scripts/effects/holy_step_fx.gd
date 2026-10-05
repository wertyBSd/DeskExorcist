class_name HolyStepFX
## Spell 8 - Holy Step (3D / first-person port).
## Blinks the caster forward along the aim vector, burning everything on the path.
extends EffectBase

## Half-width of the damaging corridor swept by the blink, in metres.
const PATH_HALF_WIDTH := 0.7

func setup(origin: Vector3, dir: Vector3, distance: float, damage: float) -> void:
	global_position = origin
	var aim := dir.normalized()
	if aim == Vector3.ZERO:
		aim = Vector3.FORWARD
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
	if player != null and player.has_method("blink_to"):
		player.call("blink_to", destination)
	var bar := add_bar(origin, destination, 0.4, Color(1.0, 0.93, 0.7, 0.75))
	fade_bar(bar, 0.22)
	self_destruct(0.3)
