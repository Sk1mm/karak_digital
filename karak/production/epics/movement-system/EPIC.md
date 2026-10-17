# Epic: MovementSystem

> **Layer**: Feature *(Core в systems-index.md)*
> **GDD**: design/gdd/movement-system.md
> **Architecture Module**: MovementSystem (Node, stateless)
> **Status**: Ready
> **Manifest Version**: 2026-10-11
> **Stories**: Not yet created — run `/create-stories movement-system`

## Overview

MovementSystem — stateless валидатор и исполнитель движения по подземелью. Проверяет exit-connectivity при размещении нового тайла (совместимые выходы между соседними ячейками), расходует шаги через TurnManager, обновляет позицию PlayerState, эмитирует `cell_entered` для запуска цепочки TileRevealVFX → EncounterDispatcher. Реализует class-specific правила движения: обход монстров (Разбойница, Воительница), проход сквозь стены (Волшебник), смена позиций (Чернокнижник), движение через Порталы.

## Governing ADRs

| ADR | Краткое решение | Engine Risk |
|-----|----------------|-------------|
| ADR-0008: Stateless Feature Systems | MovementSystem — stateless; нет var-полей накапливающихся между событиями | LOW |
| ADR-0011: Movement Class Abilities and Portal Cost Rules | Флаги класса читаются напрямую из `PlayerState.character_class`; портал = 2 шага | LOW |

## GDD Requirements

| TR-ID | Требование | ADR-покрытие |
|-------|-----------|--------------|
| TR-movement-001 | Валидация размещения тайла с проверкой exit-connectivity | ADR-0008 ✅ |
| TR-movement-002 | Class-specific обходы монстров (Разбойница, Воительница, Волшебник, Чернокнижник) | ADR-0011 ✅ |
| TR-movement-003 | Правила стоимости движения через Портал | ADR-0011 ✅ |

## Definition of Done

Эпик завершён когда:
- Все story реализованы, проревьюены и закрыты через `/story-done`
- Все acceptance criteria из `design/gdd/movement-system.md` проверены
- Все Logic-story имеют проходящие тест-файлы в `tests/unit/movement_system/`
- `cell_entered` эмитируется при каждом перемещении игрока на новую ячейку
- Story для TR-movement-002 и TR-movement-003 разблокированы (ADR-0011 Accepted)

## Next Step

Run `/create-stories movement-system` to break this epic into implementable stories.
