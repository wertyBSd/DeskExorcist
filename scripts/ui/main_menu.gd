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

var _root: Control
var _settings_screen: Node

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
	box.add_child(_button("Настройки", _on_settings))
	box.add_child(_button("Выход", _on_quit))

	_settings_screen = (load(SETTINGS_SCENE) as GDScript).new()
	_settings_screen.name = "SettingsScreen"
	add_child(_settings_screen)

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

## Raises the settings overlay.
func _on_settings() -> void:
	if _settings_screen != null:
		_settings_screen.open()

## Leaves the game.
func _on_quit() -> void:
	get_tree().quit()

## True while the settings overlay is showing; used by tests.
func is_settings_open() -> bool:
	return _settings_screen != null and _settings_screen.visible
