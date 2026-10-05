class_name EffectBase
## Base class for every spell effect node (3D / first-person port).
##
## Effects are created in code by SpellEffects, configured with setup(), and
## free themselves when their animation or lifetime ends.  They use a plain
## Node3D (no physics body) so they never block movement.
##
## Placeholder art is still the procedural textures from PlaceholderArt; they are
## shown on billboarded Sprite3D nodes scaled to world metres, so the same
## hand-painted look carries into 3D until real models are dropped in.
extends Node3D

## Metres per texture pixel for effect billboards (50 px = 1 m).
const PIXEL_SIZE := 0.02

## Adds a billboarded Sprite3D child with the given texture and returns it.
func add_sprite(texture: Texture2D) -> Sprite3D:
	var sprite := Sprite3D.new()
	sprite.texture = texture
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.pixel_size = PIXEL_SIZE
	sprite.shaded = false
	add_child(sprite)
	return sprite

## Flat aura disc lying on the floor at `world_pos`, `radius` metres across.
func add_aura(world_pos: Vector3, radius: float, colour: Color) -> Sprite3D:
	var px := maxi(4, int(radius / PIXEL_SIZE))
	var disc := add_sprite(PlaceholderArt.aura(px, colour))
	disc.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	disc.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	disc.position = to_local(world_pos) + Vector3(0.0, 0.05, 0.0)
	return disc

## Expanding ring centred on a world position, lying flat on the floor.
func pop_ring(world_pos: Vector3, radius: float, colour: Color, duration: float = 0.35) -> void:
	var ring := add_aura(world_pos, radius, colour)
	ring.scale = Vector3(0.15, 0.15, 0.15)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector3.ONE, duration)
	tween.tween_property(ring, "modulate:a", 0.0, duration)
	tween.chain().tween_callback(ring.queue_free)

## A glowing bar spanning the world points `from` -> `to`; the 3D stand-in for
## the old Line2D beams.  Returns the MeshInstance3D so callers can fade it.
func add_bar(from: Vector3, to: Vector3, width: float, colour: Color) -> MeshInstance3D:
	var seg := to - from
	var length := seg.length()
	if length <= 0.001:
		length = 0.001
	var bar := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(width, width, length)
	bar.mesh = mesh
	bar.material_override = _glow_material(colour)
	add_child(bar)
	_orient(bar, from, to)
	return bar

func _glow_material(colour: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = colour
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true
	mat.emission = colour
	mat.emission_energy_multiplier = 2.0
	return mat

func _orient(bar: Node3D, from: Vector3, to: Vector3) -> void:
	var dir := to - from
	if dir.length() <= 0.0001:
		return
	var up := Vector3.UP
	if absf(dir.normalized().dot(up)) > 0.99:
		up = Vector3.RIGHT
	bar.look_at_from_position((from + to) * 0.5, to, up)

## Fades a billboard out and frees it.
func fade_sprite(sprite: Sprite3D, duration: float) -> void:
	var tween := create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, duration)
	tween.tween_callback(sprite.queue_free)

## Fades a glow bar out and frees it.
func fade_bar(bar: MeshInstance3D, duration: float) -> void:
	var mat := bar.material_override as StandardMaterial3D
	if mat == null:
		bar.queue_free()
		return
	var tween := create_tween()
	tween.tween_property(mat, "albedo_color:a", 0.0, duration)
	tween.tween_callback(bar.queue_free)

## Free this effect after a fixed delay.
func self_destruct(delay: float) -> void:
	var tween := create_tween()
	tween.tween_interval(delay)
	tween.tween_callback(queue_free)
