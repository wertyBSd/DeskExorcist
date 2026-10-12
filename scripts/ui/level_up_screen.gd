class_name LevelUpScreen
## The three-card roguelike choice (GDD section 6).
##
## open() pauses the tree, shuffles the reward pool and lays out three cards.
## Picking one applies it, unpauses the game and hides the screen.
extends CanvasLayer

signal reward_taken

const CARD_COUNT := 3

var _root: Control
var _row: HBoxContainer
var _player: Player
var _views: Array = []
var _cursor_free := false
## Timestamp until which clicks are ignored (prevents an attack-click that was
## already held down from hitting a card the instant the overlay appears).
var _click_lock_until_ms := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 5
	# PauseMenu checks this group so Esc never stacks a pause menu on top of an
	# open card choice (both would fight over get_tree().paused).
	add_to_group("level_up_screen")
	_build()
	visible = false

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(centre)
	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", 28)
	centre.add_child(_row)

func open() -> void:
	_player = EffectUtil.player(get_tree()) as Player
	if _player == null:
		return
	# Never open the reward choice after the run has ended.
	if _run_finished():
		return
	get_tree().paused = true
	# Free the mouse so a card can actually be clicked (the FPS look keeps the
	# cursor captured, which made the reward impossible to pick).
	_cursor_free = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for child in _row.get_children():
		child.queue_free()
	_views.clear()
	var pool := UpgradePool.build(_player)
	pool.shuffle()
	var shown := mini(CARD_COUNT, pool.size())
	for i in shown:
		var view := UpgradeCardView.new()
		view.setup(pool[i])
		view.set_slot(i + 1)
		view.chosen.connect(_on_card_chosen)
		_row.add_child(view)
		_views.append(view)
	visible = true
	# Arm the click guard; also swallow the release of the mouse the player was
	# already holding when the overlay appeared (fire-while-advancing case).
	_click_lock_until_ms = Time.get_ticks_msec() + 450

## Keyboard fallback (1/2/3): lets the reward be taken without the mouse.
func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if Time.get_ticks_msec() < _click_lock_until_ms:
		return
	for i in _views.size():
		if event.is_action_pressed(StringName("spell_%d" % (i + 1))):
			var view = _views[i]
			if view != null:
				view._on_pressed()
			# Null-safe: the card may have triggered a scene change that detached
			# this screen, leaving get_viewport() null (see Баг #10).
			var vp := get_viewport()
			if vp != null:
				vp.set_input_as_handled()
			return

func _on_card_chosen(card: UpgradeCard) -> void:
	if card != null and _player != null:
		card.apply(_player)
	visible = false
	get_tree().paused = false
	# Re-capture the cursor for first-person aiming.
	_cursor_free = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	reward_taken.emit()

## True once the run director has stopped (player died or time ran out).
func _run_finished() -> bool:
	for node in get_tree().get_nodes_in_group("game"):
		if node.get("_running") != null and node.get("_running") == false:
			return true
	return false

## True while the reward choice is holding the mouse cursor free (exposed for
## tests; Input.mouse_mode is a no-op in headless runs).
func is_cursor_free() -> bool:
	return _cursor_free
