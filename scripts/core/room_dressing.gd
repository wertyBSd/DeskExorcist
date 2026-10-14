class_name RoomDressing
## Turns the level's grey boxes into rooms.
##
## `LevelBuilder` builds the arena out of solid `BoxMesh` blocks, which is the
## right thing for collision and the wrong thing for a room: flat untextured
## faces, no windows, no way in, nothing that says "office". This pass lays a
## *skin* over that geometry:
##
##   * wall panelling -- skirting board, a painted dado with a gold pinstripe and
##     a chair rail above it, and a timber fascia under a dropped ceiling
##   * windows on the outer walls: inner shell built around the opening, timber
##     frame + mullions, glass, and the starfield outside (Level Design.MD asks
##     for "огромные панорамные окна, сквозь которые виден космос")
##   * doors that never open -- frame, panelled leaf, handle, kick plate, a sign
##     plate ("SERVER ROOM", "ARCHIVE", ...) and a sconce over it
##   * a dropped-ceiling soffit over the wall ring with a cove light washing down
##     it, and pendant lamps on suspended ceiling islands over the open middle
##
## Two invariants keep it safe to bolt on top of a working arena:
##
##   * **No collision.** Every piece here is trim sitting on surfaces the level
##     collider already owns. The window is visual-only too: the wall behind it
##     stays a solid block, so nothing new can trap the player, a demon or a
##     bolt. Everything lands under one child node named "Room".
##   * **Deterministic.** Which faces get a window, a door or a lamp comes from
##     the map itself, never from `randi()`, so an arena looks the same every
##     run and the test suite can assert on it.
##
## All of it is baked into one mesh per material by MeshBatch -- a dressed
## office is about a dozen draw calls, and rebuilding it on a floor transition
## is one array append per piece.

## Mirrors LevelBuilder.BLOCK / WALL_H / DECK_H (the suite asserts they agree).
## Duplicated as plain numbers because RoomDressing talks to the level through
## an untyped instance, which keeps the two classes free of a cyclic
## dependency.
const BLOCK := 4.0
const WALL_H := 3.0
const DECK_H := 2.4

## Neighbour offsets, in cell space: +X, -X, +Z, -Z.
const FACES := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

# --- wall panelling (metres) -------------------------------------------------
const SKIRT_H := 0.16        ## skirting board height
const SKIRT_PROUD := 0.045   ## how far the skirting stands off the wall
const DADO_H := 1.02         ## top of the painted dado panel
const DADO_PROUD := 0.024
const RAIL_H := 0.055        ## chair rail cap on top of the dado
const RAIL_PROUD := 0.05
const STRIPE_H := 0.022      ## gold pinstripe under the chair rail
const FASCIA_DROP := 0.34    ## timber fascia below the ceiling line
const FASCIA_PROUD := 0.13
const COVE_Y := 2.60         ## hidden cove light behind the fascia
const COVE_H := 0.05

# --- window ------------------------------------------------------------------
const WIN_SILL := 1.16       ## above the chair rail, as in a real office
const WIN_HEAD := 2.42
const WIN_W := 2.6
const SHELL_T := 0.14        ## thickness of the inner wall shell around the hole
const GLASS_SET := 0.1       ## glass sits GLASS_SET inside the shell
const SKY_SET := 0.95        ## starfield plane, deep in the wall thickness
const MULLION := 0.05

# --- door --------------------------------------------------------------------
const DOOR_W := 1.06
const DOOR_H := 2.1
const CASE_PROUD := 0.09
const LEAF_PROUD := 0.045
const LEAF_T := 0.05
const SIGN_Y := 2.46

# --- ceiling and light -------------------------------------------------------
const SOFFIT_T := 0.22       ## dropped ceiling slab over the wall ring
const CLOUD_Y := 5.6         ## suspended ceiling island over each lamp
const CLOUD_W := 3.4
const BEAM_Y := 6.8          ## structural grid across the open middle
const BEAM_SPACING := 10.0   ## metres between beams
const LAMP_Y := 4.86         ## pendant lamp rim height
const LAMP_COUNT := 8
const DOOR_COUNT := 7
const SPACING := 2           ## in cells; keeps lamps/doors from clumping
const SIGNS := [
	"OFFICE 4B", "SERVER ROOM", "ARCHIVE", "COPY ROOM",
	"MEETING", "HR / PAYROLL", "DIRECTOR", "FIRE ESCAPE",
]

## Counters the test suite pins (they also make a useful build log).
var window_count := 0
var door_count := 0
var sign_count := 0
var lamp_count := 0
var trimmed_faces := 0
var soffit_count := 0
var light_pool_count := 0

## The level being dressed. Untyped on purpose: RoomDressing is called *from*
## LevelBuilder, so naming LevelBuilder here would make the two classes depend
## on each other at parse time.
var _lv
var _cells_x := 0
var _cells_z := 0
var _room: Node3D

## cell + face index -> true, for the windowed facade.
var _window_faces := {}
var _door_faces: Array[Vector3i] = []
var _lamp_cells: Array[Vector2i] = []

# Batches, one per material.
var _wood := MeshBatch.new()
var _paint := MeshBatch.new()
var _gold := MeshBatch.new()
var _shell := MeshBatch.new()
var _ceiling := MeshBatch.new()
var _glass := MeshBatch.new()
var _sky := MeshBatch.new()
var _wash := MeshBatch.new()
var _ao := MeshBatch.new()
var _pool := MeshBatch.new()
var _metal := MeshBatch.new()
var _shade := MeshBatch.new()
var _emissive := MeshBatch.new()
var _cove := MeshBatch.new()
var _art := MeshBatch.new()

# --- entry point -------------------------------------------------------------

## Builds the dressing for `level` and parents it under a single "Room" node.
## Returns this instance so LevelBuilder can publish the counters.
func build(level) -> RoomDressing:
	_lv = level
	_cells_x = _lv.cells_x
	_cells_z = _lv.cells_z
	_room = Node3D.new()
	_room.name = "Room"
	_lv.add_child(_room)
	_plan_facade()
	_plan_doors()
	_plan_lamps()
	_dress_walls()
	_dress_pillars()
	_dress_decks()
	_dress_doorways()
	_dress_roof()
	_place_lamps()
	_flush()
	return self

# --- planning ----------------------------------------------------------------

## Marks one face per facade cell as a window. Windows sit on every second cell
## of the outer ring, skipping the corners and skipping any cell whose neighbour
## along the wall run is a doorway -- a window jammed against a door frame looks
## like a mistake and the casings would fight.
##
## The face marked is the one pointing back INTO the map, not the one pointing
## out of bounds: that is the surface the room sees, and the glass/starfield sit
## at a negative `out`, i.e. back up inside the 4 m of wall behind it.
func _plan_facade() -> void:
	for z in _cells_z:
		for x in _cells_x:
			if _glyph(x, z) != "#":
				continue
			var outward := Vector2i.ZERO
			for d in FACES:
				var nx: int = x + d.x
				var nz: int = z + d.y
				if nx < 0 or nz < 0 or nx >= _cells_x or nz >= _cells_z:
					outward = d
			# Interior block, or a corner with two outward faces: corners would
			# get two overlapping window assemblies, so they stay plain wall.
			if outward == Vector2i.ZERO or _outward_count(x, z) != 1:
				continue
			var along: int = (x if outward.y != 0 else z)
			var edge: int = (_cells_x if outward.y != 0 else _cells_z)
			if along % 2 != 0 or along == 0 or along == edge - 1:
				continue
			var step := Vector2i(1, 0) if outward.y != 0 else Vector2i(0, 1)
			if not _is_wall(x + step.x, z + step.y) or not _is_wall(x - step.x, z - step.y):
				continue
			var inward := Vector2i(-outward.x, -outward.y)
			_window_faces[Vector3i(x, z, FACES.find(inward))] = true

## How many sides of this cell fall outside the map (0, 1 or 2).
func _outward_count(x: int, z: int) -> int:
	var n := 0
	for d in FACES:
		var nx: int = x + d.x
		var nz: int = z + d.y
		if nx < 0 or nz < 0 or nx >= _cells_x or nz >= _cells_z:
			n += 1
	return n

## Picks the door faces: an exposed wall face with open floor in front of it
## that is not already a window. Candidates are walked in map order and thinned
## out so the doors end up spread around the room instead of stacked on one
## wall.
func _plan_doors() -> void:
	var candidates: Array[Vector3i] = []
	for z in _cells_z:
		for x in _cells_x:
			if _glyph(x, z) != "#":
				continue
			for i in FACES.size():
				var d: Vector2i = FACES[i]
				var key := Vector3i(x, z, i)
				if _window_faces.has(key) or not _open_floor(x + d.x, z + d.y):
					continue
				candidates.append(key)
	var chosen: Array[Vector3i] = []
	for c in candidates:
		var spaced := true
		for k in chosen:
			if absi(k.x - c.x) <= SPACING and absi(k.y - c.y) <= SPACING:
				spaced = false
				break
		if not spaced:
			continue
		chosen.append(c)
		if chosen.size() >= DOOR_COUNT:
			break
	_door_faces = chosen

## Pendant lamps go over the open middle of the room: floor cells with open
## floor on all four sides, at least two cells from the player's spawn, spread
## out. Never over a balcony slab -- the caster stands 2.4 m up there and would
## walk into the lamp.
func _plan_lamps() -> void:
	var spawn: Vector2i = _lv.world_to_cell(_lv.player_spawn)
	var candidates: Array[Vector2i] = []
	for z in _cells_z:
		for x in _cells_x:
			if _glyph(x, z) != ".":
				continue
			if absi(x - spawn.x) < 2 and absi(z - spawn.y) < 2:
				continue
			var open := true
			for d in FACES:
				if not _open_floor(x + d.x, z + d.y):
					open = false
					break
			if open:
				candidates.append(Vector2i(x, z))
	var chosen: Array[Vector2i] = []
	for c in candidates:
		var spaced := true
		for k in chosen:
			if absi(k.x - c.x) < SPACING and absi(k.y - c.y) < SPACING:
				spaced = false
				break
		if not spaced:
			continue
		chosen.append(c)
		if chosen.size() >= LAMP_COUNT:
			break
	_lamp_cells = chosen

# --- walls -------------------------------------------------------------------

## Every wall face that looks into the room gets the trim stack, bottom-up:
## skirting, dado, rail, gold pinstripe, fascia, cove strip and its wash.
func _dress_walls() -> void:
	for z in _cells_z:
		for x in _cells_x:
			if _glyph(x, z) != "#":
				continue
			var seen := false
			for i in FACES.size():
				var d: Vector2i = FACES[i]
				if _is_solid(x + d.x, z + d.y):
					continue
				seen = true
				var frame := _frame(x, z, d)
				var key := Vector3i(x, z, i)
				if _door_faces.has(key):
					_door(frame, _door_faces.find(key))
				else:
					_trim(frame)
				if _window_faces.has(key):
					_window(frame)
				elif not _door_faces.has(key) and (x * 7 + z * 13 + i * 3) % 5 == 0:
					_picture(frame)
			if seen:
				_soffit(x, z)

## The trim stack on one exposed face. `out` is the distance out from the wall
## face towards the room, so every piece is measured from the same plane.
func _trim(frame: Dictionary) -> void:
	trimmed_faces += 1
	# Skirting board: full width, 16 cm, standing 4.5 cm proud.
	_face_box(_wood, frame, 0.0, SKIRT_H * 0.5, SKIRT_PROUD * 0.5, BLOCK, SKIRT_H, SKIRT_PROUD)
	# Painted dado panel, standing just proud of the wallpaper.
	_face_box(_paint, frame, 0.0, SKIRT_H + (DADO_H - SKIRT_H) * 0.5, DADO_PROUD * 0.5,
		BLOCK, DADO_H - SKIRT_H, DADO_PROUD)
	# Chair rail: the timber cap, then the gold pinstripe tucked under it.
	_face_box(_wood, frame, 0.0, DADO_H + RAIL_H * 0.5, RAIL_PROUD * 0.5, BLOCK, RAIL_H, RAIL_PROUD)
	_face_box(_gold, frame, 0.0, DADO_H + RAIL_H + STRIPE_H * 0.5, RAIL_PROUD + 0.004,
		BLOCK, STRIPE_H, 0.008)
	# Fascia: the timber band where the dropped ceiling meets the wall, with a
	# gold line along its bottom edge.
	_face_box(_wood, frame, 0.0, WALL_H - FASCIA_DROP * 0.5 + 0.02, FASCIA_PROUD * 0.5,
		BLOCK, FASCIA_DROP, FASCIA_PROUD)
	_face_box(_gold, frame, 0.0, WALL_H - FASCIA_DROP - 0.02, FASCIA_PROUD + 0.006, BLOCK, 0.02, 0.01)
	# The cove light itself, hidden behind the fascia and washing the wall.
	_face_box(_cove, frame, 0.0, COVE_Y, 0.05, BLOCK - 0.2, COVE_H, 0.05)
	# The wash: an additive gradient quad. The Compatibility renderer has no
	# global illumination, so without this decal the strip reads as a glowing
	# line with no light coming out of it.
	_face_quad(_wash, frame, 0.0, COVE_Y - 0.42, 0.02, BLOCK - 0.1, 0.85)
	# Contact shading where the wall meets the carpet. The renderer has no
	# ambient occlusion, and without this the wall reads as a flat sheet that
	# was dropped on top of the floor.
	_face_quad(_ao, frame, 0.0, 0.34, 0.008, BLOCK - 0.05, 0.68,
		Vector2(0.0, 1.0), Vector2(1.0, 0.0))

## Dropped ceiling over a wall cell with at least one face in the room: a slab
## sitting on the wall top, which is what turns an open-topped arena into
## something that reads as a room from the inside.
func _soffit(x: int, z: int) -> void:
	var centre: Vector3 = _lv.cell_centre(x, z) + Vector3(0.0, WALL_H + SOFFIT_T * 0.5, 0.0)
	_ceiling.add_box(centre, Vector3(BLOCK, SOFFIT_T, BLOCK))
	soffit_count += 1

## A window: inner shell built around the opening, timber frame with a mullion
## cross, the glass, the sky behind it and a pool of moonlight on the floor.
## The collision box behind it is untouched -- the window is a picture of a
## window, not a hole in the level.
func _window(frame: Dictionary) -> void:
	window_count += 1
	var gap := WIN_HEAD - WIN_SILL
	var mid_y := (WIN_SILL + WIN_HEAD) * 0.5
	var pier := (BLOCK - WIN_W) * 0.5
	# Shell: sill wall, header wall, and a pier either side of the opening.
	_face_box(_shell, frame, 0.0, WIN_SILL * 0.5, -SHELL_T * 0.5, BLOCK, WIN_SILL, SHELL_T)
	_face_box(_shell, frame, 0.0, WIN_HEAD + (WALL_H - WIN_HEAD) * 0.5, -SHELL_T * 0.5,
		BLOCK, WALL_H - WIN_HEAD, SHELL_T)
	for side in [-1.0, 1.0]:
		_face_box(_shell, frame, side * (WIN_W * 0.5 + pier * 0.5), mid_y, -SHELL_T * 0.5,
			pier, gap, SHELL_T)
	# Timber frame standing proud of the shell, plus the sill board.
	_face_box(_wood, frame, -(WIN_W * 0.5 + 0.05), mid_y, 0.03, 0.1, gap + 0.1, 0.06)
	_face_box(_wood, frame, WIN_W * 0.5 + 0.05, mid_y, 0.03, 0.1, gap + 0.1, 0.06)
	_face_box(_wood, frame, 0.0, WIN_HEAD + 0.05, 0.03, WIN_W + 0.2, 0.1, 0.06)
	_face_box(_wood, frame, 0.0, WIN_SILL - 0.05, 0.07, WIN_W + 0.3, 0.12, 0.14)
	# Mullion cross: a four-pane window reads as "window" from across the room.
	_face_box(_wood, frame, 0.0, mid_y, 0.02, MULLION, gap, 0.04)
	_face_box(_wood, frame, 0.0, mid_y, 0.02, WIN_W, MULLION, 0.04)
	# Glass, then the sky behind it (UVs from -1..1 so the starfield tiles).
	_face_box(_glass, frame, 0.0, mid_y, -GLASS_SET, WIN_W, gap, 0.02)
	_face_quad(_sky, frame, 0.0, mid_y, -SKY_SET, WIN_W + 1.6, gap + 1.4,
		Vector2(-1.0, -1.0), Vector2(1.0, 1.0))
	# Moonlight on the floor in front, but only where there is floor in front:
	# on a balcony cell the pool would land under the slab.
	var ahead: Vector3 = frame["plane"] + frame["n"] * 1.5
	var cell: Vector2i = _lv.world_to_cell(ahead)
	if _open_floor(cell.x, cell.y):
		light_pool_count += 1
		_horizontal_glow(ahead, Vector2(3.2, 2.4))

## A door that never opens. Flat on the wall: the leaf stands 4.5 cm proud and
## carries no collision, so it can never block a doorway or pin a demon.
func _door(frame: Dictionary, index: int) -> void:
	door_count += 1
	# Casing: two jambs and a head, all timber, standing 9 cm proud.
	_face_box(_wood, frame, -(DOOR_W * 0.5 + 0.06), 1.12, CASE_PROUD * 0.5, 0.12, 2.24, CASE_PROUD)
	_face_box(_wood, frame, DOOR_W * 0.5 + 0.06, 1.12, CASE_PROUD * 0.5, 0.12, 2.24, CASE_PROUD)
	_face_box(_wood, frame, 0.0, 2.2, CASE_PROUD * 0.5, DOOR_W + 0.24, 0.12, CASE_PROUD)
	# Leaf, then the two raised panels that make it read as a door instead of a
	# rectangle of wood.
	_face_box(_wood, frame, 0.0, DOOR_H * 0.5, LEAF_PROUD, DOOR_W, DOOR_H, LEAF_T)
	_face_box(_paint, frame, 0.0, 1.5, LEAF_PROUD + LEAF_T * 0.5 + 0.006, 0.82, 0.62, 0.012)
	_face_box(_paint, frame, 0.0, 0.52, LEAF_PROUD + LEAF_T * 0.5 + 0.006, 0.82, 0.78, 0.012)
	# Handles and kick plate in the accent metal.
	_face_box(_gold, frame, 0.4, 1.02, LEAF_PROUD + 0.06, 0.11, 0.035, 0.09)
	_face_box(_gold, frame, -0.4, 1.02, LEAF_PROUD + 0.06, 0.11, 0.035, 0.09)
	_face_box(_metal, frame, 0.0, 0.16, LEAF_PROUD + LEAF_T * 0.5 + 0.01, DOOR_W - 0.08, 0.2, 0.02)
	# Sign plate over the door -- the cheapest way to say "this is a workplace".
	if index >= 0:
		_sign(SIGNS[index % SIGNS.size()], frame)

## A sconce over the door plate. Doors are the one thing a player aims a spell
## at from across the room, and most of them sit in a corridor the pendant lamps
## never reach (lamps only hang over open floor), so without a local light the
## door is an unlit rectangle in a dark corner.
func _sconce(frame: Dictionary) -> void:
	_face_box(_wood, frame, 0.0, SIGN_Y + 0.32, 0.07, 0.34, 0.1, 0.14)
	_face_box(_cove, frame, 0.0, SIGN_Y + 0.22, 0.05, 0.22, 0.07, 0.1)
	_face_quad(_wash, frame, 0.0, 1.72, 0.02, 1.7, 1.7)

## A framed picture in the band between the chair rail and the fascia.
func _picture(frame: Dictionary) -> void:
	var w := 1.1
	var h := 0.72
	var y := 1.78
	_face_box(_wood, frame, 0.0, y + h * 0.5 + 0.03, 0.03, w + 0.12, 0.06, 0.06)
	_face_box(_wood, frame, 0.0, y - h * 0.5 - 0.03, 0.03, w + 0.12, 0.06, 0.06)
	_face_box(_wood, frame, -(w * 0.5 + 0.03), y, 0.03, 0.06, h + 0.12, 0.06)
	_face_box(_wood, frame, w * 0.5 + 0.03, y, 0.03, 0.06, h + 0.12, 0.06)
	_face_box(_art, frame, 0.0, y, 0.028, w, h, 0.02)

## The plate over a door. A Label3D rather than a painted box because room
## names are the cheapest possible way to sell "office" -- and it is one node
## per door, not a texture atlas.
func _sign(text: String, frame: Dictionary) -> void:
	sign_count += 1
	var label := Label3D.new()
	label.name = "DoorSign"
	label.text = text
	label.font_size = 40
	label.pixel_size = 0.0024
	label.modulate = Color("#e8c25a")
	label.outline_size = 14
	label.outline_modulate = Color(0.06, 0.04, 0.09, 0.85)
	label.alpha_cut = Label3D.ALPHA_CUT_DISCARD
	label.shaded = false
	label.double_sided = false
	label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	var n: Vector3 = frame["n"]
	# Label3D draws its text facing its own +Z, and `looking_at` aims -Z, so it
	# has to be given the opposite of the room direction -- pointing it at the
	# room instead turns every plate to face inside the wall.
	label.basis = Basis.looking_at(-n, Vector3.UP)
	label.position = frame["plane"] + n * 0.06 + Vector3.UP * SIGN_Y
	_room.add_child(label)

# --- pillars, decks, doorways ------------------------------------------------

## Cover pillars get a plinth and a capital so they stop being bare boxes.
func _dress_pillars() -> void:
	for z in _cells_z:
		for x in _cells_x:
			if _glyph(x, z) != "o":
				continue
			var c: Vector3 = _lv.cell_centre(x, z)
			_shell.add_box(c + Vector3(0.0, 0.06, 0.0), Vector3(1.62, 0.12, 1.62))
			_shell.add_box(c + Vector3(0.0, 0.18, 0.0), Vector3(1.5, 0.12, 1.5))
			_shell.add_box(c + Vector3(0.0, WALL_H - 0.09, 0.0), Vector3(1.56, 0.18, 1.56))
			_gold.add_box(c + Vector3(0.0, 1.12, 0.0), Vector3(1.44, 0.03, 1.44))

## Balcony slabs get a gold nosing on every edge that overlooks the room: the
## cheapest readability win on a second tier the player has to aim down from.
func _dress_decks() -> void:
	for z in _cells_z:
		for x in _cells_x:
			if _glyph(x, z) != "=":
				continue
			var c: Vector3 = _lv.cell_centre(x, z)
			for d in FACES:
				if _glyph(x + d.x, z + d.y) == "=":
					continue
				var u := Vector3(0.0, 0.0, 1.0) if d.x != 0 else Vector3(1.0, 0.0, 0.0)
				_gold.add_box(c + Vector3(d.x, 0.0, d.y) * (BLOCK * 0.5 - 0.01)
					+ Vector3(0.0, DECK_H - 0.02, 0.0), Vector3(BLOCK, 0.04, 0.04),
					Basis(u, Vector3.UP, u.cross(Vector3.UP)))

## The '+' doorways are real openings, so they get what a real opening has:
## jambs, a head and a threshold strip on the floor.
func _dress_doorways() -> void:
	var gap := 1.8
	for z in _cells_z:
		for x in _cells_x:
			if _glyph(x, z) != "+":
				continue
			var c: Vector3 = _lv.cell_centre(x, z)
			# The doorway splits the cell along X, so the jambs stand on +/-X.
			for side in [-1.0, 1.0]:
				_wood.add_box(c + Vector3(side * (gap * 0.5 + 0.05), 1.1, 0.0),
					Vector3(0.1, 2.2, BLOCK))
			_wood.add_box(c + Vector3(0.0, 2.25, 0.0), Vector3(gap + 0.2, 0.12, BLOCK))
			_metal.add_box(c + Vector3(0.0, 0.01, 0.0), Vector3(gap, 0.02, 0.5))

# --- lamps and roof ----------------------------------------------------------

## Suspended ceiling islands and the structural grid above them. The arena has
## no roof -- a full slab would cut through the balconies, which sit 2.4 m up --
## so "looking up" would otherwise be a black void. A cloud per pendant lamp
## plus a coarse beam grid gives the eye something to read at height while
## leaving the play space completely open.
func _dress_roof() -> void:
	var span_x := _cells_x * BLOCK
	var span_z := _cells_z * BLOCK
	var beams := int(span_x / BEAM_SPACING) + 1
	for i in beams:
		var x := -span_x * 0.5 + float(i) * BEAM_SPACING
		_metal.add_box(Vector3(x, BEAM_Y, 0.0), Vector3(0.26, 0.34, span_z))
	beams = int(span_z / BEAM_SPACING) + 1
	for i in beams:
		var z := -span_z * 0.5 + float(i) * BEAM_SPACING
		_metal.add_box(Vector3(0.0, BEAM_Y, z), Vector3(span_x, 0.34, 0.26))

## Pendant lamps under a suspended ceiling island: cloud, four rods up to the
## beam grid, a stem down to a conical shade with a glowing diffuser, and the
## one real light source in the room. Eight of them with distance falloff read
## as an office ceiling and still leave the Compatibility renderer's
## per-object light budget alone.
func _place_lamps() -> void:
	for cell in _lamp_cells:
		var c: Vector3 = _lv.cell_centre(cell.x, cell.y)
		# Ceiling island, then the rods that hold it up.
		_ceiling.add_box(c + Vector3(0.0, CLOUD_Y, 0.0), Vector3(CLOUD_W, 0.18, CLOUD_W))
		for sx in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				_metal.add_box(c + Vector3(sx, CLOUD_Y + 0.9, sz) * (CLOUD_W * 0.5 - 0.25),
					Vector3(0.04, 1.8, 0.04))
		# Stem, shade, diffuser.
		_metal.add_box(c + Vector3(0.0, LAMP_Y + 0.9, 0.0), Vector3(0.05, 0.5, 0.05))
		_shade.add_cone(c + Vector3(0.0, LAMP_Y + 0.19, 0.0), 0.45, 0.14, 0.38, 12)
		_shade.add_cone(c + Vector3(0.0, LAMP_Y + 0.42, 0.0), 0.16, 0.3, 0.12, 12)
		_emissive.add_cone(c + Vector3(0.0, LAMP_Y - 0.01, 0.0), 0.4, 0.4, 0.03, 12)
		var light := OmniLight3D.new()
		light.name = "Lamp"
		light.position = c + Vector3(0.0, LAMP_Y - 0.3, 0.0)
		light.light_color = Color("#ffdcae")
		light.light_energy = 2.0
		light.omni_range = 13.0
		light.shadow_enabled = false
		_room.add_child(light)
		lamp_count += 1

# --- output ------------------------------------------------------------------

## Bakes the batches into one mesh per material under the "Room" node.
func _flush() -> void:
	_add(_wood.build(_material_trim(), "TrimWood"))
	_add(_paint.build(_material_dado(), "TrimPaint"))
	_add(_gold.build(_material_gold(), "AccentGold"))
	_add(_shell.build(_material_wall(), "WallShell"))
	_add(_ceiling.build(_material_ceiling(), "CeilingSoffit"))
	_add(_glass.build(_material_glass(), "Glass"))
	_add(_sky.build(_material_sky(), "WindowSky"))
	_add(_wash.build(_material_wash(), "CoveWash"))
	_add(_ao.build(_material_ao(), "ContactShade"))
	_add(_pool.build(_material_pool(), "WindowLight"))
	_add(_metal.build(_material_metal(), "Metal"))
	_add(_shade.build(_material_lamp_shade(), "LampShade"))
	_add(_emissive.build(_material_emit(), "LampDiffuser"))
	_add(_cove.build(_material_cove(), "CoveStrip"))
	_add(_art.build(_material_art(), "PictureArt"))

func _add(node: MeshInstance3D) -> void:
	if node != null:
		_room.add_child(node)

# --- materials ---------------------------------------------------------------

func _material_trim() -> StandardMaterial3D:
	return TextureLibrary.material("wood", Color.WHITE, 0.72, 0.6)

func _material_dado() -> StandardMaterial3D:
	return TextureLibrary.material("wainscot", Color.WHITE, 0.95, 0.5)

func _material_gold() -> StandardMaterial3D:
	return TextureLibrary.plain(Color("#c8a24a"), 0.35, 0.75, 0.15)

func _material_wall() -> StandardMaterial3D:
	return TextureLibrary.material("wallpaper", Color.WHITE, 0.94, 0.5)

## The soffit underside is the one surface a player stares straight up at, so
## it gets ceiling tile: light, grid-lined, the opposite of the dark walls.
## Tinted down though -- at full brightness the tile out-glows the wallpaper and
## the room reads as a lit stage with dark scenery.
func _material_ceiling() -> StandardMaterial3D:
	return TextureLibrary.material("ceiling", Color("#8b8f9c"), 0.9, 0.4)

func _material_glass() -> StandardMaterial3D:
	var mat := TextureLibrary.plain(Color("#a9d4ee"), 0.05, 0.1)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.emission_enabled = true
	mat.emission = Color("#7fa8c8")
	mat.emission_energy_multiplier = 0.35
	mat.albedo_color.a = 0.28
	return mat

## The sky is unlit and mapped by the quad's own UVs, so triplanar is switched
## off here -- it would throw those UVs away.
func _material_sky() -> StandardMaterial3D:
	var mat := TextureLibrary.material("sky", Color.WHITE, 1.0, 1.0)
	mat.uv1_triplanar = false
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return mat

## Warm wash of the hidden cove light onto the upper wall.
func _material_wash() -> StandardMaterial3D:
	var mat := TextureLibrary.plain(Color("#ffd9a0"), 1.0, 0.0, 0.0, true, true)
	mat.albedo_texture = TextureLibrary.surface("glow")
	mat.albedo_color.a = 0.45
	return mat

## Contact shading at the foot of each wall: a multiply decal that darkens the
## skirting. The glow gradient is reused with its UVs flipped, so v = 0 (the
## dark end of the strip) lands at the top of the quad and the wall goes from
## shadow at the floor back to untouched paper by head height.
func _material_ao() -> StandardMaterial3D:
	var mat := TextureLibrary.plain(Color("#8a8296"), 1.0, 0.0, 0.0, true)
	mat.albedo_texture = TextureLibrary.surface("glow")
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_MUL
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color.a = 0.75
	return mat

## Cold pool of moonlight each window drops on the carpet.
func _material_pool() -> StandardMaterial3D:
	var mat := TextureLibrary.plain(Color("#9fc4ff"), 1.0, 0.0, 0.0, true, true)
	mat.albedo_texture = TextureLibrary.surface("glow")
	mat.albedo_color.a = 0.5
	return mat

func _material_metal() -> StandardMaterial3D:
	return TextureLibrary.plain(Color("#2b2e3a"), 0.55, 0.5)

func _material_lamp_shade() -> StandardMaterial3D:
	return TextureLibrary.plain(Color("#2f3140"), 0.6, 0.3)

## The lamp diffuser is a light source on screen, so it burns; the cove strip is
## only meant to look like one from a distance and sits much lower, or every
## wall gets a blown-out white bar along the top.
func _material_emit() -> StandardMaterial3D:
	return TextureLibrary.plain(Color("#ffe9c0"), 0.4, 0.0, 2.4)

func _material_cove() -> StandardMaterial3D:
	return TextureLibrary.plain(Color("#ffd9a8"), 0.5, 0.0, 0.55)

func _material_art() -> StandardMaterial3D:
	return TextureLibrary.material("canvas", Color.WHITE, 0.85, 1.0)

# --- helpers -----------------------------------------------------------------

## Frame of reference for one wall face: where its plane is, which way "into
## the wall" points (`n`), and the horizontal axis along the face (`u`). The
## `out` offset used below is measured from the plane towards the room, so
## positive means "proud of the wall".
func _frame(x: int, z: int, d: Vector2i) -> Dictionary:
	var centre: Vector3 = _lv.cell_centre(x, z)
	var n := Vector3(d.x, 0.0, d.y)
	var u := Vector3(0.0, 0.0, 1.0) if d.x != 0 else Vector3(1.0, 0.0, 0.0)
	return {
		"n": n,
		"u": u,
		"plane": centre + n * (BLOCK * 0.5),
		"basis": Basis(u, Vector3.UP, u.cross(Vector3.UP)),
	}

## Box on a wall face, placed by (along the face, up the wall, out of the wall).
## `out` is measured from the face plane TOWARDS THE ROOM along `n`, so positive
## stands proud of the wall and negative recesses into it (the window shell uses
## that to build the reveal around the opening).
func _face_box(batch: MeshBatch, frame: Dictionary, du: float, dy: float, out: float,
		size_u: float, size_y: float, size_n: float) -> void:
	var centre: Vector3 = frame["plane"] + frame["u"] * du + Vector3.UP * dy + frame["n"] * out
	batch.add_box(centre, Vector3(size_u, size_y, size_n), frame["basis"])

## Flat quad on a wall face, facing back into the room. UVs run across it so a
## gradient texture runs the way it is meant to.
func _face_quad(batch: MeshBatch, frame: Dictionary, du: float, dy: float, out: float,
		size_u: float, size_y: float, uv_min := Vector2.ZERO, uv_max := Vector2.ONE) -> void:
	var n: Vector3 = frame["n"]
	var u: Vector3 = frame["u"]
	var origin: Vector3 = frame["plane"] + n * out + Vector3.UP * dy
	var hu := u * (size_u * 0.5)
	var hv := Vector3.UP * (size_y * 0.5)
	batch.add_quad([origin - hu - hv, origin + hu - hv, origin + hu + hv, origin - hu + hv], -n, [
		uv_min, Vector2(uv_max.x, uv_min.y), uv_max, Vector2(uv_min.x, uv_max.y)])

## Horizontal additive glow on the floor: the pool of light a window drops.
func _horizontal_glow(at: Vector3, size: Vector2) -> void:
	var hu := Vector3(size.x * 0.5, 0.0, 0.0)
	var hv := Vector3(0.0, 0.0, size.y * 0.5)
	var up := Vector3.UP * 0.03
	_pool.add_quad([at - hu - hv + up, at + hu - hv + up, at + hu + hv + up, at - hu + hv + up],
		Vector3.UP, [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])

func _glyph(x: int, z: int) -> String:
	return _lv.glyph_at(x, z)

func _is_wall(x: int, z: int) -> bool:
	return _glyph(x, z) == "#"

## A face is "solid" when it looks into another wall, a doorway, or out of the
## map. The outside of the building is never seen, so dressing it would spend
## most of the trim budget on geometry the player cannot reach.
func _is_solid(x: int, z: int) -> bool:
	if x < 0 or z < 0 or x >= _cells_x or z >= _cells_z:
		return true
	var g := _glyph(x, z)
	return g == "#" or g == "+"

func _open_floor(x: int, z: int) -> bool:
	var g := _glyph(x, z)
	return g == "." or g == "S" or g == "n"