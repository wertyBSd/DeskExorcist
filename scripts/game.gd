class_name Game
## The run director (GDD sections 1 and 6).  Owns the 10-minute session timer, the
## XP/level curve and the hand-off to the level-up screen.  Lives on the main
## scene root and joins the "game" group so SoulOrb and HUD can find it.
##
## 3D / first-person port: the arena is a flat floor, so this is a Node3D.
extends Node3D

## GDD section 1: survive exactly ten minutes.
const RUN_LENGTH := 600.0

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
var _spawner: Node = null
var _level: LevelBuilder = null

## Which of LevelBuilder.LEVELS to build for this run.
var level_index := 0

func _ready() -> void:
	add_to_group("game")
	_wire_nodes()
	_build_level()
	if _player != null:
		_player.died.connect(_on_player_died)
	if _level_up != null:
		_level_up.reward_taken.connect(_on_reward_taken)

func _wire_nodes() -> void:
	_player = get_node_or_null("Player") as Player
	_hud = get_node_or_null("HUD") as HUD
	_level_up = get_node_or_null("LevelUpScreen") as LevelUpScreen
	_spawner = get_node_or_null("EnemySpawner")
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
	if _spawner != null and _spawner.has_method("set_pressure"):
		_spawner.call("set_pressure", 1.0 - time_left / RUN_LENGTH)
	if time_left <= 0.0:
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
	if _hud != null:
		_hud.show_game_over()

func _win() -> void:
	_running = false
	if _hud != null:
		_hud.show_victory()
