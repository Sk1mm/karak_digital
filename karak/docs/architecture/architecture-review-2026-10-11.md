# Architecture Review Report

> **Date**: 2026-10-11
> **Engine**: Godot 4.7.2
> **GDDs Reviewed**: 18 (all MVP systems)
> **ADRs Reviewed**: 14 (ADR-0001 through ADR-0014)
> **Reviewer**: /architecture-review (full mode)
> **Supersedes**: previous architecture-review-2026-10-11.md run (ADR-0001..0009 only)

---

## Traceability Summary

| Category | Count |
|----------|-------|
| Existing TRs in registry (pre-review) | 36 |
| New TRs identified in GDDs | 23 |
| **Total requirements** | **59** |
| ✅ Covered (full ADR coverage) | 40 |
| ⚠️ Partial (ADR touches topic, doesn't address specifically) | 15 |
| ❌ Gap (no ADR exists) | 4 |
| Registry stale entries fixed (adr: [] → correct ADR) | 5 |

---

## Coverage Gaps — No ADR Exists

| TR-ID | GDD | System | Requirement | Risk |
|-------|-----|--------|-------------|------|
| TR-turn-004 | turn-manager.md | TurnManager | `steps_taken` counter for Oracle `first_step_combat_bonus` detection | LOW |
| TR-encounter-003 | encounter-dispatcher.md | EncounterDispatcher | Fountain choice: heal_full + burn_steps + clear_cell or skip; fountain NOT consumed on refusal | LOW |
| TR-loot-005 | loot-system.md | LootSystem | Skeleton key floor placement: `place_loose_key()` when player already has a key | **MEDIUM** |
| TR-inventory-ui-003 | inventory-ui.md | InventoryUI | `ItemData.icon: Texture2D` field required for inventory slot rendering | LOW |

**Suggested ADR (1 needed)**:

- `/architecture-decision loose-key-lifecycle` — covers TR-loot-005. Cross-system floor key state: LootSystem places key → TileSystem stores `loose_key` flag → MovementSystem triggers cell_entered → LootSystem auto-picks up on next entry. The multi-turn lifecycle contract (who owns the key on the floor, when it is removed, what happens if both players visit the tile) requires an explicit architectural decision.

The other 3 gaps are implementation-level details fully specified in GDDs — no ADR needed.

---

## Partial Coverage (15 new TRs — no new ADRs required)

These are implicitly addressed by existing ADRs but not explicitly stated in the ADR text.
No new ADRs needed — update relevant ADRs during implementation to cross-reference these requirements.

Key partials:

| TR-ID | System | Gap in existing ADR |
|-------|--------|---------------------|
| TR-tile-006 | TileSystem | DungeonCell `loose_key` flag and `event_content_id` persistence — ADR-0004 covers cell structure but not these specific fields |
| TR-encounter-002 | EncounterDispatcher | Oracle two-token draw protocol — ADR-0008 covers stateless pattern but not Oracle-specific mechanics |
| TR-combat-004 | CombatSystem | Four-phase combat decision chain — ADR-0006 covers typed payloads but not full phase sequence |
| TR-combat-005 | CombatSystem | Signal ordering: `combat_resolved` BEFORE `item_dropped` — not explicitly stated in any ADR |
| TR-dungeon-003 | DungeonGenerator | `get_start_tile()` API required for Warrior teleport — ADR-0005 implies but doesn't state |

---

## TR Registry Updates (stale adr: [] fixed in registry)

| TR-ID | Was | Now |
|-------|-----|-----|
| TR-turn-003 | `adr: []` | `adr: [ADR-0012]` |
| TR-movement-002 | `adr: []` | `adr: [ADR-0011]` |
| TR-movement-003 | `adr: []` | `adr: [ADR-0011]` |
| TR-loot-003 | `adr: []` | `adr: [ADR-0013]` |
| TR-win-002 | `adr: []` | `adr: [ADR-0014]` |

---

## Cross-ADR Conflicts

### 🟡 MEDIUM — ADR-0002 vs ADR-0012: Direct Method Call Violation

**Type**: Architecture pattern conflict
**ADR-0002 states**: All cross-system communication is signal-only, wired centrally in `_wire_signals()`. Systems do not call other systems' methods directly.
**ADR-0012 requires**: CombatSystem calls `TurnManager.add_step(1)` directly (method call, not signal) before emitting `combat_resolved`. This requires CombatSystem to hold an `@export var turn_manager: TurnManager` reference — undocumented anywhere.
**Impact**: Violates the core signal-only boundary. Adds undocumented cross-system coupling. Makes CombatSystem harder to test in isolation.

**Resolution options**:
1. ✅ **Recommended**: Include `extra_steps: int` in `combat_resolved(won: bool, six_rolled: bool, extra_steps: int)` — TurnManager handles `add_step()` internally on receipt. Signal-only boundary stays intact.
2. Accept the exception and document it in ADR-0002 (as with the CombatUI→CombatSystem signal exception).

### 🔵 LOW — ADR-0002 signal topology diagram incomplete

ADR-0002's wiring diagram shows `combat_resolved` with no parameters. ADR-0012 defines `combat_resolved(won: bool, six_rolled: bool)`. No functional conflict — ADR-0012 supersedes — but ADR-0002's wiring diagram needs updating.

### 🔵 LOW — HeroClassData flag naming inconsistency (ADR-0003 vs ADR-0006/0011/0012)

`auto_reroll_on_one` (ADR-0003) vs `can_reroll_one_die` (ADR-0006). ADRs 0011/0012 introduce flags not listed in ADR-0003's HeroClassData definition. Standardize on the `can_*` naming convention when implementing HeroClassData.

### 🔵 LOW — PlayerState API scattered across four ADRs (ADR-0003/0011/0013/0014)

No single ADR has the complete PlayerState interface. Recommend adding a "PlayerState API surface" cross-reference section to ADR-0003.

### 🔵 LOW — DungeonGenerator stateless vs ADR-0010 save/load ownership

ADR-0005: DungeonGenerator is stateless after `initialize()`. ADR-0010 (Proposed): requires `DungeonGenerator.to_dict()`. Grid data lives in TileSystem. When finalizing ADR-0010, use `TileSystem.to_dict()`.

---

## ADR Dependency Order (topologically sorted)

```
Layer 0 — Foundation (no dependencies):
  1. ADR-0001: Autoload Strategy

Layer 1 — Core Architecture:
  2. ADR-0002: Signal Wiring Pattern (← ADR-0001)
  3. ADR-0003: PlayerState as Node (← ADR-0001)
  4. ADR-0007: GameEnums Global Class (← ADR-0001)

Layer 2 — Infrastructure:
  5. ADR-0004: TileSystem and TileMapLayer (← ADR-0001, ADR-0002)
  6. ADR-0006: CombatAction as Resource (← ADR-0002, ADR-0003)
  7. ADR-0008: Stateless Feature Systems (← ADR-0001, ADR-0002, ADR-0003)
  8. ADR-0009: CanvasLayer Hierarchy (← ADR-0002, ADR-0003)
  9. ADR-0010: Save/Load System [Proposed] (← ADR-0003)

Layer 3 — Feature Layer:
  10. ADR-0005: DungeonGenerator Init Pattern (← ADR-0002, ADR-0004)
  11. ADR-0011: Movement Class Abilities and Portal Costs (← ADR-0003, ADR-0008)
  12. ADR-0012: TurnManager Swordsman Extra Step Protocol (← ADR-0006, ADR-0008)
  13. ADR-0013: Loot Weapon Replacement Strategy (← ADR-0003, ADR-0008)
  14. ADR-0014: WinCondition VP Sources and Tiebreak (← ADR-0003, ADR-0008)
```

Unresolved dependencies: None.
Dependency cycles: None — clean DAG rooted at ADR-0001.
Status concern: ADR-0010 is Proposed, not Accepted. No MVP blockers, but resolve before post-MVP planning.

---

## Engine Compatibility

**Overall: LOW RISK**

| Check | Result |
|-------|--------|
| ADRs with Engine Compatibility section | 14 / 14 ✅ |
| Deprecated API references | None ✅ |
| Stale version references | None — all target Godot 4.7.2 ✅ |
| Post-cutoff API conflicts | None ✅ |
| Anti-patterns | None ✅ |

Notable correctly-handled post-cutoff items:
- `TileMapLayer` (4.3+): ADR-0004 explicitly bans deprecated `TileMap`
- `FileAccess.store_*()` returns bool (4.4+): ADR-0010 documents return value check requirement
- Control transform changes (4.7): ADR-0009 references `current-best-practices.md` verification

---

## Architecture Document Coverage

| Check | Result |
|-------|--------|
| All 18 MVP systems in layer assignments | ✅ |
| Data flows cover main gameplay paths (DF-1 through DF-4) | ✅ |
| API boundaries defined for all layers | ✅ |
| Orphaned architecture systems | None |
| Naming discrepancy | "ClassSystem" (systems-index) vs "ClassRegistry" (architecture.md/implementation) — acceptable, align systems-index note |

---

## GDD Revision Flags

No GDD assumptions conflict with verified Godot 4.7.2 engine behaviour.

---

## Verdict: ⚠️ CONCERNS

All 36 pre-existing TR requirements have ADR coverage. Foundation and Core layers fully covered. Engine compatibility clean. Dependency graph acyclic.

### Blocking before PASS (1 item)

**ADR-0012 signal architecture violation**: CombatSystem calling `TurnManager.add_step()` directly contradicts ADR-0002's signal-only cross-system communication principle. Must be resolved before CombatSystem implementation.
- Recommended fix: extend `combat_resolved` signal with `extra_steps: int` parameter

### Non-blocking concerns

- 4 true TR gaps (3 LOW, 1 MEDIUM — loose key lifecycle)
- 15 partial-coverage TRs (address during implementation)
- HeroClassData flag naming: standardize at implementation time
- ADR-0010 Proposed status: accept or defer before post-MVP

---

## Required ADRs

| Priority | Command | Reason |
|----------|---------|--------|
| 1 | `/architecture-decision loose-key-lifecycle` | TR-loot-005: MEDIUM risk cross-system floor key coordination |

The other 3 gaps (TR-turn-004, TR-encounter-003, TR-inventory-ui-003) are fully specified in GDDs — no ADR needed.

---

## Immediate Actions

1. **Resolve MEDIUM conflict**: Update ADR-0012 to extend `combat_resolved(won, six_rolled, extra_steps)` OR add exception to ADR-0002
2. **Optional**: `/architecture-decision loose-key-lifecycle`
3. **When blocking resolved**: `/gate-check pre-production`

Re-run `/architecture-review` after writing the loose-key ADR to verify 0 gaps.
