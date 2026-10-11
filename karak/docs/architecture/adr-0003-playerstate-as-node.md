# ADR-0003: PlayerState as Node

## Status
Accepted

## Date
2026-10-10

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.2 (GDScript) |
| **Domain** | Core |
| **Knowledge Risk** | LOW — Node and Resource base classes stable since Godot 4.0 |
| **References Consulted** | `docs/engine-reference/godot/current-best-practices.md`, `docs/engine-reference/godot/deprecated-apis.md` |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | Confirm two PlayerState Node instances in GameScene have fully independent state (modifying hp of one does not affect the other) |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (Autoload Strategy — establishes PlayerState is not an Autoload) |
| **Enables** | ADR-0002 (Signal Wiring — PlayerState signals are the Core→Presentation backbone) |
| **Blocks** | PlayerState implementation epic |
| **Ordering Note** | Foundation ADR. PlayerState is the most-depended-on system (8 downstream). Decide before implementing any other system. |

## Context

### Problem Statement

`PlayerState` stores mutable game state for each player: HP, position, inventory,
VP, knockout flag, and character class. It emits 6 typed signals consumed by HUD,
InventoryUI, KnockoutSystem, and TurnManager. There are exactly 2 instances per
session (2-player hotseat MVP; up to 5 in full version).

The choice between `extends Resource` and `extends Node` affects signal lifecycle,
multiplicity safety, testability, and future save/load.

### Constraints

- MVP: 2 player instances; no save/load
- Full version: up to 5 players; save/load planned post-MVP
- PlayerState emits 6 signals; listeners must auto-disconnect when scene unloads
- PlayerState has an `_ready()` use case: initialise HP from `character_class.max_hp`

### Requirements

- Must: 2 fully independent instances with no shared mutable state
- Must: Signals auto-disconnect on scene unload (no manual cleanup needed)
- Must: Inspector must make it obvious these are two separate objects
- Should: Compatible with future save/load (can add serialisation layer)

## Decision

**`PlayerState extends Node`** — in-scene Node, not Resource.

`HeroClassData extends Resource` — the static class definition (max_hp, flags,
display name) remains a Resource as it is genuinely read-only data.

### Type Separation

```gdscript
# HeroClassData — static, read-only definition of a hero class
class_name HeroClassData
extends Resource

@export var id: StringName
@export var display_name: String
@export var max_hp: int = 5
@export var auto_reroll_on_one: bool = false
@export var can_reroll_both_dice: bool = false
# ... all other class flags


# PlayerState — mutable runtime state for one player
class_name PlayerState
extends Node

signal hp_changed(new_hp: int)
signal vp_changed(new_vp: float)
signal item_added(item: ItemData, slot_type: int)
signal item_removed(item: ItemData, slot_type: int)
signal knocked_out()
signal knockout_cleared()

@export var character_class: HeroClassData   ## assigned in Inspector per player

var hp: int
var vp: float = 0.0
var position: Vector2i
var previous_position: Vector2i
var weapons: Array[ItemData] = []
var key: ItemData
var scrolls: Array[ItemData] = []
var skip_next_turn: bool = false

func _ready() -> void:
    hp = character_class.max_hp   ## initialise from class definition
```

### Architecture Diagram

```
GameScene
  ├── PlayerState[0]   (Node — player 1's runtime state)
  │     @export character_class → HeroClassData("warrior")   [Resource]
  │     var hp = 5 (independent)
  │
  └── PlayerState[1]   (Node — player 2's runtime state)
        @export character_class → HeroClassData("wizard")    [Resource]
        var hp = 5 (independent)

Both nodes visible in Scene Tree debugger.
HeroClassData resources can be shared (read-only) — no sharing risk.
```

## Alternatives Considered

### Alternative A: PlayerState extends Resource

- **Description**: PlayerState is a `.tres` Resource file; signals declared as
  `signal hp_changed(new_hp: int)` on the Resource.
- **Pros**: Serializable to `.tres` out of the box; lightweight.
- **Cons**:
  1. No `_ready()` lifecycle — HP cannot be initialised from `character_class.max_hp`
     automatically; requires manual init call.
  2. Signal connections on Resource do not auto-disconnect when scene unloads —
     dangling connections must be managed manually.
  3. Two players require two separate `.tres` files or two `duplicate()`d instances.
     If the same `.tres` is accidentally assigned to both players in Inspector,
     both share identical mutable state — a silent catastrophic bug.
  4. Methods with side effects (`take_damage()`, `set_position()`) on a Resource
     break the implicit contract that Resources are data containers.
- **Rejection Reason**: No lifecycle; accidental sharing risk; manual signal cleanup.

### Alternative B: PlayerState as Dictionary

- **Description**: PlayerState is a `Dictionary` passed between systems.
- **Pros**: No class needed; trivially serializable.
- **Cons**: No static typing; no signals; no encapsulation. Violates GDScript
  coding standards (typed classes required).
- **Rejection Reason**: No signals; not idiomatic.

### Alternative C: PlayerState extends Node + thin PlayerSaveData Resource

- **Description**: `PlayerState extends Node` for runtime; `PlayerSaveData extends Resource`
  added later for save/load.
- **Pros**: Same as chosen decision; explicitly plans for save/load.
- **Cons**: Same as chosen decision; just a naming note.
- **Relationship to chosen**: This IS the chosen pattern — `PlayerSaveData` will be
  added post-MVP. Not a separate alternative.

## Consequences

### Positive
- Two Node instances in Scene Tree are visually distinct and inspectable in debugger
- Signals auto-disconnect when GameScene is freed — no manual cleanup
- `_ready()` initialises HP from character_class — no separate init call needed
- No accidental sharing: two separate Node instances in scene tree
- Future save/load: add `func to_save_data() -> PlayerSaveData` without changing
  the Node architecture

### Negative
- Slightly heavier than Resource (Node has scene-tree overhead)
- Save/load requires a separate serialisation layer (not built in) — accepted for MVP

### Risks
- **Risk**: Developer instantiates PlayerState via `PlayerState.new()` instead of
  placing it in the scene — bypasses Inspector assignment of `character_class`.
  **Mitigation**: `assert(character_class != null, "PlayerState requires character_class set in Inspector")` in `_ready()`.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| `player-state.md` | TR-ps-001..011: HP, position, inventory, VP, knockout flag — all mutable | `extends Node` with `var` fields; no sharing between instances |
| `player-state.md` | TR-ps-012..017: 6 typed signals | Typed signal declarations; auto-disconnect via Node lifecycle |
| `class-system.md` | TR-cs-002: max_hp field on class | `HeroClassData.max_hp` (Resource); `PlayerState._ready()` reads it |
| `hud.md` | EC-HUD-01: `knocked_out` signal arrives while panel is ACTIVE | Typed `knocked_out()` signal on Node; HUD wired in `_wire_signals()` |

## Performance Implications
- **CPU**: Negligible — `Node` overhead vs `Resource` is immaterial for 2 instances
- **Memory**: ~KB per instance (Node overhead + 6 signals + Array slots for inventory)
- **Load Time**: `_ready()` initialises HP in one assignment

## Migration Plan

No existing code — greenfield. Two `PlayerState` nodes placed in GameScene, both
assigned their respective `HeroClassData` resources in Inspector before first run.

## Validation Criteria

1. Two `PlayerState` nodes exist in GameScene scene tree (not as Autoloads)
2. `player_state_0.character_class != player_state_1.character_class` (different classes assigned)
3. `player_state_0.take_damage(1)` does not change `player_state_1.hp`
4. `player_state_0.hp_changed` signal fires and is received by HUD without error
5. Freeing GameScene frees both PlayerState nodes; no signals remain connected after free

## Related Decisions
- ADR-0001: Autoload Strategy (PlayerState not Autoload — multiple instances required)
- ADR-0002: Signal Wiring Pattern (PlayerState signals are Core→Presentation backbone)
- `docs/architecture/architecture.md` — Core Layer module ownership
