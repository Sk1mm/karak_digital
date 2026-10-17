# Epic: HUD

> **Layer**: Presentation
> **GDD**: design/gdd/hud.md
> **Architecture Module**: HUD (CanvasLayer, layer=10)
> **Status**: Ready
> **Manifest Version**: 2026-10-11
> **Stories**: Not yet created — run `/create-stories hud`

## Overview

HUD реализует постоянный статусный оверлей игры как `HUD extends CanvasLayer` с `layer = 10`. Отображает состояние обоих игроков: HP-сердца, VP-счётчик, слоты инвентаря, иконки оставшихся шагов, индикатор активного игрока. По завершении партии показывает экран результата с итоговым VP и победителем. Строго Pure Reader — подписывается на сигналы PlayerState и TurnManager через `GameScene._wire_signals()`, никогда не мутирует игровое состояние и не эмитирует сигналов. Видим всегда, в том числе во время боя (HUD остаётся под CombatUI layer=11).

## Governing ADRs

| ADR | Краткое решение | Engine Risk |
|-----|----------------|-------------|
| ADR-0002: Signal Wiring Pattern | Все подписки HUD на сигналы подключаются в GameScene._wire_signals(); HUD не подключает сигналы в своём _ready() | LOW |
| ADR-0009: CanvasLayer Hierarchy | HUD — CanvasLayer layer=10; всегда виден; toggle через visible, не queue_free() | LOW |

## GDD Requirements

| TR-ID | Требование | ADR-покрытие |
|-------|-----------|--------------|
| TR-hud-001 | Постоянный CanvasLayer layer=10 с HP-сердцами, VP-счётчиком, слотами инвентаря, иконками шагов, индикатором хода | ADR-0009 ✅ |
| TR-hud-002 | Pure reader — подписывается на сигналы, никогда не мутирует состояние | ADR-0009 ✅ |

## Definition of Done

Эпик завершён когда:
- Все story реализованы, проревьюены и закрыты через `/story-done`
- Все acceptance criteria из `design/gdd/hud.md` проверены
- Visual/Feel и UI stories имеют evidence docs с sign-off в `production/qa/evidence/`
- `HUD.layer == 10` подтверждено в `game_scene.tscn`
- Файл `hud.gd` не содержит ни одного исходящего сигнала (grep-проверка)
- HUD остаётся виден когда CombatUI (layer=11) активен

## Next Step

Run `/create-stories hud` to break this epic into implementable stories.
