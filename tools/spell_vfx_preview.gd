extends Node
## Contact sheet of every spell effect, cast for real in a bare arena.
##
##   godot --path . res://tools/spell_vfx_preview.tscn
##
## Each effect is fired through `spell.cast_effect()` -- the same call the game
## makes -- and photographed a few frames later, because most of these are
## animations and a single screenshot either catches them at frame one (nothing
## has grown yet) or after they are gone.
##
## The point of the sheet is that the ten spells must be told apart at a glance.
## Ten rings, even in ten colours, read as one ring.
##
## Output: temp/vfx_<id>_<n>.png, 1280x720.

const SHOT_DIR := "res://temp/"

## GDD id -> the moments worth photographing, in seconds after the cast.
const SHOTS := {
	1: [0.10, 0.28],   # Word of Purification   - blast
	2: [0.30, 1.20],   # Holy Ground           - rune circle, then motes
	3: [0.14, 0.32],   # Expulsion of Pride    - drain
	4: [0.08, 0.22],   # Wrath of Heaven       - beam
	5: [0.12, 0.34],   # Heavenly Hammer       - column, then impact
	6: [0.10, 0.24],   # Chain Lightning       - arcs
	7: [0.60, 2.00],   # Censer of Vengeance   - orbit, then smoke
	8: [0.08, 0.20],   # Holy Step             - blink
	9: [0.16, 0.40],   # Mirror of the Soul    - dome
	0: [0.14, 0.40],   # Last Judgement        - the purge
}

const AIM := Vector3(0.0, 0.0, -6.0)

var _player: Player = null
var _spells: Array[BaseSpell] = []
var _enemies: Array = []
## GDD id to shoot only that one spell (`-- 5`), or -1 for the whole sheet.
var _only := -1

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHOT_DIR))
	await get_tree().process_frame
	_build_room()
	await get_tree().process_frame
	_player = (load("res://scenes/player.tscn") as PackedScene).instantiate() as Player
	add_child(_player)
	_player.global_position = Vector3(0.0, 0.2, 0.0)
	_spells = SpellLibrary.build_all()
	for s in _spells:
		s.is_locked = false
	_spawn_dummies()
	for i in 4:
		await get_tree().process_frame
	var cam := _player.get_node_or_null("Camera3D") as Camera3D
	if cam != null:
		cam.current = true
		cam.rotation = Vector3.ZERO
	var shot_cam := Camera3D.new()
	add_child(shot_cam)
	shot_cam.fov = 58.0
	shot_cam.global_position = Vector3(7.0, 4.2, 7.5)
	shot_cam.look_at(Vector3(0.0, 1.2, -3.5), Vector3.UP)
	shot_cam.current = true
	for i in 4:
		await get_tree().process_frame
	for a in OS.get_cmdline_user_args():
		if a.is_valid_int():
			_only = int(a)
	for spell_id: int in SHOTS.keys():
		if _only >= 0 and spell_id != _only:
			continue
		await _shoot_one(spell_id, SHOTS[spell_id])
	print("done")
	get_tree().quit(0)

func _build_room() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("#1b1f2e")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("#6d7799")
	e.ambient_light_energy = 0.5
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.transform = Transform3D(Basis(
		Vector3(0.866, 0.0, -0.5), Vector3(-0.354, 0.707, -0.612),
		Vector3(0.354, 0.707, 0.612)), Vector3(0.0, 12.0, 0.0))
	add_child(sun)
	var body := StaticBody3D.new()
	body.collision_layer = 16
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(60.0, 0.2, 60.0)
	shape.shape = box
	shape.position = Vector3(0.0, -0.1, 0.0)
	body.add_child(shape)
	add_child(body)
	var floor := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(60.0, 0.2, 60.0)
	floor.mesh = mesh
	floor.position = Vector3(0.0, -0.1, 0.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("#5d6480")
	floor.material_override = mat
	add_child(floor)

## A cluster of stand-ins so the AoE spells have something to act on: an empty
## room makes half of these look correct and useless.
func _spawn_dummies() -> void:
	var spots := [
		Vector3(2.5, 0.0, -2.0), Vector3(-2.8, 0.0, -3.5),
		Vector3(1.0, 0.0, -7.0), Vector3(-1.5, 0.0, -8.5),
		Vector3(4.5, 0.0, -6.0), Vector3(-4.2, 0.0, -5.0),
	]
	for spot in spots:
		var e := Enemy.new()
		e.configure(Enemy.Kind.PAPERWORK_PHANTOM)
		add_child(e)
		e.global_position = spot
		e.health = 9999.0
		e.max_health = 9999.0
		_enemies.append(e)

func _shoot_one(spell_id: int, moments: Array) -> void:
	var spell := SpellLibrary.find_by_id(_spells, spell_id)
	if spell == null:
		print("  no spell %d" % spell_id)
		return
	for e in _enemies:
		if is_instance_valid(e):
			e.health = 9999.0
	spell.cast_effect(_player.global_position, AIM, get_tree())
	var last := 0.0
	for i in moments.size():
		await get_tree().create_timer(maxf(0.0, float(moments[i]) - last)).timeout
		last = float(moments[i])
		for f in 2:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var path := "%svfx_%d_%d.png" % [SHOT_DIR, spell_id, i]
		var img := get_viewport().get_texture().get_image()
		var err := img.save_png(ProjectSettings.globalize_path(path))
		print("  %s (%dx%d err=%d)" % [path, img.get_width(), img.get_height(), err])
	# Let the next spell start from a clean floor. The effects are added to the
	# current scene, so they have to be swept rather than waited out -- a hammer
	# is still throwing debris two spells later, and a leftover wave reads as part
	# of the next frame.
	_clear_effects()
	await get_tree().create_timer(0.35).timeout

func _clear_effects() -> void:
	for child in get_children():
		if child is EffectBase and child != _player:
			(child as Node).queue_free()
	await get_tree().process_frame
