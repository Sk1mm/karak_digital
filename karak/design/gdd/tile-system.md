# TileSystem

> **Status**: Designed (pending /design-review)
> **Author**: game-designer + user
> **Last Updated**: 2026-10-10
> **Implements Pillar**: Pillar 1 — «Каждый тайл — маленькая история»

## Overview

TileSystem — хранилище данных подземелья: определяет все возможные типы тайлов (`TileType`) и хранит состояние каждой клетки сетки (`TileGrid`) на протяжении партии. Это второй данных-узел проекта после PlayerState — от TileSystem зависят DungeonGenerator, EncounterDispatcher и WinCondition.

Система состоит из двух частей. Первая — статические определения: перечисление `TileType` со всеми возможными типами тайлов и `TileData` ресурс, описывающий параметры каждого типа. Вторая — динамическое состояние: `TileGrid` — двумерный массив клеток подземелья, каждая из которых знает свой тип, раскрыта ли она и очищена ли (встреча разрешена).

TileSystem не генерирует подземелье и не разрешает встречи — это задачи DungeonGenerator и EncounterDispatcher. TileSystem только знает «что здесь лежит» и «в каком состоянии».

## Player Fantasy

TileSystem — это невидимая память подземелья. Игрок не думает о TileSystem. Он думает: «что там за поворотом?» — и когда переворачивает тайл, именно TileSystem знает ответ.

Каждая клетка сетки — маленькое обещание: неизвестность становится фактом. Тайл был закрыт — теперь он раскрыт, и это раскрытие необратимо. Паук, которого встретил первый игрок на этом тайле, будет там же, когда второй игрок войдёт снова. Подземелье честное: оно не меняется за спиной. Это Pillar 4 («Честная случайность») на уровне самих данных.

TileSystem обеспечивает Pillar 1 («Каждый тайл — маленькая история») не через визуал — он хранит состояние, которое визуал отражает. `is_revealed`, `is_cleared`, `loose_key` — три бита, но в них весь нарратив тайла: «здесь был бой», «здесь лежит чужой ключ», «здесь был фонтан и мы оба пили из него».

## Detailed Design

### Core Rules

1. Подземелье состоит из **тайлов подземелья** (`DungeonCell`) — клеток сетки, каждая со своей геометрией (форма + поворот → набор выходов) и состоянием (раскрыта/закрыта, очищена/нет).
2. Тайлы делятся на **5 категорий** (`TileCategory`):

| `TileCategory` | Форма | Кол-во | Поведение при посещении |
|---------------|-------|--------|-------------------------|
| `CORRIDOR` | STRAIGHT / L_TURN / T_JUNCTION / CROSS | 20 | Нет события, сразу CLEARED |
| `ROOM` | STRAIGHT / L_TURN / T_JUNCTION / CROSS | 53 | Тянется event-токен при раскрытии |
| `FOUNTAIN` | CROSS | 1 | Стартовый тайл; всегда открыт; полное лечение при посещении |
| `FOUNTAIN_SECONDARY` | L_TURN | 2 | Полное восстановление HP при посещении |
| `PORTAL` | STRAIGHT | 4 | Телепортация к любому из трёх других порталов (игрок выбирает) |

3. **Формы тайлов** задают выходы. Выход = сторона (N/E/S/W), через которую можно войти или выйти:

| Форма | `TileShape` | Выходы (0°) |
|-------|------------|-------------|
| Прямой | `STRAIGHT` | N + S |
| Поворот | `L_TURN` | N + E |
| Т-образный | `T_JUNCTION` | N + E + S |
| Крест | `CROSS` | N + E + S + W |

Поворот тайла на 90°/180°/270° сдвигает выходы по кругу. `exits` вычисляются из `shape + rotation` — не хранятся отдельно.

4. **Event-токены** (`EventToken`) — два типа:

| `EventType` | Кол-во | Описание |
|------------|--------|----------|
| `MONSTER` | 43 | Ссылка на монстра в MonsterDatabase (`content_id`); Дракон — особый монстр с `is_dragon = true` |
| `CHEST` | 10 | Сундук — нужен ключ; содержимое определяет LootSystem |

5. DungeonGenerator **перед стартом** формирует два перемешанных пула: `dungeon_tile_pool` (80 тайлов) и `event_token_pool` (53 токена). TileSystem хранит оба пула. Тайлы **не размещаются заранее** — каждый игрок сам вытягивает и кладёт тайл при движении на неисследованную клетку.
6. **Размещение тайла**: при входе на неразмещённую позицию MovementSystem вызывает `draw_tile()` → игрок выбирает поворот → `place_cell(pos, tile, rotation)`. Обязательное условие: вход со стороны текущего движения должен быть выходом тайла. Остальные выходы — на усмотрение игрока.
7. При раскрытии ROOM EncounterDispatcher вызывает `draw_event_token()` — вытягивает верхний токен из `event_token_pool`. Токен присваивается ячейке (`event_content_id`). При повторном входе на раскрытый неочищенный тайл — токен не перерисовывается.
8. **Стартовый тайл** (`FOUNTAIN`) фиксирован в центре сетки, форма `CROSS` (4 выхода), `rotation = 0`, `is_revealed = true` с начала партии.
9. **Порталы**: все 4 портальных тайла связаны между собой. Войти на портал = получить список раскрытых порталов (кроме текущего) для выбора цели. Перемещение стоит 1 шаг. Если других раскрытых порталов нет — телепортация недоступна.
10. **Вторичный фонтан**: при посещении восстанавливает полный HP. Неограниченное число использований — каждый игрок восстанавливается при каждом посещении.

### Структура DungeonCell

```gdscript
# Данные одной ячейки сетки подземелья (runtime, не Resource)
class_name DungeonCell

var position: Vector2i            # координаты в сетке
var shape: TileShape              # STRAIGHT / L_TURN / T_JUNCTION / CROSS
var rotation: int                 # 0, 90, 180, 270
var category: TileCategory        # CORRIDOR / ROOM / FOUNTAIN
var is_revealed: bool = false
var is_cleared: bool = false      # событие разрешено (бой выигран / сундук открыт)
var event_type: EventType         # MONSTER / CHEST — только для ROOM; null для остальных категорий
var event_content_id: StringName  # ID монстра из MonsterDatabase; &"" для CHEST
var loose_key: bool = false       # ключ лежит на тайле (Скелет-ключник убит, но игрок не подобрал)

func get_exits() -> Array[Direction]:
    # вычисляет N/E/S/W выходы из shape + rotation
```

### Public API (TileSystem)

Публичные методы, доступные другим системам. Все принимают `pos: Vector2i` — координаты ячейки.

```gdscript
# Чтение
func get_cell(pos: Vector2i) -> DungeonCell
func get_exits(pos: Vector2i) -> Array[Direction]
func is_revealed(pos: Vector2i) -> bool         # → get_cell(pos).is_revealed
func is_cleared(pos: Vector2i) -> bool          # → get_cell(pos).is_cleared
func has_loose_key(pos: Vector2i) -> bool       # → get_cell(pos).loose_key

# Мутации — состояние ячейки
func draw_tile() -> TileData                    # вытянуть тайл из dungeon_tile_pool
func place_cell(pos: Vector2i, tile: TileData, rotation: int) -> void
func reveal_cell(pos: Vector2i) -> void         # HIDDEN → REVEALED; испускает cell_revealed
func clear_cell(pos: Vector2i) -> void          # REVEALED → CLEARED

# Мутации — event-токены
func draw_event_token() -> EventToken           # вытянуть из event_token_pool; null если пуст

# Мутации — ключ на полу
func place_loose_key(pos: Vector2i) -> void     # loose_key = true на ячейке
func remove_loose_key(pos: Vector2i) -> void    # loose_key = false на ячейке
```

### States and Transitions

| Состояние | `is_revealed` | `is_cleared` | Условие |
|-----------|--------------|-------------|---------|
| **HIDDEN** | false | false | начальное состояние всех тайлов кроме FOUNTAIN |
| **REVEALED** | true | false | игрок вошёл на тайл; для ROOM → event_token назначен |
| **CLEARED** | true | true | встреча разрешена (бой выигран / сундук открыт / коридор без события) |

- `HIDDEN` → `REVEALED`: TileRevealVFX вызывает `reveal_cell(pos)` после завершения flip-анимации (Resolved B-14 2026-10-10)
- `REVEALED` → `CLEARED`: EncounterDispatcher вызывает `clear_cell(pos)` после разрешения встречи
- Коридоры (`CORRIDOR`): `HIDDEN` → `REVEALED` → `CLEARED` немедленно (нет события)
- FOUNTAIN: стартует в `CLEARED` — никогда не проходит через HIDDEN/REVEALED

### Interactions with Other Systems

| Система | Направление | Что передаётся |
|---------|-------------|----------------|
| DungeonGenerator | → заполняет | `dungeon_tile_pool`, `event_token_pool`; вызывает `place_cell()` для каждой позиции |
| MovementSystem | → читает/вызывает | `get_exits(pos)` для валидации хода; `draw_tile()`, `place_cell()` |
| TileRevealVFX | → вызывает | `reveal_cell(pos)` — после flip-анимации, до `tile_reveal_complete` (Resolved B-14) |
| EncounterDispatcher | → читает/вызывает | `get_cell(pos)` → тип встречи; `draw_event_token()`; `clear_cell(pos)` |
| WinCondition | → читает | `get_cell(pos).event_content_id` — проверяет `is_dragon` у монстра |
| TileRevealVFX | ← подписан на сигнал | `cell_revealed(pos, cell)` |
| LootSystem | → читает/вызывает | `has_loose_key(pos)`, `place_loose_key(pos)`, `remove_loose_key(pos)` |

## Formulas

### Формула 1: Вычисление выходов тайла

```
exits(shape, rotation) = rotate(base_exits[shape], rotation)
```

| `shape` | `base_exits` (rotation=0°) |
|---------|---------------------------|
| `STRAIGHT` | {N, S} |
| `L_TURN` | {N, E} |
| `T_JUNCTION` | {N, E, S} |
| `CROSS` | {N, E, S, W} |

Поворот 90° по часовой: N→E→S→W→N. **Пример:** `L_TURN + 90°` → {E, S}.
`CROSS`: rotation не влияет — всегда {N, E, S, W}.

---

### Формула 2: Совместимость выходов соседних тайлов

```
compatible(cell_a, cell_b) =
    direction(a → b) ∈ exits(cell_a)
    AND
    opposite(direction(a → b)) ∈ exits(cell_b)
```

Используется DungeonGenerator при укладке. Оба тайла должны иметь выход навстречу друг другу.

---

### Формула 3: Состав пулов

**Пул тайлов подземелья (80 шт):**

| Категория | Форма | Кол-во |
|-----------|-------|--------|
| `CORRIDOR` | L_TURN | 4 |
| `CORRIDOR` | STRAIGHT | 4 |
| `CORRIDOR` | CROSS | 7 |
| `CORRIDOR` | T_JUNCTION | 5 |
| `ROOM` | L_TURN | 13 |
| `ROOM` | STRAIGHT | 13 |
| `ROOM` | CROSS | 14 |
| `ROOM` | T_JUNCTION | 13 |
| `PORTAL` | STRAIGHT | 4 |
| `FOUNTAIN_SECONDARY` | L_TURN | 2 |
| `FOUNTAIN` | CROSS | 1 |
| **Итого** | | **80** |

**Пул event-токенов (53 шт):**

| Токен | `EventType` | Кол-во | Примечание |
|-------|------------|--------|------------|
| Крыса | MONSTER | 8 | — |
| Паук | MONSTER | 4 | — |
| Мумия | MONSTER | 8 | — |
| Скелет-ключник | MONSTER | 12 | дропает ключ при победе |
| Скелет-воин | MONSTER | 5 | — |
| Король скелетов | MONSTER | 3 | — |
| Призрак | MONSTER | 2 | — |
| Дракон | MONSTER | 1 | `is_dragon = true` |
| Сундук | CHEST | 10 | — |
| **Итого** | | **53** | 43 монстра + 10 сундуков |

## Edge Cases

### Пулы и размещение

- **EC-01** — ЕСЛИ `event_token_pool` исчерпан, а игрок вошёл в ROOM: `draw_event_token()` возвращает null. Ячейка помечается CLEARED без события. Не ошибка.
- **EC-02** — ЕСЛИ `dungeon_tile_pool` исчерпан, а игрок хочет выйти на неразмещённую позицию: MovementSystem блокирует движение в эту сторону — тайл взять неоткуда. Детали — в GDD MovementSystem.

### Порталы

- **EC-03** — ЕСЛИ игрок входит на PORTAL, а остальные 3 портала не раскрыты: телепортация недоступна — нельзя переместиться на нераскрытый/неразмещённый тайл. Игрок остаётся на портале, движение продолжается штатно.
- **EC-04** — ЕСЛИ из 3 остальных порталов раскрыт только 1: игрок обязан телепортироваться на него (нет выбора, вариант один).
- **EC-05** — ЕСЛИ два игрока стоят на одном портале одновременно: оба присутствуют — тайлы не блокируются по игрокам.

### Фонтаны

- **EC-06** — ЕСЛИ игрок встаёт на FOUNTAIN или FOUNTAIN_SECONDARY: EncounterDispatcher предлагает выбор. **Если игрок выбирает «да»:** лечение до max_hp + `burn_steps()` (все оставшиеся шаги сгорают). **Если «нет»:** ничего не происходит, ход продолжается. Тактическое решение — потратить ход на лечение или нет.
- **EC-07** — ЕСЛИ игрок с полным HP встаёт на фонтан и выбирает «да»: HP остаётся max_hp, шаги сгорают. Если выбирает «нет» — ход продолжается без эффекта.
- **EC-08** — ЕСЛИ нокаутированный Воин телепортируется на FOUNTAIN: KnockoutSystem применяет `knockout_full_heal` + `knockout_no_turn_skip`. Применяется ли штраф сгорания шагов от фонтана к нокаутному ходу Воина — provisional, уточнить при проектировании KnockoutSystem.

### Выходы и совместимость

- **EC-09** — ЕСЛИ игрок вытянул тайл, который можно повернуть для стыковки с входящей стороной: игрок выбирает поворот. Стыковка обязательна только со стороны входа — остальные выходы тайла могут смотреть куда угодно.
- **EC-10** — ЕСЛИ Волшебник проходит сквозь стену (сторона без выхода): MovementSystem разрешает. `get_exits()` возвращает стандартный набор — TileSystem не знает о классах.

### Состояния ячеек

- **EC-11** — ЕСЛИ `reveal_cell()` вызван на уже раскрытой ячейке: no-op, сигнал не испускается повторно.
- **EC-12** — ЕСЛИ `clear_cell()` вызван на CORRIDOR: корректно — коридор переходит в CLEARED сразу без event-токена.
- **EC-13** — ЕСЛИ `clear_cell()` вызван на HIDDEN ячейке: `push_error` — нельзя очистить нераскрытую ячейку.

## Dependencies

### Зависимости входящие (TileSystem зависит от)

Нет. TileSystem — Foundation layer, нет зависимостей.

### Зависимости исходящие (зависят от TileSystem)

| Система | Что берёт из TileSystem | Статус |
|---------|--------------------------|--------|
| **DungeonGenerator** | Инициализирует пулы (`dungeon_tile_pool`, `event_token_pool`); определяет правила совместимости выходов | Спроектирован ✓ |
| **MovementSystem** | `get_exits(pos)`, `draw_tile()`, `place_cell()` — движение по сетке (`reveal_cell()` перенесён в TileRevealVFX, Resolved B-14) | Спроектирована ✓ |
| **TileRevealVFX** | `reveal_cell(pos)` — вызывает после flip-анимации; подписан на `cell_revealed(pos, cell)` | Спроектирована ✓ |
| **EncounterDispatcher** | `get_cell(pos)` → категория и event-тип; `draw_event_token()`; `clear_cell(pos)` | Спроектирован ✓ |
| **LootSystem** | `has_loose_key(pos)`, `place_loose_key(pos)`, `remove_loose_key(pos)` — управление ключом на полу | Спроектирована ✓ |

### Важное уточнение для downstream

**Для MovementSystem**: при движении на неразмещённую клетку — игрок вытягивает тайл и выбирает поворот. Единственное ограничение при повороте: сторона входа должна быть выходом тайла. MovementSystem управляет процессом; TileSystem только хранит результат через `place_cell()`.

**Для EncounterDispatcher**: фонтанные тайлы (`FOUNTAIN`, `FOUNTAIN_SECONDARY`) обрабатываются особо — лечение и сгорание оставшихся шагов. Портальные тайлы — телепортация к другому раскрытому порталу.

## Tuning Knobs

### TK-01: Состав пула тайлов

| Параметр | Значение | Безопасный диапазон | Влияние |
|----------|----------|---------------------|---------|
| `CORRIDOR_COUNT` | 20 | 15–25 | Больше коридоров → более длинные маршруты, меньше событий на маршрут |
| `ROOM_COUNT` | 53 | 45–60 | Определяет общее количество событий в партии |
| `PORTAL_COUNT` | 4 | 4 | Не менять — портальная механика проектируется под 4 |
| `FOUNTAIN_SECONDARY_COUNT` | 2 | 1–3 | Больше → более лёгкое восстановление HP |

### TK-02: Состав пула event-токенов

| Параметр | Значение | Безопасный диапазон | Влияние |
|----------|----------|---------------------|---------|
| `CHEST_COUNT` | 10 | 8–15 | Прямо влияет на количество ОЧ от сундуков (10 ОЧ максимум) |
| `GHOST_COUNT` | 2 | 2 | Не менять — количество зафиксировано как источник ОЧ |
| `MONSTER_COUNT` | 43 | 38–48 | Частота боёв; Дракон и Призраки всегда входят в пул |
| `MONSTER_TO_CHEST_RATIO` | 43:10 (~4.3:1) | 3:1–6:1 | Баланс между боевыми ОЧ и сундучными |

### TK-03: Победные очки

| Параметр | Значение | Безопасный диапазон | Влияние |
|----------|----------|---------------------|---------|
| `CHEST_VP` | 1 | 1 (фиксировано) | Ценность каждого сундука |
| `GHOST_VP` | 1 | 0.5–2 | ОЧ за убийство каждого Призрака; 2 призрака = 2 ОЧ максимум |
| `DRAGON_VP` | 1.5 | 1.1–2.0 | Нецелое значение — служит разрешением ничьи |

> **Заметка**: Значение ОЧ за монстров хранится в MonsterDatabase (`vp_on_kill`). TileSystem передаёт `event_content_id` — EncounterDispatcher запрашивает ОЧ из MonsterDatabase при победе.

### TK-04: Поведение фонтанов

| Параметр | Значение | Безопасный диапазон | Влияние |
|----------|----------|---------------------|---------|
| `FOUNTAIN_HEAL_AMOUNT` | max_hp (полное) | — | Всегда полное восстановление |
| `FOUNTAIN_STEP_BURN` | все оставшиеся шаги | — | Тактический cost; принцип не менять |

## Visual/Audio Requirements

[To be designed]

## UI Requirements

[To be designed]

## Acceptance Criteria

### AC-01 — Пулы инициализируются корректно
- **Given** DungeonGenerator вызвал `init_pools()`
- **Then** `dungeon_tile_pool.size() == 80` AND `event_token_pool.size() == 53`
- **And** FOUNTAIN тайл присутствует ровно 1 раз; PORTAL — ровно 4

### AC-02 — Стартовый тайл размещён и раскрыт
- **Given** партия началась
- **Then** ячейка в `Vector2i(0, 0)` имеет `category == FOUNTAIN`, `shape == CROSS`, `rotation == 0`, `is_revealed == true`, `is_cleared == true`

### AC-03 — Вычисление выходов: L_TURN + 90°
- **Given** `DungeonCell` с `shape = L_TURN`, `rotation = 90`
- **Then** `get_exits()` возвращает `[Direction.E, Direction.S]`

### AC-04 — Вычисление выходов: CROSS любой поворот
- **Given** `DungeonCell` с `shape = CROSS`, `rotation = 180`
- **Then** `get_exits()` возвращает `[N, E, S, W]` (порядок не важен)

### AC-05 — `place_cell()` корректно сохраняет ячейку
- **Given** вызов `place_cell(Vector2i(1, 0), ROOM, STRAIGHT, 0)`
- **Then** `get_cell(Vector2i(1, 0)).category == ROOM` AND `is_revealed == false`

### AC-06 — `reveal_cell()`: ROOM помечается как раскрытая (без event-токена)
- **Given** ячейка с `category == ROOM`, `is_revealed == false`
- **When** `reveal_cell(pos)` вызван (TileRevealVFX после flip-анимации)
- **Then** `is_revealed == true` AND `event_token_pool.size()` **не изменился**
- **Note** event-токен (`event_content_id`) присваивается EncounterDispatcher через отдельный вызов `draw_event_token()` (Rule 7; EncounterDispatcher Rule 4) — не внутри `reveal_cell()`

### AC-07 — `reveal_cell()`: CORRIDOR сразу CLEARED
- **Given** ячейка с `category == CORRIDOR`
- **When** `reveal_cell(pos)` вызван
- **Then** `is_revealed == true` AND `is_cleared == true`

### AC-08 — `reveal_cell()` на уже раскрытой ячейке: no-op
- **Given** `is_revealed == true`
- **When** `reveal_cell(pos)` вызван повторно
- **Then** состояние не изменилось; сигнал `cell_revealed` не испущен повторно

### AC-09 — `clear_cell()` на HIDDEN ячейке: push_error
- **Given** `is_revealed == false`
- **When** `clear_cell(pos)` вызван
- **Then** `push_error` вызван; `is_cleared` остаётся `false`

### AC-10 — `draw_event_token()` при пустом пуле: null
- **Given** `event_token_pool` пуст
- **When** `draw_event_token()` вызван
- **Then** возвращает `null`; ячейка помечается `is_cleared = true` без события

### AC-11 — Совместимость выходов соседних ячеек
- **Given** cell_a (STRAIGHT, 0°) в (0,0) и cell_b (STRAIGHT, 0°) в (0,1)
- **Then** `compatible(cell_a, cell_b)` == true (A имеет выход S, B имеет выход N)

### AC-12 — Пул тайлов перемешан
- **Given** `init_pools()` вызван дважды подряд
- **Then** порядок `dungeon_tile_pool` отличается с вероятностью > 99% (статистический тест на 100 запусков)

### AC-13 — `place_loose_key` / `has_loose_key` / `remove_loose_key`
- **Given** ячейка (pos) с `loose_key == false`
- **When** `place_loose_key(pos)` вызван
- **Then** `has_loose_key(pos) == true`
- **When** `remove_loose_key(pos)` вызван
- **Then** `has_loose_key(pos) == false`

### AC-14 — `is_revealed` отражает состояние ячейки
- **Given** ячейка (pos) с `is_revealed == false`
- **When** `reveal_cell(pos)` вызван
- **Then** `is_revealed(pos) == true`

### AC-15 — `place_loose_key` на очищенном тайле (no-op для состояния ячейки)
- **Given** ячейка (pos) с `is_cleared == true`
- **When** `place_loose_key(pos)` вызван
- **Then** `has_loose_key(pos) == true`; `is_cleared` не изменился (loose_key независимо от состояния тайла)

## Open Questions

### OQ-01 — Победные очки: нужен ли флаг в DungeonCell или EventToken?

Текущая архитектура: `event_content_id` ссылается на MonsterDatabase, где хранится `vp_on_kill`. TileSystem не знает о ОЧ.

**Вопрос**: достаточно ли хранить `vp_on_kill` в MonsterDatabase, или EventToken в DungeonCell должен нести поле `vp_on_kill` напрямую для быстрого доступа без запроса к MonsterDatabase?

**Provisional**: ОЧ хранятся только в MonsterDatabase. Решить при проектировании MonsterDatabase.

---

### OQ-02 — Обновить game-concept.md: победное условие

`design/gdd/game-concept.md` содержал неверное победное условие («убить Дракона первым»).

**Статус**: RESOLVED 2026-10-10 (B-01). game-concept.md Core Mechanics #5, Elevator Pitch и Session-Level Loop обновлены: убийство Дракона завершает партию; победитель — игрок с наибольшим VP (сундуки=1, Призрак=1, Дракон=1.5). Tiebreak — убийца Дракона.

---

### OQ-03 — Могут ли другие монстры давать ОЧ?

~~**RESOLVED** (2026-10-10 — B-11)~~: Только Призрак (1 VP) и Дракон (1.5 VP). Все остальные монстры дают 0 VP. Монстры являются источником снаряжения (оружие, свитки, ключ), а не VP-прогресса. Это соответствует оригинальному Karak и сохраняет чёткое разделение: VP из сундуков и элитных монстров; силу — из обычных монстров. MonsterDatabase AC-06 подтверждает: vp_on_kill > 0 только у Ghost (1.0) и Dragon (1.5).

---

### OQ-04 — Механика сундука: только ОЧ или ещё и лут?

Текущая позиция: CHEST = 1 ОЧ. Нужен ли для открытия ключ? Даёт ли сундук помимо ОЧ ещё и предмет?

**Provisional**: сундук требует ключа; ОЧ засчитывается при открытии; содержимое определяет LootSystem. Уточнить при проектировании LootSystem.

---

### OQ-05 — Нокаут на фонтане (EC-08)

При телепортации нокаутированного Воина на FOUNTAIN — применяется ли штраф сгорания шагов к нокаутному ходу?

**Provisional**: уточнить при проектировании KnockoutSystem.
