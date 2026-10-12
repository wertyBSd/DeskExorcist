extends Node
## Global tuning singleton (Autoload: GameConfig).
##
## Every actor reads its numbers from here instead of hardcoding them, so the
## whole game can be re-balanced from one file.  Distances are in metres and
## times in seconds (3D / first-person port).

const MOUSE_SENSITIVITY: float = 0.002
const MOVE_SPEED: float = 6.0
const JUMP_VELOCITY: float = 4.5
const PLAYER_MAX_HEALTH: int = 100

const ENEMY_CHASE_SPEED: float = 3.0
const ENEMY_ATTACK_RANGE: float = 1.8
const ENEMY_ATTACK_COOLDOWN: float = 1.2
const ENEMY_SPAWN_MIN_DISTANCE: float = 10.0

# --- Final boss (ROADMAP Stage C) --------------------------------------------
## The run's finale appears when this many seconds are left on the clock (~9:00).
const BOSS_SPAWN_TIME: float = 60.0
const BOSS_HEALTH: float = 1400.0
const BOSS_SPEED: float = 2.4
const BOSS_CONTACT_DAMAGE: float = 14.0
const BOSS_SLAM_DAMAGE: float = 22.0
const BOSS_SLAM_INTERVAL: float = 3.2
const BOSS_SLAM_RADIUS: float = 4.2
const BOSS_VOLLEY_INTERVAL: float = 5.0
const BOSS_SUMMON_INTERVAL: float = 9.0
const BOSS_XP: float = 40.0

## Seconds of invulnerability after the caster is hit, so a pack of demons
## touching at once cannot stack several hits into the same instant.
const PLAYER_HIT_INVULN: float = 0.4

## How long the caster is stunned after a charging spell is interrupted by a hit
## (GDD section 2). Also carries a penalty cooldown on the interrupted spell.
const INTERRUPT_STUN: float = 0.5

const PROJECTILE_SPEED: float = 22.0
const PROJECTILE_LIFETIME: float = 3.0
const SOUL_PICKUP_RADIUS: float = 4.0
const SOUL_MAGNET_SPEED: float = 12.0

## Soul gauge (0..1) gained per collected soul; a full gauge unlocks Last Judgement.
const SOUL_GAUGE_PER_ORB: float = 0.05

## NG+ level (0 = first run). Winning bumps it by 1, up to 9.
func ng_level() -> int:
	return int(Meta.ng_level)

## Every victory permanently raises the NG+ level and scales pressure:
## +10% enemy HP, +8% enemy damage, 10% faster spawns per step.
func enemy_hp_mult() -> float:
	return 1.0 + 0.10 * float(ng_level())

func enemy_damage_mult() -> float:
	return 1.0 + 0.08 * float(ng_level())

func enemy_spawn_mult() -> float:
	return 1.0 + 0.10 * float(ng_level())

## Per-floor difficulty profile (E7 / Level Design.MD). The three GDD floors
## have distinct identities, so they should not feel like one long arena cut
## into thirds:
##   0 - Spaceport Lobby: wide and forgiving, teaches the loop.
##   1 - Openspace Blocks: the maze floor (paper piles, chairs), so the
##       director leans on runners and bombers.
##   2 - Executive Deck: VIP quarters with columns to break line of sight, so
##       tanks and ranged demons crowd in.
## `spawn_mult` scales the spawn interval (<1 = denser), `cap_mult` scales the
## concurrent-enemy cap, and `weights` biases the archetype mix.
const FLOOR_PROFILES := [
	{
		"name": "Лобби",
		"spawn_mult": 1.25,
		"cap_mult": 0.7,
		"weights": {
			Enemy.Kind.WATER_COOLER: 0.20,
			Enemy.Kind.PAPERWORK_PHANTOM: 0.45,
			Enemy.Kind.EMAIL_WRAITH: 0.05,
			Enemy.Kind.WIRE_RUNNER: 0.15,
			Enemy.Kind.FILING_CABINET_TANK: 0.05,
			Enemy.Kind.PAPER_BOMBER: 0.10,
		},
	},
	{
		"name": "Опенспейс",
		"spawn_mult": 1.0,
		"cap_mult": 1.0,
		"weights": {
			Enemy.Kind.WATER_COOLER: 0.18,
			Enemy.Kind.PAPERWORK_PHANTOM: 0.27,
			Enemy.Kind.EMAIL_WRAITH: 0.12,
			Enemy.Kind.WIRE_RUNNER: 0.20,
			Enemy.Kind.FILING_CABINET_TANK: 0.08,
			Enemy.Kind.PAPER_BOMBER: 0.15,
		},
	},
	{
		"name": "Директорский ярус",
		"spawn_mult": 0.82,
		"cap_mult": 1.25,
		"weights": {
			Enemy.Kind.WATER_COOLER: 0.15,
			Enemy.Kind.PAPERWORK_PHANTOM: 0.18,
			Enemy.Kind.EMAIL_WRAITH: 0.25,
			Enemy.Kind.WIRE_RUNNER: 0.12,
			Enemy.Kind.FILING_CABINET_TANK: 0.20,
			Enemy.Kind.PAPER_BOMBER: 0.10,
		},
	},
]

## Difficulty profile for a progression floor (clamped to the last one).
func floor_profile(floor_step: int) -> Dictionary:
	return FLOOR_PROFILES[clampi(floor_step, 0, FLOOR_PROFILES.size() - 1)]

## Seconds between spawns, ramping from 3.0s to 0.7s over a 10-minute run and
## scaled by the current floor's `spawn_mult`.
func get_spawn_interval(current_time_seconds: float, floor_step: int = 0) -> float:
	var progress: float = clamp(current_time_seconds / 600.0, 0.0, 1.0)
	var profile := floor_profile(floor_step)
	return lerp(3.0, 0.7, progress) * float(profile["spawn_mult"]) / enemy_spawn_mult()

## Concurrent enemy cap, ramping from 10 to 60 over a 10-minute run and scaled
## by the current floor's `cap_mult`. Kept modest for the arena's size: fewer,
## more readable demons beat an unkillable wall of them.
func get_max_alive_enemies(current_time_seconds: float, floor_step: int = 0) -> int:
	var progress: float = clamp(current_time_seconds / 600.0, 0.0, 1.0)
	var profile := floor_profile(floor_step)
	return maxi(1, int(lerp(10.0, 60.0, progress) * float(profile["cap_mult"])))
