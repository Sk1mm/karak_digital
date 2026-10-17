# Epic: DiceSystem

> **Layer**: Core *(Foundation в systems-index.md)*
> **GDD**: design/gdd/dice-system.md
> **Architecture Module**: DiceSystem (Node)
> **Status**: Ready
> **Manifest Version**: 2026-10-12
> **Stories**: Not yet created — run `/create-stories dice-system`

## Overview

DiceSystem реализует примитив броска кубиков с детерминированным seed-based RNG. `DiceSystem extends Node` хранит `dice_state: Array[int]` (последний результат броска) и `RandomNumberGenerator`. Публичный API: `roll(dice_count, sides) → Array[int]`, `reroll_die(index, sides)`, `get_dice_state()`, `set_seed(seed)`, `get_seed()`. После каждого `roll()` и `reroll_die()` эмитирует `dice_rolled(results: Array[int])`, который CombatUI использует для анимации. По классификации ADR-0008 — операционально stateless: `dice_state` перезаписывается при каждом броске, не накапливается между ходами. Используется исключительно CombatSystem.

## Governing ADRs

| ADR | Краткое решение | Engine Risk |
|-----|----------------|-------------|
| ADR-0008: Stateless Feature Systems | DiceSystem операционально stateless: dice_state перезаписывается при каждом roll(), не накапливается | LOW |

## GDD Requirements

| TR-ID | Требование | ADR-покрытие |
|-------|-----------|--------------|
| TR-dice-001 | Seed-based детерминированный RNG с API roll(n, sides) и reroll_die(index) | ADR-0008 ✅ |
| TR-dice-002 | set_seed() для воспроизводимости тестов | ADR-0008 ✅ *(partial)* |

## Definition of Done

Эпик завершён когда:
- Все story реализованы, проревьюены и закрыты через `/story-done`
- Все acceptance criteria из `design/gdd/dice-system.md` проверены
- Все Logic-story имеют проходящие тест-файлы в `tests/unit/dice_system/`
- `set_seed(12345); roll(2, 6)` возвращает идентичный результат при двух последовательных вызовах
- `reroll_die(0, 6)` обновляет только `dice_state[0]`, не трогает остальные

## Next Step

Run `/create-stories dice-system` to break this epic into implementable stories.
