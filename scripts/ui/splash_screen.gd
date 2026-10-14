class_name SplashScreen
extends Control
## Заставка с логотипом, которая показывается первой при запуске игры.
##
## Схема ровно та же, что в `TheBottomOfEurope`: собственная сцена заставки
## вместо встроенного сплэша движка (`boot_splash/show_image=false` в
## project.godot — иначе сначала мелькает логотип Godot), затем переход в
## главное меню.
##
## Логотип — **общий логотип студии**, тот же файл, что лежит в
## `TheBottomOfEurope/the-bottom-of-europe/assets/textures/ui/company_logo.png`,
## скопированный в `assets/ui/brand/`. Это ассет компании, а не сгенерированный
## арт: `tools/build_ui_art.py` его не трогает, конвенция имён из
## `LEONARDO_PROMPTS.md` на него не распространяется.
##
## У PNG непрозрачное поле `#04040a`, поэтому фон заставки выставлен в тот же
## цвет: при другом фоне вокруг логотипа проступает видимый тёмный квадрат.
## Меняешь логотип — замерь угол (`tools/splash_preview.tscn` печатает его).
##
## Грузится в рантайме через `load()` (как в референсе), а не ExtResource'ом в
## сцене: если Godot ещё не успел сгенерировать `.import`, ссылка в `.tscn`
## молча резолвится в null и заставка остаётся пустой. Фолбэк на иконку
## заклинания — чтобы не остаться с чёрным экраном вовсе.

## Куда уходим после заставки.
const MENU_SCENE := "res://scenes/main_menu.tscn"
## Логотип студии.
const LOGO_PATH := "res://assets/ui/brand/company_logo.png"
## Фолбэк, если файла нет: иконка «Слова Очищения» (золотой крест).
const FALLBACK_SPELL := 1
## Сколько секунд висит логотип, сек.
const HOLD := 2.4
## Длительность проявления и затухания, сек.
const FADE := 0.6

@onready var _mark: TextureRect = %Mark
@onready var _fade: ColorRect = %FadeOverlay

## Защита от повторного перехода: таймер заставки и нажатие игрока могут
## сработать в одном кадре.
var _leaving := false

func _ready() -> void:
	# На заставке курсор не нужен, но он должен быть виден: иначе после смены
	# сцены игрок остаётся с захваченным курсором на чёрном экране.
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_mark.texture = _load_logo()
	# Проявление идёт по чёрному оверлею, а не по логотипу: альфа логотипа
	# иначе проступала бы квадратными границами PNG на затухании.
	_fade.color.a = 1.0
	var intro := create_tween()
	intro.tween_property(_fade, "color:a", 0.0, FADE)
	intro.tween_callback(_await_hold)

## Логотип студии, а если его нет — иконка заклинания, чтобы заставка не
## осталась пустой.
func _load_logo() -> Texture2D:
	if ResourceLoader.exists(LOGO_PATH):
		var tex := load(LOGO_PATH) as Texture2D
		if tex != null:
			return tex
	push_warning("SplashScreen: no company logo at %s, falling back." % LOGO_PATH)
	return ArtLibrary.spell_icon(FALLBACK_SPELL)

func _await_hold() -> void:
	await get_tree().create_timer(HOLD).timeout
	_leave()

## Любая клавиша или кнопка мыши пропускает заставку.
func _unhandled_input(event: InputEvent) -> void:
	var skip := false
	if event is InputEventKey:
		skip = event.pressed and not event.echo
	elif event is InputEventMouseButton:
		skip = event.pressed
	elif event is InputEventJoypadButton:
		skip = event.pressed
	if skip:
		_leave()

## Гасим экран оверлеем и уходим в меню строго после затухания: смена сцены
## внутри tween_callback, иначе кадр очистки вьюпорта проскочил бы мимо.
func _leave() -> void:
	if _leaving:
		return
	_leaving = true
	var out := create_tween()
	out.tween_property(_fade, "color:a", 1.0, FADE)
	out.tween_callback(_to_menu)

func _to_menu() -> void:
	get_tree().change_scene_to_file(MENU_SCENE)