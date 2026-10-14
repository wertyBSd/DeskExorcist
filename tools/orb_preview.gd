extends Node
## Contact sheet of the charge orb, as the caster actually sees it.
##
##   godot --path . res://tools/orb_preview.tscn
##
## Windowed, not --headless: the point is the rendered glow, and a headless Godot
## has no rendering device and hands back black frames.
##
## The orb's materials and colour are set at RUNTIME (Viewmodel._build_charge),
## so `tools/preview_viewmodel.py` cannot show the finished thing -- it renders
## the .glb's baked materials. These frames come from the real scene graph with
## the real spell colours, at the charge levels that actually occur.
##
## Output: temp/orb_<name>.png, 1280x720.

const SHOT_DIR := "res://temp/"
## One shot per row: charge level, and the slot whose spell colour is held.
## The point of the set is that the orb takes the SPELL's colour, so the frames
## that differ only in slot are the ones that prove it.
const SHOTS := [
	{"name": "empty", "charge": 0.0, "spell": -1},
	{"name": "quarter_gold", "charge": 0.25, "spell": 4},
	{"name": "half_violet", "charge": 0.5, "spell": 6},
	{"name": "full_pink", "charge": 1.0, "spell": 2},
	{"name": "full_ice", "charge": 1.0, "spell": 8},
]

var _player: Player = null
var _view: Viewmodel = null

## One frame per bolt: how far down the lane it is, and whose it is.
## `start` is how far AHEAD of the muzzle it is born -- an enemy bolt fired at
## point-blank range from inside the player is gone before the first frame is
## drawn, so the incoming one starts at the far end of the lane instead, still
## in front of the eye.
const BOLTS := [
	{"name": "bolt_near", "at": 0.8, "enemy": false, "start": 0.0},
	{"name": "bolt_mid", "at": 3.0, "enemy": false, "start": 0.0},
	{"name": "bolt_far", "at": 9.0, "enemy": false, "start": 0.0},
	{"name": "bolt_hex", "at": 5.0, "enemy": true, "start": 9.0},
]

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHOT_DIR))
	await get_tree().process_frame
	# A bare room: the orb is unlit and self-coloured, so what is behind it only
	# has to be a plausible floor tone and must not distract from the glow.
	var root := Node3D.new()
	add_child(root)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("#2b2f42")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("#8899bb")
	e.ambient_light_energy = 0.8
	env.environment = e
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.transform = Transform3D(Basis(
		Vector3(0.866, 0.0, -0.5), Vector3(-0.354, 0.707, -0.612),
		Vector3(0.354, 0.707, 0.612)), Vector3(0.0, 12.0, 0.0))
	sun.shadow_enabled = true
	root.add_child(sun)
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 16
	floor_body.collision_mask = 0
	var floor_shape := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(20.0, 0.2, 20.0)
	floor_shape.shape = floor_box
	floor_shape.position = Vector3(0.0, -0.1, 0.0)
	floor_body.add_child(floor_shape)
	root.add_child(floor_body)
	var floor := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(20.0, 0.2, 20.0)
	floor.mesh = box
	floor.position = Vector3(0.0, -0.1, 0.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("#6a6f86")
	floor.material_override = mat
	root.add_child(floor)
	_player = (load("res://scenes/player.tscn") as PackedScene).instantiate() as Player
	root.add_child(_player)
	_player.global_position = Vector3.ZERO
	for i in 6:
		await get_tree().process_frame
	_view = _player.get_node_or_null("Camera3D/Viewmodel") as Viewmodel
	if _view == null:
		print("orb_preview: NO viewmodel")
		get_tree().quit(1)
		return
	print("orb: charge_orb=%s at %s muzzle=%s" % [
		_view._orb != null,
		_view._orb.global_position if _view._orb != null else Vector3.ZERO,
		_view.muzzle_position()])
	var cam := _player.get_node_or_null("Camera3D") as Camera3D
	cam.current = true
	cam.rotation = Vector3(deg_to_rad(-38.0), 0.0, 0.0)
	_view.set_state(Viewmodel.CAST_HOLD)
	# `hide` takes a part name so a single frame can be taken with one layer
	# missing: with three additive/unlit layers stacked it is otherwise
	# impossible to tell which one is washing the rest out.
	var hide := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("hide="):
			hide = a.substr(5)
	if hide != "":
		var node := _view._orb if hide == "Charge" else _view._orb.find_child(hide, true, false)
		if node != null:
			(node as Node3D).visible = false
			print("hid '%s' -> %s visible=%s" % [hide, node.get_path(), node.visible])
		else:
			print("orb_preview: nothing named '%s'" % hide)
	for shot in SHOTS:
		_view.set_charge(float(shot["charge"]))
		var spell := _spell(int(shot["spell"]))
		if spell != null:
			_view.set_spell_colour(spell.colour)
		# Let the colour crossfade finish, so the frame shows the settled orb.
		# Viewmodel._process is driven by hand here: the tree's own frames would
		# also move the hands, and this sheet is about the orb.
		for i in 40:
			_view._process(0.016)
		for i in 4:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var path := "%sorb_%s.png" % [SHOT_DIR, String(shot["name"])]
		get_viewport().get_texture().get_image().save_png(
			ProjectSettings.globalize_path(path))
		print("  %s" % path)
	_view.set_charge(0.0)
	_view.set_spell_colour(Viewmodel.NEUTRAL_CHARGE)
	for i in 40:
		_view._process(0.016)
	await _bolts(cam)

## Fires real projectiles from the muzzle and shoots them in flight.
##
## Distance matters more than anything else here: a bolt 0.4 m from the lens is
## a wall of light and a bolt 12 m away is a dot, and a single "in flight" frame
## only ever shows one of those.
##
## They are fired LEVEL, not down the crosshair. This bench looks at the floor,
## and a bolt fired along a -38 degree view hits the carpet two metres out, so
## every "in flight" frame would be a bolt exploding on the ground.
func _bolts(cam: Camera3D) -> void:
	cam.rotation.x = deg_to_rad(-14.0)
	for shot in BOLTS:
		var enemy := bool(shot["enemy"])
		var from := _view.muzzle_position()
		var last := from
		# Player bolts fly away down the room (-Z is what the eye looks at);
		# enemy bolts come back at us from that same lane.
		var dir := Vector3(0.0, 0.0, -1.0)
		var birth := from
		if enemy:
			dir = Vector3(0.0, 0.0, 1.0)
			# `start` metres BACK along the flight direction, not forward: the
			# bolt has to be born out in the lane the eye is looking at, and the
			# eye looks at -Z.
			birth = from - dir * float(shot["start"])
		var bolt := Projectile.new()
		bolt.setup(birth, dir, GameConfig.PROJECTILE_SPEED, 1.0, enemy)
		add_child(bolt)
		# Real physics frames: the bolt's own _physics_process is what moves it
		# and points the streak.
		var want := float(shot["at"])
		for i in 240:
			await get_tree().physics_frame
			if not is_instance_valid(bolt):
				print("    bolt %s gone after frame %d (last %s)" % [
					shot["name"], i, last])
				break
			last = bolt.global_position
			if bolt.global_position.distance_to(from) >= want:
				break
		if not is_instance_valid(bolt):
			print("  bolt %s died at %.1f m" % [shot["name"], want])
			continue
		for i in 3:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var path := "%sorb_%s.png" % [SHOT_DIR, String(shot["name"])]
		get_viewport().get_texture().get_image().save_png(
			ProjectSettings.globalize_path(path))
		print("  %s (%.1f m)" % [path, bolt.global_position.distance_to(from)])
		bolt.queue_free()
		await get_tree().process_frame
	print("done")
	get_tree().quit(0)

func _spell(index: int) -> BaseSpell:
	if index < 0 or index >= _player.spells.size():
		return null
	return _player.spells[index]
