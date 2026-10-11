# Architecture Traceability Index

> **Last Updated**: 2026-10-11
> **Engine**: Godot 4.7.2

## Coverage Summary

- **Total requirements**: 40
- **Covered**: 30 (75%)
- **Partial**: 10 (25%)
- **Gaps**: 0 (0%)

## Full Matrix

| TR-ID | GDD | System | Requirement | ADR | Status |
|-------|-----|--------|-------------|-----|--------|
| TR-player-state-001 | player-state.md | PlayerState | Two independent instances | ADR-0003 | ✅ |
| TR-player-state-002 | player-state.md | PlayerState | Signals for state changes | ADR-0002, ADR-0003 | ✅ |
| TR-player-state-003 | player-state.md | PlayerState | HP clamped [0, max_hp] | ADR-0003 | ✅ |
| TR-class-001 | class-system.md | ClassSystem | 7 hero classes as Resources | ADR-0003 | ✅ |
| TR-class-002 | class-system.md | ClassSystem | Global registry | ADR-0001 | ✅ |
| TR-tile-001 | tile-system.md | TileSystem | Sparse Dictionary grid | ADR-0004 | ✅ |
| TR-tile-002 | tile-system.md | TileSystem | TileMapLayer rendering | ADR-0004 | ✅ |
| TR-tile-003 | tile-system.md | TileSystem | 5 categories + state machine | ADR-0004, ADR-0007 | ✅ |
| TR-tile-004 | tile-system.md | TileSystem | Exits from shape + rotation | ADR-0004 | ✅ |
| TR-dice-001 | dice-system.md | DiceSystem | Seed-based deterministic RNG | ADR-0008 | ⚠️ |
| TR-monster-001 | monster-database.md | MonsterDatabase | 8 monsters globally accessible | ADR-0001 | ✅ |
| TR-item-001 | item-database.md | ItemDatabase | 6 items globally accessible | ADR-0001 | ✅ |
| TR-dungeon-001 | dungeon-generator.md | DungeonGenerator | Pool assembly seed-based | ADR-0005 | ✅ |
| TR-dungeon-002 | dungeon-generator.md | DungeonGenerator | Deferred signal init | ADR-0005 | ✅ |
| TR-turn-001 | turn-manager.md | TurnManager | FSM with 6 states | ADR-0008 | ✅ |
| TR-turn-002 | turn-manager.md | TurnManager | 4-step budget + switching | ADR-0008 | ⚠️ |
| TR-turn-003 | turn-manager.md | TurnManager | Swordsman extra step on 6 | — | ⚠️ |
| TR-movement-001 | movement-system.md | MovementSystem | Exit connectivity validation | ADR-0008 | ⚠️ |
| TR-movement-002 | movement-system.md | MovementSystem | Class-specific bypasses | — | ⚠️ |
| TR-movement-003 | movement-system.md | MovementSystem | Portal cost rules | — | ⚠️ |
| TR-encounter-001 | encounter-dispatcher.md | EncounterDispatcher | Stateless category router | ADR-0008 | ✅ |
| TR-combat-001 | combat-system.md | CombatSystem | 2d6 + bonus vs difficulty | ADR-0006, ADR-0008 | ✅ |
| TR-combat-002 | combat-system.md | CombatSystem | Class rerolls/scrolls/HP cost | ADR-0006 | ✅ |
| TR-combat-003 | combat-system.md | CombatSystem | Ephemeral state reset | ADR-0008 | ✅ |
| TR-loot-001 | loot-system.md | LootSystem | Monster drop table | ADR-0008 | ✅ |
| TR-loot-002 | loot-system.md | LootSystem | Chest VP + key automation | ADR-0008 | ⚠️ |
| TR-loot-003 | loot-system.md | LootSystem | Item replacement logic | — | ⚠️ |
| TR-knockout-001 | knockout-system.md | KnockoutSystem | HP=1 + skip on knockout | ADR-0008 | ✅ |
| TR-knockout-002 | knockout-system.md | KnockoutSystem | Warrior exception | ADR-0008 | ⚠️ |
| TR-win-001 | win-condition.md | WinCondition | Dragon kill -> game_over | ADR-0008 | ✅ |
| TR-win-002 | win-condition.md | WinCondition | VP calc + tiebreak | — | ⚠️ |
| TR-hud-001 | hud.md | HUD | CanvasLayer layer=10 | ADR-0009 | ✅ |
| TR-hud-002 | hud.md | HUD | Pure reader | ADR-0009 | ✅ |
| TR-combat-ui-001 | combat-ui.md | CombatUI | Modal layer=11 | ADR-0009 | ✅ |
| TR-combat-ui-002 | combat-ui.md | CombatUI | P->F signal CombatAction | ADR-0006, ADR-0009 | ✅ |
| TR-vfx-001 | tile-reveal-vfx.md | TileRevealVFX | Node2D flip animation | ADR-0009 | ✅ |
| TR-vfx-002 | tile-reveal-vfx.md | TileRevealVFX | tile_reveal_complete signal | ADR-0002 | ✅ |
| TR-inventory-ui-001 | inventory-ui.md | InventoryUI | Non-modal layer=10 | ADR-0009 | ✅ |
| TR-inventory-ui-002 | inventory-ui.md | InventoryUI | Signal-driven updates | ADR-0002, ADR-0009 | ✅ |
| TR-concept-001 | game-concept.md | GameConcept | 2-player hotseat | ADR-0003 | ✅ |

## Known Gaps

No architectural gaps. All 10 ⚠️ Partial items are implementation-level mechanics
delegated to GDDs — they do not require separate ADRs.

## Superseded Requirements

None — all GDD requirements are current and consistent with their ADRs.
