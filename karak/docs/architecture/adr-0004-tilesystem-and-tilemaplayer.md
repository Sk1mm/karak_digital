# ADR-0004: TileSystem and TileMapLayer

## Status
Accepted

## Date
2026-10-11

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.2 (GDScript) |
| **Domain** | Core |
| **Knowledge Risk** | LOW — TileMapLayer confirmed stable in 4.7.2; TileMap deprecation started 4.3 |
| **References Consulted** | `docs/engine-reference/godot/current-best-practices.md`, `docs/engine-reference/godot/deprecated-apis.md` |
| **Post-Cutoff APIs Used** | `TileMapLayer` (confirmed stable in 4.7.2 per deprecated-apis.md) |
| **Verification Required** | (1) Confirm `TileMapLayer.set_cell(pos, source_id, atlas_coords)` renders tile atlas correctly. (2) Confirm `Dictionary[Vector2i, DungeonCell]` compiles in 4.7.2 — plain class with no `extends` implicitly extends RefCounted, which is a valid typed dict value type since Godot 4.4. |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (Autoload Strategy — TileSystem is in-scene Node, not Autoload), ADR-0002 (Signal Wiring — `cell_revealed` signal wired in GameScene) |
| **Enables** | ADR-0005 (DungeonGenerator Init Pattern — DungeonGenerator calls TileSystem `init_pools()`) |
| **Blocks** | TileSystem implementation epic, DungeonGenerator implementation epic |
| **Ordering Note** | Must be decided before DungeonGenerator (ADR-0005) because DungeonGenerator's init() API depends on TileSystem's data model. |

## Context

### Problem Statement

`TileSystem` is the dungeon's memory: it owns the grid of 80 tiles, two shuffle
pools (80 `TileData` + 53 `EventToken`), and all mutable cell state
(`is_revealed`, `is_cleared`, `loose_key`). It also drives visual rendering of
the board via a child node that displays tile graphics.

Three interrelated decisions must be made together:

1. **Rendering node**: `TileMap` (deprecated since 4.3) vs `TileMapLayer` (current API)
2. **Grid cell type**: how to represent a `DungeonCell` — Resource, Node, or plain class
3. **Grid storage**: Dictionary vs Array for `Vector2i → DungeonCell` lookup

The choice of cell type affects memory, GC pressure, inspector visibility, and
save/load feasibility.

### Constraints

- Engine: Godot 4.7.2 — `TileMap` is deprecated; `TileMapLayer` is the current API
- Grid size: ~80 placed tiles (board game, not a large world)
- MVP: no save/load — serialization not required now
- `DungeonCell` has no signals, no `_ready()` lifecycle, no Inspector assignment
- `DungeonCell` is mutable runtime state, not read-only data
- Performance: 60fps 2D board game — cell lookups per frame are rare (only on player
  movement input)

### Requirements

- Must: Use non-deprecated rendering node API (TileMapLayer, not TileMap)
- Must: Grid lookup by `Vector2i` position — O(1) or O(log n) acceptable
- Must: `DungeonCell` instances are independent (no shared state between cells)
- Should: Cell type choice is compatible with future save/load (add serialization later)
- Should: Minimize Node count in Scene Tree (cell objects should not be Nodes)

## Decision

### 1. Rendering: `TileMapLayer`

`TileSystem extends Node2D` with one or more `TileMapLayer` child nodes for
dungeon tile rendering. `TileMap` is deprecated since Godot 4.3 and must not
be used.

Each `TileMapLayer` represents one logical visual layer:
- `ground_layer: TileMapLayer` — floor/tile graphics
- `object_layer: TileMapLayer` — overlays, fog of war, markers (if needed)

`TileSystem._ready()` gets these via `@onready` — they are placed in the scene.

### 2. Grid Cell Type: Plain GDScript Class (`class_name DungeonCell`)

`DungeonCell` is a plain GDScript class (`class_name DungeonCell`, no `extends`).
It is **not** a `Resource` and **not** a `Node`.

Rationale:
- No signals needed → Node overhead not justified
- No `_ready()` lifecycle needed → Node overhead not justified
- No `.tres` serialization needed for MVP → Resource not needed
- Plain class instances are lightweight, independently mutable, and garbage-collected
  when the Dictionary entry is removed
- `class_name DungeonCell` makes the type statically checkable across the project

Future save/load: add `func to_dict() -> Dictionary` / `func from_dict(d: Dictionary)` to
`DungeonCell` post-MVP without changing the Node or Resource architecture.

### 3. Grid Storage: `Dictionary` with `Vector2i` keys

The tile grid is stored as `var _grid: Dictionary = {}` on `TileSystem`, with
`Vector2i` as keys and `DungeonCell` as values.

Rationale:
- Dungeon is sparse: only placed tiles exist in the Dictionary
- `Vector2i` keys are value types — no accidental aliasing
- O(1) average lookup — acceptable for a board game with rare movement events
- `_grid.has(pos)` cleanly distinguishes "placed" from "not yet placed" cells

### Architecture Diagram

```
GameScene
  └── TileSystem   (Node2D — owns all dungeon state)
        ├── ground_layer    (TileMapLayer — tile visuals)
        ├── [object_layer]  (TileMapLayer — optional overlays)
        │
        var _grid: Dictionary[Vector2i, DungeonCell] = {}  # sparse: only placed tiles
        var _tile_pool: Array[TileData]      # shuffle pool (80 tiles)
        var _event_pool: Array[EventToken]   # shuffle pool (53 tokens)
```

```
DungeonCell (plain class — no extends)
  var position: Vector2i
  var shape: int             # TileShape enum value
  var rotation: int          # 0 / 90 / 180 / 270
  var category: int          # TileCategory enum value
  var is_revealed: bool
  var is_cleared: bool
  var event_type: int        # EventType enum value; -1 = none
  var event_content_id: StringName
  var loose_key: bool
```

### Key Interfaces

```gdscript
# TileSystem.gd
class_name TileSystem
extends Node2D

## External signal wiring: GameScene._wire_signals() only.

signal cell_revealed(pos: Vector2i, cell: DungeonCell)

@onready var ground_layer: TileMapLayer = $GroundLayer

var _grid: Dictionary[Vector2i, DungeonCell] = {}  # typed; DungeonCell implicitly extends RefCounted
var _tile_pool: Array[TileData] = []
var _event_pool: Array[EventToken] = []

# --- Read API ---
func get_cell(pos: Vector2i) -> DungeonCell          # null if not placed
func get_exits(pos: Vector2i) -> Array[int]          # Array of Direction enum ints
func is_cell_revealed(pos: Vector2i) -> bool
func is_cell_cleared(pos: Vector2i) -> bool
func has_loose_key(pos: Vector2i) -> bool

# --- Pool API (called by DungeonGenerator in init) ---
func init_pools(tile_pool: Array[TileData], event_pool: Array[EventToken]) -> void

# --- Mutation API ---
func draw_tile() -> TileData                          # pop from _tile_pool; null if empty
func place_cell(pos: Vector2i, tile: TileData, rotation: int) -> void
func reveal_cell(pos: Vector2i) -> void               # emits cell_revealed
func clear_cell(pos: Vector2i) -> void
func draw_event_token() -> EventToken                 # pop from _event_pool; null if empty
func place_loose_key(pos: Vector2i) -> void
func remove_loose_key(pos: Vector2i) -> void


# DungeonCell.gd
class_name DungeonCell
# No extends — plain GDScript class

var position: Vector2i
var shape: int              # GameEnums.TileShape
var rotation: int           # 0, 90, 180, 270
var category: int           # GameEnums.TileCategory
var is_revealed: bool = false
var is_cleared: bool = false
var event_type: int = -1    # GameEnums.EventType; -1 = no event
var event_content_id: StringName = &""
var loose_key: bool = false

func get_exits() -> Array[int]:
    # Returns Array of GameEnums.Direction values from shape + rotation
    pass
```

## Alternatives Considered

### Alternative A: `TileMap` (deprecated)

- **Description**: Use the legacy `TileMap` node with layer index 0.
- **Pros**: Familiar; was the standard pre-4.3.
- **Cons**: Deprecated since Godot 4.3 per `current-best-practices.md` and
  `deprecated-apis.md`. Will be removed in a future Godot release. Non-standard
  for a Godot 4.7.2 project.
- **Rejection Reason**: Deprecated API. Not acceptable for a new project.

### Alternative B: `DungeonCell extends Resource`

- **Description**: Store each cell as a `.tres`-serializable Resource.
- **Pros**: Serializable out of the box; inspector-visible if @exported.
- **Cons**: Resource overhead without benefit — cells are never loaded from `.tres`
  files; they are created at runtime by DungeonGenerator. Resource has no `_ready()`
  lifecycle (not needed here, but adds confusion). A plain class is clearer for
  "this is runtime data, not an asset."
- **Rejection Reason**: Resource overhead without serialization benefit at MVP stage.
  Pattern is confusing (mutable runtime data as Resource contradicts Resource semantics).

### Alternative C: `DungeonCell extends Node`

- **Description**: Each cell is a Node placed in the Scene Tree.
- **Pros**: Inspector-visible; can have signals; full lifecycle.
- **Cons**: 80 Nodes in Scene Tree for the dungeon grid — significant overhead for
  data objects that need none of the Node features (no signals, no `_ready()`).
  Adds noise to Scene Tree debugger. GC is heavier.
- **Rejection Reason**: Node overhead unjustified. Cells are data, not scene objects.

### Alternative D: `Array[Array]` grid (2D array)

- **Description**: Grid stored as `Array[Array]` indexed by x/y.
- **Pros**: O(1) access; compact.
- **Cons**: Fixed-size allocation required upfront; sparse dungeon wastes memory;
  `array[x][y]` vs `array[y][x]` confusion; bounds checking is manual.
  `Dictionary[Vector2i, DungeonCell]` is cleaner and naturally sparse.
- **Rejection Reason**: Dictionary is more idiomatic for sparse spatial data in Godot.

## Consequences

### Positive
- `TileMapLayer` is the current stable API — no deprecation risk
- `DungeonCell` as plain class: minimal overhead, clean semantics ("runtime data")
- Sparse `Dictionary` grid: only placed tiles consume memory; unplaced positions
  return `null` cleanly from `get_cell()`
- Future save/load: `DungeonCell.to_dict()` can be added without architecture change
- `TileSystem` Scene Tree: one `Node2D` + 1-2 `TileMapLayer` children = small footprint

### Negative
- `DungeonCell` as plain class: not inspector-visible (no `@export`). Debugging
  requires custom print methods or the Godot debugger's variable watch.
- `Dictionary` lookup: minor GC pressure from `Vector2i` boxing — negligible for 80 tiles

### Risks
- **Risk**: Developer uses deprecated `TileMap` instead of `TileMapLayer`.
  **Mitigation**: `TileMap` is listed in forbidden patterns in this registry.
  ADR explicitly bans it.
- **Risk**: `get_cell()` returns `null` for unplaced positions — callers must null-check.
  **Mitigation**: Document contract: "returns null if pos is not yet placed."
  Callers (MovementSystem, EncounterDispatcher) must assert or guard.
- **Risk**: `DungeonCell.get_exits()` called before `shape` and `rotation` are set.
  **Mitigation**: `get_exits()` asserts that `category` is set (i.e., cell is initialized).
- **Risk**: Developer calls `set_cell()` with a leading layer index (legacy `TileMap` pattern:
  `set_cell(0, pos, source_id, atlas_coords)`).
  **Mitigation**: `TileMapLayer.set_cell()` takes `(pos: Vector2i, source_id: int, atlas_coords: Vector2i)` —
  no layer index. Document this in `TileSystem.gd`'s `place_cell()` implementation comment.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| `tile-system.md` | TR-ts-001: 5 tile categories (CORRIDOR/ROOM/FOUNTAIN/FOUNTAIN_SECONDARY/PORTAL) | `DungeonCell.category: int` (GameEnums.TileCategory); all categories storable |
| `tile-system.md` | TR-ts-002: 4 tile shapes + rotation; exits computed dynamically | `DungeonCell.get_exits()` computes from `shape + rotation`; not stored separately |
| `tile-system.md` | TR-ts-003: 80-tile pool + 53 event-token pool | `TileSystem._tile_pool: Array[TileData]` + `_event_pool: Array[EventToken]` |
| `tile-system.md` | TR-ts-004: Cell state machine (HIDDEN/REVEALED/CLEARED) | `DungeonCell.is_revealed + is_cleared` fields; `reveal_cell()` / `clear_cell()` mutators |
| `tile-system.md` | TR-ts-005: `loose_key` flag per cell | `DungeonCell.loose_key: bool` |
| `tile-system.md` | TR-ts-006: Signal `cell_revealed(pos, cell)` for TileRevealVFX | `TileSystem.cell_revealed` typed signal |
| `tile-system.md` | AC-11: Compatible exits between adjacent cells | `get_exits()` on `DungeonCell` enables `compatible(a, b)` check in DungeonGenerator |

## Performance Implications
- **CPU**: `Dictionary[Vector2i]` lookup: O(1) average. 80 max entries. Negligible.
- **Memory**: 80 `DungeonCell` objects + 1 `Dictionary` = ~KB total. Negligible.
- **Load Time**: Pool initialization in `DungeonGenerator.init()` (shuffle 80+53 items): <1ms.
- **TileMapLayer rendering**: standard Godot batched tile renderer; no custom draw calls.

## Migration Plan

No existing code — greenfield. `TileSystem` Node2D + `TileMapLayer` children
placed in GameScene scene before first run. `DungeonCell` class file created at
`src/core/tile_system/dungeon_cell.gd`.

## Validation Criteria

1. `TileSystem` has no `TileMap` node — only `TileMapLayer` children
2. `DungeonCell` class has no `extends` clause (plain class) — confirmed by `grep "extends" dungeon_cell.gd`
3. `tile_system.get_cell(Vector2i(99, 99))` returns `null` (unplaced position)
4. `tile_system.reveal_cell(pos)` emits `cell_revealed(pos, cell)` signal
5. `DungeonCell` with `shape = L_TURN, rotation = 90` → `get_exits()` returns `[Direction.E, Direction.S]` (AC-03)
6. `_tile_pool.size() == 80` and `_event_pool.size() == 53` after `init_pools()` (AC-01)

## Related Decisions
- ADR-0001: Autoload Strategy (TileSystem is in-scene Node2D, not Autoload)
- ADR-0002: Signal Wiring Pattern (`cell_revealed` wired in `GameScene._wire_signals()`)
- ADR-0005: DungeonGenerator Init Pattern (calls `TileSystem.init_pools()`)
- ADR-0007: GameEnums Global Class (TileShape, TileCategory, Direction enums)
- `docs/architecture/architecture.md` — Core Layer module ownership
