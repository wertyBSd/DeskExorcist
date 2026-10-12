# Модели для генерации (Blender / 3D AI)

> Дополнение к `BlenderInstruction.MD`. Общие требования к стилю, полигонажу,
> текстурам и иерархии — там же (low-poly, 500–2000 tris, до 512×512 atlas,
> .glb, Root/Head/SpellCast empty, анимации idle/run/cast_hold/cast_release).
>
> Сгенерированные `.glb` складывать в `assets/models/` — путь уже прописан в
> `ModelLibrary` (или добавить константу и использовать её в коде).

## 1. Финальный босс — «Демон-Директор» (`boss_director.glb`) ✅
- Описание: большое демоническое существо, сросшееся с офисной мебелью: борода
  из бумажных папок, галстук-пласт, кресло-трон из офисных кресел, рога из
  скрепок. Глаза — два горящих прожектора-лампы.
- **Сделано:** `build_boss_director()` в `tools/build_models.py`. 712 tris,
  габарит 2.78 × 1.42 × 3.07 м. `boss.gd` больше не подставляет
  `water_cooler.glb` (тест `_test_enemy_models_are_distinct` проверяет, что
  пути разные).
- Осталось: анимации `cast_hold` — расправить руки-лампы (пока общая
  анимация игрока).

## 2. Новые архетипы врагов (E1-лист)

- `enemy_runner.glb` — «Демон-Уборщик» (WIRE_RUNNER) ✅ 188 tris, метла вынесена
  вбок в плоскость обзора, иначе сокращается в невидимую точку.
- `enemy_tank.glb` — «Танк «Жёсткий диск»» (FILING_CABINET_TANK) ✅ 276 tris,
  габарит 1.98 × 1.24 × 1.22 — читается как стена, которую надо обходить.
- `enemy_bomber.glb` — горящий бак- shredder с фитилём (PAPER_BOMBER) ✅ 212 tris.
- `enemy_sniper.glb` — «Бухгалтер-снайпер»: стрелок с укрытием. **Не сделан** —
  в коде отдельного архетипа нет, дальнобойку изображает EMAIL_WRAITH.
- `enemy_flyer.glb` — «Летун-Скорпиончка(mail)». **Не сделан** — в коде
  отдельного архетипа нет.

## 3. Окружение

- `prop_cart.glb` — офисная тележка (Ур.1 укрытие, `Cart`) + `prop_cabinet.glb`
  — шкаф-укрытие для Ур.3 (`LowWall`), `paper_pile.glb` — куча бумаг для тех же
  зон `PaperPile` (вместо плоских плоскостей).
- `chair.glb` — офисное кресло для `Chair` (RigidBody3D), сейчас — из двух
  коробок.
- `desk.glb` / `plant.glb` — уже используются как плоские силуэты; нужны
  цельные модели.

## 4. Переносы существующих

- `survivor.glb` (NPC) ✅ `build_survivor()`, 156 tris, 1.72 м, руки строго
  опущены — `npc.gd` теперь берёт модель вместо силуэта из блоков.

## Формат артефакта

Для каждой модели: 1×`.glb`, embedded textures/vertex colors, root на полу,
метрический масштаб (человек ≈ 1.7 м в высоту), все 4 анимации в одном файле,
если существо двигается.

## Инструменты пайплайна

Все три живут в `tools/` и гоняются headless через Blender 5.2:

| Скрипт | Что делает |
|---|---|
| `build_models.py` | единственный источник правды: строит и экспортирует все 10 `.glb` |
| `check_models.py` | печатает полигонаж, габариты и empties по каждому `.glb`, сверяет с бюджетами `BlenderInstruction.MD` |
| `preview_models.py` | рендерит контактный лист `build/preview.png` (Workbench, studio-свет) — визуальная проверка силуэтов без запуска игры |

```
"C:\Program Files\Blender Foundation\Blender 5.2\blender.exe" --background --python tools\build_models.py
"C:\Program Files\Blender Foundation\Blender 5.2\blender.exe" --background --python tools\check_models.py
"C:\Program Files\Blender Foundation\Blender 5.2\blender.exe" --background --python tools\preview_models.py
```

> `build/preview.png` лежит в git-игноре (`build/`), это артефакт ревью, а не ассет.
