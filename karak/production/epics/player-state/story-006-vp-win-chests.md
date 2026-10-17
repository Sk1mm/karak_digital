# Story 006: VP, Win Condition, Chests — add_vp, mark_dragon_killed, increment_chests

> **Epic**: PlayerState
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-10-12

## Context

**GDD**: `design/gdd/player-state.md`
**Requirement**: `TR-player-state-001`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003: PlayerState as Node
**ADR Decision Summary**: VP накапливается как float; `mark_dragon_killed()` — терминальная операция (повторный вызов — no-op). PlayerState не завершает партию самостоятельно — WinCondition читает has_won().

**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: float арифметика стабильна. Нет post-cutoff API.

**Control Manifest Rules (Core layer)**:
- Required: `won` сигнал типизирован (ADR-0002) — `signal won()` без параметров
- Required: `mark_dragon_killed()` повторно → no-op, `won` не испускается дважды (AC-15)
- Forbidden: PlayerState не завершает партию — только хранит флаг (WinCondition ответственен)

---

## Acceptance Criteria

*From GDD `design/gdd/player-state.md`, scoped to this story:*

- [ ] AC-14: `mark_dragon_killed()` → `has_won()==true`, сигнал `won` испущен ровно один раз
- [ ] AC-15: повторный `mark_dragon_killed()` при `has_killed_dragon=true` → no-op, `won` не испускается повторно
- [ ] AC-29: `add_vp(3.0)` + `add_vp(1.5)` → `vp==4.5`
- [ ] AC-30: `add_vp(-1.0)` → push_error вызван, vp не изменился

---

## Implementation Notes

*Derived from ADR-0003 Implementation Guidelines:*

Добавить в `src/foundation/player_state.gd`:

```gdscript
func has_won() -> bool:
    return has_killed_dragon

func add_vp(amount: float) -> void:
    if amount < 0.0:
        push_error("add_vp: amount must be >= 0, got %f" % amount)
        return
    vp += amount
    vp_changed.emit(vp)

func mark_dragon_killed() -> void:
    if has_killed_dragon:
        return  # терминальное состояние — no-op (AC-15)
    has_killed_dragon = true
    won.emit()
    # PlayerState не завершает партию — WinCondition получит сигнал и управляет flow

func increment_chests() -> void:
    # PlayerState не проверяет наличие ключа — это ответственность LootSystem (GDD EC-22)
    chests_opened += 1
```

**GDD EC-19:** `take_damage()` после `has_killed_dragon=true` применяется обычно — PlayerState не завершает партию самостоятельно.

**GDD EC-20:** `mark_dragon_killed()` повторно → no-op, `won` не испускается снова.

**Заметка по сигналу `won`:** Сигнал `won` присутствует в AC-14/AC-15, но отсутствует в явном списке сигналов GDD (раздел Detailed Design). Реализуем по AC — они авторитетны для тестирования. Флаг для синхронизации с GDD: при следующем /design-review обновить список сигналов в GDD player-state.md.

---

## Out of Scope

- WinCondition логика (сравнение VP при завершении партии) — отдельный эпик
- Начисление VP за конкретные события (сундуки, монстры) — LootSystem/CombatSystem
- LootSystem проверка наличия ключа перед increment_chests — не PlayerState

---

## QA Test Cases

- **AC-14**: mark_dragon_killed — первый вызов
  - Given: `has_killed_dragon==false`
  - When: `mark_dragon_killed()`
  - Then: `has_won()==true`, `won` испущен ровно один раз

- **AC-15**: mark_dragon_killed — повторный вызов
  - Given: `has_killed_dragon==true` (после первого mark_dragon_killed)
  - When: `mark_dragon_killed()` снова
  - Then: `has_won()==true`, `won` НЕ испущен повторно
  - Edge cases: вызвать 5 раз подряд — `won` испущен ровно 1 раз

- **AC-29**: add_vp накапливает
  - Given: `vp==0.0`
  - When: `add_vp(3.0)`, затем `add_vp(1.5)`
  - Then: `vp==4.5`, `vp_changed` испущен дважды (с 3.0, затем с 4.5)

- **AC-30**: add_vp отрицательный
  - Given: `vp==2.0`
  - When: `add_vp(-1.0)`
  - Then: push_error вызван, `vp==2.0` (не изменился)
  - Edge cases: `add_vp(-0.001)`, `add_vp(0.0)` — ноль допустим (no-op или +0)

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/player_state/player_state_vp_test.gd` — должен существовать и проходить

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (DONE) — поля vp, has_killed_dragon, сигналы vp_changed, won
- Unlocks: PlayerState epic COMPLETE после прохождения всех 6 stories

---

## Completion Notes
**Completed**: 2026-10-17
**Criteria**: 4/4 passing
**Deviations**: ADVISORY — add_vp(0.0) испускает vp_changed (задокументировано в doc-comment). QA backlog: EC-1..EC-4 (initial state, zero-signal, no-signal, no-VP invariant тесты) — не блокируют.
**Test Evidence**: Logic: `tests/unit/player_state/player_state_vp_test.gd` (14 тест-функций)
**Code Review**: Complete (/code-review 2026-10-17 — APPROVED WITH SUGGESTIONS, исправления применены)
