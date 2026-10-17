# ADR-0015: Loose Key Lifecycle — State Ownership and Pickup Protocol

## Status
Accepted

## Date
2026-10-11

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.2 |
| **Domain** | Core |
| **Knowledge Risk** | LOW — 2D GDScript only; no post-cutoff APIs involved |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `docs/engine-reference/godot/breaking-changes.md`, `docs/engine-reference/godot/deprecated-apis.md` |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | None — uses only stable Dictionary, bool, and method call patterns. Confirm `DungeonCell` uses no `extends` clause or `extends RefCounted` (not `extends Object`) when implemented. |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0003 (PlayerState API — `has_key`, `set_key()`), ADR-0004 (TileSystem — DungeonCell structure), ADR-0008 (LootSystem stateless rule) |
| **Enables** | None |
| **Blocks** | None |
| **Ordering Note** | Must be implemented before LootSystem story. TileSystem story must include `place_loose_key`, `remove_loose_key`, `has_loose_key` methods and `loose_key: bool` field in DungeonCell. |

## Context

### Problem Statement

При победе над Скелетом-ключником (`&"skeleton_key"`) LootSystem должен выдать ключ игроку. Если у игрока уже есть ключ — ключ кладётся на пол конкретного тайла. Этот ключ существует как многоходовое состояние: он сохраняется между ходами, подбирается любым игроком без ключа при входе на тайл, и независим от очистки тайла. Без явного архитектурного решения неясно: кто владеет этим состоянием, как оно создаётся и уничтожается, что происходит при нескольких ключах на полу одновременно, при очистке тайла, при входе обоих игроков на тот же тайл.

### Constraints

- LootSystem **обязан** оставаться stateless (ADR-0008, fp-015) — никаких `var`-полей, накапливающих состояние между событиями
- TileSystem — единственный владелец состояния подземелья (ADR-0004, so-005)
- Cross-system связи через сигналы или прямые вызовы (single-caller/single-receiver) в `_wire_signals()`
- Один ключ с пола за раз на один тайл — `loose_key` как boolean, не счётчик

### Requirements

- Ключ на полу персистируется между ходами до подбора
- LootSystem остаётся полностью stateless
- Подбор автоматический при входе на тайл (без UI-выбора)
- `clear_cell()` не уничтожает лежащий ключ (`loose_key` и `is_cleared` независимы)
- Поддерживает одновременное существование нескольких ключей на полу на разных тайлах
- `item_acquired` эмитируется в любом исходе (выдача игроку ИЛИ кладётся на пол) — TurnManager не зависает в AWAITING_LOOT

## Decision

**TileSystem владеет `loose_key`-состоянием через boolean поле в DungeonCell. LootSystem — чисто stateless coordinator: вызывает TileSystem-методы и эмитирует сигнал, не накапливая state.**

### Детали решения

**1. DungeonCell расширяется одним полем:**

```gdscript
class_name DungeonCell
# ... существующие поля ...
var loose_key: bool = false
## Ключ лежит на тайле (Скелет-ключник убит, игрок не подобрал).
## Независим от is_cleared и is_revealed — отдельный lifecycle.
```

**2. TileSystem — три новых метода (все с guard на отсутствующую позицию):**

```gdscript
func has_loose_key(pos: Vector2i) -> bool:
    ## Возвращает false для позиций вне grid — безопасно для LootSystem pickup guard.
    if not _cells.has(pos):
        return false
    return _cells[pos].loose_key

func place_loose_key(pos: Vector2i) -> void:
    ## Idempotent: если loose_key уже true — no-op.
    ## Guard: позиция должна быть в grid (уже размещённый тайл).
    if not _cells.has(pos):
        push_warning("place_loose_key: no cell at %s" % pos)
        return
    _cells[pos].loose_key = true

func remove_loose_key(pos: Vector2i) -> void:
    ## Guard: позиция должна быть в grid.
    if not _cells.has(pos):
        push_warning("remove_loose_key: no cell at %s" % pos)
        return
    _cells[pos].loose_key = false
```

**3. LootSystem — путь размещения (`item_dropped`):**

```gdscript
func _on_item_dropped(player: PlayerState, monster_id: StringName) -> void:
    var item_id: StringName = DROP_TABLE.get(monster_id, &"")
    if item_id == &"":
        item_acquired.emit(player, null)  ## Ghost/Dragon: нет лута → TurnManager выходит из AWAITING_LOOT
        return

    var item: ItemData = ItemDatabase.get_item(item_id)

    match item.item_type:
        GameEnums.ItemType.KEY:
            if not player.has_key:
                player.set_key(item)
            else:
                tile_system.place_loose_key(player.get_position())
                ## Ключ на полу — не в инвентаре. item_acquired всё равно эмитируется ниже.
        GameEnums.ItemType.WEAPON:
            # ... weapon replacement per ADR-0013 ...
        GameEnums.ItemType.SCROLL:
            # ... scroll FIFO per ADR-0013 ...

    item_acquired.emit(player, item)
    ## item_acquired эмитируется для всех путей, включая place_loose_key.
    ## Это разблокирует TurnManager из AWAITING_LOOT — обязательный контракт (EC-03 loot-system.md).
```

**4. LootSystem — путь подбора (`cell_entered`):**

```gdscript
func _on_cell_entered(player: PlayerState, pos: Vector2i) -> void:
    if tile_system.has_loose_key(pos) and not player.has_key:
        var key_item: ItemData = ItemDatabase.get_item(&"key")
        player.set_key(key_item)
        tile_system.remove_loose_key(pos)
        item_acquired.emit(player, key_item)
        ## item_acquired здесь НЕ триггерит AWAITING_LOOT — это автоподбор при движении.
        ## TurnManager FSM в TURN_ACTIVE state игнорирует item_acquired (ADR-0008 FSM contract).
```

**5. Wiring в `GameScene._wire_signals()` — порядок имеет значение:**

```gdscript
## --- cell_entered wiring: LootSystem ПЕРЕД TurnManager ---
## Godot signal dispatch синхронный; LootSystem должен завершить pickup и эмитировать
## item_acquired ДО того, как TurnManager обработает cell_entered.
## Если TurnManager подключён первым — он обработает cell_entered на stale state.
movement_system.cell_entered.connect(loot_system._on_cell_entered)    ## FIRST
movement_system.cell_entered.connect(tile_reveal_vfx._on_cell_entered) ## (existing)
## TurnManager не подключается к cell_entered напрямую — он слушает turn_started и item_acquired.
```

### Architecture Diagram

```
[CombatSystem]
    └─ item_dropped(player, &"skeleton_key")
            │
            ▼
    [LootSystem._on_item_dropped]
        player.has_key == false → PlayerState.set_key(item)
        player.has_key == true  → TileSystem.place_loose_key(pos)  [idempotent]
        → emit item_acquired(player, item)  ← TurnManager выходит из AWAITING_LOOT

[MovementSystem]
    └─ cell_entered(player, pos)
            │
            ▼
    [LootSystem._on_cell_entered]   ← подключён ПЕРЕД другими cell_entered слушателями
        has_loose_key(pos) AND !player.has_key
        → PlayerState.set_key(key_item)
        → TileSystem.remove_loose_key(pos)
        → emit item_acquired(player, key_item)  ← TurnManager игнорирует (не в AWAITING_LOOT)

[Два ключа на разных тайлах одновременно — каждый DungeonCell независим]
cell(A).loose_key = true
cell(B).loose_key = true
→ Любой игрок без ключа, входящий на A или B, подберёт его
```

## Alternatives Considered

### Alternative B: LootSystem хранит Array[Vector2i] ключей на полу

- **Description**: LootSystem держит `var floor_keys: Array[Vector2i]` — список позиций с ключами, поддерживает count (несколько ключей на одной клетке)
- **Pros**: Поддерживает >1 ключа на одной позиции
- **Cons**: Нарушает ADR-0008 (LootSystem не может иметь persistent state). С 12 skeleton_key-монстрами в пуле — максимум 1 на тайл одновременно: второй бой на том же тайле невозможен, тайл уже cleared. Счётчик > 1 практически невозможен.
- **Rejection Reason**: Нарушает stateless rule (fp-015). Boolean достаточен.

### Alternative C: Ключ как Node2D entity

- **Description**: При броске ключа инстанцируется LooseKeyPickup (Node2D) в позицию тайла; Area2D подбирает автоматически
- **Pros**: Нативный визуал; Area2D auto-pickup
- **Cons**: Overengineered для bool-флага. Требует lifecycle management для Node-инстансов. Нарушает принцип TileSystem как единственного владельца состояния тайлов.
- **Rejection Reason**: Переусложнение. Визуальное отображение ключа на полу — задача TileRevealVFX rendering, не data layer.

## Consequences

### Positive

- LootSystem остаётся полностью stateless (ADR-0008 соблюдён)
- TileSystem — единственный источник истины для состояния тайлов (ADR-0004 соблюдён)
- `place_loose_key` идемпотентен — безопасно вызывать повторно
- Несколько ключей на разных тайлах одновременно поддерживается нативно
- Нет новых FSM-состояний в TurnManager — автоподбор прозрачен для хода

### Negative

- `item_acquired(player, key_item)` эмитируется при размещении ключа на полу (не только при выдаче в инвентарь). TurnManager получает сигнал в обоих случаях — его FSM корректно обрабатывает оба пути через state check.
- Порядок подключения сигналов в `_wire_signals()` становится значимым: LootSystem должен подключаться к `cell_entered` раньше других слушателей.

### Risks

- **R-1**: `item_acquired` при автоподборе попадает в TurnManager вне AWAITING_LOOT — TurnManager может ошибочно изменить state. **Митигация**: TurnManager FSM игнорирует `item_acquired` во всех state-ах кроме AWAITING_LOOT (ADR-0008 FSM contract). Тест: AC-10 loot-system.md.
- **R-2**: Godot сигналы синхронны — порядок обработки `cell_entered` важен. **Митигация**: LootSystem подключается первым в `_wire_signals()` с явным комментарием порядка. Тест: интеграционный тест на sequence ordering.
- **R-3**: `place_loose_key` вызывается на нераскрытом тайле (гипотетически). **Митигация**: бой требует revealed тайла; `item_dropped` эмитируется после `combat_resolved`, то есть после reveal. Guard с `push_warning` отловит нарушение в dev builds.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| loot-system.md Rule 4, EC-01 | Skeleton key floor placement when player already has key | `TileSystem.place_loose_key(player.get_position())` — idempotent, guarded |
| loot-system.md Rule 3 | Loose key auto-pickup on cell_entered | LootSystem._on_cell_entered: `has_loose_key(pos) and not player.has_key` guard |
| loot-system.md EC-06, AC-11 | Player with key enters tile with loose key — key stays | `not player.has_key` guard — explicit, testable condition |
| loot-system.md AC-09 | item_dropped + player.has_key → `has_loose_key(pos) == true` | `place_loose_key()` path in `_on_item_dropped` |
| loot-system.md AC-10 | Player without key enters tile with loose_key → pickup | `_on_cell_entered` path: `set_key` + `remove_loose_key` |
| loot-system.md EC-03, AC-13 | item_acquired always emitted (prevents AWAITING_LOOT hang) | `item_acquired.emit()` on all paths, including `place_loose_key` path |
| tile-system.md AC-13 | `place_loose_key` / `has_loose_key` / `remove_loose_key` contract | Three guarded methods defined with idempotency and preconditions |
| tile-system.md AC-15 | `loose_key` independent of `is_cleared` | `clear_cell()` does NOT touch `loose_key` field — separate lifecycle flags |

## Performance Implications

- **CPU**: Negligible — one Dictionary lookup per `cell_entered` event (O(1))
- **Memory**: +1 bool per DungeonCell ≈ +80 bytes total for full dungeon (80 cells × 1 byte)
- **Load Time**: None
- **Network**: N/A (local hotseat)

## Migration Plan

New ADR — TileSystem and LootSystem not yet implemented. No migration needed.

## Validation Criteria

- AC-09 (loot-system.md): `item_dropped` + `player.has_key == true` → `has_loose_key(pos) == true`
- AC-10 (loot-system.md): Player without key enters tile with `loose_key == true` → `has_key == true`, `has_loose_key == false`
- AC-11 (loot-system.md): Player WITH key enters tile with `loose_key == true` → state unchanged
- AC-13 (tile-system.md): `place_loose_key` → `has_loose_key == true`; `remove_loose_key` → `has_loose_key == false`
- AC-15 (tile-system.md): `clear_cell()` on tile with `loose_key == true` → `loose_key` unchanged
- Integration: `item_acquired` emitted on `place_loose_key` path → TurnManager exits AWAITING_LOOT correctly
- Integration: `item_acquired` emitted on auto-pickup path → TurnManager ignores (not in AWAITING_LOOT)

## Related Decisions

- ADR-0003: PlayerState as Node — defines `has_key: bool`, `set_key(item: ItemData)` API
- ADR-0004: TileSystem and TileMapLayer — DungeonCell structure (this ADR adds `loose_key` field)
- ADR-0008: Stateless Feature Systems — enforces LootSystem stateless rule; TurnManager FSM ignores out-of-state signals
- ADR-0013: Loot Weapon Replacement Strategy — sibling ADR governing other LootSystem paths
