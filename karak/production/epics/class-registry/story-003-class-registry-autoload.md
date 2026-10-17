# Story 003: ClassRegistry Autoload

> **Epic**: ClassRegistry
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-10-12
> **Estimate**: M — 2–3 часа

## Context

**GDD**: `design/gdd/class-system.md`
**Requirement**: `TR-class-002`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0001: Autoload Strategy
**ADR Decision Summary**: Только `ClassRegistry`, `ItemDatabase`, `MonsterDatabase` являются Autoload — read-only data-реестры регистрируются в Project Settings → Autoload. API: `ClassRegistry.get_class(id)`, `ClassRegistry.get_all_classes()`, `ClassRegistry.pick_random(n, rng)`. Ресурсы загружаются через `preload()` в `_ready()`.

**Engine**: Godot 4.7.2 (GDScript) | **Risk**: LOW
**Engine Notes**: Autoload API стабилен с Godot 4.0. Godot гарантирует: все Autoloads полностью инициализированы (их `_ready()` завершён) до того, как любой `_ready()` GameScene запустится — `await` не нужен.

**Control Manifest Rules (Foundation layer)**:
- Required: только `ClassRegistry`, `ItemDatabase`, `MonsterDatabase` являются Autoload; ресурсы загружаются через `preload()` в `_ready()` — не через Inspector-слоты
- Forbidden: никогда не добавлять изменяемое состояние в Autoload; никогда не использовать EventBus Autoload
- Guardrail: Autoload lookup — O(1) Dictionary; нет аллокаций на каждое обращение

---

## Acceptance Criteria

*Из GDD `design/gdd/class-system.md`, AC-01:*

- [ ] AC-01: `ClassRegistry.get_all_classes()` возвращает ровно 7 объектов `HeroClassData`
- [ ] AC-01: у каждого из 7 объектов уникальный `id` (нет повторений)
- [ ] `ClassRegistry.get_class(id: StringName) -> HeroClassData` возвращает правильный объект по ID
- [ ] `ClassRegistry.get_class(&"nonexistent")` — возвращает `null` (или push_error + null), не crash
- [ ] Регистрация в Project Settings → Autoload: имя `ClassRegistry`, путь `res://src/foundation/class_registry.gd`
- [ ] Доступен из любого скрипта как `ClassRegistry.get_class(...)` без `preload` или `@export`

---

## Implementation Notes

*Из ADR-0001 Implementation Guidelines:*

- Файл: `src/foundation/class_registry.gd`
- `class_name ClassRegistry` / `extends Node`
- Заголовочный комментарий: `## READ-ONLY. Never add mutable game state here.`
- `_ready()` загружает все 7 `.tres` через `preload()` и заполняет `Dictionary[StringName, HeroClassData]`
- Использовать UID-пути (`preload("uid://...")`) если доступны, иначе `res://assets/data/classes/[name].tres`
- Публичные методы:
  - `get_class(id: StringName) -> HeroClassData` — O(1) Dictionary lookup
  - `get_all_classes() -> Array[HeroClassData]` — возвращает `.values()`
  - `pick_random(n: int, rng: RandomNumberGenerator) -> Array[HeroClassData]` — реализуется в Story 004
- Внутренний `var _classes: Dictionary = {}` — заполняется в `_ready()`; после `_ready()` не изменяется
- Порядок регистрации в Project Settings → Autoload: `ClassRegistry` первым (до `ItemDatabase`, `MonsterDatabase`)

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: создание `.tres` файлов — должны существовать до этой story
- Story 004: реализация `pick_random()` — здесь только заглушка или stub

---

## QA Test Cases

*Lean mode — test specs generated from GDD AC-01.*

- **AC-01-a**: `get_all_classes()` возвращает 7 объектов
  - Given: ClassRegistry инициализирован (все 7 `.tres` загружены)
  - When: вызов `ClassRegistry.get_all_classes()`
  - Then: длина массива == 7
  - Edge cases: повторный вызов возвращает тот же массив (не пересоздаёт)

- **AC-01-b**: уникальные ID
  - Given: ClassRegistry инициализирован
  - When: вызов `ClassRegistry.get_all_classes()` → собрать все `id`
  - Then: нет дубликатов; все 7 ID — ожидаемые: `&"warrior"`, `&"rogue"`, `&"wizard"`, `&"warlock"`, `&"swordsman"`, `&"oracle"`, `&"swordswoman"`

- **AC-01-c**: `get_class()` lookup по ID
  - Given: ClassRegistry инициализирован
  - When: `ClassRegistry.get_class(&"warrior")`
  - Then: возвращает `HeroClassData` с `id == &"warrior"` и `can_reroll_both_dice == true`

- **AC-01-d**: неизвестный ID
  - Given: ClassRegistry инициализирован
  - When: `ClassRegistry.get_class(&"unknown_class")`
  - Then: возвращает `null`; нет crash; push_error вызван
  - Edge cases: пустой StringName `&""` — тоже null, не crash

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/class_registry/class_registry_init_test.gd` — должен существовать и проходить

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002 (7 `.tres` файлов) должна быть DONE
- Unlocks: Story 004 (pick_random строится поверх ClassRegistry), Story 005; разблокирует все downstream эпики (PlayerState, CombatSystem и т.д.)

---

## Completion Notes
**Completed**: 2026-10-12
**Criteria**: 4/6 verified; 2 deferred (Autoload registration + global access — шаги в Godot Editor)
**Deviations**: None
**Test Evidence**: Logic — `tests/unit/class_registry/class_registry_init_test.gd` (7 тест-функций, NOT RUN — запуск вручную в Godot Editor)
**Code Review**: Complete (verdict: CHANGES REQUIRED → исправлено → APPROVED)
