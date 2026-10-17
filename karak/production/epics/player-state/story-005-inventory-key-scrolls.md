# Story 005: Inventory — Key, Scrolls, Accessors

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
**ADR Decision Summary**: get_scrolls() accessor обязателен для LootSystem (FIFO замена). Ключ — одиночный nullable слот; set_key/remove_key с guard'ами. Scrolls — max 3 слота с аналогичными add/remove/replace методами.

**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: Нет post-cutoff API — чистая GDScript логика.

**Control Manifest Rules (Core layer)**:
- Required: `get_scrolls() → Array[ItemData]` обязателен (ADR-0013)
- Required: `set_key(null)` при занятом слоте → `item_removed` сигнал (AC-22, ADR-0002)
- Forbidden: PlayerState не решает какой свиток заменить — это LootSystem FIFO (ADR-0013)

---

## Acceptance Criteria

*From GDD `design/gdd/player-state.md`, scoped to this story:*

- [ ] AC-19: `add_scroll` при 3/3 занятых слотах → возвращает false, scrolls.size()==3
- [ ] AC-20: `set_key(new_key)` при `key != null` → push_error, key не изменился
- [ ] AC-21: `set_key(null)` при `key == null` → no-op, сигналы не испускаются
- [ ] AC-22: `set_key(null)` при `key == some_key` → key==null, `item_removed(some_key, "key")` испущен *(Integration)*
- [ ] AC-33: `remove_key()` при `key != null` → key==null, `item_removed(some_key, "key")` испущен
- [ ] AC-34: `remove_key()` при `key == null` → no-op, сигналы не испускаются
- [ ] AC-35: `has_key` property отражает наличие ключа корректно

---

## Implementation Notes

*Derived from ADR-0003 + ADR-0013 Implementation Guidelines:*

Добавить в `src/foundation/player_state.gd`:

```gdscript
const KEY_SLOTS: int = 1
const SCROLL_SLOTS: int = 3

# --- Ключ ---

func set_key(item: ItemData) -> void:
    if item != null and key != null:
        push_error("set_key: key slot already occupied")
        return
    if item == null and key == null:
        return  # no-op (AC-21)
    if item == null:
        # Удаление ключа (AC-22)
        var old_key: ItemData = key
        key = null
        item_removed.emit(old_key, "key")
        return
    # Добавление ключа
    key = item
    item_added.emit(key, "key")

func remove_key() -> void:
    if key == null:
        return  # no-op (AC-34)
    var old_key: ItemData = key
    key = null
    item_removed.emit(old_key, "key")

# has_key — геттер-свойство (объявлен в story-001 skeleton):
# var has_key: bool:
#     get: return key != null

# --- Свитки ---

func get_scrolls() -> Array[ItemData]:
    return scrolls  # pure reader (ADR-0013 требует этот accessor)

func add_scroll(item: ItemData) -> bool:
    if scrolls.size() >= SCROLL_SLOTS:
        return false
    scrolls.append(item)
    item_added.emit(item, "scroll")
    return true

func remove_scroll(item: ItemData) -> void:
    var idx: int = scrolls.find(item)
    if idx == -1:
        push_error("remove_scroll: item not found in scrolls")
        return
    scrolls.remove_at(idx)
    item_removed.emit(item, "scroll")

func replace_scroll(old: ItemData, new_item: ItemData) -> void:
    var idx: int = scrolls.find(old)
    if idx == -1:
        push_error("replace_scroll: old item not found in scrolls")
        return
    scrolls[idx] = new_item
    item_removed.emit(old, "scroll")
    item_added.emit(new_item, "scroll")
```

**ADR-0013 FIFO для свитков:** LootSystem вызывает `replace_scroll(get_scrolls()[0], new_item)` — PlayerState не выбирает какой свиток заменить.

---

## Out of Scope

- Story 001: объявление scrolls, key, has_key полей
- Story 004: weapons — отдельная история с аналогичным паттерном
- LootSystem: FIFO-выбор какого свитка заменить — не PlayerState

---

## QA Test Cases

- **AC-19**: add_scroll при заполненных слотах
  - Given: scrolls.size()==3
  - When: `add_scroll(scroll_new)`
  - Then: возвращает false, scrolls.size()==3

- **AC-20**: set_key при занятом слоте
  - Given: `key != null`
  - When: `set_key(new_key)` где new_key != null
  - Then: push_error вызван, key не изменился

- **AC-21**: set_key(null) при пустом слоте
  - Given: `key == null`
  - When: `set_key(null)`
  - Then: key==null, `item_added` и `item_removed` НЕ испущены

- **AC-22**: set_key(null) при занятом слоте *(Integration)*
  - Given: `key == some_key`; стаб-подписчик подключён к item_removed
  - When: `set_key(null)`
  - Then: key==null, стаб получил `item_removed(some_key, "key")`

- **AC-33**: remove_key при наличии ключа
  - Given: `key == some_key`
  - When: `remove_key()`
  - Then: `has_key==false`, `key==null`, `item_removed(some_key, "key")` испущен

- **AC-34**: remove_key при пустом слоте
  - Given: `key == null`
  - When: `remove_key()`
  - Then: `has_key==false`, сигналы не испущены

- **AC-35**: has_key отражает наличие
  - Given: PlayerState без ключа
  - When: `set_key(some_key)`
  - Then: `has_key==true`
  - When: `remove_key()`
  - Then: `has_key==false`
  - Edge cases: `set_key(null)` при занятом слоте → `has_key==false` после

---

## Test Evidence

**Story Type**: Logic + Integration (AC-22)
**Required evidence**:
- `tests/unit/player_state/player_state_key_scrolls_test.gd` — unit тесты AC-19..AC-21, AC-33..AC-35
- `tests/integration/player_state/player_state_key_signals_test.gd` — integration тест AC-22

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (DONE) — поля scrolls, key, has_key, сигналы
- Unlocks: Story 006

## Completion Notes
**Completed**: 2026-10-17
**Criteria**: 7/7 passing
**Deviations**: ADVISORY — story notes использовали "key"/"scroll" (String) как slot_type в псевдокоде; реализовано с SLOT_KEY=1, SLOT_SCROLL=2 (int) согласно ADR-0007. Поведение идентично. Doc-комментарий к KEY_SLOTS неточен (написано "используется в guard", guard через `key != null`) — принято без фиксации в tech debt.
**Test Evidence**: Logic+Integration — unit: tests/unit/player_state/player_state_key_scrolls_test.gd (7 тестов), integration: tests/integration/player_state/player_state_key_signals_test.gd (2 теста)
**Code Review**: Complete — APPROVED WITH SUGGESTIONS (lean mode)
