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

## Which GDD floor the run is on (0 = lobby, 1 = openspace, 2 = executive).
## Drives the per-floor difficulty profile in GameConfig (E7).  Driven by
## `Game._advance_floor()`; public for tests.
var floor_step := 0

## "Дышащие" волны (GDD Level Design): цикл натиск → передышка → ровный
## темп, чтобы боя не было ни стеной, ни вакуумом. `wave_phase` открыт для
## тестов; баннер показываем на HUD.
var wave_phase := "normal"
var _phase_timer := 0.0
const PHASE_LENGTHS := {"normal": 26.0, "surge": 5.0, "breather": 6.0}
const PHASE_LABELS := {"normal": "Волны возобновились", "surge": "НАТИСК!", "breather": "ПЕРЕДЫШКА"}
## Очередь текущей волны (E3): пачка смешанных типов, выдаётся по одному.
var _wave_queue: Array[Enemy.Kind] = []
var _wave_number := 0

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
	_advance_wave_pattern(delta)
	_timer -= delta
	if _timer > 0.0:
		return
	if wave_phase == "breather":
		return
	_timer = GameConfig.get_spawn_interval(elapsed, floor_step)
	if wave_phase == "surge":
		_timer *= 0.45
	if _alive_count() >= GameConfig.get_max_alive_enemies(elapsed, floor_step):
		return
	_spawn_one()
	if wave_phase == "surge":
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
	var pos := _spawn_position(GameConfig.ENEMY_SPAWN_MIN_DISTANCE)
	var kind := _next_wave_member()
	if randf() < PORTAL_CHANCE:
		var portal := SpawnerPortal.new()
		host.add_child(portal)
		portal.global_position = pos
		get_tree().call_group("hud", "show_dialog", "Портал! Он спавнит демонов — уничтожь его!")
		return
	var demon := Enemy.new()
	demon.configure(kind)
	host.add_child(demon)
	demon.global_position = pos

## Takes the next archetype for the current wave; starts a new mixed wave when
## the queue is empty (E3).
func _next_wave_member() -> Enemy.Kind:
	if _wave_queue.is_empty():
		_build_wave()
	return _wave_queue.pop_front()

## Builds one wave of mixed archetypes. Later waves are bigger and lean harder
## into tanks/bombers/ranged demons.
func _build_wave() -> void:
	_wave_number += 1
	_wave_queue = []
	var size := 3 + int(_pressure * 6)
	for _i in size:
		_wave_queue.append(_pick_kind())
	if is_inside_tree() and get_tree() != null:
		get_tree().call_group("hud", "show_wave_banner", "ВОЛНА %d" % _wave_number)

## Cycles the wave director through normal -> surge -> breather -> normal.
## Public for tests: drives `wave_phase` and emits a HUD banner on change.
func _advance_wave_pattern(delta: float) -> void:
	_phase_timer += delta
	var length: float = PHASE_LENGTHS[wave_phase]
	if _phase_timer < length:
		return
	_phase_timer = 0.0
	match wave_phase:
		"normal":
			wave_phase = "surge"
		"surge":
			wave_phase = "breather"
		_:
			wave_phase = "normal"
	if is_inside_tree() and get_tree() != null:
		get_tree().call_group("hud", "show_wave_banner", PHASE_LABELS[wave_phase])

## A demon may not pop into existence right on top of the caster. Picks a fresh
## edge position until it is at least `min_distance` away, falling back to the
## furthest of a few tries on a cramped map.
func _spawn_position(min_distance: float = 10.0) -> Vector3:
	var player := EffectUtil.player(get_tree())
	if player == null:
		return _random_edge_position()
	var best := _random_edge_position()
	var best_d := -1.0
	for _i in 12:
		var candidate := _random_edge_position()
		var d := candidate.distance_to(player.global_position)
		if d >= min_distance:
			return candidate
		if d > best_d:
			best_d = d
			best = candidate
	return best

## Chooses the archetype for the next spawn.  Two forces shape the mix:
##   * the floor (E7) — its profile biases which archetypes belong here;
##   * run pressure — pressure *shifts* those weights (tanks and ranged demons
##     ramp up late) without ever fully overriding the floor's identity, so the
##     executive deck stays dangerous even early in a run.
func _pick_kind() -> Enemy.Kind:
	var weights := _kind_weights()
	var total := 0.0
	for k in weights:
		total += float(weights[k])
	if total <= 0.0:
		return Enemy.Kind.PAPERWORK_PHANTOM
	var roll := randf() * total
	for k in weights:
		roll -= float(weights[k])
		if roll <= 0.0:
			return k
	# Floating-point drift can leave a sliver: fall back to the last archetype.
	return Enemy.Kind.values()[weights.size() - 1]

## Floor profile weights, bent by run pressure.  Each archetype gets its floor
## share multiplied by a pressure term, then the result is renormalised.
func _kind_weights() -> Dictionary:
	var profile := GameConfig.floor_profile(floor_step)
	var base: Dictionary = profile["weights"]
	var out := {}
	# Pressure nudges every archetype toward its "late-game" self: tougher and
	# slower demons gain ground as the run goes on, chaff loses it.
	var late := {
		Enemy.Kind.WATER_COOLER: 1.0 + _pressure * 0.9,
		Enemy.Kind.PAPERWORK_PHANTOM: maxf(0.25, 1.25 - _pressure * 0.9),
		Enemy.Kind.EMAIL_WRAITH: 1.0 + _pressure * 1.4,
		Enemy.Kind.WIRE_RUNNER: 1.0 + _pressure * 0.2,
		Enemy.Kind.FILING_CABINET_TANK: 1.0 + _pressure * _pressure * 2.0,
		Enemy.Kind.PAPER_BOMBER: 1.0 + _pressure * _pressure * 1.5,
	}
	for k in base:
		out[k] = float(base[k]) * float(late.get(k, 1.0))
	return out

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
