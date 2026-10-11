# Cross-GDD Review — Karak Digital

> **Date**: 2026-10-10
> **Verdict**: FAIL
> **Previous review**: design/gdd/gdd-cross-review-2026-10-09.md (FAIL → все 14 блокеров закрыты 2026-10-10)
> **GDDs reviewed**: 18
> **New blockers found**: 14
> **Warnings**: 18
> **Info**: 2

---

## Context

Все 14 блокеров предыдущего review (2026-10-09) закрыты в рамках retrofit-кампании
2026-10-10. Данный review проведён на обновлённом корпусе GDD и выявил новый набор
проблем — независимых от предыдущих.

Агенты: systems-designer (Phase 2 consistency), game-designer (Phase 3 holism + scenarios).

---

## BLOCKING Issues

### B-01 — game-concept.md vs WinCondition: победное условие не совпадает

**GDDs**: game-concept.md, WinCondition
**Severity**: BLOCKING

`game-concept.md` раздел Core Mechanics пункт 5 и Session-Level Loop говорят:
«первый игрок, убивший Дракона, выигрывает» / «гонка: кто первым убьёт дракона».

WinCondition GDD определяет другую механику: победитель — тот, у кого больше VP
после убийства Дракона; убийца Дракона может проиграть при меньшем VP.

**Fix**: Обновить game-concept.md Core Mechanics и Session-Level Loop:
«убийство Дракона завершает игру; победитель — игрок с наибольшим VP
(сундуки=1, Призрак=1, Дракон=1.5). При равных VP убийца Дракона побеждает.»

---

### B-02 — `key_dropped`: стейл-ссылка в LootSystem EC-05 и CombatSystem AC-16

**GDDs**: LootSystem, CombatSystem
**Severity**: BLOCKING

LootSystem EC-05: «CombatSystem эмитирует `key_dropped`, а не `item_dropped` для
SKELETON_KEY». Но CombatSystem не содержит сигнала `key_dropped` — Rule 9 эмитирует
`item_dropped(player, monster_id)` для всех исходов. LootSystem Rule 4 обрабатывает
SKELETON_KEY через `item_dropped` по `monster_id="SKELETON_KEY"`. CombatSystem AC-16
также ссылается на несуществующий `key_dropped`.

**Fix**: Удалить EC-05 из LootSystem (или переформулировать: «SKELETON_KEY
приходит через `item_dropped` как любой монстр»). Обновить CombatSystem AC-16:
заменить `key_dropped(player, pos)` на `item_dropped(player, monster_id)`.

---

### B-03 — `attack_bonus`: конфликт диапазонов ItemDatabase vs CombatSystem

**GDDs**: CombatSystem, ItemDatabase
**Severity**: BLOCKING

CombatSystem Formulas: переменная `attack_bonus` — только оружие, диапазон 0–6.
ItemDatabase Formula 1: «Σ `combat_bonus`» — 0–9 (2 оружия + 3 свитка).
ItemDatabase использует то же имя `attack_bonus` для обозначения суммарного боевого
вклада, что вводит в заблуждение: `PlayerState.get_attack_bonus()` — weapons-only.

**Fix**: В ItemDatabase Formula 1 переименовать строку в `Σ effective_combat_bonus`
и уточнить: «включает оружие + свитки; ≠ `PlayerState.get_attack_bonus()`
(только оружие)».

---

### B-04 — `tile_reveal_complete`: сигнатура не совпадает

**GDDs**: TileRevealVFX, EncounterDispatcher
**Severity**: BLOCKING

TileRevealVFX эмитирует `tile_reveal_complete(pos: Vector2i)` — без аргумента `player`.
EncounterDispatcher Overview и Dependencies upstream ссылаются на
`tile_reveal_complete(player, pos)` — с аргументом `player`.

**Fix**: Выбрать одну сигнатуру и синхронизировать оба GDD. Рекомендация:
`tile_reveal_complete(pos: Vector2i)` — EncounterDispatcher получает `player`
из `TurnManager.get_active_player()`.

---

### B-05 — `burn_steps()`: направление вызова описано неверно в TurnManager

**GDDs**: TurnManager, EncounterDispatcher
**Severity**: BLOCKING

TurnManager Interactions: «EncounterDispatcher | ← слушает | `burn_steps()` (фонтан)» —
подразумевает, что TurnManager слушает сигнал `burn_steps()` от EncounterDispatcher.

EncounterDispatcher Rule 5: «`TurnManager.burn_steps()`» — это **прямой вызов метода**
на TurnManager, а не сигнал.

**Fix**: Обновить TurnManager Interactions: «EncounterDispatcher | → вызывает |
`burn_steps()` (метод, при посещении FOUNTAIN)». Убрать стрелку-«слушает».

---

### B-06 — `add_item(item_id)` / `set_key(true)`: несуществующие API PlayerState

**GDDs**: LootSystem, PlayerState
**Severity**: BLOCKING

LootSystem Core Rules Rule 4 и Interactions вызывают `PlayerState.add_item(item_id)`.
PlayerState Public API не содержит `add_item()` — есть `add_weapon(item: ItemData)`,
`set_key(item: ItemData)`, `add_scroll(item: ItemData)`.

LootSystem также использует `set_key(true)` — неверная сигнатура (принимает `ItemData`,
а не `bool`).

**Fix**: В LootSystem заменить `add_item(item_id)` на соответствующий метод по
`item.item_type`: `add_weapon(item)` / `set_key(item)` / `add_scroll(item)`.
Заменить `set_key(true)` → `set_key(item)`.

---

### B-07 — InventoryUI не в downstream TurnManager

**GDDs**: InventoryUI, TurnManager
**Severity**: BLOCKING

InventoryUI Dependencies: подписан на `TurnManager.turn_changed` для автозакрытия.
TurnManager Interactions downstream: `turn_changed(from_player, to_player)` упомянут
только для HUD. InventoryUI отсутствует как получатель.

**Fix**: Добавить в TurnManager Interactions downstream: «InventoryUI | `turn_changed`
— автозакрытие панели».

---

### B-08 — InventoryUI не в downstream CombatSystem

**GDDs**: InventoryUI, CombatSystem
**Severity**: BLOCKING

InventoryUI EC-INV-01: подписан на `CombatSystem.combat_started` для принудительного
закрытия. CombatSystem downstream (зависят от): CombatUI, LootSystem, WinCondition —
InventoryUI отсутствует.

**Fix**: Добавить в CombatSystem downstream: «InventoryUI | `combat_started` —
закрытие панели инвентаря».

---

### B-09 — MovementSystem: устаревший downstream

**GDDs**: MovementSystem, TileRevealVFX, EncounterDispatcher
**Severity**: BLOCKING

MovementSystem Interactions: «EncounterDispatcher ← слушает `cell_entered(player, pos)`»
— устаревшая информация. После retrofit TileRevealVFX является единственным
потребителем `cell_entered`; EncounterDispatcher получает `tile_reveal_complete`
от TileRevealVFX, а не `cell_entered` напрямую.

Программист, читающий MovementSystem, подключит EncounterDispatcher к `cell_entered`
напрямую — TileRevealVFX flip не запустится, Pillar 1 нарушен.

**Fix**: В MovementSystem Interactions заменить строку EncounterDispatcher на:
«TileRevealVFX | ← слушает | `cell_entered(player, pos)`».
Добавить примечание: «EncounterDispatcher получает `tile_reveal_complete` от TileRevealVFX».

---

### B-10 — Retreat / нокаут: порядок операций противоречит

**GDDs**: CombatSystem, PlayerState
**Severity**: BLOCKING

CombatSystem Rule 10a (шаг 2): при `is_knocked_out() == true` — пропустить `retreat()`.
KnockoutSystem при нокауте Воина сразу вызывает `clear_knockout()` → `is_knocked_out()`
вернёт `false` когда CombatSystem проверит — и CombatSystem вызовет `retreat()` поверх
позиции, уже установленной KnockoutSystem.

PlayerState EC-06: «порядок — сначала `take_damage(1)`, потом `retreat()`» — без
условия на нокаут.

**Fix**: Исправить PlayerState EC-06: добавить условие «если нокаут —
`retreat()` пропускается (CombatSystem Rule 10a)». Уточнить в KnockoutSystem:
`clear_knockout()` должен вызываться TurnManager, а не KnockoutSystem немедленно —
чтобы CombatSystem видел `is_knocked_out() == true` при проверке.

---

### B-11 — VP-экономика монстров: OQ-03 не закрыт

**GDDs**: WinCondition, MonsterDatabase, TileSystem
**Severity**: BLOCKING

MonsterDatabase AC-06: только Призрак и Дракон имеют `vp_on_kill > 0`. Все остальные
монстры (Крыса, Паук, Мумия, Скелет-воин, Ключник) VP не дают.

TileSystem OQ-03 ставит этот вопрос как открытый. Результат: убийство 90% монстров
за партию не даёт VP — противоречит Core Fantasy «убивать монстров → становиться
сильнее». VP сосредоточены только в сундуках (нужен ключ) + 2 Призрака + Дракон.

**Fix**: Закрыть TileSystem OQ-03 как явное дизайн-решение. Либо:
(a) подтвердить «только сундуки+Призраки+Дракон» и задокументировать,
(b) добавить VP за Короля скелетов и strong-tier монстров. Любой ответ приемлем —
неопределённость неприемлема.

---

### B-12 — `item_acquired`: сигнал ожидается TurnManager, отсутствует в LootSystem

**GDDs**: LootSystem, TurnManager
**Severity**: BLOCKING

TurnManager Rule 4: «LootSystem испускает `item_acquired` → конец хода» — один из
триггеров завершения хода. LootSystem GDD не содержит сигнал `item_acquired` нигде:
ни в States, ни в Interactions, ни в Acceptance Criteria.

Результат: после получения предмета TurnManager не получит триггер для завершения
хода — ход зависнет.

**Fix**: Добавить `item_acquired(player: PlayerState, item: ItemData)` в LootSystem:
в Signals, States/Transitions (эмитируется после успешного `add_weapon/add_scroll/set_key`),
Interactions downstream, Acceptance Criteria. Закрыть TurnManager OQ-01.

---

### B-13 — `TurnManager.end_turn()`: прямой вызов из CombatSystem, метода нет в API

**GDDs**: CombatSystem, TurnManager
**Severity**: BLOCKING

CombatSystem Rule 9: «Иначе: `TurnManager.end_turn()`». TurnManager Public API не
содержит `end_turn()` — ход завершается через сигналы (`combat_resolved`,
`steps_remaining == 0` и т.д.).

**Fix**: Удалить `TurnManager.end_turn()` из CombatSystem Rule 9. Ход завершается
автоматически когда TurnManager получает `combat_resolved` с `won=false` или иным
финальным состоянием. CombatSystem только эмитирует `combat_resolved`.

---

### B-14 — `reveal_cell()`: кто вызывает — не определено

**GDDs**: MovementSystem, TileSystem, TileRevealVFX
**Severity**: BLOCKING

MovementSystem Rule 2 шаг 4: «`TileSystem.reveal_cell(pos)`» — MovementSystem вызывает
его во время движения, до `cell_entered`. Но TileRevealVFX Core Rule 2 проверяет
`TileSystem.is_revealed(pos) == false` перед запуском анимации. Если MovementSystem
уже вызвал `reveal_cell()` до `cell_entered` — TileRevealVFX увидит `is_revealed == true`
и **пропустит flip-анимацию** при первом посещении. Pillar 1 нарушен.

**Fix**: Определить явный порядок:
1. MovementSystem эмитирует `cell_entered` **без** вызова `reveal_cell()`
2. TileRevealVFX запускает анимацию, и **по завершении** вызывает `TileSystem.reveal_cell(pos)`
3. Только после этого эмитирует `tile_reveal_complete`

Обновить MovementSystem Rule 2 и TileSystem States/Transitions: «HIDDEN→REVEALED
вызывается TileRevealVFX после завершения flip-анимации».

---

## WARNING Issues

| # | GDDs | Тип | Описание |
|---|------|-----|----------|
| W-01 | KnockoutSystem, CombatSystem | Rule contradiction | `is_knocked_out()` возвращает false после `clear_knockout()` — retreat() вызывается для Воина (см. B-10, доп. аспект) |
| W-02 | WinCondition, game-concept.md | Stale OQ | TileSystem OQ-02 помечен как требующий fix — game-concept retrofit сделан, но OQ не закрыт |
| W-03 | MovementSystem, TileRevealVFX | Bidirectionality | TileRevealVFX ожидает упоминания в MovementSystem как потребителя `cell_entered` — не сделано (закрывается B-09) |
| W-04 | ClassSystem, CombatSystem | Ownership | `WARLOCK_HP_COST` только в CombatSystem, отсутствует в ClassSystem Tuning Knobs |
| W-05 | DiceSystem, CombatSystem | Rule contradiction | Мечник авто-перебросок: DiceSystem EC-03 — «один раз»; CombatSystem EC-02 — «loop until non-1». Авторитетен CombatSystem. |
| W-06 | DiceSystem | Stale OQ | OQ-01 / EC-04 (Воин перебросок: добровольный или обязательный) — provisional, но решён в CombatSystem EC-01. Закрыть. |
| W-07 | WinCondition | Stale OQ | OQ-01 (`dragon_killed` сигнал) — «требует retrofit CombatSystem» — уже сделано. Закрыть. |
| W-08 | TileSystem, EncounterDispatcher | Missing API | `is_revealed()`, `is_cleared()`, `event_content_id` — не добавлены в EncounterDispatcher-строку таблицы downstream TileSystem |
| W-09 | DungeonGenerator, TileSystem | AC contradiction | AC-01 говорит `pool.size() == 80`; AC-06 подразумевает 79 (FOUNTAIN вынут). Одно из AC ошибочно. |
| W-10 | ClassSystem, EncounterDispatcher | Stale OQ | ClassSystem OQ-04 (Оракул — из какого пула 2 токена) — уже решён в EncounterDispatcher EC-02. Закрыть. |
| W-11 | PlayerState | Stale OQ | OQ-03 и OQ-04 — уже отражены в game-concept.md retrofit. Закрыть. |
| W-12 | WinCondition, HUD | Design gap | HUD не отображает VP — критичная информация для решения «идти на Дракона сейчас?» Нарушает Pillar 4. |
| W-13 | ClassSystem, MovementSystem | Design gap | Разбойница может bypass Дракона (ClassSystem EC-06). Потенциально доминантная стратегия / затяжная партия. Явное дизайн-решение отсутствует. |
| W-14 | DiceSystem, CombatSystem | Design gap | Без снаряжения P(win) vs Ключник = 42% (difficulty=8). Ключник — 23% пула. Ранний опыт может быть фрустрирующим для ребёнка. |
| W-15 | LootSystem, TurnManager | Incomplete spec | TurnManager OQ-02: что происходит если инвентарь полон при открытии сундука — не решено. |
| W-16 | LootSystem | Design gap | TileSystem OQ-04: даёт ли сундук кроме VP ещё и предмет? Явного ответа в LootSystem нет. |
| W-17 | EncounterDispatcher, LootSystem | Implicit ordering | `remove_key()` вызывается EncounterDispatcher до `loot_started` — неявный порядок, не задокументирован |
| W-18 | MovementSystem | Incomplete spec | Bypass Разбойницы: тайл нераскрыт — раскрывается ли? `cell_entered` не эмитируется при bypass, TileRevealVFX не запускается. |

---

## INFO Issues

| # | GDDs | Описание |
|---|------|----------|
| I-01 | EncounterDispatcher, LootSystem | `remove_key()` вызывается EncounterDispatcher напрямую, а не через LootSystem — нарушает принцип «LootSystem управляет лутом». Технически согласовано, но потенциальный источник ошибок. |
| I-02 | ClassSystem, PlayerState | `player_id` range 1–5 при 2-player MVP. Нормально для масштабирования, но MVP-реализация должна документировать assert `player_count == 2`. |

---

## Scenario Walkthroughs

### Scenario 1: Убийство Skeleton Warrior

**Chain**: MovementSystem → TileRevealVFX → EncounterDispatcher → CombatSystem →
LootSystem → PlayerState → InventoryUI / HUD

Структурно верна. **Разрыв**: LootSystem не эмитирует `item_acquired` → TurnManager
не завершит ход (B-12). Если B-09 не исправлен — EncounterDispatcher подключится к
`cell_entered` напрямую, flip не запустится.

### Scenario 2: Открытие сундука с ключом

**Chain**: MovementSystem → TileRevealVFX → EncounterDispatcher → LootSystem →
PlayerState → HUD / WinCondition

Два разрыва: (a) `item_acquired` отсутствует — ход не завершается (B-12);
(b) HUD не отображает VP (W-12) — игрок не видит прогресс к победе, нарушает
Pillar 2 и Pillar 4.

### Scenario 3: Нокаут игрока

**Chain**: CombatSystem → PlayerState → KnockoutSystem → TurnManager

Работает для Воина. Для остальных классов: если нокаут без retreat — игрок
остаётся на тайле монстра; при следующем ходе EncounterDispatcher снова запустит
бой (re-entry). Намеренно ли это — не задокументировано. Также: retreat/нокаут
порядок противоречит (B-10).

---

## Pillar Alignment

| Система | P1 | P2 | P3 | P4 | Проблема |
|---------|----|----|----|----|---------|
| TileSystem | ✓ | — | — | ✓ | — |
| DungeonGenerator | ✓ | — | — | — | — |
| CombatSystem | — | ✓ | ✓ (D-04) | ✓ | B-13 end_turn |
| LootSystem | ✓ | ✓ | — | — | B-12 item_acquired |
| WinCondition | — | ✓ | — | ✓ | B-01 game-concept, W-12 VP в HUD |
| ClassSystem | — | ✓ | — | — | W-13 Разбойница bypass |
| MovementSystem | ✓ | — | — | ✓ | B-09 stale downstream, B-14 reveal_cell |
| TileRevealVFX | ✓ | — | — | — | B-04 signature, B-14 ordering |
| EncounterDispatcher | ✓ | — | — | — | B-04, B-05 |
| HUD | — | ✓ | ✓ | ✓ | W-12 VP отсутствует |

---

## Dominant Strategy Analysis

1. **«2 топора → Дракон»**: Убить Короля скелетов дважды → `attack_bonus=6` →
   победа над Драконом при броске ≥9. Мягкая dominant strategy (Королей только 3 в пуле).

2. **«Разбойница-черепаха»**: Bypass монстров, собирать ключи и VP, убить Дракона
   последним — при гарантированном VP-преимуществе. Может затягивать партию. (W-13)

3. **«Волшебник + 3 свитка»**: 3 постоянных +1 = `scroll_bonus=3`. С топором:
   эффективный `attack_total` до 19 → победа над Драконом при броске ≥4.

---

## Required Fixes Before Next Gate

### Критические (BLOCKING — нужны для корректной работы core loop):

| ID | Fix | GDDs |
|----|-----|------|
| B-01 | Обновить game-concept.md — VP vs «убить первым» | game-concept.md |
| B-02 | Удалить `key_dropped` из LootSystem EC-05 + CombatSystem AC-16 | LootSystem, CombatSystem |
| B-03 | Переименовать `Σ combat_bonus` → `Σ effective_combat_bonus` в ItemDatabase | ItemDatabase |
| B-04 | Согласовать сигнатуру `tile_reveal_complete` | TileRevealVFX, EncounterDispatcher |
| B-05 | Исправить направление `burn_steps()` в TurnManager Interactions | TurnManager |
| B-06 | Заменить `add_item()` / `set_key(true)` на правильные методы PlayerState | LootSystem |
| B-07 | Добавить InventoryUI в downstream TurnManager | TurnManager |
| B-08 | Добавить InventoryUI в downstream CombatSystem | CombatSystem |
| B-09 | Обновить MovementSystem Interactions downstream | MovementSystem |
| B-10 | Синхронизировать retreat/нокаут порядок CombatSystem + PlayerState + KnockoutSystem | CombatSystem, PlayerState, KnockoutSystem |
| B-11 | Закрыть TileSystem OQ-03 (VP за обычных монстров) | MonsterDatabase, WinCondition, TileSystem |
| B-12 | Добавить `item_acquired` в LootSystem | LootSystem, TurnManager |
| B-13 | Удалить `TurnManager.end_turn()` из CombatSystem | CombatSystem |
| B-14 | Определить кто вызывает `reveal_cell()` и в какой момент | MovementSystem, TileSystem, TileRevealVFX |

### Рекомендуемые (WARNING):

- W-05: DiceSystem EC-03 — loop until non-1 для Мечника
- W-06, W-07, W-10, W-11, W-02: закрыть стейл Open Questions
- W-08: добавить `is_revealed()`, `is_cleared()` в EncounterDispatcher-строку TileSystem
- W-09: исправить AC-01 vs AC-06 в DungeonGenerator (pool size 79 vs 80)
- W-12: VP в HUD — добавить счётчик VP для каждого игрока
- W-13: задокументировать осознанное решение про bypass Дракона Разбойницей

---

## Progress Tracker

| Метрика | Значение |
|---------|----------|
| GDDs проверено | 18 / 18 |
| Blocking issues | 14 |
| Warning issues | 18 |
| Info issues | 2 |
| Verdict | **FAIL** |
| Предыдущий review | 2026-10-09 FAIL → все 14 блокеров закрыты 2026-10-10 |
| Следующий шаг | `/design-system retrofit` для каждого GDD из Required Fixes |
