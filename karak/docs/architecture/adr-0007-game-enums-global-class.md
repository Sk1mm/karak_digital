# ADR-0007: GameEnums Global Class

## Status
Accepted

## Date
2026-10-11

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.2 (GDScript) |
| **Domain** | Core |
| **Knowledge Risk** | LOW — `class_name`, GDScript enums, and enum-as-int in signals are stable since Godot 4.0 |
| **References Consulted** | `docs/engine-reference/godot/current-best-practices.md`, `docs/engine-reference/godot/deprecated-apis.md` |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | Confirm `GameEnums.Direction.NORTH` is accessible from any script without import; confirm enum values in signals are received as `int` |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (Autoload Strategy — establishes that GameEnums is NOT an Autoload) |
| **Enables** | All system implementations (enums used throughout) |
| **Blocks** | None — systems can implement before GameEnums is finalized, using raw ints as placeholders |
| **Ordering Note** | Should be written before any signal that uses enum parameters, to establish the int-in-signals convention. |

## Context

### Problem Statement

The project uses shared enumerations across many systems:
- `Direction` (NORTH/EAST/SOUTH/WEST) — used by TileSystem, MovementSystem, DungeonGenerator
- `ItemType` (WEAPON/KEY/SCROLL) — used by PlayerState, LootSystem, CombatSystem
- `ScrollType` (NONE/MAGIC_ATTACK/TELEPORT) — used by CombatSystem, PlayerState
- `CombatOutcome` (WIN/DRAW/LOSS) — used by CombatSystem, TurnManager
- `TileCategory` (CORRIDOR/ROOM/FOUNTAIN/FOUNTAIN_SECONDARY/PORTAL) — used by TileSystem, EncounterDispatcher
- `TileShape` (STRAIGHT/L_TURN/T_JUNCTION/CROSS) — used by TileSystem, DungeonGenerator
- `EventType` (MONSTER/CHEST) — used by TileSystem, EncounterDispatcher
- `RerollType` (NONE/BOTH/ONE_DIE) — used by CombatAction, CombatSystem

Where to put these enums so they are accessible across all 18 systems without
importing, without Autoload, and with full static type support?

### Constraints

- GDScript 4.x: enums defined inside a `class_name` class are globally accessible
  via `ClassName.EnumName.VALUE` without `preload` or `@export`
- Enums in GDScript signal parameters must be passed as `int` — typed signal params
  cannot use enum type directly (GDScript limitation)
- No Autoload for a pure-definition class — Autoloads carry runtime overhead and
  are for data/logic, not type definitions
- No instantiation — this is a pure namespace class

### Requirements

- Must: All enum definitions accessible from any script via `GameEnums.Direction.NORTH`
- Must: No import, no `preload`, no `@export` ref needed to use the enums
- Must: Document the int-in-signals convention for all enum signal parameters
- Should: Single file, single responsibility — only enum definitions, no logic

## Decision

**`GameEnums` is a `class_name` GDScript file with no `extends` (plain class),
containing only `enum` declarations.**

- Not an Autoload — no `Node` overhead, no singleton instance, no runtime cost
- Not imported — `class_name GameEnums` registers the name globally in GDScript;
  all scripts access `GameEnums.Direction.NORTH` without any import
- Enum values in signals are passed as `int` — receivers cast back to the enum type
  for comparisons: `if direction == GameEnums.Direction.NORTH:`

### Architecture Diagram

```
src/core/game_enums.gd
  class_name GameEnums
  (no extends, no instance, pure namespace)

  enum Direction      { NORTH, EAST, SOUTH, WEST }
  enum TileCategory   { CORRIDOR, ROOM, FOUNTAIN, FOUNTAIN_SECONDARY, PORTAL }
  enum TileShape      { STRAIGHT, L_TURN, T_JUNCTION, CROSS }
  enum EventType      { MONSTER, CHEST }
  enum ItemType       { WEAPON, KEY, SCROLL }
  enum ScrollType     { NONE, MAGIC_ATTACK, TELEPORT }
  enum CombatOutcome  { WIN, DRAW, LOSS }
  enum RerollType     { NONE, BOTH, ONE_DIE }

Access pattern (from any script, no import):
  GameEnums.Direction.NORTH
  GameEnums.TileCategory.CORRIDOR
  GameEnums.RerollType.BOTH
```

### Key Interfaces

```gdscript
# src/core/game_enums.gd
class_name GameEnums
## Pure enum namespace. No extends, no instance, no Autoload.
## Access from any script: GameEnums.Direction.NORTH

enum Direction {
    NORTH = 0,
    EAST  = 1,
    SOUTH = 2,
    WEST  = 3
}

enum TileCategory {
    CORRIDOR          = 0,
    ROOM              = 1,
    FOUNTAIN          = 2,
    FOUNTAIN_SECONDARY = 3,
    PORTAL            = 4
}

enum TileShape {
    STRAIGHT   = 0,
    L_TURN     = 1,
    T_JUNCTION = 2,
    CROSS      = 3
}

enum EventType {
    MONSTER = 0,
    CHEST   = 1
}

enum ItemType {
    WEAPON = 0,
    KEY    = 1,
    SCROLL = 2
}

enum ScrollType {
    NONE         = 0,
    MAGIC_ATTACK = 1,
    TELEPORT     = 2
}

enum CombatOutcome {
    WIN  = 0,
    DRAW = 1,
    LOSS = 2
}

enum RerollType {
    NONE    = 0,
    BOTH    = 1,
    ONE_DIE = 2
}
```

### Enum-in-Signals Convention

GDScript 4.x does not support enum types as typed signal parameters. Signal
declarations with enum parameters must use `int`:

```gdscript
# CORRECT — enum value passed as int
signal item_added(item: ItemData, item_type: int)      ## item_type: GameEnums.ItemType
signal cell_revealed(pos: Vector2i, category: int)     ## category: GameEnums.TileCategory

# WRONG — GDScript does not support enum types in signal declarations
signal item_added(item: ItemData, item_type: GameEnums.ItemType)  # compile error
```

Receivers cast back to the enum for readability:

```gdscript
func _on_item_added(item: ItemData, item_type: int) -> void:
    if item_type == GameEnums.ItemType.WEAPON:
        pass  # comparison works — enum values are ints
```

Comment every `int` signal parameter that represents an enum with `## [FieldName]: GameEnums.EnumType`.

## Alternatives Considered

### Alternative A: Enums defined inside each system class

- **Description**: Each system defines its own enums locally. `TileSystem` defines
  `TileCategory` and `TileShape`; `CombatSystem` defines `CombatOutcome`; etc.
- **Pros**: Locality — the enum is next to the code that uses it most.
- **Cons**: Cross-system enums (e.g., `Direction` used by TileSystem AND MovementSystem)
  must be either duplicated or one system must `preload` another's enum — tight coupling.
  Signals crossing system boundaries with enum parameters require the receiver to
  `preload` the emitter's script just for the enum. Creates implicit file dependencies.
- **Rejection Reason**: Cross-system enum sharing requires preload coupling. Violates
  clean layer boundaries.

### Alternative B: Enums in an Autoload

- **Description**: `GameEnums` registered as Project Settings → Autoload singleton.
- **Pros**: Globally accessible like `class_name` but with runtime lifecycle.
- **Cons**: Autoload carries Node overhead; Autoloads are for runtime data and logic
  (ADR-0001). A pure definition file with no state or behavior has no business being
  an Autoload. Forbidden by fp-001 (mutable_state_in_autoload) spirit — even a
  definition-only Autoload wastes the Autoload slot.
- **Rejection Reason**: Misuse of Autoload pattern. `class_name` achieves the same
  global access with zero runtime cost.

### Alternative C: One enum file per domain

- **Description**: `TileEnums.gd`, `CombatEnums.gd`, `ItemEnums.gd` etc.
- **Pros**: Smaller files; easier to find a specific enum.
- **Cons**: With 8 enums across 3 files, developers must remember which file each
  enum lives in. Adds cognitive overhead for minimal benefit at this project scale.
  One file with all enums is simpler.
- **Rejection Reason**: Complexity without benefit. If enums grow significantly post-MVP,
  splitting can be revisited.

## Consequences

### Positive
- All enums accessible globally via `GameEnums.EnumName.VALUE` — zero coupling
- No `preload` or `@export` required anywhere in the project for enum access
- Adding a new enum: one file edit, immediately accessible everywhere
- Pure definition file — no runtime cost, no GC, no scene tree entry

### Negative
- `class_name` namespace is global — `GameEnums` cannot be shadowed or mocked in tests
  (not a concern for enum definitions, but noted)
- Enum values in signals lose their type label — `int` in signal param requires
  comment discipline to stay readable

### Risks
- **Risk**: Developer adds a method or variable to `GameEnums.gd` (turns it into a logic class).
  **Mitigation**: Header comment: `## Pure enum namespace. No methods, no variables, no logic.`
  Code review enforces this.
- **Risk**: Two enums get the same value for different semantics (e.g., `Direction.NORTH == 0`
  and `TileShape.STRAIGHT == 0` — both 0 but different types).
  **Mitigation**: This is expected and correct — enum types are namespaced by their
  `GameEnums.EnumName` prefix. Never compare across enum types.
- **Risk**: `class_name GameEnums` conflicts with another file that also uses `class_name GameEnums`.
  **Mitigation**: GDScript raises a compile error on duplicate `class_name` — detected immediately.
  Only one `game_enums.gd` file may exist in the project.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| `tile-system.md` | TileCategory (5 values), TileShape (4 values), EventType (2 values) | Defined in `GameEnums` |
| `tile-system.md` | Direction enum for exit computation (`get_exits()` returns `Array[int]`) | `GameEnums.Direction` with explicit values N=0, E=1, S=2, W=3 |
| `combat-system.md` | CombatOutcome (WIN/DRAW/LOSS), RerollType (NONE/BOTH/ONE_DIE) | Defined in `GameEnums`; used by CombatAction (ADR-0006) |
| `player-state.md` | ItemType for slot routing in signals | `GameEnums.ItemType`; signal parameter documented as `int` |

## Performance Implications
- **CPU**: Zero — `class_name` is a compile-time construct; no runtime object created
- **Memory**: Zero — no instance, no Autoload node
- **Load Time**: File loaded once at engine startup with all other GDScript files

## Migration Plan

No existing code — greenfield. Create `src/core/game_enums.gd` before implementing
any system that uses cross-system enums.

## Validation Criteria

1. `GameEnums.Direction.NORTH` is accessible from `TileSystem.gd` without any `preload`
2. `GameEnums.RerollType.NONE == 0` evaluates to `true`
3. No `preload("res://src/core/game_enums.gd")` exists anywhere in the codebase —
   `class_name` global access makes preloading unnecessary
4. No `extends` clause in `game_enums.gd`
5. `GameEnums` is NOT listed in Project Settings → Autoload

## Related Decisions
- ADR-0001: Autoload Strategy (`GameEnums` is not an Autoload — pure `class_name`)
- ADR-0004: TileSystem and TileMapLayer (uses `GameEnums.Direction`, `GameEnums.TileCategory`, `GameEnums.TileShape`)
- ADR-0006: CombatAction as Resource (uses `GameEnums.RerollType`)
- `docs/architecture/architecture.md` — Foundation Layer: GameEnums section
