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

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 5
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
	get_tree().paused = true
	for child in _row.get_children():
		child.queue_free()
	var pool := UpgradePool.build(_player)
	pool.shuffle()
	var shown := mini(CARD_COUNT, pool.size())
	for i in shown:
		var view := UpgradeCardView.new()
		view.setup(pool[i])
		view.chosen.connect(_on_card_chosen)
		_row.add_child(view)
	visible = true

func _on_card_chosen(card: UpgradeCard) -> void:
	if card != null and _player != null:
		card.apply(_player)
	visible = false
	get_tree().paused = false
	reward_taken.emit()
