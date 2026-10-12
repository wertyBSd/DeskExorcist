class_name SpellPreview
## The translucent target-zone hint shown while a spell is being charged
## (GDD section 2: "удержание: заклинание визуализирует радиус или сектор
## поражения"). Lives as a child of the caster so it follows them, and is resized
## and re-coloured every time a different spell starts charging.
##
## Three shapes cover the whole GDD spell list:
##   - a floor disc (radius) for circular spells (1, 2, 3, 5, 9);
##   - a forward bar (length + width) for line spells (4, 8);
##   - a small ring marker for auto-target spells (6).
## Built from plain meshes so it needs no .tscn assets.

extends Node3D

const DISC_THICK := 0.04

var _disc: MeshInstance3D = null
var _bar: MeshInstance3D = null
var _ring: MeshInstance3D = null

## Configures the preview for `spell`, aimed along `aim_dir` (world space).
func configure(spell: BaseSpell, aim_dir: Vector3) -> void:
	clear()
	if spell == null:
		return
	var colour := spell.colour
	colour.a = 0.20
	match spell.spell_id:
		4:
			_bar = _make_bar(spell.radius if spell.radius > 0.0 else 1.5, 20.0, colour)
			_aim_bar(aim_dir, 20.0)
		8:
			_bar = _make_bar(1.2, 8.0, colour)
			_aim_bar(aim_dir, 8.0)
		6:
			_ring = _make_disc(14.0, colour)
		0:
			_ring = _make_disc(6.0, _colour(Color("#c2364a")))
		_:
			if spell.radius > 0.0:
				_disc = _make_disc(spell.radius, colour)

## Updates the orientation of a directional preview (line spells).
func update_aim(aim_dir: Vector3) -> void:
	if _bar == null:
		return
	var length := 20.0
	if _bar.mesh is BoxMesh:
		length = (_bar.mesh as BoxMesh).size.z
	_aim_bar(aim_dir, length)

func clear() -> void:
	for n in [_disc, _bar, _ring]:
		if n != null and is_instance_valid(n):
			n.queue_free()
	_disc = null
	_bar = null
	_ring = null

func _make_disc(radius: float, colour: Color) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = DISC_THICK
	mesh.mesh = cyl
	mesh.position = Vector3(0.0, 0.05, 0.0)
	mesh.material_override = _material(colour)
	add_child(mesh)
	return mesh

func _make_bar(width: float, length: float, colour: Color) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(width * 2.0, DISC_THICK, length)
	mesh.mesh = box
	mesh.position = Vector3(0.0, 0.05, 0.0)
	mesh.material_override = _material(colour)
	add_child(mesh)
	return mesh

## Places the bar so it starts at the caster and extends along `aim_dir`.
func _aim_bar(aim_dir: Vector3, length: float) -> void:
	if _bar == null:
		return
	var flat := Vector3(aim_dir.x, 0.0, aim_dir.z)
	if flat.length() <= 0.001:
		flat = Vector3.FORWARD
	flat = flat.normalized()
	_bar.global_position = global_position + flat * (length * 0.5)
	var angle := atan2(flat.x, flat.z)
	_bar.rotation = Vector3(0.0, angle, 0.0)

func _material(colour: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = colour
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true
	mat.emission = colour
	mat.emission_energy_multiplier = 0.6
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat

func _colour(c: Color) -> Color:
	c.a = 0.20
	return c
