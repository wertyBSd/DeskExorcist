class_name UpgradeCardView
## The clickable face of a single reward (GDD section 6 "juice").
##
## A Button subclass built entirely in code: it scales and tilts on hover, and
## flies in from below when the level-up screen opens.
extends Button

signal chosen(card: UpgradeCard)

const BASE_SIZE := Vector2(240, 320)

var card: UpgradeCard

func setup(p_card: UpgradeCard) -> void:
	card = p_card
	custom_minimum_size = BASE_SIZE
	text = ""
	flat = true

func _ready() -> void:
	_build_visuals()
	mouse_entered.connect(_on_hover_start)
	mouse_exited.connect(_on_hover_end)
	pressed.connect(_on_pressed)
	pivot_offset = BASE_SIZE * 0.5
	# Fly-in animation: rise from below with a fade and a grow.
	modulate.a = 0.0
	scale = Vector2(0.5, 0.5)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, 0.25)
	tween.tween_property(self, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _build_visuals() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#1c1a26")
	style.border_color = card.accent if card != null else Color("#ffe9a8")
	style.set_border_width_all(3)
	style.set_corner_radius_all(12)
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 14.0
	style.content_margin_bottom = 14.0
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	var title := Label.new()
	title.text = card.title if card != null else ""
	title.add_theme_color_override("font_color", card.accent if card != null else Color.WHITE)
	title.add_theme_font_size_override("font_size", 22)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(title)
	var desc := Label.new()
	desc.text = card.description if card != null else ""
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(desc)

func _on_hover_start() -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1.05, 1.05), 0.12)
	tween.tween_property(self, "rotation_degrees", 3.0, 0.12)

func _on_hover_end() -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2.ONE, 0.12)
	tween.tween_property(self, "rotation_degrees", 0.0, 0.12)

func _on_pressed() -> void:
	chosen.emit(card)
