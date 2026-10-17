# ADR-0010: Save/Load System — MVP Deferral and Post-MVP Path

## Status
Proposed

## Date
2026-10-11

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.2 (GDScript) |
| **Domain** | Core (Persistence / FileSystem) |
| **Knowledge Risk** | HIGH — Godot 4.7.2 is beyond LLM training cutoff (May 2025 ≈ 4.3) |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `docs/engine-reference/godot/breaking-changes.md`, `docs/engine-reference/godot/deprecated-apis.md`, `docs/engine-reference/godot/current-best-practices.md` |
| **Post-Cutoff APIs Used** | `FileAccess.store_*()` returns `bool` since 4.4 (was `void`) — must check return value in any post-MVP implementation |
| **Verification Required** | Post-MVP only: verify `FileAccess.open(path, WRITE)` returns non-null before writing; verify `user://` resolves correctly on target platform |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0003 (PlayerState as Node — any save implementation must serialize PlayerState fields; ResourceSaver incompatible) |
| **Enables** | None in MVP scope |
| **Blocks** | None — save/load explicitly deferred; no MVP epic blocked by this decision |
| **Ordering Note** | Post-MVP: before implementing, create a follow-up ADR finalizing save schema. Add `to_dict()` / `from_dict()` to PlayerState, DungeonGenerator, TurnManager per this ADR's sketched contract. |

## Context

### Problem Statement
Does Karak Digital MVP need a mid-session save system (pause and resume a game later)?
This resolves `docs/architecture/architecture.md` Open Question OQ-2:
*"Сохранение партии (save/load): нужно ли в MVP? Если да — PlayerState потребует `to_save_data() → Resource`"*

### Constraints
- Session length: 30–60 minutes (game-concept.md) — designed to complete in one sitting
- No meta-progression between sessions (game-concept.md Anti-Pillar: "НЕ мета-прогрессия между сессиями")
- MVP scope is 2–4 weeks solo — save system adds non-trivial cross-system serialization complexity
- Pillar 3: "Просто войти, сложно насытиться" — minimal friction, minimal hidden complexity

### Requirements
- **MVP**: No save functionality required
- **Post-MVP** (if implemented): Must save complete game state — all PlayerState instances, DungeonGenerator grid, TurnManager current-player and turn-number
- **Post-MVP**: Must restore an identical game state on load — same board layout, same inventories, same VP counts, same turn order

## Decision

**Save/load is NOT part of the MVP scope.**

Sessions are designed to complete in 30–60 minutes. The game has no inter-session meta-progression by design (Anti-Pillar). Adding a save system in MVP introduces serialization complexity across at minimum three systems (PlayerState, DungeonGenerator, TurnManager) without meaningful player value for the target session length.

Open Question OQ-2 from `docs/architecture/architecture.md` is resolved: **deferred to post-MVP**.

### Post-MVP Path (for when this is revisited)

If save/load is added post-MVP, the approved approach is:

**FileAccess + JSON** saved to `user://save_game.json`

```
SaveSystem (Autoload)
  └── save_game() → collects dict from all stateful systems → JSON.stringify() → FileAccess.store_string()
  └── load_game() → FileAccess.get_as_text() → JSON.parse_string() → restores each system

Serialization contract (add when implementing, not in MVP):
  PlayerState.to_dict() -> Dictionary      # only GDScript primitives: int, float, String, bool, Array, Dictionary
  PlayerState.from_dict(d: Dictionary) -> void
  DungeonGenerator.to_dict() -> Dictionary
  DungeonGenerator.from_dict(d: Dictionary) -> void
  TurnManager.to_dict() -> Dictionary
  TurnManager.from_dict(d: Dictionary) -> void
```

Save file schema (sketch — finalize in follow-up ADR):
```json
{
  "version": 1,
  "players": [
    { "player_id": 1, "hp": 3, "max_hp": 5, "vp": 2.5, "position_x": 3, "position_y": 4,
      "weapons": [...], "scrolls": [...], "has_key": false, "chests_opened": 2,
      "skip_next_turn": false, "has_killed_dragon": false }
  ],
  "dungeon_grid": { "tiles": [...] },
  "turn_manager": { "current_player_index": 0, "turn_number": 14 }
}
```

Note: `Vector2i` positions must be serialized as separate int fields (`position_x`, `position_y`) — `JSON.stringify()` does not handle Godot native types directly.

### Architecture Diagram

```
[MVP — current]
GameScene → no persistence layer
  All state is in-memory only. Closing the app loses the session. Intentional for MVP scope.

[Post-MVP — if implemented]
GameScene ──► SaveSystem.save_game()
                  ├── PlayerState[].to_dict()      → { hp, vp, weapons, ... }
                  ├── DungeonGenerator.to_dict()   → { tiles: [...] }
                  └── TurnManager.to_dict()        → { current_player_index, turn_number }
                            └── JSON.stringify() → FileAccess.store_string()
                                    └── user://save_game.json
```

### Key Interfaces
None in MVP scope. Post-MVP interfaces sketched above — will be finalized in a follow-up ADR when save is scheduled for implementation.

## Alternatives Considered

### Alternative 1: Implement mid-session save in MVP (FileAccess + JSON)
- **Description**: SaveSystem Autoload serializes all stateful nodes to JSON on demand; saves to `user://save_game.json`
- **Pros**: Players can pause mid-game; family-friendly (kids need to go to bed)
- **Cons**: Requires `to_dict()` / `from_dict()` on 3+ systems; JSON schema versioning from day one; atomic write patterns; non-trivial MVP scope risk
- **Rejection Reason**: 30–60 min sessions fit one sitting by design. Scope risk outweighs player benefit in MVP. Implementing it correctly (versioning, atomic write, Godot type conversion) takes disproportionate time for a prototype.

### Alternative 2: ResourceSaver / ResourceLoader (.tres / .res format)
- **Description**: Game state stored as Godot Resource files using built-in ResourceSaver/ResourceLoader
- **Pros**: Native Godot serialization; ResourceLoader handles type reconstruction automatically
- **Cons**: PlayerState extends Node (ADR-0003), not Resource — requires a parallel SaveData Resource class for each Node, adding double indirection and extra types. Additionally, `.tres` files expose internal Godot resource structure and are fragile across engine upgrades (field renames in code break existing `.tres` files). JSON is more forward-stable for player save data.
- **Rejection Reason**: Contradicts ADR-0003. Double indirection adds complexity without advantage. ResourceSaver is designed for editor assets, not save games.

### Alternative 3: No save system at any version
- **Description**: Game is permanently session-complete; save never added
- **Pros**: Zero complexity permanently
- **Cons**: Family audiences encounter real interruptions (dinner, bedtime); post-MVP this becomes a meaningful gap; replayability argument weakens if sessions can't be paused
- **Rejection Reason**: Valid for MVP but overly constraining as a permanent decision. Post-MVP path stays open via this ADR.

## Consequences

### Positive
- MVP scope stays tight — no serialization complexity in sprint planning
- PlayerState, DungeonGenerator, TurnManager stay clean (no serialization methods needed yet)
- OQ-2 from `architecture.md` is resolved — no ambiguity for sprint planning
- Post-MVP path (FileAccess + JSON) is pre-vetted and documented when the time comes

### Negative
- If a session is interrupted (power loss, child needs attention), all progress is lost
- Post-MVP retrofitting: adding `to_dict()` / `from_dict()` to 3+ systems and wiring SaveSystem is non-trivial work

### Risks
- **`user://` path tied to project name**: `user://` resolves to a folder named after Project Settings → Application → Config → Name. If the project name changes after release (e.g., from `karak_digital` to `Karak Digital`), existing save files become unreachable without migration. Lock the project name before shipping. — Mitigation: set project name in MVP sprint; do not rename post-release.
- **No atomic write**: `FileAccess` writes directly with no rollback. A crash mid-write produces a corrupted save file. — Mitigation for post-MVP: write to `user://save_game.tmp`, close file, then call `DirAccess.rename("user://save_game.tmp", "user://save_game.json")` to replace atomically.
- **JSON schema versioning**: If game fields change between versions, loading an old save with `from_dict()` may silently drop new fields or crash on missing keys. — Mitigation: include `"version": 1` in root JSON from day one; `from_dict()` implementations must handle absent keys with sensible defaults; check schema version on load before restoring.
- **Godot native type serialization**: `JSON.stringify()` does not handle `Vector2i`, `Vector2`, `Color`, `Rect2`, etc. Passing these directly produces incomplete output or errors. — Mitigation: enforce that all `to_dict()` implementations return only GDScript primitives (`int`, `float`, `String`, `bool`, `Array[primitive]`, `Dictionary[String, primitive]`). Document this as a hard contract for any future serializer.
- **ResourceSaver attempted post-MVP**: Another developer may attempt ResourceSaver for convenience. — Mitigation: this ADR explicitly rejects it and documents why (ADR-0003 conflict + .tres fragility).
- **`store_*` return value ignored**: Since 4.4, `FileAccess.store_string()` and siblings return `bool`. Ignoring the return value hides write failures silently. — Mitigation: check return value in SaveSystem; log an error if `false` is returned.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| game-concept.md | Anti-Pillar: "НЕ мета-прогрессия между сессиями" | No save in MVP means no accidental inter-session state persistence; fully aligned with this anti-pillar |
| game-concept.md | Session Length: 30–60 minutes | Short target session justifies deferring save — completing in one sitting is the design assumption |

## Performance Implications
- **CPU**: None in MVP (no save system runs)
- **Memory**: None in MVP
- **Load Time**: None in MVP
- **Network**: None

## Migration Plan
When save is added post-MVP:
1. Create follow-up ADR finalizing save schema, atomic write contract, and schema version handling
2. Add `to_dict()` / `from_dict()` to `PlayerState`, `DungeonGenerator`, `TurnManager`
3. Create `SaveSystem` Autoload with `save_game()` and `load_game()`
4. Wire save triggers in GameScene: `get_tree().root.close_requested` signal + explicit menu button
5. Add `"version": 1` to root of all save files from day one

## Validation Criteria
**MVP**: `grep -r "FileAccess\|ResourceSaver\|save_game\|load_game" src/ autoloads/` returns zero results — no save code in MVP codebase.
**Post-MVP**: Load a previously saved game → all PlayerState fields (hp, vp, inventory, position) match pre-save values exactly; dungeon grid layout identical; turn order and turn number preserved; `has_killed_dragon` flag preserved.

## Related Decisions
- ADR-0003: PlayerState as Node — makes ResourceSaver approach incompatible; any serialization must use explicit `to_dict()` methods
- ADR-0001: Autoload Strategy — SaveSystem, if added post-MVP, will follow the Autoload pattern established here
- `docs/architecture/architecture.md` OQ-2 — this ADR resolves that open question as "deferred to post-MVP"
