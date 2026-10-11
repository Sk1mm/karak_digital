# LootSystem

> **Status**: Designed (retrofitted 2026-10-10 ×5)
> **Author**: game-designer + user
> **Last Updated**: 2026-10-10 (retrofitted I-06)
> **Implements Pillar**: Pillar 2 — «Сила ощутима», Pillar 1 — «Каждый тайл — маленькая история»

## Overview

LootSystem управляет всеми событиями получения лута: открытие сундука, подбор ключа и получение предметов с убитых монстров. **Сундук** (`loot_started(player, pos)` от EncounterDispatcher) → начисляет игроку 1 победное очко + `TileSystem.clear_cell(pos)`. **Все монстры**, включая Скелета-ключника, передают лут через единый сигнал `item_dropped(player, monster_id)` от CombatSystem → LootSystem читает таблицу дропа по `monster_id`: Крыса → кинжал, Паук → свиток телепортации, Мумия → свиток магического удара, Скелет-воин → меч, Король скелетов → топор, Скелет-ключник → ключ (особая логика: ключ кладётся в инвентарь или на пол). Призрак и Дракон предметов не дают — их VP-награда обрабатывается в CombatSystem. LootSystem не знает правил боя и не решает, победил ли игрок — он только реагирует на сигналы.

## Player Fantasy

Игрок не думает о «LootSystem». Он думает: «убил Скелета-воина — получил меч». Меч ощутим сразу: следующий бой идёт с другими шансами. Сундук — отдельный ритуал: нашёл ключ, нашёл сундук, открыл — победное очко. Это прогресс, видимый и конкретный. LootSystem невидим, но его результат — нет.

## Detailed Design

### Core Rules

1. **Два триггера.** LootSystem слушает два сигнала:
   - `loot_started(player, pos)` от EncounterDispatcher — открытие сундука
   - `item_dropped(player, monster_id)` от CombatSystem — любой монстр убит (включая SKELETON_KEY)

   CombatSystem эмитирует `item_dropped` для всех победных исходов; LootSystem проверяет таблицу дропа по `monster_id`.

2. **Сундук (`loot_started`).** LootSystem вызывает `PlayerState.add_vp(1)`, затем `TileSystem.clear_cell(pos)`. Сундук убирается с карты навсегда. Затем: `emit_signal("item_acquired", player, null)` — VP не является ItemData; `null` сигнализирует TurnManager о завершении лут-фазы.

3. **Подбор ключа с пола.** LootSystem слушает `cell_entered(player, pos)` от MovementSystem. Если `TileSystem.has_loose_key(pos) == true` и `player.has_key == false` → `PlayerState.set_key(key_item)` + `TileSystem.remove_loose_key(pos)` → `emit_signal("item_acquired", player, key_item)`. Подбор автоматический.

   *(Выдача ключа игроку при убийстве Скелета-ключника обрабатывается в Rule 4 через drop table: `SKELETON_KEY → key`.)*

4. **Предмет монстра (`item_dropped`).** LootSystem читает таблицу дропа, получает `ItemData` через `ItemDatabase.get_item(item_id)`, затем вызывает соответствующий метод PlayerState по `item.item_type`:
   - `WEAPON` → `PlayerState.add_weapon(item)` (false = слоты заняты → предложить `replace_weapon`)
   - `SCROLL` → `PlayerState.add_scroll(item)` (false = слоты заняты → предложить `replace_scroll`)
   - `KEY` → особая логика: если `player.has_key == false` → `PlayerState.set_key(item)`, иначе → `TileSystem.place_loose_key(player.get_position())`

   После обработки (любой путь — `add_weapon`, `add_scroll`, `set_key`, `replace_weapon`, `replace_scroll`, `place_loose_key`): `emit_signal("item_acquired", player, item)` — TurnManager выходит из `AWAITING_LOOT` и завершает ход.

   Стек одинаковых предметов допустим.

   | monster_id | item_id |
   |---|---|
   | `&"rat"` | `dagger` |
   | `&"spider"` | `scroll_teleport` |
   | `&"mummy"` | `scroll_magic_attack` |
   | `&"skeleton_warrior"` | `sword` |
   | `&"skeleton_king"` | `axe` |
   | `&"skeleton_key"` | `key` — особая логика: если `player.has_key == false` → `PlayerState.set_key(item)`, иначе → `TileSystem.place_loose_key(player.get_position())` |
   | `&"ghost"` | — (VP обрабатывается в CombatSystem) |
   | `&"dragon"` | — (VP обрабатывается в CombatSystem) |

5. **LootSystem stateless.** Не хранит собственного состояния. Все данные — в PlayerState и TileSystem.

> **Кросс-ссылка:** CombatSystem GDD содержит `item_dropped(player, monster_id)` — эмитируется при каждой победе (Rule 9). Resolved 2026-10-10.

### States and Transitions

LootSystem stateless — нет собственных состояний. Получил сигнал → применил эффект → эмитирует `item_acquired` → завершил работу.

### Interactions with Other Systems

| Система | Роль | Что получает LootSystem | Что отдаёт |
|---|---|---|---|
| EncounterDispatcher | upstream | `loot_started(player, pos)` | — |
| CombatSystem | upstream | `item_dropped(player, monster_id)` — для всех монстров включая SKELETON_KEY | — |
| MovementSystem | upstream | `cell_entered(player, pos)` — для подбора ключа с пола (Rule 3а) | — |
| PlayerState | downstream | — | `add_vp(1)`, `add_weapon(item)`, `set_key(item)`, `add_scroll(item)`, `replace_weapon(old, new)`, `replace_scroll(old, new)` |
| TileSystem | downstream | — | `clear_cell(pos)`, `place_loose_key(pos)`, `has_loose_key(pos)`, `remove_loose_key(pos)` |
| TurnManager | downstream | — | сигнал `item_acquired(player, item)` — триггер выхода из `AWAITING_LOOT` и конца хода |

## Formulas

### Таблица дропа монстров (полная)

| monster_id | item_id | attack_bonus | Описание |
|---|---|---|---|
| `&"rat"` | `dagger` | +1 | Кинжал |
| `&"spider"` | `scroll_teleport` | — | Свиток телепортации к ближайшему порталу |
| `&"mummy"` | `scroll_magic_attack` | +1 | Свиток магического удара (одноразовый бонус в бою) |
| `&"skeleton_warrior"` | `sword` | +2 | Меч |
| `&"skeleton_king"` | `axe` | +3 | Топор |
| `&"skeleton_key"` | `key` | — | Ключ от сундука (особая логика размещения — см. Rule 4) |

### VP за сундук

```
vp_from_chest = 1
```

Константа. Не зависит от класса, состояния или позиции.

### Примечания

- `scroll_teleport` — не даёт attack_bonus; телепортирует к ближайшему порталу; механика определяется в ItemDatabase GDD
- `scroll_magic_attack` — одноразовый; после использования в бою удаляется из инвентаря
- Конкретные значения `attack_bonus` оружия определяются в ItemDatabase GDD и должны совпадать с combat_bonus в CombatSystem GDD

## Edge Cases

**EC-01: Игрок убивает Скелета-ключника, у него уже есть ключ.**
LootSystem получает `item_dropped(player, &"skeleton_key")` → Rule 4 drop table: `&"skeleton_key" → key` → `player.has_key == true` → ключ не добавляется игроку. Вместо этого: `TileSystem.place_loose_key(pos)`. Ключ остаётся лежать в комнате. Когда любой игрок без ключа войдёт на этот тайл — подберёт его автоматически (Rule 3а).

**EC-02: Игрок убивает монстра повторно (тот же monster_id второй раз).**
Стек допустим. LootSystem вызывает `PlayerState.add_item(item_id)` снова. У игрока два кинжала или два меча — оба дают attack_bonus. Баланс — вопрос к CombatSystem, не к LootSystem.

**EC-03: `item_dropped` с неизвестным `monster_id` (в т.ч. GHOST и DRAGON).**
Если monster_id отсутствует в таблице дропа (GHOST, DRAGON) — LootSystem не выдаёт предмет, но **обязан** испустить `emit_signal("item_acquired", player, null)`. Сигнал `item_acquired(player, null)` сигнализирует TurnManager о завершении лут-фазы (выход из AWAITING_LOOT). Без него TurnManager зависнет в AWAITING_LOOT навсегда.

Последовательность для Ghost/Dragon: `item_dropped(player, "ghost")` → нет записи в drop table → `emit_signal("item_acquired", player, null)` → TurnManager → конец хода.

**EC-04: `loot_started` после того как сундук уже был открыт.**
Не должно произойти: EncounterDispatcher вызывает `loot_started` только если `player.has_key == true`, а после открытия `TileSystem.clear_cell(pos)` тайл становится CORRIDOR. При повторном входе на CORRIDOR EncounterDispatcher не эмитирует `loot_started`. Повторный вызов теоретически безопасен: `add_vp(1)` добавит 1 VP снова — защита на стороне EncounterDispatcher.

**EC-05: `item_dropped` для SKELETON_KEY (Скелет-ключник).**
CombatSystem эмитирует `item_dropped(player, &"skeleton_key")` — единый сигнал для всех монстров. LootSystem обрабатывает `&"skeleton_key"` через таблицу дропа (Rule 4): если `player.has_key == false` → `set_key(item)`, иначе → `place_loose_key(pos)`. Отдельного сигнала `key_dropped` не существует. Resolved 2026-10-10 (B-02).

**EC-06: Игрок с ключом входит на тайл с лежащим ключом (Rule 3а).**
`TileSystem.has_loose_key(pos) == true`, но `player.has_key == true` → условие Rule 3а не выполнено. Ключ остаётся лежать на тайле — второй игрок может его подобрать.

## Dependencies

### Upstream (LootSystem зависит от)

| Система | Что использует |
|---|---|
| **EncounterDispatcher** | Сигнал `loot_started(player, pos)` — открытие сундука |
| **CombatSystem** | Сигнал `item_dropped(player, monster_id)` — при каждой победе, включая SKELETON_KEY |
| **MovementSystem** | Сигнал `cell_entered(player, pos)` — для автоподбора ключа с пола |

### Downstream (зависит от LootSystem)

| Система | Что ожидает |
|---|---|
| **PlayerState** | Вызовы `add_vp(1)`, `add_weapon(item)`, `set_key(item)`, `add_scroll(item)`, `replace_weapon(old, new)`, `replace_scroll(old, new)` — LootSystem их инициирует |
| **TileSystem** | Вызовы `clear_cell(pos)`, `place_loose_key(pos)`, `has_loose_key(pos)`, `remove_loose_key(pos)` |
| **TurnManager** | Слушает `item_acquired(player, item)` — выход из `AWAITING_LOOT` и завершение хода |
| **InventoryUI** | Должен реагировать на изменения инвентаря PlayerState после `add_item` |
| **HUD** | Должен отображать VP после `add_vp` |

### Обратные ссылки

- **CombatSystem GDD** содержит `item_dropped(player, monster_id)` — resolved 2026-10-10.
- **TileSystem GDD** должен упоминать LootSystem как потребителя `place_loose_key / has_loose_key / remove_loose_key`.
- **MovementSystem GDD** должен упоминать LootSystem как подписчика `cell_entered`.

## Tuning Knobs

| Параметр | Текущее значение | Безопасный диапазон | Что регулирует |
|---|---|---|---|
| `VP_PER_CHEST` | 1 | 1–3 | Ценность открытия сундука относительно убийства монстра |
| Таблица дропа монстров | фиксирована | — | Предмет за каждого монстра — изменение влияет на доступность оружия и экономику боя |

LootSystem не имеет вероятностных параметров — дроп детерминированный. Основные рычаги баланса находятся в ItemDatabase (attack_bonus предметов) и CombatSystem (difficulty монстров).

## Visual/Audio Requirements

LootSystem делегирует всё визуальное:
- **InventoryUI** — отображает полученный предмет при `add_item`
- **HUD** — обновляет счётчик VP при `add_vp`
- Подбор ключа с пола — визуальный токен ключа на тайле: ответственность TileRevealVFX или InventoryUI (определить при проектировании TileRevealVFX GDD)

LootSystem сам не производит визуальных эффектов и не воспроизводит звук.

## UI Requirements

LootSystem не управляет UI напрямую. Все изменения инвентаря и VP транслируются через PlayerState → InventoryUI / HUD.

Уведомление о подборе предмета («Получен: Меч») — ответственность InventoryUI, не LootSystem.

## Acceptance Criteria

**AC-01:** Игрок без ключа входит на CHEST-тайл → `loot_started` не эмитируется (проверка на стороне EncounterDispatcher).

**AC-02:** Игрок с ключом открывает сундук (`loot_started` получен) → `PlayerState.vp += 1` + тайл становится CORRIDOR.

**AC-03:** `item_dropped(player, &"rat")` получен → `PlayerState.inventory` содержит `dagger`.

**AC-04:** `item_dropped(player, &"spider")` получен → `PlayerState.inventory` содержит `scroll_teleport`.

**AC-05:** `item_dropped(player, &"mummy")` получен → `PlayerState.inventory` содержит `scroll_magic_attack`.

**AC-06:** `item_dropped(player, &"skeleton_warrior")` получен → `PlayerState.inventory` содержит `sword`.

**AC-07:** `item_dropped(player, &"skeleton_king")` получен → `PlayerState.inventory` содержит `axe`.

**AC-08:** `item_dropped(player, &"skeleton_key")` получен, `player.has_key == false` → `PlayerState.has_key == true`.

**AC-09:** `item_dropped(player, &"skeleton_key")` получен, `player.has_key == true` → `TileSystem.has_loose_key(player.get_position()) == true`, `PlayerState.has_key` не изменился.

**AC-10:** Игрок без ключа входит на тайл с `has_loose_key == true` → `PlayerState.has_key == true` + `TileSystem.has_loose_key(pos) == false`.

**AC-11:** Игрок с ключом входит на тайл с `has_loose_key == true` → ключ остаётся на тайле, `PlayerState.has_key` не изменился.

**AC-12:** Два `item_dropped` с одним `monster_id` → `PlayerState.inventory` содержит два экземпляра предмета.

**AC-13:** `item_dropped` с `monster_id = &"ghost"` → предмет не выдаётся (`&"ghost"` нет в таблице дропа) И сигнал `item_acquired(player, null)` эмитирован. (Без этого сигнала TurnManager зависнет в AWAITING_LOOT — см. EC-03.)

**AC-14:** `item_dropped(player, &"rat")` получен → `add_weapon(dagger_item)` вызван → `item_acquired(player, dagger_item)` эмитирован. (Resolved B-12 2026-10-10)

**AC-15:** `loot_started(player, pos)` получен → `add_vp(1)` + `clear_cell(pos)` вызваны → `item_acquired(player, null)` эмитирован. (Resolved B-12 2026-10-10)

## Open Questions

**OQ-01: VP хранение — PlayerState или WinCondition?** — ~~RESOLVED~~ (2026-10-09)
PlayerState retrofit добавил `vp: float` и `add_vp(amount: float)`. LootSystem вызывает `PlayerState.add_vp(1)` при открытии сундука.

**OQ-02: `place_loose_key` / `has_loose_key` / `remove_loose_key` в TileSystem.**
TileSystem GDD уже написан, но не содержит этих методов. Требует retrofit-обновления.

**OQ-03: Механика `scroll_fountain`.**
«Свиток перемещения к ближайшему фонтану» — телепортирует игрока немедленно или предлагает выбор? Расходуется ли свиток при использовании? Определить в ItemDatabase GDD.

**OQ-04: Стек оружия — суммируются ли бонусы?**
Если у игрока кинжал (+1) и меч (+2) — `attack_bonus = +3`? Или применяется только лучший предмет? Уточнить в CombatSystem retrofit.
