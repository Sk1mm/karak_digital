# ADR-0012: TurnManager Swordsman Extra Step Protocol

## Status
Accepted

## Date
2026-10-11

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.2 |
| **Domain** | Core (Game Logic / GDScript) |
| **Knowledge Risk** | LOW — pure GDScript signal and method patterns; no engine APIs |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md` |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | None |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0006 (typed signal payloads), ADR-0008 (stateless Feature systems) |
| **Enables** | None |
| **Blocks** | TurnManager story for TR-turn-003 (unblocked by this ADR) |
| **Ordering Note** | Must be Accepted before TurnManager Swordsman story is created |

## Context

### Problem Statement
The Swordsman class continues their turn when they win combat with a die showing 6 (`can_continue_turn_on_six` flag). CombatSystem knows whether a 6 was rolled; TurnManager controls the FSM and step budget. No ADR established the cross-system coordination protocol: how does CombatSystem communicate the "6 was rolled" fact, and how does TurnManager correctly add a step and continue the turn?

### Constraints
- TurnManager is the only stateful Feature system (ADR-0008); its FSM is the single source of truth for turn flow
- CombatSystem must not read TurnManager's internal FSM state
- `combat_resolved` is the only sanctioned signal boundary between CombatSystem and TurnManager
- Adding a step must happen BEFORE the FSM processes the signal (so the transition sees the updated `steps_remaining`)

### Requirements
- CombatSystem must communicate `six_rolled: bool` to TurnManager as part of `combat_resolved`
- TurnManager must add 1 step before transitioning on `won=true, six_rolled=true`
- At `steps_remaining == 0` at moment of transition: EC-05 (GDD) — turn still ends (no steps to play)
- Non-Swordsman classes: `six_rolled=false` always — no behavior change

## Decision

**Protocol**: CombatSystem calls `TurnManager.add_step(1)` **before** emitting `combat_resolved(won=true, six_rolled=true)`. The signal `combat_resolved` gains a second parameter `six_rolled: bool`. TurnManager transitions `AWAITING_COMBAT` → `PLAYER_TURN` on `won=true, six_rolled=true` (turn continues), and ends the turn on all other outcomes.

### Signal Signature (Updated)

```gdscript
# combat_resolved — second parameter added
signal combat_resolved(won: bool, six_rolled: bool)
# All existing listeners must add six_rolled: bool to their handler signatures
```

### add_step API (TurnManager)

```gdscript
func add_step(n: int) -> void:
    ## Add n steps to steps_remaining. Used by CombatSystem for Swordsman ability.
    ## Contract: call BEFORE emitting combat_resolved — the FSM reads steps_remaining
    ## during state transition; mutating it after emit is a timing bug.
    ## n <= 0 → push_error. Does not modify steps_taken.
    if n <= 0:
        push_error("add_step: n must be > 0, got %d" % n)
        return
    steps_remaining += n
```

### Coordination Sequence (Swordsman wins with 6)

```
CombatSystem:
  1. Resolves combat: won=true, rolled_value=6 (any die showed 6)
  2. Reads active_player.character_class.can_continue_turn_on_six == true
  3. Calls TurnManager.add_step(1)         ← BEFORE emit; steps_remaining updated
  4. Emits combat_resolved(true, true)     ← TurnManager receives updated step count

TurnManager._on_combat_resolved(won: bool, six_rolled: bool):
  5. Assert state == AWAITING_COMBAT (else push_error)
  6. if won == true and six_rolled == true:
         state = PLAYER_TURN           ← turn continues
  7. elif won == true and six_rolled == false:
         state = AWAITING_LOOT         ← wait for item_acquired
  8. elif won == false:
         _end_turn()                   ← turn ends (defeat or draw)
```

### Non-Swordsman path (all other classes)

CombatSystem does NOT call `add_step()` for non-Swordsman classes. Emits `combat_resolved(won, false)` — `six_rolled` is always `false` for non-Swordsman. Existing TurnManager FSM behavior unchanged.

### Defensive Guard (EC-05)

```gdscript
# In TurnManager._on_combat_resolved, after case 6 above:
if state == PLAYER_TURN and steps_remaining == 0:
    push_error("Swordsman extra step: steps_remaining == 0 after transition — ending turn")
    _end_turn()
```

This handles the case where `add_step(1)` was NOT called before emit (CombatSystem bug). Defensive only — should not trigger in correct implementations.

## Alternatives Considered

### Alternative A: TurnManager Reads character_class Directly
- **Description**: TurnManager reads `active_player.character_class.can_continue_turn_on_six` on `combat_resolved(won=true)` and decides to continue
- **Pros**: Simpler signal (no `six_rolled` param); class logic centralized in TurnManager
- **Cons**: TurnManager gains knowledge of class system; class-turn coupling scattered across two systems; CombatSystem cannot know if continuation happened
- **Rejection Reason**: Single responsibility principle; TurnManager should not know about hero class abilities

### Alternative B: Separate `swordsman_turn_continued` Signal
- **Description**: CombatSystem emits a second signal `swordsman_turn_continued(player)` that TurnManager listens to
- **Pros**: Named intent; explicit
- **Cons**: Two signal listeners for the same combat event; ordering issues; `six_rolled: bool` adds minimal overhead
- **Rejection Reason**: Adding `six_rolled: bool` to existing signal is simpler and avoids dual-signal ordering hazards

## Consequences

### Positive
- Single signal boundary between CombatSystem and TurnManager
- `six_rolled` param is reusable (HUD animation, analytics, future abilities)
- `add_step(n)` is reusable for future class abilities or power-ups
- FSM sees correct `steps_remaining` during transition (no race condition)

### Negative
- `combat_resolved` signal signature changes — all existing listeners need `six_rolled: bool` added to their handler
- Ordering contract (add_step before emit) is a temporal coupling — must be documented

### Risks
- **Risk**: Developer emits `combat_resolved` before calling `add_step` → Swordsman gets 0 extra steps (silent logic bug)
  - **Mitigation**: Ordering documented in both CombatSystem and TurnManager source comments; integration test covers AC-05; defensive guard in TurnManager catches this at runtime
- **Risk**: `combat_resolved` signature change breaks existing TurnManager/HUD listeners
  - **Mitigation**: Migration Plan below; grep check for all `combat_resolved` connection sites

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| turn-manager.md | TR-turn-003: Swordsman extra step upon 6-roll victory | Establishes `add_step(1)` + `combat_resolved(true, six_rolled=true)` protocol; defines ordering contract; documents edge cases |

## Performance Implications
- **CPU**: Negligible — one extra method call + one bool parameter per Swordsman combat win

## Migration Plan
- `combat_resolved` signal adds `six_rolled: bool` as second parameter
- All listeners of `combat_resolved` must update handler signatures:
  - `TurnManager._on_combat_resolved(won: bool)` → `_on_combat_resolved(won: bool, six_rolled: bool)`
  - Any HUD or analytics subscribers similarly updated
- CombatSystem emit sites: add `false` as second argument for all non-Swordsman paths

## Validation Criteria
- AC-05: Swordsman `add_step(1)` called → `combat_resolved(true, true)` → `steps_remaining` increased, `PLAYER_TURN` state
- AC-06: `combat_resolved(false, true)` → turn ends (defeat overrides six_rolled)
- Integration test: full Swordsman combat sequence with step budget verified

## Related Decisions
- ADR-0006: CombatAction as Resource — established typed signal discipline
- ADR-0008: Stateless Feature Systems — TurnManager FSM constraint
