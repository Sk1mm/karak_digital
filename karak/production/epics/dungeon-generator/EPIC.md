# Epic: DungeonGenerator

> **Layer**: Feature *(Core в systems-index.md)*
> **GDD**: design/gdd/dungeon-generator.md
> **Architecture Module**: DungeonGenerator (Node, one-shot)
> **Status**: Ready
> **Manifest Version**: 2026-10-11
> **Stories**: Not yet created — run `/create-stories dungeon-generator`

## Overview

DungeonGenerator — одноразовая система инициализации подземелья. Запускается ровно один раз за сессию из `GameScene._ready()`. Реализует сборку пулов (80 TileData + 53 EventToken), seed-based shuffle через `RandomNumberGenerator`, передачу пулов в TileSystem через `init_pools()`, извлечение Fountain-тайла до shuffle и его размещение в Vector2i(0,0), выставление стартовых позиций обоих игроков. Завершает инициализацию отложенным эмитом `dungeon_initialized` через `_emit_initialized.call_deferred()` — гарантирует, что TurnManager получит сигнал только после завершения `_wire_signals()`. После вызова `initialize()` не хранит никакого состояния.

## Governing ADRs

| ADR | Краткое решение | Engine Risk |
|-----|----------------|-------------|
| ADR-0005: DungeonGenerator Init Pattern | initialize() вызывается из GameScene._ready(); dungeon_initialized эмитируется через call_deferred; guard против двойного вызова | LOW |

## GDD Requirements

| TR-ID | Требование | ADR-покрытие |
|-------|-----------|--------------|
| TR-dungeon-001 | Сборка пула (80 тайлов, 53 жетона) с seed-based shuffle и одноразовой инициализацией | ADR-0005 ✅ |
| TR-dungeon-002 | Отложенный эмит сигнала (call_deferred) для безопасного порядка wiring после _wire_signals() | ADR-0005 ✅ |

## Definition of Done

Эпик завершён когда:
- Все story реализованы, проревьюены и закрыты через `/story-done`
- Все acceptance criteria из `design/gdd/dungeon-generator.md` проверены
- Все Logic-story имеют проходящие тест-файлы в `tests/unit/dungeon_generator/`
- `TurnManager._on_dungeon_initialized()` вызывается ровно один раз при старте сессии
- Повторный вызов `initialize()` логирует `push_error` и игнорируется
- При фиксированном seed результат shuffle детерминирован
- `tile_system._tile_pool.size() == 79` после `initialize()` (80 − 1 Fountain)

## Next Step

Run `/create-stories dungeon-generator` to break this epic into implementable stories.
