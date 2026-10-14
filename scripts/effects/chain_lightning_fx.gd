class_name ChainLightningFX
## Spell 6 - Chain Lightning (3D / first-person port).
## Strikes the nearest enemy, then arcs to up to `max_jumps` neighbours.
##
## The shape has no competition: a jagged arc is the only thing on screen that
## can only mean lightning. It used to be a straight glowing bar, which is a
## beam -- and spell 4 is already a beam.
extends EffectBase

## Thickness of the arc in metres.
const BAR_WIDTH := 0.18

func setup(origin: Vector3, search: float, jump: float, max_jumps: int, damage: float) -> void:
	global_position = origin
	var colour := Color("#bde3ff")
	var hit: Array = []
	var from := origin + Vector3(0.0, 1.2, 0.0)
	var cursor := EffectUtil.nearest_enemy(get_tree(), origin, search)
	var jumps := 0
	while cursor != null and jumps <= max_jumps:
		EffectUtil.damage(cursor, damage, from)
		hit.append(cursor)
		var to: Vector3 = cursor.global_position + Vector3.UP * 0.8
		SpellVfx.bolt(self, from, to, colour, 0.3, BAR_WIDTH, 0.55)
		# A flash where it lands: the arc alone is a line, and a line does not
		# say WHICH of the demons in the room just took the hit.
		SpellVfx.burst(self, to, 1.5, colour, 0.26)
		SpellVfx.motes(self, to, 3, colour, 0.4, 0.8, 0.5, 0.14)
		from = to
		cursor = _next_hop(from, jump, hit)
		jumps += 1
	self_destruct(0.35)

func _next_hop(from: Vector3, jump: float, hit: Array) -> Node3D:
	var best: Node3D = null
	var best_d := jump
	for e in EffectUtil.enemies(get_tree()):
		if not (e is Node3D) or hit.has(e):
			continue
		var d: float = (e as Node3D).global_position.distance_to(from)
		if d <= best_d:
			best_d = d
			best = e
	return best
