class_name LastJudgementFX
## Spell 0 - Last Judgement (3D / first-person port).
## Screen-wide purge.  It erases every lesser demon outright and wounds the
## tanky water-cooler demons heavily.
##
## The biggest thing in the game, so it is the only effect that uses the whole
## screen twice: a column of light coming down onto the caster, and a wave going
## out from them far enough to cross the arena. It used to be one pale disc.
extends EffectBase

const TANKY_DAMAGE := 70.0
## How high the column starts.
const SKY_HEIGHT := 18.0
## How far the wave reaches, in metres. Wider than the biggest arena.
const WAVE_RADIUS := 16.0

func setup(origin: Vector3) -> void:
	global_position = origin
	var colour := Color("#c2364a")
	var centre := origin
	var player := EffectUtil.player(get_tree())
	if player != null:
		centre = player.global_position
	for e in EffectUtil.enemies(get_tree()):
		if not (e is Node3D):
			continue
		# The boss and other tanks take heavy damage but are not erased.
		if _is_tanky(e):
			EffectUtil.damage(e, TANKY_DAMAGE, centre)
		else:
			EffectUtil.damage(e, 99999.0, centre)
	SpellVfx.light_column(self, centre + Vector3(0.0, SKY_HEIGHT, 0.0), centre,
		3.2, colour, 0.85)
	SpellVfx.shockwave(self, centre, WAVE_RADIUS, Color("#ffd0d6"), 0.95)
	SpellVfx.spikes(self, centre, 16, WAVE_RADIUS * 0.8, colour, 0.8)
	# Not a second hammer: the sky cracks open over the caster and the crack runs
	# out to the horizon. The hammer throws dust at one spot, so only one of the
	# two spells owns the column-of-light silhouette.
	for i in 8:
		var angle := TAU * float(i) / 8.0
		SpellVfx.bolt(self, centre + Vector3(0.0, 1.4, 0.0),
			centre + Vector3(cos(angle), 0.15, sin(angle)) * WAVE_RADIUS * 0.7,
			colour, 0.6, 0.30, 0.9)
	SpellVfx.burst(self, centre + Vector3(0.0, 1.2, 0.0), 7.0, Color.WHITE, 0.5)
	SpellVfx.motes(self, centre, 22, colour, 6.0, 6.0, 1.6, 0.26)
	self_destruct(1.0)

## True for enemies the ultimate should wound rather than erase (water coolers
## and the boss).
func _is_tanky(e: Node) -> bool:
	if e.has_method("is_boss") and e.call("is_boss"):
		return true
	return e is Enemy and (e as Enemy).kind == Enemy.Kind.WATER_COOLER
