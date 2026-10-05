class_name HolyGroundZone
## Spell 2 - Holy Ground (3D / first-person port).
## Static zone that slows enemies by 70% and ticks damage for its lifetime.
extends EffectBase

const TICK := 0.5

var radius := 4.0
var damage := 6.0
var remaining := 5.0
var _tick := 0.0

func setup(origin: Vector3, zone_radius: float, tick_damage: float, duration: float) -> void:
	global_position = origin
	radius = zone_radius
	damage = tick_damage
	remaining = duration
	add_aura(origin, radius, Color("#fff2b0"))

func _process(delta: float) -> void:
	remaining -= delta
	_tick -= delta
	if _tick <= 0.0:
		_tick = TICK
		for e in EffectUtil.enemies_in_radius(get_tree(), global_position, radius):
			EffectUtil.damage(e, damage, global_position)
			EffectUtil.slow(e, 0.7, TICK + 0.15)
	if remaining <= 0.0:
		queue_free()
