class_name ModelLibrary
## Loads the low-poly .glb models built by tools/build_models.py
## (see BlenderInstruction.MD) and hands them to actors at runtime.
##
## Every helper is null-safe: if a .glb is missing or fails to load, the actor
## keeps its code-built placeholder mesh, so the game never breaks when the
## asset pipeline has not been run.

extends RefCounted

const DIR := "res://assets/models/"
const EXORCIST := DIR + "exorcist.glb"
const WATER_COOLER := DIR + "water_cooler.glb"
const PAPERWORK_PHANTOM := DIR + "paperwork_phantom.glb"
const COPIER_PORTAL := DIR + "copier_portal.glb"

## True when the exported model exists on disk.
static func has_model(path: String) -> bool:
	return ResourceLoader.exists(path)

## Instantiates `path`, scales it so its tallest axis equals `target_height`
## metres, and drops its feet onto y = 0.  Returns the instance (caller adds it
## to the tree) or null when the asset is unavailable.
static func instantiate(path: String, target_height: float = 0.0) -> Node3D:
	if not ResourceLoader.exists(path):
		return null
	var packed := load(path) as PackedScene
	if packed == null:
		return null
	var root := packed.instantiate() as Node3D
	if root == null:
		return null
	_normalise(root, target_height)
	return root

## Adds a model under `parent`; returns it, or null when unavailable.
static func attach(parent: Node3D, path: String, target_height: float = 0.0) -> Node3D:
	var model := instantiate(path, target_height)
	if model != null:
		parent.add_child(model)
	return model

## Scales + grounds a freshly instantiated model using its mesh bounds.
static func _normalise(root: Node3D, target_height: float) -> void:
	var bounds := _mesh_bounds(root)
	if bounds.size.y > 0.001 and target_height > 0.0:
		var factor := target_height / bounds.size.y
		root.scale = root.scale * factor
		bounds = _mesh_bounds(root)
	# Push the model up so its lowest point rests on the ground plane.
	root.position.y -= bounds.position.y

## World-space AABB of every MeshInstance3D under `root`, in `root`'s space.
static func _mesh_bounds(root: Node3D) -> AABB:
	var found := false
	var result := AABB()
	for child in root.find_children("*", "MeshInstance3D", true, false):
		var mi := child as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var box := mi.get_aabb()
		# Express the child box in root-local space (models only use uniform
		# scale + translation, so a plain offset is accurate enough here).
		var local := box
		local.position += mi.position * root.scale
		if not found:
			result = local
			found = true
		else:
			result = result.merge(local)
	return result
