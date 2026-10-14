extends Node
## Wedge repro for BUGS.md #16: drops a demon into every solid cell of an arena
## and reports the ones it cannot get out of. `trapped=[]` means the fix holds.
##
##   godot --headless --path . res://tools/repro_wedge.tscn -- 3
##
## n = one arena index, `-1` = every arena.
##
## Two traps this tool walks into on purpose, both learned the hard way:
## the player must be kept alive, and `get_tree().paused` must be reset after
## every probe -- a dead player pauses the tree, and every later probe then
## reports `w=0.00` nonsense because nothing ticks.

func _ready() -> void:
	await get_tree().process_frame
	var only := -1
	for a in OS.get_cmdline_user_args():
		if a.is_valid_int():
			only = int(a)
	var scene: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(scene)
	get_tree().current_scene = scene
	var game := scene as Game
	var level := scene.get_node_or_null("Level") as LevelBuilder
	var player := scene.get_node_or_null("Player") as Player
	var indices: Array = range(LevelBuilder.LEVELS.size()) if only < 0 else [only]
	for i in indices:
		game.level_index = i
		game._build_level()
		await get_tree().physics_frame
		var trapped: Array[String] = []
		var freed: Array[int] = []
		for z in level.cells_z:
			for x in level.cells_x:
				if not level.is_blocked(level.cell_centre(x, z)):
					continue
				var outcome := await _probe(level, player, level.cell_centre(x, z))
				if outcome < 0:
					trapped.append("%s%d" % [String.chr(65 + x), z + 1])
				else:
					freed.append(outcome)
		print("arena=%s trapped=%s freed_after_frames=%s" % [LevelBuilder.LEVELS[i]["name"],
			str(trapped), str(freed)])
	level.player_spawn = level.player_spawn
	player.global_position = level.player_spawn
	player.health = player.max_health
	get_tree().quit(0)

## Drops a demon at `spot`, runs the physics for a while and returns the frame
## it escaped on, or -1 if it never did.
func _probe(level: LevelBuilder, player: Player, spot: Vector3) -> int:
	var demon := Enemy.new()
	demon.configure(Enemy.Kind.PAPERWORK_PHANTOM)
	demon.health = 9999
	get_tree().current_scene.add_child(demon)
	demon.global_position = spot + Vector3(0.0, 0.5, 0.0)
	# Keep the caster alive and the tree running: a death pauses the tree and
	# every later probe would then tick nothing at all.
	player.health = player.max_health
	player._invuln_time = 99.0
	get_tree().paused = false
	var frames := 0
	while frames < 420:
		await get_tree().physics_frame
		get_tree().paused = false
		player.health = player.max_health
		frames += 1
		if not level.is_blocked(demon.global_position):
			demon.queue_free()
			return frames
	demon.queue_free()
	await get_tree().physics_frame
	get_tree().paused = false
	return -1