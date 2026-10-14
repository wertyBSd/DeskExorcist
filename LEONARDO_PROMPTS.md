# Промты для Leonardo.ai + конвенция имён файлов

> Все промты на английском, с соотношением сторон. Для иконок заклинаний —
> прозрачный фон, квадрат. Для обложек — 16:9.
>
> **Про поверхности комнат (обои/пол/потолок) промтов здесь нет и быть не
> должно** — им нужны бесшовные тайлы, а не кадры. См. §Поверхности комнат.
>
> **Статус: комплект собран.** Исходники лежат в `temp/*.jpg` — так их отдаёт
> генератор (JPG, без альфы). В игру идут пересобранные версии в `assets/ui/`:
> те же имена, `.png`, 256×256 с прозрачным фоном. Сборка —
> `tools/build_ui_art.py`, см. §Как это собрано. `PlaceholderArt` остался
> фолбэком: если файл удалить, слот снова рисуется кодом и игра не падает.

## Конвенция имён

Единственное правило, которое делает картинки пригодными для игры: **имя файла
обязано совпадать с тем, что уже есть в коде.** Тогда движок находит ассет по
имени, без ручных списков и таблиц соответствия.

### Куда класть

```
assets/ui/icons/spell_<цифра>.png        иконки заклинаний (в игру)
assets/ui/backgrounds/menu.png           фон главного меню (в игру)
assets/ui/brand/company_logo.png         логотип студии (в игру)
assets/ui/reference/*.png                референсы для 3D-генерации (в игру НЕ идут)
```

> `brand/` — единственная папка, куда кладётся **не сгенерированное**: логотип
> CYBER THAI CAT копируется из `TheBottomOfEurope/the-bottom-of-europe/assets/textures/ui/`
> и используется заставкой (`scenes/splash_screen.tscn`). Конвенция имён и
> `tools/build_ui_art.py` его не касаются.

### Как называть

1. **lower_snake_case**, только ASCII. Без пробелов, кириллицы и пр capitals.
2. **Цифра в имени — это цифра на клавише**, которую игрок видит на капс-локе.
   Не индекс в массиве и не `spell_id`: слот 0 в коде это клавиша «1».
3. Один файл — один ассет. Без `-v2`, `-final`, `-FINAL2`.
4. Расширение `.png` (прозрачность), не `.jpg`.

> ⚠️ Главная ловушка: `spell_1.png` — это **первое** заклинание (клавиша «1»),
> а не «нулевой слот». Массив в `SpellLibrary.build_all()` нумеруется с 0,
> слот в HUD тоже с 0, но и клавиши, и `spell_id` считаются от 1. Сверяйся
> с таблицей ниже, а не с порядком в коде.

### Разрешение

| Ассет | Размер | Формат |
|---|---|---|
| `icons/spell_*.png` | 256×256 | RGBA, **прозрачный фон** |
| `backgrounds/menu.png` | 1344×768 (16:9, как отдал генератор) | RGB |
| `reference/*.png` | 1024×1024 | RGB |

Иконка рисуется в слоте 40×40 px с `STRETCH_KEEP_ASPECT_CENTERED` — держи
знак по центру с полями примерно 10%, иначе при уменьшении он срежется.
256→40 это минификация в 6 раз, поэтому у иконок включены мипмапы
(`mipmaps/generate=true` в `.import`), а в `hud.gd` у `TextureRect` стоит
`TEXTURE_FILTER_LINEAR_WITH_MIPMAPS`: проект рисует 2D в nearest, и на
иконках это превращается в рябь.

### Как это собрано

```
blender.exe --background --python tools/build_ui_art.py
```

Скрипт берёт `temp/*.jpg` и кладёт готовые `.png` в `assets/ui/`. Промежуточный
JPG→PNG нельзя сделать переименованием: генератор отдаёт непрозрачные квадраты
(у одной иконки фон белый, у другой тёмно-синий, у третьей — плитка «иконки
приложения», у четвёртой — целая каменная сцена), и такой квадрат в слоте HUD
виден как цветное пятно. Скрипт:

1. **Снимает фон заливкой от края** (`flood fill`), а не цветовым ключом: у
   этих иконок «фон» — это «то, что связано с краем кадра». Два ограничителя
   не дают заливке сорваться: локальный допуск по шагу (градиенты и тени
   остаются фоном) и глобальный порог `cap` (плавный переход не съедает
   весь кадр).
2. **Дочищает маску**: заливает «карманы» фона, отрезанные самим предметом
   (цепи кадила), убирает волосяные остатки тени морфиологическим открытием и
   сглаживает ступеньки, оставшиеся от маски низкого разрешения.
3. **Кроет по содержимому** с полями 8% и ресайзит в 256×256. Ресайз идёт по
   premultiplied alpha, иначе прозрачные пиксели обводят знак тёмным ореолом.
4. Пишет два контрольных листа в `temp/`: `ui_icons_sheet.png` (на шахматке —
   видно остатки фона) и `ui_icons_hud.png` (в реальном размере слота 40 px).

Пороги заданы на иконку в словаре `ICONS`: у каждой свой подводный камень
(у `spell_0` тень на 85 единиц отличается от фона, у `spell_8` свечение
отличается от персикового фона меньше чем сам след, поэтому там нужен ещё и
сброс по яркости). Комментарии в коде объясняют каждый.

### Как это загружается

`ArtLibrary` (`scripts/core/art_library.gd`) — null-safe, по образцу
`ModelLibrary`: если файла нет, возвращается процедурный плейсхолдер, игра
не падает. Поэтому **можно сгенерировать не всё сразу** — недостающие иконки
просто останутся нарисованными кодом.

---

## Поверхности комнат: обои, пол, потолок

> Коротко на главный вопрос «надо ли генерировать картинки стен, пола и
> потолка?». **Не в таком виде.** Стена — это не картинка, а **бесшовная
> (seamless) текстура материала**, один тайл на поверхность. Генератор картинок
> отдаёт кадр с точкой съёмки, предметами и светом внутри: такой тайл не
> стыкуется с соседним (видна сетка повторов через всю арену 56×40 м), и его
> нельзя натянуть на стену. Нужны: обои, панель-дадо, дерево trim'а, ковролин,
> плитка потолка — по одной текстуре на поверхность, плюс PBR-карты, если
> когда-нибудь понадобится.

### Что уже сделано кодом

`TextureLibrary` (`scripts/core/texture_library.gd`) рисует все поверхности
процедурно и кладёт их трипланарно с фиксированным мировым масштабом, так что
одна и та же текстура не «растягивается» по блоку стены 4 м и не превращается в
одну гигантскую картинку на полу. Пока нет файлов — игра работает.

### Куда класть настоящие текстуры

```
assets/textures/<surface>.png
```

Имя файла — **весь контракт**, как в `ArtLibrary`: файл с правильным именем
подхватывается без единой строчки кода, удалённый файл возвращает
процедурную версию, и игра не падает. Список имён — `TextureLibrary.SURFACES`:

| Файл | Что это | Тайл |
|---|---|---|
| `wallpaper.png` | обои верхней части стены | 2 м |
| `wainscot.png` | панель-дадо под обоями | 2 м |
| `wood.png` | плинтус, штапики, рамы, двери | 2 м |
| `carpet.png` | ковролин | 2 м |
| `ceiling.png` | подвесной потолок | 2.5 м |
| `sky.png` | то, что видно в окно | 1 тайл на окно |
| `canvas.png` | картина в раме | 1 картина |
| `glow.png` | градиент света (декали, не поверхность) | — |

Требования к файлу: **бесшовный** тайл, плоское освещение, без перспективы и
без предметов в кадре, 512×512 (1024 для пола, если хватит). Если придёт PBR —
`albedo/normal/roughness` одним префиксом не примутся, для этого допишется
отдельная конвенция.

### Чем генерировать, если захочется не кодом

Leonardo для бесшовных тайлов не годится (сюжет в кадре + швы). Подходят
тайловые текстуры с Poly Haven (у Blender-MCP есть библиотека `polyhaven`,
сейчас выключена) — это честные PBR-тайлы. Поэтому промты для них в этом файле
не пишутся, а слот в `assets/textures/` уже готов.

---

## Иконки заклинаний — полная таблица

Порядок и цифра в имени выведены из `InputSetup.spell_id_for_slot()` и
`SpellLibrary`. Это единственный источник правды.

| Файл | Клавиша | Слот | `spell_id` | Заклинание | Prompt (1:1, прозрачный) |
|---|---|---|---|---|---|
| `spell_1.png` | 1 | 0 | 1 | Слово Очищения | glowing golden cross projectile icon, flat vector style, game UI icon, no background |
| `spell_2.png` | 2 | 1 | 2 | Святая Земля | golden rune circle on stone floor icon, flat game UI icon |
| `spell_3.png` | 3 | 2 | 3 | Изгнание Гордыни | purple boot kicking a golden crown icon, flat game UI icon |
| `spell_4.png` | 4 | 3 | 4 | Гнев Небес | golden lightning beam slashing down icon, flat game UI icon |
| `spell_5.png` | 5 | 4 | 5 | Небесный Молот | giant golden hammer descending icon, flat game UI icon |
| `spell_6.png` | 6 | 5 | 6 | Цепная Молния | cyan chained lightning arcs icon, flat game UI icon |
| `spell_7.png` | 7 | 6 | 7 | Кадило Возмездия | swinging golden thurible censer on chains icon, flat game UI icon |
| `spell_8.png` | 8 | 7 | 8 | Святой Шаг | golden glowing footprint dash icon, flat game UI icon |
| `spell_9.png` | 9 | 8 | 9 | Зеркало Души | golden ornate shield mirror icon, flat game UI icon |
| `spell_0.png` | 0 | 9 | 0 | Страшный Суд | red divine hammer striking down icon, flat game UI icon |

Общий суффикс для всех: `, flat vector icon, thick clean outline, centered,
high contrast on transparent background, no text, no background`

---

## Фон главного меню

| Файл | Соотношение | Prompt |
|---|---|---|
| `backgrounds/menu.png` | 16:9 | low-poly gothic office horror hero background, dark office floor, glowing violet portal in the back, tired exorcist silhouette with a holy symbol, purple and gold palette, flat shading, no text |

Тёмная часть кадра должна быть сверху-слева (там логотип), светлая — снизу
(там меню), иначе текст не прочитается. `main_menu.gd` поверх фона кладёт
затемняющий `ColorRect` с alpha 0.45 — это ослабляет контраст, рисуй с запасом.

## Фон тренировочного зала (опционально)

| Файл | Соотношение | Prompt |
|---|---|---|
| `backgrounds/training.png` | 16:9 | low-poly empty office training hall, polished dark floor, wide empty space, dim ceiling lights, flat shading, no characters, no text |

Файл лежит в `assets/ui/backgrounds/`, но **пока ничего его не грузит**:
тренировочный зал — это 3D-сцена (`scenes/training.tscn`), а не 2D-фон.
Пригодится, если появится экран загрузки или заставка перед входом в зал.

---

## Референсы для 3D-генерации (в игру не идут)

Нужны как вход для `tools/build_models.py` и для внешних 3D-генераторов.
Сейчас модели собраны кодом (`build_*.py`), поэтому файлы ниже — опциональны;
их роль — зафиксировать художественное направление.

### Демоны

| Файл | Prompt |
|---|---|
| `reference/enemy_water_cooler.png` | low-poly stylized possessed office water cooler, glowing purple liquid bottle, sharp teeth mouth on the plastic body, three thin demonic legs, flat shading, cute but creepy |
| `reference/enemy_paperwork_phantom.png` | low-poly ghost made of swirling office paper sheets and documents, floating paperclips, stylized bat-like silhouette, flat shading |
| `reference/enemy_email_wraith.png` | low-poly blue courier ghost, hooded, holding a sealed letter, glowing cyan paperclips orbiting, flat shading |
| `reference/enemy_runner.png` | low-poly small round demonic orb on two thin legs holding a huge broom sideways, rust red shell, glowing amber eye slit, fast and lean, flat shading |
| `reference/enemy_tank.png` | low-poly toppled black server chassis monster on tank treads, wide and low, glowing red eye slot, drive bays on the front, flat shading |
| `reference/enemy_bomber.png` | low-poly wheeled office shredder bin overflowing with burning documents, orange fire glow and a lit fuse on top, flat shading |
| `reference/boss_director.png` | low-poly gothic demon director office monster, beard of colourful paper folders, melted tie, throne fused from office chairs, paperclip horns, two burning lamp-eyes, dark purple and gold, flat shading |
| `reference/survivor.png` | low-poly stylized office survivor standing, white shirt and grey vest, arms down at the sides, scared expression, flat shading, game asset |
| `reference/copier_portal.png` | low-poly possessed office photocopier, glowing violet light beam from the lid, glowing runes on the metal body, flat shading |

### Скриншоты арен (для лендинга, не ассет)

| Файл | Соотношение | Prompt |
|---|---|---|
| `backgrounds/arena_overview.png` | 16:9 | low-poly office arena top-down, multiple desks and cabinets, violet portal beam, dark gothic lighting, flat shading |

Тоже не подключён к коду — это иллюстрация для лендинга/STORE-страницы.
Лежит рядом с игровыми фонами по чистоте пути (`build_ui_art.py` кладёт
всё, что не иконка, в `backgrounds/`).