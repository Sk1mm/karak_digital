# ADR-0005: DungeonGenerator Init Pattern

## Status
Accepted

## Date
2026-10-11

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.2 (GDScript) |
| **Domain** | Core |
| **Knowledge Risk** | LOW — `call_deferred`, `_ready()` order, and signal lifecycle are stable since Godot 4.0 |
| **References Consulted** | `docs/engine-reference/godot/current-best-practices.md`, `docs/engine-reference/godot/deprecated-apis.md` |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | Confirm `call_deferred("emit_signal", "dungeon_initialized")` fires after `_wire_signals()` completes; confirm TurnManager receives `dungeon_initialized` on first session start |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0002 (Signal Wiring Pattern — establishes that `_wire_signals()` must run before signals fire), ADR-0004 (TileSystem — `initialize()` calls `TileSystem.init_pools()`) |
| **Enables** | TurnManager implementation (TurnManager's `_on_dungeon_initialized()` is its bootstrap entry point) |
| **Blocks** | DungeonGenerator implementation epic, TurnManager implementation epic |
| **Ordering Note** | ADR-0002 identified the timing problem (fp-005: synchronous_dungeon_initialized_emit) and deferred its resolution here. This ADR is the authoritative resolution of that constraint. |

## Context

### Problem Statement

`DungeonGenerator.initialize()` builds the dungeon state and must run **before**
`GameScene._wire_signals()` — because it populates TileSystem's pools and places
the start tile, which TurnManager needs as preconditions for its first turn.

However, `DungeonGenerator` emits `dungeon_initialized` to signal TurnManager that
the game is ready to start. `TurnManager` must be connected to that signal **before**
it fires — which requires `_wire_signals()` to have already run.

This creates a strict ordering requirement:
1. `initialize()` must run first (populates game state)
2. `_wire_signals()` must run second (connects all listeners)
3. `dungeon_initialized` must fire after step 2

If `initialize()` emits `dungeon_initialized` synchronously, TurnManager misses the
signal because `_wire_signals()` has not yet run. This is forbidden pattern fp-005
from ADR-0002.

### Constraints

- Godot `_ready()` is single-threaded — all of `GameScene._ready()` runs in one frame
- `call_deferred()` queues a call to execute at the end of the current frame, after
  `_ready()` completes — this naturally satisfies the ordering requirement
- DungeonGenerator is stateless after `initialize()` completes (one-shot system)
- No `await` in `_ready()` — async patterns in `_ready()` are avoided per Godot best practice
- The GDD defines the public API as `initialize(seed: int = -1)` — this name is canonical

### Requirements

- Must: `dungeon_initialized` signal fires only after `_wire_signals()` completes
- Must: TileSystem is fully populated before any Feature system is active
- Must: PlayerState.position is set to `Vector2i(0, 0)` before TurnManager starts
- Should: No `await` in `GameScene._ready()` — synchronous init preferred

## Decision

**`DungeonGenerator.initialize()` uses `call_deferred` to emit `dungeon_initialized`
after `GameScene._ready()` finishes (and thus after `_wire_signals()` completes).**

### Execution Order

```
GameScene._ready()                          ← Frame N, start
  │
  ├─ dungeon_generator.initialize(seed)     ← Step A: populate game state
  │     │  builds tile_pool + event_pool
  │     │  calls tile_system.init_pools(...)
  │     │  calls tile_system.place_cell(Vector2i(0,0), ...)
  │     │  calls player_state_0.set_position(Vector2i(0,0))
  │     │  calls player_state_1.set_position(Vector2i(0,0))
  │     └─ call_deferred("_emit_initialized")  ← queued, not fired yet
  │
  └─ _wire_signals()                        ← Step B: connect all listeners
        │  turn_manager._on_dungeon_initialized connected
        │  all other signals connected
        └─ returns
                                            ← Frame N, _ready() complete
                                            ← Deferred queue flushes:
                                            ← dungeon_generator._emit_initialized()
                                                 dungeon_initialized.emit()
                                                 → turn_manager._on_dungeon_initialized()
                                                 (connection is live — fires correctly)
```

### Key Interfaces

```gdscript
# DungeonGenerator.gd
class_name DungeonGenerator
extends Node

## External signal wiring: GameScene._wire_signals() only.

signal dungeon_initialized()

func initialize(seed: int = -1) -> void:
    # --- ШАГ 1: seed ---
    var rng := RandomNumberGenerator.new()
    if seed == -1:
        rng.randomize()
    else:
        rng.seed = seed

    # --- ШАГ 2: build pools ---
    var tile_pool: Array[TileData] = _build_tile_pool()
    var event_pool: Array[EventToken] = _build_event_pool()
    _shuffle(tile_pool, rng)
    _shuffle(event_pool, rng)

    # --- ШАГ 3: hand pools to TileSystem ---
    tile_system.init_pools(tile_pool, event_pool)

    # --- ШАГ 4: place start tile ---
    tile_system.place_cell(Vector2i(0, 0), _extract_fountain(tile_pool), 0)

    # --- ШАГ 5: set player start positions ---
    for ps: PlayerState in player_states:
        ps.set_position(Vector2i(0, 0))

    # --- ШАГ 6: deferred signal — fires AFTER _wire_signals() ---
    _emit_initialized.call_deferred()   # Callable form — type-safe, preferred over string-based call_deferred

func _emit_initialized() -> void:
    dungeon_initialized.emit()

func get_start_tile() -> Vector2i:
    return Vector2i(0, 0)   # constant — Fountain is always at origin


# GameScene.gd
func _ready() -> void:
    dungeon_generator.initialize()   # Step A — game state ready; signal deferred
    _wire_signals()                  # Step B — connections live
    # Deferred queue fires dungeon_initialized after _ready() returns
```

### Why not call TurnManager directly?

An alternative to `call_deferred` is for `GameScene._ready()` to call
`turn_manager._on_dungeon_initialized()` directly after `_wire_signals()`:

```gdscript
func _ready() -> void:
    dungeon_generator.initialize()
    _wire_signals()
    turn_manager._on_dungeon_initialized()   # direct bootstrap
```

This is valid and simpler. The `call_deferred` approach was chosen because:
1. It keeps `GameScene._ready()` clean — no direct calls to internal system methods
2. It preserves the signal-driven architecture — TurnManager's bootstrap is always
   triggered by the same signal, whether in the normal game flow or in future replay/
   restart scenarios
3. It matches the pattern documented in ADR-0002's Risks section (fp-005 mitigation)

Both options are acceptable. `call_deferred` is the canonical choice for this project.

## Alternatives Considered

### Alternative A: Synchronous emit inside `initialize()`

- **Description**: `dungeon_initialized.emit()` called directly at the end of
  `initialize()`, before `_wire_signals()` runs.
- **Pros**: Simple — one call, no deferred queue.
- **Cons**: TurnManager misses the signal because it is not yet connected.
  GameScene would need to call `initialize()` after `_wire_signals()` — but then
  `_wire_signals()` must connect signals from uninitialized nodes (race condition
  risk on signal parameter values).
- **Rejection Reason**: Violates fp-005 (ADR-0002). TurnManager never receives
  `dungeon_initialized` → game never starts.

### Alternative B: `await` in `GameScene._ready()`

- **Description**: Use `await dungeon_generator.dungeon_initialized` in `_ready()`
  after `_wire_signals()`:
  ```gdscript
  func _ready() -> void:
      dungeon_generator.initialize()   # emits synchronously
      _wire_signals()
      await dungeon_generator.dungeon_initialized  # wait for it
  ```
  But this fails for the same reason as Alternative A — the signal fires before
  `_wire_signals()` runs, so the `await` never resolves.
- **Pros**: Async-friendly if the design ever needs async init.
- **Cons**: Doesn't solve the ordering problem. `await` in `_ready()` creates a
  coroutine that suspends `_ready()`, which can cause subtle ordering bugs in
  Godot when child nodes' `_ready()` depends on parent's `_ready()` completing.
- **Rejection Reason**: Doesn't solve the timing problem; `await` in `_ready()` is
  an anti-pattern for synchronous init.

### Alternative C: Two-phase init with explicit `start()`

- **Description**: `GameScene._ready()` calls `dungeon_generator.prepare()` (builds
  pools, no signal), then `_wire_signals()`, then `dungeon_generator.start()` (emits
  `dungeon_initialized` synchronously).
- **Pros**: Explicit, no deferred queue, readable ordering.
- **Cons**: Two public methods instead of one; `start()` would be called from
  `GameScene._ready()` which breaks the pattern that no system method is called
  after `_wire_signals()`.
- **Relationship to chosen**: Functionally equivalent to `call_deferred`. The chosen
  approach keeps a single `initialize()` entry point.

## Consequences

### Positive
- `dungeon_initialized` always fires after all signals are wired — no missed signal
- `initialize()` remains a single entry point — clear API
- `GameScene._ready()` is readable: `initialize()` → `_wire_signals()` (two steps)
- Restart/replay: calling `initialize()` again will re-emit `dungeon_initialized`
  via deferred queue — TurnManager receives it correctly if signals are still live

### Negative
- `call_deferred` adds one frame of latency before TurnManager activates — invisible
  to the player, but developers debugging startup may be surprised by the deferred call
- Developers must not add synchronous post-init logic that depends on TurnManager
  being active within `_ready()` itself

### Risks
- **Risk**: Developer adds logic after `dungeon_generator.initialize()` in `_ready()`
  that assumes TurnManager is already bootstrapped. TurnManager is NOT bootstrapped
  until the deferred frame.
  **Mitigation**: Document in `GameScene.gd` header: "TurnManager is not active
  until the frame after `_ready()` — do not query TurnManager state in `_ready()`."
- **Risk**: `call_deferred("_emit_initialized")` string-based method call —
  typo in method name causes silent failure (no signal emitted, no error at `_ready()` time).
  **Mitigation**: Use `call_deferred("_emit_initialized")` consistently; add an
  `assert(has_method("_emit_initialized"))` in `initialize()` during development builds.
  Alternatively, use the Callable form: `_emit_initialized.call_deferred()` (Godot 4 preferred).
- **Risk**: `initialize()` called more than once (e.g., restart without scene reload).
  **Mitigation**: Add guard `if _initialized: push_error(...); return` at top of `initialize()`.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| `dungeon-generator.md` | Rule 1: DungeonGenerator runs once at game init | `initialize()` one-shot; `_initialized` guard prevents double-call |
| `dungeon-generator.md` | Rule 2: Init sequence — pools → shuffle → TileSystem → start tile → player positions | Documented execution order in `initialize()` with step comments |
| `dungeon-generator.md` | Rule 3: FOUNTAIN extracted before shuffle, placed first | `_extract_fountain()` called before `_shuffle()` |
| `dungeon-generator.md` | Rule 4: Optional seed for replay/testing | `initialize(seed: int = -1)` signature |
| `dungeon-generator.md` | Signal `dungeon_initialized` → TurnManager | `call_deferred` ensures TurnManager is connected before signal fires |

## Performance Implications
- **CPU**: Pool construction (80+53 items) + shuffle: <1ms. `call_deferred`: one queued call. Negligible.
- **Memory**: Transient — tile pool and event pool transferred to TileSystem; DungeonGenerator holds no data after init.
- **Load Time**: One-frame startup cost for deferred emit — invisible to player (no visual output in that frame).

## Migration Plan

No existing code — greenfield. `DungeonGenerator` created fresh using this pattern.

## Validation Criteria

1. `TurnManager._on_dungeon_initialized()` is called exactly once per session start
2. Calling `dungeon_generator.initialize()` twice logs a `push_error` and ignores the second call
3. `tile_system._tile_pool.size() == 79` after `initialize()` (80 tiles minus 1 FOUNTAIN placed)
4. `tile_system._event_pool.size() == 53` after `initialize()`
5. `tile_system.get_cell(Vector2i(0, 0)).category == TileCategory.FOUNTAIN` after `initialize()`
6. With fixed seed `12345`, `tile_pool[0]` is the same tile on two consecutive runs (shuffle determinism)

## Related Decisions
- ADR-0002: Signal Wiring Pattern (fp-005 — synchronous emit forbidden; this ADR resolves it)
- ADR-0004: TileSystem and TileMapLayer (`initialize()` calls `TileSystem.init_pools()`)
- `docs/architecture/architecture.md` — Data Flow DF-1 (boot order)
