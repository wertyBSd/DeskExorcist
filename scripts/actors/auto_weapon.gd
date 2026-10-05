class_name AutoWeapon
## The player's basic attack (GDD section 1): a holy bolt fired along the aim
## line on left click.  Lives as a Node3D child of the Player so it can read the
## player's damage multiplier.
extends Node3D

const BASE_DAMAGE := 10.0
const FIRE_COOLDOWN := 0.25

var _cooldown := 0.0
var _player: Node3D = null

func _ready() -> void:
	_player = get_parent()

func _process(delta: float) -> void:
	if _cooldown > 0.0:
		_cooldown = maxf(0.0, _cooldown - delta)

## Fires a holy bolt toward `aim_point`.  Called by the Player on left click.
func fire(aim_point: Vector3) -> void:
	if _cooldown > 0.0:
		return
	_cooldown = FIRE_COOLDOWN
	EffectUtil.sound(get_tree(), &"bolt_fire", global_position)
	var origin := global_position
	var dir := aim_point - origin
	if dir.length() <= 0.001:
		dir = -global_transform.basis.z
	var dmg := BASE_DAMAGE
	if _player != null and _player.get("damage_multiplier") != null:
		dmg *= _player.damage_multiplier
	var bolt := Projectile.new()
	bolt.setup(origin, dir, GameConfig.PROJECTILE_SPEED, dmg, false)
	var host := get_tree().current_scene
	if host != null:
		host.add_child(bolt)
