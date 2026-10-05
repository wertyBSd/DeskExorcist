class_name SoulOrb
## A saint soul dropped by a slain demon (3D / first-person port).
## It drifts toward the player and grants XP when close, feeding the level-up
## loop owned by Game.
extends Area3D

const COLLECT_DISTANCE := 0.8

var xp_value := 1.0

var _player: Node3D = null
var _mesh: MeshInstance3D = null

## Sets how much XP this orb is worth (called before or after add_child).
func setup(p_xp: float) -> void:
	xp_value = p_xp

func _ready() -> void:
	_mesh = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.15
	sphere.height = 0.3
	_mesh.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("#ffe9a8")
	mat.emission_enabled = true
	mat.emission = Color("#ffe9a8")
	mat.emission_energy_multiplier = 1.5
	_mesh.material_override = mat
	add_child(_mesh)

func _process(delta: float) -> void:
	_acquire_player()
	if _player == null:
		return
	var to := _player.global_position - global_position
	var dist := to.length()
	var radius := GameConfig.SOUL_PICKUP_RADIUS
	if _player.get("pickup_radius") != null:
		radius = _player.pickup_radius
	if dist <= radius and dist > 0.001:
		global_position += (to / dist) * GameConfig.SOUL_MAGNET_SPEED * delta
	if dist <= COLLECT_DISTANCE:
		_collect()

func _acquire_player() -> void:
	if _player != null and is_instance_valid(_player):
		return
	var list := get_tree().get_nodes_in_group("player")
	_player = list[0] if not list.is_empty() else null

func _collect() -> void:
	EffectUtil.sound(get_tree(), &"soul_pickup", global_position)
	var games := get_tree().get_nodes_in_group("game")
	if not games.is_empty() and games[0].has_method("add_xp"):
		games[0].call("add_xp", xp_value)
	# Souls also feed the player's ultimate gauge (Last Judgement).
	if _player != null and is_instance_valid(_player) and _player.has_method("add_soul"):
		_player.call("add_soul", GameConfig.SOUL_GAUGE_PER_ORB)
	queue_free()
