extends Node3D
## Тренировочный зал (GDD Level Design): та же арена, что и Ур.1, но без
## демонов-спавнера и волн — демоны здесь статичные манекены, заклинания
## и болты можно проверить без риска для жизни. Esc — назад в меню.

const RUN_SCENE := "res://scenes/main_menu.tscn"

func _ready() -> void:
	# Арена Ур.1 (игровой LevelBuilder, см. main.tscn).
	var level := LevelBuilder.new()
	level.name = "Level"
	add_child(level)
	level.build(0)
	var player := get_node_or_null("Player") as Player
	if player != null:
		player.global_position = level.player_spawn
	# Статичные «манекены» вместо живой волны: стоят, бьют по ним, но не
	# преследуют и не убивают (speed = 0, контактный урон всё ещё считается,
	# поэтому танку справа разрешено стоять вплотную только для демонстрации).
	for i in 4:
		var dummy := Enemy.new()
		dummy.configure(Enemy.Kind.PAPERWORK_PHANTOM)
		dummy.speed = 0.0
		add_child(dummy)
		var angle := TAU * float(i) / 4.0 + 0.4
		dummy.global_position = level.player_spawn + Vector3(cos(angle), 0.0, sin(angle)) * 5.0
	# Подсказка.
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var label := Label.new()
	label.text = "ТРЕНИРОВКА  ·  ЛКМ — болт  ·  1–0 — заклинания  ·  Esc — в меню"
	label.add_theme_font_size_override("font_size", 20)
	label.position = Vector2(24, 24)
	canvas.add_child(label)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		get_tree().paused = false
		get_tree().change_scene_to_file(RUN_SCENE)
