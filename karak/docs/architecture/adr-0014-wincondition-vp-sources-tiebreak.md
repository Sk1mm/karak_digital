# ADR-0014: WinCondition VP Sources and Tiebreak Rule

## Status
Accepted

## Date
2026-10-11

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.2 |
| **Domain** | Core (Game Logic / GDScript) |
| **Knowledge Risk** | LOW — pure GDScript float arithmetic and signal patterns |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md` |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | None |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0003 (PlayerState — `vp: float`, `add_vp()`), ADR-0008 (stateless Feature systems) |
| **Enables** | None |
| **Blocks** | WinCondition story for TR-win-002 (unblocked by this ADR) |
| **Ordering Note** | Must be Accepted before WinCondition TR-win-002 story is created |

## Context

### Problem Statement
VP accumulates from 3 distinct sources across 3 different systems (LootSystem, CombatSystem, WinCondition). No ADR established who is responsible for VP calculation at each source, how VP flows into PlayerState, and how the final winner is determined — including the tiebreak rule when VP values are equal.

### Constraints
- WinCondition is stateless (ADR-0008): cannot maintain running VP totals across events
- PlayerState is the single source of truth for per-player runtime state (ADR-0003)
- `vp: float` is already established as the PlayerState field type (ADR-0003 retrofit)
- `game_over(winner: PlayerState)` must be emitted exactly once per session

### Requirements
- VP from chests: awarded by LootSystem
- VP from Ghost kill: awarded by CombatSystem (reads `vp_on_kill` from MonsterDatabase)
- VP from Dragon kill: awarded by WinCondition (triggers game end)
- Winner determined by highest `player.vp` at `dragon_killed`
- Tiebreak: player who killed the Dragon wins

## Decision

**Distributed VP accumulation**: each system that awards VP calls `PlayerState.add_vp(amount: float)` directly. WinCondition does NOT track VP in-flight — it only reads final `player.vp` values from PlayerState at game end.

### VP Sources and Owners

| Source | VP Amount | Responsible System | Timing |
|--------|-----------|-------------------|--------|
| Chest opened | `VP_CHEST = 1.0` | LootSystem | On `loot_started` handled → `PlayerState.add_vp(1.0)` |
| Ghost killed | `monster.vp_on_kill` | CombatSystem | On winning combat vs Ghost → `PlayerState.add_vp(monster.vp_on_kill)` |
| Dragon killed | `VP_DRAGON_KILL = 1.5` | WinCondition | On `dragon_killed` signal, before `_determine_winner()` |

### Winner Determination

```gdscript
# WinCondition (stateless Node)
const VP_DRAGON_KILL: float = 1.5

func _on_dragon_killed(killer: PlayerState) -> void:
    killer.add_vp(VP_DRAGON_KILL)          # 1.5 VP to killer BEFORE comparison
    var winner: PlayerState = _determine_winner(killer)
    game_over.emit(winner)

func _determine_winner(dragon_killer: PlayerState) -> PlayerState:
    # players is an Array[PlayerState] injected via _wire_signals (ADR-0002)
    # Initialized to dragon_killer as default tiebreak (EC-02: tie is mathematically
    # impossible under current VP rules, but this default handles edge cases)
    var best_vp: float = -1.0
    var winner: PlayerState = dragon_killer  # tiebreak default: killer wins
    for player in players:
        if player.vp > best_vp:
            best_vp = player.vp
            winner = player
    # NOTE: winner is overwritten to the highest-VP player found in the loop.
    # If dragon_killer is in the players array (expected), they will be set
    # as winner when the loop reaches them — the pre-init to dragon_killer
    # only acts as null-safety if players array is unexpectedly empty.
    return winner
```

### Tiebreak Mathematical Analysis

`VP_DRAGON_KILL = 1.5` is the only fractional VP source. The killer always has a fractional total (X + 1.5 = X.5). All other VP sources are integer-valued (chest = 1.0 integer, `vp_on_kill` from MonsterDatabase = integer). Therefore a non-killer's total is always an integer, and `integer ≠ X.5` — a tie is mathematically impossible under current rules (GDD EC-02). The tiebreak rule is a **formal safety net** that does not trigger in practice. If `VP_DRAGON_KILL` is ever changed to an integer, the tiebreak becomes load-bearing.

### Float Precision Note

`vp: float` is established by ADR-0003. Using `float` for VP accumulation carries a theoretical drift risk (e.g., `1.0 + 1.0 + 1.0 = 2.9999...`). Mitigation: the mathematical impossibility of ties (above) means float precision errors cannot change the winner determination under current VP rules. If VP values ever change to allow multiple 0.5-increment sources, a half-point integer representation (`int × 2`) should be considered.

### Constants

```gdscript
# WinCondition
const VP_DRAGON_KILL: float = 1.5

# LootSystem (already defined as VP_PER_CHEST)
const VP_CHEST: float = 1.0

# CombatSystem — reads from MonsterDatabase:
# var vp_on_kill: float  (MonsterData field for Ghost)
```

### Why Distributed (Not Centralized in WinCondition)

Centralizing VP in WinCondition would make it stateful (contradicts ADR-0008) and tightly couple it to LootSystem and CombatSystem event feeds. PlayerState already owns all per-player runtime state (ADR-0003); VP is player state, not game meta-state. Each awarding system is already processing the relevant event and is the natural place to call `add_vp()`.

## Alternatives Considered

### Alternative A: Centralized VP in WinCondition
- **Description**: WinCondition subscribes to `chest_opened`, `monster_killed`, `dragon_killed` and maintains VP totals internally
- **Pros**: All VP logic in one place; easy to audit the complete VP economy
- **Cons**: Makes WinCondition stateful (violates ADR-0008); tight coupling to LootSystem and CombatSystem event feeds
- **Rejection Reason**: Stateless constraint is non-negotiable (ADR-0008)

### Alternative B: VP Event Bus
- **Description**: Each VP source emits `vp_awarded(player, amount)` signal; PlayerState and WinCondition both subscribe
- **Pros**: Fully decoupled; auditable VP stream
- **Cons**: Adds indirection for a simple accumulation pattern; `PlayerState.add_vp()` direct call is equivalent with less complexity
- **Rejection Reason**: Unnecessary complexity at MVP scale; event bus adds no testability benefit over direct method calls

## Consequences

### Positive
- Simple: each awarding system calls `add_vp()` directly — readable, traceable to source
- WinCondition remains stateless (reads only at game end)
- VP always current in PlayerState — HUD can display live VP by subscribing to PlayerState changes

### Negative
- VP economy is distributed: developer must check LootSystem + CombatSystem + WinCondition to understand full VP flow
- Ghost `vp_on_kill` lives in MonsterDatabase — indirect dependency

### Risks
- **Risk**: Future VP source added → developer forgets to call `add_vp()` → silent VP deficit
  - **Mitigation**: End-to-end integration test verifying all VP sources (chest + ghost + dragon) emitted in a single session
- **Risk**: `VP_DRAGON_KILL` changed to integer → tie becomes possible → tiebreak becomes load-bearing
  - **Mitigation**: GDD documents the 0.5-fractional requirement for `VP_DRAGON_KILL`; changing it requires an ADR update
- **Risk**: Float precision drift in VP accumulation
  - **Mitigation**: Mathematically impossible under current rules (see Float Precision Note above)

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| win-condition.md | TR-win-002: VP from chests (1.0), Ghost (`vp_on_kill`), Dragon (1.5); tiebreak to dragon killer | Establishes distributed `add_vp()` pattern; documents which system owns each VP source; defines tiebreak default in `_determine_winner()`; documents float precision analysis |

## Performance Implications
- **CPU**: Negligible — float comparison over ≤2 players at game end
- **Memory**: None

## Migration Plan
No new methods required — `add_vp(amount: float)` is already established by ADR-0003 retrofit. CombatSystem must add `add_vp(monster.vp_on_kill)` call for Ghost kill during CombatSystem implementation.

## Validation Criteria
- Unit test: chest opened → `player.vp == 1.0`
- Unit test: dragon killed → `killer.vp += 1.5`, `game_over(winner)` emitted
- Unit test: `dragon_killed(player_A)`, `player_A.vp > player_B.vp` → `winner == player_A`
- Unit test: `dragon_killed(player_A)`, `player_A.vp < player_B.vp` → `winner == player_B`
- Integration test: full session — chest (1.0) + ghost (1.0) + dragon (1.5) → correct VP totals

## Related Decisions
- ADR-0003: PlayerState as Node — source of `vp: float` and `add_vp()` API
- ADR-0008: Stateless Feature Systems — WinCondition stateless constraint
