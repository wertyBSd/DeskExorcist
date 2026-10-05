class_name SpawnerPortal
## A possessed copier that keeps disgorging demons until it is smashed
## (3D / first-person port).  Joins the "enemies" group so spells sweep it too,
## and spawns an Enemy on a timer while it lives.
extends CharacterBody3D

signal died(portal: SpawnerPortal)

const PORTAL_HEALTH := 120.0
const SPAWN_INTERVAL := 3.5
const GRAVITY := 24.0

var health := PORTAL_HEALTH
var max_health := PORTAL_HEALTH
var spawn_kind: Enemy.Kind = Enemy.Kind.PAPERWORK_PHANTOM

var _spawn_timer := SPAWN_INTERVAL
var _mesh: MeshInstance3D = null
var _model: Node3D = null

func _ready() -> void:
	add_to_group("enemies")
	_build_mesh()
	# Prefer the Blender-authored copier (BlenderInstruction.MD lot 4).
	_model = ModelLibrary.attach(self, ModelLibrary.COPIER_PORTAL, 1.6)
	if _model != null and _mesh != null:
		_mesh.visible = false

func _build_mesh() -> void:
	_mesh = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.4, 1.6, 1.0)
	_mesh.mesh = box
	_mesh.position = Vector3(0.0, 0.8, 0.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("#5a1a9c")
	mat.emission_enabled = true
	mat.emission = Color("#a03cff")
	mat.emission_energy_multiplier = 0.6
	_mesh.material_override = mat
	add_child(_mesh)

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0.0
	move_and_slide()
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer = SPAWN_INTERVAL
		_spawn()

func _spawn() -> void:
	var host := get_tree().current_scene
	if host == null:
		return
	var demon := Enemy.new()
	demon.configure(spawn_kind)
	host.add_child(demon)
	demon.global_position = global_position + Vector3(0.0, 0.2, 0.0)

# --- Damage API -------------------------------------------------------------

func take_damage(amount: float, _source: Vector3 = Vector3.INF) -> void:
	health -= amount
	if health <= 0.0:
		died.emit(self)
		queue_free()

func apply_knockback(_from: Vector3, _force: float) -> void:
	# The copier is bolted to the office floor; it does not budge.
	pass

func apply_slow(_ratio: float, _duration: float) -> void:
	# A machine cannot be slowed by holy ground.
	pass
