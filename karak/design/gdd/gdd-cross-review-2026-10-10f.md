# Cross-GDD Review Report — 7-й прогон
**Date**: 2026-10-10
**GDDs Reviewed**: 18
**Прогон**: #7 — верификация G-01..G-08 + полный повторный скан

---

## Verdict: FAIL

**Блокеров**: 1 (H-01)
**Предупреждений**: 8 (перенесены + новые)

---

## Phase 2: Consistency Issues

### Blocking (блокирует архитектуру)

#### 🔴 H-01 — `vp_changed` отсутствует в PlayerState GDD (каскад от G-03)

**GDD**: `player-state.md` + `hud.md`

G-03 (Retrofit #6) добавил в `hud.md`:
- VPRow подписывается на сигнал `vp_changed(new_vp: float)` от PlayerState
- AC-HUD-CR-09 / AC-HUD-CR-10 тестируют отображение VP по этому сигналу

Но `player-state.md` не обновлён:
- Нет `signal vp_changed(new_vp: float)` в разделе сигналов
- `add_vp()` не упоминает эмиссию сигнала
- Таблица Interactions с HUD не содержит `vp_changed`

**Последствие**: разработчик реализует PlayerState без сигнала; HUD не получает обновления VP; AC-HUD-CR-09/10 упадут.

**Действие**: добавить в `player-state.md` — сигнал, описание в `add_vp()`, строку в Interactions.

---

### Verified CLOSED — G-01..G-08 (Retrofit #6)

| ID | Описание | Статус |
|----|----------|--------|
| G-01 | ItemDatabase Overview: magic_charge_no_discard → TELEPORT | CLOSED ✓ |
| G-02 | Min combat_bonus для Дракона = 4 (строгое >) | CLOSED ✓ |
| G-03 | HUD VP-дисплей: VPRow + AC-HUD-CR-09/10 добавлены | CLOSED ✓ |
| G-04 | LootSystem AC-13: item_acquired(null) для GHOST | CLOSED ✓ |
| G-05 | TurnManager EC-09: guard на GAME_OVER + item_acquired | CLOSED ✓ |
| G-06 | PlayerState Dependencies: ClassSystem + ItemDatabase → Спроектирована ✓ | CLOSED ✓ |
| G-07 | MonsterDatabase Dependencies: все 5 строк → Спроектирована ✓ | CLOSED ✓ |
| G-08 | DiceSystem + TileSystem Dependencies обновлены; WinCondition удалена из TileSystem | CLOSED ✓ |

---

### Warnings (перенесены из 6-го прогона, не блокируют)

#### ⚠️ W-01 — Контракт `is_first_step` не верифицирован на граничном значении

**GDD**: `oracle-system.md`, `turn-manager.md`

TurnManager инкрементирует `steps_taken` после движения. `is_first_step` = `steps_taken == 1`.
`steps_taken = 0` до первого шага → первый шаг → `steps_taken = 1` → Oracle проверяет → корректно.
Но ClassSystem (EC-17) описывает поведение Oracle при `is_first_step` без ссылки на этот контракт.

**Действие**: добавить в ClassSystem EC-17 ссылку «`is_first_step` определяется TurnManager как `steps_taken == 1`».

#### ⚠️ W-02 — WinCondition не перечислена в Dependencies TurnManager как downstream

**GDD**: `turn-manager.md`, `win-condition.md`

WinCondition слушает сигналы TurnManager, но в Dependencies TurnManager нет строки для WinCondition.

**Действие**: добавить WinCondition в исходящие зависимости TurnManager.

#### ⚠️ W-03 — KnockoutSystem не перечислена в Dependencies CombatSystem как downstream

**GDD**: `combat-system.md`, `knockout-system.md`

KnockoutSystem зависит от CombatSystem (реагирует на поражение), но CombatSystem не перечисляет KnockoutSystem в исходящих.

**Действие**: добавить KnockoutSystem в исходящие зависимости CombatSystem.

#### ⚠️ W-04 — TurnManager: инвариант «ровно один активный игрок» нигде не задокументирован

**GDD**: `turn-manager.md`

При переходе IDLE → PLAYER_TURN инвариант «ровно один игрок активен в любой момент» подразумевается, но явно не закреплён ни в Rules, ни в Acceptance Criteria.

**Действие**: добавить инвариант в TurnManager Rules или отдельным AC.

#### ⚠️ W-06 — Сложность Призрака (12) создаёт резкий spike в прогрессии

**GDD**: `monster-database.md`

Прогрессия сложности: Крыса 5 → Паук 6 → Мумия 7 → Скелет-ключник 8 → Скелет-воин 9 → Король 10 → **Призрак 12** → Дракон 15.
Шаг от Короля к Призраку = +2 (удвоение от Короля к Призраку с 17% до 3% P(win)).
Требует дизайнерского решения — намеренно или нет?

**Действие**: подтвердить намеренность или скорректировать difficulty Призрака до 11.

#### ⚠️ W-07 — Баланс Разбойника (combat_bonus+1) vs Воина (combat_bonus+2)

**GDD**: `class-system.md`

Воин: +2 combat_bonus. Разбойник: +1 combat_bonus. Разбойник компенсируется движением (+1 step), но против Дракона разница +1 vs +2 существенна.
Требует дизайнерского решения.

**Действие**: подтвердить баланс или скорректировать бонус Разбойника.

#### ⚠️ W-NEW-01 — WinCondition: OQ-01 / OQ-02 закрыты в других GDD, но не в самом WinCondition

**GDD**: `win-condition.md`

OQ-01 (is_dragon flag) и OQ-02 (chest count) разрешены через MonsterDatabase и ChestSystem соответственно, но в `win-condition.md` статус OQ не обновлён.

**Действие**: пометить OQ-01 / OQ-02 как RESOLVED в `win-condition.md`.

#### ⚠️ W-NEW-02 — VP float: форматирование «1.0» vs «1» в UI не специфицировано

**GDD**: `hud.md`, `player-state.md`

VP хранится как float (Ghost = 1.0, Dragon = 1.5). HUD отображает Label, но формат не указан.
«1.0» vs «1» vs «1,5» (локаль) — неопределённость.

**Действие**: добавить в hud.md спецификацию формата: `"%.1f" % vp` или целое при `.x == 0`.

---

## Phase 3: Design Theory

### Verdict: CONCERNS (без новых блокеров)

Все 3 Pillar'а активно обслуживаются системами. Экономика VP корректна (W-08 CLOSED в G-03).
Когнитивная нагрузка: 4 активные системы в основном цикле — в пределах нормы (≤4).

Сценарные прогоны (Phase 4): все 5 ключевых сценариев прошли без undefined behavior после Retrofit #6.

Перенесённые concerns: W-06 (Ghost spike), W-07 (Rogue/Warrior) — дизайнерские решения, не технические баги.

---

## Phase 5: Summary

| Категория | Количество | Статус |
|-----------|-----------|--------|
| Blocking | 1 | H-01 — PlayerState vp_changed |
| Warnings | 8 | W-01..W-04, W-06..W-07, W-NEW-01..W-NEW-02 |
| CLOSED (Retrofit #6) | 8 | G-01..G-08 ✓ |

**Следующий шаг**: закрыть H-01 → запустить 8-й прогон → при PASS → `/create-architecture`
