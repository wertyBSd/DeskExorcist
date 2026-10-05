class_name LastJudgementFX
## Spell 0 - Last Judgement (3D / first-person port).
## Screen-wide purge.  It erases every lesser demon outright and wounds the
## tanky water-cooler demons heavily.
extends EffectBase

const TANKY_DAMAGE := 70.0

func setup(origin: Vector3) -> void:
	global_position = origin
	var centre := origin
	var player := EffectUtil.player(get_tree())
	if player != null:
		centre = player.global_position
	for e in EffectUtil.enemies(get_tree()):
		if not (e is Node3D):
			continue
		if e is Enemy and (e as Enemy).kind == Enemy.Kind.WATER_COOLER:
			EffectUtil.damage(e, TANKY_DAMAGE, centre)
		else:
			EffectUtil.damage(e, 99999.0, centre)
	var flash := add_aura(centre, 8.4, Color("#ffd0d6"))
	var tween := create_tween()
	tween.tween_property(flash, "modulate:a", 0.0, 0.6)
	self_destruct(0.7)
