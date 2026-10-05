class_name ChainLightningFX
## Spell 6 - Chain Lightning (3D / first-person port).
## Strikes the nearest enemy, then arcs to up to `max_jumps` neighbours.
extends EffectBase

## Thickness of the lightning bar in metres.
const BAR_WIDTH := 0.12

func setup(origin: Vector3, search: float, jump: float, max_jumps: int, damage: float) -> void:
	global_position = origin
	var hit: Array = []
	var from := origin
	var cursor := EffectUtil.nearest_enemy(get_tree(), origin, search)
	var jumps := 0
	while cursor != null and jumps <= max_jumps:
		EffectUtil.damage(cursor, damage, from)
		hit.append(cursor)
		var bar := add_bar(from, cursor.global_position, BAR_WIDTH, Color("#bde3ff"))
		fade_bar(bar, 0.25)
		from = cursor.global_position
		cursor = _next_hop(from, jump, hit)
		jumps += 1
	self_destruct(0.3)

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
