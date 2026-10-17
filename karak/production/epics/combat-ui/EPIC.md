# Epic: CombatUI

> **Layer**: Presentation
> **GDD**: design/gdd/combat-ui.md
> **Architecture Module**: CombatUI (CanvasLayer, layer=11)
> **Status**: Ready
> **Manifest Version**: 2026-10-11
> **Stories**: Not yet created — run `/create-stories combat-ui`

## Overview

CombatUI реализует модальный боевой оверлей как `CombatUI extends CanvasLayer` с `layer = 11` — всегда поверх HUD во время активного боя. Отображает два кубика с анимацией (подписывается на `dice_rolled`, `auto_reroll_triggered`), breakdown-строку (dice + attack_bonus + scroll_bonus + hp_bonus vs difficulty), кнопки выбора действия игрока (Reroll both / Reroll one / Use scroll / Spend HP / Confirm). Скрыт вне боя через `visible = false`. Является единственной Presentation-системой с исходящим сигналом: `player_action_taken(action: CombatAction)` → CombatSystem — документированное исключение из правила Pure Reader (ADR-0009).

## Governing ADRs

| ADR | Краткое решение | Engine Risk |
|-----|----------------|-------------|
| ADR-0002: Signal Wiring Pattern | player_action_taken подключается в GameScene._wire_signals(); CombatUI не подключает сигналы в своём _ready() | LOW |
| ADR-0006: CombatAction as Resource | CombatAction extends Resource — типизированный payload player_action_taken; не Dictionary | LOW |
| ADR-0009: CanvasLayer Hierarchy | CombatUI — CanvasLayer layer=11 (выше HUD); toggle через visible; единственный одобренный P→F сигнал | LOW |

## GDD Requirements

| TR-ID | Требование | ADR-покрытие |
|-------|-----------|--------------|
| TR-combat-ui-001 | Модальный CanvasLayer layer=11 поверх HUD | ADR-0009 ✅ |
| TR-combat-ui-002 | Единственный Presentation→Feature сигнал: player_action_taken(CombatAction) | ADR-0006 ✅, ADR-0009 ✅ |

## Definition of Done

Эпик завершён когда:
- Все story реализованы, проревьюены и закрыты через `/story-done`
- Все acceptance criteria из `design/gdd/combat-ui.md` проверены
- Visual/Feel и UI stories имеют evidence docs с sign-off в `production/qa/evidence/`
- `CombatUI.layer == 11` подтверждено в `game_scene.tscn`
- `player_action_taken` подключён в `GameScene._wire_signals()`, не в `CombatUI._ready()`
- `combat_ui.gd` эмитирует ровно один сигнал: `player_action_taken` (grep-проверка)
- Переключение видимости через `visible`, не через `queue_free()`/`instantiate()`

## Next Step

Run `/create-stories combat-ui` to break this epic into implementable stories.
