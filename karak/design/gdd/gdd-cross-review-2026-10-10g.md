# Cross-GDD Review Report — 8-й прогон
**Date**: 2026-10-10
**GDDs Reviewed**: 18
**Прогон**: #8 — полный повторный скан после H-01 retrofit

---

## Verdict: FAIL

**Блокеров**: 6 (I-01..I-06)
**Предупреждений**: 11 (перенесённые + новые)

---

## Phase 2: Consistency Issues

### Blocking (блокирует архитектуру)

#### I-01 — Конфликт маршрута сигнала GAME_OVER: `PlayerState.won` vs `WinCondition.game_over(winner)`

**GDD**: `turn-manager.md`, `win-condition.md`, `player-state.md`

TurnManager определяет переход в GAME_OVER:
- Rule 7: "PlayerState испускает `won` → TurnManager → GAME_OVER"
- AC-11: "PlayerState испускает `won` → GAME_OVER"
- Transitions: "Любое → GAME_OVER | PlayerState: `won`"
- Interactions: "PlayerState | ← слушает | `won` → GAME_OVER"

WinCondition определяет:
- Interactions: "TurnManager | downstream | Сигнал `game_over(winner)` — TurnManager останавливает цикл ходов"

Два разных сигнала от двух разных источников заявлены как триггер одного перехода:
- `PlayerState.won` — TurnManager слушает
- `WinCondition.game_over(winner)` — WinCondition отправляет

Дополнительная проблема: PlayerState объявляет `signal won` (line 100), но **нигде не описано**, кто и когда его испускает. WinCondition определяет победителя и вызывает `add_vp(1.5)`, но не вызывает ничего на PlayerState, что бы испустило `won`.

**Последствие**: разработчик TurnManager подключится к `PlayerState.won`. Разработчик WinCondition испустит `game_over(winner)`. Никто не соединит их — GAME_OVER никогда не наступит.

**Действие**: определить единый маршрут. Варианты:
- (A) WinCondition вызывает `player.mark_won()` → PlayerState emits `won` → TurnManager реагирует
- (B) WinCondition emits `game_over(winner)` → TurnManager слушает WinCondition напрямую

Выбрать один, обновить оба GDD.

---

#### I-02 — PlayerState outgoing deps: HUD row missing `vp_changed`

**GDD**: `player-state.md`

Retrofit H-01 добавил `signal vp_changed(new_vp: float)` в секцию Signals, обновил `add_vp()` и Interactions. Но таблица Dependencies → Outgoing (line 223) не обновлена:

```
| HUD | Подписан на `hp_changed`, `item_added`, `item_removed` |
```

Должно быть: `hp_changed`, `vp_changed`, `item_added`, `item_removed`.

**Действие**: добавить `vp_changed` в строку HUD таблицы Dependencies outgoing.

---

#### I-03 — TurnManager AC-05 противоречит CombatSystem `add_step(1)` для Мечника

**GDD**: `turn-manager.md`, `combat-system.md`

CombatSystem Rule 9 для Мечника с 6:
> `TurnManager.add_step(1)` + `emit_signal("combat_resolved", true, true)`

`add_step(1)` вызывается **ДО** `combat_resolved`. При `steps_remaining == 2`: `add_step(1)` → `steps_remaining = 3`.

TurnManager AC-05:
> GIVEN Мечник, steps_remaining == 2
> WHEN combat_resolved(won=true, six_rolled=true)
> THEN steps_remaining == 2 (не изменилось)

Противоречие: `steps_remaining` уже 3 к моменту получения `combat_resolved`. AC-05 должен говорить `steps_remaining == 3`.

**Действие**: исправить AC-05: `steps_remaining == 3 (2 + 1 от add_step)`.

---

#### I-04 — EncounterDispatcher `get_tile(pos)` vs TileSystem `get_cell(pos)`: несовпадение имени метода

**GDD**: `encounter-dispatcher.md`, `tile-system.md`

EncounterDispatcher использует `get_tile(pos)` (Rule 2, Interactions, EC-09, Dependencies).
TileSystem определяет `get_cell(pos: Vector2i) -> DungeonCell` (Public API, line 90).
TileSystem's собственная Interactions table: "EncounterDispatcher → `get_cell(pos)`".

Одна пара GDD использует два разных имени для одного метода.

**Последствие**: вызов `get_tile()` на TileSystem → runtime error "method not found".

**Действие**: заменить все `get_tile(pos)` на `get_cell(pos)` в `encounter-dispatcher.md`.

---

#### I-05 — `MIN_COMBAT_BONUS_FOR_DRAGON`: ItemDatabase = 3 vs MonsterDatabase = 4

**GDD**: `item-database.md`, `monster-database.md`

ItemDatabase TK (line 152):
> `MIN_COMBAT_BONUS_FOR_DRAGON | 3 | — | DRAGON_DIFFICULTY(15) - roll_max(12)`

MonsterDatabase TK (line 128):
> `MIN_COMBAT_BONUS_FOR_DRAGON | 4 | — | DRAGON_DIFFICULTY - 12 + 1 = 4 (строгое >)`

Правильное значение — **4**: оператор строго `>` (15 > 15 = false, draw = loss). Формула ItemDatabase `15 - 12 = 3` не учитывает строгое неравенство.

**Действие**: исправить ItemDatabase TK: `MIN_COMBAT_BONUS_FOR_DRAGON = 4`, формула: `DRAGON_DIFFICULTY - roll_max + 1 = 4`.

---

#### I-06 — monster_id: UPPERCASE в LootSystem/CombatSystem vs lowercase в MonsterDatabase

**GDD**: `loot-system.md`, `combat-system.md`, `monster-database.md`

MonsterDatabase определяет id как lowercase StringName: `&"rat"`, `&"spider"`, `&"skeleton_key"` и т.д.

LootSystem drop table и ACs: `RAT`, `SPIDER`, `MUMMY`, `SKELETON_KEY` (UPPERCASE).
CombatSystem AC-16: `monster_data.id = "SKELETON_KEY"` (UPPERCASE).

`monster_data.id` — это значение из MonsterDatabase (lowercase). Сигнал `item_dropped(player, monster_data.id)` передаст `&"rat"`, а не `"RAT"`.

**Последствие**: LootSystem lookup по `"RAT"` при получении `&"rat"` → не найдёт запись → дроп не сработает.

**Действие**: привести к единому регистру. Рекомендация: lowercase StringName (`&"rat"`) как канонический формат. Обновить LootSystem и CombatSystem ACs.

---

### Verified CLOSED — H-01 (Retrofit #7)

| ID | Описание | Статус |
|----|----------|--------|
| H-01 | PlayerState `vp_changed`: сигнал добавлен, Interactions обновлены | CLOSED ✓ (частично — I-02 выявил пропущенную строку в Dependencies) |

---

### Warnings (перенесённые, всё ещё открыты)

#### W-01 — ClassSystem EC-17 `is_first_step` contract

ClassSystem EC-17 описывает Oracle при `is_first_step` как параметр от MovementSystem, но CombatSystem читает `TurnManager.steps_taken` напрямую. Контракт старый.

#### W-02 — WinCondition не в Dependencies TurnManager (подпоглощён I-01)

Часть более широкой проблемы I-01. Будет решена вместе с I-01.

#### W-04 — TurnManager инвариант "ровно один активный игрок" не задокументирован

Неявно следует из `active_player_index`, но не закреплён в Rules или AC.

#### W-06 — Ghost difficulty 12: spike в прогрессии

10 → 12 (skip 11). Дизайнерское решение — намеренно или нет?

#### W-07 — Rogue vs Warrior balance

Rogue: `wins_on_draw`. Warrior: `can_reroll_both_dice`. Разные механики — требует playtesting, не противоречие.

#### W-NEW-01 — WinCondition OQ-01/OQ-02/OQ-03 stale

Все три OQ разрешены в других GDD, но в `win-condition.md` не помечены как RESOLVED.

#### W-NEW-02 — VP float formatting

HUD AC-HUD-CR-09 показывает "1.5", AC-HUD-CR-10 показывает "2.0" и "0" (не "0.0"). Неопределённость формата.

---

### Новые warnings

#### W-NEW-03 — MovementSystem Dependencies: HUD = "Не спроектирован" (stale)

MovementSystem Dependencies outgoing: HUD помечен как "Не спроектирован". HUD GDD полностью спроектирован. Обновить статус.

#### W-NEW-04 — KnockoutSystem Downstream: `clear_knockout()` приписан KnockoutSystem

KnockoutSystem Downstream таблица: "PlayerState | calls `clear_knockout()` — only for Warrior". На самом деле `clear_knockout()` вызывает TurnManager, не KnockoutSystem. Исправить владельца вызова.

#### W-NEW-08 — systems-index.md: 14 систем "Needs Revision" — stale

systems-index.md Progress Tracker (line 155): "14 systems Needs Revision". Все GDD обновлены до "Designed". Обновить Progress Tracker.

#### W-NEW-10 — `clear_cell()` на CLEARED fountain: undefined behavior

EncounterDispatcher вызывает `clear_cell(pos)` для FOUNTAIN. Если fountain уже CLEARED (повторный визит) — TileSystem не определяет поведение. Должен быть no-op.

---

## Phase 3: Design Theory

### Verdict: PASS (без блокеров)

**3a — Progression Loop**: PASS. Единственная доминантная прогрессия — VP. Power (оружие) — enabler, не конкурент.

**3b — Attention Budget**: PASS. 3 одновременно активных системы в обычном ходу (Movement, Encounter, TurnManager). Combat заменяет Movement. Предел 4 не превышен.

**3c — Dominant Strategy**: PASS. Нет доминантной стратегии — каждый класс имеет trade-offs. Rogue bypass + chest farming ограничен необходимостью убить Dragon.

**3d — Economic Loops**: 2 concerns (не блокируют):
- **3d-1**: Минимальный catch-up. Раннее преимущество в оружии усиливается. Смягчается коротким сеансом (30-60 мин) и множеством путей к VP. Верно оригиналу.
- **3d-2**: Оружие — permanent (нет sink). Power gap растёт. Намеренно (Pillar 2). Смягчается длиной сессии.

**3e — Difficulty Curve**: PASS. Прогрессия монстров (5→6→7→8→9→10→12→15) совпадает с ростом силы игрока (0→+1→+2→+3→+6..+9). Ghost spike (W-06) — единственный concern.

**3f — Pillar Alignment**: PASS. Все 18 систем обслуживают ≥1 pillar. Анти-pillars не нарушены.

**3g — Player Fantasy**: PASS. Когерентная идентичность: "от нуля до драконоубийцы за один вечер".

---

## Phase 4: Cross-System Scenario Walkthrough

### Сценарий 1: Убийство Дракона (3+ системы)

**Trigger**: Игрок с `combat_bonus >= 4` побеждает Dragon.

**Цепочка**:
1. MovementSystem → `spend_step()` → TurnManager `steps_remaining -= 1`
2. TileSystem → `reveal_cell(pos)` → TileRevealVFX
3. EncounterDispatcher → `combat_started(player, dragon_data)` → CombatSystem
4. CombatSystem → dice roll → WIN → `clear_cell()` → `dragon_killed(player)` → **WinCondition**
5. WinCondition → `player.add_vp(1.5)` → `game_over(winner)` → **?? TurnManager**
6. CombatSystem → `combat_resolved(true, false)` → TurnManager (уже в GAME_OVER?)
7. CombatSystem → `item_dropped(player, dragon_id)` → LootSystem

**Проблема на шаге 5-6**: I-01 проявляется. TurnManager слушает `PlayerState.won`, WinCondition отправляет `game_over(winner)`. Если никто не соединяет их — TurnManager не переходит в GAME_OVER. Затем `combat_resolved` приходит, TurnManager переходит в AWAITING_LOOT, ждёт `item_acquired` для Dragon (который может быть null). Ход завершается как обычный, и игра продолжается вместо завершения.

**Severity**: BLOCKER (I-01).

### Сценарий 2: Мечник побеждает с 6 при steps_remaining = 2

**Trigger**: Swordsman wins combat, one die shows 6.

**Цепочка**:
1. CombatSystem Rule 9 Swordsman: `TurnManager.add_step(1)` → steps_remaining = 3
2. CombatSystem: `emit_signal("combat_resolved", true, true)` → TurnManager
3. TurnManager Rule 6: six_rolled=true → НЕ завершает ход, steps_remaining сохраняется (= 3)
4. HUD: обновляет StepsRow → steps_empty = 4 - 3 = 1 → OK

**Проблема**: AC-05 утверждает steps_remaining == 2, но реально 3 (I-03). Тест по AC-05 упадёт.

**Severity**: BLOCKER (I-03).

### Сценарий 3: Победа над Крысой → LootSystem drop

**Trigger**: Player kills Rat.

**Цепочка**:
1. CombatSystem: WIN → `item_dropped(player, monster_data.id)` → id = `&"rat"` (lowercase, from MonsterDatabase)
2. LootSystem: receives `item_dropped(player, &"rat")` → lookup in drop table by `"RAT"` (UPPERCASE)
3. Lookup fails → no item dropped → `item_acquired(player, null)`

**Проблема**: I-06 — case mismatch. Player doesn't receive Dagger.

**Severity**: BLOCKER (I-06).

### Сценарий 4: EncounterDispatcher reads tile type

**Trigger**: Player enters revealed tile.

**Цепочка**:
1. EncounterDispatcher: `TileSystem.get_tile(pos)` → **method not found**
2. Runtime error — encounter never dispatched

**Проблема**: I-04 — method name mismatch.

**Severity**: BLOCKER (I-04).

### Сценарий 5: VP update → HUD display

**Trigger**: Player opens chest → LootSystem → `PlayerState.add_vp(1.0)`.

**Цепочка**:
1. PlayerState: `add_vp(1.0)` → emits `vp_changed(1.0)` → HUD
2. HUD: VPRow обновляется корректно
3. Developer reading only PlayerState Dependencies outgoing (line 223): не видит `vp_changed` → может не подключить HUD

**Проблема**: I-02 — неполная документация deps. Смягчается тем, что Signals section корректна.

**Severity**: BLOCKER (minor — документационная ошибка, но может привести к пропуску).

---

## Phase 5: Summary

| Категория | Количество | Статус |
|-----------|-----------|--------|
| Blocking (new) | 6 | I-01..I-06 |
| Warnings (carry-over) | 7 | W-01, W-02, W-04, W-06, W-07, W-NEW-01, W-NEW-02 |
| Warnings (new) | 4 | W-NEW-03, W-NEW-04, W-NEW-08, W-NEW-10 |
| CLOSED (Retrofit #7) | 1 | H-01 ✓ (частично — I-02) |
| Phase 3 Design Theory | PASS | 2 non-blocking concerns |

**Следующий шаг**: закрыть I-01..I-06 (Retrofit #8) → запустить 9-й прогон → при PASS → `/create-architecture`
