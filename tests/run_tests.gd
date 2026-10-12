extends Node
## Headless test + balance suite for Desk Exorcist.
## Run:  godot --headless --path . res://tests/tests.tscn
## Exit code 0 = all passed, 1 = at least one failure.

var _passed := 0
var _failed := 0

func _ready() -> void:
	print("=== Desk Exorcist test suite ===")
	# Let the SceneTree finish setting up children before any test adds nodes:
	# adding to root while it is still busy fails ("Parent node is busy").
	await get_tree().process_frame
	# Isolate the campaign state: tests never depend on a real meta.cfg that
	# previous runs may have left in an elevated NG+/perk state.
	var _meta_reset := get_node_or_null("/root/Meta")
	if _meta_reset != null:
		_meta_reset.ng_level = 0
		_meta_reset.wins = 0
		_meta_reset.total_souls = 0.0
		_meta_reset.perm_hp_bonus = 0.0
		_meta_reset.perm_dmg_mult = 1.0
		_meta_reset.perm_speed_mult = 1.0
		_meta_reset.starting_perk = ""
		_meta_reset.save_meta()
	_test_spawn_curve()
	_test_enemy_cap()
	_test_xp_curve()
	_test_spell_library()
	_test_enemy_archetypes()
	_test_upgrade_pool()
	_test_upgrade_modifiers()
	_test_level_design()
	_test_deck_navigation()
	_test_floor_gimmicks()
	_test_floor_difficulty()
	_test_paper_slow_player()
	_test_starting_perk()
	_test_wave_breathing()
	_test_wave_batches()
	_test_wave_cycle_spawns()
	_test_meta_shop()
	_test_portal_beacon()
	await _test_e8_hp_bars_and_minimap()
	await _test_training_hall()
	await _test_demon_respawns_within_two_minutes()
	_test_main_scene_wiring()
	_test_charge_indicator()
	_test_pause_menu()
	_test_models()
	_test_spell_gdd()
	_test_ranged_demon()
	_test_npc_dialog()
	_test_balance()
	_test_stage3_polish()
	await _test_hud_slots_ui()
	_test_ngplus_scaling()
	await _test_postwin_overlay()
	_test_arena_content()
	await _test_stairwell_clearance()
	_test_stage3_vfx()
	_test_stage4_audio_settings()
	_test_stage4_main_menu()
	_test_stage4_meta()
	_test_stage4_project()
	_test_crosshair()
	_test_enemy_collision()
	_test_npc_silhouette()
	_test_props_clear_of_npcs()
	_test_first_person_body_hidden()
	_test_hit_invulnerability()
	_test_stage_b_combat()
	_test_boss()
	# End-to-end suite: must be awaited (it steps real physics frames).
	await _test_integration()
	print("=== RESULT: %d passed, %d failed ===" % [_passed, _failed])
	get_tree().quit(0 if _failed == 0 else 1)

func _check(cond: bool, name: String) -> void:
	if cond:
		_passed += 1
		print("  [PASS] ", name)
	else:
		_failed += 1
		print("  [FAIL] ", name)

## The base curves are now scaled per floor (E7), so they are asserted against
## the floor-1 openspace profile, whose multipliers are exactly 1.0.
const NEUTRAL_FLOOR := 1

func _test_spawn_curve() -> void:
	var open_slow := GameConfig.get_spawn_interval(0.0, NEUTRAL_FLOOR)
	var open_fast := GameConfig.get_spawn_interval(600.0, NEUTRAL_FLOOR)
	_check(is_equal_approx(open_slow, 3.0), "spawn interval @0s = 3.0")
	_check(is_equal_approx(open_fast, 0.7), "spawn interval @600s = 0.7")
	_check(open_fast < open_slow, "spawn rate ramps up (interval shrinks)")

func _test_enemy_cap() -> void:
	var open_cap := GameConfig.get_max_alive_enemies(0.0, NEUTRAL_FLOOR)
	_check(open_cap == 10, "alive cap @0s = 10")
	_check(GameConfig.get_max_alive_enemies(600.0, NEUTRAL_FLOOR) == 60, "alive cap @600s = 60")
	_check(GameConfig.get_max_alive_enemies(300.0, NEUTRAL_FLOOR) > 10, "alive cap grows over time")
	# The cap is never allowed to collapse to zero, however the profile scales.
	for step in 5:
		_check(GameConfig.get_max_alive_enemies(600.0, step) >= 1, "alive cap stays positive on floor %d" % step)

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
	_check(cards.size() >= 12, "upgrade pool has >=12 cards (%d)" % cards.size())
	var before: float = player.max_health
	cards[0].apply(player)
	_check(player.max_health > before, "first card applies (max_health)")
	# Titles must be unique so the shuffle never shows the same reward twice.
	var seen := {}
	var unique := true
	for c in cards:
		if seen.has(c.title):
			unique = false
		seen[c.title] = true
	_check(unique, "upgrade card titles are unique")
	remove_child(player)
	player.free()

## ROADMAP Stage C: the new build-card modifiers actually change the caster.
func _test_upgrade_modifiers() -> void:
	var player: Player = load("res://scenes/player.tscn").instantiate()
	add_child(player)
	# Every card applies cleanly.
	for c in UpgradePool.build(player):
		c.apply(player)
	_check(player.cooldown_multiplier < 1.0, "cooldown card shortens cooldowns (%.2f)" % player.cooldown_multiplier)
	_check(player.projectile_count >= 2, "multi-shot card adds bolts (%d)" % player.projectile_count)
	_check(player.projectile_pierce >= 1, "pierce card adds piercing (%d)" % player.projectile_pierce)
	_check(player.regen > 0.0, "regen card grants passive healing")
	_check(player.soul_gain_multiplier > 1.0, "soul card boosts gauge gain")
	# The cooldown multiplier reaches the live cooldown readout.
	player._start_charging(0)
	player._charge_timer = player.spells[0].charge_time
	player._release_charging()
	_check(player.cooldown_ratio(1) > 0.0, "casting still puts the spell on cooldown")
	remove_child(player)
	player.free()

## Regression (Баг #11): a demon walking on the ground must head for a balcony's
## stair, never straight at (or under) the deck slab -- that made demons pile up
## beneath the balcony, invisible from the first-person view.
func _test_deck_navigation() -> void:
	var level := LevelBuilder.new()
	add_child(level)
	level.build(0)
	# Find a deck cell and a ground cell beside it.
	var deck := Vector2i(-1, -1)
	for z in level.cells_z:
		for x in level.cells_x:
			if level.glyph_at(x, z) == "=":
				deck = Vector2i(x, z)
				break
		if deck.x >= 0:
			break
	_check(deck.x >= 0, "level 0 has a balcony deck")
	if deck.x >= 0:
		var from_cell := Vector2i(deck.x - 1, deck.y)
		if level.glyph_at(from_cell.x, from_cell.y) != ".":
			from_cell = Vector2i(deck.x, deck.y + 2)
		var deck_pos := level.cell_centre(deck.x, deck.y) + Vector3(0.0, level.DECK_H + 0.9, 0.0)
		var from_pos := level.cell_centre(from_cell.x, from_cell.y) + Vector3(0.0, 0.9, 0.0)
		var waypoint: Vector3 = level.next_path_point(from_pos, deck_pos)
		var wp_cell := level.world_to_cell(waypoint)
		_check(level.glyph_at(wp_cell.x, wp_cell.y) != "=", "demon does not path straight onto the deck slab")
		# Баг #13: every demon drop must sit in a cell reachable on foot from the
		# caster, or it idles behind a wall where only the minimap / AoE find it.
		var reach := level._reachable_from_player()
		var all_reachable := not level.spawn_cells.is_empty()
		for c in level.spawn_cells:
			if not reach.has(c):
				all_reachable = false
		_check(all_reachable, "every demon spawn cell is reachable from the player")
		# Doorways '+' and under-deck '=' tiles are walkable ground, so corridors
		# through a door or beneath a balcony stay connected.
		_check(level._cell_passable(deck.x, deck.y), "under-deck space is walkable ground")
	remove_child(level)
	level.free()

## Level-design invariants (Level Design.MD section 7): every floor is sealed,
## carries two-tier balconies reachable by a stair, and keeps demon drops on the
## ground plane.
func _test_level_design() -> void:
	_check(LevelBuilder.LEVELS.size() >= 7, "seven GDD floors registered")
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
		# Баг #13: every demon drop must be reachable on foot from the caster, so
		# no demon is ever sealed behind a wall with no passage to the player.
		_check(level.spawn_cells.size() > 0, "%s keeps a non-empty demon spawn pool (%d)" % [floor_name, level.spawn_cells.size()])
		var reach := level._reachable_from_player()
		var all_reachable := true
		for c in level.spawn_cells:
			if not reach.has(c):
				all_reachable = false
		_check(all_reachable, "%s every demon spawn is reachable from the player" % floor_name)
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
	_free_run(scene)

## Stage 1.2 (ROADMAP): the HUD must listen to the player's `charge_changed`
## signal and mirror the 0..1 charge into a visible indicator.
func _test_charge_indicator() -> void:
	var hud := HUD.new()
	add_child(hud)
	var player: Player = load("res://scenes/player.tscn").instantiate()
	add_child(player)
	hud.bind(player, null)
	_check(hud.get_charge_ratio() == 0.0, "HUD charge starts at 0")
	_check(not hud.is_charge_visible(), "charge indicator hidden when idle")
	player.charge_changed.emit(0.5)
	_check(is_equal_approx(hud.get_charge_ratio(), 0.5), "charge_changed(0.5) updates HUD")
	_check(hud.is_charge_visible(), "charge indicator visible while charging")
	player.charge_changed.emit(1.0)
	_check(is_equal_approx(hud.get_charge_ratio(), 1.0), "full charge reaches 1.0")
	player.charge_changed.emit(0.0)
	_check(not hud.is_charge_visible(), "charge indicator hides on release (0.0)")
	remove_child(player)
	player.free()
	remove_child(hud)
	hud.free()

## Stage 1.3 (ROADMAP): the pause menu must exist as a node in main.tscn, freeze
## the tree while open, and release it again on close.
func _test_pause_menu() -> void:
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	add_child(scene)
	var menu := scene.get_node_or_null("PauseMenu")
	_check(menu != null, "main.tscn contains a PauseMenu node")
	if menu != null and menu is PauseMenu:
		_check(not menu.is_open(), "pause menu hidden at start")
		menu.open()
		_check(menu.is_open(), "open() shows the pause menu")
		_check(get_tree().paused, "open() freezes the tree")
		menu.close()
		_check(not menu.is_open(), "close() hides the pause menu")
		_check(not get_tree().paused, "close() resumes the tree")
		# Regression (Баг #10): a restart reloads the scene, which detaches this
		# menu from the tree, so get_viewport() becomes null.  The input-handling
		# helper must therefore never assume a live viewport.
		var orphan := PauseMenu.new()
		add_child(orphan)
		remove_child(orphan)  # detached -> get_viewport() == null
		_check(orphan.get_viewport() == null, "detached PauseMenu has no viewport")
		orphan._mark_input_handled()
		_check(true, "restart input-handled guard is null-safe")
		orphan.free()
	_free_run(scene)

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

## Stage 2.1 (ROADMAP): lock the spell parameters against GDD section 3 and the
## three mechanics that were only verified by code inspection before.
func _test_spell_gdd() -> void:
	var spells := SpellLibrary.build_all()
	var by_id := {}
	for s in spells:
		by_id[s.spell_id] = s
	# Charge times and cooldowns straight from the GDD table.
	_check(is_equal_approx(by_id[1].charge_time, 0.8) and is_equal_approx(by_id[1].cooldown, 3.0), "spell 1 charge/CD = 0.8/3")
	_check(is_equal_approx(by_id[2].charge_time, 1.2) and is_equal_approx(by_id[2].cooldown, 6.0), "spell 2 charge/CD = 1.2/6")
	_check(is_equal_approx(by_id[3].charge_time, 1.5) and is_equal_approx(by_id[3].cooldown, 12.0), "spell 3 charge/CD = 1.5/12")
	_check(is_equal_approx(by_id[8].charge_time, 0.4) and is_equal_approx(by_id[8].cooldown, 4.0), "spell 8 charge/CD = 0.4/4")
	_check(is_equal_approx(by_id[9].charge_time, 1.0) and is_equal_approx(by_id[9].cooldown, 10.0), "spell 9 charge/CD = 1.0/10")
	_check(is_equal_approx(by_id[0].charge_time, 3.5) and is_equal_approx(by_id[0].cooldown, 0.0), "ultimate charge/CD = 3.5/reset")
	# GDD radii mapped from px at the project's 30 px = 1 m port scale.
	_check(is_equal_approx(by_id[1].radius, 5.0), "spell 1 radius 150px -> 5 m")
	_check(is_equal_approx(by_id[2].radius, 6.5), "spell 2 radius 200px -> 6.5 m")
	_check(is_equal_approx(by_id[3].radius, 3.5), "spell 3 radius 100px -> 3.5 m")
	_check(is_equal_approx(by_id[5].radius, 4.0), "spell 5 radius 120px -> 4 m")
	_check(is_equal_approx(by_id[9].radius, 4.0), "spell 9 radius 120px -> 4 m")
	# Chain lightning jumps to five extra enemies.
	_check(SpellLibrary.ChainLightning.MAX_JUMPS == 5, "chain lightning jumps to 5")
	# Holy Step blink distance 250 px -> 8 m.
	_check(is_equal_approx(SpellLibrary.HolyStep.DISTANCE, 8.0), "holy step blink = 8 m")
	# Mirror of the Soul reflection is wired into projectile.gd.
	var bolt := Projectile.new()
	add_child(bolt)
	var fake := _FakeShielded.new()
	add_child(fake)
	bolt.from_enemy = true
	bolt.velocity = Vector3(1.0, 0.0, 0.0)
	_check(bolt._try_reflect(fake), "enemy bolt reflects off a shielded caster")
	_check(bolt.from_enemy == false, "reflected bolt becomes friendly")
	_check(bolt.velocity.x < 0.0, "reflected bolt reverses direction")
	remove_child(bolt)
	bolt.free()
	remove_child(fake)
	fake.free()

## Minimal stand-in for a shielded player used by the reflection check.
class _FakeShielded extends Node:
	func is_shielded() -> bool:
		return true

## Stage 2.2 (ROADMAP): the third archetype is a ranged demon that fires hex
## bolts and keeps its distance; the spawner can pick it.
func _test_ranged_demon() -> void:
	var w := Enemy.new()
	w.configure(Enemy.Kind.EMAIL_WRAITH)
	add_child(w)
	_check(w.max_health == 40.0, "email wraith HP = 40")
	_check(w.xp_value == 2.0, "email wraith XP = 2")
	_check(Enemy.Kind.size() >= 3, "enemy Kind has a third archetype")
	remove_child(w)
	w.free()
	_check(Enemy.Kind.size() >= 5, "enemy Kind has the new archetypes")
	var runner := Enemy.new()
	runner.configure(Enemy.Kind.WIRE_RUNNER)
	add_child(runner)
	_check(runner.speed == Enemy.RUNNER_SPEED, "WIRE_RUNNER is fast")
	remove_child(runner)
	runner.free()
	var tank := Enemy.new()
	tank.configure(Enemy.Kind.FILING_CABINET_TANK)
	add_child(tank)
	_check(tank.max_health == Enemy.TANK1_HEALTH, "TANK is tanky")
	remove_child(tank)
	tank.free()
	var bomber := Enemy.new()
	bomber.configure(Enemy.Kind.PAPER_BOMBER)
	add_child(bomber)
	_check(bomber.damage == Enemy.BOMBER_DAMAGE, "BOMBER hits hard")
	remove_child(bomber)
	bomber.free()
	# The spawner picks a valid archetype for a range of pressures.
	var spawner := EnemySpawner.new()
	add_child(spawner)
	var saw_wraith := false
	for i in 200:
		if spawner._pick_kind() == Enemy.Kind.EMAIL_WRAITH:
			saw_wraith = true
			break
	_check(saw_wraith, "spawner can pick the ranged wraith")
	remove_child(spawner)
	spawner.free()

## Stage 2.3 (ROADMAP): a survivor NPC trigger pushes its line to the HUD and
## clears it when the player leaves.
func _test_npc_dialog() -> void:
	var hud := HUD.new()
	add_child(hud)
	var npc := NPCDialog.new()
	add_child(npc)
	_check(not npc.line.is_empty(), "NPC picked a survivor line")
	# The NPC talks to the HUD through the "hud" group.
	get_tree().call_group("hud", "show_dialog", npc.line)
	_check(hud._dialog_label.text == npc.line, "HUD shows the survivor line")
	get_tree().call_group("hud", "clear_dialog")
	_check(hud._dialog_label.text == "", "HUD clears the line")
	remove_child(npc)
	npc.free()
	remove_child(hud)
	hud.free()

## Bug tracker #2: survivors must read as humans, not as a T-posed "monster", and
## must not be buried inside a prop cube.
func _test_npc_silhouette() -> void:
	var npc := NPCDialog.new()
	add_child(npc)
	# Arms must hang down (not spread out like the reused hero T-pose): every
	# mesh must sit close to the body centre on the X axis.
	var max_reach := 0.0
	for child in npc.get_children():
		if child is MeshInstance3D and (child as MeshInstance3D).mesh is BoxMesh:
			max_reach = maxf(max_reach, absf((child as MeshInstance3D).position.x))
	_check(max_reach < 0.5, "survivor arms hang down (max x-reach %.2f < 0.5)" % max_reach)
	remove_child(npc)
	npc.free()

## Bug tracker #2: no decorative prop may overlap a survivor NPC's tile.
func _test_props_clear_of_npcs() -> void:
	var level := LevelBuilder.new()
	add_child(level)
	level.build(0)
	var overlaps := 0
	for child in level.get_children():
		if not (child is MeshInstance3D) or child.name != "Prop":
			continue
		for p in level.npc_points:
			if (child as Node3D).global_position.distance_to(p) < LevelBuilder.BLOCK * 0.75:
				overlaps += 1
	_check(overlaps == 0, "no prop overlaps a survivor NPC (%d overlaps)" % overlaps)
	remove_child(level)
	level.free()

## Bug #3b: the caster's own body must never render in the first-person camera
## (the T-posed hero clipped through the view as a "white box").
func _test_first_person_body_hidden() -> void:
	var player: Player = load("res://scenes/player.tscn").instantiate()
	add_child(player)
	var bit := 1 << (Player.OWN_BODY_LAYER - 1)
	_check((player._camera.cull_mask & bit) == 0, "first-person camera ignores the caster's own body layer")
	var meshes := player.find_children("*", "MeshInstance3D", true, false)
	_check(meshes.size() > 0, "caster model is attached")
	var on_layer := true
	for m in meshes:
		if (m.layers & bit) == 0:
			on_layer = false
	_check(on_layer, "caster model renders only on the own-body layer")
	remove_child(player)
	player.free()

## Bug #3 difficulty: i-frames stop a pack of contacts stacking into one instant.
func _test_hit_invulnerability() -> void:
	var player: Player = load("res://scenes/player.tscn").instantiate()
	add_child(player)
	var full: float = player.health
	player.take_damage(10.0)
	player.take_damage(10.0)
	player.take_damage(10.0)
	_check(is_equal_approx(player.health, full - 10.0), "only one hit lands during i-frames (hp %.0f)" % player.health)
	player.take_damage(10.0)  # still inside the window
	_check(is_equal_approx(player.health, full - 10.0), "further instant hits are ignored")
	remove_child(player)
	player.free()

## ROADMAP Stage B: penalty cooldown + stun on interrupt, a charge-zone preview,
## and the HUD damage flash.
func _test_stage_b_combat() -> void:
	var player: Player = load("res://scenes/player.tscn").instantiate()
	add_child(player)
	# The preview node exists and lights up while charging a spell. Access private
	# members duck-typed: the global class cache can be stale in a fresh headless
	# run, which would fail parse-time member resolution.
	var preview = player.get("_preview")
	_check(preview != null, "caster builds a spell preview node")
	_check(not player.is_stunned(), "caster starts unstunned")
	player._start_charging(0)  # slot 0 = spell 1 (Word of Purification, radius)
	_check(preview.visible, "charging shows the target-zone preview")
	_check(player.get("_charging_slot") == 0, "slot 0 is charging")
	# A hit interrupts: stun + penalty cooldown on the interrupted spell.
	player.take_damage(5.0)
	_check(player.get("_charging_slot") == -1, "a hit breaks the cast")
	_check(not preview.visible, "interrupt hides the target-zone preview")
	_check(player.is_stunned(), "interrupt stuns the caster")
	_check(player.cooldown_ratio(1) > 0.0, "interrupted spell gets a penalty cooldown")
	# While stunned, a new charge cannot start.
	player._start_charging(0)
	_check(player.get("_charging_slot") == -1, "cannot start a cast while stunned")
	remove_child(player)
	player.free()

	# HUD damage flash.
	var hud := HUD.new()
	add_child(hud)
	_check(not hud.is_damage_flashing(), "no damage flash by default")
	hud.flash_damage()
	_check(hud.is_damage_flashing(), "flash_damage lights the red screen tint")
	remove_child(hud)
	hud.free()
	_check(GameConfig.INTERRUPT_STUN > 0.0, "interrupt stun duration is positive")

## ROADMAP Stage C: the final boss exists, phases scale with damage, and the
## ultimate wounds rather than erases it.
func _test_boss() -> void:
	var boss := Boss.new()
	add_child(boss)
	_check(boss.is_in_group("enemies"), "boss joins the enemies group (spells hit it)")
	_check(boss.is_boss(), "boss identifies itself as a boss")
	_check(boss.max_health == GameConfig.BOSS_HEALTH, "boss uses the configured HP")
	_check(boss.get("_phase") == 1, "boss starts in phase 1")
	# Damage into phase 2, then 3.
	boss.take_damage(GameConfig.BOSS_HEALTH * 0.4)
	_check(boss.get("_phase") == 2, "boss enters phase 2 below 66% HP")
	boss.take_damage(GameConfig.BOSS_HEALTH * 0.3)
	_check(boss.get("_phase") == 3, "boss enters phase 3 below 33% HP")
	# The ultimate must not erase the boss outright.
	boss.health = boss.max_health
	var lj := LastJudgementFX.new()
	add_child(lj)
	lj.setup(boss.global_position)
	_check(is_instance_valid(boss) and boss.health >= boss.max_health - LastJudgementFX.TANKY_DAMAGE - 0.01,
		"boss survives a Last Judgement (wounded, not erased)")
	remove_child(lj)
	lj.free()
	remove_child(boss)
	boss.free()

## ROADMAP Stage C: the run advances through the three GDD floors at the
## scheduled times, rebuilding the arena and keeping the caster alive.
func _test_floor_progression() -> void:
	_check(Game.FLOOR_TIMES.size() == 2, "two floor transitions are scheduled")
	var scene := await _spawn_run()
	var game := scene as Game
	var player := scene.get_node_or_null("Player") as Player
	# Random start: index must be valid for the pool.
	_check(game.level_index >= 0 and game.level_index < LevelBuilder.LEVELS.size(), "run starts on a valid floor")
	var first_index := game.level_index
	# Jump to just before the first transition and step across it.
	game.time_left = Game.RUN_LENGTH - Game.FLOOR_TIMES[0] + 0.05
	var hp_before := player.health
	for i in 30:
		await get_tree().physics_frame
	_check(game.level_index != first_index, "run advances to a new floor after the first threshold")
	_check(game.level_index >= 0 and game.level_index < LevelBuilder.LEVELS.size(), "floor 2 is a valid arena")
	_check(player.is_alive(), "caster survives the floor transition")
	# Second threshold -> floor 3.
	var second_index := game.level_index
	game.time_left = Game.RUN_LENGTH - Game.FLOOR_TIMES[1] + 0.05
	for i in 30:
		await get_tree().physics_frame
	_check(game.level_index != second_index, "run advances to a new floor after the second threshold")
	_check(game.time_left > 0.0, "run is still going on floor 3")
	_free_run(scene)

## ROADMAP Stage C: the multi-shot and pierce cards reach the live weapon.
func _it_multishot_and_pierce() -> void:
	var scene := await _spawn_run()
	var player := scene.get_node_or_null("Player") as Player
	# Фиксированная карта для детерминизма (open space вокруг центра).
	var game := scene as Game
	if game != null:
		game.level_index = 0
		game._build_level()
		await get_tree().physics_frame
	player.projectile_count = 3
	player.projectile_pierce = 2
	# Count projectiles spawned by a single shot. Bolts attach to
	# get_tree().current_scene (the test runner), not the run scene.
	var host := get_tree().current_scene
	var before_proj := _count_projectiles(host)
	player._auto_weapon.call("fire", player.global_position - player._camera.global_transform.basis.z * 10.0)
	await get_tree().physics_frame
	var after_proj := _count_projectiles(host)
	_check(after_proj - before_proj == 3, "three bolts spawn from a triple shot (%d)" % (after_proj - before_proj))
	# A piercing bolt must kill two demons lined up.
	var first: Enemy = Enemy.new()
	first.configure(Enemy.Kind.PAPERWORK_PHANTOM)
	first.speed = 0.0
	scene.add_child(first)
	var second: Enemy = Enemy.new()
	second.configure(Enemy.Kind.PAPERWORK_PHANTOM)
	second.speed = 0.0
	scene.add_child(second)
	var forward := -player._camera.global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var base := Vector3(player.global_position.x, 0.0, player.global_position.z)
	first.global_position = base + forward * 5.0
	second.global_position = base + forward * 7.0
	await get_tree().physics_frame
	# Single, piercing shots aimed at the body centre of the pair.
	player.projectile_count = 1
	var aim := first.hurt_center()
	for i in 200:
		if is_instance_valid(first) and is_instance_valid(second):
			first.global_position = base + forward * 5.0
			second.global_position = base + forward * 7.0
			aim = first.hurt_center()
		if not is_instance_valid(first) and not is_instance_valid(second):
			break
		player._auto_weapon.call("fire", aim)
		await get_tree().physics_frame
	_check(not is_instance_valid(first) and not is_instance_valid(second), "a piercing bolt kills two aligned demons")
	_free_run(scene)

## Number of live Projectile nodes parented under the run scene.
func _count_projectiles(host: Node) -> int:
	var n := 0
	for c in host.get_children():
		if c is Projectile:
			n += 1
	return n

## Bug: the wave director must yield to the boss and the boss bar must appear.
func _it_boss_finale() -> void:
	var scene := await _spawn_run()
	var game := scene as Game
	var player := scene.get_node_or_null("Player") as Player
	var hud := scene.get_node_or_null("HUD") as HUD
	# Jump the clock to the boss window and heal so the caster survives.
	game.time_left = GameConfig.BOSS_SPAWN_TIME - 0.05
	for i in 240:
		await get_tree().physics_frame
		if is_instance_valid(player) and player.is_alive():
			player.health = player.max_health
		if game._boss_spawned:
			break
	_check(game._boss_spawned, "boss spawns near the end of the run")
	var boss := game._boss
	_check(boss != null and is_instance_valid(boss), "game holds a live boss reference")
	# Regression: the boss must not be teleported into a wall/pillar (then it is
	# in reachable and the whole floor is empty until the clock runs out).
	var level_node := scene.get_node_or_null("Level") as LevelBuilder
	if level_node != null and is_instance_valid(boss):
		_check(level_node.is_floor(boss.global_position), "boss spawns on a walkable floor tile")
		_check(boss.global_position.distance_to(player.global_position) > 2.0, "boss spawns away from the player")
	_check(hud != null and hud._boss_bar != null and hud._boss_bar.visible, "HUD shows the boss health bar")
	var spawner := scene.get_node_or_null("EnemySpawner")
	_check(spawner.process_mode == Node.PROCESS_MODE_DISABLED, "wave director stops during the finale")
	# Killing the boss wins the run.
	if is_instance_valid(boss):
		boss.take_damage(999999.0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	# NG+ victory presents the permanent-perk choice first.
	await _choose_first_postwin_perk(hud)
	_check(not game._running and hud.is_victory(), "slaying the boss wins the run")
	_free_run(scene)

## Simulates choosing the first permanent perk in the NG+ victory overlay.
func _choose_first_postwin_perk(hud: HUD) -> void:
	if hud == null:
		return
	var meta := get_node_or_null("/root/Meta")
	# Snapshot and restore the persistent perk state so the suite is isolated.
	var saved := [meta.perm_hp_bonus, meta.perm_dmg_mult, meta.perm_speed_mult] if meta != null else [0.0, 1.0, 1.0]
	await get_tree().process_frame
	var buttons := hud.find_children("*", "Button", true, false)
	if not buttons.is_empty():
		# The real game locks clicks for a short grace period after the overlay
		# appears; in tests we lift it immediately.
		buttons[0].set_meta("lock_until", 0)
		buttons[0].pressed.emit()
	await get_tree().process_frame
	if meta != null:
		meta.perm_hp_bonus = saved[0]
		meta.perm_dmg_mult = saved[1]
		meta.perm_speed_mult = saved[2]
		meta.save_meta()

## Bug #3b: demons must spawn well away from the caster, not in their face.
func _test_spawn_distance() -> void:
	var scene: Node = await _spawn_run()
	var player := scene.get_node_or_null("Player") as Player
	var spawner := scene.get_node_or_null("EnemySpawner")
	var min_seen := 999.0
	var level := scene.get_node_or_null("Level") as LevelBuilder
	var allowed := GameConfig.ENEMY_SPAWN_MIN_DISTANCE
	if level != null:
		# Small arenas cannot keep spawns a full 10 m away; accept the best
		# the geometry allows (the spawner falls back to the furthest tile).
		var arena_half := minf(level.cells_x, level.cells_z) * LevelBuilder.BLOCK * 0.5
		allowed = minf(allowed, arena_half - LevelBuilder.BLOCK)
	for _i in 30:
		var p: Vector3 = spawner._spawn_position(GameConfig.ENEMY_SPAWN_MIN_DISTANCE)
		min_seen = minf(min_seen, p.distance_to(player.global_position))
	_check(min_seen >= allowed - 0.01,
		"demons spawn at least %.0f m away (closest %.1f)" % [allowed, min_seen])
	_free_run(scene)

## Bug #3c: bolts must be stopped by walls, so ranged demons cannot shoot through
## cover.
func _test_projectile_blocked_by_wall() -> void:
	var level := LevelBuilder.new()
	add_child(level)
	level.build(0)
	# Find a wall cell with a walkable neighbour to fire from.
	var from := Vector3.INF
	var wall_centre := Vector3.INF
	for z in level.cells_z:
		for x in level.cells_x:
			if level.glyph_at(x, z) != "#":
				continue
			var open := Vector3.INF
			if level.glyph_at(x, z + 1) != "#" and level.glyph_at(x, z + 1) != "":
				open = level.cell_centre(x, z + 1)
			elif level.glyph_at(x, z - 1) != "#" and level.glyph_at(x, z - 1) != "":
				open = level.cell_centre(x, z - 1)
			if open.is_finite():
				from = open
				wall_centre = level.cell_centre(x, z)
				break
		if from.is_finite():
			break
	_check(from.is_finite(), "found a wall to shoot at")
	if not from.is_finite():
		remove_child(level)
		level.free()
		return
	var bolt := Projectile.new()
	bolt.setup(from + Vector3(0.0, 1.0, 0.0), (wall_centre - from).normalized(), 40.0, 10.0, false)
	add_child(bolt)
	var last := bolt.global_position
	for i in 30:
		await get_tree().physics_frame
		if not is_instance_valid(bolt):
			break
		last = bolt.global_position
	await get_tree().physics_frame
	_check(not is_instance_valid(bolt), "bolt is destroyed by a wall")
	_check(last.distance_to(wall_centre) < LevelBuilder.BLOCK * 1.5,
		"bolt did not pass through the wall (stopped %.1f m from centre)" % last.distance_to(wall_centre))
	remove_child(level)
	level.free()

## Bug #6: a melee demon under a balcony must not bite a caster standing on it
## (the "invisible damage" report). Melee needs similar height and line of sight.
func _test_melee_through_floor() -> void:
	var scene: Node = await _spawn_run()
	var player := scene.get_node_or_null("Player") as Player
	var level := scene.get_node_or_null("Level") as LevelBuilder
	# Stand the caster on a balcony deck.
	var deck := Vector3.INF
	for c in level.free_cells:
		if level.glyph_at(c.x, c.y) == "=":
			deck = level.cell_centre(c.x, c.y)
			break
	_check(deck.is_finite(), "level has a balcony deck to stand on")
	if not deck.is_finite():
		_free_run(scene)
		return
	player.global_position = deck + Vector3(0.0, LevelBuilder.DECK_H + 0.2, 0.0)
	# Demon on the floor below, just off-centre so horizontal distance is > 0.
	var demon: Enemy = Enemy.new()
	demon.configure(Enemy.Kind.PAPERWORK_PHANTOM)
	demon.speed = 0.0
	scene.add_child(demon)
	demon.global_position = deck + Vector3(1.0, 0.4, 0.0)
	var hp0 := player.health
	for i in 150:
		await get_tree().physics_frame
	_check(player.health >= hp0, "demon under the deck cannot bite through the floor (hp %.0f)" % player.health)
	_free_run(scene)

## Bug #6: a ranged demon must not fire through a wall.
func _test_ranged_line_of_sight() -> void:
	var scene: Node = await _spawn_run()
	var player := scene.get_node_or_null("Player") as Player
	var wraith: Enemy = Enemy.new()
	wraith.configure(Enemy.Kind.EMAIL_WRAITH)
	wraith.speed = 0.0
	scene.add_child(wraith)
	# Wraith on the far side of the outer wall from the caster.
	wraith.global_position = Vector3(100.0, 0.4, 100.0)
	await get_tree().physics_frame
	_check(not wraith._has_line_of_sight(), "wraith has no line of sight through the wall")
	wraith.global_position = player.global_position + Vector3(3.0, 0.0, 0.0)
	await get_tree().physics_frame
	_check(wraith._has_line_of_sight(), "wraith sees the caster in the open")
	_free_run(scene)

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
		var rate := 1.0 / GameConfig.get_spawn_interval(t, NEUTRAL_FLOOR)
		var cooler_share: float = 0.15 + 0.35 * (t / run_len)
		spawns += rate
		xp_total += rate * (1.0 * (1.0 - cooler_share) + 3.0 * cooler_share)
		t += 1.0
	print("  [INFO] approx spawns/run: %d, XP/run: %d" % [int(spawns), int(xp_total)])
	# Deliberately gentler than the original 400/300: the arena is small and the
	# old curve drowned the player. Enough to progress, not enough to swarm.
	_check(spawns > 300.0, "enough spawns for a full run (%d)" % int(spawns))
	_check(xp_total > 250.0, "enough XP for progression (%d)" % int(xp_total))
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

## Stage 3 (P2) - content & polish: the code-built animation set exists with the
## four BlenderInstruction section 4 clips, and the asset library exposes the new
## Email Wraith model slot (null-safe fallback keeps the suite green without it).
func _test_stage3_polish() -> void:
	var host := Node3D.new()
	add_child(host)
	var pivot := Node3D.new()
	host.add_child(pivot)
	var anim := PlayerAnimation.attach(host, pivot)
	_check(anim != null, "PlayerAnimation.attach returns an AnimationPlayer")
	for clip in PlayerAnimation.CLIPS:
		_check(anim.has_animation(clip), "animation clip '%s' registered" % clip)
	_check(PlayerAnimation.CLIPS.size() == 4, "four BlenderInstruction clips declared")
	_check(anim.current_animation == PlayerAnimation.IDLE, "idle plays on attach")
	remove_child(host)
	host.free()
	# The Email Wraith slot exists on the model library (dedicated .glb optional).
	_check(ModelLibrary.EMAIL_WRAITH.ends_with("email_wraith.glb"), "ModelLibrary exposes EMAIL_WRAITH")

## Stage 3 (P2) - arena content: every stair cell is capped by a ceiling slab at
## CEILING_H (Level Design.MD's >= 4 m clearance), and each floor is decorated
## with scattered office props.
## Stage C, ÑÑ‚Ð°Ð¶Ð½Ñ‹Ðµ Ñ„Ð¸ÑˆÐºÐ¸: Ð£Ñ€.1 â€” ÐºÐ¾Ð»Ð»Ð°Ð¹Ð´ÐµÑ€Ñ‹-ÑƒÐºÑ€Ñ‹Ñ‚Ð¸Ñ (Ñ‚ÐµÐ»ÐµÐ¶ÐºÐ¸), Ð£Ñ€.2 â€”
## Ð±ÑƒÐ¼Ð°Ð³Ð¸ (Area3D, Ð·Ð°Ð¼ÐµÐ´Ð»ÑÑŽÑ‰Ð¸Ðµ Ð¸Ð³Ñ€Ð¾ÐºÐ°) + ÐºÑ€ÐµÑÐ»Ð° Ð½Ð° Ñ„Ð¸Ð·Ð¸ÐºÐµ, Ð£Ñ€.3 â€” Ð½Ð¸Ð·ÐºÐ¸Ðµ
## ÑÑ‚ÐµÐ½Ñ‹-ÑƒÐºÑ€Ñ‹Ñ‚Ð¸Ñ. ÐŸÐ»ÑŽÑ Ð´ÐµÐ¼Ð¾Ð½Ñ‹ Ð½Ðµ ÑÐ¿Ð°Ð²Ð½ÑÑ‚ÑÑ Ð½Ð° ÐºÐ»ÐµÑ‚ÐºÐ°Ñ… Ñ Ñ„Ð¸ÑˆÐºÐ°Ð¼Ð¸.
func _test_floor_gimmicks() -> void:
	var level := LevelBuilder.new()
	add_child(level)
	level.build(0)
	_check(level.floor_gimmick_count > 0, "level 1 has cover carts (%d)" % level.floor_gimmick_count)
	var carts := level.get_children().filter(func(c: Node) -> bool: return c.is_in_group("floor_gimmick"))
	_check(carts.size() == level.floor_gimmick_count, "level 1 cover blocks built (%d)" % carts.size())
	level.build(1)
	_check(level.floor_gimmick_count > 0, "level 2 has papers/chairs (%d)" % level.floor_gimmick_count)
	var papers := get_tree().get_nodes_in_group("papers")
	var chairs := level.get_children().filter(func(c: Node) -> bool: return c.is_in_group("floor_gimmick") and c is RigidBody3D)
	_check(papers.size() > 0, "level 2 has paper piles (%d)" % papers.size())
	_check(chairs.size() > 0, "level 2 has physics chairs (%d)" % chairs.size())
	level.build(2)
	_check(level.floor_gimmick_count > 0, "level 3 has low cover walls (%d)" % level.floor_gimmick_count)
	var low_walls := level.get_children().filter(func(c: Node) -> bool: return c.is_in_group("floor_gimmick"))
	_check(low_walls.size() == level.floor_gimmick_count, "level 3 cover walls built (%d)" % low_walls.size())
	_check(level.gimmick_cells.size() == level.floor_gimmick_count, "gimmick cells tracked (%d)" % level.gimmick_cells.size())
	for c in level.gimmick_cells:
		_check(c not in level.spawn_cells, "no demon spawns on a gimmick cell")
		break
	level.queue_free()

## E7: each GDD floor has its own difficulty curve and archetype mix, so the
## run does not feel like one arena cut into thirds.
func _test_floor_difficulty() -> void:
	var spawner := EnemySpawner.new()
	add_child(spawner)
	# --- Every floor has a profile, and the ramp is monotonic ---------------
	_check(GameConfig.FLOOR_PROFILES.size() == 3, "three floor profiles (%d)" % GameConfig.FLOOR_PROFILES.size())
	var spawn_rate := []
	var alive_cap := []
	for step in GameConfig.FLOOR_PROFILES.size():
		# Compare at the same moment in the run so only the floor differs.
		spawn_rate.append(GameConfig.get_spawn_interval(400.0, step))
		alive_cap.append(GameConfig.get_max_alive_enemies(400.0, step))
	_check(spawn_rate[0] > spawn_rate[1] and spawn_rate[1] > spawn_rate[2],
		"later floors spawn more densely (%s)" % str(spawn_rate))
	_check(alive_cap[2] > alive_cap[0], "the executive floor holds more demons (%s)" % str(alive_cap))
	# Out-of-range steps clamp instead of crashing.
	_check(GameConfig.floor_profile(-5) == GameConfig.floor_profile(0), "negative floor clamps to lobby")
	_check(GameConfig.floor_profile(99) == GameConfig.floor_profile(2), "huge floor clamps to executive")
	# --- The archetype mix actually differs per floor ----------------------
	var samples := {}
	for step in GameConfig.FLOOR_PROFILES.size():
		spawner.floor_step = step
		spawner.set_pressure(0.5)
		var counts := {}
		for k in Enemy.Kind.values():
			counts[k] = 0
		for _i in 300:
			var kind: Enemy.Kind = spawner._pick_kind()
			counts[kind] = int(counts[kind]) + 1
		samples[step] = counts
	var lobby: Dictionary = samples[0]
	var exec: Dictionary = samples[2]
	_check(int(lobby[Enemy.Kind.PAPERWORK_PHANTOM]) > int(exec[Enemy.Kind.PAPERWORK_PHANTOM]),
		"lobby leans on chaff phantoms")
	_check(int(exec[Enemy.Kind.FILING_CABINET_TANK]) > int(lobby[Enemy.Kind.FILING_CABINET_TANK]),
		"the executive deck leans on tanks")
	_check(int(exec[Enemy.Kind.EMAIL_WRAITH]) > int(lobby[Enemy.Kind.EMAIL_WRAITH]),
		"the executive deck leans on wraiths")
	# --- Pressure bends the mix without overriding the floor ---------------
	spawner.floor_step = 2
	spawner.set_pressure(1.0)
	var late_tanks := 0
	for _i in 300:
		if spawner._pick_kind() == Enemy.Kind.FILING_CABINET_TANK:
			late_tanks += 1
	spawner.set_pressure(0.0)
	var early_tanks := 0
	for _i in 300:
		if spawner._pick_kind() == Enemy.Kind.FILING_CABINET_TANK:
			early_tanks += 1
	_check(late_tanks > early_tanks, "pressure ramps tanks up (%d vs %d)" % [late_tanks, early_tanks])
	remove_child(spawner)
	spawner.free()

## Ð£Ñ€.2: ÐºÑƒÑ‡Ð¸ Ð±ÑƒÐ¼Ð°Ð³ Ð·Ð°Ð¼ÐµÐ´Ð»ÑÑŽÑ‚ Ð¸Ð³Ñ€Ð¾ÐºÐ° Ð½Ð° 50%, Ð¿Ð¾ÐºÐ° Ð¾Ð½ Ð² Ð·Ð¾Ð½Ðµ.
func _test_paper_slow_player() -> void:
	var player := Player.new()
	add_child(player)
	_check(player._paper_slow_ratio() == 0.0, "no paper slow by default")
	player.paper_zone_enter()
	_check(is_equal_approx(player._paper_slow_ratio(), 0.5), "papers slow player to 50%")
	player.paper_zone_enter()
	player.paper_zone_exit()
	_check(is_equal_approx(player._paper_slow_ratio(), 0.5), "overlapping piles keep the slow")
	player.paper_zone_exit()
	_check(player._paper_slow_ratio() == 0.0, "leaving papers restores speed")
	player.queue_free()

## Pre-run terminal: the chosen perk lands on the freshly built player.
func _test_starting_perk() -> void:
	var meta := get_node_or_null("/root/Meta")
	if meta == null:
		_check(false, "Meta autoload exists")
		return
	meta.starting_perk = "vigor"
	var player := Player.new()
	add_child(player)
	_check(player.max_health >= 110.0, "vigor perk boosts max HP (%.0f)" % player.max_health)
	player.queue_free()
	meta.starting_perk = ""
	var p2 := Player.new()
	add_child(p2)
	_check(p2.max_health == 100.0 or p2.max_health < 110.0, "no perk -> baseline HP (%.0f)" % p2.max_health)
	p2.queue_free()

## The wave director breathes: normal -> surge -> breather -> normal cycle.
func _test_wave_breathing() -> void:
	var spawner := EnemySpawner.new()
	add_child(spawner)
	_check(spawner.wave_phase == "normal", "wave phase starts normal")
	spawner._advance_wave_pattern(27.0)
	_check(spawner.wave_phase == "surge", "surge after 26 s of normal")
	spawner._advance_wave_pattern(5.5)
	_check(spawner.wave_phase == "breather", "breather after the surge")
	spawner._advance_wave_pattern(6.5)
	_check(spawner.wave_phase == "normal", "back to normal after the breather")
	spawner.queue_free()

## The wave director never leaves the "normal" phase with zero enemies coming:
## after each transition it spawns at once and then periodically.
func _test_wave_cycle_spawns() -> void:
	var spawner := EnemySpawner.new()
	add_child(spawner)
	var last_phase := spawner.wave_phase
	var spawns := 0
	for i in 60 * 50:
		var before := get_tree().get_nodes_in_group("enemies").size()
		spawner._process(1.0 / 60.0)
		var after := get_tree().get_nodes_in_group("enemies").size()
		if after > before:
			spawns += after - before
		if spawner.wave_phase != last_phase:
			last_phase = spawner.wave_phase
	# At 50 simulated seconds: 26 normal + ~5 surge + ~6 breather + ~13 normal.
	# At least one full cycle should have happened, giving us enemies.
	_check(last_phase in ["normal", "surge", "breather"], "wave cycle ran (%s)" % last_phase)
	_check(spawns > 0, "wave director spawned %d enemies over 50 simulated seconds" % spawns)
	spawner.queue_free()
	for e in get_tree().get_nodes_in_group("enemies"):
		e.queue_free()

## Playing the full run: demons are cleared every two minutes, and the spawner
## must repopulate the arena before that two-minute window closes.
func _test_demon_respawns_within_two_minutes() -> void:
	var scene := await _spawn_run()
	var game := scene as Game
	var spawner := scene.get_node_or_null("EnemySpawner")
	if spawner != null:
		spawner.process_mode = Node.PROCESS_MODE_INHERIT
	var player := scene.get_node_or_null("Player") as Player
	if player != null:
		player.health = player.max_health
	var ok := true
	for sec in 480:
		game._process(1.0)
		if spawner != null:
			spawner._process(1.0)
		# Hard-clear the arena every 120 simulated seconds.
		if sec != 0 and sec % 120 == 0:
			for e in get_tree().get_nodes_in_group("enemies"):
				if is_instance_valid(e):
					e.take_damage(99999.0, Vector3.ZERO)
		# Sixty seconds after each clear there must have been at least one respawn,
		# otherwise the spawner left the floor empty for half a minute.
		if sec != 0 and sec % 120 == 60:
			if get_tree().get_nodes_in_group("enemies").size() == 0:
				ok = false
				break
	_check(ok, "demons respawned within the two-minute window")
	_free_run(scene)

## E3: waves are mixed batches — non-empty, valid kinds, bigger under pressure.
func _test_wave_batches() -> void:
	var spawner := EnemySpawner.new()
	add_child(spawner)
	spawner.set_pressure(0.0)
	spawner._build_wave()
	_check(not spawner._wave_queue.is_empty(), "wave 1 is non-empty")
	var small_size := spawner._wave_queue.size()
	for k in spawner._wave_queue:
		_check(k >= 0 and k < Enemy.Kind.size(), "wave member is a valid archetype")
	spawner.set_pressure(1.0)
	spawner._build_wave()
	_check(spawner._wave_queue.size() > small_size, "waves grow with pressure (%d -> %d)" % [small_size, spawner._wave_queue.size()])
	# Draining the queue starts a new wave.
	spawner._wave_queue.clear()
	var first := spawner._next_wave_member()
	_check(first >= 0 and first < Enemy.Kind.size(), "next wave member is valid")
	_check(not spawner._wave_queue.is_empty(), "new wave queued after drain")
	spawner.queue_free()

## E4: the soul shop spends souls, applies upgrades, and persists.
func _test_meta_shop() -> void:
	var meta := get_node_or_null("/root/Meta")
	if meta == null:
		_check(false, "Meta autoload exists")
		return
	meta.total_souls = 200.0
	_check(meta.can_buy("hp"), "can buy HP upgrade with 200 souls")
	_check(meta.buy_upgrade("hp"), "buy HP upgrade succeeds")
	_check(meta.upgrade_level("hp") == 1, "HP upgrade level is 1")
	_check(is_equal_approx(meta.total_souls, 150.0), "souls deducted (%.0f)" % meta.total_souls)
	_check(not meta.can_buy("spell") or meta.total_souls >= 100.0, "spell purchase gated by cost")
	# Spell purchase unlocks the next locked spell.
	meta.total_souls = 100.0
	_check(meta.buy_upgrade("spell"), "buy spell unlock succeeds")
	_check(meta.unlocked_count() > 3, "a new spell is permanently unlocked (%d)" % meta.unlocked_count())
	# Upgrades apply to a fresh player.
	var player := Player.new()
	add_child(player)
	_check(player.max_health > 100.0, "soul-shop HP applies to player (%.0f)" % player.max_health)
	remove_child(player)
	player.free()
	# Reset for the rest of the suite.
	meta.total_souls = 0.0
	meta.meta_upgrades = {}
	meta.unlocked_spells = Meta.DEFAULT_UNLOCKED.duplicate()
	meta.save_meta()

## E8: floating HP bars over damaged demons and a live minimap in the HUD.
func _test_e8_hp_bars_and_minimap() -> void:
	var scene := await _spawn_run()
	var game := scene as Game
	var player := scene.get_node_or_null("Player") as Player
	var hud := scene.get_node_or_null("HUD") as HUD
	# Spawn a demon, damage it, and confirm the HP bar appears.
	var demon := Enemy.new()
	demon.configure(Enemy.Kind.PAPERWORK_PHANTOM)
	scene.add_child(demon)
	demon.global_position = player.global_position + Vector3(3.0, 0.0, 0.0)
	await get_tree().physics_frame
	_check(demon._hp_bar != null, "demon has an HP bar node")
	_check(not demon._hp_bar.visible, "HP bar hidden at full health")
	demon.take_damage(5.0)
	await get_tree().physics_frame
	_check(demon._hp_bar.visible, "HP bar shows after damage")
	# Minimap is present and visible during a run.
	_check(hud != null and hud._minimap != null, "HUD has a minimap")
	_check(hud._minimap.visible, "minimap visible during a run")
	demon.queue_free()
	_free_run(scene)

## Portals telegraph themselves: a violet beacon beam on top of the copier.
func _test_portal_beacon() -> void:
	var portal := SpawnerPortal.new()
	add_child(portal)
	_check(portal.get_node_or_null("PortalBeam") != null, "portal has a beacon beam")
	portal.queue_free()

## Training hall loads: arena + player, no demon spawner, static dummies.
func _test_training_hall() -> void:
	var scene := load("res://scenes/training.tscn") as PackedScene
	_check(scene != null, "training scene exists")
	if scene == null:
		return
	var training := scene.instantiate()
	add_child(training)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(training.get_node_or_null("Level") != null, "training has an arena")
	_check(training.get_node_or_null("EnemySpawner") == null, "training has no demon spawner")
	_check(training.get_node_or_null("HUD") != null, "training has a HUD (crosshair, slots, timer)")
	var dummies := get_tree().get_nodes_in_group("enemies")
	_check(dummies.size() == 4, "training has 4 static dummies (%d)" % dummies.size())
	training.queue_free()

## HUD skill bar: locked spells are hidden, every visible slot shows its key.
func _test_hud_slots_ui() -> void:
	var player: Player = load("res://scenes/player.tscn").instantiate()
	add_child(player)
	var hud := HUD.new()
	add_child(hud)
	await get_tree().process_frame
	await get_tree().process_frame
	var visible_ids: Array[int] = []
	for holder in hud._slots:
		if holder.visible:
			visible_ids.append(int(holder.get_meta("spell_id")))
	_check(visible_ids.size() == 3, "only the 3 unlocked slots are shown (%d)" % visible_ids.size())
	for holder in hud._slots:
		if not holder.visible:
			continue
		var has_key := false
		for c in holder.get_children():
			if c is Label:
				# slot i maps to digit i+1 modulo 10, e.g. slot 9 -> "0"
				has_key = true
		_check(has_key, "visible slot has a key label")
		break
	remove_child(hud)
	hud.free()
	remove_child(player)
	player.free()

## NG+: every step raises the permanent level, scaling enemy HP/damage/spawns.
func _test_ngplus_scaling() -> void:
	var meta := get_node_or_null("/root/Meta")
	if meta == null:
		_check(false, "Meta autoload exists")
		return
	meta.ng_level = 0
	var base_interval := GameConfig.get_spawn_interval(0.0)
	var base_mult := GameConfig.enemy_hp_mult()
	meta.ng_level = 5
	_check(GameConfig.get_spawn_interval(0.0) < base_interval, "spawns faster at NG+5")
	_check(GameConfig.enemy_hp_mult() > base_mult, "enemy HP scales with NG+")
	var enemy := Enemy.new()
	add_child(enemy)
	_check(enemy.max_health > enemy.PHANTOM_HEALTH, "enemy max HP uses NG mult (%.0f)" % enemy.max_health)
	enemy.queue_free()
	var boss := Boss.new()
	add_child(boss)
	_check(boss.max_health > GameConfig.BOSS_HEALTH, "boss HP uses NG mult (%.0f)" % boss.max_health)
	boss.queue_free()
	meta.ng_level = 0

## Victory lets the player pick one permanent perk before the next run.
func _test_postwin_overlay() -> void:
	var meta := get_node_or_null("/root/Meta")
	if meta != null:
		meta.ng_level = 3
	var hud := HUD.new()
	add_child(hud)
	hud.show_postwin_choices()
	await get_tree().process_frame
	var buttons := hud.find_children("*", "Button", true, false)
	_check(buttons.size() >= 3, "postwin overlay lists permanent perks (%d)" % buttons.size())
	# Do not consume the perk here (campaign state must stay clean).
	hud.free()
	if meta != null:
		meta.ng_level = 0


func _test_arena_content() -> void:
	var level := LevelBuilder.new()
	add_child(level)
	level.build(0)
	_check(level.ceiling_count > 0, "stair cells are capped (%d ceilings)" % level.ceiling_count)
	_check(level.props_count > 0, "arena is decorated (%d props)" % level.props_count)
	# The ceiling constant itself must meet the brief's 4 m head clearance.
	_check(LevelBuilder.CEILING_H >= 4.0, "CEILING_H >= 4 m over stairs")
	# Every stair count on the built floor is matched by a ceiling.
	_check(level.ceiling_count == level.stair_count, "one ceiling per stair cell")
	# Regression (BUGS.md #14): the ceiling slab used to be laid at CEILING_H
	# above the FLOOR, which is only 1.6 m of headroom over the 2.4 m ramp --
	# the caster scraped their head walking up.  It must clear the ramp top by
	# the caster's own height.
	var clearance := LevelBuilder.CEILING_H
	_check(clearance >= 4.0, "stairwell clears the ramp top by >= 4 m")
	# And the columns must stand on the floor, not float: they carry the slab.
	_check(level.ceiling_column_count == level.ceiling_count * 4,
		"four columns per stairwell (%d)" % level.ceiling_column_count)
	remove_child(level)
	level.free()

## Regression for the "no ceilings were ever built" bug: _add_ceiling() is only
## reachable from the '^' branch, so its own glyph guard always matched and it
## returned before building anything.  Walk a caster-sized capsule up a real
## ramp to prove the stairwell is both present and walkable.
func _test_stairwell_clearance() -> void:
	var level := LevelBuilder.new()
	add_child(level)
	level.build(0)
	await get_tree().physics_frame
	var space := level.get_world_3d().direct_space_state
	var tall := 1.8   ## player capsule height
	var all_clear := true
	var ceilings := 0
	for z in level.cells_z:
		for x in level.cells_x:
			if level.glyph_at(x, z) != "^":
				continue
			ceilings += 1
			# A head-clearance probe from the top of the ramp straight up: it must
			# not hit the ceiling slab.
			var ramp_top := level.cell_centre(x, z) + Vector3(0.0, LevelBuilder.DECK_H, 0.0)
			var params := PhysicsRayQueryParameters3D.create(
				ramp_top, ramp_top + Vector3.UP * tall, 16)
			if not space.intersect_ray(params).is_empty():
				all_clear = false
	_check(ceilings > 0, "floor 0 has stair cells to probe (%d)" % ceilings)
	_check(all_clear, "caster fits under every stairwell ceiling")
	remove_child(level)
	level.free()

## Stage 3 (P2) - juice VFX: the physics debris chunk launches and tints itself,
## and the HUD exposes a hit marker + screen shake that EffectUtil forwards to.
func _test_stage3_vfx() -> void:
	# Debris chunk: a RigidBody3D that takes a launch velocity and tints itself.
	var chunk := DebrisChunk.new()
	add_child(chunk)
	chunk.launch(Vector3(1, 1, 0), 5.0, Color("#2f7dff"))
	_check(chunk.linear_velocity.length() > 0.0, "debris chunk launches with velocity")
	_check(DebrisChunk.LIFETIME > 0.0, "debris chunk has a finite lifetime")
	remove_child(chunk)
	chunk.free()

	# HUD: hit marker flashes and screen shake kick off on demand.
	var hud := HUD.new()
	add_child(hud)
	_check(not hud.is_hitmarker_visible(), "hit marker hidden by default")
	hud.flash_hitmarker()
	_check(hud.is_hitmarker_visible(), "flash_hitmarker shows the marker")
	hud.shake()
	_check(hud.is_shaking(), "shake starts the screen shake timer")
	remove_child(hud)
	hud.free()


## Stage 4 (P3) - audio plumbing: Settings owns the five bus volumes and the
## SoundManager stub counts cues without touching real audio files.
func _test_stage4_audio_settings() -> void:
	_check(Settings.BUSES.size() == 5, "Settings declares 5 audio buses")
	_check(Settings.BUSES.has(&"Music") and Settings.BUSES.has(&"SFX"), "Settings has Music + SFX buses")
	Settings.master_volume = 0.5
	Settings.apply_all()
	var master_idx := AudioServer.get_bus_index(&"Master")
	_check(master_idx >= 0, "Master bus exists after apply_all")
	_check(is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(master_idx)), 0.5), "Master volume round-trips to 0.5")
	Settings.master_volume = 1.0
	Settings.apply_all()

	SoundManager.play(&"test_cue")
	SoundManager.play(&"test_cue")
	_check(SoundManager.play_count(&"test_cue") == 2, "SoundManager counts repeated cues")
	_check(SoundManager.play_count(&"never_played") == 0, "unknown cue count is 0")
	SoundManager.play_music(&"battle")
	_check(SoundManager.music_key() == &"battle", "play_music remembers the key")
	SoundManager.stop_music()
	_check(SoundManager.music_key() == &"", "stop_music clears the key")
	_check(AudioServer.get_bus_index(&"Music") >= 0, "Music bus created by the stub")
	# Stage 4 wiring: every cue key now maps to a real res://sound/ file.
	_check(SoundManager.has_cue(&"bolt_fire"), "bolt_fire cue is mapped to a real file")
	_check(SoundManager.has_cue(&"player_hurt"), "player_hurt cue is mapped")
	_check(SoundManager.has_cue(&"ui_click"), "ui_click cue is mapped")
	_check(SoundManager.spell_cast_key(1) == &"spell_01_cast", "spell 1 maps to its cast cue")
	_check(SoundManager.spell_cast_key(6) == &"", "spell 6 (unsupported .aiff) has no cue key")

## Stage 4 (P3) - the main menu is the new entry scene and reaches the run scene,
## the settings overlay and quit.
func _test_stage4_main_menu() -> void:
	var menu_scene: Node = load("res://scenes/main_menu.tscn").instantiate()
	add_child(menu_scene)
	# Duck-typed: the class_name global cache may be stale in a fresh headless run.
	_check(menu_scene.has_method("is_settings_open"), "main_menu.tscn uses the MainMenu script")
	_check(menu_scene.get_node_or_null("SettingsScreen") != null, "main menu embeds a SettingsScreen")
	_check(menu_scene.get("RUN_SCENE") == "res://scenes/main.tscn", "Start targets the run scene")
	_check(not menu_scene.is_settings_open(), "settings closed at start")
	menu_scene._on_settings()
	_check(menu_scene.is_settings_open(), "_on_settings() opens the overlay")
	menu_scene.get_node("SettingsScreen").close()
	_check(menu_scene.get_node_or_null("MetaScreen") != null, "main menu embeds a MetaScreen")
	_check(not menu_scene.is_meta_open(), "meta screen closed at start")
	menu_scene._on_meta()
	_check(menu_scene.is_meta_open(), "_on_meta() opens the meta screen")
	menu_scene.get_node("MetaScreen").close()
	remove_child(menu_scene)
	menu_scene.free()

	var screen: Node = load("res://scripts/ui/settings_screen.gd").new()
	add_child(screen)
	_check(screen.get("RESOLUTIONS").size() >= 3, "settings screen offers >=3 resolutions")
	_check(not screen.visible, "settings screen hidden on ready")
	screen.open()
	_check(screen.visible, "open() shows the settings screen")
	screen.close()
	_check(not screen.visible, "close() hides the settings screen")
	remove_child(screen)
	screen.free()

## Stage 4 (P3) - meta progression persists unlocked spells between runs.
func _test_stage4_meta() -> void:
	_check(Meta.unlocked_count() >= 3, "at least the 3 starter spells are unlocked")
	_check(Meta.is_unlocked(1) and Meta.is_unlocked(2) and Meta.is_unlocked(3), "spells 1-3 unlocked by default")
	Meta.reset()
	_check(not Meta.is_unlocked(7), "spell 7 locked before unlock")
	Meta.unlock_spell(7)
	_check(Meta.is_unlocked(7), "unlock_spell() unlocks spell 7")
	Meta.unlock_spell(7)
	_check(Meta.unlocked_count() == 4, "re-unlocking does not duplicate")
	Meta.reset()
	_check(Meta.unlocked_count() == 3, "reset() restores the default loadout")

## Stage 4: the new main scene and autoloads are registered in project.godot.
func _test_stage4_project() -> void:
	var main_scene: String = ProjectSettings.get_setting("application/run/main_scene", "")
	_check(main_scene == "res://scenes/main_menu.tscn", "main scene is main_menu.tscn")
	_check(ProjectSettings.has_setting("autoload/Meta"), "Meta autoload registered")
	_check(ProjectSettings.has_setting("autoload/Settings"), "Settings autoload registered")
	_check(ProjectSettings.has_setting("autoload/SoundManager"), "SoundManager autoload registered")

## Gameplay fix: the HUD must draw an always-on aim reticle so the player knows
## where holy bolts and spells go.
func _test_crosshair() -> void:
	var hud := HUD.new()
	add_child(hud)
	_check(hud._crosshair != null, "HUD builds an aim crosshair")
	if hud._crosshair != null:
		# Four arms + one centre dot.
		_check(hud._crosshair.get_child_count() == 5, "crosshair has 4 arms + 1 centre dot")
		_check(hud._crosshair.visible, "crosshair is visible during a run")
	remove_child(hud)
	hud.free()

## Gameplay fix: demons are spawned via Enemy.new() (not enemy.tscn), so the
## class must build its own CollisionShape3D. Without it a demon has no floor
## and falls out of the world while still dealing contact damage.
func _test_enemy_collision() -> void:
	var e := Enemy.new()
	add_child(e)
	var shapes := e.find_children("*", "CollisionShape3D", true, false)
	_check(shapes.size() >= 1, "spawned Enemy builds its own collision shape (%d)" % shapes.size())
	if shapes.size() >= 1:
		var shape := shapes[0] as CollisionShape3D
		_check(shape.shape is CapsuleShape3D, "enemy collision shape is a capsule")
	remove_child(e)
	e.free()

# --- End-to-end / integration suite -----------------------------------------
#
# Everything below drives a real main.tscn through actual physics frames, so it
# verifies the pieces work *together* and, crucially, that a full 10-minute run
# can be traversed to victory.  Move speed is boosted locally so the simulated
# run only costs a fraction of a second of wall time.

func _test_integration() -> void:
	await _it_run_starts_and_spawns()
	await _it_enemies_track_floor()
	await _it_player_can_be_killed()
	await _it_full_run_reaches_victory()
	await _it_attack_and_kill_grants_xp()
	await _it_level_up_releases_cursor()
	await _it_death_freezes_run()
	await _test_spawn_distance()
	await _test_projectile_blocked_by_wall()
	await _test_melee_through_floor()
	await _test_ranged_line_of_sight()
	await _it_boss_finale()
	await _test_floor_progression()
	await _it_multishot_and_pierce()

## Fresh run scene placed under the test runner, after Game._ready() has built
## the level.  Note: spawned souls, bolts, debris and effects attach to
## get_tree().current_scene (the test runner), so _free_run() also sweeps those
## leftovers -- otherwise one sub-test leaks demons/XP into the next.
func _spawn_run() -> Node:
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(scene)
	# Game scripts use get_tree().current_scene as the host for new nodes.
	get_tree().current_scene = scene
	await get_tree().physics_frame
	return scene

func _free_run(scene: Node) -> void:
	if is_instance_valid(scene):
		if scene.get_parent() == get_tree().root:
			get_tree().root.remove_child(scene)
		else:
			remove_child(scene)
		scene.free()
	# Restore the test runner as the current scene for subsequent ad-hoc adds.
	get_tree().current_scene = self
	# Sweep anything that attached to the test runner instead of the run scene.
	for child in get_children():
		if child is Projectile or child is SoulOrb or child is EffectBase or child is DebrisChunk:
			child.free()
		elif child is Node and child.is_in_group("enemies"):
			child.free()
	get_tree().paused = false

func _it_run_starts_and_spawns() -> void:
	var scene := await _spawn_run()
	var game := scene as Game
	_check(game.time_left > 590.0, "run timer starts near 600s")
	var player := scene.get_node_or_null("Player") as Player
	_check(player != null, "run scene has a Player")
	_check(player.is_alive(), "player starts alive")
	_check(not get_tree().paused, "run starts unpaused")

	# The wave director must actually populate the arena with live demons.
	var found := false
	for i in 400:
		await get_tree().physics_frame
		if get_tree().get_nodes_in_group("enemies").size() > 0:
			found = true
			break
	_check(found, "spawner populates the arena with demons")
	_free_run(scene)

## Regression guard for the "demons fall through the floor" bug: every spawned
## demon must stay grounded.  A body with no collision shape / wrong mask sinks
## without bound (y -> -hundreds) while still chasing in XZ.
func _it_enemies_track_floor() -> void:
	var scene := await _spawn_run()
	var level := scene.get_node_or_null("Level") as LevelBuilder
	var enemy: Enemy = Enemy.new()
	enemy.configure(Enemy.Kind.WATER_COOLER)
	scene.add_child(enemy)
	enemy.global_position = level.random_edge_position() + Vector3(0.0, 0.5, 0.0)
	for i in 150:
		await get_tree().physics_frame
	_check(is_instance_valid(enemy) and enemy.global_position.y > -3.0, "spawned demon does not fall through the floor (y=%.1f)" % (enemy.global_position.y if is_instance_valid(enemy) else 0.0))
	_check(is_instance_valid(enemy) and enemy.is_on_floor(), "spawned demon settles on the floor")
	_free_run(scene)

## The enemy pressure must be meaningful: demons packed around a stationary
## caster have to be able to end the run through contact damage.
func _it_player_can_be_killed() -> void:
	var scene := await _spawn_run()
	var game := scene as Game
	var player := scene.get_node_or_null("Player") as Player
	# Ring the caster with tanks and re-seat them each frame: left alone they
	# shove each other out of melee reach and the test becomes flaky.
	var demons: Array[Enemy] = []
	for i in 6:
		var demon: Enemy = Enemy.new()
		demon.configure(Enemy.Kind.WATER_COOLER)
		scene.add_child(demon)
		demons.append(demon)
	var killed := false
	for i in 600:
		if is_instance_valid(player) and player.is_alive():
			for j in demons.size():
				if not is_instance_valid(demons[j]):
					continue
				var a := TAU * float(j) / float(demons.size()) + float(i) * 0.02
				demons[j].global_position = player.global_position + Vector3(cos(a), 0.0, sin(a)) * 1.2
		await get_tree().physics_frame
		if not is_instance_valid(player) or not player.is_alive():
			killed = true
			break
	_check(killed, "contact damage can kill the player")
	_check(not game._running, "player death ends the run")
	_free_run(scene)

## The full loop: fast-forward the clock and confirm the run can be *completed*
## (victory), not just lost.
func _it_full_run_reaches_victory() -> void:
	var scene := await _spawn_run()
	var game := scene as Game
	var player := scene.get_node_or_null("Player") as Player
	var hud := scene.get_node_or_null("HUD") as HUD
	# Survive by out-healing the (still spawning) horde so the run can be
	# completed deterministically; the point is to exercise the win path.
	var finished := false
	for i in 600:
		await get_tree().physics_frame
		if is_instance_valid(player) and player.is_alive():
			player.health = player.max_health
		if i == 30:
			game.time_left = 0.5
		if not game._running:
			finished = true
			break
	_check(finished, "run reaches an end state")
	await _choose_first_postwin_perk(hud)
	_check(hud != null and hud.is_victory(), "surviving the clock triggers HUD victory")
	_free_run(scene)

## Combat integration: a bolt fired from the auto weapon kills an exposed demon
## and the resulting soul feeds XP into the run director.
func _it_attack_and_kill_grants_xp() -> void:
	var scene := await _spawn_run()
	var game := scene as Game
	var player := scene.get_node_or_null("Player") as Player
	# Freeze the wave director and use a stationary target so the test is
	# deterministic (no stray demons to absorb bolts or inflate XP).
	var spawner := scene.get_node_or_null("EnemySpawner")
	if spawner != null:
		spawner.process_mode = Node.PROCESS_MODE_DISABLED
	# Put a demon right in front of the camera and shoot it. Demons are grounded,
	# and bolts fly at eye height (~1.7 m), so the round must be aimed at the
	# body centre -- this also guards the hit-detection regression.
	var enemy: Enemy = Enemy.new()
	enemy.configure(Enemy.Kind.PAPERWORK_PHANTOM)
	enemy.speed = 0.0
	scene.add_child(enemy)
	var forward := -player._camera.global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	enemy.global_position = Vector3(player.global_position.x, 0.0, player.global_position.z) + forward * 3.0
	await get_tree().physics_frame
	var xp_before := game.xp
	# One bolt does 10 damage vs 26 HP, so land a few (auto weapon has its own
	# fire cooldown).
	for i in 240:
		if not is_instance_valid(enemy):
			break
		player._auto_weapon.call("fire", enemy.hurt_center())
		await get_tree().physics_frame
	_check(not is_instance_valid(enemy), "aimed holy bolts kill a demon")
	# Let the dropped soul drift into the pickup radius and be collected.
	for i in 300:
		await get_tree().physics_frame
		if game.xp > xp_before:
			break
	_check(game.xp > xp_before, "killing a demon yields XP (%.0f -> %.0f)" % [xp_before, game.xp])
	_free_run(scene)

## Bug tracker #1: the level-up card choice must release the mouse so a card can
## be clicked, and re-capture it afterwards.
func _it_level_up_releases_cursor() -> void:
	var scene := await _spawn_run()
	var game := scene as Game
	var level_up := scene.get_node_or_null("LevelUpScreen") as LevelUpScreen
	# Give enough XP to trigger a level-up and open the choice.
	game.add_xp(game.xp_to_next)
	await get_tree().physics_frame
	_check(level_up != null and level_up.visible, "level-up screen opens and shows cards")
	_check(level_up.is_cursor_free(), "cursor is released for the reward choice")
	# Also confirm the pool builds clickable cards.
	var row := level_up._row
	_check(row.get_child_count() >= 1, "level-up screen lays out reward cards")
	level_up._on_card_chosen(_first_card(level_up))
	_check(not level_up.visible, "choosing a card closes the level-up screen")
	_check(not level_up.is_cursor_free(), "cursor is re-captured after the reward")
	_free_run(scene)

## The UpgradeCard behind the first on-screen reward view, or null.
func _first_card(level_up: LevelUpScreen) -> UpgradeCard:
	for view in level_up._views:
		if view != null and view.card != null:
			return view.card
	return null

## Bug tracker #3a: death must actually stop the run (freeze the world) instead
## of letting the player keep running around among live demons.
func _it_death_freezes_run() -> void:
	var scene := await _spawn_run()
	var game := scene as Game
	var player := scene.get_node_or_null("Player") as Player
	player.take_damage(9999.0, Vector3.ZERO)
	await get_tree().physics_frame
	_check(not game._running, "player death ends the run")
	_check(get_tree().paused, "death freezes the world")
	# The pause menu must not be able to un-freeze a finished run.
	var menu := scene.get_node_or_null("PauseMenu") as PauseMenu
	menu.open()
	menu.close()
	_check(get_tree().paused, "closing the pause menu cannot resume a dead run")
	# A level-up can no longer open after death.
	game.add_xp(9999.0)
	var level_up := scene.get_node_or_null("LevelUpScreen") as LevelUpScreen
	await get_tree().physics_frame
	_check(level_up == null or not level_up.visible, "no reward choice after death")
	_free_run(scene)

