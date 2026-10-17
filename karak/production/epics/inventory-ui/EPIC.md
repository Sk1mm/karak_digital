# Epic: InventoryUI

> **Layer**: Presentation
> **GDD**: design/gdd/inventory-ui.md
> **Architecture Module**: InventoryUI (CanvasLayer, layer=10)
> **Status**: Ready
> **Manifest Version**: 2026-10-11
> **Stories**: Not yet created — run `/create-stories inventory-ui`

## Overview

InventoryUI реализует немодальный инвентарь-оверлей как `InventoryUI extends CanvasLayer` с `layer = 10`. Отображает 2 слота оружия, 1 слот ключа и 3 слота свитков для активного игрока. Автоматически обновляется при получении сигналов `item_added` и `item_removed` от PlayerState. Скрывается/показывается при смене хода через `turn_started`. Pure reader — не мутирует состояние и не эмитирует сигналов. Размещается в Scene Tree после HUD (при одинаковом layer=10 Godot использует порядок в дереве как tiebreaker).

## Governing ADRs

| ADR | Краткое решение | Engine Risk |
|-----|----------------|-------------|
| ADR-0002: Signal Wiring Pattern | Все подписки InventoryUI на сигналы подключаются в GameScene._wire_signals() | LOW |
| ADR-0009: CanvasLayer Hierarchy | InventoryUI — CanvasLayer layer=10; размещается после HUD в Scene Tree; toggle через visible | LOW |

## GDD Requirements

| TR-ID | Требование | ADR-покрытие |
|-------|-----------|--------------|
| TR-inventory-ui-001 | Немодальный CanvasLayer layer=10 с 2 слотами оружия + 1 ключ + 3 свитка | ADR-0009 ✅ |
| TR-inventory-ui-002 | Автообновление из сигналов PlayerState, только чтение | ADR-0002 ✅, ADR-0009 ✅ |

## Definition of Done

Эпик завершён когда:
- Все story реализованы, проревьюены и закрыты через `/story-done`
- Все acceptance criteria из `design/gdd/inventory-ui.md` проверены
- Visual/Feel и UI stories имеют evidence docs с sign-off в `production/qa/evidence/`
- `InventoryUI.layer <= 10` подтверждено в `game_scene.tscn`
- `InventoryUI` расположен после `HUD` в Scene Tree (tiebreaker порядок)
- Файл `inventory_ui.gd` не содержит ни одного исходящего сигнала (grep-проверка)
- Переключение через `visible`, не через `queue_free()`/`instantiate()`

## Next Step

Run `/create-stories inventory-ui` to break this epic into implementable stories.
