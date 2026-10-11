# Cross-GDD Review Report — 9th Run
**Date**: 2026-10-10  
**Verdict**: **FAIL** — 3 blocking issues (J-01..J-03)  
**GDDs Reviewed**: 18  
**Systems Covered**: DiceSystem, ItemDatabase, MonsterDatabase, PlayerState, ClassSystem, TurnManager, MovementSystem, EncounterDispatcher, CombatSystem, LootSystem, KnockoutSystem, WinCondition, DungeonGenerator, HUD, CombatUI, InventoryUI, TileRevealVFX, systems-index

---

## Verification: Retrofit #8 (I-01..I-06)

| Issue | Fix | Status |
|-------|-----|--------|
| I-01 | TurnManager слушает `game_over(winner)` от WinCondition; `signal won` удалён | ✓ PASS |
| I-02 | PlayerState outgoing HUD row: добавлен `vp_changed` | ✓ PASS |
| I-03 | TurnManager AC-05: `steps_remaining == 3 (2 + 1 от add_step)` | ✓ PASS |
| I-04 | EncounterDispatcher: `get_cell` вместо `get_tile` | ✓ PASS |
| I-05 | ItemDatabase `MIN_COMBAT_BONUS_FOR_DRAGON = 4` | ✓ PASS |
| I-06 | LootSystem/CombatSystem: monster_id lowercase `&"..."` в таблицах и AC | ✓ PASS |

---

## Phase 2: Consistency Issues

### BLOCKING

**J-01 — ItemDatabase: hp_bonus Чернокнижника указан как +4 (должно быть +1)**  
`item-database.md` Formulas, note (строки 89–92):  
> "attack_total с классовыми бонусами (Чернокнижник spend_hp **+4**, Оракул first_step +1) может достигать 23"

`combat-system.md` Rule 6: "потратить 1 HP для **+1** к броску". CombatUI `hp_already_spent` флаг (AC-CUI-26) подтверждает: одна трата на бой, max hp_bonus = 1.  
Практический максимум `attack_total` для любого класса = **22** (hp_bonus и first_step_bonus не суммируются — разные классы). Теоретический максимум 23 при одновременном +1 HP + +1 first_step тоже недостижим.

**Что поменять**: ItemDatabase Formulas note → `"Чернокнижник spend_hp +1"`, потолок `22`.

---

**J-02 — WinCondition vs HUD: архитектура GAME_OVER экрана не определена**  
`win-condition.md` Dependencies Downstream: "HUD | Сигнал `game_over(winner)` — HUD отображает экран результата"  
`hud.md` EC-HUD-05: "HUD не обнаруживает GAME_OVER самостоятельно — управление передаёт вышестоящий **GameController**"  
`hud.md` OQ-01 (открытый): "При GAME_OVER — HUD просто замораживается или подписывается...?"  
HUD Dependencies не содержит WinCondition.

Две несовместимые архитектуры: (A) HUD напрямую слушает `game_over(winner)`, (B) неспроектированный GameController оркестрирует показ. Сценарий "Dragon убит" → step 6: `game_over(winner)` испущен → непонятно кто рендерит экран результата.

**Что поменять**: выбрать Option A (HUD слушает `game_over(winner)` напрямую) или Option B (задокументировать GameController). Закрыть HUD OQ-01. Синхронизировать WinCondition и HUD Dependencies.

---

**J-03 — CombatSystem AC-14 vs AC-15: противоречие в условии Oracle first_step_bonus**  
`combat-system.md`:
- AC-14: "бой на первом шаге (`steps_taken==1`) → `first_step_bonus = 1`"
- AC-15: "бой не на первом шаге (`steps_taken > 0`) → `first_step_bonus = 0`"

`steps_taken > 0` включает `steps_taken == 1`, прямое противоречие с AC-14.  
EC-06 корректен: "first_step_bonus = 1 если `steps_taken == 1`".

**Что поменять**: AC-15 → условие `steps_taken > 1`.

---

### WARNINGS

**W-J-01 — TurnManager Interactions vs HUD: расхождение по `turn_changed`**  
TurnManager Dependencies outgoing HUD row: включает `turn_changed(from_player, to_player)`.  
HUD Dependencies incoming TurnManager row: НЕ включает `turn_changed` — только `turn_started`, `step_spent`, `turn_ended`, `turn_skipped`.  
InventoryUI правильно подписывается на `turn_changed`. HUD, судя по state-transitions, на него не подписан.  
Исправить: убрать HUD из `turn_changed`-строки TurnManager (или добавить в HUD, если реально используется).

**W-J-02 — KnockoutSystem Overview: неверное утверждение про retreat**  
Overview: "CombatSystem уже отступил игрока на предыдущий тайл (`retreat()`)".  
Факт: CombatSystem Rule 10a ПРОПУСКАЕТ `retreat()` когда `is_knocked_out() == true`. Стандартный нокаут — игрок остаётся на тайле монстра.  
Rules 2 и AC-01 корректны, Overview — нет. Исправить Overview.

**W-J-03 — Стандартный нокаут и монстр на тайле: документация отсутствует**  
Стандартный нокаут (не Воин): игрок остаётся на тайле с живым монстром. EncounterDispatcher триггерит только через `tile_reveal_complete` (движение), а не при старте хода → игрок может уйти на следующем ходу не вступая в бой снова. Это корректно с Pillar 4 (fair randomness), но нигде не задокументировано явно.  
Добавить в KnockoutSystem Edge Cases или TurnManager: пояснение что standing-encounter не триггерится без движения.

**W-J-04 — Оставшиеся UPPERCASE SKELETON_KEY в прозаическом тексте (I-06 частичный)**  
Таблицы и AC исправлены (I-06). Прозаические описания:  
- `combat-system.md` Overview: `"monster_id == "SKELETON_KEY""`  
- `loot-system.md` Rule 1, Interactions, Dependencies Upstream: "включая SKELETON_KEY"  
Исправить на `&"skeleton_key"`.

**W-J-05 — WinCondition OQ-01/OQ-02: открыты, но resolved**  
OQ-01 (сигнал `dragon_killed` в CombatSystem) — RESOLVED ✓ (в combat-system.md есть).  
OQ-02 (`vp: float`, `add_vp()` в PlayerState) — RESOLVED ✓ (в player-state.md есть).  
OQ-03 (TurnManager и HUD подписаны) — PARTIALLY resolved (TurnManager ✓, HUD — вопрос J-02).  
Отметить OQ-01 и OQ-02 как `~~RESOLVED~~`, OQ-03 перенаправить на J-02.

**W-J-06 — CombatUI: устаревшая retrofit-метка**  
CombatUI Dependencies Bidirectional: "Retrofit required: добавить `auto_reroll_triggered` и `player_choice_requested` в CombatSystem GDD". Оба сигнала уже есть в CombatSystem Dependencies Downstream.  
Удалить устаревшую метку.

**W-J-07 — HUD OQ-03: устаревший вопрос об ItemData.icon**  
ItemDatabase уже содержит `@export var icon: Texture2D`. Пометить как resolved.

**W-J-08 — CombatSystem AC-19: несуществующий monster_id "goblin"**  
Заменить `"goblin"` на реальный ID, например `&"rat"`.

---

## Phase 3: Design Theory

| Check | Verdict | Примечание |
|-------|---------|------------|
| 3a Progression Loop | PASS | Один главный loop (Dragon kill), поддерживающие (VP, лут) |
| 3b Cognitive Load | PASS | 5 систем в бою — намеренно (hotseat, взрослый + ребёнок) |
| 3c Dominant Strategy | PASS | Wizard не доминирует (нет combat bonus) |
| 3d Feedback / Player Experience | CONCERN | GAME_OVER display routing через неспроектированный GameController (J-02 design gap) — финальный момент кампании должен быть явно архитектурно задан |
| 3e Knockout tile retention | CONCERN (resolved) | Игрок остаётся на monster tile, но walk-away без бой-триггера → fair. Требует документации (W-J-03) |
| 3f Pillar Alignment | PASS | Все системы обслуживают минимум 1 pillar |
| 3g Player Fantasy Coherence | PASS | Идентичность «семейный hotseat данжн-кроулер» консистентна |

---

## Phase 4: Scenario — Dragon Kill GAME_OVER Flow

| Шаг | Система | Результат |
|-----|---------|-----------|
| 1 | CombatSystem: `attack_total > 15` → WIN | ✓ |
| 2 | `TileSystem.clear_cell(dragon_pos)` | ✓ |
| 3 | `emit dragon_killed(player_A)` → WinCondition | ✓ |
| 4 | WinCondition: `player_A.add_vp(1.5)` | ✓ |
| 5 | WinCondition: определить winner, emit `game_over(winner)` | ✓ |
| 6 | TurnManager → `GAME_OVER`, прекращает ходы | ✓ |
| **7** | **Кто показывает экран результата?** | **⚠️ AMBIGUOUS (J-02)** |
| 8 | `combat_resolved(true, false)` → TurnManager (GAME_OVER state) | ✓ EC-09: игнорируется |
| 9 | `item_dropped(player_A, &"dragon")` → LootSystem | ✓ |
| 10 | LootSystem: нет в drop table → `item_acquired(player_A, null)` → TurnManager | ✓ EC-09: игнорируется |

**BLOCKER**: шаг 7 не определён — J-02 нужно закрыть до архитектуры.

---

## Summary

**Verdict: FAIL**

| | Количество |
|---|---|
| BLOCKING (J-01..J-03) | **3** |
| WARNINGS (W-J-01..W-J-08) | 8 |
| Phase 3 CONCERNS | 2 (3d=J-02; 3e=W-J-03) |
| Retrofit #8 verified PASS | 6/6 |

**Retrofit #9 blockers:**
- J-01: `item-database.md` — исправить "+4" → "+1", потолок "+22"
- J-02: `win-condition.md` + `hud.md` — решить архитектуру GAME_OVER display, закрыть OQ-01
- J-03: `combat-system.md` — AC-15: `steps_taken > 0` → `steps_taken > 1`
