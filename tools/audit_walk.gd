extends Node
## Walkability audit (BUGS.md #19): can a body the width of the caster reach
## every floor tile of an arena, and can it walk THROUGH every partition?
##
##   godot --headless --path . res://tools/audit_walk.tscn -- -1
##
## `-1` = every arena, n = one arena index.
##
## The level is built here with a bare `LevelBuilder`, NOT through
## `Game._build_level()`. Driving the live game means the run timer is running,
## and at 200 s / 400 s `Game._advance_floor()` rebuilds the arena underneath the
## bench -- so the map being measured halfway through is a different floor from
## the map in the printed heading, with doorways in different columns.
##
## Two earlier attempts at this check were wrong in instructive ways, so both
## warnings are recorded here rather than rediscovered later:
##
##   * A centre-to-centre ray per cell hop ALWAYS fails on a '+' doorway. That
##     cell is a slot cut in a 4 m thick wall, and the ray from the neighbouring
##     cell centre runs straight into the wall beside the slot. The first version
##     of this bench "found" 89 unreachable cells on a perfectly walkable map.
##   * A sphere probe the caster's width cannot tell "cramped" from "sealed": it
##     refuses every point under a stair ramp or a balcony, which is walkable
##     and is not a sealed room.
##
## So it drives the real capsule with the level's own pathfinder.
##
## There are two passes and they answer different questions:
##
##   PASS 1 (sweeps the floor) walks to the furthest unvisited tile. Treat it as a
##   SMOKE TEST, not as a proof: `LevelBuilder.next_path_point` is a grid search
##   that knows nothing about furniture, so a body walks into a desk and slides,
##   and a leg that misses its tile is usually "the greedy route was bad".
##
##   PASS 2 (walks every doorway) is the decisive one, because it is the player's
##   actual complaint: a body is placed in the open cell on one side of each '+'
##   opening and walks to the open cell on the other side. Short, aimed, and
##   immune to the greedy-routing noise above.
##
## The per-leg time budget is DERIVED FROM THE DISTANCE. A fixed budget is far
## too small for a 56 m arena and reports every single leg as stuck -- which is
## exactly the bug the first run of this bench appeared to have found.

const SPEED := 6.0
const BUDGET_SLACK := 2.5     ## seconds added to every sweep leg
const BUDGET_FACTOR := 1.8    ## headroom for turns and slides
const MAX_LEG_SECONDS := 14.0
const MAX_LEGS := 60
const DOORWAY_BUDGET := 12.0

func _ready() -> void:
	await get_tree().process_frame
	var only := -1
	for a in OS.get_cmdline_user_args():
		if a.is_valid_int():
			only = int(a)
	var indices: Array = range(LevelBuilder.LEVELS.size()) if only < 0 else [only]
	var sealed_any: Array = []
	for i in indices:
		var level := LevelBuilder.new()
		level.name = "Level"
		add_child(level)
		level.build(i)
		var walker := _make_walker()
		add_child(walker)
		await get_tree().physics_frame
		walker.global_position = level.player_spawn + Vector3.UP * 0.1
		walker.velocity = Vector3.ZERO
		await get_tree().physics_frame

		var seen := {level.world_to_cell(level.player_spawn): true}
		var legs := 0
		while legs < MAX_LEGS:
			var target: Variant = _furthest(level, walker.global_position, seen)
			if target == null:
				break
			var budget: float = minf(MAX_LEG_SECONDS,
				maxf(4.0, float(target.distance_to(walker.global_position)) / SPEED * BUDGET_FACTOR)
				+ BUDGET_SLACK)
			await _walk_to(level, walker, target, seen, budget)
			legs += 1
		print("%-18s sweep: tiles stood on=%d/%d in %d legs" % [LevelBuilder.LEVELS[i]["name"],
			seen.size(), _floor_tiles(level), legs])

		var sealed := await _walk_doorways(level, walker, String(LevelBuilder.LEVELS[i]["name"]))
		for s: String in sealed:
			sealed_any.append("%s %s" % [LevelBuilder.LEVELS[i]["name"], s])
		print("%-18s doorways: %s" % [LevelBuilder.LEVELS[i]["name"],
			"all pass" if sealed.is_empty() else "SEALED %s" % _list(sealed)])
		walker.queue_free()
		level.queue_free()
		await get_tree().process_frame
	print("SUMMARY sealed doorways: %s" % _list(sealed_any))
	get_tree().quit(0)

## Places the body in the open cell on one side of every '+' opening and walks it
## to the open cell on the other side. Returns the labels of the ones it could
## not cross.
func _walk_doorways(level: LevelBuilder, body: CharacterBody3D, label: String) -> Array:
	var sealed: Array = []
	var tested := 0
	for z in level.cells_z:
		for x in level.cells_x:
			if level.glyph_at(x, z) != "+":
				continue
			# The opening splits the cell along X, so the two rooms are on +/-X.
			var here: Variant = _open_cell(level, x - 1, z)
			var there: Variant = _open_cell(level, x + 1, z)
			if here == null or there == null:
				continue
			tested += 1
			body.global_position = (here as Vector3) + Vector3.UP * 0.1
			body.velocity = Vector3.ZERO
			await get_tree().physics_frame
			var seen := {}
			var ok := await _walk_to(level, body, there as Vector3, seen, DOORWAY_BUDGET)
			print("  %s %s%d: %s" % [label, String.chr(65 + x), z + 1,
				"walked through" if ok else "SEALED (ended at %s)" % str(level.world_to_cell(body.global_position))])
			if not ok:
				sealed.append("%s%d" % [String.chr(65 + x), z + 1])
	if tested > 0:
		print("  %s: %d doorway(s) marked '+'" % [label, tested])
	return sealed

## A bare CharacterBody3D with the caster's capsule and collision mask.
func _make_walker() -> CharacterBody3D:
	var body := CharacterBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 21
	var shape := CapsuleShape3D.new()
	shape.radius = 0.4
	shape.height = 1.8
	var node := CollisionShape3D.new()
	node.shape = shape
	node.position = Vector3(0.0, 0.9, 0.0)
	body.add_child(node)
	return body

## Walks toward `target` with the level's own pathfinder, recording every tile it
## touches. False when it did not arrive inside the time budget.
func _walk_to(level: LevelBuilder, body: CharacterBody3D, target: Vector3, seen: Dictionary, budget: float) -> bool:
	var clock := 0.0
	while clock < budget:
		var to: Vector3 = target - body.global_position
		to.y = 0.0
		if to.length() < 1.8:
			return true
		var step: Vector3 = level.next_path_point(body.global_position, target) - body.global_position
		step.y = 0.0
		if step.length() < 0.05:
			step = to
		step = step.normalized()
		body.velocity.x = step.x * SPEED
		body.velocity.z = step.z * SPEED
		body.velocity.y -= 9.8 * get_physics_process_delta_time()
		body.move_and_slide()
		seen[level.world_to_cell(body.global_position)] = true
		await get_tree().physics_frame
		clock += get_physics_process_delta_time()
	return false

## The unvisited floor tile furthest from the body.
func _furthest(level: LevelBuilder, from: Vector3, seen: Dictionary) -> Variant:
	var best: Variant = null
	var best_d := -1.0
	for z in level.cells_z:
		for x in level.cells_x:
			var cell := Vector2i(x, z)
			if seen.has(cell):
				continue
			if not _is_floor(level.glyph_at(x, z)):
				continue
			var centre: Vector3 = level.cell_centre(x, z)
			var d: float = centre.distance_to(from)
			if d > best_d:
				best_d = d
				best = centre
	return best

## Centre of the open floor cell at (x, z), or null when there is none.
func _open_cell(level: LevelBuilder, x: int, z: int) -> Variant:
	if x < 0 or z < 0 or x >= level.cells_x or z >= level.cells_z:
		return null
	if not _is_floor(level.glyph_at(x, z)):
		return null
	return level.cell_centre(x, z)

func _is_floor(g: String) -> bool:
	return g == "." or g == "S" or g == "n"

func _floor_tiles(level: LevelBuilder) -> int:
	var n := 0
	for z in level.cells_z:
		for x in level.cells_x:
			if _is_floor(level.glyph_at(x, z)):
				n += 1
	return n

func _list(items: Array) -> String:
	if items.is_empty():
		return "(none)"
	var head: Array = items.slice(0, 18)
	return "%d [%s]%s" % [items.size(), String(", ").join(head),
		" ..." if items.size() > 18 else ""]