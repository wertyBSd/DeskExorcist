class_name HUD
## Heads-up display (GDD section 4): session timer, health, XP, soul gauge and
## the 1-0 ability bar with per-slot cooldown fills.  Built entirely in code so
## the HUD needs no .tscn wiring.
extends CanvasLayer

const ICON := 40
## Screen box the minimap is fitted into, in pixels, and its margin from the
## window edge. The arena scales to whichever of the two axes runs out first.
const MINIMAP_PX := Vector2(224, 160)
const MINIMAP_MARGIN := 16.0

var _root: Control
var _timer_label: Label
var _health_bar: ProgressBar
var _xp_bar: ProgressBar
var _soul_bar: ProgressBar
var _slots: Array[Control] = []

var _player: Player
var _game: Game
var _dialog_label: Label
var _charge_bar: ProgressBar
var _charge_ratio: float = 0.0
var _victory: bool = false

## Damage flash (ROADMAP Stage B): a red screen tint on every hit taken.
var _damage_flash: ColorRect
var _damage_time: float = 0.0
const DAMAGE_FLASH_TIME := 0.35

## Final boss health bar (ROADMAP Stage C): shown while the boss is alive.
var _boss: Boss = null
var _boss_bar: ProgressBar
var _boss_label: Label

## Hit marker (ROADMAP Stage 3 VFX): a brief cross that flashes on every hit.
var _hitmarker: Control
var _hit_time: float = 0.0
const HIT_MARKER_TIME := 0.18

## Aim reticle (GDD section 1): the fixed centre crosshair the player aims
## holy bolts and spells with. Always visible while the run is going.
var _crosshair: Control
const CROSSHAIR_GAP := 5.0    ## empty space between the centre dot and each arm
const CROSSHAIR_ARM := 8.0    ## length of each arm, in pixels
const CROSSHAIR_THICK := 2.0

## Screen shake (ROADMAP Stage 3 VFX): an offset applied while the player is hit.
var _shake_time: float = 0.0
const SHAKE_TIME := 0.25
const SHAKE_AMOUNT := 10.0

## Minimap (E8): canvas item drawing the arena layout plus player/enemy/
## portal markers. Shows while a run is going.
var _minimap: Minimap

func _ready() -> void:
	layer = 1
	# The run-end banner must stay readable after Game pauses the tree on death.
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("hud")
	_build()

## Called by Game once both nodes exist.
func bind(p_player: Player, p_game: Game) -> void:
	_bind_player(p_player)
	_game = p_game

## Attaches to the player's charge signal exactly once, even though the HUD also
## re-discovers the player every frame from the "player" group.
func _bind_player(p_player: Player) -> void:
	if _player == p_player:
		return
	if _player != null and _player.charge_changed.is_connected(_on_charge_changed):
		_player.charge_changed.disconnect(_on_charge_changed)
	_player = p_player
	if _player != null and not _player.charge_changed.is_connected(_on_charge_changed):
		_player.charge_changed.connect(_on_charge_changed)

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_timer_label = Label.new()
	_timer_label.add_theme_font_size_override("font_size", 34)
	_timer_label.position = Vector2(560, 16)
	_root.add_child(_timer_label)

	_health_bar = _make_bar(Color("#c2364a"), Vector2(24, 24), Vector2(280, 22))
	_xp_bar = _make_bar(Color("#9fe8ff"), Vector2(24, 52), Vector2(280, 12))
	_soul_bar = _make_bar(Color("#ffe9a8"), Vector2(24, 70), Vector2(280, 12))

	_dialog_label = Label.new()
	_dialog_label.add_theme_font_size_override("font_size", 22)
	_dialog_label.add_theme_color_override("font_color", Color("#ffe9a8"))
	_dialog_label.position = Vector2(360, 600)
	_root.add_child(_dialog_label)

	# Charge indicator (GDD section 4): a centred bar that fills while a spell is
	# held (0..1) and hides the moment the cast is released or interrupted.
	_charge_bar = _make_bar(Color("#ffd166"), Vector2(440, 586), Vector2(400, 16))
	_charge_bar.visible = false

	# Hit marker: four short arms around the crosshair, hidden until a hit.
	_hitmarker = Control.new()
	_hitmarker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hitmarker.position = Vector2(624, 344)
	_hitmarker.visible = false
	for d in [Vector2(0, -12), Vector2(0, 12), Vector2(-12, 0), Vector2(12, 0)]:
		var arm := ColorRect.new()
		arm.color = Color("#ffe9a8")
		arm.size = Vector2(8, 4)
		arm.position = d
		_hitmarker.add_child(arm)
	_root.add_child(_hitmarker)

	# Minimap (E8): arena layout + player/enemy/portal markers, top-right.
	# Position and scale are derived from the arena size and the window on every
	# frame in _update_minimap(), so nothing is hardcoded here.
	_minimap = Minimap.new()
	_minimap.visible = false
	_root.add_child(_minimap)

	# Damage flash: a full-screen red tint that fades out on every hit taken.
	_damage_flash = ColorRect.new()
	_damage_flash.color = Color(0.9, 0.15, 0.2, 0.0)
	_damage_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_damage_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_damage_flash)

	_build_boss_bar()
	_build_crosshair()

	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 6)
	bar.position = Vector2(24, 640)
	_root.add_child(bar)
	for slot in InputSetup.SPELL_KEYS.size():
		bar.add_child(_make_slot(slot))

func _make_bar(fill: Color, pos: Vector2, size: Vector2) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.position = pos
	bar.custom_minimum_size = size
	bar.size = size
	bar.max_value = 1.0
	bar.value = 1.0
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.5)
	bg.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("background", bg)
	var fg := StyleBoxFlat.new()
	fg.bg_color = fill
	fg.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("fill", fg)
	_root.add_child(bar)
	return bar

func _make_slot(slot: int) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(ICON, ICON)
	var icon := TextureRect.new()
	icon.texture = ArtLibrary.spell_icon(InputSetup.spell_id_for_slot(slot))
	# A TextureRect's minimum size is its texture size unless expand_mode says
	# otherwise, so a 256px icon would blow the 40px slot wide open and spill
	# across the screen. IGNORE_SIZE hands the sizing back to the holder.
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	# The project draws 2D at nearest so the procedural art stays crisp, but a
	# 256px icon dropped into a 40px slot is a 6x minification: nearest turns
	# it into crawling speckle. Mipmaps + linear filtering are per-node, so the
	# rest of the HUD keeps the project's setting.
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.add_child(icon)
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.6)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(overlay)
	holder.set_meta("overlay", overlay)
	holder.set_meta("spell_id", InputSetup.spell_id_for_slot(slot))
	# Key hint so players see which digit activates this slot (GDD §1).
	var key_label := Label.new()
	key_label.text = "0" if slot == 9 else str(slot + 1)
	key_label.add_theme_font_size_override("font_size", 12)
	key_label.add_theme_color_override("font_color", Color("#eaeaf2"))
	key_label.position = Vector2(ICON * 0.5 - 4.0, ICON + 2.0)
	holder.add_child(key_label)
	_slots.append(holder)
	return holder

## Builds the always-on aim reticle: four short arms around an open centre,
## centred on the viewport. It is the fixed reference for the mouse-look aim
## (holy bolts and spells fire along the camera axis through this point).
func _build_crosshair() -> void:
	_crosshair = Control.new()
	_crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Centre the reticle now; _refresh_anchors() also re-centres it on resize.
	var vp := get_viewport()
	if vp != null:
		var size := vp.get_visible_rect().size
		_crosshair.position = (size - Vector2.ONE * (CROSSHAIR_GAP + CROSSHAIR_ARM)) * 0.5
	else:
		_crosshair.position = Vector2(640, 360)
	var span := CROSSHAIR_GAP + CROSSHAIR_ARM
	# Each arm: (offset from the reticle origin, size).
	var arms := [
		[Vector2(-span, -CROSSHAIR_THICK * 0.5), Vector2(CROSSHAIR_ARM, CROSSHAIR_THICK)],   # left
		[Vector2(CROSSHAIR_GAP, -CROSSHAIR_THICK * 0.5), Vector2(CROSSHAIR_ARM, CROSSHAIR_THICK)],  # right
		[Vector2(-CROSSHAIR_THICK * 0.5, -span), Vector2(CROSSHAIR_THICK, CROSSHAIR_ARM)],   # top
		[Vector2(-CROSSHAIR_THICK * 0.5, CROSSHAIR_GAP), Vector2(CROSSHAIR_THICK, CROSSHAIR_ARM)],  # bottom
	]
	for a in arms:
		var arm := ColorRect.new()
		arm.color = Color("#eaeaf2")
		arm.size = a[1]
		arm.position = a[0]
		arm.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_crosshair.add_child(arm)
	# A single centre dot so the exact aim point is unambiguous.
	var dot := ColorRect.new()
	dot.color = Color("#ffe9a8")
	dot.size = Vector2(CROSSHAIR_THICK, CROSSHAIR_THICK)
	dot.position = Vector2(-CROSSHAIR_THICK * 0.5, -CROSSHAIR_THICK * 0.5)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crosshair.add_child(dot)
	_root.add_child(_crosshair)

## Builds the boss health bar (hidden until a boss spawns), centred near the top.
func _build_boss_bar() -> void:
	_boss_label = Label.new()
	_boss_label.text = "ДЕМОН-ДИРЕКТОР"
	_boss_label.add_theme_font_size_override("font_size", 20)
	_boss_label.add_theme_color_override("font_color", Color("#ffb3c1"))
	_boss_label.position = Vector2(460, 74)
	_boss_label.visible = false
	_root.add_child(_boss_label)
	_boss_bar = _make_bar(Color("#c2364a"), Vector2(340, 96), Vector2(600, 20))
	_boss_bar.visible = false

## Binds a freshly spawned boss and reveals its health bar.
func bind_boss(boss: Boss) -> void:
	_boss = boss
	if _boss_bar != null:
		_boss_bar.visible = true
	if _boss_label != null:
		_boss_label.visible = true

func _process(delta: float) -> void:
	if _player == null:
		_bind_player(EffectUtil.player(get_tree()) as Player)
	if _game == null:
		var games := get_tree().get_nodes_in_group("game")
		if not games.is_empty():
			_game = games[0] as Game
	_refresh()
	_tick_vfx(delta)
	_update_minimap()

## Draws the arena layout, player, enemies and portal on the minimap.
func _update_minimap() -> void:
	if _minimap == null:
		return
	_minimap.visible = false
	if _game == null or _player == null:
		return
	var host := get_tree().current_scene
	if host == null:
		return
	var level := host.get_node_or_null("Level") as LevelBuilder
	if level == null:
		return
	# The map is drawn in cells and scaled to fill a fixed screen box, so every
	# arena (14x10, 18x13, 16x15) comes out the same size and the markers stay
	 # readable instead of collapsing to a pixel. Recomputed per frame, which is
	# also what keeps the map pinned to the corner when the window is resized.
	var cols := float(level.cells_x)
	var rows := float(level.cells_z)
	var vp := get_viewport()
	var screen := vp.get_visible_rect().size if vp != null else Vector2(1280, 720)
	var scale := minf(minf(MINIMAP_PX.x / cols, MINIMAP_PX.y / rows), 64.0)
	_minimap.scale = Vector2(scale, scale)
	_minimap.position = Vector2(
		maxf(0.0, screen.x - cols * scale) - MINIMAP_MARGIN,
		MINIMAP_MARGIN)
	_minimap.visible = true
	_minimap.clear()
	_minimap.set_extent(Vector2(cols, rows))
	# Arena floor + walls.
	for z in level.cells_z:
		for x in level.cells_x:
			var g: String = level.glyph_at(x, z)
			var pos := Vector2(x, z)
			var tile := Rect2(pos, Vector2.ONE)
			if g == "#" or g == "+" or g == "o":
				_minimap.add_rect(tile, Color(0.36, 0.38, 0.45))
			elif g == "=":
				_minimap.add_rect(tile, Color(0.30, 0.32, 0.40))
			else:
				_minimap.add_rect(tile, Color(0.14, 0.15, 0.19))
	# Portal marker (purple).
	for node in host.get_children():
		if node is SpawnerPortal:
			var pp := level.world_to_cell(node.global_position)
			_minimap.add_circle(Vector2(pp) + Vector2(0.5, 0.5), 0.42, Color(0.75, 0.35, 1.0))
	# Enemy markers (red).
	for e in get_tree().get_nodes_in_group("enemies"):
		if e is Node3D and is_instance_valid(e):
			var ep := level.world_to_cell(e.global_position)
			_minimap.add_circle(Vector2(ep) + Vector2(0.5, 0.5), 0.32, Color(0.95, 0.22, 0.2))
	# Player marker (white) plus the view cone, so the map says where the
	# caster is looking and not only where they are -- on a 56x40 arena the
	# difference between "the demon is north" and "the demon is north-west of
	# where I am looking" is the whole read.
	var pl := level.world_to_cell(_player.global_position)
	var here := Vector2(pl) + Vector2(0.5, 0.5)
	var look := _player.look_direction()
	_minimap.set_facing(here, Vector2(look.x, look.z))
	_minimap.add_circle(here, 0.38, Color(1, 1, 1))

## Runs down the hit marker and screen shake timers (ROADMAP Stage 3 VFX).
func _tick_vfx(delta: float) -> void:
	if _hit_time > 0.0:
		_hit_time = maxf(0.0, _hit_time - delta)
		if _hitmarker != null:
			_hitmarker.visible = _hit_time > 0.0
	if _shake_time > 0.0:
		_shake_time = maxf(0.0, _shake_time - delta)
		var offset := Vector2.ZERO
		if _shake_time > 0.0:
			offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * SHAKE_AMOUNT * (_shake_time / SHAKE_TIME)
		if _root != null:
			_root.position = offset
	if _damage_time > 0.0:
		_damage_time = maxf(0.0, _damage_time - delta)
		if _damage_flash != null:
			var a := (_damage_time / DAMAGE_FLASH_TIME) * 0.4
			_damage_flash.color = Color(0.9, 0.15, 0.2, a)

func _refresh() -> void:
	if _game != null:
		var total := int(ceil(_game.time_left))
		@warning_ignore("integer_division")
		var minutes := total / 60
		_timer_label.text = "%02d:%02d  ·  NG+%d" % [minutes, total % 60, int(Meta.ng_level)]
		_xp_bar.value = _game.xp_ratio()
	else:
		# No run director (training hall): the clock slots read as "free mode".
		_timer_label.text = "--:--"
		_xp_bar.value = 0.0
	if _player != null:
		_health_bar.value = clampf(_player.health / _player.max_health, 0.0, 1.0)
		_soul_bar.value = _player.soul_gauge
		# Indicate the ultimate (0 / Last Judgement): the soul bar pulses gold once
		# full, and the 0-slot dims until the gauge is charged.
		var ready := _player.soul_gauge >= 1.0
		_soul_bar.modulate = Color.WHITE if ready else Color(0.75, 0.75, 0.75, 1.0)
		for holder in _slots:
			var id := int(holder.get_meta("spell_id"))
			# Locked spells stay off the bar entirely: only open slots are shown.
			var spell: BaseSpell = null
			if _player != null:
				for s in _player.spells:
					if s.spell_id == id:
						spell = s
						break
			holder.visible = spell != null and not spell.is_locked
			var overlay := holder.get_meta("overlay") as ColorRect
			if overlay != null:
				var cd := _player.cooldown_ratio(id)
				if id == 0 and not ready:
					cd = 1.0
				overlay.color.a = cd
	# Boss health bar.
	if _boss_bar != null and _boss_bar.visible:
		if _boss == null or not is_instance_valid(_boss):
			_boss_bar.visible = false
			if _boss_label != null:
				_boss_label.visible = false
		else:
			_boss_bar.value = clampf(_boss.health / _boss.max_health, 0.0, 1.0)

## Mirrors the player's Hold & Release charge (0..1) onto the on-screen bar.
func _on_charge_changed(ratio: float) -> void:
	_charge_ratio = clampf(ratio, 0.0, 1.0)
	if _charge_bar != null:
		_charge_bar.value = _charge_ratio
		_charge_bar.visible = _charge_ratio > 0.0

## Current charge fill shown by the indicator (0..1); exposed for tests.
func get_charge_ratio() -> float:
	return _charge_ratio

## True while the charge indicator is on screen.
func is_charge_visible() -> bool:
	return _charge_bar != null and _charge_bar.visible

## Flashes the crosshair hit marker (ROADMAP Stage 3 VFX).  Called on any hit.
func flash_hitmarker() -> void:
	_hit_time = HIT_MARKER_TIME
	if _hitmarker != null:
		_hitmarker.visible = true

## Kicks a short camera shake when the caster takes damage (ROADMAP Stage 3 VFX).
func shake() -> void:
	_shake_time = SHAKE_TIME

## Lights the red damage flash when the caster is hit (ROADMAP Stage B).
func flash_damage() -> void:
	_damage_time = DAMAGE_FLASH_TIME
	if _damage_flash != null:
		_damage_flash.color = Color(0.9, 0.15, 0.2, 0.4)

## True while the damage flash is fading; exposed for tests.
func is_damage_flashing() -> bool:
	return _damage_time > 0.0

## True while the hit marker cross is on screen; exposed for tests.
func is_hitmarker_visible() -> bool:
	return _hitmarker != null and _hitmarker.visible

## True while the screen shake timer is still running; exposed for tests.
func is_shaking() -> bool:
	return _shake_time > 0.0

## Called by a nearby NPCDialog when the player walks into its trigger sphere.
func show_dialog(text: String) -> void:
	_dialog_label.text = text

## Clears the survivor line when the player walks away.
func clear_dialog() -> void:
	_dialog_label.text = ""

## Filename-caption for the floor reached (ROADMAP Stage C: progression through
## the three GDD floors). Fades in and back out over a couple of seconds.
func show_floor_banner(floor_name: String) -> void:
	if _root == null:
		return
	var label := Label.new()
	label.text = "ЭТАЖ: %s" % floor_name.to_upper()
	label.add_theme_font_size_override("font_size", 40)
	label.add_theme_color_override("font_color", Color("#9fe8ff"))
	label.position = Vector2(360, 130)
	label.modulate.a = 0.0
	_root.add_child(label)
	var tween := create_tween()
	tween.tween_property(label, "modulate:a", 1.0, 0.3)
	tween.tween_interval(1.6)
	tween.tween_property(label, "modulate:a", 0.0, 0.5)
	tween.tween_callback(label.queue_free)

## NG+ post-victory overlay: offer one permanent perk to carry into the next
## run, then show the victory banner.
func show_postwin_choices() -> void:
	if _root == null:
		return
	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(overlay)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.75)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(centre)
	var panel := VBoxContainer.new()
	panel.add_theme_constant_override("separation", 14)
	centre.add_child(panel)
	var title := Label.new()
	title.text = "ПОБЕДА! Выбери постоянный апгрейд:"
	title.add_theme_font_size_override("font_size", 32)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(title)
	var meta := get_node_or_null("/root/Meta")
	# Prevent a held attack-click from instantly picking the centre card.
	var lock_until := Time.get_ticks_msec() + 450
	var picks := [
		["+25 к макс. здоровью (навсегда)", "perm_hp"],
		["+10% к урону (навсегда)", "perm_dmg"],
		["+10% к скорости бега (навсегда)", "perm_speed"],
	]
	for i in picks.size():
		var btn := _postwin_button(picks[i][0], picks[i][1], meta, overlay)
		btn.set_meta("lock_until", lock_until)
		panel.add_child(btn)
	var hint := Label.new()
	hint.text = "После выбора нажми R для нового забега (NG+%d)" % int(Meta.ng_level)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(hint)

## A single NG+ perk button (its lambda captures per-call parameters).
func _postwin_button(label: String, perk: String, meta: Node, overlay: Control) -> Button:
	var b := Button.new()
	b.text = label
	b.custom_minimum_size = Vector2(420, 52)
	b.pressed.connect(func() -> void:
		if Time.get_ticks_msec() < int(b.get_meta("lock_until", 0)):
			return
		if meta != null:
			match perk:
				"perm_hp":
					meta.perm_hp_bonus += 25.0
				"perm_dmg":
					meta.perm_dmg_mult *= 1.10
				"perm_speed":
					meta.perm_speed_mult *= 1.10
			meta.save_meta()
		overlay.queue_free()
		show_victory()
	)
	return b

func show_victory() -> void:
	_show_banner("ВЫ ВЫЖИЛИ!", Color("#ffe9a8"))
	_victory = true

## Transient callout for the wave director's breathing (НАТИСК / ПЕРЕДЫШКА),
## distinct colour from the floor banner so the two never clash.
func show_wave_banner(text: String) -> void:
	if _root == null:
		return
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 30)
	label.add_theme_color_override("font_color", Color("#ffd166"))
	label.position = Vector2(360, 170)
	label.modulate.a = 0.0
	_root.add_child(label)
	var tween := create_tween()
	tween.tween_property(label, "modulate:a", 1.0, 0.2)
	tween.tween_interval(1.4)
	tween.tween_property(label, "modulate:a", 0.0, 0.4)
	tween.tween_callback(label.queue_free)

func show_game_over() -> void:
	_show_banner("ВЫ ПОГИБЛИ", Color("#c2364a"))
	_victory = false

## True once the victory banner has been raised (exposed for integration tests).
func is_victory() -> bool:
	return _victory

func _show_banner(text: String, colour: Color) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 64)
	label.add_theme_color_override("font_color", colour)
	label.position = Vector2(360, 300)
	_root.add_child(label)
	var hint := Label.new()
	hint.text = "Нажми R, чтобы начать заново"
	hint.add_theme_font_size_override("font_size", 24)
	hint.add_theme_color_override("font_color", Color("#eaeaf2"))
	hint.position = Vector2(360, 390)
	_root.add_child(hint)
