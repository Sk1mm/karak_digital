# ADR-0006: CombatAction as Resource

## Status
Accepted

## Date
2026-10-11

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.2 (GDScript) |
| **Domain** | Core |
| **Knowledge Risk** | LOW — Resource base class, typed signals, and class_name stable since Godot 4.0 |
| **References Consulted** | `docs/engine-reference/godot/current-best-practices.md`, `docs/engine-reference/godot/deprecated-apis.md` |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | Confirm `signal player_choice_requested(options: CombatOptions)` and `signal player_action_taken(action: CombatAction)` compile and dispatch correctly in Godot 4.7.2 |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0002 (Signal Wiring Pattern — signal topology), ADR-0003 (PlayerState as Node — CombatAction references PlayerState methods) |
| **Enables** | CombatSystem implementation epic, CombatUI implementation epic |
| **Blocks** | CombatSystem and CombatUI implementation — both depend on the shared command object type |
| **Ordering Note** | CombatSystem and CombatUI communicate via signal with a typed payload. Both must agree on the payload type before either is implemented. |

## Context

### Problem Statement

`CombatSystem` needs to present the player with a set of available combat options
(can reroll? can use scroll? can spend HP?) and receive back the player's choice.
`CombatUI` is the Presentation layer component that shows the options and collects
the choice.

The signal from CombatSystem → CombatUI carries "available options" (what the player
can do). The signal from CombatUI → CombatSystem carries "player choice" (what the
player decided to do).

Both signals need typed payloads. The question is: typed `Dictionary`, or a dedicated
typed `Resource` class?

### Constraints

- GDScript 4.7.2: `Dictionary` is untyped — field names are strings, not compile-time checked
- CombatSystem GDD defines 4 option flags: `can_reroll`, `can_reroll_one_die`, `can_use_scroll`, `can_spend_hp`
- CombatSystem GDD defines player action choices: reroll type (both/one die), die index for one-die reroll, scroll index if used, HP spending flag
- Both payload types are short-lived value objects (created once per combat phase, discarded)
- No save/load required for combat state

### Requirements

- Must: Signal parameters are statically typed — no untyped Dictionary passed in signals
- Must: CombatUI cannot put invalid field combinations in the action payload
- Must: CombatSystem can access payload fields with static-type-checked property access
- Should: Payload types are simple to construct (no complex init)

## Decision

**Two `Resource` subclasses carry the combat phase payloads:**
- `CombatOptions extends Resource` — emitted by CombatSystem to CombatUI (available actions)
- `CombatAction extends Resource` — emitted by CombatUI to CombatSystem (player's choice)

Both extend `Resource` because:
1. `Resource` supports typed `@export` fields — clean property declaration
2. `Resource.new()` creates a lightweight instance with no scene-tree overhead
3. Signal parameters can be typed to any `class_name` type, including Resource subclasses
4. No lifecycle (`_ready()`, signals) needed — pure data carriers

`CombatAction` is the "command object": it encodes exactly what the player decided.
`CombatOptions` is the "options object": it encodes what choices are available.

### Architecture Diagram

```
CombatSystem                          CombatUI
     │                                    │
     │  player_choice_requested           │
     │  (options: CombatOptions) ────────►│
     │                                    │  [player makes choice]
     │  player_action_taken               │
     │◄─────────────────── (action: CombatAction)
     │                                    │
     │  [resolves action, continues combat]│
```

### Key Interfaces

```gdscript
# CombatOptions.gd — what the player CAN do this combat phase
class_name CombatOptions
extends Resource

@export var can_reroll_both: bool = false     ## Warrior class ability
@export var can_reroll_one: bool = false      ## Warrior-F class ability
@export var can_use_scroll: bool = false      ## player has MAGIC_ATTACK scroll in inventory
@export var can_spend_hp: bool = false        ## Warlock + hp > 1


# CombatAction.gd — what the player CHOSE to do
class_name CombatAction
extends Resource

## Reroll choice
@export var reroll_type: int = 0          ## GameEnums.RerollType: NONE / BOTH / ONE_DIE
@export var reroll_die_index: int = -1    ## Index of die to reroll (0 or 1); -1 if not rerolling one

## Scroll choice
@export var use_scroll: bool = false
@export var scroll_index: int = -1        ## Index in PlayerState.scrolls; -1 if unused

## HP choice (Warlock)
@export var spend_hp: bool = false


# CombatSystem.gd — signal declarations
signal player_choice_requested(options: CombatOptions)
signal player_action_taken(action: CombatAction)   ## wired in GameScene: combat_ui → combat_system

# Usage in CombatSystem (PLAYER_CHOICE phase):
func _enter_player_choice_phase(player: PlayerState) -> void:
    var opts := CombatOptions.new()
    opts.can_reroll_both = player.character_class.can_reroll_both_dice
    opts.can_reroll_one = player.character_class.can_reroll_one_die
    opts.can_use_scroll = player.scrolls.any(func(s): return s.type == GameEnums.ItemType.MAGIC_ATTACK)
    opts.can_spend_hp = player.character_class.can_spend_hp_for_attack and player.hp > 1
    player_choice_requested.emit(opts)
    # wait for player_action_taken signal (wired from CombatUI)

# Handler for CombatUI response:
func _on_player_action_taken(action: CombatAction) -> void:
    # action.reroll_type, action.reroll_die_index, action.use_scroll, action.spend_hp
    # all statically typed — no string keys, no null checks on field names
    pass
```

## Alternatives Considered

### Alternative A: `Dictionary` payload

- **Description**: Pass `Dictionary` in both signals:
  `signal player_choice_requested(options: Dictionary)`,
  `signal player_action_taken(action: Dictionary)`.
  Fields accessed as `action["reroll_type"]`, `action.get("die_index", -1)`.
- **Pros**: No new files; familiar to Python/dynamic-language developers.
- **Cons**:
  1. No static type checking — typo in key name (`"reroll_type"` vs `"rerollType"`)
     silently returns `null` instead of failing at compile time.
  2. GDScript signal `Dictionary` parameter loses static type safety entirely at
     the signal boundary — the receiving function sees `Variant`.
  3. CombatUI can add invalid keys or omit required keys with no warning.
  4. Violates the project's static typing standard (coding-standards.md).
- **Rejection Reason**: No static type safety. Violates coding standards.

### Alternative B: Plain GDScript class (no `extends`)

- **Description**: `class_name CombatAction` with no `extends`, same as `DungeonCell`
  in ADR-0004. Fields as `var` instead of `@export`.
- **Pros**: Lightweight; no Resource overhead.
- **Cons**: Cannot use `@export` for fields (plain class fields are not exports).
  For a data carrier with ~5 fields passed in a signal, the difference between
  `Resource.new()` and a plain class `new()` is negligible. The `@export` on Resource
  makes field declarations more explicit and IDE-visible, which aids readability for
  a multi-field command object.
- **Relationship to chosen**: Both are acceptable. `Resource` was chosen for the
  `@export` field clarity and consistent pattern with other data objects in the project.
  The distinction is minor — the key requirement (typed signal parameter) is satisfied
  by either.

### Alternative C: Typed signal with individual parameters

- **Description**: Inline all options/action fields as separate signal parameters:
  `signal player_choice_requested(can_reroll_both: bool, can_reroll_one: bool, can_use_scroll: bool, can_spend_hp: bool)`
- **Pros**: No new Resource files; all types explicit.
- **Cons**: Signal parameters grow as combat options grow; changing the combat rules
  requires changing the signal signature and all connection sites. At 4+ fields, a
  command object is cleaner than a parameter list. `CombatOptions` and `CombatAction`
  are likely to gain fields (e.g., `can_use_weapon_ability`) in future — Resource
  allows adding fields without breaking the signal signature.
- **Rejection Reason**: Signals with 4+ parameters are fragile under feature evolution.
  Command object pattern is more maintainable.

## Consequences

### Positive
- Static type safety end-to-end: CombatSystem constructs `CombatOptions`, CombatUI
  reads it with typed access, constructs `CombatAction`, CombatSystem reads it typed
- Adding a new combat option requires adding one field to `CombatOptions` and one to
  `CombatAction` — signal signatures unchanged
- `@export` fields on Resource make both classes self-documenting in the IDE
- No Dictionary null-access bugs possible

### Negative
- Two additional files: `combat_options.gd` and `combat_action.gd`
- `Resource` overhead is minimal but nonzero for a pure value object

### Risks
- **Risk**: Developer adds logic to `CombatOptions` or `CombatAction` (signals, methods
  with side effects) — these are intended as pure data carriers.
  **Mitigation**: Comment header: `## Pure data carrier — no methods, no signals, no side effects.`
- **Risk**: `CombatAction.reroll_type == 0` is ambiguous (0 = NONE or uninitialized?).
  **Mitigation**: `GameEnums.RerollType.NONE == 0` is the canonical sentinel. Document in
  the enum definition. `CombatAction.new()` defaults to NONE, which is correct initial state.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| `combat-system.md` | Rule 4: `player_choice_requested` signal with 4 option flags | `CombatOptions` Resource with 4 `@export bool` fields |
| `combat-system.md` | Rule 4: CombatUI returns player action (reroll type, die index, scroll, HP) | `CombatAction` Resource with typed fields for each choice |
| `combat-system.md` | Rule 5: Scroll use — index in player.scrolls | `CombatAction.scroll_index: int` |
| `combat-system.md` | Rule 6: HP Warlock — boolean spend flag | `CombatAction.spend_hp: bool` |

## Performance Implications
- **CPU**: `Resource.new()` for 2 small objects per combat phase: negligible
- **Memory**: ~bytes per instance; GC'd after combat phase resolves
- **Load Time**: N/A — no `.tres` files, pure runtime construction

## Migration Plan

No existing code — greenfield. Create `src/core/combat/combat_options.gd` and
`src/core/combat/combat_action.gd` before implementing CombatSystem or CombatUI.

## Validation Criteria

1. `CombatOptions.new()` compiles and all 4 fields are accessible with static typing
2. `CombatAction.new()` compiles and all fields default to their zero/false values
3. `signal player_choice_requested(options: CombatOptions)` compiles in CombatSystem.gd
4. `signal player_action_taken(action: CombatAction)` compiles in CombatUI.gd
5. CombatUI assigning `action.reroll_type = GameEnums.RerollType.BOTH` compiles with no type error
6. Accessing `action.nonexistent_field` (dot notation) in CombatSystem produces a compile-time error — GDScript resolves dot-access against the known class layout. Dict-bracket notation `action["key"]` is a runtime error, not compile-time; dot notation is mandatory for typed access.

## Related Decisions
- ADR-0002: Signal Wiring Pattern (`player_action_taken` is wired in `GameScene._wire_signals()`)
- ADR-0007: GameEnums Global Class (`RerollType` enum used in `CombatAction.reroll_type`)
- `docs/architecture/architecture.md` — Feature Layer: CombatSystem API Boundaries
