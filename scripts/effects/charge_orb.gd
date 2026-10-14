class_name ChargeOrb
## The lit core, its rings and its glow -- one look, two very different uses:
## the charge cupped in the caster's palms, and the holy bolt that leaves it.
##
## Built in code rather than modelled, and that is the point. A bolt lives in
## world space at a different scale and cannot reuse a mesh out of the viewmodel
## .glb; the only way to guarantee the bolt and the orb keep looking like the
## same spell is for them to be the same code. It also keeps the orb out of a
## model whose entire job is to be a pair of hands.
##
## Everything is unlit. A glow that takes lighting is grey on the side facing
## away from the sun, which is most of a sphere at any moment -- and the colour
## goes in ALBEDO, because `SHADING_MODE_UNSHADED` outputs the albedo and skips
## the lighting term entirely, taking `emission` with it.
extends Node3D

## How each part takes the spell's colour.
##
## The core is pulled towards white BEFORE it is brightened, not after. Driving
## a saturated colour up past 1 just clips it: #e0567a at 2.4 is a flat pink,
## and #ffd166 at 2.4 is pure white with the gold gone. Whitening first keeps
## every spell coloured in the middle while still reading as a light source.
const CORE_GAIN := 1.15
const CORE_WHITEN := 0.30
const RING_GAIN := 1.4
const HALO_GAIN := 1.1

## Ring radii as a multiple of the core's. They have to clear the core and each
## other, or the pair reads as one thick hoop instead of a cage.
const RING_A_SCALE := 1.45
const RING_B_SCALE := 1.80
## The glow has to be wider than the outer ring or the ring sits outside its own
## halo and the whole thing reads as a donut.
const HALO_SCALE := 6.0
const MOTE_SCALE := 1.60
const MOTE_COUNT := 3

## Colour shown until something asks for another.
const NEUTRAL := Color("#ffe9a8")

## How fast the rings and motes turn, as a multiplier the caller scales by its
## own charge: 1.0 is a calm idle, 6.0 is a bolt at full tilt.
var spin := 1.0

var colour: Color = NEUTRAL

var _core: MeshInstance3D = null
var _halo: MeshInstance3D = null
var _rings: Node3D = null
var _motes: Node3D = null
var _core_mat: StandardMaterial3D = null
var _ring_mat: StandardMaterial3D = null
var _halo_mat: StandardMaterial3D = null
var _phase := 0.0

## Builds an orb whose glowing core has radius `core_radius` metres. `with_motes`
## adds the circling sparks; a bolt does not need them, it has a trail, and at
## bolt scale they would be bigger than the bolt.
static func build(core_radius: float, with_motes := false) -> ChargeOrb:
	var orb := ChargeOrb.new()
	orb.name = "ChargeOrb"
	orb._assemble(core_radius, with_motes)
	return orb

## World point a projectile should leave from: the middle of the core, pushed a
## little along the orb's own facing so it clears the glow quad instead of
## starting inside its own light.
func muzzle(out_offset := 0.35) -> Vector3:
	return global_position + global_transform.basis.z * (_core_radius() * out_offset)

func _core_radius() -> float:
	if _core == null or _core.mesh == null:
		return 0.0
	return (_core.mesh as SphereMesh).radius

func _assemble(r: float, with_motes: bool) -> void:
	_core_mat = _light_material()
	_ring_mat = _light_material()
	_halo_mat = _light_material()
	_halo_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_halo_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_halo_mat.albedo_texture = TextureLibrary.radial()
	# A glow is a decal: both faces, and it must not write depth or it clips
	# into whatever it is lighting.
	_halo_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_halo_mat.no_depth_test = false
	# Faces the lens on its own. Cheaper and steadier than re-aiming a quad
	# every frame, and the orb is seen from every angle as a bolt flies past.
	_halo_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED

	var core := SphereMesh.new()
	core.radius = r
	core.height = r * 2.0
	core.radial_segments = 12
	core.rings = 8
	_core = MeshInstance3D.new()
	_core.name = "Core"
	_core.mesh = core
	_core.material_override = _core_mat
	_core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_core)

	_rings = Node3D.new()
	_rings.name = "Rings"
	add_child(_rings)
	# A torus is built around +Y, and everything here is authored around +Z --
	# the direction the orb's parent faces. So every ring gets the same quarter
	# turn, and the differences are only the tilt and the spin that stop the
	# pair looking like one circle drawn twice.
	_rings.add_child(_ring(r, RING_A_SCALE, 0.11, Vector3(90.0, 0.0, 18.0)))
	_rings.add_child(_ring(r, RING_B_SCALE, 0.08, Vector3(120.0, 0.0, -24.0)))

	if with_motes:
		_motes = Node3D.new()
		_motes.name = "Motes"
		add_child(_motes)
		for i in MOTE_COUNT:
			var angle := TAU * float(i) / float(MOTE_COUNT)
			var mote := SphereMesh.new()
			mote.radius = r * 0.22
			mote.height = r * 0.44
			mote.radial_segments = 6
			mote.rings = 4
			var mesh := MeshInstance3D.new()
			mesh.mesh = mote
			mesh.position = Vector3(cos(angle) * r * MOTE_SCALE, 0.0,
				sin(angle) * r * MOTE_SCALE)
			mesh.material_override = _ring_mat
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_motes.add_child(mesh)

	var quad := QuadMesh.new()
	quad.size = Vector2(r * HALO_SCALE, r * HALO_SCALE)
	_halo = MeshInstance3D.new()
	_halo.name = "Glow"
	_halo.mesh = quad
	_halo.material_override = _halo_mat
	_halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_halo)
	set_colour(colour)

func _ring(r: float, radius_scale: float, thickness: float, tilt: Vector3) -> MeshInstance3D:
	var torus := TorusMesh.new()
	torus.inner_radius = r * radius_scale
	torus.outer_radius = r * radius_scale + r * thickness
	torus.rings = 14
	torus.ring_segments = 4
	var mesh := MeshInstance3D.new()
	mesh.mesh = torus
	mesh.rotation_degrees = tilt
	mesh.material_override = _ring_mat
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mesh

func _light_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return mat

## Pushes one colour through the core, the rings, the motes and the glow.
## Reads `colour` and never writes it: the owner eases that value itself, so
## there is exactly one place that decides what colour the orb is.
func set_colour(tint: Color) -> void:
	colour = tint
	_paint(_core_mat, tint.lerp(Color.WHITE, CORE_WHITEN), CORE_GAIN)
	_paint(_ring_mat, tint, RING_GAIN)
	_paint(_halo_mat, tint, HALO_GAIN)

func _paint(mat: StandardMaterial3D, tint: Color, gain: float) -> void:
	mat.albedo_color = Color(tint.r * gain, tint.g * gain, tint.b * gain, 1.0)

func _process(delta: float) -> void:
	_phase += delta * spin
	if _rings != null:
		_rings.rotate_y(delta * spin)
		# The wobble is what stops a ring that is square to the lens reading as
		# a drawn circle: it tips away and back as it turns.
		_rings.rotation.x = sin(_phase * 1.3) * 0.18
	if _motes != null:
		_motes.rotate_y(-delta * spin * 1.6)
