# Epic: TileRevealVFX

> **Layer**: Presentation
> **GDD**: design/gdd/tile-reveal-vfx.md
> **Architecture Module**: TileRevealVFX (Node2D, scene space)
> **Status**: Ready
> **Manifest Version**: 2026-10-11
> **Stories**: Not yet created — run `/create-stories tile-reveal-vfx`

## Overview

TileRevealVFX реализует анимацию переворота тайла как `TileRevealVFX extends Node2D` — в пространстве сцены, следует за позициями тайлов при движении камеры. Анимация: squish по Y (0.15s) → смена спрайта на лицевую сторону тайла → expand обратно (0.15s), итого ~0.4s. Слушает `cell_entered` от MovementSystem, запускает анимацию на нужной позиции сетки, по завершении эмитирует `tile_reveal_complete(pos: Vector2i)` — триггер для EncounterDispatcher. НЕ является CanvasLayer: использование CanvasLayer вызвало бы смещение анимации относительно тайлов при движении камеры.

## Governing ADRs

| ADR | Краткое решение | Engine Risk |
|-----|----------------|-------------|
| ADR-0002: Signal Wiring Pattern | cell_entered и tile_reveal_complete подключаются в GameScene._wire_signals() | LOW |
| ADR-0009: CanvasLayer Hierarchy | TileRevealVFX — Node2D в пространстве сцены, NOT CanvasLayer; следует за позицией камеры | LOW |

## GDD Requirements

| TR-ID | Требование | ADR-покрытие |
|-------|-----------|--------------|
| TR-vfx-001 | Flip-анимация (squish 0.15s → swap → expand 0.15s) как scene-space Node2D | ADR-0009 ✅ |
| TR-vfx-002 | Эмитирует tile_reveal_complete для триггера EncounterDispatcher | ADR-0002 ✅ |

## Definition of Done

Эпик завершён когда:
- Все story реализованы, проревьюены и закрыты через `/story-done`
- Все acceptance criteria из `design/gdd/tile-reveal-vfx.md` проверены
- Visual/Feel stories имеют evidence docs (скриншоты/видео анимации) с sign-off в `production/qa/evidence/`
- `TileRevealVFX extends Node2D` — NOT CanvasLayer (grep-проверка)
- `tile_reveal_complete` эмитируется ровно один раз по завершении анимации
- Анимация визуально совпадает с позицией тайла при движении камеры (manual QA)

## Next Step

Run `/create-stories tile-reveal-vfx` to break this epic into implementable stories.
