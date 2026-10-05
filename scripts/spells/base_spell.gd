class_name BaseSpell
## Base class for every hold-and-release spell (GDD section 5).
##
## Charge/cooldown/damage live here; the actual payload is the overridden
## cast_effect().  Spells are stateless Resources, so the same instance can be
## shared between the player and the ability bar without duplicating state --
## the runtime cooldown timer lives on the Player, not here.

extends Resource

## Key slot this spell is bound to (GDD numbering: 1..9 then 0).
@export var spell_id: int = 1

## Display name shown on the ability bar and on upgrade cards.
@export var display_name: String = ""

## How long the button must be held before the spell is fully charged.
@export var charge_time: float = 1.0

## Lockout after a successful cast.
@export var cooldown: float = 3.0

## Damage dealt before player-wide damage bonuses are applied.
@export var base_damage: float = 10.0

## Accent colour used for the range preview and the ability bar.
@export var colour: Color = Color("#ffe9a8")

## Radius in metres for circular spells; 0 when the spell is not circular.
@export var radius: float = 0.0

## True while the ability is locked behind a level-up card.
var is_locked: bool = false

## How long the cooldown bar should consider this spell busy, in seconds.
## Overridden by spells whose effect lingers (holy ground, censers, ultimate).
func effective_cooldown() -> float:
	return cooldown

## Applies the spell's effect.  `player_position` is the caster's world position,
## `target_position` is the aim point in front of the camera, and `tree` is
## provided so effects can spawn nodes.  (3D / first-person port.)
func cast_effect(_player_position: Vector3, _target_position: Vector3, _tree: SceneTree) -> void:
	# Overridden by every concrete spell.
	pass

## Short line describing the effect, used by the level-up card text.
func describe() -> String:
	return "Заряд %.1fс / КД %.1fс" % [charge_time, cooldown]
