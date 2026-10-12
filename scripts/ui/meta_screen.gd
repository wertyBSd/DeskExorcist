class_name MetaScreen
## Meta-progression overlay (E4): shows campaign stats and lets the player
## spend cumulative souls on permanent upgrades. Built in code like the rest
## of the UI, null-safe for headless tests.
extends CanvasLayer

var _root: Control

func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	visible = false
	_build()

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	_refresh()

func _refresh() -> void:
	if _root == null:
		return
	for c in _root.get_children():
		c.queue_free()
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.8)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(centre)
	var panel := VBoxContainer.new()
	panel.add_theme_constant_override("separation", 12)
	centre.add_child(panel)

	var title := Label.new()
	title.text = "МЕТА-ПРОГРЕССИЯ"
	title.add_theme_font_size_override("font_size", 36)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(title)

	var stats := Label.new()
	var meta := get_node_or_null("/root/Meta")
	stats.text = "NG+%d  ·  Побед: %d  ·  Души: %d" % [
		int(meta.ng_level) if meta != null else 0,
		int(meta.wins) if meta != null else 0,
		int(meta.total_souls) if meta != null else 0,
	]
	stats.add_theme_font_size_override("font_size", 20)
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats.autowrap_mode = TextServer.AUTOWRAP_WORD
	panel.add_child(stats)

	if meta == null:
		return
	var shop := [
		["hp", "+10 к макс. здоровью (ур. %d/%d)"],
		["dmg", "+5%% к урону (ур. %d/%d)"],
		["speed", "+5%% к скорости (ур. %d/%d)"],
		["spell", "Открыть заклинание"],
	]
	for entry in shop:
		var id: String = entry[0]
		var maxed: bool = meta.upgrade_cost(id) == 0
		var label_text: String = entry[1]
		if id != "spell":
			label_text = label_text % [meta.upgrade_level(id), int(Meta.UPGRADE_MAX[id])]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		panel.add_child(row)
		var info := Label.new()
		info.text = label_text
		info.custom_minimum_size = Vector2(320, 48)
		info.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(info)
		if maxed:
			var done := Label.new()
			done.text = "МАКС"
			done.custom_minimum_size = Vector2(80, 48)
			done.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			row.add_child(done)
		else:
			var cost: int = meta.upgrade_cost(id)
			var b := Button.new()
			b.text = "%d душ" % cost
			b.custom_minimum_size = Vector2(120, 48)
			b.disabled = meta.total_souls < cost
			b.pressed.connect(func() -> void:
				if meta.buy_upgrade(id):
					_refresh())
			row.add_child(b)
	var close := Button.new()
	close.text = "Закрыть"
	close.custom_minimum_size = Vector2(200, 48)
	close.pressed.connect(func() -> void:
		close())
	panel.add_child(close)

func open() -> void:
	if _root == null:
		_build()
	_refresh()
	visible = true

func close() -> void:
	visible = false

func is_open() -> bool:
	return visible
