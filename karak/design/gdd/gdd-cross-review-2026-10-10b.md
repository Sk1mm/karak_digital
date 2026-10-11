# Cross-GDD Review Report

**Date**: 2026-10-10 (третий прогон)
**GDDs Reviewed**: 18 системных + game-concept.md + systems-index.md
**Verdict**: **FAIL**
**Blocking**: 12 | **Warning**: 20 | **Info**: 3

Entity registry: отсутствует.
Game-pillars.md: отсутствует (пиллары в game-concept.md).

Системы: DiceSystem, ClassSystem, PlayerState, TurnManager, MovementSystem, TileSystem, TileRevealVFX, EncounterDispatcher, CombatSystem, LootSystem, WinCondition, KnockoutSystem, DungeonGenerator, MonsterDatabase, ItemDatabase, HUD, CombatUI, InventoryUI

---

## Consistency Issues — BLOCKING (9)

### C-01 — Двойное начисление VP за Дракона

**GDD**: CombatSystem (Rule 9), WinCondition, MonsterDatabase
**Severity**: BLOCKING

CombatSystem Rule 9: `PlayerState.add_vp(monster_data.vp_on_kill)` — для Дракона = 1.5 VP.
Затем эмитирует `dragon_killed(player)` → WinCondition также вызывает `player.add_vp(1.5)`.
Итого Дракон даёт **3.0 VP** вместо 1.5. При VP-лимите 6 это критически меняет баланс.

**Fix**: CombatSystem Rule 9 — пропустить `add_vp` если `monster_data.is_dragon == true`.
Только WinCondition начисляет VP за Дракона. Обновить: CombatSystem Rule 9 + AC-01.

---

### C-02 — Условие победы: `>` (CombatSystem) vs `>=` (MonsterDatabase)

**GDD**: CombatSystem (Rule 8), MonsterDatabase (Формула 1)
**Severity**: BLOCKING

CombatSystem Rule 8: `attack_total > difficulty` = WIN; `attack_total == difficulty` = DRAW (не Разбойница).
MonsterDatabase Формула 1: `player_wins = attack_total >= difficulty`. Прямое противоречие при ничье.

**Fix**: MonsterDatabase Формула 1 → `player_wins = attack_total > difficulty`.
Добавить примечание о Разбойнице (`wins_on_draw`).

---

### C-03 — Bypass Воительницы: 1 шаг (ClassSystem) vs 2 шага (MovementSystem)

**GDD**: ClassSystem (Формула 3), MovementSystem (Rule 9, TK)
**Severity**: BLOCKING

ClassSystem Формула 3: `bypass_cost = 1 step + 1 HP`.
MovementSystem Rule 9: `2 шага + 1 HP`; `steps_remaining >= 2`.

**Fix**: ClassSystem Формула 3 → `bypass_cost = 2 steps + 1 HP`.

---

### C-04 — Фонтан: шаги сгорают всегда (TileSystem) vs по выбору (EncounterDispatcher)

**GDD**: TileSystem (EC-06, EC-07), EncounterDispatcher (Rule 5)
**Severity**: BLOCKING

TileSystem EC-06/07: шаги сгорают при посещении фонтана всегда, даже при полном HP.
EncounterDispatcher Rule 5: предлагает выбор «да/нет»; при «нет» — «ничего не происходит, ход продолжается».
Если шаги всегда сгорают — зачем выбор? Правила несовместимы.

**Fix**: TileSystem EC-06/07 — шаги сгорают только при выборе «да». При «нет» — ход продолжается без потери шагов. EncounterDispatcher — авторитетный источник.

---

### C-05 — TurnManager: AC-09 противоречит Rule 5 (clear_knockout для Воина)

**GDD**: TurnManager (внутреннее)
**Severity**: BLOCKING

Rule 5: `knockout_no_turn_skip AND is_knocked_out()` → вызвать `clear_knockout()`, дать ход нормально.
AC-09: «player_1 Воин, is_knocked_out() == true → player_1 ходит нормально, `clear_knockout()` **не вызван**».
Прямое внутреннее противоречие.

**Fix**: AC-09 → `clear_knockout()` ВЫЗВАН, `turn_skipped` не испущен.

---

### C-06 — CombatSystem EC-08 ссылается на несуществующий `end_turn()`

**GDD**: CombatSystem (EC-08), TurnManager
**Severity**: BLOCKING

EC-08: «Только `retreat()` + `end_turn()`». TurnManager не имеет метода `end_turn()`.
Ход завершается через сигнал `combat_resolved(false, false)`.

**Fix**: CombatSystem EC-08 → заменить `end_turn()` на `emit_signal("combat_resolved", false, false)`.

---

### C-07 — EncounterDispatcher: `is_revealed()` всегда true при получении `tile_reveal_complete`

**GDD**: EncounterDispatcher (Rule 4), TileRevealVFX (Rule 5), TileSystem
**Severity**: BLOCKING

TileRevealVFX Rule 5 вызывает `reveal_cell(pos)` **перед** `tile_reveal_complete`. К моменту получения
сигнала EncounterDispatcher'ом тайл уже REVEALED. Проверка `is_revealed == false` из EncounterDispatcher
Rule 4 никогда не выполнится → `draw_event_token()` не вызывается → встречи не происходят.

**Fix**: EncounterDispatcher Rule 4 — заменить проверку `is_revealed(pos) == false` на
`is_cleared(pos) == false` для определения первого визита.

---

### C-08 — Кто вызывает draw_event_token: `reveal_cell()` (TileSystem AC-06) или EncounterDispatcher?

**GDD**: TileSystem (AC-06), EncounterDispatcher (Rule 4)
**Severity**: BLOCKING

TileSystem AC-06 подразумевает, что `reveal_cell()` автоматически тянет event_token для ROOM-ячейки.
EncounterDispatcher Rule 4 явно вызывает `draw_event_token()` отдельно. Двойной вызов = двойной расход
токенов из пула.

**Fix**: TileSystem AC-06 — убрать draw_event_token из `reveal_cell()`. EncounterDispatcher — единственный
вызывающий `draw_event_token()`.

---

### C-09 — `combat_resolved` сигнатура: `String` (CombatUI) vs `(bool, bool)` (CombatSystem)

**GDD**: CombatUI (Rule 9), CombatSystem (Interactions, AC-02/03/08/09)
**Severity**: BLOCKING

CombatUI Rule 9 ожидает `combat_resolved(result: String)` — значения `"WIN"`, `"DRAW"`, `"LOSS"`.
CombatSystem эмитирует `combat_resolved(won: bool, six_rolled: bool)`. CombatUI не может корректно
подписаться на этот сигнал.

**Fix**: CombatUI Rule 9 — подписаться на `(won: bool, six_rolled: bool)`;
конвертировать в строку локально для отображения.

---

## Consistency Issues — WARNING (14)

| # | GDD | Описание | Предложение |
|---|-----|---------|-------------|
| W-01 | systems-index.md, EncounterDispatcher | EncounterDispatcher зависимости в индексе неполны: пропущены TileRevealVFX и TurnManager | Обновить systems-index.md |
| W-02 | MonsterDatabase, LootSystem | Поле `drops_key` в MonsterData больше не читается LootSystem (заменено `item_dropped` + drop table) | Убрать `drops_key` или пометить deprecated |
| W-03 | LootSystem | ItemDatabase отсутствует в upstream Dependencies, хотя Rule 4 вызывает `ItemDatabase.get_item()` | Добавить ItemDatabase в upstream LootSystem |
| W-04 | TileSystem | OQ-04 («содержимое сундука») не закрыт — ответ: только 1 VP | Закрыть OQ-04 как RESOLVED |
| W-05 | PlayerState | Формула 2: `dice_roll: int, 1–6` (1d6) — бросок 2d6 (диапазон 2–12) в CombatSystem | Обновить или убрать Формулу 2 из PlayerState |
| W-06 | MovementSystem, EncounterDispatcher | Проверка `steps_remaining >= 1` для портала: ПОСЛЕ или ДО `spend_step()` входа? | Уточнить в EncounterDispatcher Rule 6 |
| W-07 | EncounterDispatcher | `get_tile(pos)` → TileSystem Public API называет метод `get_cell(pos)` | Заменить get_tile → get_cell |
| W-08 | LootSystem, MonsterDatabase, CombatSystem | Несоответствие регистра monster_id: LootSystem/CombatSystem UPPERCASE, MonsterDatabase lowercase `&"rat"` | Привести LootSystem и CombatSystem AC к lowercase |
| W-09 | KnockoutSystem | Overview: «CombatSystem уже отступил игрока» — устарело после B-10 (retreat() пропускается) | Обновить Overview |
| W-10 | TileSystem, LootSystem, WinCondition | VP за сундук определён в трёх GDD: `CHEST_VP`, `VP_PER_CHEST`, `VP_CHEST` | LootSystem — владелец; остальные ссылаются на него |
| W-11 | PlayerState, ItemDatabase | WEAPON_SLOTS дублирован в двух GDD | PlayerState — владелец |
| W-12 | ItemDatabase, CombatSystem | ItemDatabase макс attack_total = 21, CombatSystem = 23 (не учтены hp_bonus и first_step_bonus) | Уточнить что ItemDatabase описывает только item-диапазон |
| W-13 | CombatSystem | AC-01: `combat_resolved(WIN)` — строковый формат вместо `combat_resolved(true, false)` | Исправить AC-01 |
| W-14 | game-concept.md, TurnManager | game-concept.md MVP: «hotseat 2–5P»; все системы спроектированы под 2 | Обновить game-concept.md MVP → «hotseat 2P» |

---

## Design Theory Issues — BLOCKING (3)

### D-01 — TurnManager не ждёт лут после победы в бою

**GDD**: TurnManager, CombatSystem, LootSystem
**Severity**: BLOCKING

`combat_resolved(won=true)` → TurnManager сразу переходит в «конец хода» (states таблица: `AWAITING_COMBAT → конец хода`). Но LootSystem ещё обрабатывает `item_dropped`: если слоты заняты и нужна замена предмета — игрок не может принять решение, ход уже сменился.

**Fix**: Добавить явный переход `AWAITING_COMBAT → AWAITING_LOOT` при `combat_resolved(won=true)`.
Ход завершается при `item_acquired` (уже существует). При `won=false` — ход завершается при `combat_resolved`.
Обновить TurnManager States + AC.

---

### D-02 — Двойное начисление VP за Дракона (Design Theory)

*(см. C-01 — то же противоречие, найдено в сценарном обходе Scenario 2)*

---

### D-03 — Дракон/Призрак могут быть первым event-токеном → невыигрываемый бой

**GDD**: DungeonGenerator, TileSystem, EncounterDispatcher
**Severity**: BLOCKING

Нет protection zone для токенов. Призрак (difficulty 12) или Дракон (15) на первом событии —
игрок без снаряжения гарантированно проигрывает. Нарушает Pillar 4 («Честная случайность»).

**Fix (требует решения)**:
- Опция A: задокументировать как intentional design (верность оригинальному Karak) + явный AC в DungeonGenerator
- Опция B: запрет Дракона/Призрака в первых N событиях

---

## Design Theory Issues — WARNING (6)

| # | GDD | Описание |
|---|-----|---------|
| D-W-01 | ClassSystem, KnockoutSystem | Воин: нокаут = телепорт на старт + полный хил + нет пропуска хода. Остальные: 1 HP + пропуск хода. Разрыв в наказании огромен. |
| D-W-02 | ClassSystem, ItemDatabase, CombatSystem | Волшебник + 3 свитка MAGIC_ATTACK = вечные +3 в каждом бою → тривиализирует Дракона (+6 оружие + +3 свитки + dice 6+ = 15 guaranteed) |
| D-W-03 | TileSystem, EncounterDispatcher | Фонтаны: бесконечное лечение без ресурсного стока → безрисковый farming-паттерн |
| D-W-04 | WinCondition, game-concept | Нет catch-up механики по VP — лидер может убить Дракона, чтобы зафиксировать победу |
| D-W-05 | CombatSystem, TurnManager, LootSystem | Порядок `add_step(1)` vs синхронный `item_dropped` для Мечника — неопределён |
| D-W-06 | EncounterDispatcher, LootSystem | `remove_key()` вызывается ДО `loot_started` → ключ исчезает из HUD до анимации открытия сундука |

---

## Design Theory Issues — INFO (3)

| # | GDD | Описание |
|---|-----|---------|
| D-I-01 | game-concept, LootSystem | Snowball: больше снаряжения → сильнее → ещё лучшее снаряжение; без catch-up → нединамичные партии |
| D-I-02 | EncounterDispatcher, LootSystem | remove_key() визуальный порядок: ключ пропадает до VP |
| D-I-03 | ClassSystem, CombatSystem | Мечник: теоретически бесконечный ход при цепочке побед с 6 |

---

## Cross-System Scenario Issues

Scenarios walked: 5

### BLOCKING

**Scenario 1 (вход → монстр → бой → лут)** — CombatSystem, TurnManager, LootSystem  
`combat_resolved(won=true)` → TurnManager завершает ход до обработки замены предмета. (→ D-01)

**Scenario 2 (победа над Драконом)** — CombatSystem, WinCondition  
Двойное начисление VP: 1.5 (CombatSystem) + 1.5 (WinCondition) = 3.0. (→ C-01)

### WARNING

**Scenario 5 (Мечник, шестёрка)** — CombatSystem, TurnManager, LootSystem  
`add_step(1)` вызывается до `combat_resolved`, но `item_dropped` обрабатывается синхронно — порядок зависит от очерёдности подписки на сигнал в Godot.

### INFO

**Scenario 3 (нокаут Воина)** — CombatSystem, KnockoutSystem, TurnManager  
Цепочка корректна после ретрофита B-10. Документирована полностью.

**Scenario 4 (сундук с ключом)** — EncounterDispatcher, LootSystem  
`remove_key()` до `loot_started` → ключ пропадает из HUD до анимации. Визуальный порядок не оптимален.

---

## GDDs Flagged for Revision

| GDD | Причина | Тип | Приоритет |
|-----|---------|-----|-----------|
| combat-system.md | C-01, C-06, C-09, W-13 | Consistency | Blocking |
| win-condition.md | C-01 | Consistency | Blocking |
| turn-manager.md | C-05, D-01 | Consistency + Design | Blocking |
| encounter-dispatcher.md | C-07, W-07 | Consistency | Blocking |
| tile-system.md | C-04, C-08, W-04 | Consistency | Blocking |
| monster-database.md | C-02, W-02 | Consistency | Blocking |
| class-system.md | C-03, D-W-01 | Consistency + Design | Blocking |
| combat-ui.md | C-09 | Consistency | Blocking |
| dungeon-generator.md | D-03 | Design | Blocking |
| movement-system.md | C-03 | Consistency | Blocking |
| loot-system.md | W-03, D-01 | Consistency + Design | Warning |
| knockout-system.md | W-09 | Consistency | Warning |
| player-state.md | W-05 | Consistency | Warning |
| item-database.md | W-12 | Consistency | Warning |

---

## Verdict: FAIL

**12 blocking issues** (9 consistency + 3 design).

**Требуемые действия перед следующим `/review-all-gdds`:**

1. **C-01** — Убрать `add_vp(vp_on_kill)` из CombatSystem при `is_dragon == true`
2. **C-02** — Исправить MonsterDatabase Формулу 1: `>=` → `>`
3. **C-03** — Исправить ClassSystem Формулу 3: 1 шаг → 2 шага для Воительницы
4. **C-04** — Исправить TileSystem EC-06/07: шаги сгорают только при «да»
5. **C-05** — Исправить TurnManager AC-09: clear_knockout() ВЫЗВАН
6. **C-06** — Исправить CombatSystem EC-08: end_turn() → combat_resolved(false, false)
7. **C-07** — Исправить EncounterDispatcher Rule 4: is_revealed → is_cleared
8. **C-08** — Исправить TileSystem AC-06: убрать auto draw_event_token из reveal_cell()
9. **C-09** — Исправить CombatUI Rule 9: String → (bool, bool)
10. **D-01** — Добавить AWAITING_COMBAT → AWAITING_LOOT переход в TurnManager при won=true
11. **D-02** — см. C-01
12. **D-03** — Принять решение: intentional или protection zone
