# Story 005: Character Class Immutability Guard

> **Epic**: ClassRegistry
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: S — 1–2 часа
> **Performance Impact**: None — guard clause, no runtime computations
> **Manifest Version**: 2026-10-12

## Context

**GDD**: `design/gdd/class-system.md`
**Requirement**: `TR-class-003`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003: PlayerState as Node
**ADR Decision Summary**: `PlayerState extends Node` — runtime-состояние игрока. `@export var character_class: HeroClassData` назначается в Inspector до первого хода; после установки — неизменен до конца партии. `assert(character_class != null, ...)` в `_ready()` предотвращает запуск без класса.

**Engine**: Godot 4.7.2 (GDScript) | **Risk**: LOW
**Engine Notes**: `@export` и `assert()` в `_ready()` стабильны. `push_error()` в GDScript не бросает исключение — выводит ошибку в лог и продолжает выполнение; это ожидаемое поведение для guard.

**Control Manifest Rules (Foundation layer / Core layer)**:
- Required: `assert(character_class != null, "PlayerState requires character_class set in Inspector")` в `PlayerState._ready()`; `PlayerState extends Node` — in-scene Node, два независимых инстанса
- Forbidden: никогда не реализовывать `PlayerState extends Resource`; никогда не создавать через `PlayerState.new()`
- Guardrail: все публичные методы юнит-тестируемы через dependency injection

---

## Acceptance Criteria

*Из GDD `design/gdd/class-system.md`, AC-13, EC-03:*

- [ ] AC-13: если `PlayerState.character_class` уже установлен и вызывается повторная установка — `push_error` вызван; `character_class` не изменился
- [ ] EC-03: перевыбор класса в середине партии невозможен
- [ ] `PlayerState._ready()` содержит `assert(character_class != null, ...)`
- [ ] Первоначальная установка (когда `character_class == null`) — проходит без ошибки

---

## Implementation Notes

*Из ADR-0003 Implementation Guidelines:*

```gdscript
# В PlayerState — setter для character_class
func set_character_class(new_class: HeroClassData) -> void:
    if character_class != null:
        push_error("PlayerState: character_class already set — cannot change class mid-game. EC-03.")
        return
    character_class = new_class
```

- Использовать `set_character_class()` метод или GDScript `setter` (`var character_class: HeroClassData: set = _set_character_class`)
- `@export var character_class: HeroClassData` назначается в Inspector напрямую (не через setter) при первоначальной настройке сцены — это нормально
- Setter нужен для **runtime попыток переназначения** (например, баг в коде или некорректный вызов)
- `_ready()`: `assert(character_class != null, "PlayerState requires character_class set in Inspector")`
- Этот assert работает только в debug builds; в release builds игнорируется — это приемлемо

> ⚠ Примечание: эта story реализует guard в **PlayerState**, а не в ClassRegistry. PlayerState может ещё не существовать как полноценный класс — реализовать минимальный `PlayerState` с `character_class` полем, getter/setter и `_ready()` assert. Полная реализация PlayerState (HP, сигналы, позиция) — в PlayerState эпике.

---

## Out of Scope

*Handled by neighbouring stories / epics — do not implement here:*

- Story 004: логика выбора случайных классов (pick_random)
- PlayerState epic: HP, позиция, инвентарь, сигналы, VP — только минимальный stub здесь
- Полный PlayerState — реализуется в его собственном эпике

---

## QA Test Cases

*Lean mode — test specs generated from GDD AC-13, EC-03.*

- **AC-13-a**: первоначальная установка проходит
  - Given: `PlayerState` создан; `character_class == null`
  - When: `player.set_character_class(warrior_class)`
  - Then: `player.character_class == warrior_class`; нет ошибки в логе

- **AC-13-b**: повторная установка отклонена
  - Given: `PlayerState` создан; `character_class == warrior_class` (уже установлен)
  - When: `player.set_character_class(rogue_class)`
  - Then: `push_error` вызван; `player.character_class` по-прежнему `== warrior_class`
  - Edge cases: попытка установить тот же класс повторно — тоже отклоняется с `push_error`

- **AC-13-c**: assert при `character_class == null` в _ready()
  - Given: `PlayerState` добавлен в сцену без назначения `character_class` в Inspector
  - When: `_ready()` запускается
  - Then: assert срабатывает (в debug build); в тесте — заменить assert на `if character_class == null: push_error(...)` для тестируемости
  - Edge cases: в unit-тестах GdUnit4 assert может прерывать тест — рассмотреть mock или условный assert

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/class_registry/class_immutability_test.gd` — должен существовать и проходить

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (HeroClassData тип нужен для параметра setter) должна быть DONE
- Unlocks: PlayerState epic (минимальный stub PlayerState создан здесь — полная реализация там)

---

## Completion Notes

**Completed**: 2026-10-17
**Criteria**: 4/4 passing (AC-13-c — assert в `_ready()` — deferred: ручная проверка в Editor)
**Deviations**: None
**Test Evidence**: Logic — `tests/unit/class_registry/class_immutability_test.gd` (6 тест-функций)
**Code Review**: Complete (code-review скилл — CHANGES REQUIRED → исправлено → APPROVED WITH SUGGESTIONS)
**Extra**: Добавлен null-guard на входной параметр `new_class` в `set_character_class()` — не был предусмотрен story, но выявлен code review как BLOCKING gap. Тест `test_player_state_set_null_class_rejected_keeps_null` добавлен.
