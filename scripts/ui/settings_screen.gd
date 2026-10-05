class_name SettingsScreen
## Stage 4 settings overlay (ROADMAP P3).
##
## Sliders for the five audio buses plus mouse sensitivity, and a window
## resolution picker.  Every change is pushed straight into the Settings autoload
## and persisted to user://settings.cfg.  Built entirely in code (same pattern as
## PauseMenu) so the main menu and, later, an in-game options screen can reuse it.
## null-safe: if the Settings autoload is missing (isolated tests) it still builds.
extends CanvasLayer

## Emitted when the player backs out of the screen.
signal closed

const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
]

var _root: Control
var _sliders: Dictionary = {}   # key -> HSlider
var _resolution: OptionButton

func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_sync_from_settings()
	visible = false

func _settings() -> Node:
	return get_node_or_null("/root/Settings")

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.78)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)

	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(centre)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.custom_minimum_size = Vector2(440, 0)
	centre.add_child(box)

	var title := Label.new()
	title.text = "НАСТРОЙКИ"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	box.add_child(title)

	_sliders["master"] = _add_slider(box, "Общая громкость", 0.0, 1.0, 0.01, _on_master)
	_sliders["music"] = _add_slider(box, "Музыка", 0.0, 1.0, 0.01, _on_music)
	_sliders["sfx"] = _add_slider(box, "Эффекты", 0.0, 1.0, 0.01, _on_sfx)
	_sliders["ambient"] = _add_slider(box, "Эмбиент", 0.0, 1.0, 0.01, _on_ambient)
	_sliders["ui"] = _add_slider(box, "Интерфейс", 0.0, 1.0, 0.01, _on_ui)
	_sliders["sensitivity"] = _add_slider(box, "Чувствительность мыши", 0.0005, 0.01, 0.0001, _on_sensitivity)

	_add_resolution_row(box)
	box.add_child(_button("Назад", _on_back))

func _add_slider(parent: Control, label_text: String, lo: float, hi: float, step: float, handler: Callable) -> HSlider:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	parent.add_child(row)
	var label := Label.new()
	label.text = label_text
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = lo
	slider.max_value = hi
	slider.step = step
	slider.custom_minimum_size = Vector2(420, 24)
	slider.value_changed.connect(handler)
	row.add_child(slider)
	return slider

func _add_resolution_row(parent: Control) -> void:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	parent.add_child(row)
	var label := Label.new()
	label.text = "Разрешение окна"
	row.add_child(label)
	_resolution = OptionButton.new()
	for res in RESOLUTIONS:
		_resolution.add_item("%d x %d" % [res.x, res.y])
	_resolution.item_selected.connect(_on_resolution)
	row.add_child(_resolution)

func _button(text: String, handler: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(220, 44)
	b.pressed.connect(handler)
	return b

## Pulls the stored values into the widgets without re-emitting change signals.
func _sync_from_settings() -> void:
	var s := _settings()
	if s == null:
		return
	_set_slider(&"master", s.master_volume)
	_set_slider(&"music", s.music_volume)
	_set_slider(&"sfx", s.sfx_volume)
	_set_slider(&"ambient", s.ambient_volume)
	_set_slider(&"ui", s.ui_volume)
	_set_slider(&"sensitivity", s.mouse_sensitivity)
	if _resolution != null:
		for i in RESOLUTIONS.size():
			if RESOLUTIONS[i] == Vector2i(s.window_width, s.window_height):
				_resolution.select(i)
				break

func _set_slider(key: StringName, value: float) -> void:
	if not _sliders.has(key):
		return
	var slider: HSlider = _sliders[key]
	slider.set_value_no_signal(value)

## Shows the overlay (used by the main menu and available to tests).
func open() -> void:
	_sync_from_settings()
	visible = true

## Hides the overlay and announces it.
func close() -> void:
	visible = false
	closed.emit()

# --- Slider callbacks -------------------------------------------------------

func _on_master(value: float) -> void:
	var s := _settings()
	if s != null:
		s.master_volume = value
		s.set_bus_volume(&"Master", value)

func _on_music(value: float) -> void:
	var s := _settings()
	if s != null:
		s.music_volume = value
		s.set_bus_volume(&"Music", value)

func _on_sfx(value: float) -> void:
	var s := _settings()
	if s != null:
		s.sfx_volume = value
		s.set_bus_volume(&"SFX", value)

func _on_ambient(value: float) -> void:
	var s := _settings()
	if s != null:
		s.ambient_volume = value
		s.set_bus_volume(&"Ambient", value)

func _on_ui(value: float) -> void:
	var s := _settings()
	if s != null:
		s.ui_volume = value
		s.set_bus_volume(&"UI", value)

func _on_sensitivity(value: float) -> void:
	var s := _settings()
	if s != null:
		s.mouse_sensitivity = value

func _on_resolution(index: int) -> void:
	var s := _settings()
	if s == null or index < 0 or index >= RESOLUTIONS.size():
		return
	var res := RESOLUTIONS[index]
	s.window_width = res.x
	s.window_height = res.y
	s.apply_window_size()

## Persist everything and hand control back to the caller.
func _on_back() -> void:
	var s := _settings()
	if s != null:
		s.save_settings()
	close()
