extends Node
## Screenshots the in-run HUD with the minimap visible, from a few caster
## yaws, so the facing cone can be reviewed without playing. Windowed, like
## room_preview -- a headless Godot has no rendering device.
##   "Godot.exe" --path . --resolution 1280x720 res://tools/hud_preview.tscn

const SHOT_DIR := "res://temp/"

## One arena, a few yaws: north, east, south-west.
const YAWS := [0.0, PI * 0.5, -PI * 2.25]

func _ready() -> void:
	await get_tree().process_frame
	var scene: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	# Same dance as the suite's `_spawn_run()`: the run has to be a child of the
	# window root AND the registered current scene, otherwise the HUD's
	# `get_tree().current_scene` lookup fails and the map never draws.
	get_tree().root.add_child(scene)
	get_tree().current_scene = scene
	var game := scene as Game
	game.level_index = 0
	game._build_level()
	var level := scene.get_node_or_null("Level") as LevelBuilder
	var player := scene.get_node_or_null("Player") as Player
	player.global_position = level.player_spawn
	var hud := scene.get_node_or_null("HUD") as HUD
	if hud == null:
		get_tree().quit(1)
		return
	# A couple of demons and a portal so the map has something to point at.
	for i in 3:
		var demon := Enemy.new()
		demon.configure(Enemy.Kind.PAPERWORK_PHANTOM)
		scene.add_child(demon)
		demon.global_position = level.player_spawn + Vector3(6.0 + float(i) * 3.0, 0.0, -4.0 - float(i) * 3.0)
	for i in 12:
		await get_tree().process_frame
	for yaw in YAWS:
		player._camera.rotation.y = yaw
		for i in 3:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var name := "hud_yaw_%d.png" % int(round(rad_to_deg(yaw)))
		get_viewport().get_texture().get_image().save_png(
			ProjectSettings.globalize_path("%s%s" % [SHOT_DIR, name]))
		print("  %s%s" % [SHOT_DIR, name])
	get_tree().quit(0)