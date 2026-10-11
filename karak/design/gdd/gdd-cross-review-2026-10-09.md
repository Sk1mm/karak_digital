# Cross-GDD Review Report

> **Date**: 2026-10-09
> **GDDs Reviewed**: 18 систем + game-concept.md + systems-index.md
> **Verdict**: FAIL
> **Blocking Issues**: 14
> **Warnings**: 25+
> **Info**: 8

---

## Consistency Issues — BLOCKING

### 🔴 C-01 [2b] Конфликт триггера EncounterDispatcher

`encounter-dispatcher.md` Core Rule 1: слушает `cell_entered` от MovementSystem
`tile-reveal-vfx.md` Core Rule 1: EncounterDispatcher должен слушать `tile_reveal_complete`
→ Retrofit зафиксирован в TileRevealVFX, но EncounterDispatcher GDD не обновлён. Необходимо выбрать один канонический источник и обновить оба GDD.
**Fix**: Update `encounter-dispatcher.md` — заменить upstream trigger с `MovementSystem.cell_entered` на `TileRevealVFX.tile_reveal_complete`.

---

### 🔴 C-02 [2b] Портальная механика — 3 противоречия

`tile-system.md` Rule 8: «телепортация бесплатна»; «игрок выбирает из 3 порталов»
`movement-system.md` Rule 5: «2 шага суммарно» (1 вход + 1 телепортация)
`encounter-dispatcher.md` Formulas: `target_pos = ближайший по манхэттенскому расстоянию` (автовыбор)
→ Три документа описывают разную стоимость и разную механику выбора назначения.
**Fix**: Определить canonical rule в одном GDD (предлагается TileSystem или EncounterDispatcher), остальные ссылаются.

---

### 🔴 C-03 [2c] PlayerState API: 5 отсутствующих элементов

Отсутствуют в `player-state.md`:
- `vp: float` — требуется WinCondition, LootSystem, CombatSystem
- `add_vp(amount: float)` — требуется WinCondition, LootSystem, CombatSystem
- `heal_full()` — требуется EncounterDispatcher (фонтан), KnockoutSystem (Воин)
- `has_key: bool` — требуется EncounterDispatcher Rule 4
- `remove_key()` — требуется EncounterDispatcher Rule 4
**Fix**: Добавить все 5 в `player-state.md` раздел Fields и Public Methods.

---

### 🔴 C-04 [2c] CombatSystem: 3 отсутствующих сигнала

Отсутствуют в `combat-system.md`:
- `item_dropped(player: Node, monster_id: String)` — требует LootSystem (без него 5/7 монстров не дают лут)
- `auto_reroll_triggered(die_index: int, new_value: int)` — требует CombatUI
- `player_choice_requested(available_actions: Dictionary)` — требует CombatUI
**Fix**: Добавить все три в `combat-system.md` Signals и Interactions Downstream.

---

### 🔴 C-05 [2c] LootSystem: несуществующие ID

`loot-system.md` Formulas таблица: `monster_id = "ZOMBIE"` → `scroll_magic_attack`
→ В `monster-database.md` нет монстра `"zombie"`. Есть `"mummy"`.
`loot-system.md` Formulas таблица: предмет `scroll_fountain` (дроп с Паука)
→ В `item-database.md` нет записи `scroll_fountain`. Есть только 6 предметов.
**Fix**: Переименовать ZOMBIE → MUMMY в LootSystem. Решить статус scroll_fountain: либо добавить в ItemDatabase как 7й предмет, либо убрать из пула дропа.

---

### 🔴 C-06 [2c] TileSystem: 4 отсутствующих публичных метода

Отсутствуют в `tile-system.md`:
- `place_loose_key(pos: Vector2i)` — требует LootSystem
- `has_loose_key(pos: Vector2i): bool` — требует LootSystem
- `remove_loose_key(pos: Vector2i)` — требует LootSystem
- `is_revealed(pos: Vector2i): bool` — требует TileRevealVFX (OQ-VFX-01)
**Fix**: Добавить все 4 метода в `tile-system.md` Public API.

---

### 🔴 C-07 [2c] ItemDatabase: отсутствует `icon: Texture2D`

Отсутствует в `item-database.md` классе `ItemData`:
- `@export var icon: Texture2D`
→ InventoryUI, HUD, CombatUI — три системы ожидают это поле.
**Fix**: Добавить поле в `item-database.md` ItemData resource definition.

---

### 🔴 C-08 [2c] DungeonGenerator: отсутствует `get_start_tile()`

`knockout-system.md` OQ-02: KnockoutSystem вызывает `DungeonGenerator.get_start_tile()`
→ `dungeon-generator.md` не экспортирует этот метод.
**Fix**: Добавить `get_start_tile() -> Vector2i` в `dungeon-generator.md` Public API.

---

### 🔴 C-09 [2c] TurnManager: отсутствует `steps_taken` и `add_step()`

`combat-system.md` OQ-03: читает `TurnManager.steps_taken` для Oracle `first_step_bonus`
`combat-system.md` Rule 9: вызывает `TurnManager.add_step(1)` для Swordsman
→ `turn-manager.md` не содержит ни поля `steps_taken`, ни метода `add_step()`.
**Fix**: Добавить оба в `turn-manager.md` State Fields и Public API.

---

### 🔴 C-10 [2e/2f] Максимум `attack_total`: 22 vs 23

`combat-system.md` Formulas: объявленный максимум = 22 (без Oracle first_step_bonus)
`combat-ui.md` EC-UI-13: корректно вычисляет 12 + 6 (оружие) + 3 (свитки) + 1 (HP) + 1 (Oracle) = 23
→ CombatSystem GDD занижает на 1, не учитывая Oracle.
**Fix**: Обновить максимум в `combat-system.md` до 23.

---

### 🔴 C-11 [2f+Scenario2] Warrior knockout + retreat: повреждение позиции

Порядок в CombatSystem Rule 10a: `take_damage(1)` → сигнал `knocked_out` → KnockoutSystem телепортирует Воина на `start_tile` → затем `retreat()` в CombatSystem переносит Воина обратно на `previous_position`.
→ KnockoutSystem телепортация Воина полностью отменяется следующим `retreat()`.
**Fix**: `combat-system.md` Rule 10a должен проверить `player.knockout_no_turn_skip` перед вызовом `retreat()`. Для Воина — пропустить `retreat()` (KnockoutSystem уже установил позицию).

---

## Game Design Issues — BLOCKING

### 🔴 D-01 [3d] ZOMBIE/MUMMY — сломана вся цепочка дропа scroll_magic_attack

(Дублирует C-05 — приоритет повышен: scroll_magic_attack является ключевым ресурсом Волшебника)
→ Без исправления: scroll_magic_attack фактически недостижим через бой.

---

### 🔴 D-02 [3d] scroll_fountain / scroll_teleport — неопределённый предмет

`loot-system.md`: дроп с Паука — `scroll_fountain`
`item-database.md`: этого предмета нет. Есть `scroll_teleport` (описан как телепорт к ближайшему фонтану)
`encounter-dispatcher.md`: scroll_teleport описан как телепорт к ближайшему **порталу** (не фонтану)
→ Три документа описывают разные механики. Неясно: scroll_fountain = scroll_teleport (переименовать)? Или это третий тип свитка?
**Fix**: Принять решение дизайнера. Наиболее вероятное: scroll_fountain → scroll_teleport, исправить LootSystem. Согласовать семантику (портал vs. фонтан) в EncounterDispatcher и ItemDatabase.

---

### 🔴 D-03 [3a/3g] Win condition рассинхронизирован

`game-concept.md` Elevator Pitch: «сражаетесь за право убить дракона первым»
`win-condition.md` Core Rules: победитель — тот у кого больше VP при убийстве Дракона. Убийца может проиграть.
→ Ребёнок открывает игру с нарративом «убей дракона первым», но может выиграть без боя с Драконом (7+ VP из сундуков) или проиграть после победы над Драконом.
**Fix**: Обновить `game-concept.md` — точно описать VP-победное условие. ИЛИ упростить WinCondition: убийца Дракона всегда побеждает (убрать VP-сравнение).

---

### 🔴 D-04 [3b] Когнитивный бюджет боя: 4 фазы решений против Pillar 3

CombatUI реализует: CHOICE_REROLL → выбор конкретного кубика → CHOICE_BONUSES (свитки) → трата HP. Для Воительницы/Чернокнижника: 6–8 микрорешений за один бой.
→ Прямо противоречит Pillar 3 «Просто войти» для аудитории 6+.
**Fix**: Рассмотреть упрощение для MVP: объединить CHOICE_REROLL и CHOICE_BONUSES в одну фазу; авто-применение где возможно. Это требует изменения в `combat-ui.md` и `combat-system.md`.

---

## Cross-System Scenario Issues — BLOCKING

### 🔴 S-01 [Scenario 1] Цепочка лута оружия полностью сломана

CombatSystem не эмитирует `item_dropped(player, monster_id)`. LootSystem его слушает для выдачи Кинжала, Меча, Топора. Без сигнала 5 из 7 монстров не дают лут.
(Дублирует C-04 — приоритет подтверждён scenario walkthrough)

---

### 🔴 S-02 [Scenarios 1,3] Игра не может завершиться

`PlayerState.vp` и `add_vp()` отсутствуют в GDD. WinCondition вызывает их при убийстве Дракона. Без них сигнал `game_over` не эмитируется. Игра не заканчивается.
(Дублирует C-03 — приоритет подтверждён)

---

### 🔴 S-03 [Scenario 5] EncounterDispatcher рисует новый токен при повторном входе

Если Игрок A проиграл бой и отступил (тайл `is_revealed=true`, `is_cleared=false`), Игрок B входит на тот же тайл → EncounterDispatcher вызывает `draw_event_token()` снова. Потребляется новый токен из пула, Игрок B может столкнуться с другим монстром чем видел Игрок A.
**Fix**: `encounter-dispatcher.md` нужно правило: при re-entry на `is_revealed=true, is_cleared=false` — использовать существующий `event_content_id` из `DungeonCell`, не рисовать новый токен.

---

## Warnings — Выборка ключевых

| ID | Источник | Описание |
|----|---------|---------|
| W-01 | 2a (×8) | MovementSystem не перечисляет LootSystem и TileRevealVFX как downstream; аналогичные асимметрии в TurnManager, KnockoutSystem, InventoryUI |
| W-02 | 2b | Фонтан вызывает `clear_cell()` → повторные визиты не работают (противоречит TileSystem EC-07) |
| W-03 | 2d | `DRAGON_VP`, `GHOST_VP`, `VP_CHEST` задублированы в 2–3 GDD без единого источника истины |
| W-04 | 3c | Разбойница может обходить Дракона — единственный класс без принудительного финала; нарушает Pillar 4 |
| W-05 | 3e | `auto_reroll_on_one`: ClassSystem «один раз», CombatSystem «до первого не-1» |
| W-06 | 3c | 12 Скелетов-ключников vs. 10 сундуков — 2 лишних ключа без применения |
| W-07 | 2c | InventoryUI ссылается на `turn_changed` — в TurnManager есть только `turn_started`/`turn_ended`/`turn_skipped` |
| W-08 | 4-S5 | Chest на неочищенном тайле: токен не сохраняется в cell data — второй игрок с ключом не видит сундук |
| W-09 | 2c | systems-index.md: ItemDatabase = "Not Started"; упоминает несуществующую "DeathRespawn" (это KnockoutSystem) |
| W-10 | 3b | Нет GDD/дизайна для UI замены предмета при полном инвентаре — критический момент выбора без дизайна |
| W-11 | 4-S4 | InventoryUI EC section содержит только `[To be designed]` — EC-INV-07 referenced но не documented |
| W-12 | 2d | SWAP_COST (Чернокнижник) объявлен и в ClassSystem и в MovementSystem — дублирование tuning knob |

---

## GDDs Flagged for Revision

| GDD | Причина | Тип | Приоритет |
|-----|---------|-----|-----------|
| `encounter-dispatcher.md` | C-01, C-02, S-03, W-02, W-08 | Consistency + Scenario | 🔴 Blocking |
| `player-state.md` | C-03, S-02 | Consistency | 🔴 Blocking |
| `combat-system.md` | C-04, C-10, C-11, S-01, D-04 | Consistency + Design | 🔴 Blocking |
| `loot-system.md` | C-05, D-01, D-02 | Consistency + Design | 🔴 Blocking |
| `tile-system.md` | C-06, C-02 | Consistency | 🔴 Blocking |
| `item-database.md` | C-07, D-02 | Consistency + Design | 🔴 Blocking |
| `dungeon-generator.md` | C-08 | Consistency | 🔴 Blocking |
| `turn-manager.md` | C-09, W-07 | Consistency | 🔴 Blocking |
| `game-concept.md` | D-03 | Design | 🔴 Blocking |
| `movement-system.md` | C-02, W-01 | Consistency | ⚠️ Warning |
| `inventory-ui.md` | W-07, W-11 (EC пустой) | Consistency | ⚠️ Warning |
| `systems-index.md` | W-09 (stale data) | Stale data | ⚠️ Warning |
| `class-system.md` | W-05 (auto_reroll_on_one) | Consistency | ⚠️ Warning |

---

## Required Actions Before Re-running Gate

1. **PlayerState GDD** — добавить: `vp: float`, `add_vp()`, `heal_full()`, `has_key`, `remove_key()`
2. **CombatSystem GDD** — добавить: `item_dropped`, `auto_reroll_triggered`, `player_choice_requested`; исправить max=23; fix Warrior retreat order
3. **EncounterDispatcher GDD** — исправить триггер, портальную механику, правило re-entry
4. **LootSystem GDD** — ZOMBIE→MUMMY; resolve scroll_fountain/scroll_teleport
5. **TileSystem GDD** — добавить 4 метода в API
6. **ItemDatabase GDD** — добавить `icon: Texture2D`
7. **DungeonGenerator GDD** — добавить `get_start_tile()`
8. **TurnManager GDD** — добавить `steps_taken`, `add_step()`, сигнал `turn_changed`
9. **game-concept.md** — исправить победное условие

После исправления всех 9 GDDs — повторить `/gate-check technical-setup`.

---

## Verdict: FAIL

**14 blocking issues** — все должны быть разрешены до начала архитектурной работы.

Дизайн механически здоров: пиллары представлены, progression loop чистый, все системы служат хотя бы одному пиллару. Проблемы — API контракты между системами, не сам дизайн.
