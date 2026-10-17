# Story 004: pick_random — Class Selection Pool

> **Epic**: ClassRegistry
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-10-12
> **Estimate**: S — 1–2 часа

## Context

**GDD**: `design/gdd/class-system.md`
**Requirement**: `TR-class-003`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003: PlayerState as Node
**ADR Decision Summary**: `character_class` в PlayerState неизменен после выбора. `ClassRegistry.pick_random(n, rng)` реализует формулу выбора: `offered = random_sample(available, N)`, где `available = all_classes − already_selected`. Если доступных < N — предложить все доступные (не ошибка).

**Engine**: Godot 4.7.2 (GDScript) | **Risk**: LOW
**Engine Notes**: `RandomNumberGenerator` API стабилен. Использовать `rng.randi_range()` для детерминированного тестирования (передаётся RNG с фиксированным seed).

**Control Manifest Rules (Foundation layer)**:
- Required: все публичные методы юнит-тестируемы через dependency injection — RNG передаётся параметром, не создаётся внутри метода
- Forbidden: никогда не добавлять изменяемое состояние в Autoload
- Guardrail: gameplay-значения data-driven — `CLASS_OFFER_COUNT = 3` как константа в ClassRegistry

---

## Acceptance Criteria

*Из GDD `design/gdd/class-system.md`, AC-10..AC-12:*

- [x] AC-10: класс, уже выбранный другим игроком, отсутствует в предложении
- [x] AC-11: если доступных классов ≥ N — длина предложения == `CLASS_OFFER_COUNT` (3 по умолчанию)
- [x] AC-12: если доступных классов < N — предложены все доступные (длина < N, не ошибка)
- [x] EC-01: если доступных == 0 — возвращает пустой массив (EC-02: assert если `player_count > 7`, но это edge case MVP)
- [x] Метод детерминирован: один и тот же RNG seed даёт один и тот же результат
- [x] Нет повторений внутри одного предложения (sampling without replacement)

---

## Implementation Notes

*Из GDD Формула 1 и ADR-0003:*

```gdscript
## Константа — tuning knob (GDD Tuning Knobs: safe range 2–5)
const CLASS_OFFER_COUNT: int = 3

## Выбрать N случайных классов из тех, что не заняты.
## Caller передаёт already_selected — ClassRegistry не хранит состояние выборов.
func pick_random(n: int, rng: RandomNumberGenerator,
                 already_selected: Array[HeroClassData] = []) -> Array[HeroClassData]:
```

- `available_classes = get_all_classes().filter(...)` — исключить `already_selected`
- Если `available_classes.size() <= n` — вернуть `available_classes.duplicate()` (все доступные)
- Иначе: Fisher-Yates shuffle или `Array.pick_random()` N раз без возврата
- ClassRegistry остаётся **stateless** относительно выборов: кто уже выбрал — передаётся снаружи
- `already_selected` сравнивается по ссылке на `HeroClassData` объект (одни и те же `.tres` ресурсы)
- Предпочтительный метод shuffle: создать копию `available_classes`, shuffle через RNG, взять первые N

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 003: базовая инициализация ClassRegistry и `get_all_classes()` — должна быть DONE
- Story 005: иммутабельность `character_class` в PlayerState (отдельная story)
- UI экрана выбора класса — не в scope ClassRegistry эпика

---

## Performance

N/A — изолированный утилитарный метод. Не затрагивает gameplay loop, рендеринг или физику. Аллокации ограничены: одна копия массива + shuffle. Вызывается один раз за экран выбора класса.

---

## QA Test Cases

*Lean mode — test specs generated from GDD AC-10..AC-12.*

- **AC-10**: нет повторений из занятых классов
  - Given: ClassRegistry инициализирован; Игрок 1 выбрал `warrior`
  - When: `pick_random(3, rng, [warrior_class])`
  - Then: `warrior` отсутствует в результате; длина результата == 3 (6 доступных ≥ 3)
  - Edge cases: `already_selected` содержит 5 классов → доступно 2 < 3 → вернуть 2 (AC-12)

- **AC-11**: ровно N предложений когда ≥N доступных
  - Given: ClassRegistry инициализирован; `already_selected = []`
  - When: `pick_random(3, rng, [])`
  - Then: длина результата == 3; все 3 — разные классы
  - Edge cases: `pick_random(3, rng, [])` вызван дважды с одинаковым seed → одинаковый результат

- **AC-12**: меньше N доступных → вернуть все доступные
  - Given: `already_selected` содержит 5 классов (доступно 2)
  - When: `pick_random(3, rng, five_classes)`
  - Then: длина результата == 2; нет ошибки; оба класса из доступных
  - Edge cases: `already_selected` содержит все 7 → `pick_random` возвращает `[]`

- **AC-determinism**: детерминированность
  - Given: `RandomNumberGenerator` с `seed = 42`
  - When: `pick_random(3, rng_seed42, [])` дважды (пересоздать RNG с тем же seed)
  - Then: оба вызова вернули идентичный массив

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/class_registry/pick_random_test.gd` — должен существовать и проходить

**Status**: [x] PASSED — 8/8 тестов (2026-10-17)

---

## Dependencies

- Depends on: Story 003 (ClassRegistry Autoload с `get_all_classes()`) должна быть DONE
- Unlocks: Story 005 (можно реализовывать параллельно); разблокирует UI выбора класса (другой эпик)

---

## Completion Notes

**Completed**: 2026-10-17
**Criteria**: 6/6 passing
**Deviations**: None — реализация соответствует ADR-0003 и control manifest
**Test Evidence**: Logic — `tests/unit/class_registry/pick_random_test.gd` — 8/8 PASSED
**Code Review**: Skipped — Lean mode
**Extra fixes (out of scope)**:
- `class_name ClassRegistry` удалён из `class_registry.gd` — устранён naming conflict с Autoload (Godot 4.7)
- `project.godot` — исправлен битый UID Autoload ClassRegistry
- `class_registry_init_test.gd` — удалена неиспользуемая `_ClassRegistryScript` const
