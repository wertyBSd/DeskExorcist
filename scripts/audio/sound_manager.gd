extends Node
## Sound manager singleton (Autoload: SoundManager).  ROADMAP Stage 4.
##
## STUB for now: no audio files ship yet, so every play() is a counted no-op.
## The API is final and null-safe, so wiring call sites now means dropping the
## .ogg/.wav files (per SOUND_LIST.md) in later needs no code changes here.
##
## Buses (Music/SFX/Ambient/UI) are created on demand and their volumes come from
## the Settings autoload, which the settings screen edits.

## Emitted whenever a cue is requested; exposed so tests can assert the wiring.
signal cue_requested(key: StringName)

## Cues requested this session (key -> count); a stub stand-in for playback.
var _play_counts: Dictionary = {}
var _music_key: StringName = &""

func _ready() -> void:
	ensure_buses()

## Creates the four game buses under Master if they do not already exist.
func ensure_buses() -> void:
	for bus in [&"Music", &"SFX", &"Ambient", &"UI"]:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
	apply_volumes()

## Pulls bus volumes from Settings (called on ready and after a settings change).
func apply_volumes() -> void:
	if not has_node("/root/Settings"):
		return
	var s := get_node("/root/Settings")
	_set_bus(&"Music", s.music_volume)
	_set_bus(&"SFX", s.sfx_volume)
	_set_bus(&"Ambient", s.ambient_volume)
	_set_bus(&"UI", s.ui_volume)

func _set_bus(bus: StringName, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus)
	if idx < 0:
		return
	AudioServer.set_bus_mute(idx, linear <= 0.0)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, 0.0001)))

## One-shot SFX request.  No-op until the matching file exists (see SOUND_LIST).
func play(key: StringName, _position: Vector3 = Vector3.INF) -> void:
	_play_counts[key] = int(_play_counts.get(key, 0)) + 1
	cue_requested.emit(key)

## Starts a looping music track.  Stub: just remembers the current key.
func play_music(key: StringName) -> void:
	_music_key = key
	cue_requested.emit(key)

## Stops the current music track (no-op stub).
func stop_music() -> void:
	_music_key = &""

## How many times a cue was requested; used by tests to prove wiring.
func play_count(key: StringName) -> int:
	return int(_play_counts.get(key, 0))

## Current music key ("" when silent); used by tests.
func music_key() -> StringName:
	return _music_key
