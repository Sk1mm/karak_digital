# MonsterDatabase

> **Status**: Designed
> **Author**: game-designer + user
> **Last Updated**: 2026-10-10 (retrofitted G-02, G-07)
> **Implements Pillar**: Pillar 2 — «Сила ощутима»

## Overview

MonsterDatabase — статическое хранилище данных всех монстров игры. Определяет для каждого монстра: уникальный идентификатор (`id: StringName`), имя, сложность (`difficulty: int`) для сравнения с броском CombatSystem, флаг `is_dragon` для WinCondition, флаг `drops_key` для LootSystem и `vp_on_kill: float` для счётчика победных очков. База данных неизменяема в ходе партии — только читается. TileSystem ссылается на монстров по `id` через `event_content_id`; CombatSystem читает `difficulty` для разрешения боя; WinCondition проверяет `is_dragon` для определения конца игры.

## Player Fantasy

MonsterDatabase — чистый data layer. Игрок не взаимодействует с базой данных напрямую: он видит монстра на тайле, бросает кубик и сравнивает результат со сложностью. Эмоция «трудный монстр» или «страшный дракон» создаётся CombatSystem и CombatUI; MonsterDatabase только хранит числа, которые это обеспечивают.

## Detailed Design

### Core Rules

1. MonsterDatabase хранит набор записей `MonsterData` — по одной на каждый тип монстра. База данных неизменяема в ходе партии.
2. Каждая запись `MonsterData` содержит:

```gdscript
class_name MonsterData
extends Resource

@export var id: StringName          # уникальный ключ — используется как event_content_id в DungeonCell
@export var display_name: String    # имя для UI
@export var difficulty: int         # порог броска: attack_total > difficulty → победа (строгое «больше»; ничья = поражение без урона)
@export var is_dragon: bool = false # WinCondition читает это поле
@export var drops_key: bool = false # LootSystem читает это поле (Скелет-ключник)
@export var vp_on_kill: float = 0.0 # победные очки за убийство (Призрак = 1, Дракон = 1.5)
```

3. **Таблица монстров:**

| `id` | `display_name` | `difficulty` | `is_dragon` | `drops_key` | `vp_on_kill` |
|------|----------------|-------------|-------------|-------------|--------------|
| `&"rat"` | Крыса | 5 | false | false | 0 |
| `&"spider"` | Паук | 6 | false | false | 0 |
| `&"mummy"` | Мумия | 7 | false | false | 0 |
| `&"skeleton_key"` | Скелет-ключник | 8 | false | true | 0 |
| `&"skeleton_warrior"` | Скелет-воин | 9 | false | false | 0 |
| `&"skeleton_king"` | Король скелетов | 10 | false | false | 0 |
| `&"ghost"` | Призрак | 12 | false | false | 1.0 |
| `&"dragon"` | Дракон | 15 | true | false | 1.5 |

4. `difficulty = 15` у Дракона превышает максимум `roll(2, 6) = 12`. Победить Дракона без снаряжения физически невозможно. Минимальный необходимый `combat_bonus = 4` (условие победы строгое: `attack_total > difficulty`; при bonus=3: 12+3=15, 15>15=false — ничья, не победа; при bonus=4: 12+4=16>15=true).
5. `get_monster(id: StringName) -> MonsterData` — единственная публичная операция. Возвращает запись по `id`; возвращает `null` если `id` не найден.

### States and Transitions

MonsterDatabase не имеет состояний. Все данные статичны и загружаются один раз при старте.

### Interactions with Other Systems

| Система | Направление | Что передаётся |
|---------|-------------|----------------|
| TileSystem | → читает | `event_content_id` из DungeonCell → `get_monster(id)` для получения записи |
| CombatSystem | → читает | `get_monster(id).difficulty` для сравнения с `attack_total` |
| WinCondition | → читает | `get_monster(id).is_dragon` — проверка конца игры |
| LootSystem | → читает | `get_monster(id).drops_key` — дроп ключа при победе |
| EncounterDispatcher | → читает | `get_monster(id)` — определяет тип встречи |

## Formulas

### Формула 1: Условие победы в бою

```
player_wins = attack_total > difficulty
```

**Переменные:**

| Переменная | Тип | Диапазон | Описание |
|------------|-----|----------|----------|
| `attack_total` | int | 2–(12+N) | Сумма `roll(2,6)` + `combat_bonus` от снаряжения |
| `difficulty` | int | 5–15 | Порог монстра из MonsterDatabase |
| `player_wins` | bool | — | true если `attack_total > difficulty` (строгое «больше»; ничья = поражение без урона) |

**Диапазоны по монстрам (без снаряжения, combat_bonus = 0):**

| Монстр | difficulty | P(win) без бонуса | Минимальный бонус для гарантии |
|--------|-----------|-------------------|-------------------------------|
| Крыса | 5 | 83% | — |
| Паук | 6 | 72% | — |
| Мумия | 7 | 58% | — |
| Скелет-ключник | 8 | 42% | — |
| Скелет-воин | 9 | 28% | — |
| Король скелетов | 10 | 17% | — |
| Призрак | 12 | 3% | — |
| Дракон | 15 | **0%** | **+4** (12+4=16 > 15; при +3: 12+3=15, 15>15=false — ничья) |

> **Примечание**: формула принадлежит CombatSystem. MonsterDatabase предоставляет только `difficulty`. Таблица здесь для контекста баланса.

## Edge Cases

- **EC-01** — ЕСЛИ `get_monster(id)` вызван с несуществующим `id`: возвращает `null`. Вызывающая система обязана проверить результат на `null` перед использованием.
- **EC-02** — ЕСЛИ `event_content_id == &""` (CHEST токен): `get_monster(&"")` возвращает `null`. Не ошибка — EncounterDispatcher проверяет `event_type` перед вызовом.
- **EC-03** — ЕСЛИ второй игрок входит в ROOM, где первый ещё не завершил бой: **невозможно** — бои атомарны. Бой первого игрока завершается полностью (победа → ячейка CLEARED; поражение → игрок возвращается в предыдущую ячейку) до того, как второй игрок может войти в эту комнату. Контроль порядка — в TurnManager / MovementSystem.
- **EC-04** — ЕСЛИ `difficulty = 15` и `attack_total < 15`: игрок проигрывает бой и возвращается в предыдущую ячейку. Детали разрешения поражения (урон HP, нокаут) — в CombatSystem GDD.
- **EC-05** — ЕСЛИ `vp_on_kill > 0` и монстр этого типа встречается несколько раз в пуле (Призрак ×2): каждое убийство засчитывает ОЧ отдельно — нет ограничения на количество ОЧ от одного типа.

## Dependencies

### Зависимости входящие (MonsterDatabase зависит от)

Нет. MonsterDatabase — Foundation layer, нет зависимостей.

### Зависимости исходящие (зависят от MonsterDatabase)

| Система | Что берёт | Статус |
|---------|-----------|--------|
| **CombatSystem** | `get_monster(id).difficulty` — порог броска | Спроектирована ✓ |
| **WinCondition** | `get_monster(id).is_dragon` — проверка конца игры | Спроектирована ✓ |
| **LootSystem** | `get_monster(id).drops_key` — дроп ключа при победе | Спроектирована ✓ |
| **EncounterDispatcher** | `get_monster(id)` — тип и параметры встречи | Спроектирован ✓ |
| **TileSystem** | `event_content_id` ссылается на `id` монстра | Спроектирована ✓ |

## Tuning Knobs

| Параметр | Значение | Безопасный диапазон | Влияние |
|----------|----------|---------------------|---------|
| `RAT_DIFFICULTY` | 5 | 3–7 | Порог входного монстра; ниже → слишком лёгкое начало |
| `DRAGON_DIFFICULTY` | 15 | 13–18 | Порог финального боя; должен превышать `roll(2,6)` max (12) |
| `GHOST_VP` | 1.0 | 0.5–2.0 | ОЧ за Призрака; высокий риск (difficulty 12) — высокая награда |
| `DRAGON_VP` | 1.5 | 1.1–2.0 | Нецелое — разрешение ничьи; не менять на целое |
| `MIN_COMBAT_BONUS_FOR_DRAGON` | 4 | — | Минимум для любого исхода WIN: `DRAGON_DIFFICULTY - 12 + 1 = 4` (строгое >); справочное значение |

## Visual/Audio Requirements

[To be designed]

## UI Requirements

[To be designed]

## Acceptance Criteria

### AC-01 — База содержит ровно 8 записей
- **Given** MonsterDatabase загружен
- **Then** количество записей == 8

### AC-02 — `get_monster` возвращает корректные данные
- **When** `get_monster(&"dragon")` вызван
- **Then** `result.difficulty == 15` AND `result.is_dragon == true` AND `result.vp_on_kill == 1.5`

### AC-03 — `get_monster` с несуществующим id возвращает null
- **When** `get_monster(&"unknown_monster")` вызван
- **Then** результат == `null`

### AC-04 — Скелет-ключник дропает ключ
- **When** `get_monster(&"skeleton_key")` вызван
- **Then** `result.drops_key == true`

### AC-05 — Только Дракон имеет is_dragon = true
- **Given** все 8 записей
- **Then** ровно одна запись имеет `is_dragon == true`, и это `&"dragon"`

### AC-06 — Только Призрак и Дракон имеют vp_on_kill > 0
- **Given** все 8 записей
- **Then** записи с `vp_on_kill > 0` == 2: `&"ghost"` (1.0) и `&"dragon"` (1.5)

> **Design rationale** (Resolved B-11 2026-10-10): монстры = источник снаряжения, не VP. VP сосредоточены в сундуках (ключ-ограничение) + Призрак (высокий риск, difficulty 12) + Дракон (финал). Это соответствует оригинальному Karak и сохраняет чёткое разделение ценностей: «убивай монстров → становишься сильнее; открывай сундуки + охоться на Призраков → набираешь VP».

### AC-07 — Дракон непобедим без снаряжения; минимальный бонус для победы = 4
- **Given** `difficulty("dragon") == 15`, `roll(2,6)` max == 12
- **Then** без `combat_bonus`: `12 > 15` = false → победа невозможна
- **And** при `combat_bonus = 3`: `12+3=15 > 15` = false → ничья, победа невозможна
- **And** при `combat_bonus = 4`: `12+4=16 > 15` = true → минимальный один исход WIN достигнут

## Open Questions

### OQ-01 — Что происходит при поражении (HP / нокаут)?

EC-04 фиксирует «игрок возвращается в предыдущую ячейку», но не затрагивает урон HP и нокаут. Детали — в CombatSystem и KnockoutSystem GDD.

**Provisional**: поражение = потеря 1 HP + возврат. Уточнить в CombatSystem.

### OQ-02 — Нужен ли `loot_table_id` в MonsterData?

~~**RESOLVED** (2026-10-10)~~: не нужен. LootSystem GDD спроектирован — drop table захардкожена по `monster_id` (`StringName`) в LootSystem Rule 4. `MonsterData` не хранит loot-данные. Поле `drops_key` заменено унифицированным `item_dropped(player, monster_id)` сигналом в CombatSystem (B-02, resolved 2026-10-10).
