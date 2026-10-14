# Desk Exorcist

3D arena-shooter vertical slice on **Godot 4.7.2.stable.mono** (GDScript).

## Требования

- **Godot 4.7.2.stable.mono**. На этой машине он установлен в
  `C:\Program Files\Godot\Godot.exe` и **не добавлен в PATH** — используй полный путь.
- Python + Blender (headless) — только для пересборки моделей (`tools/build_models.py`).

## Запуск игры

```
"C:\Program Files\Godot\Godot.exe" --path c:\research\games\Shooter
```

Игра стартует с заставки (`scenes/splash_screen.tscn`, логотип студии + «нажми
любую клавишу»), дальше главное меню; из него — забег (`res://scenes/main.tscn`).
Встроенный сплэш движка выключен (`boot_splash/show_image=false`), иначе перед
нашей заставкой мелькнул бы логотип Godot.

Логотип — `assets/ui/brand/company_logo.png`, копия из
`TheBottomOfEurope/the-bottom-of-europe/assets/textures/ui/`. Это ассет
студии, а не сгенерированный арт: фон заставки выставлен в `#04040a`, в цвет
собственного поля картинки, иначе вокруг логотипа проступает тёмный квадрат.

## Управление

| Действие | Клавиша |
|---|---|
| Ходьба | `WASD` |
| Прыжок | `Space` (на столы и кубики тоже) |
| Стрельба | ЛКМ (автомат, стреляет сам) |
| **Отмена заряда заклинания** | **ПКМ** |
| Заклинания | `1`–`0` (зажать — заряд, отпустить — каст) |
| Пауза | `Esc` |
| Убить демона под прицелом (отладка) | `K` |

Заклинание можно читать **на ходу**: заряд снижает скорость до 45 %, но не
приковывает. Попадание отбрасывает окруживших демонов и прерывает заряд, так
что зажатый в углу игрок получает место, чтобы выбраться.

## Тесты

Сьют гоняется headless; `exit 0` = всё зелёное, `1` = есть падения.

Полная команда:

```
"C:\Program Files\Godot\Godot.exe" --headless --path c:\research\games\Shooter res://tests/tests.tscn
```

Скрипт-обёртка (пишет лог и печатает `EXITCODE`):

```
powershell -NoProfile -ExecutionPolicy Bypass -File tools\run_tests.ps1
```

Параметры `-Godot <path>` и `-Project <path>` позволяют переопределить пути.

## Сборка билда

Экспорт-пресеты в `export_presets.cfg` (Windows + Linux):

1. Открой проект в Godot (`--path c:\research\games\Shooter`).
2. **Project → Export…** → выбери пресет (Windows Desktop / Linux/X11).
3. **Export Project** → получишь `build/DeskExorcist.exe` или `build/DeskExorcist.x86_64`.

## Модели

`tools/build_models.py` (Blender headless) → `assets/models/*.glb`,
грузятся через `ModelLibrary` (null-safe fallback на процедурные плейсхолдеры).

Все 10 моделей собираются, проверяются по бюджету полигонажа и рендерятся в
контактный лист для визуального ревью:

```
"C:\Program Files\Blender Foundation\Blender 5.2\blender.exe" --background --python tools\build_models.py
"C:\Program Files\Blender Foundation\Blender 5.2\blender.exe" --background --python tools\check_models.py
"C:\Program Files\Blender Foundation\Blender 5.2\blender.exe" --background --python tools\preview_models.py
"C:\Program Files\Blender Foundation\Blender 5.2\blender.exe" --background --python tools\preview_viewmodel.py
```

`build/preview.png` — шот всех силуэтов, `build/preview_viewmodel_ingame.png` —
руки заклинателя ровно так, как их видит игрок (папка в git-игноре).

## Комнаты

Арена строится как сетка solid-блоков (так надёжнее для коллизии), а
`RoomDressing` (`scripts/core/room_dressing.gd`) кладёт поверх отделку:
обои с панелью-дадо, окна на внешних стенах, двери с табличками, подвесной
потолок с подсветкой карниза и люстрами. Отделка **не добавляет коллизии** —
окно это картинка, а не дырка в уровне.

Поверхности (`TextureLibrary`) рисуются кодом и бесшовны; настоящая текстура
подхватывается по имени файла `assets/textures/<surface>.png` без правок кода.
Почему для стен не нужны картинки от генератора — в `LEONARDO_PROMPTS.md`.

Ревью комнат глазами (рендер каждой арены с 4 ракурсов + кадр на двери,
результат в `temp/room_*.png`). **Обязательно с окном, не `--headless`** —
иначе у Godot нет устройства рендера и кадры выходят чёрными:

```
"Godot.exe" --path c:\research\games\Shooter --resolution 1280x720 res://tools/room_preview.tscn
```

Аргументом можно указать номер арены: `-- 3`.

Диагностика демонов, застрявших в геометрии (`BUGS.md` #16) — кладёт демона в
каждую solid-клетку арены и печатает те, из которых он не выбрался:

```
"Godot.exe" --headless --path c:\research\games\Shooter res://tools/repro_wedge.tscn -- 3
```

Проходимость арен (`BUGS.md` #19) — реальная капсула игрока обходит арену по
`LevelBuilder.next_path_point` и печатает клетки, на которые ни разу не встала.
`-1` — все арены сразу:

```
"Godot.exe" --headless --path c:\research\games\Shooter res://tools/audit_walk.tscn -- -1
```

Проёмы дверей — что стоит в каждом `+`-проёме (должно быть пусто):

```
"Godot.exe" --headless --path c:\research\games\Shooter res://tools/audit_doorways.tscn -- -1
```

Шот заставки (`temp/splash.png`), чтобы править логотип, не запуская игру:

```
"Godot.exe" --path c:\research\games\Shooter --resolution 1280x720 res://tools/splash_preview.tscn
```

HUD с миникартой на трёх поворотах камеры (`temp/hud_yaw_*.png`) — так видно,
что конус направления взгляда следует за камерой:

```
"Godot.exe" --path c:\research\games\Shooter --resolution 1280x720 res://tools/hud_preview.tscn
```

Тени заклинателя (`BUGS.md` #23, «тень от рук, а от тела нет»). Режим `probe` —
заклинатель один на пустом полу под тем же солнцем, что и в `main.tscn`, так что
на кадрах видно ровно то, что добавляет сам заклинатель; `live` — боевая арена;
`bare` снимает ту же сцену без контактного пятна. С окном, кадры в `temp/`:

```
"Godot.exe" --path c:\research\games\Shooter --resolution 1280x720 res://tools/shadow_preview.tscn -- probe
```

Два кадра отличаются на десятки процентов из-за того, что руки в idle дышат, —
сравнивать «на глаз» бесполезно. `tools/img_diff.py` печатает, где и насколько
изменилось, профиль по строке (мягкий горб = нормальная декаль, плато = ровная
заливка квадратом) и RGB в точках, плюс может вырезать кроп для сравнения:

```
python tools\img_diff.py temp\shadow_probe_novm_top.png temp\shadow_probe_bare_top.png --line 359 --pixels "639,359;592,322"
```

Шар заряда и снаряды (`temp/orb_*.png`) — пять кадров от пустой ладони до полного
заряда попарно с разными заклинаниями (видно, что шар берёт цвет заклинания) и
четыре снаряда в полёте. Рендерит настоящий рендерер игры, а не Blender: и шар,
и снаряд собираются в рантайме, `preview_viewmodel.py` их не покажет. Один слой
можно убрать аргументом, когда непонятно, кто выбивает остальные в белый:

```
"Godot.exe" --path c:\research\games\Shooter --resolution 1280x720 res://tools/orb_preview.tscn -- hide=Glow
```

Эффекты всех десяти заклинаний (`BUGS.md` #24, «не просто круги, а если огонь —
то эффект огня»). Стенд кастует заклинания **настоящим** `spell.cast_effect()` в
пустой арене с манекенами и снимает по два кадра на заклинание — они анимации,
поэтому одного снимка либо не поймает ничего, либо придёт после конца. Кадры в
`temp/vfx_<id>_<n>.png`; `id` — номер заклинания по GDD (0 = Страшный Суд).
Одно заклинание вместо всех: `-- 6`. Заодно вычищает эффекты предыдущего — иначе
остатки волны от Молота попадают в кадр следующего заклинания и тот выглядит так,
будто рисует чужое:

```
"Godot.exe" --path c:\research\games\Shooter --resolution 1280x720 res://tools/spell_vfx_preview.tscn
```

После пересборки `.glb` Godot не всегда переимпортирует модель: если в сцене
остались узлы, которых в файле уже нет, удали кэш
`.godot/imported/<model>.glb-*` и прогони `Godot.exe --headless --path . --import`.

Путь, который начинается с префикса каталога, а не с имени файла, в `save_png`
не создаёт папку, а делает её **каталогом**: `make_dir_recursive_absolute
("res://temp/vfx_")` создаёт `temp/vfx_`, после чего `save_png` возвращает
`ERR_CANT_CREATE`, а все кадры стенда пишутся файлами по нулю байт — и выглядит
это как «рендерер сломался», а не как опечатка в пути.

## 2D-арт

`tools/build_ui_art.py` (Blender headless, там же numpy) пересобирает
`temp/*.jpg` в `assets/ui/`: иконки заклинаний 256×256 RGBA с прозрачным
фоном + фоны меню. JPG из генератора непрозрачные и у каждой иконки свой фон,
поэтому скрипт снимает его заливкой от края и кроет по содержимому.

```
"C:\Program Files\Blender Foundation\Blender 5.2\blender.exe" --background --python tools\build_ui_art.py
```

`temp/ui_icons_sheet.png` и `temp/ui_icons_hud.png` — контрольные листы
(на шахматке и в реальном размере слота 40 px), пересобираются скриптом и
в git-игноре. Промты и конвенция имён — `LEONARDO_PROMPTS.md`.

## Документы

- `GAME DESIGN DOCUMENT.MD` — GDD.
- `Level Design.MD` — уровни.
- `BlenderInstruction.MD` — пайплайн моделей.
- `ROADMAP.md` — план разработки по этапам (P0–P3).
- `GDD_ROADMAP.md` — сверка с GDD по пунктам + план до играбельного состояния.
- `LEONARDO_PROMPTS.md` — промты для 2D-арта + конвенция имён файлов.
- `BUGS.md` — трекер багов (что нашли, что пофикшено, что речекать).
