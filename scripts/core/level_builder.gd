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

const LEVELS := [
	{
		"name": "Spaceport Lobby",
		"map": [
			"##########",
			"#..====..#",
			"#n.^..^.n#",
			"#...S....#",
			"#..+##+..#",
			"#..o..o..#",
			"##########",
		],
	},
	{
		"name": "Openspace Blocks",
		"map": [
			"##########",
			"#..====..#",
			"#n.^..^..#",
			"#.o.##.o.#",
			"#....S...#",
			"#no.oo.on#",
			"##########",
		],
	},
	{
		"name": "Executive Deck",
		"map": [
			"##########",
			"#n.====.n#",
			"#o.^..^.o#",
			"#...S....#",
			"#o.o..o.o#",
			"#n.o..o.n#",
			"##########",
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

## Walkable tiles at floor level only -- decks and stairs are excluded so
## demons never materialise inside a balcony slab.
var spawn_cells: Array[Vector2i] = []

var block_count := 0
var npc_count := 0
var deck_count := 0
var stair_count := 0

var _map: Array = []
var _wall_mat: StandardMaterial3D = null
var _floor_mat: StandardMaterial3D = null
var _deck_mat: StandardMaterial3D = null
var _stair_mat: StandardMaterial3D = null

func _ready() -> void:
	add_to_group("level")

## Clears the node and rebuilds it from LEVELS[level_index].
func build(level_index: int = 0) -> void:
	for c in get_children():
		c.queue_free()
	block_count = 0
	npc_count = 0
	deck_count = 0
	stair_count = 0
	npc_points.clear()
	free_cells.clear()
	spawn_cells.clear()

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
				"=":
					free_cells.append(Vector2i(x, z))
					_add_deck(centre)
				_:
					_register_floor_cell(x, z)

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
func _add_stair(base: Vector3, x: int, z: int) -> void:
	var body := StaticBody3D.new()
	body.name = "Stair"
	body.collision_layer = 16
	body.collision_mask = 0
	# Push the slab back by its own thickness so the low end stays buried in the
	# floor instead of hovering over it.
	body.position = base + Vector3(0.0, DECK_H * 0.5 - STAIR_THICK, 0.0)
	# A '=' in front of the ramp means the deck is further toward -Z, so the ramp
	# climbs that way; otherwise it is flipped to climb toward +Z.
	if not _connects_to_deck(x, z):
		body.rotation.x = PI
	var run := sqrt(BLOCK * BLOCK + DECK_H * DECK_H)
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
