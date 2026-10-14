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
## Cards can add extra bolts (a small spread fan) and piercing.
##
## `origin` is where the bolt appears -- the charge in the caster's palms, not
## this node -- and the bolt is aimed from THERE at the aim point, not from the
## eye. The eye and the hands are 10 cm and 37 cm apart, so firing parallel to
## the crosshair from between them puts every shot a hand's width low; aiming
## from the muzzle converges on the aim point instead, and the slight upward
## tilt as it leaves the hands is what a shot out of a cupped palm looks like.
func fire(aim_point: Vector3, origin := Vector3.INF) -> void:
	if _cooldown > 0.0:
		return
	_cooldown = FIRE_COOLDOWN
	EffectUtil.sound(get_tree(), &"bolt_fire", global_position)
	if origin == Vector3.INF:
		origin = global_position
	var dir := aim_point - origin
	if dir.length() <= 0.001:
		dir = -global_transform.basis.z
	dir = dir.normalized()
	var dmg := BASE_DAMAGE
	var count := 1
	var pierce := 0
	if _player != null:
		if _player.get("damage_multiplier") != null:
			dmg *= _player.damage_multiplier
		if _player.get("projectile_count") != null:
			count = maxi(1, int(_player.projectile_count))
		if _player.get("projectile_pierce") != null:
			pierce = int(_player.projectile_pierce)
	var host := get_tree().current_scene
	if host == null:
		return
	# Small fan around the aim ray: total spread grows gently with count and
	# the volley stays centred on the crosshair, so extra bolts don't scatter
	# the shot. 0.09 rad (~5°) between neighbours instead of the old
	# 0.12*count fan that sent bolts wildly off-target.
	var spread := 0.09
	for i in count:
		var offset := (float(i) - float(count - 1) * 0.5) * spread
		var shot_dir := dir.rotated(Vector3.UP, offset)
		var bolt := Projectile.new()
		bolt.setup(origin, shot_dir, GameConfig.PROJECTILE_SPEED, dmg, false)
		bolt.pierce = pierce
		host.add_child(bolt)
