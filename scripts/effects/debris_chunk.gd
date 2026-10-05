class_name DebrisChunk
## A single chunk of physics debris flung from a demon death or an explosion
## (ROADMAP Stage 3: "physics-разлёт мусора от взрывов").  A RigidBody3D so it
## tumbles and bounces off the level, then fades and frees itself.
extends RigidBody3D

## Seconds before the chunk despawns.
const LIFETIME := 1.3

var _life := 0.0
var _mesh: MeshInstance3D = null
var _mat: StandardMaterial3D = null

## Flings the chunk in `direction` with `speed` and tints it to the given colour.
func launch(direction: Vector3, speed: float, colour: Color) -> void:
	var size := randf_range(0.12, 0.26)
	_mesh = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(size, size, size)
	_mesh.mesh = box
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = colour
	_mat.emission_enabled = true
	_mat.emission = colour
	_mat.emission_energy_multiplier = 0.8
	_mesh.material_override = _mat
	add_child(_mesh)
	linear_velocity = direction.normalized() * speed
	angular_velocity = Vector3(randf_range(-6, 6), randf_range(-6, 6), randf_range(-6, 6))

func _physics_process(delta: float) -> void:
	_life += delta
	if _life >= LIFETIME:
		queue_free()
		return
	# Fade out over the final third of the lifetime.
	if _mat != null and _life > LIFETIME * 0.66:
		_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mat.albedo_color.a = maxf(0.0, 1.0 - (_life - LIFETIME * 0.66) / (LIFETIME * 0.34))
