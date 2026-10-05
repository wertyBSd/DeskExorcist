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

Главная сцена: `res://scenes/main.tscn`.

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

## Модели

`tools/build_models.py` (Blender headless) → `assets/models/*.glb`,
грузятся через `ModelLibrary` (null-safe fallback на процедурные плейсхолдеры).

## Документы

- `GAME DESIGN DOCUMENT.MD` — GDD.
- `Level Design.MD` — уровни.
- `BlenderInstruction.MD` — пайплайн моделей.
- `ROADMAP.md` — план разработки по этапам (P0–P3).
