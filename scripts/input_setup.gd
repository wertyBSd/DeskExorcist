extends Node
## Registers every input action the game needs, at runtime.
##
## Doing this here instead of inside project.godot keeps the bindings readable
## and avoids hand-writing serialized InputEvent blobs. Physical key codes are
## used so WASD and the 1-0 number row keep working on any keyboard layout.

## slot index (0-9) -> the digit the player presses (slot 0 is "1", slot 9 is "0").
const SPELL_KEYS: Array[Key] = [
	KEY_1, KEY_2, KEY_3, KEY_4, KEY_5,
	KEY_6, KEY_7, KEY_8, KEY_9, KEY_0,
]

## Action name for a spell slot. Slot 0 is key "1" ... slot 9 is key "0".
func spell_action(slot: int) -> StringName:
	return StringName("spell_%d" % ((slot + 1) % 10))

## Spell id for a slot -- identical to the GDD's "i %% 10" numbering.
func spell_id_for_slot(slot: int) -> int:
	return (slot + 1) % 10

func _enter_tree() -> void:
	_bind_keys(&"move_up", [KEY_W, KEY_UP])
	_bind_keys(&"move_down", [KEY_S, KEY_DOWN])
	_bind_keys(&"move_left", [KEY_A, KEY_LEFT])
	_bind_keys(&"move_right", [KEY_D, KEY_RIGHT])
	_bind_keys(&"jump", [KEY_SPACE])
	_bind_mouse(&"attack", MOUSE_BUTTON_LEFT)
	_bind_keys(&"pause", [KEY_ESCAPE])
	_bind_keys(&"restart", [KEY_R])
	_bind_keys(&"debug_kill_all", [KEY_K])
	for slot in SPELL_KEYS.size():
		_bind_keys(spell_action(slot), [SPELL_KEYS[slot]])

func _bind_keys(action: StringName, keys: Array) -> void:
	if InputMap.has_action(action):
		InputMap.erase_action(action)
	InputMap.add_action(action, 0.2)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)

func _bind_mouse(action: StringName, button: MouseButton) -> void:
	if InputMap.has_action(action):
		InputMap.erase_action(action)
	InputMap.add_action(action, 0.2)
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)
