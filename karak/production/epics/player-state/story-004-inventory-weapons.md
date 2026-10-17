# Story 004: Inventory — Weapons, attack_bonus cache, get_weapons

> **Epic**: PlayerState
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-10-12

## Context

**GDD**: `design/gdd/player-state.md`
**Requirement**: `TR-player-state-006`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003: PlayerState as Node; ADR-0013: Loot Weapon Replacement Strategy
**ADR Decision Summary**: PlayerState предоставляет `get_weapons() → Array[ItemData]` и `get_scrolls()` accessors. LootSystem читает их для определения слабейшего оружия. attack_bonus — кэш суммы attack_bonus всех оружий, пересчитывается при любом изменении оружейных слотов.

**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: Array[ItemData] typed array — стабилен с Godot 4.0. Нет post-cutoff API.

**Control Manifest Rules (Core layer)**:
- Required: `get_weapons() → Array[ItemData]` и `get_scrolls() → Array[ItemData]` обязательны (ADR-0013)
- Required: replace_weapon испускает `item_removed(old)` + `item_added(new)` (AC-17, ADR-0002)
- Forbidden: PlayerState не решает какое оружие заменить — это LootSystem (ADR-0013)

---

## Acceptance Criteria

*From GDD `design/gdd/player-state.md`, scoped to this story:*

- [ ] AC-02: weapon(+2) + weapon(+1) → `get_attack_bonus()==3`
- [ ] AC-03: weapon(+2) + scroll(+3) → `get_attack_bonus()==2` (свитки не в формуле)
- [ ] AC-04: добавить второе оружие → attack_bonus пересчитан немедленно
- [ ] AC-05: `replace_weapon(+1, +4)` при двух оружиях → `get_attack_bonus()==6`
- [ ] AC-06: пустой weapons → `get_attack_bonus()==0`
- [ ] AC-16: `add_weapon` при 2/2 → возвращает false, weapons.size()==2, attack_bonus не изменился
- [ ] AC-17: `replace_weapon(old, new)` → `item_removed(old, "weapon")` + `item_added(new, "weapon")` испущены *(Integration test)*
- [ ] AC-18: `replace_weapon(unknown, new)` → push_error, weapons не изменён

---

## Implementation Notes

*Derived from ADR-0003 + ADR-0013 Implementation Guidelines:*

Добавить в `src/foundation/player_state.gd`:

```gdscript
const WEAPON_SLOTS: int = 2

func get_attack_bonus() -> int:
    return attack_bonus

func get_weapons() -> Array[ItemData]:
    return weapons  # pure reader, без копирования

func add_weapon(item: ItemData) -> bool:
    if weapons.size() >= WEAPON_SLOTS:
        return false
    weapons.append(item)
    _recalculate_attack_bonus()
    item_added.emit(item, "weapon")
    return true

func replace_weapon(old: ItemData, new_item: ItemData) -> void:
    var idx: int = weapons.find(old)
    if idx == -1:
        push_error("replace_weapon: old item not found in weapons")
        return
    weapons[idx] = new_item
    _recalculate_attack_bonus()
    item_removed.emit(old, "weapon")
    item_added.emit(new_item, "weapon")

func _recalculate_attack_bonus() -> void:
    # Формула (GDD): attack_bonus = Σ weapon.attack_bonus для всех weapon в weapons
    var bonus: int = 0
    for w: ItemData in weapons:
        bonus += w.attack_bonus
    attack_bonus = bonus
```

**Формула attack_bonus (GDD):** `attack_bonus = Σ weapon.attack_bonus` — только оружие, не свитки (AC-03).

**EC-10 (GDD):** пустой weapons — `attack_bonus=0`. Валидное начальное состояние.

---

## Out of Scope

- Story 001: объявление weapons, attack_bonus полей
- Story 005: set_key(), add/remove_scroll() — отдельная история
- ADR-0013 алгоритм выбора слабейшего оружия — реализуется в LootSystem, не здесь

---

## QA Test Cases

- **AC-02**: attack_bonus с двумя оружиями
  - Given: PlayerState с пустым weapons
  - When: `add_weapon(weapon_a)` (attack_bonus=2), `add_weapon(weapon_b)` (attack_bonus=1)
  - Then: `get_attack_bonus()==3`

- **AC-03**: attack_bonus не включает свитки
  - Given: одно оружие (+2) в weapons, один свиток (combat_bonus=3) в scrolls
  - When: `get_attack_bonus()`
  - Then: возвращает 2

- **AC-04**: attack_bonus пересчитывается немедленно
  - Given: одно оружие (+1) → attack_bonus==1
  - When: `add_weapon(weapon_b)` (attack_bonus=3)
  - Then: `get_attack_bonus()==4` немедленно

- **AC-05**: attack_bonus после replace_weapon
  - Given: weapons=[w1(+2), w2(+1)] → attack_bonus==3
  - When: `replace_weapon(w2, w3)` где w3.attack_bonus=4
  - Then: `get_attack_bonus()==6`

- **AC-06**: пустой weapons
  - Given: PlayerState только создан, weapons==[]
  - When: `get_attack_bonus()`
  - Then: 0

- **AC-16**: add_weapon при заполненных слотах
  - Given: weapons.size()==2
  - When: `add_weapon(weapon_c)`
  - Then: возвращает false, weapons.size()==2, attack_bonus не изменился

- **AC-17**: replace_weapon испускает сигналы *(Integration)*
  - Given: weapon_old в weapons; стаб-подписчик подключён к item_removed и item_added
  - When: `replace_weapon(weapon_old, weapon_new)`
  - Then: стаб получил `item_removed(weapon_old, "weapon")` и `item_added(weapon_new, "weapon")`
  - Edge cases: убедиться что old отсутствует, new присутствует

- **AC-18**: replace_weapon с невалидным old
  - Given: weapons==[weapon_a]
  - When: `replace_weapon(weapon_unknown, weapon_new)`
  - Then: push_error вызван, weapons==[weapon_a], attack_bonus не изменился

---

## Test Evidence

**Story Type**: Logic + Integration (AC-17)
**Required evidence**:
- `tests/unit/player_state/player_state_weapons_test.gd` — unit тесты AC-02..AC-06, AC-16, AC-18
- `tests/integration/player_state/player_state_weapon_signals_test.gd` — integration тест AC-17

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (DONE) — поля weapons, attack_bonus, сигналы item_added/item_removed
- Unlocks: Story 005 (scrolls — аналогичный паттерн)

---

## Completion Notes
**Completed**: 2026-10-17
**Criteria**: 8/8 passing
**Deviations**: ADVISORY — story notes использовали `"weapon"` (String) для slot_type; реализовано с `SLOT_WEAPON = 0` (int) per ADR-0007. Корректное решение: сигнал объявлен `slot_type: int`.
**Test Evidence**: Logic+Integration: `tests/unit/player_state/player_state_weapons_test.gd` (8 тестов), `tests/integration/player_state/player_state_weapon_signals_test.gd` (3 теста)
**Code Review**: Complete (APPROVED WITH SUGGESTIONS — исправлен `StringName(...)` паттерн в test helpers)
