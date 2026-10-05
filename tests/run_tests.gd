extends Node
## Headless test + balance suite for Desk Exorcist.
## Run:  godot --headless --path . res://tests/tests.tscn
## Exit code 0 = all passed, 1 = at least one failure.

var _passed := 0
var _failed := 0

func _ready() -> void:
	print("=== Desk Exorcist test suite ===")
	_test_spawn_curve()
	_test_enemy_cap()
	_test_xp_curve()
	_test_spell_library()
	_test_enemy_archetypes()
	_test_upgrade_pool()
	_test_level_design()
	_test_main_scene_wiring()
	_test_models()
	_test_balance()
	print("=== RESULT: %d passed, %d failed ===" % [_passed, _failed])
	get_tree().quit(0 if _failed == 0 else 1)

func _check(cond: bool, name: String) -> void:
	if cond:
		_passed += 1
		print("  [PASS] ", name)
	else:
		_failed += 1
		print("  [FAIL] ", name)

func _test_spawn_curve() -> void:
	_check(is_equal_approx(GameConfig.get_spawn_interval(0.0), 3.0), "spawn interval @0s = 3.0")
	_check(is_equal_approx(GameConfig.get_spawn_interval(600.0), 0.3), "spawn interval @600s = 0.3")
	_check(GameConfig.get_spawn_interval(600.0) < GameConfig.get_spawn_interval(0.0), "spawn rate ramps up (interval shrinks)")

func _test_enemy_cap() -> void:
	_check(GameConfig.get_max_alive_enemies(0.0) == 15, "alive cap @0s = 15")
	_check(GameConfig.get_max_alive_enemies(600.0) == 120, "alive cap @600s = 120")
	_check(GameConfig.get_max_alive_enemies(300.0) > 15, "alive cap grows over time")

func _test_xp_curve() -> void:
	var g := Game.new()
	g.add_xp(Game.BASE_XP)
	_check(g.level == 2, "5 XP levels up once")
	_check(g.xp_to_next == roundf(Game.BASE_XP * Game.XP_GROWTH), "xp_to_next grows by 1.35x")
	g.add_xp(g.xp_to_next)
	_check(g.level == 3, "second level-up works")
	g.free()

func _test_spell_library() -> void:
	var spells := SpellLibrary.build_all()
	_check(spells.size() == 10, "10 spells registered")
	_check(spells[0].spell_id == 1 and spells[9].spell_id == 0, "slots 0..9 map to keys 1..0")
	_check(spells[0].is_locked == false, "spell 1 unlocked at start")
	_check(spells[2].is_locked == false, "spell 3 unlocked at start")
	_check(spells[3].is_locked == true, "spell 4 locked at start")
	_check(SpellLibrary.find_by_id(spells, 7) != null, "find_by_id(7) resolves")

func _test_enemy_archetypes() -> void:
	var e := Enemy.new()
	e.configure(Enemy.Kind.WATER_COOLER)
	add_child(e)
	_check(e.max_health == 90.0, "water cooler HP = 90")
	_check(e.xp_value == 3.0, "water cooler XP = 3")
	remove_child(e)
	e.free()
	var p := Enemy.new()
	p.configure(Enemy.Kind.PAPERWORK_PHANTOM)
	add_child(p)
	_check(p.max_health == 26.0, "phantom HP = 26")
	_check(p.xp_value == 1.0, "phantom XP = 1")
	remove_child(p)
	p.free()

func _test_upgrade_pool() -> void:
	var player: Player = load("res://scenes/player.tscn").instantiate()
	add_child(player)
	var cards := UpgradePool.build(player)
	_check(cards.size() >= 4, "upgrade pool has >=4 cards")
	var before: float = player.max_health
	cards[0].apply(player)
	_check(player.max_health > before, "first card applies (max_health)")
	remove_child(player)
	player.free()

## Level-design invariants (Level Design.MD section 7): every floor is sealed,
## carries two-tier balconies reachable by a stair, and keeps demon drops on the
## ground plane.
func _test_level_design() -> void:
	_check(LevelBuilder.LEVELS.size() == 3, "three GDD floors registered")
	for i in LevelBuilder.LEVELS.size():
		var level := LevelBuilder.new()
		add_child(level)
		level.build(i)
		var floor_name: String = LevelBuilder.LEVELS[i]["name"]
		var map: Array = LevelBuilder.LEVELS[i]["map"]

		# --- Geometry was actually built -------------------------------------
		_check(level.block_count > 0, "%s has walls/pillars (%d)" % [floor_name, level.block_count])
		_check(level.npc_count > 0, "%s has survivor NPCs (%d)" % [floor_name, level.npc_count])
		_check(level.deck_count > 0, "%s has balcony decks (%d)" % [floor_name, level.deck_count])
		_check(level.stair_count > 0, "%s has stair ramps (%d)" % [floor_name, level.stair_count])

		# --- Border is sealed so nothing walks off the map -------------------
		var sealed := true
		for row in map:
			var r: String = row
			if r.substr(0, 1) != "#" or r.substr(r.length() - 1, 1) != "#":
				sealed = false
		var width := (map[0] as String).length()
		for col in width:
			if (map[0] as String).substr(col, 1) != "#":
				sealed = false
			if (map[map.size() - 1] as String).substr(col, 1) != "#":
				sealed = false
		_check(sealed, "%s outer border is fully sealed" % floor_name)

		# --- Decks and stairs agree with the map -----------------------------
		var decks := 0
		var stairs := 0
		var all_link := true
		for z in map.size():
			for x in width:
				var g: String = (map[z] as String).substr(x, 1)
				if g == "=":
					decks += 1
				elif g == "^":
					stairs += 1
					if not level._connects_to_deck(x, z):
						all_link = false
		_check(level.deck_count == decks, "%s deck tiles == built decks (%d)" % [floor_name, decks])
		_check(level.stair_count == stairs, "%s stair tiles == built stairs (%d)" % [floor_name, stairs])
		_check(all_link, "%s every stair ramp touches a deck tile" % floor_name)

		# --- Spawn pool is ground level only ---------------------------------
		_check(level.spawn_cells.size() < level.free_cells.size(), "%s spawn pool excludes decks (%d of %d)" % [floor_name, level.spawn_cells.size(), level.free_cells.size()])
		var on_ground := true
		for _n in 20:
			var p := level.random_edge_position()
			if absf(p.y - 0.5) > 0.01:
				on_ground = false
		_check(on_ground, "%s demon spawns stay on the ground plane" % floor_name)

		# --- The player actually has a start tile ----------------------------
		var sx := int(floor((level.player_spawn.x + level.half_x) / LevelBuilder.BLOCK))
		var sz := int(floor((level.player_spawn.z + level.half_z) / LevelBuilder.BLOCK))
		var spawn_cell := level.cell_centre(sx, sz)
		_check(spawn_cell.distance_to(level.player_spawn) < 0.5, "%s player spawn sits on a real tile" % floor_name)

		remove_child(level)
		level.free()

## Stage 1.1 wiring (ROADMAP): the main scene must carry a LevelBuilder node so
## Game._build_level() actually raises one of the three GDD floors instead of
## running on the old flat fallback arena.
func _test_main_scene_wiring() -> void:
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	add_child(scene)
	var level := scene.get_node_or_null("Level")
	_check(level != null, "main.tscn contains a Level node")
	_check(level is LevelBuilder, "Level node uses the LevelBuilder script")
	if level is LevelBuilder:
		# Game._ready() already ran _build_level(), so the floor is populated.
		_check(level.get_child_count() > 0, "Level built geometry on scene ready")
		_check(level.block_count > 0, "Level placed wall blocks (%d)" % level.block_count)
		_check(level.spawn_cells.size() > 0, "Level exposes ground spawn cells (%d)" % level.spawn_cells.size())
		_check(level.npc_count > 0, "Level spawned survivor NPCs (%d)" % level.npc_count)
	remove_child(scene)
	scene.free()

## Blender model pipeline (BlenderInstruction.MD): every exported .glb must
## exist, load, and carry real mesh geometry through the loader.
func _test_models() -> void:
	var paths := [
		ModelLibrary.EXORCIST,
		ModelLibrary.WATER_COOLER,
		ModelLibrary.PAPERWORK_PHANTOM,
		ModelLibrary.COPIER_PORTAL,
	]
	for path in paths:
		var label: String = path.get_file()
		_check(ModelLibrary.has_model(path), "%s exists on disk" % label)
		var inst := ModelLibrary.instantiate(path, 1.0)
		_check(inst != null, "%s instantiates" % label)
		if inst != null:
			var meshes := inst.find_children("*", "MeshInstance3D", true, false)
			_check(meshes.size() > 0, "%s carries mesh geometry (%d)" % [label, meshes.size()])
			inst.free()

func _test_balance() -> void:
	var dps := 10.0 / 0.25
	_check(dps >= 30.0 and dps <= 60.0, "auto weapon DPS %.0f in 30-60" % dps)
	_check(26.0 / dps >= 0.4 and 26.0 / dps <= 1.2, "phantom TTK %.2fs in 0.4-1.2" % (26.0 / dps))
	_check(90.0 / dps >= 1.5 and 90.0 / dps <= 4.0, "cooler TTK %.2fs in 1.5-4.0" % (90.0 / dps))
	var run_len := 600.0
	var spawns := 0.0
	var xp_total := 0.0
	var t := 0.0
	while t < run_len:
		var rate := 1.0 / GameConfig.get_spawn_interval(t)
		var cooler_share: float = 0.15 + 0.35 * (t / run_len)
		spawns += rate
		xp_total += rate * (1.0 * (1.0 - cooler_share) + 3.0 * cooler_share)
		t += 1.0
	print("  [INFO] approx spawns/run: %d, XP/run: %d" % [int(spawns), int(xp_total)])
	_check(spawns > 400.0, "enough spawns for a full run (%d)" % int(spawns))
	_check(xp_total > 300.0, "enough XP for progression (%d)" % int(xp_total))
	var g := Game.new()
	var pool := xp_total
	var guard := 0
	while pool >= g.xp_to_next and guard < 500:
		pool -= g.xp_to_next
		g.level += 1
		g.xp_to_next = roundf(g.xp_to_next * Game.XP_GROWTH)
		guard += 1
	print("  [INFO] theoretical max level: %d" % g.level)
	_check(g.level >= 8 and g.level <= 30, "max level %d in 8-30" % g.level)
	g.free()
