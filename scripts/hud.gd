class_name HUD
## Heads-up display (GDD section 4): session timer, health, XP, soul gauge and
## the 1-0 ability bar with per-slot cooldown fills.  Built entirely in code so
## the HUD needs no .tscn wiring.
extends CanvasLayer

const ICON := 40

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

func _ready() -> void:
	layer = 1
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
	icon.texture = PlaceholderArt.spell_icon(InputSetup.spell_id_for_slot(slot))
	icon.custom_minimum_size = Vector2(ICON, ICON)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	holder.add_child(icon)
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.6)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(overlay)
	holder.set_meta("overlay", overlay)
	holder.set_meta("spell_id", InputSetup.spell_id_for_slot(slot))
	_slots.append(holder)
	return holder

func _process(_delta: float) -> void:
	if _player == null:
		_bind_player(EffectUtil.player(get_tree()) as Player)
	if _game == null:
		var games := get_tree().get_nodes_in_group("game")
		if not games.is_empty():
			_game = games[0] as Game
	_refresh()

func _refresh() -> void:
	if _game != null:
		var total := int(ceil(_game.time_left))
		@warning_ignore("integer_division")
		var minutes := total / 60
		_timer_label.text = "%02d:%02d" % [minutes, total % 60]
		_xp_bar.value = _game.xp_ratio()
	if _player != null:
		_health_bar.value = clampf(_player.health / _player.max_health, 0.0, 1.0)
		_soul_bar.value = _player.soul_gauge
		for holder in _slots:
			var id := int(holder.get_meta("spell_id"))
			var overlay := holder.get_meta("overlay") as ColorRect
			if overlay != null:
				overlay.color.a = _player.cooldown_ratio(id)

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

## Called by a nearby NPCDialog when the player walks into its trigger sphere.
func show_dialog(text: String) -> void:
	_dialog_label.text = text

## Clears the survivor line when the player walks away.
func clear_dialog() -> void:
	_dialog_label.text = ""

func show_victory() -> void:
	_show_banner("ВЫ ВЫЖИЛИ!", Color("#ffe9a8"))

func show_game_over() -> void:
	_show_banner("ВЫ ПОГИБЛИ", Color("#c2364a"))

func _show_banner(text: String, colour: Color) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 64)
	label.add_theme_color_override("font_color", colour)
	label.position = Vector2(360, 300)
	_root.add_child(label)
