# Architecture Review Report

> **Date**: 2026-10-11
> **Engine**: Godot 4.7.2
> **GDDs Reviewed**: 18 (+ game-concept)
> **ADRs Reviewed**: 9
> **Verdict**: PASS

---

## Traceability Summary

| Metric | Count | % |
|--------|-------|---|
| Total requirements | 40 | 100% |
| ✅ Covered | 30 | 75% |
| ⚠️ Partial | 10 | 25% |
| ❌ Gaps | 0 | 0% |

**Note on ⚠️ Partial items**: All 10 partial items are implementation-level details
that the ADRs correctly delegate to implementation time. ADR-0008 classifies each
system's state contract; the specific algorithms (movement validation, item replacement,
VP calculation, class-specific edge cases) are GDD-level mechanics, not architectural
decisions. No new ADRs are required for these.

---

## Full Traceability Matrix

| TR-ID | GDD | Requirement | ADR | Status |
|-------|-----|-------------|-----|--------|
| TR-player-state-001 | player-state.md | Two independent instances with HP/VP/inventory/position/knockout | ADR-0003 | ✅ |
| TR-player-state-002 | player-state.md | Signals for all state changes | ADR-0002, ADR-0003 | ✅ |
| TR-player-state-003 | player-state.md | HP clamped [0, max_hp], init from class data | ADR-0003 | ✅ |
| TR-class-001 | class-system.md | 7 hero classes as read-only Resource data | ADR-0003 | ✅ |
| TR-class-002 | class-system.md | Global class registry accessible without import | ADR-0001 | ✅ |
| TR-tile-001 | tile-system.md | Sparse grid Dictionary[Vector2i, DungeonCell] | ADR-0004 | ✅ |
| TR-tile-002 | tile-system.md | TileMapLayer rendering (not deprecated TileMap) | ADR-0004 | ✅ |
| TR-tile-003 | tile-system.md | 5 tile categories with state machine | ADR-0004, ADR-0007 | ✅ |
| TR-tile-004 | tile-system.md | Cell exits computed from shape + rotation | ADR-0004 | ✅ |
| TR-dice-001 | dice-system.md | Seed-based deterministic RNG | ADR-0008 | ⚠️ |
| TR-monster-001 | monster-database.md | 8 monsters read-only, globally accessible | ADR-0001 | ✅ |
| TR-item-001 | item-database.md | 6 items read-only, globally accessible | ADR-0001 | ✅ |
| TR-dungeon-001 | dungeon-generator.md | Pool assembly (80 tiles, 53 tokens) seed-based | ADR-0005 | ✅ |
| TR-dungeon-002 | dungeon-generator.md | Deferred signal init for safe wiring | ADR-0005 | ✅ |
| TR-turn-001 | turn-manager.md | FSM with 6 states | ADR-0008 | ✅ |
| TR-turn-002 | turn-manager.md | 4-step budget, player switching, knockout skip | ADR-0008 | ⚠️ |
| TR-turn-003 | turn-manager.md | Swordsman extra step on 6-roll | — | ⚠️ |
| TR-movement-001 | movement-system.md | Tile placement validation with exit connectivity | ADR-0008 | ⚠️ |
| TR-movement-002 | movement-system.md | Class-specific movement bypasses | — | ⚠️ |
| TR-movement-003 | movement-system.md | Portal movement cost rules | — | ⚠️ |
| TR-encounter-001 | encounter-dispatcher.md | Stateless router: category -> event type | ADR-0008 | ✅ |
| TR-combat-001 | combat-system.md | 2d6 + bonus vs difficulty comparison | ADR-0006, ADR-0008 | ✅ |
| TR-combat-002 | combat-system.md | Class rerolls, scroll bonuses, HP cost | ADR-0006 | ✅ |
| TR-combat-003 | combat-system.md | Ephemeral state reset per combat | ADR-0008 | ✅ |
| TR-loot-001 | loot-system.md | Monster drop table lookup | ADR-0008 | ✅ |
| TR-loot-002 | loot-system.md | Chest VP + key pickup + auto-award | ADR-0008 | ⚠️ |
| TR-loot-003 | loot-system.md | Item replacement logic (weakest weapon) | — | ⚠️ |
| TR-knockout-001 | knockout-system.md | Damage to 0 -> HP=1 + skip_next_turn | ADR-0008 | ✅ |
| TR-knockout-002 | knockout-system.md | Warrior exception: teleport + heal + no skip | ADR-0008 | ⚠️ |
| TR-win-001 | win-condition.md | Dragon kill triggers game_over | ADR-0008 | ✅ |
| TR-win-002 | win-condition.md | VP calculation + tiebreak rules | — | ⚠️ |
| TR-hud-001 | hud.md | Always-visible CanvasLayer layer=10 | ADR-0009 | ✅ |
| TR-hud-002 | hud.md | Pure reader — no state mutation | ADR-0009 | ✅ |
| TR-combat-ui-001 | combat-ui.md | Modal CanvasLayer layer=11 | ADR-0009 | ✅ |
| TR-combat-ui-002 | combat-ui.md | Single P->F signal with CombatAction payload | ADR-0006, ADR-0009 | ✅ |
| TR-vfx-001 | tile-reveal-vfx.md | Flip animation as scene-space Node2D | ADR-0009 | ✅ |
| TR-vfx-002 | tile-reveal-vfx.md | tile_reveal_complete -> EncounterDispatcher | ADR-0002 | ✅ |
| TR-inventory-ui-001 | inventory-ui.md | Non-modal CanvasLayer layer=10 | ADR-0009 | ✅ |
| TR-inventory-ui-002 | inventory-ui.md | Auto-updates from PlayerState signals | ADR-0002, ADR-0009 | ✅ |
| TR-concept-001 | game-concept.md | 2-player hotseat | ADR-0003 | ✅ |

---

## Cross-ADR Conflicts

**No conflicts detected.** All 9 ADRs are mutually consistent:

- **Data ownership**: Clear — PlayerState owns mutable player data (ADR-0003),
  TileSystem owns grid data (ADR-0004), Autoloads own read-only registries (ADR-0001).
  No overlaps.
- **Integration contracts**: All cross-system communication through centralized signal
  wiring (ADR-0002). CombatAction/CombatOptions as typed Resource payloads (ADR-0006)
  match the signal contracts.
- **Performance budget**: 2D board game at 60fps with <100 draw calls — no ADR
  approaches the frame budget.
- **Dependency cycles**: None detected.
- **Pattern consistency**: All systems follow the same patterns — stateless where
  possible (ADR-0008), signals for communication (ADR-0002), enums in one namespace
  (ADR-0007).

---

## ADR Dependency Order (topologically sorted)

### Foundation (no dependencies)
1. ADR-0007: GameEnums Global Class
2. ADR-0001: Autoload Strategy

### Depends on Foundation
3. ADR-0003: PlayerState as Node (requires ADR-0001)
4. ADR-0004: TileSystem and TileMapLayer (requires ADR-0007)

### Core layer
5. ADR-0002: Signal Wiring Pattern (requires ADR-0003, ADR-0004)
6. ADR-0005: DungeonGenerator Init (requires ADR-0002, ADR-0004)
7. ADR-0006: CombatAction as Resource (requires ADR-0007)
8. ADR-0008: Stateless Feature Systems (requires ADR-0002, ADR-0003, ADR-0004)

### Presentation
9. ADR-0009: CanvasLayer Hierarchy (requires ADR-0002, ADR-0006)

No unresolved dependencies. No cycles.

---

## GDD Revision Flags

None — all GDD assumptions are consistent with verified engine behaviour.

---

## Engine Compatibility Issues

**Engine**: Godot 4.7.2 | **Risk**: LOW

ADRs with Engine Compatibility section: 9/9

| Issue | ADR | Severity | Detail |
|-------|-----|----------|--------|
| Typed Dictionary inconsistency | ADR-0004 | LOW | Architecture diagram says `Dictionary[Vector2i, DungeonCell]`, code says `Dictionary = {}`. Pick one before implementation. Typed form should work (DungeonCell implicitly extends RefCounted). |
| `preload()` vs `load()` conflation | ADR-0001 | INFO | `preload()` is parse-time, not runtime. Minor doc clarity. |
| Verification Required field outdated | ADR-0005 | INFO | References old string-based `call_deferred("...")` but implementation uses Callable form. |
| CombatAction shared reference after emit | ADR-0006 | INFO | Signal passes reference not copy. Do not mutate after emit. |

**Deprecated API references**: None.
**Stale version references**: None — all ADRs target 4.7.2.

### Engine Specialist Findings

Godot specialist confirmed all 9 ADRs use correct Godot 4.7.2 patterns:
- `_emit_initialized.call_deferred()` Callable form is correct and preferred
- Resource subclasses as typed signal parameters work correctly
- `TileRevealVFX as Node2D` (not CanvasLayer) is correct for scene-space VFX
- `class_name GameEnums` with no extends is the right pattern for enum namespace
- **Action item**: ADR-0004 should choose typed vs untyped Dictionary before implementation

---

## Architecture Document Coverage

`docs/architecture/architecture.md` — comprehensive:

- ✅ All 18 MVP systems in 5-layer map
- ✅ 4 data flow paths (boot, wiring, turn loop, knockout)
- ✅ Module ownership table (18 systems)
- ✅ 5 invariants
- ✅ 9 ADRs referenced
- ✅ 5 open questions documented
- ✅ No orphaned architecture

---

## Verdict: PASS

All Foundation and Core layer requirements covered by ADRs. No cross-ADR conflicts.
Engine compatibility verified. 10 partial-coverage items are implementation-level
mechanics correctly delegated to GDDs.

### Minor Issues (non-blocking, fix during implementation)

1. **ADR-0004**: Resolve typed Dictionary declaration — verify `Dictionary[Vector2i, DungeonCell]` compiles in 4.7.2
2. **ADR-0005**: Update Verification Required field to match Callable form
3. **ADR-0001**: Clarify `preload()` vs `load()` usage
4. **ADR-0006**: Add implementation note about not mutating CombatAction after emit

### Required ADRs

None — the current 9 ADRs provide complete architectural coverage for the 18 MVP systems.

---

## Handoff

### Immediate Actions
1. Fix ADR-0004 Dictionary declaration (typed vs untyped) — 5 min
2. Fix ADR-0005 Verification Required field — 2 min
3. Run `/gate-check pre-production` to advance

### Gate Guidance
All blocking issues resolved. Run `/gate-check pre-production` when ready to advance.

### Rerun Trigger
Re-run `/architecture-review` after any new ADR is written to verify coverage.
