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

const ENEMY_CHASE_SPEED: float = 3.5
const ENEMY_ATTACK_RANGE: float = 1.8
const ENEMY_ATTACK_COOLDOWN: float = 1.2

const PROJECTILE_SPEED: float = 22.0
const PROJECTILE_LIFETIME: float = 3.0
const SOUL_PICKUP_RADIUS: float = 4.0
const SOUL_MAGNET_SPEED: float = 12.0

## Soul gauge (0..1) gained per collected soul; a full gauge unlocks Last Judgement.
const SOUL_GAUGE_PER_ORB: float = 0.05

## Seconds between spawns, ramping from 3.0s to 0.3s over a 10-minute run.
func get_spawn_interval(current_time_seconds: float) -> float:
	var progress: float = clamp(current_time_seconds / 600.0, 0.0, 1.0)
	return lerp(3.0, 0.3, progress)

## Concurrent enemy cap, ramping from 15 to 120 over a 10-minute run.
func get_max_alive_enemies(current_time_seconds: float) -> int:
	var progress: float = clamp(current_time_seconds / 600.0, 0.0, 1.0)
	return int(lerp(15.0, 120.0, progress))
