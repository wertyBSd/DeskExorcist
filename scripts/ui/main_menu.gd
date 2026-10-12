class_name MainMenu
## Stage 4 main menu (ROADMAP P3).
##
## The new entry scene (see project.godot run/main_scene).  Start loads the run
## scene, Settings raises the shared SettingsScreen overlay, Quit exits.  Built
## entirely in code, matching PauseMenu's pattern, and null-safe so it can be
## instantiated in headless tests without a live window.
extends CanvasLayer

## The run scene launched by Start.
const RUN_SCENE := "res://scenes/main.tscn"

## Emitted when the player presses Start; main scene loading is left to the node
## so a test can observe the signal without actually swapping scenes.
signal start_requested

## Path to the shared settings overlay script (loaded dynamically so the global
## class cache is never required on a fresh headless run).
const SETTINGS_SCENE := "res://scripts/ui/settings_screen.gd"
const META_SCREEN := "res://scripts/ui/meta_screen.gd"

var _root: Control
var _settings_screen: Node
var _meta_screen: Node
var _terminal_overlay: Control

func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_build()

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.05, 0.08, 1.0)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)

	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(centre)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	centre.add_child(box)

	var title := Label.new()
	title.text = "DESK EXORCIST"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 52)
	box.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Выживи 10 минут среди офисных демонов"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 16)
	box.add_child(subtitle)

	box.add_child(_spacer(10))
	box.add_child(_button("Старт", _on_start))
	box.add_child(_button("Терминал", _on_terminal))
	box.add_child(_button("Мета", _on_meta))
	box.add_child(_button("Тренировочный зал", _on_training))
	box.add_child(_button("Настройки", _on_settings))
	box.add_child(_button("Выход", _on_quit))

	_settings_screen = (load(SETTINGS_SCENE) as GDScript).new()
	_settings_screen.name = "SettingsScreen"
	add_child(_settings_screen)
	_meta_screen = (load(META_SCREEN) as GDScript).new()
	_meta_screen.name = "MetaScreen"
	add_child(_meta_screen)

func _spacer(height: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, height)
	return c

func _button(text: String, handler: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(300, 52)
	b.pressed.connect(handler)
	b.pressed.connect(_play_click)
	b.mouse_entered.connect(_play_hover)
	return b

func _play_click() -> void:
	EffectUtil.sound(get_tree(), &"ui_click")

func _play_hover() -> void:
	EffectUtil.sound(get_tree(), &"ui_hover")

## Loads the run scene (Start button / start_requested consumers).
func _on_start() -> void:
	start_requested.emit()
	get_tree().change_scene_to_file(RUN_SCENE)

## Opens the meta-progression overlay (soul shop + campaign stats).
func _on_meta() -> void:
	if _meta_screen != null:
		_meta_screen.open()

## Raises the settings overlay.
func _on_settings() -> void:
	if _settings_screen != null:
		_settings_screen.open()

## The pre-run terminal: a quick pick of one starting perk (GDD analogue of
## "загрузка персонажа") so the player enters a run with a chosen flavour.
func _on_terminal() -> void:
	if _terminal_overlay == null:
		_build_terminal()
	_terminal_overlay.visible = true

func _build_terminal() -> void:
	_terminal_overlay = Control.new()
	_terminal_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_terminal_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_terminal_overlay)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_terminal_overlay.add_child(dim)
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	_terminal_overlay.add_child(centre)
	var panel := VBoxContainer.new()
	panel.add_theme_constant_override("separation", 12)
	centre.add_child(panel)
	var title := Label.new()
	title.text = "ТЕРМИНАЛ СНАРЯЖЕНИЯ"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	panel.add_child(title)
	var perks := [
		["vigor", "Живучесть: +50 к максимальному здоровью"],
		["swiftness", "Скорость: +20% к скорости бега"],
		["zeal", "Рвение: +20% к урону атак"],
	]
	for p in perks:
		panel.add_child(_perk_button(p[0], p[1]))
	var close := Button.new()
	close.text = "Готово"
	close.custom_minimum_size = Vector2(420, 48)
	close.pressed.connect(func() -> void:
		_terminal_overlay.visible = false)
	panel.add_child(close)
	_terminal_overlay.visible = false

## A terminal button with its own captured perk id (lambda captures params by
## value per call, so each button works independently).
func _perk_button(perk_id: String, label: String) -> Button:
	var b := Button.new()
	b.text = label
	b.custom_minimum_size = Vector2(420, 48)
	b.pressed.connect(func() -> void:
		var meta := get_node_or_null("/root/Meta")
		if meta != null:
			meta.starting_perk = perk_id
		b.text = label + "  ✓"
		b.grab_focus())
	return b

## Loads the training hall (no enemies, static dummies, Esc returns here).
func _on_training() -> void:
	get_tree().change_scene_to_file("res://scenes/training.tscn")

## Leaves the game.
func _on_quit() -> void:
	get_tree().quit()

## True while the settings overlay is showing; used by tests.
func is_settings_open() -> bool:
	return _settings_screen != null and _settings_screen.visible

## True while the meta-progression overlay is showing; used by tests.
func is_meta_open() -> bool:
	return _meta_screen != null and _meta_screen.visible
