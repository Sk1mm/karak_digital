# ItemDatabase

> **Status**: Designed (retrofitted 2026-10-10)
> **Author**: game-designer + user
> **Last Updated**: 2026-10-10 (retrofitted G-01, G-02, I-05)
> **Implements Pillar**: Pillar 2 — «Сила ощутима»

## Overview

ItemDatabase — статическое хранилище данных всех предметов игры. Определяет три категории предметов: **оружие** (`WEAPON`) с полем `combat_bonus`; **ключ** (`KEY`) — расходуемый предмет для открытия сундуков; **свитки** (`SCROLL`) двух подтипов — `MAGIC_ATTACK` (используется в бою: добавляет бонус к броску или наносит урон) и `TELEPORT` (используется вне боя: телепортирует игрока к ближайшему раскрытому порталу). Флаг `magic_charge_no_discard` Волшебника (ClassSystem) применяется только к `scroll_teleport` — Волшебник использует Свиток телепорта неограниченное число раз; `scroll_magic_attack` расходуется нормально для всех классов включая Волшебника. LootSystem читает ItemDatabase при открытии сундука; CombatSystem читает `combat_bonus` оружия и эффект свитков `MAGIC_ATTACK`; PlayerState хранит ссылки на `ItemData` в слотах (2 оружия, 1 ключ, 3 свитка).

## Player Fantasy

ItemDatabase — чистый data layer. Эмоция «нашёл мощный топор» или «применил свиток в критический момент» создаётся LootSystem, CombatSystem и CombatUI; ItemDatabase только хранит числа, которые делают эти моменты значимыми. Pillar 2 («Сила ощутима») реализуется через значения `combat_bonus` в оружии — именно эти цифры определяют, насколько явно игрок чувствует прогрессию.

## Detailed Design

### Core Rules

1. ItemDatabase хранит статические записи `ItemData` — по одной на каждый предмет. База данных неизменяема в партии.
2. Каждая запись `ItemData` содержит:

```gdscript
class_name ItemData
extends Resource

@export var id: StringName           # уникальный ключ
@export var display_name: String     # имя для UI
@export var item_type: ItemType      # WEAPON / KEY / SCROLL
@export var icon: Texture2D          # иконка для InventoryUI / HUD / CombatUI
@export var combat_bonus: int = 0    # бонус к attack_total (только для WEAPON и SCROLL с MAGIC_ATTACK)
@export var scroll_type: ScrollType  # MAGIC_ATTACK / TELEPORT / NONE
@export var is_consumable: bool      # true = удаляется из инвентаря после использования
```

3. **Таблица предметов:**

| `id` | `display_name` | `item_type` | `combat_bonus` | `scroll_type` | `is_consumable` |
|------|----------------|-------------|---------------|---------------|-----------------|
| `&"dagger"` | Кинжал | WEAPON | 1 | NONE | false |
| `&"sword"` | Меч | WEAPON | 2 | NONE | false |
| `&"axe"` | Топор | WEAPON | 3 | NONE | false |
| `&"key"` | Ключ | KEY | 0 | NONE | true |
| `&"scroll_magic_attack"` | Магический удар | SCROLL | 1 | MAGIC_ATTACK | true |
| `&"scroll_teleport"` | Свиток телепорта | SCROLL | 0 | TELEPORT | true |

4. **Исключение Волшебника**: флаг `magic_charge_no_discard` в ClassSystem отменяет `is_consumable` **только для `scroll_teleport`** — Волшебник использует Свиток телепорта неограниченное число раз, не теряя его. `scroll_magic_attack` расходуется нормально для всех классов включая Волшебника. Логика исключения — в CombatSystem и EncounterDispatcher, не в ItemDatabase.

5. **Слоты инвентаря** (хранятся в PlayerState): 2 слота `WEAPON`, 1 слот `KEY`, 3 слота `SCROLL`.
6. `get_item(id: StringName) -> ItemData` — единственная публичная операция. Возвращает `null` если `id` не найден.

### States and Transitions

ItemDatabase не имеет состояний. Данные статичны, загружаются один раз при старте.

### Interactions with Other Systems

| Система | Направление | Что передаётся |
|---------|-------------|----------------|
| LootSystem | → читает | список предметов для формирования лут-таблицы сундуков |
| CombatSystem | → читает | `get_item(id).combat_bonus` экипированных предметов + эффект `MAGIC_ATTACK` |
| PlayerState | → хранит | ссылки на `id` предметов в слотах инвентаря |
| EncounterDispatcher | → читает | `get_item(&"key")` — проверка наличия ключа для открытия сундука; применяет `TELEPORT` свиток |

## Formulas

ItemDatabase — чистый data layer без собственной математики. Все формулы, использующие данные ItemDatabase, принадлежат другим системам. Раздел документирует только эти связи.

### Формула 1: Итог атаки с учётом предметов *(принадлежит CombatSystem)*

```
attack_total = sum(roll(2, 6)) + Σ effective_combat_bonus(equipped_items)
             = dice + weapon_bonus + scroll_bonus
```

| Переменная | Источник | Диапазон | Описание |
|------------|----------|----------|----------|
| `roll(2, 6)` | DiceSystem | 2–12 | Базовый боевой бросок |
| `combat_bonus` | ItemDatabase | 0–3 | Бонус одного предмета (поле `ItemData.combat_bonus`) |
| Σ `effective_combat_bonus` | PlayerState (2 оружия + до 3 свитков по 1) | 0–9 | Суммарный боевой вклад всего экипированного снаряжения |
| `attack_total` | — | 2–21 | Итог для сравнения с `difficulty` |

> **Важно**: `Σ effective_combat_bonus` (0–9) ≠ `PlayerState.get_attack_bonus()`.
> `get_attack_bonus()` возвращает только вклад оружия (0–6); свитки `MAGIC_ATTACK`
> добавляются CombatSystem отдельно. Не использовать `get_attack_bonus()` как proxy
> для полного боевого бонуса.
>
> Максимум: 2 топора (3+3) + 3 свитка Магического удара (1+1+1) + бросок 12 = 21.
> Против Дракона (difficulty=15): минимальный `Σ effective_combat_bonus` для **любого** исхода WIN = 4
> (условие победы строгое: `attack_total > difficulty`; при bonus=3: 12+3=15, 15>15=false — ничья, поражение без урона).
> `attack_total` с классовыми бонусами (Чернокнижник spend_hp +1, Оракул first_step +1) может достигать 22 для любого отдельного класса —
> hp_bonus и first_step_bonus принадлежат разным классам и не суммируются одновременно.
> Подробнее — в CombatSystem Formulas.

### Формула 2: Условие consumable *(принадлежит CombatSystem / EncounterDispatcher)*

```
discard_after_use = item.is_consumable AND NOT class.magic_charge_no_discard
```

| Условие | Результат |
|---------|-----------|
| `is_consumable = false` | Предмет остаётся в инвентаре (оружие) |
| `is_consumable = true`, флаг Волшебника отсутствует | Предмет удаляется из слота |
| `is_consumable = true`, флаг Волшебника активен, `item_type == SCROLL_TELEPORT` | Предмет остаётся (Волшебник, только свиток телепортации) |
| `is_consumable = true`, флаг Волшебника активен, `item_type == SCROLL_MAGIC_ATTACK` | Предмет **расходуется** (Волшебник не исключение для боевых свитков) |

### Формула 3: Вместимость инвентаря *(принадлежит PlayerState)*

```
capacity = {WEAPON: 2, KEY: 1, SCROLL: 3}
item_fits = count(slots[item.item_type]) < capacity[item.item_type]
```

> ItemDatabase не проверяет вместимость — это зона ответственности PlayerState и LootSystem.

## Edge Cases

- **EC-01** — ЕСЛИ `get_item(id)` вызван с несуществующим `id`: возвращает `null`. Вызывающая система обязана проверить результат перед использованием.
- **EC-02** — ЕСЛИ слот заполнен при подборе предмета: игрок может заменить один из предметов в слоте — новый помещается в инвентарь, старый выкладывается на текущий тайл («на пол»). Логика замены и размещения выброшенного предмета — в LootSystem, не в ItemDatabase.
- **EC-03** — ЕСЛИ Волшебник использует `scroll_teleport` при `magic_charge_no_discard = true`: `is_consumable` игнорируется, слот не освобождается. Применимо **только** к `scroll_teleport`; `scroll_magic_attack` расходуется нормально для Волшебника. Логика — в CombatSystem / EncounterDispatcher.
- **EC-04** — ЕСЛИ игрок экипирует два одинаковых оружия (например, два `&"axe"`): допустимо — слоты независимы, `combat_bonus` суммируется дважды (3+3=6). ItemDatabase не ограничивает дублирование — это политика LootSystem.
- **EC-05** — ЕСЛИ `get_item(&"key")` вызван EncounterDispatcher для проверки наличия ключа: возвращает запись `ItemData` независимо от того, есть ли ключ у игрока. Наличие ключа в инвентаре проверяет PlayerState — ItemDatabase только хранит описание предмета.
- **EC-06** — ЕСЛИ свиток `TELEPORT` применён, а ближайший раскрытый портал отсутствует: поведение определяет EncounterDispatcher (например, свиток не тратится). ItemDatabase не знает о состоянии карты.

## Dependencies

### Зависимости входящие (ItemDatabase зависит от)

Нет. ItemDatabase — Foundation layer, нет зависимостей.

### Зависимости исходящие (зависят от ItemDatabase)

| Система | Что берёт | Статус |
|---------|-----------|--------|
| **LootSystem** | `get_item(id)` — список предметов для лут-таблицы сундуков; логика замены при полном слоте | Спроектирована ✓ |
| **CombatSystem** | `get_item(id).combat_bonus` экипированных предметов; `is_consumable` + флаг Волшебника для свитков `MAGIC_ATTACK` | Спроектирована ✓ |
| **EncounterDispatcher** | `get_item(&"key")` — проверка типа предмета; применение свитка `TELEPORT` | Спроектирован ✓ |
| **PlayerState** | Хранит `id` предметов в слотах инвентаря (2 WEAPON, 1 KEY, 3 SCROLL) | Спроектирован ✓ |
| **InventoryUI** | `get_item(id).display_name`, `item_type`, `icon` для отображения слотов | Спроектирован ✓ |

## Tuning Knobs

| Параметр | Значение | Безопасный диапазон | Влияние |
|----------|----------|---------------------|---------|
| `DAGGER_BONUS` | 1 | 1–2 | Бонус кинжала; нижняя ступень линейки оружий |
| `SWORD_BONUS` | 2 | 2–3 | Бонус меча; средняя ступень |
| `AXE_BONUS` | 3 | 3–4 | Бонус топора; верхняя ступень; снижать нельзя ниже 3 (иначе Дракон непобедим без 3 свитков) |
| `SCROLL_MAGIC_ATTACK_BONUS` | 1 | 1–2 | Бонус одного свитка Магического удара; 3 свитка = +3 суммарно — альтернативный путь к Дракону |
| `WEAPON_SLOTS` | 2 | 1–2 | Количество слотов оружия; влияет на максимальный combat_bonus от оружий |
| `KEY_SLOTS` | 1 | 1 | Количество слотов ключа; не менять |
| `SCROLL_SLOTS` | 3 | 2–3 | Количество слотов свитков; меньше 2 ограничивает класс Волшебника |
| `MIN_COMBAT_BONUS_FOR_DRAGON` | 4 | — | Вычисляется: `DRAGON_DIFFICULTY(15) - roll_max(12) + 1 = 4` (строгое >); справочное значение |

## Visual/Audio Requirements

[To be designed]

## UI Requirements

[To be designed]

## Acceptance Criteria

### AC-01 — База содержит ровно 6 записей
- **Given** ItemDatabase загружен
- **Then** количество записей == 6

### AC-02 — `get_item` возвращает корректные данные для оружия
- **When** `get_item(&"axe")` вызван
- **Then** `result.item_type == WEAPON` AND `result.combat_bonus == 3` AND `result.is_consumable == false`

### AC-03 — `get_item` возвращает корректные данные для ключа
- **When** `get_item(&"key")` вызван
- **Then** `result.item_type == KEY` AND `result.combat_bonus == 0` AND `result.is_consumable == true`

### AC-04 — `get_item` возвращает корректные данные для свитка
- **When** `get_item(&"scroll_magic_attack")` вызван
- **Then** `result.item_type == SCROLL` AND `result.scroll_type == MAGIC_ATTACK` AND `result.combat_bonus == 1` AND `result.is_consumable == true`

### AC-05 — `get_item` с несуществующим id возвращает null
- **When** `get_item(&"unknown_item")` вызван
- **Then** результат == `null`

### AC-06 — Только оружие имеет `is_consumable = false`
- **Given** все 6 записей
- **Then** записи с `is_consumable == false` == 3, все имеют `item_type == WEAPON`

### AC-07 — Только свитки имеют `scroll_type != NONE`
- **Given** все 6 записей
- **Then** записи с `scroll_type != NONE` == 2, все имеют `item_type == SCROLL`

### AC-08 — Суммарный максимальный combat_bonus достигает 9
- **Given** 2× `&"axe"` (3+3) + 3× `&"scroll_magic_attack"` (1+1+1)
- **Then** Σ `combat_bonus` == 9

## Open Questions

### OQ-01 — Что происходит с предметом «на полу» если другой игрок заходит на тот же тайл?

EC-02 фиксирует, что выброшенный предмет остаётся на тайле. Может ли второй игрок его подобрать? Что происходит, если на тайле уже лежит предмет при открытии сундука?

**Provisional**: второй игрок может подобрать предмет с пола. Уточнить в LootSystem GDD.

### OQ-02 — Можно ли применить свиток `MAGIC_ATTACK` вне боя?

Сейчас свиток помечен как боевой (`MAGIC_ATTACK`). Если игрок попытается использовать его вне боя — что происходит?

**Provisional**: невозможно — EncounterDispatcher блокирует применение вне боя. Уточнить в EncounterDispatcher GDD.

### OQ-03 — Нужен ли `display_icon` или `sprite_path` в ItemData?

~~**RESOLVED** (2026-10-10 — C-07)~~: добавлено поле `@export var icon: Texture2D` в ItemData. InventoryUI, HUD и CombatUI читают `icon` для отображения предметов. Тип `Texture2D` — нативный Godot Resource, назначается в Inspector через `@export`.
