# ADR-0009: CanvasLayer Hierarchy

## Status
Accepted

## Date
2026-10-11

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.2 (GDScript) |
| **Domain** | UI / Rendering |
| **Knowledge Risk** | LOW — `CanvasLayer`, `Control`, layer ordering, and `Control` transforms are stable in 4.7.2 |
| **References Consulted** | `docs/engine-reference/godot/current-best-practices.md`, `docs/engine-reference/godot/deprecated-apis.md` |
| **Post-Cutoff APIs Used** | `Control` position/rotation/scale direct manipulation (new in Godot 4.7 — confirmed in current-best-practices.md) |
| **Verification Required** | Confirm CombatUI CanvasLayer (layer=11) renders above HUD (layer=10) when both are visible; confirm `Control` position animation works in 4.7.2 |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0002 (Signal Wiring — `player_action_taken` is the only Presentation→Feature signal), ADR-0003 (PlayerState as Node — HUD holds @export refs to PlayerState) |
| **Enables** | HUD implementation epic, CombatUI implementation epic, InventoryUI implementation epic |
| **Blocks** | Presentation layer implementation — layer numbers must be agreed before placing CanvasLayer nodes in scene |
| **Ordering Note** | Layer numbers must be assigned before the GameScene scene file is created. Once assigned they are stable — changing layer numbers breaks InspectorExport order. |

## Context

### Problem Statement

The Presentation layer has 4 components:
- `HUD` — permanent status overlay (HP, VP, inventory, turn indicator)
- `CombatUI` — modal overlay during active combat (dice, choice buttons)
- `InventoryUI` — optional overlay for inventory detail view
- `TileRevealVFX` — tile flip animation effects over the board

The question is which of these should use `CanvasLayer` and at what layer numbers,
and which should use `Node2D` (rendered in scene space, affected by camera).

A second question: the only signal that flows Presentation→Feature is
`combat_ui.player_action_taken → combat_system._on_player_action_taken`.
This is an exception to the strict "Presentation reads, Feature writes" rule.
Where and how is it documented?

### Constraints

- Godot `CanvasLayer` renders its children in a fixed 2D viewport independent of
  camera position — correct for persistent UI (HUD always visible)
- `CanvasLayer.layer` controls stacking order: higher number = rendered on top
- Godot default UI layer for `CanvasLayer` is 1; game world renders at 0
- CombatUI must render above HUD when combat is active (modal overlay)
- `TileRevealVFX` must follow the camera/board position — `Node2D` in scene space
- Godot 4.7 added direct `position`/`rotation`/`scale` manipulation on `Control`
  nodes — enables UI animations without workarounds (confirmed in current-best-practices.md)

### Requirements

- Must: CombatUI renders on top of HUD when both are visible
- Must: HUD is always present; CombatUI and InventoryUI are shown/hidden on demand
- Must: TileRevealVFX animations follow the tile board (scene-space Node2D)
- Must: The single Presentation→Feature signal (`player_action_taken`) is documented
  as the only exception to the Presentation read-only rule
- Should: Layer numbers leave headroom for future overlays (no gap-filling required
  for the 9-ADR MVP scope)

## Decision

### Layer Assignment

| System | Node Type | `layer` | Visible | Notes |
|--------|----------|---------|---------|-------|
| `HUD` | `CanvasLayer` | 10 | Always | Status panels, VP, inventory slots |
| `InventoryUI` | `CanvasLayer` | 10 | On demand | Same layer as HUD; shown when player opens inventory |
| `CombatUI` | `CanvasLayer` | 11 | During combat | Above HUD — modal; hidden outside combat |
| `TileRevealVFX` | `Node2D` | — | Always | Scene space — follows camera; not CanvasLayer |

Layer 10 for HUD and InventoryUI: they are peers, not overlapping — InventoryUI
occupies screen space HUD does not (e.g., a side panel or full-screen overlay that
hides HUD). If InventoryUI ever needs to overlap HUD, it should move to layer 12.
At equal `layer` values Godot uses scene-tree order as tiebreaker — place InventoryUI
after HUD in the GameScene tree as a convention.

Layer 11 for CombatUI: one step above HUD. CombatUI is modal — it takes full input
focus during combat. HUD remains visible beneath it (health and VP visible during
combat is a GDD requirement).

Layers 1–9: reserved for future use (menus, loading screens, pause overlay).
Layers 12+: available for future post-MVP overlays.

### Presentation→Feature Exception: `player_action_taken`

The strict architecture rule is: Presentation layer reads Core state via signals and
`@export` refs; it never modifies game state and never calls Feature layer methods
directly.

`CombatUI.player_action_taken` is the **one exception**: it is a signal emitted by
CombatUI (Presentation) and consumed by CombatSystem (Feature). It represents the
player's combat decision and must flow upward.

This exception is acceptable because:
1. It uses the signal pattern — not a direct method call
2. It is wired in `GameScene._wire_signals()` (ADR-0002 pattern)
3. `CombatAction` is a typed Resource (ADR-0006) — statically type-safe
4. Without this signal, CombatSystem would need to poll CombatUI or CombatUI would
   need a direct reference to CombatSystem (worse coupling)

All other Presentation→Feature communication is prohibited.

### Architecture Diagram

```
CanvasLayer (layer=11)  CombatUI
  │  shows/hides during combat
  │  emits: player_action_taken(action: CombatAction)  ← ONLY P→F signal
  │
CanvasLayer (layer=10)  HUD
  │  always visible
  │  emits: nothing
  │
CanvasLayer (layer=10)  InventoryUI
  │  shows/hides on demand
  │  emits: nothing
  │
Node2D (scene space)    TileRevealVFX
  │  tile flip animations, follows camera
  │  emits: tile_reveal_complete(pos: Vector2i)
  │
Node2D (scene space)    Board / TileSystem
```

### Key Interfaces

```gdscript
# HUD.gd
class_name HUD
extends CanvasLayer

## CanvasLayer.layer = 10 (set in Inspector)
## External signal wiring: GameScene._wire_signals() only.
## PURE READER — emits no signals; only reacts to Core and Feature signals.

@export var player_state_0: PlayerState
@export var player_state_1: PlayerState

func _on_hp_changed(new_hp: int, player_index: int) -> void: pass
func _on_vp_changed(new_vp: float, player_index: int) -> void: pass
func _on_item_added(item: ItemData, slot_type: int, player_index: int) -> void: pass
func _on_item_removed(item: ItemData, slot_type: int, player_index: int) -> void: pass
func _on_knocked_out(player_index: int) -> void: pass
func _on_knockout_cleared(player_index: int) -> void: pass
func _on_turn_started(player: PlayerState) -> void: pass
func _on_step_spent(steps_remaining: int) -> void: pass
func _on_game_over(winner: PlayerState) -> void: pass


# CombatUI.gd
class_name CombatUI
extends CanvasLayer

## CanvasLayer.layer = 11 (set in Inspector)
## External signal wiring: GameScene._wire_signals() only.
## EXCEPTION: emits player_action_taken — the only Presentation→Feature signal.

signal player_action_taken(action: CombatAction)

func _on_player_choice_requested(options: CombatOptions) -> void: pass
func _on_dice_rolled(dice_state: Array) -> void: pass
func _on_combat_resolved(won: bool, six_rolled: bool) -> void: pass


# TileRevealVFX.gd
class_name TileRevealVFX
extends Node2D

## Node2D — scene space, follows camera. NOT a CanvasLayer.
## External signal wiring: GameScene._wire_signals() only.

signal tile_reveal_complete(pos: Vector2i)

func _on_cell_revealed(pos: Vector2i, cell: DungeonCell) -> void: pass
```

## Alternatives Considered

### Alternative A: All Presentation nodes as CanvasLayer

- **Description**: `TileRevealVFX` also uses `CanvasLayer` instead of `Node2D`.
- **Pros**: Consistent — all Presentation uses CanvasLayer.
- **Cons**: `TileRevealVFX` renders tile flip animations on the game board — its
  position must follow the tile grid, which is in scene space. A `CanvasLayer` is
  fixed to the viewport, not the scene; tile flip animations would not align with
  board tiles if the camera moves. `Node2D` in scene space is the correct choice
  for any visual effect that tracks scene-world positions.
- **Rejection Reason**: `CanvasLayer` for scene-space animations causes position
  misalignment when camera moves.

### Alternative B: CombatUI and HUD at same layer (both layer=10)

- **Description**: Both HUD and CombatUI at `CanvasLayer.layer = 10`. Show/hide
  as needed.
- **Pros**: Simpler — only one layer value to remember.
- **Cons**: At the same layer, CombatUI and HUD are siblings. Godot renders siblings
  at the same layer in scene-tree order — the second sibling in the tree renders on
  top. This creates an implicit ordering dependency on the scene tree rather than an
  explicit layer declaration. If nodes are reordered in the scene tree (common
  during development), the rendering order changes unexpectedly.
- **Rejection Reason**: Implicit ordering via scene tree position is fragile.
  Explicit `layer` values are the correct mechanism.

### Alternative C: Direct method call CombatUI → CombatSystem (no signal)

- **Description**: CombatUI holds an `@export` ref to CombatSystem and calls
  `combat_system._on_player_action_taken(action)` directly.
- **Pros**: Simpler — no signal needed.
- **Cons**: Creates a direct Presentation→Feature reference — CombatUI depends on
  CombatSystem explicitly. Violates the layer separation principle. Makes CombatUI
  untestable without CombatSystem present.
- **Rejection Reason**: Direct upward call violates layer boundaries. Signal is the
  correct decoupled mechanism.

## Consequences

### Positive
- Clear layer hierarchy: game world → HUD (10) → CombatUI (11)
- CombatUI always renders above HUD — no scene-tree reorder can change this
- `TileRevealVFX` in scene space — tile flip animations always align with board tiles
- The single P→F signal exception is explicit and documented — no hidden coupling
- Layer numbers 1–9 and 12+ available for future UI without collision
- Showing/hiding `CanvasLayer` nodes via `visible = true/false` hides the entire
  layer and all children in one assignment. Do not use `queue_free()` / `instantiate()`
  cycles to toggle CombatUI or InventoryUI — node state would be lost between combats.

### Negative
- Layer 10 for both HUD and InventoryUI assumes they don't overlap — if they do
  in future, InventoryUI needs a layer bump (minor)
- `CanvasLayer.layer` is set in Inspector — it's not code-enforced. A developer can
  change it without touching GDScript.

### Risks
- **Risk**: Developer places `TileRevealVFX` as `CanvasLayer` instead of `Node2D`.
  **Mitigation**: Class header: `## Node2D — NOT CanvasLayer. Must follow scene space.`
  Validation Criterion 4 checks this.
- **Risk**: Developer adds a second Presentation→Feature signal without documenting it.
  **Mitigation**: fp-015 in registry: only `player_action_taken` is an approved P→F signal.
  Any new P→F signal requires explicit ADR update.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| `hud.md` | Rule 1: HUD is CanvasLayer (layer=10) | Layer=10 confirmed as canonical value |
| `hud.md` | Rule 7: HUD only reads state via signals; never modifies game state | Documented in HUD.gd header; no emitted signals except none |
| `combat-system.md` | `player_action_taken` Presentation→Feature signal | Documented as the single approved P→F exception |
| `tile-reveal-vfx.md` (implied) | TileRevealVFX animations follow the board tiles | Node2D in scene space (not CanvasLayer) |

## Performance Implications
- **CPU**: `CanvasLayer` rendering: standard Godot batched renderer. Negligible for 3 UI layers.
- **Memory**: 4 Presentation nodes per session: ~KB each
- **Rendering**: Layer ordering computed once per frame by Godot's compositor. No custom draw calls.

## Migration Plan

No existing code — greenfield. Layer numbers set in Inspector when CanvasLayer
nodes are placed in GameScene.

## Validation Criteria

1. `HUD.layer == 10` confirmed in `game_scene.tscn`
2. `CombatUI.layer == 11` confirmed in `game_scene.tscn`
3. `InventoryUI.layer <= 10` confirmed in `game_scene.tscn`
4. `TileRevealVFX extends Node2D` — NOT `CanvasLayer`
5. No Presentation GDScript file (hud.gd, combat_ui.gd, inventory_ui.gd, tile_reveal_vfx.gd)
   emits a signal that is consumed by Feature or Core layer EXCEPT `CombatUI.player_action_taken`
6. `CombatUI.player_action_taken` is connected in `GameScene._wire_signals()`, not in `CombatUI._ready()`

## Related Decisions
- ADR-0002: Signal Wiring Pattern (`player_action_taken` wired in `_wire_signals()`)
- ADR-0006: CombatAction as Resource (payload of `player_action_taken`)
- ADR-0008: Stateless Feature Systems (Presentation systems are always stateless)
- `docs/architecture/architecture.md` — Presentation Layer Module Ownership
