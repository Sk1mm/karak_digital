# ADR-0002: Signal Wiring Pattern

## Status
Accepted

## Date
2026-10-10

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.2 (GDScript) |
| **Domain** | Core |
| **Knowledge Risk** | LOW — GDScript signal API (`connect()`, `emit()`, typed signals) stable since Godot 4.0 |
| **References Consulted** | `docs/engine-reference/godot/current-best-practices.md`, `docs/engine-reference/godot/deprecated-apis.md` |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | Confirm `_wire_signals()` runs after all child `_ready()` complete; test that no signal is double-connected on scene reload |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (Autoload Strategy — establishes which systems are in-scene nodes) |
| **Enables** | ADR-0005 (DungeonGenerator Init Pattern — init() triggers signals) |
| **Blocks** | All Feature and Presentation epics — signal connections must follow this pattern |
| **Ordering Note** | Must be settled before any cross-system signal code is written. |

## Context

### Problem Statement

18 systems communicate via GDScript signals. Without a single enforced wiring
pattern, each system connects its own signals in `_ready()` — the dependency graph
becomes invisible, scattered across 18 files, and fragile when signal names change.
We need one canonical rule for where and how signals are connected.

### Constraints

- Godot 4.7.2 GDScript typed signals
- All systems are in-scene Nodes (except Autoloads which emit no signals)
- No EventBus / observer pattern (ruled out by ADR-0001)
- ~30–40 cross-system signal connections in one game session

### Requirements

- Must: The full dependency graph must be readable in one place
- Must: No double-connections on scene reload
- Must: Systems must not break if a downstream listener is absent
- Should: Systems remain self-contained enough to test in isolation

## Decision

**All cross-system signal connections are wired centrally in `GameScene._ready()`
via a dedicated `_wire_signals()` method.**

Rules:
1. **Systems do NOT call `connect()` on other systems' signals in their own `_ready()`.**
   Each system only connects its own internal signals (e.g., a Timer to a private method).
2. **`GameScene._wire_signals()` is the single authoritative source** for all
   cross-system signal topology.
3. **`_wire_signals()` is called after `dungeon_generator.init()`** — so all game
   state is initialised before signals begin firing.
4. **Typed signal syntax** is mandatory: `signal hp_changed(new_hp: int)` —
   no untyped `signal hp_changed`.
5. **Callable syntax** for connect: `signal_name.connect(target._on_method)` —
   not the legacy `connect("signal_name", target, "method_name")` string form.

### Architecture Diagram

```
GameScene._ready()
  │
  ├─ dungeon_generator.init()           ← Step A: initialise game state
  │
  └─ _wire_signals()                    ← Step B: connect all signals
       │
       ├─ Core → Feature
       │   player_state_0.knocked_out.connect(knockout_system._on_knocked_out)
       │   player_state_1.knocked_out.connect(knockout_system._on_knocked_out)
       │
       ├─ Feature → Feature
       │   dungeon_generator.dungeon_initialized.connect(turn_manager._on_dungeon_initialized)
       │   movement_system.cell_entered.connect(tile_reveal_vfx._on_cell_entered)
       │   tile_reveal_vfx.tile_reveal_complete.connect(encounter_dispatcher._on_tile_reveal_complete)
       │   encounter_dispatcher.combat_started.connect(combat_system._on_combat_started)
       │   combat_system.combat_resolved.connect(turn_manager._on_combat_resolved)
       │   combat_system.item_dropped.connect(loot_system._on_item_dropped)
       │   combat_system.dragon_killed.connect(win_condition._on_dragon_killed)
       │   loot_system.item_acquired.connect(turn_manager._on_item_acquired)
       │   win_condition.game_over.connect(turn_manager._on_game_over)
       │
       ├─ Feature → Presentation
       │   win_condition.game_over.connect(hud._on_game_over)
       │   combat_system.dice_rolled.connect(combat_ui._on_dice_rolled)
       │   combat_system.player_choice_requested.connect(combat_ui._on_player_choice_requested)
       │   combat_system.combat_resolved.connect(combat_ui._on_combat_resolved)
       │   turn_manager.turn_started.connect(hud._on_turn_started)
       │   turn_manager.step_spent.connect(hud._on_step_spent)
       │   turn_manager.turn_ended.connect(hud._on_turn_ended)
       │   turn_manager.turn_skipped.connect(hud._on_turn_skipped)
       │
       ├─ Core → Presentation
       │   player_state_0.hp_changed.connect(hud._on_hp_changed.bind(0))
       │   player_state_0.vp_changed.connect(hud._on_vp_changed.bind(0))
       │   player_state_0.item_added.connect(hud._on_item_added.bind(0))
       │   player_state_0.item_removed.connect(hud._on_item_removed.bind(0))
       │   player_state_0.knocked_out.connect(hud._on_knocked_out.bind(0))
       │   player_state_0.knockout_cleared.connect(hud._on_knockout_cleared.bind(0))
       │   # (mirror for player_state_1 with .bind(1))
       │   player_state_0.item_added.connect(inventory_ui._on_item_added.bind(0))
       │   player_state_0.item_removed.connect(inventory_ui._on_item_removed.bind(0))
       │   turn_manager.turn_started.connect(inventory_ui._on_turn_started)
       │
       └─ Presentation → Feature (единственная обратная связь)
           combat_ui.player_action_taken.connect(combat_system._on_player_action_taken)
```

### Key Interfaces

```gdscript
# GameScene.gd
extends Node

@export var player_state_0: PlayerState
@export var player_state_1: PlayerState
@export var tile_system: TileSystem
@export var dice_system: DiceSystem
@export var dungeon_generator: DungeonGenerator
@export var turn_manager: TurnManager
@export var movement_system: MovementSystem
@export var encounter_dispatcher: EncounterDispatcher
@export var combat_system: CombatSystem
@export var loot_system: LootSystem
@export var knockout_system: KnockoutSystem
@export var win_condition: WinCondition
@export var hud: HUD
@export var combat_ui: CombatUI
@export var inventory_ui: InventoryUI
@export var tile_reveal_vfx: TileRevealVFX

func _ready() -> void:
    dungeon_generator.init(
        [player_state_0, player_state_1],
        tile_system
    )
    _wire_signals()

func _wire_signals() -> void:
    # [all connections as shown in diagram above]
    pass
```

## Alternatives Considered

### Alternative A: Distributed wiring (each system connects its own signals)

- **Description**: Each system's `_ready()` connects the signals it needs from
  other systems via `@export` refs.
- **Pros**: Each system is self-contained; moving a system to another scene is easier.
- **Cons**: With 18 systems and ~35 connections, the dependency graph is invisible
  unless you read all 18 `_ready()` methods. Debugging signal issues requires
  grepping across the whole codebase. Risk of double-connection if a system is
  re-entered.
- **Rejection Reason**: Invisible dependency graph; hard to audit.

### Alternative B: EventBus Autoload (global signal relay)

- **Description**: One `EventBus` Autoload with all signals. Systems `emit` to
  EventBus; listeners connect to EventBus.
- **Pros**: Total decoupling — systems don't know about each other at all.
- **Cons**: Signal types are erased at EventBus boundary (no compiler checking of
  parameter types). EventBus becomes a God Object over time. Performance: every
  event goes through one node even if only one listener exists.
- **Rejection Reason**: Loses static type safety; encourages spaghetti topology.

### Alternative C: Dependency injection via constructor

- **Description**: Each system receives its signal sources as constructor parameters.
- **Pros**: Explicit, testable.
- **Cons**: GDScript has no constructor injection pattern for Nodes. `_init()` in
  Nodes is called before `@export` refs are assigned. Requires a factory pattern
  that doesn't exist in Godot idioms.
- **Rejection Reason**: Not idiomatic in Godot 4 for Node-based systems.

## Consequences

### Positive
- Full signal topology visible in one ~40-line method
- No double-connections: `_wire_signals()` runs once after scene load
- Systems remain independently instantiable (they expose typed handlers but don't
  connect themselves)
- Refactoring signal names requires changes in one file only

### Negative
- `GameScene.gd` has ~18 `@export` fields (one per in-scene system)
- `_wire_signals()` grows if new systems are added — mitigated by grouping
  connections into labelled comment blocks (# Core → Feature, etc.)

### Risks
- **Risk**: Developer adds a `connect()` call inside a system's `_ready()`.
  **Mitigation**: Code review rule: systems never call `.connect()` on external signals.
  Add lint comment at top of each system: `## External signal wiring: GameScene._wire_signals() only.`
- **Risk**: `_wire_signals()` is called before all child nodes finish `_ready()`.
  **Mitigation**: Godot guarantees all child `_ready()` complete before parent's `_ready()`.
  Since `_wire_signals()` is called from `GameScene._ready()`, all nodes are ready.
- **Risk**: `dungeon_generator.init()` emits `dungeon_initialized` synchronously before
  `_wire_signals()` runs — TurnManager would never receive the signal.
  **Mitigation (hard contract)**: `DungeonGenerator.init()` must NOT emit `dungeon_initialized`
  synchronously. It must either (a) emit after returning to `GameScene._ready()` via
  `call_deferred("emit_signal", "dungeon_initialized")`, or (b) GameScene calls
  `turn_manager._on_dungeon_initialized()` directly after `_wire_signals()`. ADR-0005
  documents this as a binding constraint on DungeonGenerator.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| `turn-manager.md` | TurnManager listens to `dungeon_initialized`, `combat_resolved`, `item_acquired`, `game_over` | All connections wired in `_wire_signals()`; TurnManager exposes typed `_on_*` handlers |
| `hud.md` | HUD subscribes to PlayerState signals and TurnManager signals | Centrally connected via `.bind(player_index)` for per-player routing |
| `combat-system.md` | CombatSystem receives `combat_started`; emits `combat_resolved`, `item_dropped`, `dragon_killed` | Full combat signal chain wired in `_wire_signals()` |
| `win-condition.md` | WinCondition emits `game_over(winner)` → TurnManager + HUD both listen | Single emit, two listeners — centralised wiring makes this explicit |

## Performance Implications
- **CPU**: Negligible — signal connections are function pointer registrations, O(1)
- **Memory**: ~35 Callable objects created once at scene load; freed when scene unloads
- **Load Time**: `_wire_signals()` runs in a single frame during scene init; invisible to player

## Migration Plan

No existing code — greenfield. All signal connections written fresh in `GameScene._wire_signals()`.

## Validation Criteria

1. `GameScene.gd` contains a `_wire_signals()` method
2. No `system.other_signal.connect(...)` calls exist in any system's `_ready()` (grep: `connect` in `_ready` outside `game_scene.gd`)
3. All signals in `_wire_signals()` use typed Callable syntax: `signal.connect(target.method)` not `connect("signal_name", target, "method")`
4. Removing any one system from `@export` in Inspector causes a null-check failure at scene load — not a silent data corruption

## Related Decisions
- ADR-0001: Autoload Strategy (Autoloads emit no signals — only in-scene nodes wired here)
- ADR-0003: PlayerState as Node (PlayerState signals are the Core→Presentation backbone)
- `docs/architecture/architecture.md` — Data Flow DF-2 shows the full signal chain
