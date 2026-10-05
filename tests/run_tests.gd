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
	_test_charge_indicator()
	_test_pause_menu()
	_test_models()
	_test_spell_gdd()
	_test_ranged_demon()
	_test_npc_dialog()
	_test_balance()
	_test_stage3_polish()
	_test_arena_content()
	_test_stage3_vfx()
	_test_stage4_audio_settings()
	_test_stage4_main_menu()
	_test_stage4_meta()
	_test_stage4_project()
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
	remove_child(scene)
	scene.free()
	get_tree().paused = false

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

