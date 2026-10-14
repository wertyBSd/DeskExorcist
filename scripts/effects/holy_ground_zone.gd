class_name HolyGroundZone
## Spell 2 - Holy Ground (3D / first-person port).
## Static zone that slows enemies by 70% and ticks damage for its lifetime.
##
## The only spell in the game that OUTLASTS its cast, so it is the only one
## drawn as something standing rather than something happening: a rune circle
## turning slowly on the floor, with light welling up out of it the whole time
## it is working. A flat disc, which is what this was, reads as a highlight and
## then as nothing.
extends EffectBase

const TICK := 0.5
## How often light wells up out of the circle.
const MOTE_INTERVAL := 0.28

var radius := 4.0
var damage := 6.0
var remaining := 5.0
var _tick := 0.0
var _mote := 0.0
var _runes: Node3D = null
var _colour := Color("#fff2b0")
var _spin := 0.0

func setup(origin: Vector3, zone_radius: float, tick_damage: float, duration: float) -> void:
	global_position = origin
	radius = zone_radius
	damage = tick_damage
	remaining = duration
	_runes = SpellVfx.rune_circle(self, origin, radius, _colour)
	SpellVfx.motes(self, origin, 10, _colour, radius * 0.8, 1.2, 1.0, 0.16)

func _process(delta: float) -> void:
	remaining -= delta
	_spin += delta * 0.35
	if _runes != null and is_instance_valid(_runes):
		# Two rings counter-turning. A circle that does not move is a decal; this
		# is what tells the player the ground is still doing something.
		_runes.rotate_y(_spin * (1.0 if _spin > 0.0 else -1.0))
	_mote -= delta
	if _mote <= 0.0:
		_mote = MOTE_INTERVAL
		SpellVfx.motes(self, global_position, 2, _colour, radius * 0.85, 0.9, 1.1, 0.13)
	_tick -= delta
	if _tick <= 0.0:
		_tick = TICK
		for e in EffectUtil.enemies_in_radius(get_tree(), global_position, radius):
			EffectUtil.damage(e, damage, global_position)
			EffectUtil.slow(e, 0.7, TICK + 0.15)
	if remaining <= 0.0:
		queue_free()
