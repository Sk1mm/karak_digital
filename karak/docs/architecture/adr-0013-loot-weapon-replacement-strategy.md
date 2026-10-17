# ADR-0013: LootSystem Weapon Replacement Strategy

## Status
Accepted

## Date
2026-10-11

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.2 |
| **Domain** | Core (Game Logic / GDScript) |
| **Knowledge Risk** | LOW — pure GDScript Array access and comparison; no engine APIs |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md` |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | None |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0003 (PlayerState API — `add_weapon()`, `replace_weapon()`), ADR-0008 (stateless Feature systems) |
| **Enables** | None |
| **Blocks** | LootSystem story for TR-loot-003 (unblocked by this ADR) |
| **Ordering Note** | Must be Accepted before LootSystem TR-loot-003 story is created |

## Context

### Problem Statement
When a player picks up a weapon and both weapon slots (2/2) are occupied, a replacement decision is required. The GDD defines `PlayerState.replace_weapon(old, new)` as the API but does not specify: who selects the item to replace, and by what criterion.

### Constraints
- LootSystem is stateless (ADR-0008): cannot store a "pending replacement" across frames
- Must always emit `item_acquired` to exit `AWAITING_LOOT` phase in TurnManager
- PlayerState owns inventory mutation (`replace_weapon` is PlayerState's responsibility)
- Replacement must be immediate and deterministic — no UI pause required

### Requirements
- Must always produce a valid post-replacement inventory state
- Must always emit `item_acquired` regardless of replacement outcome
- Must handle the edge case: `get_weapons()` returns an empty array (defensive guard required)

## Decision

**Automatic replacement of the weakest weapon** (lowest `attack_bonus` field from `ItemData`). LootSystem reads `attack_bonus` from each current weapon and replaces the one with the lowest value. **Tie-break rule**: replace index 0 (first slot / oldest acquired). This is deterministic and requires no player input.

### Replacement Algorithm

```gdscript
# In LootSystem, called when add_weapon(new_item) returns false (slots full):
func _replace_weakest_weapon(player: PlayerState, new_item: ItemData) -> void:
    var weapons: Array[ItemData] = player.get_weapons()
    if weapons.is_empty():
        # Defensive guard: should not happen if add_weapon returned false (slots full)
        # but protects against inconsistent PlayerState
        push_error("_replace_weakest_weapon: player has no weapons but slots reported full")
        item_acquired.emit(player, new_item)
        return
    var weakest: ItemData = weapons[0]
    for w in weapons:
        if w.attack_bonus < weakest.attack_bonus:
            weakest = w
    # Tie-break: if multiple weapons share the lowest attack_bonus, 'weakest'
    # remains weapons[0] (first slot) — deterministic by iteration order
    player.replace_weapon(weakest, new_item)
    item_acquired.emit(player, new_item)
```

### No Upgrade Guard (Intentional)

LootSystem does NOT check whether `new_item.attack_bonus > weakest.attack_bonus`. Even if the new item is weaker than both current weapons, it replaces the weakest. Rationale: the drop table is cumulative (Axe drops from King Skeleton, a harder monster than Rat's Dagger), so in practice all pickups are lateral or better. Enforcing a minimum-upgrade check would add complexity for a case that is game-design impossible at MVP scope.

### Scroll Replacement Rule

Scrolls use **FIFO**: replace the scroll at index 0 (oldest acquired). Scrolls have no `attack_bonus` analogue — the FIFO rule requires no comparison logic.

```gdscript
func _replace_oldest_scroll(player: PlayerState, new_item: ItemData) -> void:
    var scrolls: Array[ItemData] = player.get_scrolls()
    if scrolls.is_empty():
        push_error("_replace_oldest_scroll: player has no scrolls but slots reported full")
        item_acquired.emit(player, new_item)
        return
    player.replace_scroll(scrolls[0], new_item)  # scrolls[0] = oldest
    item_acquired.emit(player, new_item)
```

### New PlayerState Methods Required

This ADR adds two accessor methods to PlayerState that must be added during PlayerState implementation:

```gdscript
func get_weapons() -> Array[ItemData]   # returns current weapon slots (0–2 items)
func get_scrolls() -> Array[ItemData]   # returns current scroll slots (0–3 items)
```

These are pure readers — no state mutation.

### Key Interfaces

```gdscript
# PlayerState (existing — ADR-0003; get_weapons/get_scrolls added by this ADR)
func add_weapon(item: ItemData) -> bool     # false = slots full
func replace_weapon(old: ItemData, new: ItemData) -> void
func get_weapons() -> Array[ItemData]       # NEW — added by this ADR
func add_scroll(item: ItemData) -> bool     # false = slots full
func replace_scroll(old: ItemData, new: ItemData) -> void
func get_scrolls() -> Array[ItemData]       # NEW — added by this ADR

# ItemData field
var attack_bonus: int  # defined in ItemDatabase GDD; 0 for scrolls/keys
```

## Alternatives Considered

### Alternative A: Player Choice UI
- **Description**: Pause in `AWAITING_LOOT`, show comparison UI, player chooses which weapon to drop
- **Pros**: Player agency; more strategic depth
- **Cons**: Violates stateless constraint (ADR-0008) — LootSystem would need to hold "pending choice" state; requires new FSM state in TurnManager (`AWAITING_REPLACE`); UX design cost
- **Rejection Reason**: Stateless constraint (ADR-0008) prohibits holding state between frames; the added complexity is disproportionate for MVP

### Alternative B: Discard New Item (No Replacement)
- **Description**: If slots full, new weapon is simply dropped (not picked up)
- **Pros**: Simplest implementation; no replacement logic needed
- **Cons**: Player loses combat reward; punishes having a good inventory; contradicts Pillar 2 ("Сила ощутима")
- **Rejection Reason**: Combat victories must always feel rewarding; the player killed a monster and deserves the item

## Consequences

### Positive
- LootSystem remains stateless
- Always emits `item_acquired` — TurnManager never hangs in `AWAITING_LOOT`
- Deterministic and unit-testable (weakest by `attack_bonus`, tie-break index 0)

### Negative
- Player has no agency over which weapon is replaced
- Requires `ItemData.attack_bonus` to be a reliable comparison field
- `get_weapons()` / `get_scrolls()` must be added to PlayerState implementation

### Risks
- **Risk**: `weapons[0]` accessed without bounds check → crash on empty array
  - **Mitigation**: `is_empty()` guard added (see algorithm above); `push_error` logs the inconsistency
- **Risk**: Two weapons have identical `attack_bonus` — which is dropped?
  - **Mitigation**: Tie-break = index 0 (first slot); deterministic, documented, unit-tested
- **Risk**: Future scroll types with meaningful ordering (e.g., scroll with cooldown) — FIFO rule may not be optimal
  - **Mitigation**: Acceptable at MVP; revisit with `/architecture-decision` if scroll depth increases

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| loot-system.md | TR-loot-003: Item replacement logic when weapon slots are full | Establishes automatic weakest-weapon replacement by `attack_bonus`; tie-break index 0; scroll FIFO replacement; adds `get_weapons()`/`get_scrolls()` accessors to PlayerState |

## Performance Implications
- **CPU**: O(N) over 2 weapons — negligible
- **Memory**: No new allocations

## Migration Plan
- PlayerState must add `get_weapons() -> Array[ItemData]` and `get_scrolls() -> Array[ItemData]` accessor methods
- Note in PlayerState GDD/story that these methods are required by this ADR

## Validation Criteria
- Unit test: pickup weapon, slots full (2/2) → weakest by `attack_bonus` removed, new weapon added
- Unit test: tie in `attack_bonus` → index 0 slot replaced
- Unit test: `get_weapons()` returns empty array → `push_error` called, `item_acquired` still emitted
- grep: no `var` fields (excluding `@export`/`@onready`) in `loot_system.gd`

## Related Decisions
- ADR-0003: PlayerState as Node — source of `replace_weapon()` API
- ADR-0008: Stateless Feature Systems — LootSystem stateless constraint
