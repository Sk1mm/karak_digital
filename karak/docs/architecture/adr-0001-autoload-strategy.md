# ADR-0001: Autoload Strategy

## Status
Accepted

## Date
2026-10-10

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.2 (GDScript) |
| **Domain** | Core |
| **Knowledge Risk** | LOW — Autoload API is stable since Godot 4.0; no post-cutoff changes |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `docs/engine-reference/godot/deprecated-apis.md` |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | Confirm Autoload registration order in Project Settings matches boot dependency order (ClassRegistry → ItemDatabase → MonsterDatabase) |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | None |
| **Enables** | ADR-0002 (Signal Wiring Pattern), ADR-0003 (PlayerState as Node), ADR-0005 (DungeonGenerator Init Pattern) |
| **Blocks** | All implementation epics — must be Accepted before any scene code is written |
| **Ordering Note** | Foundation ADR. Write this first; all other ADRs assume this is settled. |

## Context

### Problem Statement

Karak Digital has 18 systems across 4 layers. Some systems are pure read-only data
stores needed by many other systems (ClassRegistry, ItemDatabase, MonsterDatabase).
Others hold mutable per-session game state (PlayerState, TileSystem). We need a
clear, enforceable rule for which systems live as Godot Project Settings Autoloads
(global singletons) vs. in-scene Node instances wired via `@export`.

### Constraints

- Godot 4.7.2 GDScript — no C# or GDExtension
- 2-player hotseat; `PlayerState` has exactly 2 instances per session
- MVP has no save/load — no serialisation requirement in scope
- No networking — no need for server-authoritative singleton patterns
- Performance budget: 60fps, 2D board game — autoload overhead is negligible

### Requirements

- Global data (monster stats, item stats, class definitions) must be accessible
  from any system without passing references through every layer
- Mutable game state must never be accidentally shared between players
- Systems must be independently testable (dependency injection preferred for
  mutable state)
- Signal lifecycle must be safe: signals must auto-disconnect when nodes are freed

## Decision

**Autoloads (Project Settings → Autoload)**: read-only data registries only.

| Autoload Name | Script | Purpose |
|---------------|--------|---------|
| `ClassRegistry` | `src/foundation/class_registry.gd` | All 7 `HeroClassData` resources; `pick_random()` for class selection |
| `ItemDatabase` | `src/foundation/item_database.gd` | All 6 `ItemData` resources; `get_item(id)` lookup |
| `MonsterDatabase` | `src/foundation/monster_database.gd` | All 8 `MonsterData` resources; `get_monster(id)` lookup |

**In-scene Nodes (wired via `@export` in GameScene)**: all systems with mutable state
or lifecycle requirements.

| System | Node Type | Instances | Reason not Autoload |
|--------|-----------|-----------|---------------------|
| `PlayerState` | `Node` | ×2 | Mutable; per-player; signals need lifecycle |
| `TileSystem` | `Node2D` | ×1 | Mutable session state; TileMapLayer child |
| `DiceSystem` | `Node` | ×1 | Stateful (dice_state, RNG seed) |
| All Feature systems | `Node` | ×1 each | Stateless or ephemeral state; @export deps |
| All Presentation systems | CanvasLayer / Node2D | ×1 each | UI lifecycle tied to scene |

**No EventBus Autoload.** All cross-system signals are wired directly in
`GameScene._ready()` via `_wire_signals()` (see ADR-0002).

### Architecture Diagram

```
Project Settings Autoloads (always available, read-only):
  ClassRegistry ──────────────────────────────────────────┐
  ItemDatabase ────────────────────────────────────────────┤
  MonsterDatabase ─────────────────────────────────────────┤
                                                           │ read
GameScene (loads at session start):                        │
  ├── PlayerState[0]  (Node, @export refs to Autoloads) ◄──┘
  ├── PlayerState[1]  (Node)
  ├── TileSystem      (Node2D + TileMapLayer children)
  ├── DiceSystem      (Node)
  ├── [Feature systems] (Nodes, @export refs)
  └── [Presentation]  (CanvasLayer / Node2D)
```

### Key Interfaces

```gdscript
# Autoload access — no @export needed, accessible anywhere:
ClassRegistry.get_class(&"warrior")      # → HeroClassData
ItemDatabase.get_item(&"axe")            # → ItemData
MonsterDatabase.get_monster(&"dragon")   # → MonsterData

# In-scene access — always via @export:
@export var player_states: Array[PlayerState]
@export var tile_system: TileSystem
```

## Alternatives Considered

### Alternative A: All Systems as Autoloads
- **Description**: Every system (including PlayerState, TileSystem, TurnManager)
  registered as a Project Settings Autoload singleton.
- **Pros**: Simple global access pattern; no @export wiring needed.
- **Cons**: PlayerState as singleton breaks 2-player requirement — one global
  PlayerState cannot represent two independent players. Signal lifecycle becomes
  fragile (singletons never freed → connections accumulate). Testing requires
  mocking globals.
- **Rejection Reason**: Incompatible with ×2 PlayerState requirement. Risk of
  accidental state sharing between players.

### Alternative B: No Autoloads — All @export
- **Description**: Every system including data registries wired via `@export`
  in GameScene.
- **Pros**: Pure dependency injection; no globals; easiest to unit-test.
- **Cons**: Every system that reads item/monster/class data needs an `@export`
  reference passed from GameScene. With 18 systems, this creates ~40 additional
  @export fields and Inspector slots. CombatSystem, LootSystem, EncounterDispatcher,
  KnockoutSystem all read from these registries — passing them through every
  intermediate system violates the principle of minimal coupling.
- **Rejection Reason**: High boilerplate cost; read-only data registries have no
  mutable state and no lifecycle concerns — Autoload is appropriate.

### Alternative C: Static GDScript Classes
- **Description**: Use `static var` in standalone scripts (no Autoload, no Node)
  for data registries.
- **Pros**: No Autoload overhead; no scene-tree entry.
- **Cons**: GDScript static vars are initialised lazily with limited control over
  order; no `_ready()` lifecycle for loading `.tres` resource files; harder to
  mock in tests. Not a standard Godot pattern for resource registries.
- **Rejection Reason**: No clean initialisation lifecycle for loading `.tres` files.

## Consequences

### Positive
- Data registries accessible from any system without passing refs through layers
- PlayerState × 2 cleanly separated — no accidental sharing
- Signal lifecycle safe: PlayerState signals auto-disconnect when scene is freed
- Autoload scripts are minimal (load resources, expose lookup) — easy to test
  by calling functions directly without scene setup
- Clear rule: "is it read-only data used everywhere?" → Autoload; "does it have
  mutable state or lifecycle?" → in-scene Node

### Negative
- Autoloads are always loaded even in non-game scenes (MainMenu, etc.) — minor
  memory overhead (~KB for 3 small registries)
- Future systems that need global access but have mutable state cannot use Autoload
  without revisiting this ADR

### Risks
- **Risk**: A developer adds mutable state to an Autoload (e.g., `ItemDatabase`
  starts tracking "picked up items").
  **Mitigation**: Enforce in code review; add `assert` or `@warning_ignore` comment
  to Autoload classes: `## READ-ONLY. Never add mutable game state here.`
- **Risk**: Autoload registration order in Project Settings is incorrect, causing
  `ClassRegistry` to be `null` when `ItemDatabase._ready()` runs (if ItemDatabase
  depended on it).
  **Mitigation**: These three Autoloads are independent — no inter-Autoload dependencies.
  Order does not matter between them.
- **Invariant (boot order)**: Godot guarantees all Autoloads are fully initialised
  (their `_ready()` completed) before any GameScene node's `_ready()` runs. No deferred
  initialisation or `await` needed in Feature systems that call Autoload APIs.
- **Resource loading in Autoloads**: Use `preload()` or `load()` in `_ready()` to load
  `.tres` resource files — **not `@export` Inspector slots**. `@export` on an Autoload
  node is technically valid but non-standard; resources moved without UID tracking will
  silently break. Prefer `preload("res://assets/data/items/axe.tres")` or UID-based
  paths (`preload("uid://...")`) for all data resources in Autoloads.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| `class-system.md` | TR-cs-010: ClassRegistry Autoload — singleton storing all 7 classes | Defines ClassRegistry as Autoload with `get_class()` and `pick_random()` API |
| `item-database.md` | TR-ps-001..005: PlayerState stores inventory refs to ItemData IDs | ItemDatabase Autoload accessible from PlayerState, LootSystem, CombatSystem without @export chain |
| `monster-database.md` | TR-md-006: `get_monster(id)` lookup from CombatSystem and EncounterDispatcher | MonsterDatabase Autoload accessible directly from any Feature system |
| `player-state.md` | TR-ps-007..016: PlayerState emits signals; 2 independent instances | In-scene Node (not Autoload) guarantees 2 independent instances with proper signal lifecycle |

## Performance Implications
- **CPU**: Negligible — Autoload lookup is a singleton property access; no overhead vs local var
- **Memory**: ~KB per registry (8 MonsterData + 6 ItemData + 7 HeroClassData resources)
- **Load Time**: Resources loaded once at Autoload `_ready()`; subsequent lookups are O(1) Dictionary
- **Network**: N/A

## Migration Plan

No existing code to migrate — this is a greenfield project. Autoloads are registered
in Project Settings before any scene code is written.

## Validation Criteria

1. `ClassRegistry`, `ItemDatabase`, `MonsterDatabase` are listed in Project Settings → Autoload
2. No `PlayerState` in Autoload list
3. `CombatSystem` can call `MonsterDatabase.get_monster(&"dragon")` without any `@export` reference
4. Two `PlayerState` instances exist in GameScene with independent `hp` values (modifying one does not affect the other)
5. All Autoload classes load their resources via `preload()` or `load()` in `_ready()` — no `@export` Inspector-slot wiring; no `var` that changes during gameplay

## Related Decisions
- ADR-0002: Signal Wiring Pattern (defines how in-scene nodes connect signals)
- ADR-0003: PlayerState as Node (expands on why PlayerState is not an Autoload)
- `docs/architecture/architecture.md` — System Layer Map and Module Ownership sections
