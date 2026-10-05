class_name EnemySpawner
## Wave director (GDD section 4).  Spawns demons just outside the arena walls
## and ramps up pressure over the ten-minute run, occasionally dropping a
## SpawnerPortal for the player to destroy.
extends Node3D

## Spawn-ring half-extents in metres.  These sit *inside* the arena: the floor
## spans X ±20 / Z ±14 and the walls occupy the outermost ~0.5 m, so spawning
## at ±20/±14 embedded demons in the walls and shoved them off the edge of the
## world (invisible, but still dealing distance-based contact damage).
const SPAWN_HALF_X := 16.0
const SPAWN_HALF_Z := 10.0
const PORTAL_CHANCE := 0.08

var _timer := 0.0
var _pressure := 0.0
var _game: Node = null
var _level: Node = null

func _ready() -> void:
	add_to_group("enemy_spawner")

func _acquire_level() -> void:
	if _level != null and is_instance_valid(_level):
		return
	var levels := get_tree().get_nodes_in_group("level")
	_level = levels[0] if not levels.is_empty() else null

## 0.0 .. 1.0 difficulty dial driven by Game (elapsed / run length).
func set_pressure(value: float) -> void:
	_pressure = clampf(value, 0.0, 1.0)

func _process(delta: float) -> void:
	_acquire_game()
	var elapsed := 0.0
	if _game != null and _game.get("time_left") != null:
		elapsed = maxf(0.0, 600.0 - float(_game.time_left))
	if _pressure <= 0.0 and elapsed > 0.0:
		_pressure = clampf(elapsed / 600.0, 0.0, 1.0)
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = GameConfig.get_spawn_interval(elapsed)
	if _alive_count() >= GameConfig.get_max_alive_enemies(elapsed):
		return
	_spawn_one()

func _acquire_game() -> void:
	if _game != null and is_instance_valid(_game):
		return
	var games := get_tree().get_nodes_in_group("game")
	_game = games[0] if not games.is_empty() else null

func _alive_count() -> int:
	return get_tree().get_nodes_in_group("enemies").size()

func _spawn_one() -> void:
	var host := get_tree().current_scene
	if host == null:
		return
	var pos := _random_edge_position()
	if randf() < PORTAL_CHANCE:
		var portal := SpawnerPortal.new()
		host.add_child(portal)
		portal.global_position = pos
		return
	var demon := Enemy.new()
	# Later in the run the tanky water coolers become more common.
	demon.configure(Enemy.Kind.WATER_COOLER if randf() < 0.15 + _pressure * 0.35 else Enemy.Kind.PAPERWORK_PHANTOM)
	host.add_child(demon)
	demon.global_position = pos

## Picks a spawn point on the outer ring of open tiles using the level's own
## grid, so demons never appear inside a wall or a pillar.  Falls back to a
## plain rectangle when no LevelBuilder is in the tree (e.g. in unit tests).
func _random_edge_position() -> Vector3:
	_acquire_level()
	if _level != null and _level.has_method("random_edge_position"):
		return _level.call("random_edge_position")
	var side := randi() % 4
	match side:
		0:
			return Vector3(-SPAWN_HALF_X, 0.5, randf_range(-SPAWN_HALF_Z, SPAWN_HALF_Z))
		1:
			return Vector3(SPAWN_HALF_X, 0.5, randf_range(-SPAWN_HALF_Z, SPAWN_HALF_Z))
		2:
			return Vector3(randf_range(-SPAWN_HALF_X, SPAWN_HALF_X), 0.5, -SPAWN_HALF_Z)
		_:
			return Vector3(randf_range(-SPAWN_HALF_X, SPAWN_HALF_X), 0.5, SPAWN_HALF_Z)
