# EncounterDispatcher

> **Status**: Designed (pending /design-review)
> **Author**: game-designer + user
> **Last Updated**: 2026-10-10 (retrofitted I-04)
> **Implements Pillar**: Pillar 1 — «Каждый тайл — маленькая история»

## Overview

EncounterDispatcher — маршрутизатор встреч. Слушает сигнал `tile_reveal_complete(player, pos)` от TileRevealVFX (после завершения анимации переворота), читает категорию и событие тайла через TileSystem и направляет управление нужному обработчику: запускает бой (MONSTER), открывает сундук (CHEST), лечит и завершает ход (FOUNTAIN / FOUNTAIN_SECONDARY), предлагает телепортацию (PORTAL) или ничего не делает (CORRIDOR, очищенный тайл).

EncounterDispatcher — единственная точка входа в «что здесь происходит». Он не знает правил боя, не знает содержимого инвентаря — он только решает: «это бой, это лут, или это просто коридор» — и передаёт управление дальше. Классовое исключение Оракула (выбор из двух event-токенов) обрабатывается здесь. Обход монстров Разбойницей и Воительницей обрабатывается в MovementSystem до вызова `tile_reveal_complete`.

## Player Fantasy

EncounterDispatcher невидим. Игрок не знает, что существует «диспетчер» — он знает только, что перевернул тайл и теперь перед ним монстр. Или сундук. Или фонтан.

Именно эта непредсказуемость и есть Pillar 1: «Каждый тайл — маленькая история». EncounterDispatcher — тот, кто решает, какой будет эта история. Он не создаёт напряжение сам — он гарантирует, что оно возникает каждый раз, когда тайл переворачивается. Без него каждый шаг был бы просто перемещением.

## Detailed Design

### Core Rules

1. **Единственная точка входа.** EncounterDispatcher слушает сигнал `tile_reveal_complete(player: PlayerState, pos: Vector2i)` от TileRevealVFX. Сигнал эмитируется после завершения анимации переворота тайла. Он — единственный вызываемый в этот момент обработчик маршрутизации встречи.

2. **Чтение тайла.** При получении сигнала EncounterDispatcher вызывает `TileSystem.get_cell(pos)` и читает поля `category` и `event`.

3. **Маршрутизация по категории:**

   | category | Действие |
   |----------|----------|
   | `CORRIDOR` | `TileSystem.clear_cell(pos)` → конец |
   | `ROOM` | Перейти к Rule 4 (draw event token) |
   | `FOUNTAIN` / `FOUNTAIN_SECONDARY` | Перейти к Rule 5 (выбор фонтана) |
   | `PORTAL` | Перейти к Rule 6 (выбор портала) |

4. **ROOM — draw event token (первый вход).**
   - Вызывается только если `TileSystem.is_cleared(pos) == false` (ячейка не очищена — монстр/сундук ещё не разрешён).
   - Вызывает `TileSystem.draw_event_token()` → возвращает `event`. TileSystem сохраняет `event` в `DungeonCell.event_content_id`.
   - **Оракул (класс):** получает 2 токена → выбирает 1 → второй возвращается в мешок.
   - По значению `event`:
     - `MONSTER` → `emit_signal("combat_started", player, monster_data)`
     - `CHEST` + `player.has_key` → `emit_signal("loot_started", player, pos)` + `player.remove_key()`
     - `CHEST` + нет ключа → ничего
     - Другие event-значения → зарезервировано (игнорируется)

4a. **ROOM — повторный вход (re-entry).**
   - Вызывается если `TileSystem.is_revealed(pos) == true` и `TileSystem.is_cleared(pos) == false`.
   - `draw_event_token()` **не вызывается**. Читает `DungeonCell.event_content_id` из TileSystem.
   - Применяет то же `event`, что было при первом входе. Это гарантирует: Игрок B встречает того же монстра/сундук, что видел Игрок A.

5. **FOUNTAIN / FOUNTAIN_SECONDARY — выбор игрока.**
   - EncounterDispatcher предлагает выбор: использовать фонтан или нет.
   - **Если да:** `PlayerState.heal_full()` + `TurnManager.burn_steps()` + `TileSystem.clear_cell(pos)` → конец хода.
   - **Если нет:** ничего не происходит, ход продолжается.
   - Фонтан **не расходуется** при отказе — доступен при следующем визите.

6. **PORTAL — выбор игрока (стоит 1 шаг).**
   - Если `TurnManager.steps_remaining >= 1`: предложить телепортацию.
   - EncounterDispatcher передаёт игроку список `revealed_portals \ {pos}` как доступные цели.
   - **Если принял и выбрал цель `chosen_portal`:** `PlayerState.set_position(chosen_portal)` + `TurnManager.spend_step()`.
   - **Если отказался:** ничего, ход продолжается.
   - Телепортация всегда стоит 1 шаг; если `steps_remaining == 0` — выбор не предлагается.

### States and Transitions

EncounterDispatcher не хранит собственного состояния. Он stateless — получает сигнал, маршрутизирует, завершает работу. Все состояния хранятся в TurnManager, PlayerState и TileSystem.

### Interactions with Other Systems

| Система | Роль | Что получает EncounterDispatcher | Что отдаёт |
|---------|------|-----------------------------------|------------|
| TileRevealVFX | upstream | `tile_reveal_complete(player, pos)` — триггер диспетчера | — |
| TileSystem | upstream | `get_cell(pos)`, `draw_event_token()` | `clear_cell(pos)` |
| PlayerState | upstream/downstream | `player.has_key`, `player.class` | `heal_full()`, `remove_key()`, `set_position()` |
| TurnManager | downstream | `steps_remaining` | `burn_steps()`, `spend_step()` |
| CombatSystem | downstream | — | `combat_started(player, monster_data)` |
| LootSystem | downstream | — | `loot_started(player, pos)` |

## Formulas

### Список доступных порталов для телепортации

```
available_portals = revealed_portals \ {pos}
```

| Переменная | Тип | Диапазон | Описание |
|-----------|-----|----------|----------|
| `revealed_portals` | `Array[Vector2i]` | 1..N | Все раскрытые тайлы с category=PORTAL |
| `pos` | `Vector2i` | — | Текущая позиция игрока (портал, на котором стоит) |
| `available_portals` | `Array[Vector2i]` | 0..N-1 | Цели для выбора; пуст если нет других порталов |

**Правило**: игрок видит `available_portals` и выбирает любой. Порядок отображения — порядок обнаружения (insertion order в TileSystem).

**Диапазон:** 0 (выбор недоступен) до N-1 вариантов.

**Если других порталов нет:** `available_portals` пуст — телепортация недоступна, выбор не предлагается.

**Пример:** игрок на портале A (1,1), раскрыты B (3,3) и C (5,1). Игрок видит список [B, C] и выбирает один.

### Использование фонтана

Нет формулы. `heal_full()` восстанавливает HP до `PlayerState.max_hp` — логика в PlayerState.

### Использование сундука

Нет формулы. `has_key` — булево поле PlayerState. Логика лута в LootSystem.

## Edge Cases

**EC-01: Два игрока на одном тайле одновременно.**
Игроки ходят по очереди (hotseat). Два игрока не могут входить на один тайл в один ход. Если игрок B входит на тайл, который игрок A уже посетил и очистил — тайл категории `CORRIDOR`, диспетчер вызывает только `clear_cell` (уже очищен, повторный вызов безвреден).

**EC-02: Оракул — в мешке остался 1 токен.**
`TileSystem.draw_event_token()` вызывается дважды. Если мешок содержит 1 токен — Оракул получает только 1 и выбора нет, токен применяется автоматически.

**EC-03: Оракул — в мешке 0 токенов.**
Если при входе Оракула в ROOM мешок пуст — ничего не происходит, тайл ведёт себя как CORRIDOR. TileSystem должен гарантировать, что ROOM-тайлы не появляются без токенов в мешке.

**EC-04: Портал — единственный на поле.**
`revealed_portals` содержит только текущий pos. Телепортация недоступна. Игрок входит на тайл, выбор не предлагается, ход продолжается.

**EC-05: Фонтан — игрок уже на полном HP.**
Выбор предлагается всегда. Игрок может принять (heal_full вызовется, HP останется max_hp) или отказаться. Фонтан расходуется при принятии независимо от HP.

**EC-06: Сундук — игрок нашёл его дважды (второй игрок).**
После того как первый игрок открыл сундук, LootSystem удаляет лут. Если второй игрок входит на тот же тайл — `TileSystem.get_cell(pos).category` уже `CORRIDOR` (тайл очищён). EncounterDispatcher вызывает `clear_cell` повторно (безвреден).

**EC-07: steps_remaining = 0 при входе на PORTAL.**
Условие Rule 6: `steps_remaining >= 1`. При 0 шагах выбор не предлагается. Ход заканчивается на портале без телепортации.

**EC-08: Повторный вход на нераскрытый тайл ROOM (re-entry).**
Игрок A вошёл на ROOM (pos), потерял бой и отступил. Тайл: `is_revealed=true`, `is_cleared=false`. Игрок B входит на тот же pos → EncounterDispatcher читает `DungeonCell.event_content_id`, **не вызывает** `draw_event_token()`. Игрок B встречает того же монстра/сундук, что видел Игрок A. Новый токен из мешка не расходуется.

## Dependencies

### Upstream (EncounterDispatcher зависит от)

| Система | Что использует |
|---------|----------------|
| **TileRevealVFX** | Сигнал `tile_reveal_complete(player, pos)` — триггер работы диспетчера (после завершения анимации) |
| **TileSystem** | `get_cell(pos)` → category/event; `draw_event_token()` → event; `clear_cell(pos)` → очистка тайла |
| **PlayerState** | `player.has_key` → проверка ключа; `player.class` → класс для исключения Оракула; `heal_full()`, `remove_key()`, `set_position()` |
| **TurnManager** | `steps_remaining` → проверка для портала; `burn_steps()`, `spend_step()` |

### Downstream (зависит от EncounterDispatcher)

| Система | Что ожидает |
|---------|-------------|
| **CombatSystem** | Сигнал `combat_started(player, monster_data)` — запуск боя |
| **LootSystem** | Сигнал `loot_started(player, pos)` — открытие сундука |
| **TileRevealVFX** | Эмитирует `tile_reveal_complete` → EncounterDispatcher слушает. TileRevealVFX является upstream, не downstream. |

### Обратные ссылки

- **TileRevealVFX GDD** должен упоминать EncounterDispatcher как получателя сигнала `tile_reveal_complete`.
- **TileSystem GDD** должен упоминать EncounterDispatcher как читателя `get_tile()`, `draw_event_token()`, `is_revealed()`, `is_cleared()`, `DungeonCell.event_content_id`.
- **CombatSystem GDD** должен упоминать EncounterDispatcher как источник сигнала `combat_started`.
- **LootSystem GDD** должен упоминать EncounterDispatcher как источник сигнала `loot_started`.
- **MovementSystem GDD** — EncounterDispatcher больше не слушает `cell_entered` напрямую; MovementSystem является indirect upstream через TileRevealVFX.

## Tuning Knobs

EncounterDispatcher — stateless маршрутизатор без игровых параметров. Все числовые значения (HP, шаги) хранятся в зависимых системах. Рычагов настройки здесь нет.

Если в будущем потребуется изменить поведение (например, сделать фонтан одноразовым), это изменение делается в Rule 5 Detailed Design — не через tuning knob.

## Visual/Audio Requirements

Визуальные и аудио-требования EncounterDispatcher делегирует:
- **TileRevealVFX** — анимация переворота тайла при `cell_entered`.
- **CombatUI** — интерфейс боя при `combat_started`.
- **LootSystem** — интерфейс лута при `loot_started`.

EncounterDispatcher сам не производит визуальных или аудио-эффектов. Порядок событий: MovementSystem → TileRevealVFX (анимация) → `tile_reveal_complete` → EncounterDispatcher (маршрутизация). EncounterDispatcher всегда запускается после завершения анимации переворота.

## UI Requirements

- **Фонтан:** требуется диалог выбора «Использовать фонтан? Да / Нет». Реализация в отдельном UI-компоненте (не в EncounterDispatcher).
- **Портал:** требуется диалог выбора «Телепортироваться? Да / Нет». Реализация аналогично.
- **Оракул:** требуется интерфейс выбора одного из двух event-токенов. Реализация — отдельный UI-компонент.
- EncounterDispatcher не знает о UI — он эмитирует сигналы, UI-компоненты подписываются на них.

## Acceptance Criteria

**AC-01:** Игрок входит на CORRIDOR-тайл → тайл очищается (`clear_cell` вызван), никакого события не происходит.

**AC-02:** Игрок входит на ROOM-тайл → вызывается `draw_event_token()`, получен `MONSTER` → сигнал `combat_started` эмитирован с корректным `monster_data`.

**AC-03:** Игрок входит на ROOM-тайл → вызывается `draw_event_token()`, получен `CHEST` + есть ключ → сигнал `loot_started` эмитирован, `player.has_key = false`.

**AC-04:** Игрок входит на ROOM-тайл → вызывается `draw_event_token()`, получен `CHEST` + нет ключа → никакого сигнала, ничего не происходит.

**AC-05:** Игрок (Оракул) входит на ROOM-тайл → `draw_event_token()` вызван дважды → игрок видит выбор из двух токенов → выбранный применяется, второй возвращается в мешок.

**AC-06:** Игрок входит на FOUNTAIN → предложен выбор → игрок принимает → `heal_full()` вызван, `burn_steps()` вызван, `clear_cell()` вызван.

**AC-07:** Игрок входит на FOUNTAIN → предложен выбор → игрок отказывается → ничего не вызвано, фонтан остаётся доступным.

**AC-08:** Игрок повторно входит на FOUNTAIN после отказа → снова предложен выбор (фонтан не заблокирован).

**AC-09:** Игрок входит на PORTAL при `steps_remaining >= 1` → предложена телепортация → принимает → `set_position(nearest_portal)` + `spend_step()`.

**AC-10:** Игрок входит на PORTAL при `steps_remaining = 0` → выбор не предлагается, ход завершается.

**AC-11:** Единственный портал на поле → игрок входит на него → выбор телепортации не предлагается.

**AC-12:** EncounterDispatcher не вызывается повторно при движении после фонтана/портала — только `tile_reveal_complete` от TileRevealVFX является триггером; один шаг = одна анимация = один вызов диспетчера.

**AC-13 — Re-entry не тянет новый токен.**
GIVEN тайл (pos): `is_revealed=true`, `is_cleared=false`, `event_content_id="goblin"`
WHEN второй игрок входит на (pos)
THEN `draw_event_token()` не вызван; применяется `event_content_id="goblin"`; монстр тот же, что при первом входе.

## Open Questions

**OQ-01: Сигнал выбора фонтана и портала.**
Кто эмитирует сигнал «игрок решил» — EncounterDispatcher или UI-компонент? Если UI, то EncounterDispatcher должен ждать ответа (async/await или сигнал обратно). Нужно определить при проектировании CombatUI/LootSystem.

**OQ-02: Что происходит с Оракулом, если оба токена — CHEST и нет ключа?**
Оба токена неиспользуемы. Применяется выбранный (ничего не происходит) или особая логика? Скорее всего — применяется выбранный, ничего не происходит, аналогично обычному CHEST без ключа.

**OQ-03: draw_event_token() при мешке с 0 токенами (EC-03).**
Должен ли TileSystem не допускать ROOM без токенов (гарантия), или EncounterDispatcher должен защититься от пустого мешка самостоятельно? Решить при проектировании TileSystem.
