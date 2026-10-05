extends Node
## User settings singleton (Autoload: Settings).  ROADMAP Stage 4.
##
## Persists volume, mouse sensitivity and window size to user://settings.cfg and
## applies them through AudioServer / DisplayServer.  The player reads
## `mouse_sensitivity` every frame so a slider change takes effect instantly.
## Sound itself is stubbed for now (see SoundManager); the volume values here are
## already the single source of truth it will read once audio files land.

const PATH := "user://settings.cfg"

## Audio buses the game owns.  SoundManager creates them if missing.
const BUSES: Array[StringName] = [&"Master", &"Music", &"SFX", &"Ambient", &"UI"]

var master_volume := 1.0
var music_volume := 0.8
var sfx_volume := 1.0
var ambient_volume := 0.8
var ui_volume := 1.0
var mouse_sensitivity := 0.002
var window_width := 1280
var window_height := 720

func _ready() -> void:
	load_settings()

## Reads user://settings.cfg (if present) and applies every value.
func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		master_volume = cfg.get_value("audio", "master", master_volume)
		music_volume = cfg.get_value("audio", "music", music_volume)
		sfx_volume = cfg.get_value("audio", "sfx", sfx_volume)
		ambient_volume = cfg.get_value("audio", "ambient", ambient_volume)
		ui_volume = cfg.get_value("audio", "ui", ui_volume)
		mouse_sensitivity = cfg.get_value("input", "mouse_sensitivity", mouse_sensitivity)
		window_width = cfg.get_value("video", "width", window_width)
		window_height = cfg.get_value("video", "height", window_height)
	apply_all()

## Writes the current values back to disk (called by the settings screen).
func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master", master_volume)
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.set_value("audio", "ambient", ambient_volume)
	cfg.set_value("audio", "ui", ui_volume)
	cfg.set_value("input", "mouse_sensitivity", mouse_sensitivity)
	cfg.set_value("video", "width", window_width)
	cfg.set_value("video", "height", window_height)
	cfg.save(PATH)
	apply_all()

## Pushes the stored values into the engine.
func apply_all() -> void:
	set_bus_volume(&"Master", master_volume)
	set_bus_volume(&"Music", music_volume)
	set_bus_volume(&"SFX", sfx_volume)
	set_bus_volume(&"Ambient", ambient_volume)
	set_bus_volume(&"UI", ui_volume)
	apply_window_size()

## Resizes the game window to the stored resolution.  Guarded so it is a no-op
## in a headless run (the dummy DisplayServer cannot resize a window).
func apply_window_size() -> void:
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_size(Vector2i(window_width, window_height))

## Linear volume (0..1) -> decibels on the named bus, muted at 0.
## A missing bus is created on demand so the game runs before the layout exists.
func set_bus_volume(bus: StringName, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus)
	if idx < 0:
		AudioServer.add_bus()
		idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, bus)
	var value := clampf(linear, 0.0, 1.0)
	AudioServer.set_bus_mute(idx, value <= 0.0)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(value, 0.0001)))
