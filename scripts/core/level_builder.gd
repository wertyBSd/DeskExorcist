class_name LevelBuilder
## Modular arena builder for the three GDD floors (Level Design.MD section 7).
##
## Each floor is a hand-authored ASCII map on a 4 m grid:
##   '#' full wall block   '+' wall block with a doorway
##   'o' cover pillar      '.' open floor
##   'S' player spawn      'n' survivor NPC dialog point
##   '=' elevated deck     '^' stair ramp climbing one deck toward -Z
## All geometry is code-built and sits on collision layer 16, so the player
## (mask 21) and the demons (mask 18) both collide with it.

extends Node3D

const BLOCK := 4.0          ## grid cell size in metres
const WALL_H := 3.0         ## wall height
const PILLAR := 1.4         ## pillar footprint
const DOOR_GAP := 1.8       ## opening left in a '+' wall

## Two-tier balcony geometry (GDD: "the player can climb wide stairs onto the
## second-floor balconies").  Decks are 2.4 m up so the player still fits
## underneath; stairs are a tilted slab because a stack of vertical steps is an
## unclimbable wall for move_and_slide().
const DECK_H := 2.4         ## walkable height of a deck
const DECK_THICK := 0.4     ## deck slab thickness
const STAIR_THICK := 0.3    ## stair ramp slab thickness
## How many shallow ramps a '^' cell is split into.  Each step covers half a
## cell in Z and an equal share of DECK_H, so the slope stays walkable.
const STAIR_STEPS := 2

## Minimum head clearance over a stair run (Level Design.MD: "Потолки над
## лестницами должны иметь запас высоты не менее 4 метров").  A solid slab is
## laid over every '^' stair cell with its underside this far above the TOP of
## the ramp, so the caster walks up without scraping their head.
const CEILING_H := 4.0
const CEILING_THICK := 0.3
## Footprint of the four columns carrying a stairwell ceiling down to the floor.
const COLUMN := 0.35

## How many decorative office props to sprinkle over each floor's open tiles.
const PROPS_PER_FLOOR := 22

const LEVELS := [
	{
		"name": "Spaceport Lobby",
		"map": [
			"##############",
			"#....====....#",
			"#.n..^..^..n.#",
			"#............#",
			"#..o......o..#",
			"#....S.......#",
			"#..+##..##+..#",
			"#....o..o....#",
			"#.n........n.#",
			"##############",
		],
	},
	{
		"name": "Openspace Blocks",
		"map": [
			"##############",
			"#...======...#",
			"#.n.^....^.n.#",
			"#............#",
			"#.o..####..o.#",
			"#....S.......#",
			"#.o..####..o.#",
			"#n..........n#",
			"#...o....o...#",
			"##############",
		],
	},
	{
		"name": "Executive Deck",
		"map": [
			"##############",
			"#n...====...n#",
			"#.o..^..^..o.#",
			"#............#",
			"#.o..####..o.#",
			"#....S.......#",
			"#.o..####..o.#",
			"#n..........n#",
			"#...o....o...#",
			"##############",
		],
	},
	{
		"name": "Server Hall",
		"map": [
			"##################",
			"#n......====....n#",
			"#.......^..^.....#",
			"#..o...o....o...o.#",
			"#..+..######..+..#",
			"#....o......o....#",
			"#..+..######..+..#",
			"#................#",
			"#..o...o....o...o.#",
			"#................#",
			"#.......S........#",
			"#................#",
			"##################",
		],
	},
	{
		"name": "Meeting Pods",
		"map": [
			"################",
			"#n...#....#....n#",
			"#.o..#....#..o..#",
			"#...+......+....#",
			"#...#..==..#....#",
			"#.o.#..^...#..o.#",
			"#...#......#....#",
			"#..+...S....+...#",
			"#...#......#....#",
			"#.o.#..^...#..o.#",
			"#...#..==..#....#",
			"#...+......+....#",
			"#.n..#....#..n..#",
			"################",
		],
	},
	{
		"name": "Archive Maze",
		"map": [
			"############",
			"#n....#....#",
			"#.o...#..n.#",
			"#..o..#..o.#",
			"#..+.....+#",
			"#..o..#..o.#",
			"#.n...#..n.#",
			"#..+..=..+#",
			"#..o..^..o.#",
			"#..+.....+#",
			"#n....S....#",
			"############",
		],
	},
	{
		"name": "Rooftop Array",
		"map": [
			"####################",
			"#n................n#",
			"#..o..o..o..o..o...#",
			"#..................#",
			"#..+.....==.....+..#",
			"#........^^........#",
			"#..o..o..o..o..o...#",
			"#..................#",
			"#..+............+..#",
			"#..................#",
			"#..o..o..o..o..o...#",
			"#........S.........#",
			"####################",
		],
	},
]

var cells_x := 0
var cells_z := 0
var half_x := 0.0
var half_z := 0.0
var player_spawn := Vector3.ZERO
var npc_points: Array[Vector3] = []

## Every walkable tile (floor, spawn, NPC, deck, stair).
var free_cells: Array[Vector2i] = []

## Floor tiles occupied by gimmicks (cover blocks, paper piles, chairs) —
## demons are never spawned on these (they would clip into geometry).
var gimmick_cells: Array[Vector2i] = []

## Walkable tiles at floor level only -- decks and stairs are excluded so
## demons never materialise inside a balcony slab.
var spawn_cells: Array[Vector2i] = []

var block_count := 0
var npc_count := 0
var deck_count := 0
## Number of '^' stair CELLS on the map.  `_add_stair` builds STAIR_STEPS ramp
## slabs per cell, so the physical slab count lives in `stair_ramp_count`.
var stair_count := 0
## Number of actual ramp slabs built (STAIR_STEPS per stair cell).
var stair_ramp_count := 0
var props_count := 0
## Number of stairwell ceilings (== the number of '^' cells).
var ceiling_count := 0
## Corner columns built under those ceilings (COLUMN_COUNT per ceiling).
var ceiling_column_count := 0

var _map: Array = []
var _wall_mat: StandardMaterial3D = null
var _floor_mat: StandardMaterial3D = null
var _deck_mat: StandardMaterial3D = null
var _stair_mat: StandardMaterial3D = null
var _ceiling_mat: StandardMaterial3D = null
var _prop_mat: StandardMaterial3D = null
var _metal_mat: StandardMaterial3D = null
var _panel_mat: StandardMaterial3D = null
var _pot_mat: StandardMaterial3D = null
var _leaf_mat: StandardMaterial3D = null

func _ready() -> void:
	add_to_group("level")

## Clears the node and rebuilds it from LEVELS[level_index].
func build(level_index: int = 0) -> void:
	for c in get_children():
		c.free()
	block_count = 0
	npc_count = 0
	deck_count = 0
	stair_count = 0
	stair_ramp_count = 0
	props_count = 0
	ceiling_count = 0
	ceiling_column_count = 0
	floor_gimmick_count = 0
	npc_points.clear()
	free_cells.clear()
	spawn_cells.clear()
	gimmick_cells.clear()

	var entry: Dictionary = LEVELS[clampi(level_index, 0, LEVELS.size() - 1)]
	_map = entry["map"]
	cells_x = (_map[0] as String).length()
	cells_z = _map.size()
	half_x = cells_x * BLOCK * 0.5
	half_z = cells_z * BLOCK * 0.5
	player_spawn = Vector3(0.0, 0.2, 0.0)

	_build_floor()
	for z in cells_z:
		var row: String = _map[z]
		for x in cells_x:
			var ch := row.substr(x, 1)
			var centre := cell_centre(x, z)
			match ch:
				"#":
					_add_block(centre, Vector3(BLOCK, WALL_H, BLOCK))
				"+":
					_add_door_wall(centre)
				"o":
					_add_block(centre, Vector3(PILLAR, WALL_H, PILLAR))
				"S":
					player_spawn = centre + Vector3(0.0, 0.2, 0.0)
					_register_floor_cell(x, z)
				"n":
					npc_points.append(centre)
					_register_floor_cell(x, z)
					_spawn_npc(centre)
				"^":
					_register_floor_cell(x, z)
					_add_stair(centre, x, z)
					_add_ceiling(centre)
				"=":
					free_cells.append(Vector2i(x, z))
					_add_deck(centre)
				_:
					_register_floor_cell(x, z)

	_scatter_props()
	_scatter_floor_gimmicks(level_index)
	# Demons must not materialise inside a cover block / paper pile / chair.
	if not gimmick_cells.is_empty():
		spawn_cells = spawn_cells.filter(func(c: Vector2i) -> bool: return c not in gimmick_cells)
	# Баг #13: a demon drop must be reachable on foot from the caster, or it
	# just mills about in a walled-off pocket the caster only sees on the
	# minimap (and only AoE can touch).  Keep reachable drops only.
	var reachable := _reachable_from_player()
	spawn_cells = spawn_cells.filter(func(c: Vector2i) -> bool: return reachable.has(c))

## Every cell reachable on foot from the player's start tile, walking only over
## ground-walkable tiles (see `_cell_passable`): walls '#' and pillars 'o'
## block, doorways '+' and under-deck '=' cells do not.  Used to guarantee that
## every demon spawn is connected to the caster (Баг #13).
func _reachable_from_player() -> Dictionary:
	var start := world_to_cell(player_spawn)
	var seen := {start: true}
	var frontier: Array[Vector2i] = [start]
	var neighbours := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	while not frontier.is_empty():
		var cell: Vector2i = frontier.pop_front()
		for d in neighbours:
			var n: Vector2i = cell + d
			if seen.has(n) or not _cell_passable(n.x, n.y):
				continue
			seen[n] = true
			frontier.append(n)
	return seen

## World-space centre of a grid cell, at floor level.
func cell_centre(x: int, z: int) -> Vector3:
	return Vector3((x + 0.5) * BLOCK - half_x, 0.0, (z + 0.5) * BLOCK - half_z)

## True when a world position lands in a wall, doorway or pillar cell.
func is_blocked(world: Vector3) -> bool:
	var x := int(floor((world.x + half_x) / BLOCK))
	var z := int(floor((world.z + half_z) / BLOCK))
	if x < 0 or z < 0 or x >= cells_x or z >= cells_z:
		return true
	var ch: String = (_map[z] as String).substr(x, 1)
	return ch == "#" or ch == "+" or ch == "o"

## A random open floor tile, preferring the ring that hugs the outer wall so
## demons walk in from the edges instead of popping up in the player's face.
## Only ground-level tiles are used, so a demon can never be dropped on top of
## a balcony slab.
func random_edge_position() -> Vector3:
	if spawn_cells.is_empty():
		return Vector3.ZERO
	var ring: Array[Vector2i] = []
	for c in spawn_cells:
		if c.x == 1 or c.y == 1 or c.x == cells_x - 2 or c.y == cells_z - 2:
			ring.append(c)
	var pool: Array[Vector2i] = ring if not ring.is_empty() else spawn_cells
	var c: Vector2i = pool[randi() % pool.size()]
	var jitter := Vector3(randf_range(-1.0, 1.0), 0.5, randf_range(-1.0, 1.0))
	return cell_centre(c.x, c.y) + jitter

## Grid cell for a world position (may be out of bounds).
func world_to_cell(world: Vector3) -> Vector2i:
	return Vector2i(int(floor((world.x + half_x) / BLOCK)), int(floor((world.z + half_z) / BLOCK)))

## Next world position a ground walker should head for to reach `to_world` from
## `from_world` without hugging walls, via a coarse breadth-first search over the
## arena grid. Returns `to_world` when a straight shot is already clear, or when
## no path is found (the caller then falls back to a direct chase). This is a
## NavMesh-free stand-in that keeps demons from pinning themselves on pillars
## and concave corners.
func next_path_point(from_world: Vector3, to_world: Vector3) -> Vector3:
	var start := world_to_cell(from_world)
	var goal := world_to_cell(to_world)
	# The caster standing on a balcony is only reachable up a stair.  Aim the
	# walker at the stair that feeds that deck; otherwise the 2-D grid lets a
	# demon path straight under the slab and it piles up there, invisible from
	# above (only the minimap / AoE could ever touch it).
	if glyph_at(goal.x, goal.y) == "=" and glyph_at(start.x, start.y) != "=":
		var stair := _stair_for_deck(goal)
		if stair.x >= 0:
			# Head for the foot of the stair, not the deck slab above it.
			return cell_centre(stair.x, stair.y)
	if _cell_passable(goal.x, goal.y) and _line_clear_world(from_world, to_world):
		return to_world
	var path := _bfs(start, goal)
	if path.size() < 2:
		return to_world
	# First step after the start cell, returned at floor level.
	var step: Vector2i = path[1]
	return cell_centre(step.x, step.y)

## True when the arena tile can be walked on at *ground* level.  Only solid
## walls '#' and cover pillars 'o' block: a doorway '+' carries a 1.8 m gap a
## demon walks through, and a balcony '=' slab floats at DECK_H leaving a ~2 m
## crawlspace beneath it.  (Баг #12 originally treated '=' as impassable, which
## severed corridors that only ran under a balcony or through a door -- see
## Баг #13, where reachability is now guaranteed instead.)
func _cell_passable(x: int, z: int) -> bool:
	var g := glyph_at(x, z)
	return g != "" and g != "#" and g != "o"

## Short raycast to check a straight world-space path is not blocked by geometry.
func _line_clear_world(from_world: Vector3, to_world: Vector3) -> bool:
	var space := get_world_3d().direct_space_state if get_world_3d() != null else null
	if space == null:
		return true
	var a := Vector3(from_world.x, 0.8, from_world.z)
	var b := Vector3(to_world.x, 0.8, to_world.z)
	var params := PhysicsRayQueryParameters3D.create(a, b, 16)
	return space.intersect_ray(params).is_empty()

## 4-neighbour BFS over passable cells; returns the cell path ([] if none).
func _bfs(start: Vector2i, goal: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if not _cell_passable(start.x, start.y) or not _cell_passable(goal.x, goal.y):
		return out
	var frontier: Array[Vector2i] = [start]
	var came := {start: start}
	var neighbours := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	var guard := 0
	while not frontier.is_empty() and guard < 4000:
		guard += 1
		var cell: Vector2i = frontier.pop_front()
		if cell == goal:
			var node := cell
			while node != start:
				out.push_front(node)
				node = came[node]
			out.push_front(start)
			return out
		for d in neighbours:
			var n: Vector2i = cell + d
			if came.has(n) or not _cell_passable(n.x, n.y):
				continue
			came[n] = cell
			frontier.append(n)
	return out

## The stair ramp cell that feeds a balcony cell, or (-1, -1) when the deck has
## no ramp.  Ground demons head here instead of piling up beneath a balcony the
## caster is standing on.
func _stair_for_deck(deck_cell: Vector2i) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_d := 1 << 30
	for z in cells_z:
		for x in cells_x:
			if glyph_at(x, z) != "^" or not _connects_to_deck(x, z):
				continue
			var d := absi(x - deck_cell.x) + absi(z - deck_cell.y)
			if d < best_d:
				best_d = d
				best = Vector2i(x, z)
	return best


# --- Construction helpers ----------------------------------------------------

func _build_floor() -> void:
	var size := Vector3(cells_x * BLOCK, 1.0, cells_z * BLOCK)
	var body := StaticBody3D.new()
	body.name = "Floor"
	body.collision_layer = 16
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = Vector3(0.0, -0.5, 0.0)
	body.add_child(shape)
	var mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mesh.mesh = bm
	mesh.position = Vector3(0.0, -0.5, 0.0)
	mesh.material_override = _floor_material()
	body.add_child(mesh)
	add_child(body)

## Adds a collidable, visible box whose base sits on the floor at `base`.
func _add_block(base: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 16
	body.collision_mask = 0
	body.position = base + Vector3(0.0, size.y * 0.5, 0.0)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	var mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mesh.mesh = bm
	mesh.material_override = _wall_material()
	body.add_child(mesh)
	add_child(body)
	block_count += 1

## A wall cell split around a central doorway, so corridors stay connected.
func _add_door_wall(base: Vector3) -> void:
	var seg := (BLOCK - DOOR_GAP) * 0.5
	var off := DOOR_GAP * 0.5 + seg * 0.5
	_add_block(base + Vector3(-off, 0.0, 0.0), Vector3(seg, WALL_H, BLOCK))
	_add_block(base + Vector3(off, 0.0, 0.0), Vector3(seg, WALL_H, BLOCK))

func _spawn_npc(base: Vector3) -> void:
	var npc := NPCDialog.new()
	npc.position = base
	add_child(npc)
	npc_count += 1

# --- Two-tier balcony helpers ------------------------------------------------

## Marks a tile as walkable at ground level.  Both `free_cells` (everything the
## player may stand on) and `spawn_cells` (ground-only demon drops) grow here.
func _register_floor_cell(x: int, z: int) -> void:
	var cell := Vector2i(x, z)
	free_cells.append(cell)
	spawn_cells.append(cell)

## The map glyph sitting at a grid cell, or "" when out of bounds.
## True when the cell is walkable floor (not a wall/pillar, and not a stair
## ramp or balcony slab — those live above ground level).
func is_floor(world: Vector3) -> bool:
	var cell := world_to_cell(world)
	if cell.x < 0 or cell.y < 0 or cell.x >= cells_x or cell.y >= cells_z:
		return false
	var glyph: String = glyph_at(cell.x, cell.y)
	return glyph == "." or glyph == "S" or glyph == "n"

func glyph_at(x: int, z: int) -> String:
	if z < 0 or z >= _map.size():
		return ""
	var row: String = _map[z]
	if x < 0 or x >= row.length():
		return ""
	return row.substr(x, 1)


## A balcony slab whose top surface sits DECK_H above the floor, leaving room
## to walk underneath it.
func _add_deck(base: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = "Deck"
	body.collision_layer = 16
	body.collision_mask = 0
	body.position = base + Vector3(0.0, DECK_H - DECK_THICK * 0.5, 0.0)
	var size := Vector3(BLOCK, DECK_THICK, BLOCK)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	var mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mesh.mesh = bm
	mesh.material_override = _deck_material()
	body.add_child(mesh)
	add_child(body)
	deck_count += 1

## A ramp rising from floor level at the +Z edge of the cell to deck height at
## its -Z edge, so it always meets the balcony it is placed in front of.
## The ramp is split into two shallower steps so the player (and demons) can
## actually walk up it instead of bonking into a single steep slab.
func _add_stair(base: Vector3, x: int, z: int) -> void:
	# STAIR_STEPS stacked ramps: each climbs an equal share of the deck height
	# over half a cell, keeping the slope walkable for
	# CharacterBody3D.move_and_slide().
	for step in STAIR_STEPS:
		var body := StaticBody3D.new()
		body.name = "Stair%d" % step
		body.collision_layer = 16
		body.collision_mask = 0
		var step_h := DECK_H / float(STAIR_STEPS)
		var step_z := BLOCK / float(STAIR_STEPS)
		# Low end of this step sits at step * step_h, high end at (step+1) * step_h.
		var y := step_h * (float(step) + 0.5) - STAIR_THICK
		var z_off := -BLOCK * 0.25 + float(step) * step_z
		body.position = base + Vector3(0.0, y, z_off)
		# A '=' in front of the ramp means the deck is further toward -Z, so the
		# ramp climbs that way; otherwise it is flipped to climb toward +Z.
		if not _connects_to_deck(x, z):
			body.rotation.x = PI
		var run := sqrt(step_z * step_z + step_h * step_h)
		var size := Vector3(BLOCK, STAIR_THICK, run)
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
		shape.shape = box
		body.add_child(shape)
		var mesh := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = size
		mesh.mesh = bm
		mesh.material_override = _stair_material()
		body.add_child(mesh)
		add_child(body)
		stair_ramp_count += 1
	# One map glyph == one stair cell, whatever the ramp is split into.
	stair_count += 1

## True when a deck tile sits directly against the ramp cell (either side).
func _connects_to_deck(x: int, z: int) -> bool:
	return glyph_at(x, z - 1) == "=" or glyph_at(x, z + 1) == "="

func _wall_material() -> StandardMaterial3D:
	if _wall_mat == null:
		_wall_mat = StandardMaterial3D.new()
		_wall_mat.albedo_color = Color("#3a3d4d")
		_wall_mat.roughness = 0.9
	return _wall_mat

func _floor_material() -> StandardMaterial3D:
	if _floor_mat == null:
		_floor_mat = StandardMaterial3D.new()
		_floor_mat.albedo_color = Color("#23222c")
		_floor_mat.roughness = 1.0
	return _floor_mat

## Balcony slabs are a touch lighter than the floor so the second tier reads
## clearly from underneath.
func _deck_material() -> StandardMaterial3D:
	if _deck_mat == null:
		_deck_mat = StandardMaterial3D.new()
		_deck_mat.albedo_color = Color("#4a4f63")
		_deck_mat.roughness = 0.85
	return _deck_mat

func _stair_material() -> StandardMaterial3D:
	if _stair_mat == null:
		_stair_mat = StandardMaterial3D.new()
		_stair_mat.albedo_color = Color("#5c6275")
		_stair_mat.roughness = 0.8
	return _stair_mat

func _ceiling_material() -> StandardMaterial3D:
	if _ceiling_mat == null:
		_ceiling_mat = StandardMaterial3D.new()
		_ceiling_mat.albedo_color = Color("#2a2c38")
		_ceiling_mat.roughness = 0.95
	return _ceiling_mat

func _prop_material() -> StandardMaterial3D:
	if _prop_mat == null:
		_prop_mat = StandardMaterial3D.new()
		_prop_mat.albedo_color = Color("#6b6350")
		_prop_mat.roughness = 0.9
	return _prop_mat

## A stairwell volume over a '^' cell: a solid slab whose underside sits
## CEILING_H above the TOP of the ramp, so the caster never bonks their head
## while walking up (Level Design.MD asks for >= 4 m of headroom over stairs).
## Four corner columns carry the slab down to the floor so the room reads as
## built rather than as a slab floating over the ramp.
func _add_ceiling(base: Vector3) -> void:
	var underside := DECK_H + CEILING_H
	var slab_top := underside + CEILING_THICK
	_add_ceiling_slab(Vector3(BLOCK, CEILING_THICK, BLOCK),
		base + Vector3(0.0, underside + CEILING_THICK * 0.5, 0.0))
	var half := BLOCK * 0.5 - COLUMN * 0.5
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_add_ceiling_slab(Vector3(COLUMN, slab_top, COLUMN),
				base + Vector3(sx * half, slab_top * 0.5, sz * half))
			ceiling_column_count += 1
	ceiling_count += 1

## One collidable ceiling element (slab or column), built like every other piece
## of level geometry: StaticBody3D on layer 16 with a matching box mesh.
func _add_ceiling_slab(size: Vector3, at: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = "Ceiling"
	body.collision_layer = 16
	body.collision_mask = 0
	body.position = at
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	var mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mesh.mesh = bm
	mesh.material_override = _ceiling_material()
	body.add_child(mesh)
	add_child(body)

## Sprinkles readable office furniture (Level Design.MD atmosphere).  Props are
## pushed toward the cell edges so the middle of the room stays walkable and the
## arena does not feel like an obstacle course.
func _scatter_props() -> void:
	if free_cells.is_empty():
		return
	var candidates := free_cells.duplicate()
	candidates.shuffle()
	for i in mini(PROPS_PER_FLOOR, candidates.size()):
		var c: Vector2i = candidates[i]
		var centre := cell_centre(c.x, c.y)
		if centre.distance_to(player_spawn) < BLOCK * 1.5:
			continue
		# Never drop a prop on a survivor tile (they overlapped into "a monster
		# stuck inside a cube").
		var on_npc := false
		for p in npc_points:
			if centre.distance_to(p) < BLOCK * 0.75:
				on_npc = true
				break
		if on_npc:
			continue
		# Only furnish tiles that hug a wall or pillar, so open lanes stay clear.
		if not _is_against_structure(c.x, c.y):
			continue
		_spawn_prop(centre)

## Floor-specific gimmicks (GDD Level Design §этажи): Ур.1 — мебель-укрытия
## с коллизией; Ур.2 — кучи бумаг, замедляющие игрока, и кресла, которые
## разлетаются от физики; Ур.3 — низкие стены-укрытия от болтов призраков.
var floor_gimmick_count := 0

func _scatter_floor_gimmicks(level_index: int) -> void:
	floor_gimmick_count = 0
	if free_cells.is_empty():
		return
	var candidates := free_cells.duplicate()
	candidates.shuffle()
	var placed := 0
	for c in candidates:
		if placed >= 10:
			break
		var centre := cell_centre(c.x, c.y)
		if centre.distance_to(player_spawn) < BLOCK * 2.0:
			continue
		var on_npc := false
		for p in npc_points:
			if centre.distance_to(p) < BLOCK * 0.75:
				on_npc = true
				break
		if on_npc:
			continue
		match level_index:
			0:
				_spawn_cover_block(centre, Vector3(1.6, 1.1, 0.9), "Cart")   # тележка/автомат
				placed += 1
			1:
				if placed % 2 == 0:
					_spawn_paper_zone(centre)
				else:
					_spawn_chair(centre)
				placed += 1
			2:
				_spawn_cover_block(centre, Vector3(2.2, 1.5, 0.4), "LowWall")  # укрытие
				placed += 1
		gimmick_cells.append(c)
		floor_gimmick_count += 1

## A collidable cover block (cart/partition), so Ур.1 has real obstacles.
func _spawn_cover_block(base: Vector3, size: Vector3, block_name: String) -> void:
	var body := StaticBody3D.new()
	body.name = block_name
	body.add_to_group("floor_gimmick")
	body.collision_layer = 16
	body.collision_mask = 0
	body.position = base + Vector3(0.0, size.y * 0.5, 0.0)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	var mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mesh.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("#5a6070")
	mesh.material_override = mat
	body.add_child(mesh)
	add_child(body)

## Loose papers: an Area3D that slows the caster while standing in it
## (Level Design Ур.2).
func _spawn_paper_zone(base: Vector3) -> void:
	var zone := Area3D.new()
	zone.name = "PaperPile"
	zone.add_to_group("papers")
	zone.position = base
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(BLOCK * 0.85, 0.6, BLOCK * 0.85)
	shape.shape = box
	shape.position = Vector3(0.0, 0.3, 0.0)
	zone.add_child(shape)
	for i in 5:
		var sheet := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(0.5, 0.7)
		sheet.mesh = pm
		sheet.rotation_degrees = Vector3(-90.0, randf_range(0.0, 360.0), 0.0)
		sheet.position = Vector3(randf_range(-1.2, 1.2), 0.02 + i * 0.01, randf_range(-1.2, 1.2))
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color("#e8e8e2")
		sheet.material_override = mat
		zone.add_child(sheet)
	zone.body_entered.connect(_on_paper_body_entered)
	zone.body_exited.connect(_on_paper_body_exited)
	add_child(zone)

func _on_paper_body_entered(body: Node) -> void:
	if body.has_method("paper_zone_enter"):
		body.paper_zone_enter()

func _on_paper_body_exited(body: Node) -> void:
	if body.has_method("paper_zone_exit"):
		body.paper_zone_exit()

## An office chair on a physics body: pushed around by the player and bolts.
func _spawn_chair(base: Vector3) -> void:
	var chair := RigidBody3D.new()
	chair.name = "Chair"
	chair.add_to_group("floor_gimmick")
	chair.mass = 8.0
	chair.collision_layer = 2
	chair.collision_mask = 17   # player (1) + level (16)
	chair.position = base + Vector3(0.0, 0.5, 0.0)
	var seat := CollisionShape3D.new()
	var sb := BoxShape3D.new()
	sb.size = Vector3(0.55, 0.12, 0.55)
	seat.shape = sb
	seat.position = Vector3(0.0, 0.45, 0.0)
	chair.add_child(seat)
	var back := CollisionShape3D.new()
	var bb := BoxShape3D.new()
	bb.size = Vector3(0.55, 0.6, 0.1)
	back.shape = bb
	back.position = Vector3(0.0, 0.75, -0.25)
	chair.add_child(back)
	var seat_m := MeshInstance3D.new()
	var sm := BoxMesh.new()
	sm.size = Vector3(0.55, 0.12, 0.55)
	seat_m.mesh = sm
	seat_m.position = Vector3(0.0, 0.45, 0.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("#37415a")
	seat_m.material_override = mat
	chair.add_child(seat_m)
	var back_m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.55, 0.6, 0.1)
	back_m.mesh = bm
	back_m.position = Vector3(0.0, 0.75, -0.25)
	back_m.material_override = mat
	chair.add_child(back_m)
	add_child(chair)

## True when any orthogonal neighbour of the cell is solid, i.e. the tile sits
## against a wall or pillar (a natural spot for furniture).
func _is_against_structure(x: int, z: int) -> bool:
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var g := glyph_at(x + d.x, z + d.y)
		if g == "#" or g == "+" or g == "o":
			return true
	return false

## One piece of office furniture.  A small set of recognizable low-poly silhouettes
## (desk, filing cabinet, cubicle panel, potted plant) instead of a random box, so
## the clutter reads as an office rather than noise.
func _spawn_prop(base: Vector3) -> void:
	var kind := randi() % 4
	var root := Node3D.new()
	root.name = "Prop"
	root.position = base
	root.rotation.y = [0.0, PI * 0.5, PI, PI * 1.5][randi() % 4]
	add_child(root)
	match kind:
		0:
			_build_desk(root)
		1:
			_build_cabinet(root)
		2:
			_build_cubicle(root)
		_:
			_build_plant(root)
	props_count += 1

## A desk: a top slab on four slim legs.
func _build_desk(root: Node3D) -> void:
	_add_prop_box(root, Vector3(0.0, 0.72, 0.0), Vector3(1.5, 0.08, 0.8), _prop_material())
	for sx in [-0.65, 0.65]:
		for sz in [-0.32, 0.32]:
			_add_prop_box(root, Vector3(sx, 0.36, sz), Vector3(0.06, 0.72, 0.06), _metal_material())

## A filing cabinet: a body with two thin drawer lines.
func _build_cabinet(root: Node3D) -> void:
	_add_prop_box(root, Vector3(0.0, 0.55, 0.0), Vector3(0.6, 1.1, 0.5), _metal_material())
	for y in [0.42, 0.68]:
		_add_prop_box(root, Vector3(0.0, y, -0.26), Vector3(0.5, 0.03, 0.03), _prop_material())

## A cubicle: a low fabric panel with a small desk behind it.
func _build_cubicle(root: Node3D) -> void:
	_add_prop_box(root, Vector3(0.0, 0.6, 0.0), Vector3(1.7, 1.2, 0.1), _panel_material())
	_add_prop_box(root, Vector3(0.0, 0.72, -0.45), Vector3(0.9, 0.06, 0.5), _prop_material())

## A potted plant: a pot with a couple of low-poly leaf boxes.
func _build_plant(root: Node3D) -> void:
	_add_prop_box(root, Vector3(0.0, 0.22, 0.0), Vector3(0.4, 0.44, 0.4), _pot_material())
	_add_prop_box(root, Vector3(0.0, 0.6, 0.0), Vector3(0.5, 0.5, 0.5), _leaf_material())
	_add_prop_box(root, Vector3(0.1, 0.9, 0.0), Vector3(0.32, 0.34, 0.32), _leaf_material())

func _add_prop_box(root: Node3D, pos: Vector3, size: Vector3, material: StandardMaterial3D) -> void:
	var mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mesh.mesh = bm
	mesh.position = pos
	mesh.material_override = material
	root.add_child(mesh)

## Props are visual-only: no collision, so they never trap the player or AI.
func _metal_material() -> StandardMaterial3D:
	if _metal_mat == null:
		_metal_mat = StandardMaterial3D.new()
		_metal_mat.albedo_color = Color("#8a8f9e")
		_metal_mat.roughness = 0.6
	return _metal_mat

func _panel_material() -> StandardMaterial3D:
	if _panel_mat == null:
		_panel_mat = StandardMaterial3D.new()
		_panel_mat.albedo_color = Color("#556075")
		_panel_mat.roughness = 0.95
	return _panel_mat

func _pot_material() -> StandardMaterial3D:
	if _pot_mat == null:
		_pot_mat = StandardMaterial3D.new()
		_pot_mat.albedo_color = Color("#9c5b3f")
		_pot_mat.roughness = 0.9
	return _pot_mat

func _leaf_material() -> StandardMaterial3D:
	if _leaf_mat == null:
		_leaf_mat = StandardMaterial3D.new()
		_leaf_mat.albedo_color = Color("#3f7d54")
		_leaf_mat.roughness = 0.9
	return _leaf_mat
