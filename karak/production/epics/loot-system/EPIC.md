# Epic: LootSystem

> **Layer**: Feature *(Core в systems-index.md)*
> **GDD**: design/gdd/loot-system.md
> **Architecture Module**: LootSystem (Node, stateless)
> **Status**: Ready
> **Manifest Version**: 2026-10-11
> **Stories**: Not yet created — run `/create-stories loot-system`

## Overview

LootSystem — stateless обработчик добычи. Реализует три сценария: drop монстра (lookup таблицы по monster_id → ItemData через ItemDatabase), сундук с ключом (1 VP + `clear_cell()`), автоматический подбор ключа при прохождении (если есть `loose_key` на ячейке). Добавляет предметы в PlayerState через `add_item()`, начисляет VP через `add_vp()`, эмитирует `item_acquired`. При заполненных слотах — замена слабейшего оружия (TR-loot-003, пока без ADR).

## Governing ADRs

| ADR | Краткое решение | Engine Risk |
|-----|----------------|-------------|
| ADR-0008: Stateless Feature Systems | LootSystem — stateless; нет persistent var-полей между событиями | LOW |
| ADR-0013: Loot Weapon Replacement Strategy | Автозамена слабейшего оружия по `attack_bonus`; tie-break index 0; scroll FIFO | LOW |

## GDD Requirements

| TR-ID | Требование | ADR-покрытие |
|-------|-----------|--------------|
| TR-loot-001 | Lookup drop-таблицы монстров (8 монстров → предметы) | ADR-0008 ✅ |
| TR-loot-002 | Начисление VP за сундук (1 VP), автоподбор ключа | ADR-0008 ✅ |
| TR-loot-003 | Логика замены слабейшего оружия при подборе нового | ADR-0013 ✅ |

## Definition of Done

Эпик завершён когда:
- Все story реализованы, проревьюены и закрыты через `/story-done`
- Все acceptance criteria из `design/gdd/loot-system.md` проверены
- Все Logic-story имеют проходящие тест-файлы в `tests/unit/loot_system/`
- Файл не содержит `var`-полей кроме `@export` и `@onready` (grep-проверка)
- Story для TR-loot-003 разблокирована (ADR-0013 Accepted)

## Next Step

Run `/create-stories loot-system` to break this epic into implementable stories.
