extends Node
## Renders the dressed arena from a few fixed camera angles and writes PNGs to
## `temp/`, the same "contact sheet for visual review" job `tools/preview_models.py`
## does for the character silhouettes.
##
## Run it windowed -- a headless Godot has no rendering device and would hand
## back black frames:
##   godot --path . res://tools/room_preview.tscn -- [level_index]
##
## level_index defaults to -1, which shoots every registered arena. Output:
## `temp/room_<name>.png`, 1280x720.

const SHOT_DIR := "res://temp/"

## One arena per angle. Offsets are in GRID CELLS from the player's spawn, not
## metres: arenas differ in size and the spawn is not always in the middle, so a
## fixed metre offset walks the camera into a wall (or out of the building) on
## every map that is not the lobby. `look` is the cell to look at.
const SHOTS := [
	{"name": "hall", "from": Vector2i(0, 2), "look": Vector2i(0, -3), "fov": 70.0},
	{"name": "wall", "from": Vector2i(-2, 1), "look": Vector2i(-5, -1), "fov": 65.0},
	{"name": "up", "from": Vector2i(1, 0), "look": Vector2i(0, -2), "fov": 85.0, "up": true},
	{"name": "corner", "from": Vector2i(-2, 2), "look": Vector2i(3, -3), "fov": 70.0},
]

var _index := -1

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.is_valid_int():
			_index = int(a)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHOT_DIR))
	var levels: Array = LevelBuilder.LEVELS if _index < 0 else [LevelBuilder.LEVELS[clampi(_index, 0, LevelBuilder.LEVELS.size() - 1)]]
	await get_tree().process_frame
	for entry in levels:
		await _shoot(entry)
	print("wrote %d shots to temp/" % (levels.size() * SHOTS.size()))
	get_tree().quit(0)

func _shoot(entry: Dictionary) -> void:
	var scene: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(scene)
	var game := scene as Game
	game.level_index = LevelBuilder.LEVELS.find(entry)
	game._build_level()
	var level := scene.get_node_or_null("Level") as LevelBuilder
	var player := scene.get_node_or_null("Player") as Player
	# Architectural shots: the caster's HUD and viewmodel would sit on top of
	# exactly the detail this tool exists to review.
	var hud := scene.get_node_or_null("HUD") as CanvasLayer
	if hud != null:
		hud.visible = false
	# NO_DRESS=1 hides the dressing so a shot can be diffed against the bare
	# collision boxes it is supposed to be skinning.
	if OS.get_environment("NO_DRESS") == "1":
		var room := scene.get_node_or_null("Level/Room")
		if room != null:
			(room as Node3D).visible = false
	# Real frames: the dressing builds itself in `_build_level`, and letting the
	# scene settle means the shots show the arena the player actually spawns in.
	for i in 4:
		await get_tree().process_frame
	var spawn: Vector3 = level.player_spawn
	var spawn_cell: Vector2i = level.world_to_cell(spawn)
	for shot in SHOTS:
		var from := _open_cell(level, spawn_cell, shot["from"])
		var at := _open_cell(level, spawn_cell, shot["look"])
		var cam := Camera3D.new()
		cam.fov = float(shot["fov"])
		add_child(cam)
		cam.global_position = level.cell_centre(from.x, from.y) + Vector3.UP * 1.65
		var target := level.cell_centre(at.x, at.y)
		# The "up" shot tilts from the camera instead of aiming at a point.
		cam.look_at(Vector3(target.x, cam.global_position.y + 3.0, target.z) if bool(shot.get("up", false))
			else Vector3(target.x, 1.3, target.z), Vector3.UP)
		# The caster's own camera is flagged current in player.tscn, so a new
		# camera has to take over explicitly.
		cam.current = true
		# Three frames so the freshly enabled camera is actually the one drawn.
		for i in 3:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		var path := "%sroom_%s_%s.png" % [SHOT_DIR, String(entry["name"]).to_lower().replace(" ", "_"), shot["name"]]
		img.save_png(ProjectSettings.globalize_path(path))
		print("  %s" % path)
		cam.queue_free()
	# One extra shot the fixed angles cannot reach: the dressing decides where
	# the doors go, so frame whichever one this arena happened to pick.
	var door := _first_sign(scene)
	if door != null:
		var plate := door.global_position
		var back := _clearance(scene, plate, door.global_basis.z)
		print("door plate=%s fwd=%s back=%.1f" % [plate, door.global_basis.z, back])
		await _grab(scene, plate + door.global_basis.z * back + Vector3.UP * -1.0,
			plate + Vector3.DOWN * 1.1, 62.0, "door_%s" % String(entry["name"]).to_lower().replace(" ", "_"))
	# The level scale differs per arena; keep the shots inside it.
	player.global_position = level.player_spawn
	scene.queue_free()
	await get_tree().process_frame

## Spawn + a cell offset, snapped back into the arena and onto floor that is
## not a wall: the offset exists to frame the room, so if it lands inside a wall
## the shot is useless (and a camera inside a wall renders the sky quad).
func _open_cell(level: LevelBuilder, spawn: Vector2i, offset: Vector2i) -> Vector2i:
	var want := Vector2i(clampi(spawn.x + offset.x, 1, level.cells_x - 2),
		clampi(spawn.y + offset.y, 1, level.cells_z - 2))
	if not level.is_blocked(level.cell_centre(want.x, want.y)):
		return want
	# Spiral out to the nearest free tile instead of giving up on the shot.
	for radius in range(1, 6):
		for dz in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				var c := Vector2i(want.x + dx, want.y + dz)
				if c.x < 1 or c.y < 1 or c.x >= level.cells_x - 1 or c.y >= level.cells_z - 1:
					continue
				if not level.is_blocked(level.cell_centre(c.x, c.y)):
					return c
	return spawn

## The first door plate in the room, or null when this arena has no doors.
func _first_sign(scene: Node) -> Label3D:
	var room := scene.get_node_or_null("Level/Room")
	if room == null:
		return null
	var signs := room.find_children("*", "Label3D", true, false)
	return signs[0] as Label3D if not signs.is_empty() else null

## How far back the camera can stand and still see the door: a fixed distance
## buries the lens inside the opposite wall of a narrow arena (Archive Maze
## corridors are one cell wide). Stops 1.2 m short of the first hit on the
## level's collision layer.
func _clearance(scene: Node, from: Vector3, dir: Vector3) -> float:
	const WANT := 4.6
	const FLOOR := 1.6
	var world := get_viewport().world_3d.direct_space_state
	var params := PhysicsRayQueryParameters3D.create(from, from + dir * WANT, 16)
	var hit := world.intersect_ray(params)
	if hit.is_empty():
		return WANT
	return clampf(from.distance_to(hit["position"]) - 1.2, FLOOR, WANT)

## Saves one framed shot under `name`.
func _grab(scene: Node, pos: Vector3, look: Vector3, fov: float, name: String) -> void:
	var cam := Camera3D.new()
	cam.fov = fov
	add_child(cam)
	cam.global_position = pos
	cam.look_at(look, Vector3.UP)
	cam.current = true
	for i in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(
		ProjectSettings.globalize_path("%sroom_%s.png" % [SHOT_DIR, name]))
	print("  %sroom_%s.png" % [SHOT_DIR, name])
	cam.queue_free()