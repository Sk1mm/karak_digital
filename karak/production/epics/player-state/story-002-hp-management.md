# Story 002: HP Management — take_damage, heal_full, нокаут

> **Epic**: PlayerState
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-10-12

## Context

**GDD**: `design/gdd/player-state.md`
**Requirement**: `TR-player-state-003`, `TR-player-state-005`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003: PlayerState as Node
**ADR Decision Summary**: PlayerState содержит мутируемое runtime-состояние; HP зажат в [1, max_hp] в устойчивом состоянии; нокаут (hp→1, skip_next_turn=true) — единственный способ достичь hp=1 через бой.

**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: Нет post-cutoff API — чистая GDScript логика.

**Control Manifest Rules (Core layer)**:
- Required: Типизированные сигналы — `signal hp_changed(new_hp: int, max_hp: int)` (ADR-0002)
- Required: Сигналы испускаются только при фактическом изменении состояния (AC-24, AC-26, AC-32)
- Forbidden: `effective_attack` не добавлять в PlayerState (GDD EC)

---

## Acceptance Criteria

*From GDD `design/gdd/player-state.md`, scoped to this story:*

- [ ] AC-12: `take_damage(1)` при hp=1 → `get_hp()==1`, `is_knocked_out()==true`, `skip_next_turn==true`, сигналы `knocked_out` и `hp_changed(1, max_hp)` испущены
- [ ] AC-13: нокаут не меняет position, weapons, key
- [ ] AC-24: `take_damage(0)` → hp не меняется, сигнал `hp_changed` не испущен
- [ ] AC-25: `take_damage(-1)` → `push_error` вызван, hp не меняется
- [ ] AC-26: `clear_knockout()` при живом игроке (`skip_next_turn=false`) → no-op, `knockout_cleared` не испущен
- [ ] AC-31: `heal_full()` при hp=2, max_hp=5 → `get_hp()==5`, сигнал `hp_changed(5, 5)` испущен
- [ ] AC-32: `heal_full()` при `hp==max_hp` → no-op, сигнал `hp_changed` не испущен

---

## Implementation Notes

*Derived from ADR-0003 Implementation Guidelines:*

Добавить в `src/foundation/player_state.gd`:

```gdscript
func get_hp() -> int:
    return hp

func is_knocked_out() -> bool:
    return skip_next_turn

func take_damage(amount: int) -> void:
    # --- ШАГ 1: валидация ---
    if amount < 0:
        push_error("take_damage: amount must be >= 0, got %d" % amount)
        return
    if amount == 0:
        return  # no-op — сигнал не испускается (AC-24)
    # --- ШАГ 2: применить урон ---
    hp -= amount
    # --- ШАГ 3: нокаут если hp <= 0 ---
    if hp <= 0:
        hp = 1
        skip_next_turn = true
        hp_changed.emit(hp, max_hp)
        knocked_out.emit()
        return
    hp_changed.emit(hp, max_hp)

func heal_full() -> void:
    if hp == max_hp:
        return  # no-op (AC-32)
    hp = max_hp
    hp_changed.emit(hp, max_hp)

func clear_knockout() -> void:
    if not skip_next_turn:
        return  # no-op на живом игроке (AC-26)
    skip_next_turn = false
    knockout_cleared.emit()
```

**Нокаут-поведение (GDD Rule 7):** при `hp <= 0`: hp→1, skip_next_turn→true. Позиция и инвентарь не меняются (AC-13).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: объявление сигналов и полей hp/max_hp
- Story 003: retreat() — не вызывается в take_damage, это задача CombatSystem
- Story 006: mark_dragon_killed() — победа не связана с HP

---

## QA Test Cases

- **AC-12**: Нокаут при hp=1
  - Given: PlayerState с hp=1, max_hp=5
  - When: `take_damage(1)`
  - Then: `get_hp()==1`, `is_knocked_out()==true`, `skip_next_turn==true`, эмитированы `knocked_out` и `hp_changed(1, 5)`
  - Edge cases: take_damage(100) при hp=3 → тот же нокаут-результат

- **AC-13**: Нокаут не трогает position/weapons/key
  - Given: PlayerState с weapons=[weapon_a, weapon_b], key=some_key, position=Vector2i(3,3), hp=1
  - When: `take_damage(1)`
  - Then: position==Vector2i(3,3), weapons.size()==2, key!=null

- **AC-24**: take_damage(0) — no-op
  - Given: hp=3
  - When: `take_damage(0)`
  - Then: `get_hp()==3`, сигнал `hp_changed` не испущен

- **AC-25**: take_damage отрицательный
  - Given: hp=3
  - When: `take_damage(-1)`
  - Then: push_error вызван, `get_hp()==3`
  - Edge cases: take_damage(-100)

- **AC-26**: clear_knockout на живом игроке
  - Given: `skip_next_turn=false`
  - When: `clear_knockout()`
  - Then: `is_knocked_out()==false`, `knockout_cleared` не испущен

- **AC-31**: heal_full восстанавливает
  - Given: hp=2, max_hp=5
  - When: `heal_full()`
  - Then: `get_hp()==5`, `hp_changed(5, 5)` испущен

- **AC-32**: heal_full при max HP
  - Given: hp=5, max_hp=5
  - When: `heal_full()`
  - Then: `get_hp()==5`, `hp_changed` НЕ испущен

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/player_state/player_state_hp_test.gd` — должен существовать и проходить

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (DONE) — skeleton с полями hp, max_hp, skip_next_turn, сигналами
- Unlocks: Story 003, 004, 005, 006 (могут реализовываться параллельно)

---

## Completion Notes

**Completed**: 2026-10-17
**Criteria**: 7/7 passing
**Deviations**: ADVISORY — doc-комментарий `get_hp()` цитирует TR-003 как `[0, max_hp]`, реальный инвариант `[1, max_hp]`. Только комментарий, не логика.
**Test Evidence**: Logic — `tests/unit/player_state/player_state_hp_test.gd` (11 тест-функций, GdUnit4 6.2.2)
**Code Review**: Complete (lean mode — LP-CODE-REVIEW пропущен)
