class_name HeroClassData  # READ-ONLY resource schema for a hero class definition
extends Resource  # Pure data container — no Node, no _ready(), no mutable logic

# ===================================================
# HERO CLASS DATA — Foundation Layer
# ===================================================
# READ-ONLY class definition for a hero class. Never add mutable state or methods here.
#
# This resource holds ALL stat and flag data for one hero class (Warrior, Rogue, etc.).
# It is loaded once and shared across systems — treat it as immutable at runtime.
#
# Consumers:
#   CombatSystem        — combat flags (COMBAT section)
#   KnockoutSystem      — knockout behaviour (KNOCKOUT section)
#   MovementSystem      — movement abilities (MOVEMENT section)
#   EncounterDispatcher — tile/dungeon flags (TILE/DUNGEON section)
#   LootSystem          — item interaction flags (ITEMS section)
#   PlayerState         — reads max_hp in _ready() to set initial HP
#   ClassRegistry       — indexes by `id`
#   UI                  — reads display_name for labels
#
# ADR Reference: ADR-0003 (Hero Class Data Resource schema)
# Control Manifest: Foundation Layer — HeroClassData extends Resource (required)
#
# Forbidden: PlayerState extends Resource (see Control Manifest)
# Guardrail: all variables are statically typed (@export var with explicit type)
# ===================================================

## READ-ONLY class definition for a hero class. Never add mutable state or methods here.

# --- Base identity fields (no section — placed before section blocks) ---

@export var id: StringName  # GlobalID: &"warrior", &"rogue", etc. — used by ClassRegistry to index and look up this class

@export var display_name: String  # Human-readable class name shown in UI ("Warrior", "Rogue") — read by UI

@export var max_hp: int = 5  # Base HP pool for this class — read by PlayerState._ready() to initialise current_hp


# === COMBAT ===
# All flags below are read exclusively by CombatSystem (and TurnManager where noted).

@export var can_reroll_both_dice: bool = false      # Warrior ability — reroll both combat dice; second result is mandatory — read by CombatSystem

@export var wins_on_draw: bool = false               # Rogue ability — treat a draw result as a win in combat — read by CombatSystem

@export var can_spend_hp_for_attack: bool = false    # Warlock ability — spend -1 HP before roll to gain +1 attack power (optional) — read by CombatSystem

@export var auto_reroll_on_one: bool = false         # Swordsman ability — automatically reroll any die that shows 1 — read by CombatSystem

@export var can_continue_turn_on_six: bool = false   # Swordsman ability — if combat is won with a 6, continue the current turn — read by CombatSystem/TurnManager (ADR-0012)

@export var can_reroll_one_die: bool = false         # Swordswoman ability — reroll exactly one chosen die; second result is mandatory — read by CombatSystem

@export var first_step_combat_bonus: int = 0         # Oracle ability — +1 attack power if combat occurs on the first step of the turn — read by CombatSystem


# === KNOCKOUT ===
# All flags below are read exclusively by KnockoutSystem.

@export var knockout_teleport_to_start: bool = false # Warrior ability — teleport to fountain tile instead of standard knockout flow — read by KnockoutSystem

@export var knockout_no_turn_skip: bool = false      # Warrior ability — do NOT skip the next turn after being knocked out — read by KnockoutSystem

@export var knockout_full_heal: bool = false         # Warrior ability — restore HP to max_hp on knockout instead of partial heal — read by KnockoutSystem


# === MOVEMENT ===
# All flags below are read exclusively by MovementSystem (ADR-0011).

@export var can_bypass_monster_free: bool = false    # Rogue ability — bypass a monster tile without entering combat and without HP penalty — read by MovementSystem (ADR-0011)

@export var can_bypass_monster_cost: bool = false    # Swordswoman ability — bypass a monster tile at cost: -1 step, -1 HP — read by MovementSystem (ADR-0011)

@export var can_pass_through_walls: bool = false     # Wizard ability — move through wall tiles as if they were open passages — read by MovementSystem (ADR-0011)

@export var can_swap_positions: bool = false         # Warlock ability — swap board position with another hero at cost: -4 steps — read by MovementSystem (ADR-0011)


# === TILE/DUNGEON ===
# All flags below are read exclusively by EncounterDispatcher.

@export var choose_encounter_from_two: bool = false  # Oracle ability — when landing on an encounter tile, choose from 2 randomly drawn options — read by EncounterDispatcher


# === ITEMS ===
# All flags below are read by LootSystem and CombatSystem.

@export var magic_charge_no_discard: bool = false    # Wizard ability — scroll_teleport is NOT consumed after use; scroll_magic_attack still discards — read by LootSystem/CombatSystem
