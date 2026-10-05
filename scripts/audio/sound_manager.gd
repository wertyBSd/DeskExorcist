extends Node
## Sound manager singleton (Autoload: SoundManager).  ROADMAP Stage 4.
##
## Plays the real audio files shipped in res://sound/ (see SOUND_LIST.md).  The
## public API is unchanged from the Stage-4 stub, so no call site needed editing:
## EffectUtil.sound(tree, key, position) for one-shots, EffectUtil.music(tree, key)
## for the looping track, EffectUtil.spell_cast(tree, spell_id, position) for a
## cast cue.  Every stream is loaded lazily and a missing / unsupported file
## degrades to a counted no-op, keeping the headless suite green.
##
## Buses (Music/SFX/Ambient/UI) are created on demand and their volumes come from
## the Settings autoload, which the settings screen edits.

## Emitted whenever a cue is requested; exposed so tests can assert the wiring.
signal cue_requested(key: StringName)

## One-shot cue key -> res:// path.  Keys follow SOUND_LIST.md.  Note: .aiff is
## not importable by Godot, so spell_06 (chain cast) is intentionally omitted and
## degrades to a no-op until a .wav/.ogg version is dropped in.
const CUES := {
	"bolt_fire": "res://sound/bolt_fire.wav",
	"bolt_impact": "res://sound/bolt_impact.wav",
	"bolt_reflect": "res://sound/bolt_reflect.wav",
	"level_up": "res://sound/level_up.wav",
	"player_charge_start": "res://sound/player_charge_start.wav",
	"player_charge_loop": "res://sound/player_charge_loop.wav",
	"player_cast_release": "res://sound/player_cast_release.wav",
	"player_fizzle": "res://sound/player_fizzle.wav",
	"player_dash": "res://sound/player_dash.wav",
	"player_death": "res://sound/player_death.mp3",
	"player_hurt": "res://sound/player_hurt.wav",
	"player_jump": "res://sound/player_jump.wav",
	"player_land": "res://sound/player_land.wav",
	"player_footstep": "res://sound/player_footstep_01.wav",
	"soul_pickup": "res://sound/soul_pickup_01.wav",
	"ui_click": "res://sound/ui_click.wav",
	"ui_hover": "res://sound/ui_hover.wav",
	"ui_card_reveal": "res://sound/ui_card_reveal.wav",
	"ui_card_pick": "res://sound/ui_card_pick.wav",
	"ui_pause": "res://sound/ui_pause.wav",
	"spell_00_cast": "res://sound/spell_00_judgement_cast.wav",
	"spell_01_cast": "res://sound/spell_01_purify_cast.wav",
	"spell_02_cast": "res://sound/spell_02_ground_cast.mp3",
	"spell_03_cast": "res://sound/spell_03_pride_cast.mp3",
	"spell_04_cast": "res://sound/spell_04_beam_cast.flac",
	"spell_05_cast": "res://sound/spell_05_hammer_cast.wav",
	"spell_08_cast": "res://sound/spell_08_step_cast.wav",
	"spell_09_cast": "res://sound/spell_09_mirror_cast.wav",
}

## Music key -> looping track.  No music_*.ogg has shipped yet, so this is empty
## on purpose; add entries when the tracks land and they play as-is.
const MUSIC := {}

## Cues requested this session (key -> count); also proves wiring in tests.
var _play_counts: Dictionary = {}
var _music_key: StringName = &""

## path -> loaded AudioStream (or null when the file is absent / unsupported).
var _streams: Dictionary = {}
var _music_player: AudioStreamPlayer = null

func _ready() -> void:
	ensure_buses()
	_music_player = AudioStreamPlayer.new()
	_music_player.name = "MusicPlayer"
	_music_player.bus = &"Music"
	add_child(_music_player)

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

## True when `key` has a real audio file mapped; used by call sites and tests.
func has_cue(key: StringName) -> bool:
	return CUES.has(String(key))

## Cast cue key for a GDD spell id (1..9, 0); &"" when that spell has no file.
func spell_cast_key(spell_id: int) -> StringName:
	var key := "spell_%02d_cast" % spell_id
	return StringName(key) if CUES.has(key) else &""

## One-shot SFX request.  Always counts the cue and emits cue_requested; plays
## the mapped file when it exists / imports.  Positional when a world position
## is supplied and a live scene is running, otherwise non-positional.
func play(key: StringName, position: Vector3 = Vector3.INF) -> void:
	_play_counts[key] = int(_play_counts.get(key, 0)) + 1
	cue_requested.emit(key)
	var path: String = String(CUES.get(String(key), ""))
	if path.is_empty():
		return
	var stream := _load_stream(path)
	if stream == null:
		return
	var bus := &"UI" if String(key).begins_with("ui_") else &"SFX"
	if position != Vector3.INF and get_tree() != null and get_tree().current_scene != null:
		var p3 := AudioStreamPlayer3D.new()
		p3.stream = stream
		p3.bus = bus
		p3.max_distance = 40.0
		add_child(p3)
		p3.global_position = position
		p3.finished.connect(p3.queue_free)
		p3.play()
	else:
		var p := AudioStreamPlayer.new()
		p.stream = stream
		p.bus = bus
		add_child(p)
		p.finished.connect(p.queue_free)
		p.play()

## Starts (or switches to) a looping music track.  Remembers the key even when
## no file is shipped yet, so call sites and tests stay valid.
func play_music(key: StringName) -> void:
	_music_key = key
	cue_requested.emit(key)
	var path: String = String(MUSIC.get(String(key), ""))
	if path.is_empty() or _music_player == null:
		return
	var stream := _load_stream(path)
	if stream == null:
		return
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	elif stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
	_music_player.stream = stream
	_music_player.play()

## Stops the current music track.
func stop_music() -> void:
	_music_key = &""
	if _music_player != null:
		_music_player.stop()

## Loads (and caches) an audio stream; returns null when the file is absent or
## cannot be imported, so playback silently degrades instead of erroring.
func _load_stream(path: String) -> AudioStream:
	if _streams.has(path):
		return _streams[path]
	var stream: AudioStream = null
	if ResourceLoader.exists(path):
		stream = ResourceLoader.load(path) as AudioStream
	_streams[path] = stream
	return stream

## How many times a cue was requested; used by tests to prove wiring.
func play_count(key: StringName) -> int:
	return int(_play_counts.get(key, 0))

## Current music key ("" when silent); used by tests.
func music_key() -> StringName:
	return _music_key
