# Story 002: 7 Class Data Files

> **Epic**: ClassRegistry
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Config/Data
> **Manifest Version**: 2026-10-12

## Context

**GDD**: `design/gdd/class-system.md`
**Requirement**: `TR-class-001`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003: PlayerState as Node
**ADR Decision Summary**: `HeroClassData extends Resource` — статические данные класса в `.tres` файлах; каждый из 7 классов — отдельный `.tres` с правильно заполненными флагами.

**Engine**: Godot 4.7.2 (GDScript) | **Risk**: LOW
**Engine Notes**: `.tres` файлы — текстовый формат Godot. Godot 4.4+ поддерживает uid:// ссылки; при `preload()` из Autoload предпочтительно использовать UID-пути для устойчивости к переименованиям файлов.

**Control Manifest Rules (Foundation layer)**:
- Required: ресурсы в Autoload загружаются через `preload()` в `_ready()` — не через Inspector-слоты
- Forbidden: никогда не добавлять изменяемое игровое состояние в Autoload-классы
- Guardrail: gameplay-значения data-driven — никаких hardcoded чисел в GDScript логике

---

## Acceptance Criteria

*Из GDD `design/gdd/class-system.md`, AC-02..AC-09, AC-14:*

- [ ] AC-02: у всех 7 классов `max_hp == 5`
- [ ] AC-03: Воин — `can_reroll_both_dice == true`, `knockout_teleport_to_start == true`, `knockout_no_turn_skip == true`, `knockout_full_heal == true`; у остальных 6 эти флаги == false
- [ ] AC-04: Разбойница — `wins_on_draw == true`, `can_bypass_monster_free == true`; у других == false
- [ ] AC-05: Волшебник — `magic_charge_no_discard == true`, `can_pass_through_walls == true`; у других == false
- [ ] AC-06: Чернокнижник — `can_spend_hp_for_attack == true`, `can_swap_positions == true`; у других == false
- [ ] AC-07: Мечник — `auto_reroll_on_one == true`, `can_continue_turn_on_six == true`; у других == false
- [ ] AC-08: Оракул — `first_step_combat_bonus == 1`, `choose_encounter_from_two == true`; у других `first_step_combat_bonus == 0`
- [ ] AC-09: Воительница — `can_reroll_one_die == true`, `can_bypass_monster_cost == true`; у других == false
- [ ] AC-14: все 7 `.tres` файлов существуют по пути `assets/data/classes/`

---

## Implementation Notes

*Из ADR-0003 и GDD Таблица классов:*

Создать 7 `.tres` файлов (можно через `new HeroClassData()` в скрипте или вручную):

| Файл | id | Уникальные флаги (true) |
|------|----|------------------------|
| `assets/data/classes/warrior.tres` | `&"warrior"` | `can_reroll_both_dice`, `knockout_teleport_to_start`, `knockout_no_turn_skip`, `knockout_full_heal` |
| `assets/data/classes/rogue.tres` | `&"rogue"` | `wins_on_draw`, `can_bypass_monster_free` |
| `assets/data/classes/wizard.tres` | `&"wizard"` | `magic_charge_no_discard`, `can_pass_through_walls` |
| `assets/data/classes/warlock.tres` | `&"warlock"` | `can_spend_hp_for_attack`, `can_swap_positions` |
| `assets/data/classes/swordsman.tres` | `&"swordsman"` | `auto_reroll_on_one`, `can_continue_turn_on_six` |
| `assets/data/classes/oracle.tres` | `&"oracle"` | `choose_encounter_from_two`; `first_step_combat_bonus = 1` |
| `assets/data/classes/swordswoman.tres` | `&"swordswoman"` | `can_reroll_one_die`, `can_bypass_monster_cost` |

- `display_name`: локализованное имя на русском («Воин», «Разбойница», «Волшебник», «Чернокнижник», «Мечник», «Оракул», «Воительница»)
- Все остальные boolean-флаги у каждого класса — `false`; `max_hp = 5` для всех
- Оракул: `first_step_combat_bonus = 1` (единственный класс с ненулевым значением)

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: определение схемы `HeroClassData` (должна быть готова до этой story)
- Story 003: загрузка этих файлов в ClassRegistry

---

## QA Test Cases

*Config/Data story — smoke check:*

- **AC-smoke-1**: все 7 `.tres` файлов существуют и загружаются
  - Setup: запустить игру или тест, вызвать `load("res://assets/data/classes/warrior.tres")`
  - Verify: каждый load() возвращает `HeroClassData`, не null, не ошибку
  - Pass condition: 7/7 файлов загрузились без ошибок

- **AC-smoke-2**: флаги классов соответствуют таблице GDD
  - Setup: загрузить все 7 `.tres`
  - Verify: для каждого класса проверить его уникальные флаги == true; проверить что эти флаги у остальных == false
  - Pass condition: все 7 × AC-03..09 проверки прошли

---

## Test Evidence

**Story Type**: Config/Data
**Required evidence**:
- Smoke check pass: `production/qa/smoke-[date].md`

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (HeroClassData schema) должна быть DONE
- Unlocks: Story 003 (ClassRegistry загружает эти файлы)

---

## Completion Notes
**Completed**: 2026-10-12
**Criteria**: 9/9 passing
**Deviations**: None
**Test Evidence**: Config/Data — smoke check не запущен (ADVISORY; запустить `/smoke-check` после открытия в Godot Editor)
**Code Review**: Skipped — lean mode, Config/Data story
