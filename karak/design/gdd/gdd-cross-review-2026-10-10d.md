# Cross-GDD Review Report — 5-й прогон

**Date**: 2026-10-10
**GDDs Reviewed**: 18
**Verdict**: **FAIL**

---

## Blocking Issues (5)

### F-01 — ClassSystem: downstream-зависимости помечены «Не спроектирована» (стейл)

**Severity**: BLOCKING
**GDD**: `class-system.md` → Dependencies → Outgoing
**Проблема**: Четыре системы помечены как «Не спроектирована», хотя все они уже спроектированы:
- CombatSystem — «Не спроектирована»
- KnockoutSystem — «Не спроектирована»
- MovementSystem — «Не спроектирована»
- EncounterDispatcher — «Не спроектирована»
**Исправление**: Обновить статусы на «Спроектирована ✓» для всех четырёх систем.

---

### F-02 — CombatSystem: стейл Wizard + scroll_magic_attack (D-01 не распространился)

**Severity**: BLOCKING
**GDD**: `combat-system.md`
**Проблема**: D-01 исправил EC-05 и часть комментариев, но следующие места остались с pre-nerf текстом:

| Место | Стейл-текст |
|-------|-------------|
| Rule 5 | «Если `magic_charge_no_discard = true` (Волшебник): свиток не тратится» |
| EC-09 | «тратится (кроме Волшебника)» |
| AC-10 | «`remove_scroll()` вызван (кроме Волшебника)» |
| AC-11 | «Волшебник использует свиток → `remove_scroll()` НЕ вызван; свиток остаётся в слоте» |

**Исправление**: Rule 5, EC-09, AC-10, AC-11 — уточнить: scroll_magic_attack тратится для всех включая Волшебника; только scroll_teleport не тратится.

---

### F-03 — ItemDatabase: Rule 4 + EC-03 + Note — стейл (D-01 не распространился)

**Severity**: BLOCKING
**GDD**: `item-database.md`
**Проблема**: D-01 исправил Formula 2 таблицу, но Rule 4 и EC-03 по-прежнему говорят что `magic_charge_no_discard` применяется ко **всем** свиткам:

| Место | Стейл-текст |
|-------|-------------|
| Rule 4 | «отменяет `is_consumable` для **всех свитков** (`SCROLL`) — Волшебник использует как Магический удар, так и Свиток телепорта неограниченное число раз» |
| Rule 4 Note | «название флага охватывает оба типа свитков» |
| EC-03 | «Применимо к обоим типам свитков (`MAGIC_ATTACK` и `TELEPORT`)» |

**Исправление**: Rule 4, Note и EC-03 — только scroll_teleport; scroll_magic_attack расходуется нормально.

---

### F-04 — CombatSystem: AC-14 steps_taken=0 (стейл после E-03)

**Severity**: BLOCKING
**GDD**: `combat-system.md` → Acceptance Criteria → AC-14
**Проблема**: E-03 исправил EC-06 (`steps_taken == 1`), но AC-14 всё ещё использует старое значение `steps_taken=0`.
```
AC-14: «бой на первом шаге хода (steps_taken=0)»
EC-06: «Проверять steps_taken == 1, а не == 0» ← уже исправлен
```
**Исправление**: AC-14: `steps_taken=0` → `steps_taken==1`.

---

### F-05 — CombatSystem: порядок сигналов — item_dropped до combat_resolved (deadlock)

**Severity**: BLOCKING — функциональный дедлок
**GDD**: `combat-system.md` → Core Rules → Rule 9
**Проблема**: В Rule 9 (победа) порядок эмиссии сигналов:
```
1. clear_cell + add_vp
2. emit item_dropped(player, monster_id)   ← синхронный
   → LootSystem обрабатывает синхронно
   → emit item_acquired(player, item)
   → TurnManager находится в AWAITING_COMBAT → EC-04 push_error, сигнал игнорируется
3. emit combat_resolved(true, false)
   → TurnManager переходит в AWAITING_LOOT
   → ждёт item_acquired который никогда не придёт → DEADLOCK
```
GDScript сигналы синхронны по умолчанию. item_acquired приходит до того, как TurnManager готов его принять.

**Исправление**: В Rule 9 переместить `emit_signal("combat_resolved", ...)` **перед** `emit_signal("item_dropped", ...)`. TurnManager сначала входит в AWAITING_LOOT, затем получает item_acquired из LootSystem.

Для Мечника с шестёркой (six_rolled=true): TurnManager переходит в TURN_ACTIVE (не AWAITING_LOOT), поэтому item_acquired приходит в TURN_ACTIVE — PlayerState получает предмет, TurnManager игнорирует сигнал, ход продолжается. Deadlock отсутствует.

---

## Warning Issues (10)

**W-01** — ClassSystem EC-17: «MovementSystem обязана передавать `is_first_step: bool` в CombatSystem» — контракт не отражён в MovementSystem GDD. Advisory.

**W-02** — CombatSystem Interactions: `combat_resolved(result)` в таблице — `result: String` vs `(won: bool, six_rolled: bool)`. Строка оставалась с pre-B-13 текстом частично (Visual/Audio Requirements).

**W-03** — TileSystem: для фонтана с выбором «нет» — нет явного указания что шаги не тратятся. EC-06/07 ясны, но Rule для фонтана не содержит отдельной ветки «выбор = нет».

**W-04** — PlayerState: Dependencies не упоминают ClassSystem как upstream. Asymmetry.

**W-05** — LootSystem: EC-03 (Ghost/Dragon) — item_acquired(player, null) эмитируется, но TurnManager EC-04 описывает AWAITING_LOOT → TURN_ACTIVE только «если предмет != null и сундук». Нужно явно добавить: AWAITING_LOOT принимает item_acquired(null) и тоже завершает ход.

**W-06** — WinCondition: не упоминает CombatSystem как upstream в Dependencies (asymmetry по dragon_killed).

**W-07** — EncounterDispatcher Rule 4: `is_cleared(pos)` — метод не верифицирован в TileSystem Public API. Рекомендуется явно добавить в TileSystem.

**W-08** — DiceSystem: не упоминает TurnManager в downstream (TurnManager читает dice_state для Мечника через CombatSystem — indirect, но стоит задокументировать).

**W-09** — KnockoutSystem: не упоминает ClassSystem как upstream в Dependencies (читает `knockout_*` флаги).

**W-10** — MovementSystem: не упоминает ClassSystem как upstream в Dependencies (читает 4 флага движения).

---

## Info Issues (4)

**I-01** — HUD GDD: зависимость от PlayerState `vp: float` уже присутствует. ✓

**I-02** — MonsterDatabase: Rule 2 код-комментарий исправлен (`>`) ✓ E-01 закрыт.

**I-03** — TurnManager AWAITING_LOOT: состояние добавлено в 3-м прогоне ✓

**I-04** — Общая заметка: после закрытия F-01–F-05 рекомендуется запустить 6-й прогон для финальной верификации.

---

## Cross-System Scenario Issues

### Сценарий: Победа над Призраком/Драконом → лут → переход хода

**Участвующие системы**: CombatSystem → LootSystem → TurnManager

**Шаги и проблема (до F-05 фикса)**:
1. attack_total > difficulty → CombatSystem WIN state
2. clear_cell, add_vp (для Ghost)
3. `emit item_dropped(player, "GHOST")` ← синхронный
4. LootSystem: Ghost не в drop table → `emit item_acquired(player, null)`
5. TurnManager: AWAITING_COMBAT → EC-04 push_error, item_acquired игнорируется
6. `emit combat_resolved(true, false)`
7. TurnManager: AWAITING_COMBAT → AWAITING_LOOT
8. TurnManager ждёт item_acquired который уже прошёл → **DEADLOCK**

**Статус**: F-05 закрывает этот сценарий.

---

## Статус по кампаниям

| Кампания | Дата | Блокеры | Закрыто |
|----------|------|---------|---------|
| 1-я (C-01–C-11, D-01–D-03) | 2026-10-09 | 14 | 14 ✓ |
| 2-я (B-01–B-14) | 2026-10-10 | 14 | 14 ✓ |
| 3-я (C-01–C-09, D-01–D-03) | 2026-10-10 | 12 | 12 ✓ |
| 4-я (E-01–E-03, D-01) | 2026-10-10 | 4 | 4 ✓ |
| **5-я (F-01–F-05)** | **2026-10-10** | **5** | **0 (в работе)** |

---

## Рекомендуемые исправления (в порядке приоритета)

1. **F-05** — CombatSystem Rule 9: переместить `combat_resolved` перед `item_dropped`
2. **F-02** — CombatSystem Rule 5, EC-09, AC-10, AC-11: убрать исключение Волшебника для scroll_magic_attack
3. **F-03** — ItemDatabase Rule 4, Note, EC-03: только scroll_teleport
4. **F-04** — CombatSystem AC-14: `steps_taken=0` → `==1`
5. **F-01** — ClassSystem Dependencies: статусы → «Спроектирована ✓»
