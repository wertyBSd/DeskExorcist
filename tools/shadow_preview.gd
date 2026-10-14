extends Node
## Shadow audit for the caster.
##
##   godot --path . res://tools/shadow_preview.tscn -- probe     # empty room
##   godot --path . res://tools/shadow_preview.tscn -- live      # real arena
##
## The question this exists to answer: in first person the caster sees a shadow
## on the floor that is NOT their own body. Everything else here exists to keep
## that from being a guess -- a dressed arena has a dozen other casters, so
## `probe` puts the caster alone on a bare floor under the same sun and the
## only things that can darken it are the caster and the casting arms.
##
## Output: temp/shadow_<name>.png, 1280x720.

const SHOT_DIR := "res://temp/"
const LEVEL := 0

## The sun as main.tscn sets it, so the probe and the game agree. main.tscn
## writes its Transform3D row-major, so these are its rows read as columns.
const SUN_BASIS := Basis(
	Vector3(0.866025, 0.0, -0.5),
	Vector3(-0.353553, 0.707107, -0.612372),
	Vector3(0.353553, 0.707107, 0.612372))

var _scene: Node = null
var _player: Player = null
var _light: DirectionalLight3D = null
var _mode := "probe"
var _bare := false

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHOT_DIR))
	for a in OS.get_cmdline_user_args():
		if a in ["probe", "live"]:
			_mode = a
		elif a == "bare":
			_bare = true
	await get_tree().process_frame
	if _mode == "probe":
		await _probe()
	else:
		await _live()
	print("done (%s)" % _mode)
	get_tree().quit(0)

# --- probe: caster alone on a bare floor -------------------------------------

func _probe() -> void:
	var root := Node3D.new()
	add_child(root)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.1, 0.11, 0.15)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.55, 0.6, 0.75)
	e.ambient_light_energy = 0.6
	env.environment = e
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.transform = Transform3D(SUN_BASIS, Vector3(0.0, 12.0, 0.0))
	sun.shadow_enabled = true
	root.add_child(sun)
	_light = sun
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 16
	floor_body.collision_mask = 0
	root.add_child(floor_body)
	var floor := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(24.0, 0.2, 24.0)
	floor.mesh = box
	floor.position = Vector3(0.0, -0.1, 0.0)
	var shape := CollisionShape3D.new()
	var shape_box := BoxShape3D.new()
	shape_box.size = Vector3(24.0, 0.2, 24.0)
	shape.shape = shape_box
	shape.position = Vector3(0.0, -0.1, 0.0)
	floor_body.add_child(shape)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.55, 0.57, 0.66)
	floor.material_override = mat
	root.add_child(floor)
	_player = (load("res://scenes/player.tscn") as PackedScene).instantiate() as Player
	root.add_child(_player)
	_player.global_position = Vector3.ZERO
	# The caster is aimed along +Z (the level builder's spawn facing) so the
	# numbers below describe a real in-game pose rather than an arbitrary one.
	_player.rotation.y = PI
	for i in 8:
		await get_tree().process_frame
	_dump()
	_dump_patch()
	await _shots(Vector3.ZERO, "probe")
	await _variants()

## Where the contact patch ended up, and whether the floor probe found anything.
func _dump_patch() -> void:
	var patch := _player.get_node_or_null("ContactShadow") as ContactShadow
	if patch == null:
		print("  contact shadow: MISSING")
		return
	var mesh := patch.get_node_or_null("Patch") as MeshInstance3D
	print("  contact shadow: visible=%s at=%s alpha=%.2f (caster at %s)" % [
		mesh.visible if mesh != null else false,
		mesh.global_position if mesh != null else Vector3.ZERO,
		(patch._material.albedo_color.a if patch._material != null else 0.0),
		_player.global_position])
	if mesh == null:
		return
	print("    in_tree=%s tree_visible=%s layers=%d mesh=%s aabb=%s" % [
		mesh.is_inside_tree(), mesh.is_visible_in_tree(), mesh.layers,
		mesh.mesh, mesh.get_aabb()])
	print("    global_xform=%s cast=%s" % [mesh.global_transform, mesh.cast_shadow])
	var mat := mesh.material_override as StandardMaterial3D
	if mat != null:
		print("    mat tex=%s filter=%d transparency=%d cull=%d" % [
			mat.albedo_texture, mat.texture_filter, mat.transparency, mat.cull_mode])

func _variants() -> void:
	for node in get_tree().get_nodes_in_group("viewmodel"):
		(node as Node3D).visible = false
	await _shots(Vector3.ZERO, "probe_novm")
	for node in get_tree().get_nodes_in_group("viewmodel"):
		(node as Node3D).visible = true
	for mi in _player.get_node("ModelRoot").find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).visible = false
	await _shots(Vector3.ZERO, "probe_nobody")
	for mi in _player.get_node("ModelRoot").find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).visible = true
	# Clean-floor baseline: body, arms and contact patch all gone, so the only
	# caster-free floor in the set. Diffing this against `probe_novm` isolates
	# the patch, and against `probe` shows everything the caster adds.
	var patch := _player.get_node_or_null("ContactShadow") as ContactShadow
	for node in get_tree().get_nodes_in_group("viewmodel"):
		(node as Node3D).visible = false
	for mi in _player.get_node("ModelRoot").find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).visible = false
	if patch != null:
		patch.visible = false
	await _shots(Vector3.ZERO, "probe_bare")
	if patch != null:
		patch.visible = true
	for node in get_tree().get_nodes_in_group("viewmodel"):
		(node as Node3D).visible = true
	for mi in _player.get_node("ModelRoot").find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).visible = true
	# Airborne: a patch at full strength under a jump reads as a hole in the
	# floor, so it has to fade out with the gap.
	_player.global_position = Vector3(0.0, 1.1, 0.0)
	_player.velocity = Vector3.ZERO
	for i in 4:
		await get_tree().process_frame
	await _eye(-60.0, "probe_air_eye60")
	_player.global_position = Vector3(0.0, 2.6, 0.0)
	for i in 4:
		await get_tree().process_frame
	await _eye(-60.0, "probe_air2_eye60")
	_dump_patch()
	_player.global_position = Vector3.ZERO
	for i in 4:
		await get_tree().process_frame

# --- live: the real arena, for before/after review shots ----------------------

func _live() -> void:
	_scene = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(_scene)
	var game := _scene as Game
	game.level_index = LEVEL
	game._build_level()
	var hud := _scene.get_node_or_null("HUD") as CanvasLayer
	if hud != null:
		hud.visible = false
	for i in 8:
		await get_tree().process_frame
	_player = _scene.get_node_or_null("Player") as Player
	_light = _scene.get_node_or_null("DirectionalLight3D") as DirectionalLight3D
	_dump()
	_dump_patch()
	await _shots(_player.global_position, "live")
	# `live bare` re-shoots with the patch off, which is the A/B pair for the
	# caster's own eyes (the viewmodel bob is the only other difference).
	if _bare:
		var patch := _player.get_node_or_null("ContactShadow") as ContactShadow
		if patch != null:
			patch.visible = false
		await _shots(_player.global_position, "live_nopatch")
		if patch != null:
			patch.visible = true

# --- shared ------------------------------------------------------------------

func _shots(p: Vector3, tag: String) -> void:
	var ldir := -_light.global_basis.z
	print("%s: light travels %s" % [tag, ldir])
	# Looking at the caster from the side the shadow falls on, so the shadow and
	# the caster are in one frame.
	var side := Vector3(ldir.x, 0.0, ldir.z).normalized()
	await _from(_player.get_node("Camera3D") as Camera3D, p, side * 3.4 + Vector3.UP * 2.4,
		p + Vector3.UP * 0.6, 60.0, "%s_third" % tag)
	await _top(p, "%s_top" % tag)
	for pitch in [-30.0, -45.0, -60.0]:
		await _eye(pitch, "%s_eye%d" % [tag, int(-pitch)])

## Overhead: the only angle that shows the caster, the arms and where each
## shadow lands on the same stretch of floor.
func _top(p: Vector3, name: String) -> void:
	var cam := _player.get_node("Camera3D") as Camera3D
	var keep := cam.position
	cam.position = Vector3(0.0, 9.0, 0.0)
	cam.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
	cam.fov = 50.0
	cam.current = true
	for i in 4:
		await get_tree().process_frame
	await _save(name)
	cam.position = keep

## The caster's own eye, pitched down: what the player actually gets to see.
func _eye(pitch_deg: float, name: String) -> void:
	var cam := _player.get_node("Camera3D") as Camera3D
	cam.position = Vector3(0.0, 1.6, 0.0)
	cam.rotation = Vector3(deg_to_rad(pitch_deg), 0.0, 0.0)
	cam.fov = 75.0
	cam.current = true
	for i in 4:
		await get_tree().process_frame
	await _save(name)

func _from(cam: Camera3D, _p: Vector3, pos: Vector3, look: Vector3, fov: float, name: String) -> void:
	var extra := Camera3D.new()
	add_child(extra)
	extra.fov = fov
	extra.global_position = pos
	extra.look_at(look, Vector3.UP)
	extra.current = true
	for i in 4:
		await get_tree().process_frame
	await _save(name)
	extra.queue_free()
	if cam != null:
		cam.current = true

func _save(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(
		ProjectSettings.globalize_path("%sshadow_%s.png" % [SHOT_DIR, name]))
	print("  %sshadow_%s.png" % [SHOT_DIR, name])

## Everything the shadow pass looks at, printed rather than eyeballed.
func _dump() -> void:
	print("--- sun ---")
	print("  shadow_enabled=%s cull_mask=%d" % [_light.shadow_enabled, _light.light_cull_mask])
	print("  travels=%s" % [(-_light.global_basis.z)])
	print("--- caster body ---")
	var root := _player.get_node_or_null("ModelRoot") as Node3D
	if root == null:
		print("  NO ModelRoot")
		return
	var n := 0
	var off_layer := 0
	var no_cast := 0
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		n += 1
		if m.layers != 1:
			off_layer += 1
		if m.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_ON:
			no_cast += 1
	print("  meshes=%d  off_default_layer=%d  not_casting=%d" % [n, off_layer, no_cast])
	print("--- caster camera ---")
	var cam := _player.get_node_or_null("Camera3D") as Camera3D
	if cam != null:
		print("  cull_mask=%d near=%.3f" % [cam.cull_mask, cam.near])
