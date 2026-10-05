class_name PauseMenu
## Real pause overlay (ROADMAP 1.3).
##
## Esc freezes the run through get_tree().paused and raises this menu; R (or the
## Restart button) reloads the current scene for a fresh attempt. The node runs
## with PROCESS_MODE_ALWAYS so it keeps reading input while the tree is paused --
## and so it can unpause itself. It leaves the pause flag alone whenever a
## level-up screen is on top, so the two overlays never fight over the same
## boolean.
extends CanvasLayer

## Emitted when the player asks for a fresh run (R or the Restart button).
signal restart_requested

var _root: Control

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 6
	_build()
	visible = false

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Swallow clicks on the dim backdrop so they never reach the frozen game.
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)

	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(centre)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	centre.add_child(box)

	var title := Label.new()
	title.text = "ПАУЗА"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	box.add_child(title)

	box.add_child(_button("Продолжить", _on_resume))
	box.add_child(_button("Рестарт", _on_restart))
	box.add_child(_button("Выход", _on_quit))

func _button(text: String, handler: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(260, 48)
	b.pressed.connect(handler)
	return b

## Toggles the overlay. Used by Esc and available to tests.
func toggle() -> void:
	if visible:
		close()
	else:
		open()

## Freezes the tree, releases the cursor and shows the buttons.
func open() -> void:
	if visible:
		return
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	visible = true

## Unpauses the run and re-captures the cursor for first-person aiming.
func close() -> void:
	if not visible:
		return
	visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

## True while the overlay is on screen.
func is_open() -> bool:
	return visible

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"restart"):
		_restart()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"pause"):
		# A visible level-up screen owns the pause; let it keep the key.
		if not visible and _level_up_open():
			return
		toggle()
		get_viewport().set_input_as_handled()

func _on_resume() -> void:
	close()

func _on_restart() -> void:
	_restart()

func _on_quit() -> void:
	get_tree().paused = false
	get_tree().quit()

## Reloads the current scene and re-captures the cursor for a fresh run.
func _restart() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	restart_requested.emit()
	get_tree().reload_current_scene()

## True while a level-up screen is visible (it shares the pause boolean).
func _level_up_open() -> bool:
	for node in get_tree().get_nodes_in_group("level_up_screen"):
		if node is CanvasLayer and node.visible:
			return true
	return false
