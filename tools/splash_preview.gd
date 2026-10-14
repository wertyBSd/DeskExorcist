extends Node
## Renders the splash screen to `temp/splash.png` so the logo lockup can be
## reviewed without launching the whole game. Windowed, like room_preview:
## a headless Godot has no rendering device.
##   "Godot.exe" --path . res://tools/splash_preview.tscn

const SHOT_PATH := "res://temp/splash.png"
## When to grab: after the fade-in has finished, before the hold expires.
const SHOT_AT := 1.0

func _ready() -> void:
	await get_tree().process_frame
	var splash: Control = (load("res://scenes/splash_screen.tscn") as PackedScene).instantiate()
	add_child(splash)
	var elapsed := 0.0
	while elapsed < SHOT_AT:
		await get_tree().process_frame
		elapsed += 1.0 / 60.0
	await RenderingServer.frame_post_draw
	var mark := splash.get_node_or_null("Column/Mark") as TextureRect
	print("fade=%.2f mark=%s size=%s" % [(splash.get_node("FadeOverlay") as ColorRect).color.a,
		mark.texture, mark.size if mark != null else Vector2.ZERO])
	# Report the logo's own background colour so the splash backdrop can be
	# matched to it -- a mismatched field shows up as a visible square.
	if mark != null and mark.texture != null:
		var src := mark.texture.get_image()
		if src != null:
			var corner: Color = src.get_pixel(2, 2)
			print("logo_corner=%s  logo_alpha_corner=%.2f" % [corner.to_html(false), corner.a])
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(SHOT_PATH))
	print("wrote %s" % SHOT_PATH)
	get_tree().quit(0)