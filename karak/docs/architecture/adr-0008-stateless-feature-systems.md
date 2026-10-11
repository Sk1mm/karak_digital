# ADR-0008: Stateless Feature Systems

## Status
Accepted

## Date
2026-10-11

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.2 (GDScript) |
| **Domain** | Core |
| **Knowledge Risk** | LOW — Node lifecycle, signal patterns, and @export are stable since Godot 4.0 |
| **References Consulted** | `docs/engine-reference/godot/current-best-practices.md`, `docs/engine-reference/godot/deprecated-apis.md` |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | None — architecture pattern, not an API choice |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (Autoload Strategy — Feature systems are in-scene Nodes), ADR-0002 (Signal Wiring — Feature systems expose typed handlers), ADR-0003 (PlayerState as Node — Feature systems hold @export refs to PlayerState) |
| **Enables** | All Feature layer implementation epics |
| **Blocks** | None — systems can begin implementation once dependencies are accepted |
| **Ordering Note** | Defines the state contract for Feature systems. All Feature implementations must follow this pattern. |

## Context

### Problem Statement

The Feature layer contains 7 systems: `EncounterDispatcher`, `CombatSystem`,
`LootSystem`, `KnockoutSystem`, `WinCondition`, `MovementSystem`, and `TurnManager`.
These systems coordinate the core game loop by reacting to signals, querying Core
state (PlayerState, TileSystem), and emitting further signals.

The question is: which of these systems may hold persistent game state (state that
survives across multiple events or turns), and which must be stateless (process one
event and return to idle)?

Mixing stateful and stateless Feature systems without a clear rule creates:
- Risk of stale state persisting across turns (e.g., a scroll bonus from last combat
  applying to this combat)
- Testing complexity (must reset state before each test)
- Debugging difficulty (bug may be in accumulated state from N events ago)

### Constraints

- MVP: 2-player hotseat; no networking; no save/load of game state
- TurnManager is a FSM orchestrator — it must hold turn state by design
- CombatSystem has local combat-phase state (scroll_bonus, hp_bonus) that must be
  reset after each combat — this is ephemeral, not persistent
- EncounterDispatcher, LootSystem, KnockoutSystem, WinCondition have no need for
  inter-event state

### Requirements

- Must: Clearly distinguish which Feature systems may hold state and which must not
- Must: Combat-phase state in CombatSystem is reset before every new combat
- Must: Stateless systems produce no side effects outside of their explicit outputs
  (signals emitted, Core state mutations via API calls)
- Should: Stateless systems are independently testable by calling their handlers
  directly with mock inputs

## Decision

**Four Feature systems are stateless: `EncounterDispatcher`, `LootSystem`,
`KnockoutSystem`, `WinCondition`.**

**`TurnManager` is the only stateful Feature system (FSM).**

**`CombatSystem` holds combat-local ephemeral state** (reset at the start of each
new combat) — not persistent state.

**`MovementSystem` and `DiceSystem` are operationally stateless** (DiceSystem holds
`dice_state` for display purposes but it is overwritten on every roll — no
inter-turn accumulation).

### State Classification

| System | State Type | Persistent? | Notes |
|--------|-----------|-------------|-------|
| `TurnManager` | FSM state | YES — across turns | Only Feature system with intentional persistent state |
| `CombatSystem` | Combat-local ephemeral | NO — reset per combat | `scroll_bonus`, `hp_bonus`, `first_step_bonus` reset at `_on_combat_started` |
| `DiceSystem` | Last roll | NO — overwritten per roll | `dice_state: Array[int]` = last result only; UI reads it |
| `EncounterDispatcher` | None | NO | Pure signal router |
| `LootSystem` | None | NO | Pure table lookup + signal |
| `KnockoutSystem` | None | NO | Pure state mutation + signal |
| `WinCondition` | None | NO | Pure check + signal |
| `MovementSystem` | None | NO | Pure validation + signal |

### Stateless System Contract

A system is **stateless** if and only if:
1. It has no `var` fields that accumulate or persist across independent events
2. Its handler methods produce identical output given identical Core state inputs
3. It can be tested in isolation by calling `_on_signal_name(args)` with no setup of
   prior system state

```gdscript
## STATELESS system pattern — EncounterDispatcher example
class_name EncounterDispatcher
extends Node

## External signal wiring: GameScene._wire_signals() only.
## This system holds NO persistent state.

signal combat_started(player: PlayerState, monster_data: MonsterData)
signal loot_started(player: PlayerState, pos: Vector2i)

@export var tile_system: TileSystem

func _on_tile_reveal_complete(pos: Vector2i) -> void:
    ## Stateless handler: input = (pos) + Core state query = deterministic output
    var cell: DungeonCell = tile_system.get_cell(pos)
    if cell == null or cell.category == GameEnums.TileCategory.CORRIDOR:
        tile_system.clear_cell(pos)
        return
    # route to appropriate encounter signal
    # NO state stored between calls
```

### CombatSystem Ephemeral State Contract

`CombatSystem` accumulates state **within** a single combat phase (scroll_bonus,
hp_bonus, first_step_bonus). This state is fully reset at the start of each new
combat. It is **not** persistent across turns.

```gdscript
## CombatSystem: ephemeral combat-local state pattern
class_name CombatSystem
extends Node

## Combat-local state — reset at start of each combat in _on_combat_started()
var _scroll_bonus: int = 0
var _hp_bonus: int = 0
var _first_step_bonus: int = 0

func _on_combat_started(player: PlayerState, monster_data: MonsterData) -> void:
    ## RESET all combat-local state before doing anything else
    _scroll_bonus = 0
    _hp_bonus = 0
    _first_step_bonus = _get_first_step_bonus(player)
    # ... proceed with combat
```

### TurnManager FSM Contract

`TurnManager` is the only Feature system permitted to hold persistent game state.
Its state is the current FSM state and turn counters:

```gdscript
## TurnManager: the only stateful Feature system
class_name TurnManager
extends Node

## FSM state — persistent across events within a session
enum State { IDLE, AWAITING_INIT, TURN_ACTIVE, AWAITING_COMBAT, AWAITING_LOOT, GAME_OVER }
var _state: State = State.AWAITING_INIT
var _current_player_index: int = 0
var _steps_remaining: int = 0
```

## Alternatives Considered

### Alternative A: All Feature systems may hold state freely

- **Description**: No constraint on Feature system state. Each system manages its
  own state as needed.
- **Pros**: Maximum flexibility.
- **Cons**: Bug surface grows with each accumulated state variable. Testing requires
  full system setup. Stale state from previous turns can corrupt current turn. With
  18 systems and ~35 signal connections, debugging an accumulated-state bug is
  extremely difficult.
- **Rejection Reason**: High debugging and testing cost without benefit. Most systems
  have no natural reason to hold state.

### Alternative B: All Feature systems are stateless (including TurnManager)

- **Description**: TurnManager holds no state; GameScene drives the FSM externally.
- **Pros**: Purely functional Feature layer.
- **Cons**: TurnManager IS a state machine — its purpose is to orchestrate the turn
  sequence. Externalizing its FSM to GameScene turns GameScene into a god object.
  TurnManager's internal state (current player, steps remaining, FSM phase) is the
  natural domain of TurnManager.
- **Rejection Reason**: Forces a god object pattern on GameScene. TurnManager needs
  to be stateful by definition.

## Consequences

### Positive
- Stateless systems are trivially testable: call `_on_event(args)`, assert outputs
- Stale-state bugs are impossible in stateless systems
- CombatSystem reset-at-start pattern makes combat-phase bugs self-contained
- Only TurnManager needs careful state management — clear ownership
- Adding a new Feature system defaults to stateless (explicit opt-in to state)

### Negative
- CombatSystem ephemeral state requires discipline: every new combat MUST reset
  all `_*_bonus` variables before doing any work. Missing a reset causes a very
  subtle bug (bonuses from last combat carry over)
- "Stateless" is a convention, not enforced by GDScript — code review is the gate

### Risks
- **Risk**: Developer adds a persistent `var` to a stateless system (e.g., `LootSystem`
  counts total items looted for a "statistics" feature).
  **Mitigation**: Comment header on all stateless systems:
  `## STATELESS. This system holds no persistent game state.`
  Code review: any `var` field in a stateless system requires explicit justification.
- **Risk**: `CombatSystem` reset call (`_scroll_bonus = 0` etc.) is skipped or placed
  after early-return logic in `_on_combat_started`.
  **Mitigation**: Reset block is the FIRST thing in `_on_combat_started()` — before
  any conditional logic. Add `assert` in debug build: `assert(_scroll_bonus == 0, "...")`.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| `combat-system.md` | Rule 7: `scroll_bonus`, `hp_bonus`, `first_step_bonus` reset each combat | CombatSystem ephemeral state pattern — reset at `_on_combat_started` |
| `turn-manager.md` | TurnManager as FSM with states IDLE/TURN_ACTIVE/AWAITING_COMBAT/etc. | Explicitly permitted stateful system |
| All Feature GDDs | Systems must not interfere with each other's state | Stateless contract — no shared mutable state between Feature systems |

## Performance Implications
- **CPU**: Negligible — resetting 3 ints at combat start is trivial
- **Memory**: Stateless systems hold only `@export` refs (no runtime data) — minimal
- **Testing**: Stateless systems require no teardown/setup — test isolation is free

## Migration Plan

No existing code — greenfield. Comment header added to all stateless system files
at creation time.

## Validation Criteria

1. `EncounterDispatcher.gd`, `LootSystem.gd`, `KnockoutSystem.gd`, `WinCondition.gd`
   contain no `var` fields that accumulate across calls (grep: `var` in these files
   should return only `@export` and `@onready` refs)
2. `CombatSystem._on_combat_started()` has reset block as first statement
3. `TurnManager` has an `enum State` with at least 4 FSM states
4. All stateless system files have header comment: `## STATELESS.`

## Related Decisions
- ADR-0001: Autoload Strategy (Feature systems are in-scene Nodes, not Autoloads)
- ADR-0002: Signal Wiring Pattern (Feature systems expose typed `_on_*` handlers)
- ADR-0003: PlayerState as Node (Feature systems hold `@export` refs to PlayerState)
- `docs/architecture/architecture.md` — Feature Layer Module Ownership table
