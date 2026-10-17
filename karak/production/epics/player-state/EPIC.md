# Epic: PlayerState

> **Layer**: Core *(Foundation в systems-index.md)*
> **GDD**: design/gdd/player-state.md
> **Architecture Module**: PlayerState (Node ×2)
> **Status**: Ready
> **Manifest Version**: 2026-10-12
> **Stories**: 6 stories created — 2026-10-17

## Overview

PlayerState реализует изменяемое runtime-состояние одного игрока в виде `PlayerState extends Node`. В GameScene размещаются два независимых инстанса — по одному на каждого игрока. Эпик включает все поля состояния (hp, vp, position, previous_position, inventory, skip_next_turn, character_class), 6 типизированных сигналов (hp_changed, vp_changed, item_added, item_removed, knocked_out, knockout_cleared) и полный публичный API мутации (take_damage, heal_full, add_vp, set_position, retreat, add_item, remove_item, clear_knockout). PlayerState — самый зависимый компонент проекта: 8 систем потребляют его состояние и/или подписываются на его сигналы.

## Governing ADRs

| ADR | Краткое решение | Engine Risk |
|-----|----------------|-------------|
| ADR-0002: Signal Wiring Pattern | Все сигналы PlayerState подключаются в GameScene._wire_signals(); типизированный Callable-синтаксис | LOW |
| ADR-0003: PlayerState as Node | PlayerState extends Node (не Resource); 2 независимых инстанса; HeroClassData extends Resource | LOW |
| ADR-0013: Loot Weapon Replacement Strategy | get_weapons() / get_scrolls() accessors обязательны; замена слабейшего оружия; FIFO свитки | LOW |

## GDD Requirements

| TR-ID | Требование | ADR-покрытие |
|-------|-----------|--------------|
| TR-player-state-001 | Два независимых инстанса PlayerState с HP, VP, инвентарём, позицией, нокаутом | ADR-0003 ✅ |
| TR-player-state-002 | Типизированные сигналы для всех изменений состояния (hp_changed, vp_changed, item_added, item_removed, knocked_out, knockout_cleared) | ADR-0002 ✅, ADR-0003 ✅ |
| TR-player-state-003 | HP зажат в [0, max_hp], инициализируется из данных класса | ADR-0003 ✅ |
| TR-player-state-004 | set_position() сохраняет previous_position; retreat() восстанавливает её | ADR-0003 ✅ |
| TR-player-state-005 | HP нокаут: hp<=0 → hp=1, skip_next_turn=true; позиция/инвентарь неизменны | ADR-0003 ✅ |
| TR-player-state-006 | get_weapons() и get_scrolls() accessors для запросов инвентаря | ADR-0013 ✅ |

## Definition of Done

Эпик завершён когда:
- Все story реализованы, проревьюены и закрыты через `/story-done`
- Все acceptance criteria из `design/gdd/player-state.md` проверены
- Все Logic-story имеют проходящие тест-файлы в `tests/unit/player_state/`
- Два PlayerState-нода размещены в GameScene (не через PlayerState.new())
- `player_state_0.take_damage(1)` не влияет на `player_state_1.hp`
- Сигналы автоматически отключаются при выгрузке GameScene

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | PlayerState Node Skeleton — поля, сигналы, player_id guard | Logic | Ready | ADR-0003 |
| 002 | HP Management — take_damage, heal_full, нокаут | Logic | Ready | ADR-0003 |
| 003 | Position & Retreat — set_position, previous_position, retreat | Logic | Ready | ADR-0003 |
| 004 | Inventory: Weapons — add_weapon, replace_weapon, attack_bonus cache | Logic | Ready | ADR-0003, ADR-0013 |
| 005 | Inventory: Key & Scrolls — set_key, remove_key, add/remove_scroll | Logic | Ready | ADR-0003, ADR-0013 |
| 006 | VP, Win Condition, Chests — add_vp, mark_dragon_killed, increment_chests | Logic | Ready | ADR-0003 |

## Next Step

Run `/story-readiness production/epics/player-state/story-001-node-skeleton.md` to begin implementation.
