# Epic: CombatSystem

> **Layer**: Feature *(Core в systems-index.md)*
> **GDD**: design/gdd/combat-system.md
> **Architecture Module**: CombatSystem (Node, ephemeral state)
> **Status**: Ready
> **Manifest Version**: 2026-10-11
> **Stories**: Not yet created — run `/create-stories combat-system`

## Overview

CombatSystem реализует полную логику боя: 2d6 + attack_bonus vs difficulty монстра → WIN/DRAW/LOSS. Включает class-specific модификаторы: перебросы (Warrior оба кубика, Swordswoman один), автопереброс единиц (Swordsman), бонус первого шага (Oracle), трата HP (Warlock), победа при ничье (Rogue). Управляет фазой выбора игрока через `CombatOptions`/`CombatAction` Resource (ADR-0006). Хранит эфемерное бой-локальное состояние (`_scroll_bonus`, `_hp_bonus`, `_first_step_bonus`) — сбрасывается как **первый оператор** `_on_combat_started()`. Эмитирует: `dice_rolled`, `auto_reroll_triggered`, `player_choice_requested`, `combat_resolved`, `item_dropped`, `dragon_killed`.

## Governing ADRs

| ADR | Краткое решение | Engine Risk |
|-----|----------------|-------------|
| ADR-0006: CombatAction as Resource | CombatOptions/CombatAction extends Resource — типизированные signal payload; не Dictionary | LOW |
| ADR-0008: Stateless Feature Systems | CombatSystem — ephemeral state; сброс _scroll_bonus/_hp_bonus/_first_step_bonus — первый оператор _on_combat_started() | LOW |

## GDD Requirements

| TR-ID | Требование | ADR-покрытие |
|-------|-----------|--------------|
| TR-combat-001 | 2d6 + attack_bonus vs difficulty: WIN/DRAW/LOSS | ADR-0006 ✅, ADR-0008 ✅ |
| TR-combat-002 | Class rerolls (Warrior оба, Swordsman один), scroll-бонусы, HP cost (Warlock) | ADR-0006 ✅ |
| TR-combat-003 | Эфемерное бой-локальное состояние сбрасывается в _on_combat_started() | ADR-0008 ✅ |

## Definition of Done

Эпик завершён когда:
- Все story реализованы, проревьюены и закрыты через `/story-done`
- Все acceptance criteria из `design/gdd/combat-system.md` проверены
- Все Logic-story имеют проходящие тест-файлы в `tests/unit/combat_system/`
- Блок сброса эфемерного состояния — первый оператор в `_on_combat_started()` (code review)
- `CombatOptions.new()` и `CombatAction.new()` компилируются со статически типизированными полями
- `player_choice_requested` и `player_action_taken` передают типизированные Resource-объекты

## Next Step

Run `/create-stories combat-system` to break this epic into implementable stories.
