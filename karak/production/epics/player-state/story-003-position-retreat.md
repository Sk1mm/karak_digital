# Story 003: Position & Retreat — set_position, previous_position, retreat

> **Epic**: PlayerState
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-10-12

## Context

**GDD**: `design/gdd/player-state.md`
**Requirement**: `TR-player-state-004`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003: PlayerState as Node
**ADR Decision Summary**: PlayerState хранит position и previous_position как Vector2i. set_position() всегда сохраняет current в previous перед изменением. retreat() восстанавливает previous без изменения самого previous_position.

**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: Vector2i — встроенный тип, стабилен с Godot 4.0. Нет post-cutoff API.

**Control Manifest Rules (Core layer)**:
- Required: PlayerState не управляет движением сам — только хранит state. MovementSystem и CombatSystem вызывают set_position()/retreat().
- Forbidden: retreat() не обновляет previous_position (AC-09, EC-05)

---

## Acceptance Criteria

*From GDD `design/gdd/player-state.md`, scoped to this story:*

- [ ] AC-07: `set_position(Vector2i(5,7))` из position=Vector2i(2,3) → `get_position()==Vector2i(5,7)`, `previous_position==Vector2i(2,3)`
- [ ] AC-08: set A → set B → `retreat()` → `get_position()==A`
- [ ] AC-09: retreat дважды без промежуточного set_position → оба вызова возвращают к A; `previous_position` не меняется вторым retreat
- [ ] AC-10: `take_damage(1)` + `retreat()` при hp=3 → `get_hp()==2`, `get_position()==A`
- [ ] AC-11: нокаут (hp=1→take_damage→нокаут) + retreat → hp==1, `is_knocked_out()==true`, `get_position()==A`
- [ ] AC-23: `retreat()` до первого `set_position()` → вернуть на start_tile (не Vector2i(0,0))

---

## Implementation Notes

*Derived from ADR-0003 Implementation Guidelines:*

Добавить в `src/foundation/player_state.gd`:

```gdscript
# start_tile инициализируется снаружи (GameScene или TurnManager) сразу после создания
var start_tile: Vector2i = Vector2i(0, 0)  # перезаписывается до первого хода

func get_position() -> Vector2i:
    return position

func set_position(pos: Vector2i) -> void:
    previous_position = position  # сохранить current перед изменением (AC-07)
    position = pos

func retreat() -> void:
    # retreat возвращает на previous_position.
    # Если set_position ещё не вызывался, previous_position == start_tile
    # (оба поля инициализированы start_tile при создании — AC-23)
    position = previous_position
    # previous_position НЕ обновляется (EC-05, AC-09)
```

**Инициализация start_tile (AC-23):**
В `_ready()` инициализировать оба поля стартовой позицией:
```gdscript
func _ready() -> void:
    # ... (player_id assert, class init)
    position = start_tile
    previous_position = start_tile
```
start_tile — @export поле, назначается в Inspector или через код до первого хода. НЕ Vector2i(0,0) по умолчанию без явной установки.

**EC-05 (GDD):** `retreat()` дважды подряд — обе итерации возвращают к A. previous_position не обновляется самим retreat(). Это корректное поведение по дизайну.

---

## Out of Scope

- Story 001: объявление полей position/previous_position/start_tile
- Story 002: take_damage() — AC-10, AC-11 тестируют комбинацию, но take_damage реализуется в story-002
- Логика движения (MovementSystem), выбора тайлов, ограничений карты — не PlayerState

---

## QA Test Cases

- **AC-07**: set_position сохраняет previous
  - Given: position=Vector2i(2,3)
  - When: `set_position(Vector2i(5,7))`
  - Then: `get_position()==Vector2i(5,7)`, `previous_position==Vector2i(2,3)`

- **AC-08**: retreat возвращает на A
  - Given: `set_position(A)`, затем `set_position(B)`
  - When: `retreat()`
  - Then: `get_position()==A`

- **AC-09**: retreat дважды
  - Given: `set_position(A)`, `set_position(B)`
  - When: `retreat()` дважды подряд
  - Then: оба вызова возвращают к A; после второго retreat: `previous_position` не изменился
  - Edge cases: retreat три раза — то же поведение

- **AC-10**: take_damage + retreat
  - Given: hp=3, position=B, previous_position=A
  - When: `take_damage(1)`, затем `retreat()`
  - Then: `get_hp()==2`, `get_position()==A`

- **AC-11**: нокаут + retreat
  - Given: hp=1, position=B, previous_position=A
  - When: `take_damage(1)`, затем `retreat()`
  - Then: hp==1, `is_knocked_out()==true`, `get_position()==A`

- **AC-23**: retreat до первого set_position
  - Given: PlayerState инициализирован с start_tile=Vector2i(0,2); set_position не вызывался
  - When: `retreat()`
  - Then: `get_position()==Vector2i(0,2)`, НЕ Vector2i(0,0)

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/player_state/player_state_position_test.gd` — должен существовать и проходить

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (DONE) — поля position, previous_position, start_tile
- Depends on: Story 002 (DONE) — take_damage() для AC-10, AC-11
- Unlocks: Story 004, 005, 006

## Completion Notes
**Completed**: 2026-10-17
**Criteria**: 6/6 passing
**Deviations**: ADVISORY — `start_tile` default `Vector2i(0, 2)` требует уточнения в GDD (возможен sentinel); edge case `set_position(same_pos)` не специфицирован — backlog.
**Test Evidence**: Logic: `tests/unit/player_state/player_state_position_test.gd` (10 тест-функций)
**Code Review**: Complete — APPROVED WITH SUGGESTIONS (S-01 исправлен, S-02/S-03 в backlog)
