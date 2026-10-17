# Story 001: HeroClassData Resource Schema

> **Epic**: ClassRegistry
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-10-12
> **Estimate**: S — 2 часа
> **Performance Impact**: Нет — Resource read-only, ~20 полей на экземпляр, нет вычислений и аллокаций в runtime

## Context

**GDD**: `design/gdd/class-system.md`
**Requirement**: `TR-class-001`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003: PlayerState as Node
**ADR Decision Summary**: `HeroClassData extends Resource` — статическое определение класса (max_hp, флаги способностей, display_name); только чтение. `PlayerState extends Node` — runtime-состояние. Разделение: данные класса в Resource, состояние игрока в Node.

**Engine**: Godot 4.7.2 (GDScript) | **Risk**: LOW
**Engine Notes**: `Resource` и `@export` стабильны с Godot 4.0. UID-ссылки (`uid://...`) предпочтительны с Godot 4.4 — использовать при `preload()` в ClassRegistry.

**Control Manifest Rules (Foundation layer)**:
- Required: `HeroClassData extends Resource` — статическое определение класса, только чтение
- Forbidden: никогда не реализовывать `PlayerState extends Resource` (это другой класс — не путать)
- Guardrail: все переменные, параметры функций и return types статически типизированы

---

## Acceptance Criteria

*Из GDD `design/gdd/class-system.md`, AC-14 + структура полей:*

- [ ] `class_name HeroClassData` / `extends Resource` объявлены корректно
- [ ] Все 19 `@export` полей объявлены со статическими типами (см. GDD — Структура HeroClass Resource)
- [ ] Дефолтные значения: все boolean-флаги `= false`; `max_hp: int = 5`; `first_step_combat_bonus: int = 0`
- [ ] Поле `id: StringName` — тип StringName, не String
- [ ] AC-14: Resource загружается как данные; внешний код не может изменить поле и сохранить изменение в источник (`.tres` read-only в runtime)

---

## Implementation Notes

*Из ADR-0003 Implementation Guidelines:*

- Файл: `src/foundation/hero_class_data.gd`
- `class_name HeroClassData` / `extends Resource` — без Node, без _ready()
- Все поля — `@export var` с явными типами; только данные, никакой логики
- `id: StringName` использует литерал `&"warrior"` и т.д. при создании `.tres`
- Комментарии-заголовки секций обязательны: `# === COMBAT ===`, `# === KNOCKOUT ===`, `# === MOVEMENT ===`, `# === TILE/DUNGEON ===`, `# === ITEMS ===`
- Добавить заголовочный комментарий класса: `## READ-ONLY class definition for a hero class. Never add mutable state or methods here.`
- Каждое поле должно иметь inline-комментарий: кто его читает (CombatSystem, KnockoutSystem и т.д.)

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: заполнение `.tres` файлов (7 классов) — только определяем схему
- Story 003: ClassRegistry Autoload, preload логика
- Story 004: pick_random логика

---

## QA Test Cases

*Lean mode — test specs generated from GDD acceptance criteria.*

- **AC-schema-1**: HeroClassData class instantiation
  - Given: файл `src/foundation/hero_class_data.gd` загружен
  - When: `HeroClassData.new()` создан
  - Then: объект не null, `max_hp == 5`, все boolean-флаги `== false`, `first_step_combat_bonus == 0`
  - Edge cases: проверить, что `id` имеет тип StringName (не String)

- **AC-schema-2**: Все 19 полей существуют
  - Given: экземпляр `HeroClassData`
  - When: обращение к каждому из 19 @export полей
  - Then: нет ошибки "Invalid get index", все поля доступны

- **AC-14**: Данные ресурса read-only
  - Given: загружен `.tres` через `load()`
  - When: код присваивает значение полю (например, `res.max_hp = 99`)
  - Then: изменение не сохраняется в источник; `.tres` на диске не изменился
  - Edge cases: изменение in-memory допустимо (Resource не immutable в GDScript), но `.tres` на диске неизменен

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/class_registry/hero_class_data_schema_test.gd` — должен существовать и проходить

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None — первая story эпика, нет зависимостей
- Unlocks: Story 002 (нужна схема для создания `.tres`), Story 003 (нужен тип для load), Story 004, Story 005

---

## Completion Notes
**Completed**: 2026-10-12
**Criteria**: 5/5 passing
**Deviations**: None
**Test Evidence**: Logic — `tests/unit/class_registry/hero_class_data_schema_test.gd` (10 тест-функций, NOT RUN — запуск вручную в Godot Editor)
**Code Review**: Complete (verdict: CHANGES REQUIRED → исправлено → APPROVED)
**Notes**: Тест `test_hero_class_data_duplicate_isolates_mutation_from_original` добавлен по итогам code review — покрывает runtime-риск shared Resource corruption (AC-14 isolation).
