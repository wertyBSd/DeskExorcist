class_name ContactShadow
## The caster's own shadow, placed where the caster can actually see it.
##
## The body has always cast a real shadow, and it still does -- but the sun in
## main.tscn throws it about 1.7 m BEHIND the caster, while the first-person
## camera sits exactly where the body is. Look down and the carpet under the
## caster's feet is bare; spin around and there is a full human silhouette
## lying in the room with nothing attached to it. `tools/shadow_preview.gd`
## is the bench that proved both halves of that (probe mode: caster alone on a
## bare floor -- the third-person frame has the silhouette, the caster's own
## eye has nothing at all).
##
## So the body keeps casting for every camera that can see the body, and THIS
## is what the caster's own eyes get: a soft contact patch pinned to the floor
## between the feet, dropped by a raycast so it stays glued to the carpet on
## stairs, ramps and balconies instead of hovering at the spawn height.
##
## It fades out as the caster leaves the floor. A blob that stays at full
## strength under a jump is worse than no blob at all: it reads as a hole in
## the world rather than as the caster's shadow.
##
## Enemies, the boss and the NPC need none of this -- the player walks up to
## them and their real shadows are already in frame.
extends Node3D

## The footprint of the patch. The caster's capsule is 0.8 m across, and the
## patch is a little wider than that, so the feet read as standing ON something
## rather than hovering over a circle.
const SIZE := Vector2(1.25, 1.05)
## How far up and down the floor probe looks. The caster's origin is at the
## feet, so the reach down has to cover a full jump plus a balcony edge.
const PROBE_UP := 0.25
const PROBE_DOWN := 3.0
## Level geometry only (see LevelBuilder: every wall, stair and floor slab is a
## StaticBody3D on layer 16). Props like chairs are deliberately NOT probed:
## the caster walks through those, and a patch that snapped onto a chair the
## caster is standing inside would jump.
const GROUND_MASK := 16
## Centimetres to lift the decal off the carpet so it does not z-fight.
const LIFT := 0.02
## The colour the carpet is pulled towards under the feet, and how far the pull
## goes at full strength. Alpha blending toward a near-black is what makes the
## patch fade to NOTHING at its rim instead of stopping at "slightly less dark",
## and the strength doubles as the airborne fade.
const SHADE := Color("#171a26")
const MAX_STRENGTH := 0.6
const FADE_START := 0.35
const FADE_END := 2.0
## Texture edge length. The patch is never more than ~1.2 m across and is seen
## from standing height, so 128 px is already past the point where the gradient
## reads as pixels.
const TEX := 128

## One radial gradient shared by every caster in the scene (there is only one,
## but the tests build several players in a row).
static var _blob: ImageTexture = null

var _mesh: MeshInstance3D = null
var _material: StandardMaterial3D = null
var _host: CollisionObject3D = null

## Builds the patch under `host` and returns it. Null only when there is no
## host, so the player never has to guard the call.
static func attach(host: Node3D) -> ContactShadow:
	if host == null:
		return null
	var shadow := ContactShadow.new()
	shadow.name = "ContactShadow"
	shadow._host = host as CollisionObject3D
	host.add_child(shadow)
	return shadow

func _ready() -> void:
	# Children of an already-parented node miss their parent's _ready, so the
	# mesh is built here rather than in a static helper.
	_mesh = MeshInstance3D.new()
	_mesh.name = "Patch"
	var quad := QuadMesh.new()
	quad.size = SIZE
	_mesh.mesh = quad
	_material = _make_material()
	_mesh.material_override = _material
	# A flat decal has nothing to cast, and a decal that casts is a second
	# shadow under the caster's real one.
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Keep it on the default visual layer: the first-person camera culls ONLY
	# the own-body layer, so anything else here is visible to the caster.
	_mesh.layers = 1
	add_child(_mesh)
	_mesh.visible = false

func _physics_process(_delta: float) -> void:
	if _mesh == null:
		return
	var world := get_world_3d()
	if world == null:
		return
	var from := global_position + Vector3.UP * PROBE_UP
	var to := global_position - Vector3.UP * PROBE_DOWN
	var params := PhysicsRayQueryParameters3D.create(from, to, GROUND_MASK)
	if _host != null:
		params.exclude = [_host.get_rid()]
	var hit := world.direct_space_state.intersect_ray(params)
	if hit.is_empty():
		_mesh.visible = false
		return
	var at: Vector3 = hit["position"]
	var normal: Vector3 = hit["normal"]
	var up := normal.normalized() if normal.length() > 0.001 else Vector3.UP
	# The caster's origin is the feet, so the ray's start height is the gap.
	var gap := from.y - at.y
	var strength := 1.0 - clampf(inverse_lerp(FADE_START, FADE_END, gap), 0.0, 1.0)
	if strength * MAX_STRENGTH <= 0.001:
		_mesh.visible = false
		return
	_mesh.visible = true
	_material.albedo_color = Color(SHADE.r, SHADE.g, SHADE.b,
		strength * MAX_STRENGTH)
	_mesh.global_transform = Transform3D(_flat_basis(up), at + up * LIFT)

## A basis that lays the patch flat on whatever it landed on.
##
## QuadMesh faces +Z, so the patch's Z axis has to BE the floor normal; the
## other two lie along the floor. Leaving the basis alone instead leaves the
## quad standing on edge like a billboard, which is invisible from above and
## from a first-person eye -- a patch that measures correct in every property
## and draws nothing at all. The reference axis is chosen off the floor's own up
## so the cross product cannot collapse when the caster stands on a ramp.
func _flat_basis(up: Vector3) -> Basis:
	var ref := Vector3.FORWARD if absf(up.dot(Vector3.UP)) > 0.9 else Vector3.UP
	var x := ref.cross(up).normalized()
	var y := up.cross(x).normalized()
	return Basis(x, y, up)

## Straight alpha blend toward a near-black.
##
## Multiply blend is the obvious choice for a shadow decal, and the dressing
## uses it for its own contact shading -- but in this renderer it multiplies
## RGB and IGNORES alpha, which breaks a soft blob in two ways: with the
## falloff in alpha the decal is invisible, and with a grey tint as the
## strength knob that grey dyes the WHOLE quad, so the patch reads as a
## hard-edged square of flat tint sitting on the carpet. Alpha blending takes
## the strength straight from the alpha channel, so the rim lands exactly on
## the floor colour and there is nothing to see.
##
## Deliberately NO mipmaps either: a mip chain averages the dark core into the
## rim, so at a distance the whole quad samples one flat value. The patch is
## never more than a metre across and is always seen from standing height, so
## plain bilinear costs nothing.
func _make_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = _blob_texture()
	mat.albedo_color = Color(SHADE.r, SHADE.g, SHADE.b, MAX_STRENGTH)
	mat.roughness = 1.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	return mat

## A soft radial falloff: solid under the feet, gone before the quad edge, so
## the patch has no visible rim to give the trick away. Alpha carries the curve
## and RGB stays white, because alpha blending uses the two independently.
static func _blob_texture() -> ImageTexture:
	if _blob != null:
		return _blob
	var img := Image.create_empty(TEX, TEX, false, Image.FORMAT_RGBA8)
	var half := float(TEX) * 0.5
	for y in TEX:
		for x in TEX:
			var d := Vector2(float(x) - half + 0.5, float(y) - half + 0.5).length() / half
			var a := 0.0
			if d < 1.0:
				# Squared falloff: a wide, soft skirt with a denser core, which is
				# how a body actually darkens the floor it is standing on.
				a = pow(1.0 - d, 1.8)
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
	_blob = ImageTexture.create_from_image(img)
	return _blob
