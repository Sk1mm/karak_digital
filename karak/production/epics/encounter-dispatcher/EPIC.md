# Epic: EncounterDispatcher

> **Layer**: Feature *(Core в systems-index.md)*
> **GDD**: design/gdd/encounter-dispatcher.md
> **Architecture Module**: EncounterDispatcher (Node, stateless)
> **Status**: Ready
> **Manifest Version**: 2026-10-11
> **Stories**: Not yet created — run `/create-stories encounter-dispatcher`

## Overview

EncounterDispatcher — stateless signal router, центральная точка маршрутизации встреч. Слушает `tile_reveal_complete` от TileRevealVFX, читает категорию и тип события раскрытой ячейки из TileSystem и направляет исполнение: ROOM с монстром → `combat_started(player, monster_data)`, ROOM с сундуком → `loot_started(player, pos)`, FOUNTAIN → heal + burn_steps, PORTAL → teleport, CORRIDOR → `clear_cell()`. Реализует class-specific логику Оракула (`choose_encounter_from_two`). Не хранит никакого состояния между вызовами.

## Governing ADRs

| ADR | Краткое решение | Engine Risk |
|-----|----------------|-------------|
| ADR-0008: Stateless Feature Systems | EncounterDispatcher — stateless signal router; нет persistent var-полей | LOW |

## GDD Requirements

| TR-ID | Требование | ADR-покрытие |
|-------|-----------|--------------|
| TR-encounter-001 | Stateless signal router: ROOM → combat/loot, FOUNTAIN → heal, PORTAL → teleport, CORRIDOR → clear | ADR-0008 ✅ |

## Definition of Done

Эпик завершён когда:
- Все story реализованы, проревьюены и закрыты через `/story-done`
- Все acceptance criteria из `design/gdd/encounter-dispatcher.md` проверены
- Все Logic-story имеют проходящие тест-файлы в `tests/unit/encounter_dispatcher/`
- Вызов `_on_tile_reveal_complete(pos)` дважды с одинаковым Core-состоянием даёт идентичный результат (stateless contract)
- Файл не содержит `var`-полей кроме `@export` и `@onready` (grep-проверка)

## Next Step

Run `/create-stories encounter-dispatcher` to break this epic into implementable stories.
