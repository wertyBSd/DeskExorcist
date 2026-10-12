class_name Game
## The run director (GDD sections 1 and 6).  Owns the 10-minute session timer, the
## XP/level curve and the hand-off to the level-up screen.  Lives on the main
## scene root and joins the "game" group so SoulOrb and HUD can find it.
##
## 3D / first-person port: the arena is a flat floor, so this is a Node3D.
extends Node3D

## GDD section 1: survive exactly ten minutes.
const RUN_LENGTH := 600.0

## Elapsed seconds at which the run moves to the next GDD floor (Level Design.MD:
## arriving lobby -> openspace blocks -> executive deck). The boss then owns the
## final stretch in the executive deck.
const FLOOR_TIMES := [200.0, 400.0]

## XP needed for level 2, and how much more each level costs.
const BASE_XP := 5.0
const XP_GROWTH := 1.35

signal level_gained(level: int)

var time_left := RUN_LENGTH
var level := 1
var xp := 0.0
var xp_to_next := BASE_XP

var _running := true
var _player: Player = null
var _hud: HUD = null
var _level_up: LevelUpScreen = null
var _spawner: EnemySpawner = null
var _level: LevelBuilder = null
## The single final boss, spawned once near the end of the run.
var _boss: Boss = null
var _boss_spawned := false

## Which of LevelBuilder.LEVELS to build for this run. Picked randomly at start
## so every run opens with a different arena.
var level_index := 0
## How many of FLOOR_TIMES have already been crossed this run.
var _floor_step := 0

func _ready() -> void:
	add_to_group("game")
	_wire_nodes()
	# Random starting arena (roguelike variety).
	level_index = randi() % LevelBuilder.LEVELS.size()
	_build_level()
	if _player != null:
		_player.died.connect(_on_player_died)
	if _level_up != null:
		_level_up.reward_taken.connect(_on_reward_taken)

func _wire_nodes() -> void:
	_player = get_node_or_null("Player") as Player
	_hud = get_node_or_null("HUD") as HUD
	_level_up = get_node_or_null("LevelUpScreen") as LevelUpScreen
	_spawner = get_node_or_null("EnemySpawner") as EnemySpawner
	_level = get_node_or_null("Level") as LevelBuilder

## Builds the selected floor and drops the player onto its spawn tile.
func _build_level() -> void:
	if _level == null:
		return
	_level.build(level_index)
	if _player != null:
		_player.global_position = _level.player_spawn

func _process(delta: float) -> void:
	if not _running:
		return
	time_left = maxf(0.0, time_left - delta)
	var elapsed := RUN_LENGTH - time_left
	if _spawner != null and _spawner.has_method("set_pressure"):
		_spawner.call("set_pressure", 1.0 - time_left / RUN_LENGTH)
	# Advance to the next GDD floor at the scheduled elapsed times.
	if _floor_step < FLOOR_TIMES.size() and elapsed >= FLOOR_TIMES[_floor_step]:
		_advance_floor()
	# The finale: one boss for the last stretch of the run, and only once the
	# last floor has been built.  Spawning during a floor transition let the
	# next `_advance_floor()` rebuild the arena underneath the boss, leaving it
	# buried in the new map's geometry (the finale then never engaged).
	if not _boss_spawned and _floor_step >= FLOOR_TIMES.size() and time_left <= GameConfig.BOSS_SPAWN_TIME:
		_spawn_boss()
	if time_left <= 0.0:
		_win()

## Moves the run to the next floor: rebuilds the arena, recentres the caster and
## clears any leftover demons/souls so the new room starts clean. Picks a random
## map from the pool (roguelike variety) instead of a fixed index.
func _advance_floor() -> void:
	_floor_step += 1
	# The wave director retunes to the new floor's difficulty profile (E7).
	if _spawner is EnemySpawner:
		(_spawner as EnemySpawner).floor_step = _floor_step
	# Random map for this floor; avoid repeating the previous one.
	var pool: Array[int] = []
	for i in LevelBuilder.LEVELS.size():
		if i != level_index:
			pool.append(i)
	if not pool.is_empty():
		level_index = pool[randi() % pool.size()]
	var host := get_tree().current_scene
	if host != null:
		for node in host.get_children():
			# The boss is a boss, not a regular demon: floor transitions must
			# not free it (it is meant to outlast the current arena cleanup).
			if node.is_in_group("boss"):
				continue
			if node.is_in_group("enemies") or node is SoulOrb or node is Projectile:
				node.queue_free()
	_build_level()
	# Drop every demon onto the fresh arena edges after a short breather.
	if _hud != null and _hud.has_method("show_floor_banner"):
		_hud.call("show_floor_banner", LevelBuilder.LEVELS[level_index]["name"])

## Spawns the final boss away from the caster and starts its health bar.
func _spawn_boss() -> void:
	_boss_spawned = true
	var host := get_tree().current_scene
	if host == null or _player == null:
		return
	var spawn_pos := _boss_spawn_position()
	_boss = Boss.new()
	host.add_child(_boss)
	_boss.global_position = spawn_pos
	_boss.died.connect(_on_boss_died)
	# Stop the wave director so the finale is about the boss, not the swarm.
	if _spawner != null:
		_spawner.process_mode = Node.PROCESS_MODE_DISABLED
	if _hud != null and _hud.has_method("bind_boss"):
		_hud.call("bind_boss", _boss)

## Picks a walkable ground tile as far from the caster as the arena allows.
## Never blind-offsets into geometry: a boss that materialises inside a wall
## stays stuck there and the finale never starts (see BUGS.md #9).
func _boss_spawn_position() -> Vector3:
	var player_pos := _player.global_position
	var level := get_node_or_null("Level") as LevelBuilder
	if level == null:
		return player_pos + Vector3(1.0, 0.0, 1.0).normalized() * 14.0
	var best := player_pos
	var best_d := -1.0
	for cell in level.free_cells:
		var centre := level.cell_centre(cell.x, cell.y)
		# Real floor only: not a wall/pillar, not a balcony slab or a stair.
		if level.is_blocked(centre) or not level.is_floor(centre):
			continue
		var d: float = centre.distance_to(player_pos)
		if d > best_d:
			best_d = d
			best = centre
	# Scattered over 2-3 tiles so the entrance reads as an ambush rather than a
	# single fixed point, but still on the exact tile centre (no jitter that
	# could bleed into a neighbouring wall cell).
	if best_d > 0.0:
		best += Vector3(randf_range(-0.9, 0.9), 0.0, randf_range(-0.9, 0.9))
	return best

## Killing the boss is the run's climactic victory.
func _on_boss_died(_boss_node: Boss) -> void:
	if not _running:
		return
	_win()

# --- XP and levelling -------------------------------------------------------

## Adds experience from a collected soul and levels up when the bar fills.
func add_xp(amount: float) -> void:
	xp += amount
	while xp >= xp_to_next:
		xp -= xp_to_next
		level += 1
		xp_to_next = roundf(xp_to_next * XP_GROWTH)
		_pending_levels += 1
		# Guarded so the XP-curve unit test, which runs on a detached Game
		# instance, does not call get_tree() off-tree and log an engine error.
		if is_inside_tree():
			EffectUtil.sound(get_tree(), &"level_up")
		level_gained.emit(level)
	_open_level_up_if_needed()

## Fraction of the current level's XP bar that is filled (0 ready .. 1 full).
func xp_ratio() -> float:
	if xp_to_next <= 0.0:
		return 0.0
	return clampf(xp / xp_to_next, 0.0, 1.0)

var _pending_levels := 0

func _open_level_up_if_needed() -> void:
	if _pending_levels <= 0:
		return
	if _level_up == null:
		_pending_levels = 0
		return
	if _level_up.visible:
		return
	_level_up.open()

func _on_reward_taken() -> void:
	_pending_levels = maxi(0, _pending_levels - 1)
	if _pending_levels > 0:
		_open_level_up_if_needed()

# --- Run end states ---------------------------------------------------------

func _on_player_died() -> void:
	if not _running:
		return
	_running = false
	# A dead run must actually stop: freeze the world so the player cannot keep
	# running around, and release the mouse so the banner is readable.
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true
	if _hud != null:
		_hud.show_game_over()

func _win() -> void:
	if not _running:
		return
	_running = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true
	# NG+ loop: the victory raises the persistent level and offers a permanent
	# perk choice before the next run begins.
	var meta := get_node_or_null("/root/Meta")
	if meta != null:
		meta.wins += 1
		meta.total_souls += xp
		meta.ng_level = mini(meta.ng_level + 1, 9)
		meta.save_meta()
	if _hud != null and _hud.has_method("show_postwin_choices"):
		_hud.call("show_postwin_choices")
	else:
		if _hud != null:
			_hud.show_victory()
