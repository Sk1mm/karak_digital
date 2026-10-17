# Epic: TileSystem

> **Layer**: Core *(Foundation в systems-index.md)*
> **GDD**: design/gdd/tile-system.md
> **Architecture Module**: TileSystem (Node2D + TileMapLayer) + DungeonCell (plain class)
> **Status**: Ready
> **Manifest Version**: 2026-10-12
> **Stories**: Not yet created — run `/create-stories tile-system`

## Overview

TileSystem реализует память подземелья: `TileSystem extends Node2D` с дочерними `TileMapLayer`-нодами для рендеринга, `DungeonCell` plain class (без extends) для хранения состояния ячейки, и sparse `Dictionary[Vector2i, DungeonCell]` как основное хранилище сетки. Эпик включает пулы тайлов (80 TileData) и жетонов событий (53 EventToken), полный API мутации и чтения (get_cell, place_cell, reveal_cell, clear_cell, draw_tile, draw_event_token, place/remove_loose_key) и сигнал `cell_revealed`. DungeonGenerator вызывает `init_pools()` через GameScene, после чего TileSystem становится единственным источником истины о состоянии подземелья. ENGINE RISK: MEDIUM — TileMapLayer post-cutoff API (верифицировано в current-best-practices.md).

## Governing ADRs

| ADR | Краткое решение | Engine Risk |
|-----|----------------|-------------|
| ADR-0004: TileSystem and TileMapLayer | TileMapLayer (не TileMap); DungeonCell plain class; Dictionary[Vector2i, DungeonCell] | MEDIUM |
| ADR-0007: GameEnums Global Class | TileCategory, TileShape, Direction, EventType enums в GameEnums; enum в сигналах — int | LOW |
| ADR-0005: DungeonGenerator Init Pattern | init_pools() вызывается из GameScene._ready(); защита от двойной инициализации | LOW |
| ADR-0015: Loose Key Lifecycle | DungeonCell.loose_key flag; has/place/remove_loose_key() API; clear_cell() не трогает loose_key | LOW |

## GDD Requirements

| TR-ID | Требование | ADR-покрытие |
|-------|-----------|--------------|
| TR-tile-001 | Sparse grid Dictionary[Vector2i, DungeonCell] с O(1) lookup | ADR-0004 ✅ |
| TR-tile-002 | TileMapLayer рендеринг (не deprecated TileMap) | ADR-0004 ✅ |
| TR-tile-003 | 5 категорий тайлов (CORRIDOR, ROOM, FOUNTAIN, FOUNTAIN_SECONDARY, PORTAL) с state machine | ADR-0004 ✅, ADR-0007 ✅ |
| TR-tile-004 | Выходы ячейки вычисляются из TileShape + rotation | ADR-0004 ✅ |
| TR-tile-005 | Пул тайлов (80) и жетонов событий (53) с API draw_tile() и draw_event_token() | ADR-0004 ✅, ADR-0005 ✅ |
| TR-tile-006 | DungeonCell.loose_key флаг и event_content_id для повторного входа в комнату | ADR-0004 ✅, ADR-0015 ✅ *(partial)* |
| TR-tile-007 | Список порталов: отслеживать revealed порталы для выбора цели телепортации | ADR-0004 ✅ *(partial)* |

## Definition of Done

Эпик завершён когда:
- Все story реализованы, проревьюены и закрыты через `/story-done`
- Все acceptance criteria из `design/gdd/tile-system.md` проверены
- Все Logic-story имеют проходящие тест-файлы в `tests/unit/tile_system/`
- TileSystem не содержит ни одного `TileMap` нода — только `TileMapLayer`
- `DungeonCell` не имеет `extends` (grep-проверка)
- `tile_system.get_cell(Vector2i(99, 99))` возвращает null для неразмещённой позиции
- `reveal_cell(pos)` эмитирует `cell_revealed(pos, cell)`

## Next Step

Run `/create-stories tile-system` to break this epic into implementable stories.
