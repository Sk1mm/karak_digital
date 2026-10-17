# Epic: TurnManager

> **Layer**: Feature *(Core в systems-index.md)*
> **GDD**: design/gdd/turn-manager.md
> **Architecture Module**: TurnManager (Node, FSM)
> **Status**: Ready
> **Manifest Version**: 2026-10-11
> **Stories**: Not yet created — run `/create-stories turn-manager`

## Overview

TurnManager — единственная Feature-система с разрешённым persistent state (ADR-0008). Реализует FSM игрового цикла с состояниями IDLE, AWAITING_INIT, TURN_ACTIVE, AWAITING_COMBAT, AWAITING_LOOT, GAME_OVER. Управляет бюджетом 4 шага/ход, сменой активного игрока, обработкой knockout-skip, реакцией на `dungeon_initialized`, `combat_resolved`, `item_acquired`, `game_over`. Эмитирует `turn_started`, `turn_ended`, `step_spent`, `turn_skipped` для HUD и InventoryUI.

## Governing ADRs

| ADR | Краткое решение | Engine Risk |
|-----|----------------|-------------|
| ADR-0008: Stateless Feature Systems | TurnManager — единственная Feature-система с permitted persistent state (FSM state + счётчики ходов) | LOW |
| ADR-0012: TurnManager Swordsman Extra Step Protocol | `add_step(1)` → `combat_resolved(true, six_rolled=true)` — продолжение хода Мечника | LOW |

## GDD Requirements

| TR-ID | Требование | ADR-покрытие |
|-------|-----------|--------------|
| TR-turn-001 | FSM с состояниями: IDLE, AWAITING_INIT, TURN_ACTIVE, AWAITING_COMBAT, AWAITING_LOOT, GAME_OVER | ADR-0008 ✅ |
| TR-turn-002 | Бюджет 4 шага/ход, смена игроков, обработка knockout skip | ADR-0008 ✅ |
| TR-turn-003 | Дополнительный ход Мечника при 6 на кубике | ADR-0012 ✅ |

## Definition of Done

Эпик завершён когда:
- Все story реализованы, проревьюены и закрыты через `/story-done`
- Все acceptance criteria из `design/gdd/turn-manager.md` проверены
- Все Logic-story имеют проходящие тест-файлы в `tests/unit/turn_manager/`
- FSM корректно переходит между всеми 6 состояниями
- После `game_over` все последующие game-flow сигналы игнорируются (GAME_OVER state)
- Story для TR-turn-003 разблокирована (ADR-0012 Accepted)

## Next Step

Run `/create-stories turn-manager` to break this epic into implementable stories.
