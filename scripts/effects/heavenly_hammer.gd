class_name HeavenlyHammerFX
## Spell 5 - Heavenly Hammer (3D / first-person port).
## Colossal damage in a circle aimed with the mouse; also smashes portals.
##
## The one spell with a cause and an effect, so it is the one drawn in two
## beats: a column of light dropping out of the sky, and then the floor
## answering -- a flash, a wave, a ring of debris and dust. A single disc where
## the hammer lands says nothing about WHY anything happened.
extends EffectBase

## Knockback impulse in metres/second.
const KNOCKBACK := 5.2
## How high up the strike comes from.
const SKY_HEIGHT := 9.0

func setup(target: Vector3, radius: float, damage: float) -> void:
	global_position = target
	var colour := Color("#ffd166")
	SpellVfx.light_column(self, target + Vector3(0.0, SKY_HEIGHT, 0.0),
		target, radius * 0.4, colour, 0.26)
	for e in EffectUtil.enemies_in_radius(get_tree(), target, radius):
		EffectUtil.damage(e, damage, target)
		EffectUtil.knockback(e, target, KNOCKBACK)
	SpellVfx.burst(self, target + Vector3(0.0, 0.5, 0.0), radius * 1.2,
		Color.WHITE, 0.3)
	SpellVfx.shockwave(self, target, radius, colour, 0.5)
	# A hammer hitting concrete throws dust, not light rays. The radial spikes
	# are the vocabulary of things that blast; this one hits a single point.
	for i in 8:
		var angle := TAU * float(i) / 8.0
		var at := target + Vector3(cos(angle), 0.1, sin(angle)) * radius * 0.7
		SpellVfx.puff(self, at, Color("#b8ac97"), 0.7, 1.5,
			Vector3(cos(angle) * 0.6, 1.0, sin(angle) * 0.6))
	# Real physics chunks: a hammer that only glows does not weigh anything.
	EffectUtil.spawn_debris(get_tree(), target + Vector3.UP * 0.3, 7,
		Color("#8b7f6a"), 5.5)
	SpellVfx.motes(self, target, 14, Color("#c9bda6"), radius * 0.8, 2.0, 1.2, 0.3,
		TextureLibrary.puff())
	self_destruct(0.55)
