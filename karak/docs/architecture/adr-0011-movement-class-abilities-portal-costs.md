# ADR-0011: Movement Class Abilities and Portal Cost Rules

## Status
Accepted

## Date
2026-10-11

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.2 |
| **Domain** | Core (Game Logic / GDScript) |
| **Knowledge Risk** | LOW — no engine APIs used; pure GDScript flag reads and method calls |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md` |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | None — no engine API calls involved |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0003 (PlayerState as Node — `character_class` field), ADR-0008 (stateless Feature systems) |
| **Enables** | None |
| **Blocks** | MovementSystem stories for TR-movement-002, TR-movement-003 (unblocked by this ADR) |
| **Ordering Note** | Must be Accepted before MovementSystem stories are created |

## Context

### Problem Statement
MovementSystem implements 4 class-specific movement overrides and portal traversal cost rules. No ADR established how class-specific behavior is triggered in a stateless system, or how portal costs are attributed across TurnManager step expenditure.

### Constraints
- MovementSystem must remain stateless (ADR-0008)
- Class data is owned by PlayerState/ClassRegistry (ADR-0001, ADR-0003)
- No new Autoloads for class logic
- `spend_step()` is the only interface to TurnManager for step expenditure

### Requirements
- Must support Rogue (`can_bypass_monster_free`): free bypass of monster tile in 1 step total
- Must support Swordwoman (`can_bypass_monster_cost`): bypass costs 2 steps + 1 HP
- Must support Wizard (`can_pass_through_walls`): ignore exit validation
- Must support Warlock (`can_swap_positions`): swap with other player for 4 steps
- Portal entry = 1 step; optional teleportation = 1 more step; total if used = 2 steps
- At `steps_remaining == 1` before portal entry: teleportation option is suppressed (no steps left after entry)

## Decision

MovementSystem reads class ability flags **directly from `PlayerState.character_class`** (a `HeroClassData` Resource) using dot-notation access to boolean fields. No strategy objects, no polymorphism — direct conditional branching on well-named boolean flags.

### Class Ability Flag Mapping

| Flag | Class | MovementSystem Behavior |
|------|-------|------------------------|
| `can_bypass_monster_free` | Rogue (Разбойница) | Skip monster tile, land on next tile in same direction, total = 1 `spend_step()`; `cell_entered` NOT emitted on monster tile |
| `can_bypass_monster_cost` | Swordwoman (Воительница) | Bypass costs 2 `spend_step()` + `PlayerState.take_damage(1)`; requires `steps_remaining >= 2` before bypass |
| `can_pass_through_walls` | Wizard (Волшебник) | Exit validation skipped entirely; tile must exist but entry direction is unrestricted |
| `can_swap_positions` | Warlock (Чернокнижник) | Costs 4 `spend_step()` calls; requires `steps_remaining >= 4`; updates `set_position()` for both players |

### Portal Cost Rule

```
const PORTAL_ENTER_COST: int = 1     # spend_step() on entering the portal tile
const PORTAL_TELEPORT_COST: int = 1  # spend_step() on choosing a destination portal

# Offer teleportation only when steps_remaining >= 1 AFTER portal entry
# (i.e., steps_remaining >= 2 BEFORE entry)
# Edge case: at steps_remaining == 1 before entry → enter (1 step spent),
#   steps_remaining == 0 → turn ends, teleportation not offered
```

### Architecture Diagram

```
MovementSystem._process_move(player, target_pos):
  class_data = player.character_class  # HeroClassData from PlayerState (ADR-0003)

  if target_has_monster and class_data.can_bypass_monster_free:
      → bypass free: spend_step() × 1, land on tile_after_monster
  elif target_has_monster and class_data.can_bypass_monster_cost:
      → bypass cost: spend_step() × 2, take_damage(1), land on tile_after_monster
  else:
      → normal move: exit_valid check (skipped if can_pass_through_walls)
         spend_step() × 1, set_position(), cell_entered.emit()

  if target_tile.category == PORTAL:
      spend_step() × 1  (portal entry)
      if steps_remaining >= 1:
          → offer teleportation UI → spend_step() × 1, set_position(dest_portal)

MovementSystem._handle_swap(player_a, player_b):
  # Requires steps_remaining >= SWAP_COST (4)
  spend_step() × 4
  set_position(player_a, player_b.get_position())
  set_position(player_b, player_a.get_position())
```

### Key Interfaces

```gdscript
# Read from PlayerState (ADR-0003)
player.character_class.can_bypass_monster_free: bool
player.character_class.can_bypass_monster_cost: bool
player.character_class.can_pass_through_walls: bool
player.character_class.can_swap_positions: bool

# Existing interfaces (unchanged)
TurnManager.spend_step() -> void
PlayerState.set_position(pos: Vector2i) -> void
PlayerState.take_damage(amount: int) -> void  # Swordwoman bypass only

# MovementSystem constants
const PORTAL_ENTER_COST: int = 1
const PORTAL_TELEPORT_COST: int = 1
const SWAP_COST: int = 4
const SWORDWOMAN_BYPASS_STEP_COST: int = 2
```

## Alternatives Considered

### Alternative A: Strategy Pattern (Movement Strategy per Class)
- **Description**: Each HeroClass provides a `MovementStrategy` object with overridable methods
- **Pros**: Open/Closed principle; easy to add new class types
- **Cons**: Overengineered for 4 boolean flags; adds Resource/Object overhead; breaks stateless principle if strategies hold state
- **Rejection Reason**: 4 flags with direct conditionals is simpler, more readable, and the GDD already models them as boolean flags on `HeroClassData`

### Alternative B: Signal-Based Class Modifications
- **Description**: ClassSystem emits `movement_rule_modified(player, rule)` that MovementSystem subscribes to
- **Pros**: Fully decoupled
- **Cons**: Asynchronous modification of synchronous movement validation is fragile; no benefit at MVP scale; harder to test
- **Rejection Reason**: Direct flag reads are sufficient; signal overhead is unjustified for a synchronous check

## Consequences

### Positive
- Minimal code: 4 if/elif branches in MovementSystem
- Class flags defined once in HeroClassData (ClassRegistry), read everywhere
- Stateless: MovementSystem never stores which class is active
- Consistent with ADR-0003 PlayerState API

### Negative
- MovementSystem has implicit dependency on HeroClassData field names
- Adding a new class ability requires editing MovementSystem conditionals

### Risks
- **Risk**: HeroClassData boolean flag sprawl if many classes added — advisable to use a bitmask if class count exceeds 8
  - **Mitigation**: Acceptable at current 5-class MVP scope; revisit with `/architecture-decision` if extended
- **Risk**: `can_bypass_monster_cost` requires `steps_remaining >= 2` — if this check is omitted, Swordwoman can bypass with 1 step (bug)
  - **Mitigation**: Acceptance criteria AC-08/EC-06 cover this; unit test required

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| movement-system.md | TR-movement-002: Class-specific bypasses (Rogue, Swordwoman, Wizard, Warlock) | Establishes direct flag-read pattern from `PlayerState.character_class`; defines cost and constraint for each class ability |
| movement-system.md | TR-movement-003: Portal movement cost rules (2 steps total; suppressed when steps < 2) | Documents `PORTAL_ENTER_COST` + `PORTAL_TELEPORT_COST` constants; specifies suppression condition |

## Performance Implications
- **CPU**: Negligible — 4 boolean flag reads per move action
- **Memory**: None — no new objects created
- **Load Time**: None

## Migration Plan
No existing code to migrate — this ADR documents the implementation pattern for new MovementSystem code.

## Validation Criteria
- AC-07 (Rogue bypass 1 step), AC-08 (Swordwoman 2 steps + HP), AC-09 (Wizard ignores exits), AC-10/AC-11 (Warlock swap), AC-05 (Portal 2-step), AC-06 (Portal refuse) from `design/gdd/movement-system.md` all pass
- grep: no `strategy` or `movement_rule` patterns in `movement_system.gd`
- Unit test: `can_bypass_monster_cost` blocked when `steps_remaining < 2`

## Related Decisions
- ADR-0003: PlayerState as Node — source of `character_class` field
- ADR-0008: Stateless Feature Systems — MovementSystem stateless constraint
