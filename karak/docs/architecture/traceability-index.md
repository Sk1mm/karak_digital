# Architecture Traceability Index

> **Last Updated**: 2026-10-11
> **Engine**: Godot 4.7.2
> **Review**: architecture-review-2026-10-11.md (full, ADR-0001–0014)

## Coverage Summary

- **Total requirements**: 59 (36 existing + 23 new)
- **Covered** ✅: 40 (68%)
- **Partial** ⚠️: 15 (25%)
- **Gaps** ❌: 4 (7%)

## Full Matrix

| TR-ID | GDD | System | Requirement | ADR | Status |
|-------|-----|--------|-------------|-----|--------|
| TR-player-state-001 | player-state.md | PlayerState | Two independent instances with HP, VP, inventory, position, knockout | ADR-0003 | ✅ |
| TR-player-state-002 | player-state.md | PlayerState | Typed signals for all state changes | ADR-0002, ADR-0003 | ✅ |
| TR-player-state-003 | player-state.md | PlayerState | HP clamped [0, max_hp], initialized from class data | ADR-0003 | ✅ |
| TR-player-state-004 | player-state.md | PlayerState | set_position() saves previous_position; retreat() restores it | ADR-0003 | ✅ |
| TR-player-state-005 | player-state.md | PlayerState | HP knockout: hp<=0 sets hp=1, skip_next_turn=true | ADR-0003 | ✅ |
| TR-player-state-006 | player-state.md | PlayerState | get_weapons() and get_scrolls() accessor methods | ADR-0013 | ✅ |
| TR-class-001 | class-system.md | ClassSystem | 7 hero classes as read-only HeroClassData Resources with ability flags | ADR-0003 | ✅ |
| TR-class-002 | class-system.md | ClassSystem | Global ClassRegistry accessible from any system | ADR-0001 | ✅ |
| TR-class-003 | class-system.md | ClassSystem | Class selection: N random from unoccupied pool; immutable after selection | ADR-0003 | ⚠️ |
| TR-tile-001 | tile-system.md | TileSystem | Sparse grid Dictionary[Vector2i, DungeonCell] with O(1) lookup | ADR-0004 | ✅ |
| TR-tile-002 | tile-system.md | TileSystem | TileMapLayer rendering (not deprecated TileMap) | ADR-0004 | ✅ |
| TR-tile-003 | tile-system.md | TileSystem | 5 tile categories with state machine | ADR-0004, ADR-0007 | ✅ |
| TR-tile-004 | tile-system.md | TileSystem | Cell exits computed from TileShape + rotation | ADR-0004 | ✅ |
| TR-tile-005 | tile-system.md | TileSystem | Tile pool (80 tiles) and event token pool (53 tokens) with draw APIs | ADR-0004, ADR-0005 | ✅ |
| TR-tile-006 | tile-system.md | TileSystem | DungeonCell loose_key flag and event_content_id persistence | ADR-0004 | ⚠️ |
| TR-tile-007 | tile-system.md | TileSystem | Portal list tracking revealed portals for teleport target selection | ADR-0004 | ⚠️ |
| TR-dice-001 | dice-system.md | DiceSystem | Seed-based deterministic RNG with roll(n, sides) and reroll_die(index) API | ADR-0008 | ✅ |
| TR-dice-002 | dice-system.md | DiceSystem | set_seed() for test reproducibility | ADR-0008 | ⚠️ |
| TR-monster-001 | monster-database.md | MonsterDatabase | 8 monsters as read-only MonsterData, globally accessible | ADR-0001 | ✅ |
| TR-item-001 | item-database.md | ItemDatabase | 6 items as read-only ItemData with typed properties, globally accessible | ADR-0001 | ✅ |
| TR-dungeon-001 | dungeon-generator.md | DungeonGenerator | Pool assembly with seed-based shuffle and one-time init | ADR-0005 | ✅ |
| TR-dungeon-002 | dungeon-generator.md | DungeonGenerator | Deferred signal emission (call_deferred) after _wire_signals() | ADR-0005 | ✅ |
| TR-dungeon-003 | dungeon-generator.md | DungeonGenerator | get_start_tile() API for KnockoutSystem Warrior teleport | ADR-0005 | ⚠️ |
| TR-turn-001 | turn-manager.md | TurnManager | FSM with states: IDLE, AWAITING_INIT, TURN_ACTIVE, AWAITING_COMBAT, AWAITING_LOOT, GAME_OVER | ADR-0008 | ✅ |
| TR-turn-002 | turn-manager.md | TurnManager | 4-step-per-turn budget, player switching, knockout skip handling | ADR-0008 | ✅ |
| TR-turn-003 | turn-manager.md | TurnManager | Swordsman extra step continuation on 6-roll | ADR-0012 | ✅ |
| TR-turn-004 | turn-manager.md | TurnManager | steps_taken counter for Oracle first_step_combat_bonus detection | — | ❌ |
| TR-turn-005 | turn-manager.md | TurnManager | burn_steps() API: sets steps_remaining=0 for fountain visits | ADR-0008 | ⚠️ |
| TR-movement-001 | movement-system.md | MovementSystem | Tile placement validation with exit connectivity checking | ADR-0008 | ✅ |
| TR-movement-002 | movement-system.md | MovementSystem | Class-specific movement bypasses (Rogue, Swordswoman, Wizard, Warlock) | ADR-0011 | ✅ |
| TR-movement-003 | movement-system.md | MovementSystem | Portal movement cost rules | ADR-0011 | ✅ |
| TR-encounter-001 | encounter-dispatcher.md | EncounterDispatcher | Stateless signal router: ROOM→combat/loot, FOUNTAIN→heal, PORTAL→teleport, CORRIDOR→clear | ADR-0008 | ✅ |
| TR-encounter-002 | encounter-dispatcher.md | EncounterDispatcher | Oracle two-token draw: draw x2, player chooses 1, return other to pool | ADR-0008 | ⚠️ |
| TR-encounter-003 | encounter-dispatcher.md | EncounterDispatcher | Fountain choice: heal_full + burn_steps + clear_cell or skip; not consumed on refusal | — | ❌ |
| TR-encounter-004 | encounter-dispatcher.md | EncounterDispatcher | Room re-entry: read existing event_content_id instead of drawing new token | ADR-0004, ADR-0008 | ⚠️ |
| TR-combat-001 | combat-system.md | CombatSystem | 2d6 + attack_bonus vs difficulty: WIN/DRAW/LOSS outcomes | ADR-0006, ADR-0008 | ✅ |
| TR-combat-002 | combat-system.md | CombatSystem | Class rerolls (Warrior both, Swordsman one), scroll bonuses, HP cost (Warlock) | ADR-0006 | ✅ |
| TR-combat-003 | combat-system.md | CombatSystem | Ephemeral combat-local state reset at _on_combat_started() | ADR-0008 | ✅ |
| TR-combat-004 | combat-system.md | CombatSystem | Multi-phase combat: auto-reroll → class reroll → scroll → HP Warlock → resolve | ADR-0006 | ⚠️ |
| TR-combat-005 | combat-system.md | CombatSystem | Signal ordering: combat_resolved BEFORE item_dropped to prevent TurnManager deadlock | ADR-0012 | ⚠️ |
| TR-combat-006 | combat-system.md | CombatSystem | Defeat/draw outcomes: take_damage(1) + knockout check + conditional retreat | ADR-0008 | ⚠️ |
| TR-loot-001 | loot-system.md | LootSystem | Monster drop table lookup (8 monsters → items) | ADR-0008 | ✅ |
| TR-loot-002 | loot-system.md | LootSystem | Chest VP award (1 VP), key pickup automation | ADR-0008 | ✅ |
| TR-loot-003 | loot-system.md | LootSystem | Item replacement logic (weakest weapon replaced on pickup) | ADR-0013 | ✅ |
| TR-loot-004 | loot-system.md | LootSystem | Loose key auto-pickup on cell_entered: has_loose_key + set_key + remove_loose_key | ADR-0008 | ⚠️ |
| TR-loot-005 | loot-system.md | LootSystem | Skeleton key floor placement: place_loose_key() when player already has key | — | ❌ |
| TR-knockout-001 | knockout-system.md | KnockoutSystem | Damage to 0 HP → HP=1 + skip_next_turn=true | ADR-0008 | ✅ |
| TR-knockout-002 | knockout-system.md | KnockoutSystem | Warrior exception: teleport to start + heal full + no skip | ADR-0008 | ✅ |
| TR-knockout-003 | knockout-system.md | KnockoutSystem | Warrior knockout: delayed clear_knockout (CombatSystem must see is_knocked_out=true during combat) | ADR-0008 | ⚠️ |
| TR-win-001 | win-condition.md | WinCondition | Dragon kill triggers game_over signal | ADR-0008 | ✅ |
| TR-win-002 | win-condition.md | WinCondition | VP calculation: chests (1), Ghost (1.0), Dragon (1.5); tiebreak to dragon killer | ADR-0014 | ✅ |
| TR-hud-001 | hud.md | HUD | Always-visible CanvasLayer layer=10 with HP, VP, inventory, steps, turn indicator | ADR-0009 | ✅ |
| TR-hud-002 | hud.md | HUD | Pure reader — subscribes to signals, never mutates state | ADR-0009 | ✅ |
| TR-hud-003 | hud.md | HUD | game_over(winner) display: show final VP comparison and winner announcement | ADR-0009 | ⚠️ |
| TR-combat-ui-001 | combat-ui.md | CombatUI | Modal CanvasLayer layer=11 overlay above HUD | ADR-0009 | ✅ |
| TR-combat-ui-002 | combat-ui.md | CombatUI | Single Presentation→Feature signal: player_action_taken(CombatAction) | ADR-0006, ADR-0009 | ✅ |
| TR-combat-ui-003 | combat-ui.md | CombatUI | auto_reroll_triggered(die_index, new_value) signal for Swordsman sequential reroll display | ADR-0009 | ⚠️ |
| TR-vfx-001 | tile-reveal-vfx.md | TileRevealVFX | Flip animation (squish 0.15s → swap → expand 0.15s) as scene-space Node2D | ADR-0009 | ✅ |
| TR-vfx-002 | tile-reveal-vfx.md | TileRevealVFX | Emits tile_reveal_complete signal to trigger EncounterDispatcher | ADR-0002 | ✅ |
| TR-inventory-ui-001 | inventory-ui.md | InventoryUI | Non-modal CanvasLayer layer=10 with 2 weapon + 1 key + 3 scroll slots | ADR-0009 | ✅ |
| TR-inventory-ui-002 | inventory-ui.md | InventoryUI | Auto-updates from PlayerState signals, read-only display | ADR-0002, ADR-0009 | ✅ |
| TR-inventory-ui-003 | inventory-ui.md | InventoryUI | ItemData.icon: Texture2D field required for slot rendering | — | ❌ |
| TR-concept-001 | game-concept.md | GameConcept | 2-player hotseat board game | ADR-0003 | ✅ |

---

## Known Gaps

| TR-ID | System | Requirement | Suggested Action |
|-------|--------|-------------|-----------------|
| TR-turn-004 | TurnManager | steps_taken counter for Oracle bonus | No ADR needed — GDD fully specifies; implement per turn-manager.md Rule 1 |
| TR-encounter-003 | EncounterDispatcher | Fountain choice mechanics | No ADR needed — GDD fully specifies; implement per encounter-dispatcher.md Rule 5 |
| TR-loot-005 | LootSystem | Skeleton key floor placement | `/architecture-decision loose-key-lifecycle` — cross-system floor key lifecycle (MEDIUM risk) |
| TR-inventory-ui-003 | InventoryUI | ItemData.icon: Texture2D field | No ADR needed — retrofit ItemData Resource; update item-database.md GDD |

---

## Superseded Requirements

None at this time.
