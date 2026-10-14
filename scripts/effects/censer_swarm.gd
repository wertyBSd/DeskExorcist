class_name CenserSwarm
## Spell 7 - Censer of Vengeance (3D / first-person port).
## Summons orbiting censers that follow the player and burn anything they touch.
extends EffectBase

const ORBIT_RADIUS := 1.9
const ORBIT_HEIGHT := 1.1
const SPIN_SPEED := 3.2
const HIT_RADIUS := 0.55
const TICK := 0.3
## How often a censer breathes out. Three of them at this rate is about a dozen
## puffs alive at once, which is the point: the trail is the effect.
const SMOKE_INTERVAL := 0.16

var damage := 14.0
var remaining := 10.0

var _angle := 0.0
var _tick := 0.0
var _smoke := 0.0
var _player: Node3D = null
var _censers: Array[Sprite3D] = []

func setup(count: int, duration: float, hit_damage: float) -> void:
	damage = hit_damage
	remaining = duration
	for i in maxi(1, count):
		var censer := add_sprite(PlaceholderArt.censer())
		censer.set_meta(SpellVfx.TAG, "censer")
		_censers.append(censer)

func _process(delta: float) -> void:
	remaining -= delta
	_angle += SPIN_SPEED * delta
	if _player == null or not is_instance_valid(_player):
		_player = EffectUtil.player(get_tree())
	if _player != null:
		global_position = _player.global_position
	var step := TAU / float(maxi(1, _censers.size()))
	for i in _censers.size():
		var a := _angle + step * float(i)
		_censers[i].position = Vector3(cos(a), ORBIT_HEIGHT, sin(a)) * ORBIT_RADIUS
	# Smoke. A censer is the one prop in this office that is supposed to be
	# smoking, and three metal balls orbiting on their own read as jewellery.
	_smoke -= delta
	if _smoke <= 0.0:
		_smoke = SMOKE_INTERVAL
		for censer in _censers:
			SpellVfx.puff(self, censer.global_position + Vector3.UP * 0.25,
				Color("#6b5f7d"), 0.34, 1.4)
	_tick -= delta
	if _tick <= 0.0:
		_tick = TICK
		for censer in _censers:
			var world := censer.global_position
			for e in EffectUtil.enemies_in_radius(get_tree(), world, HIT_RADIUS):
				EffectUtil.damage(e, damage, world)
	if remaining <= 0.0:
		queue_free()
