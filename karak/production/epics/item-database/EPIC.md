# Epic: ItemDatabase

> **Layer**: Foundation
> **GDD**: design/gdd/item-database.md
> **Architecture Module**: ItemDatabase (Autoload)
> **Status**: Ready
> **Manifest Version**: 2026-10-12
> **Stories**: Not yet created — run `/create-stories item-database`

## Overview

ItemDatabase реализует базу данных шести предметов игры и глобальный Autoload-реестр для их поиска. Эпик включает `ItemData extends Resource` — read-only `.tres`-файлы для каждого из 6 предметов (2 оружия, 1 ключ, 3 свитка) с типом (`GameEnums.ItemType`), combat_bonus и прочими свойствами — и `ItemDatabase extends Node` — Autoload с API `get_item(id: StringName) → ItemData`. Нет логики; только данные и lookup. Необходим CombatSystem, LootSystem, PlayerState, InventoryUI.

## Governing ADRs

| ADR | Краткое решение | Engine Risk |
|-----|----------------|-------------|
| ADR-0001: Autoload Strategy | ItemDatabase — Autoload; read-only data; ресурсы загружаются через preload() в _ready() | LOW |

## GDD Requirements

| TR-ID | Требование | ADR-покрытие |
|-------|-----------|--------------|
| TR-item-001 | 6 предметов как read-only ItemData с типизированными свойствами (WEAPON/KEY/SCROLL), глобально доступны | ADR-0001 ✅ |

## Definition of Done

Эпик завершён когда:
- Все story реализованы, проревьюены и закрыты через `/story-done`
- Все acceptance criteria из `design/gdd/item-database.md` проверены
- Все Logic-story имеют проходящие тест-файлы в `tests/unit/item_database/`
- `ItemDatabase` зарегистрирован в Project Settings → Autoload
- Все 6 `.tres` файлов созданы в `assets/data/items/`

## Next Step

Run `/create-stories item-database` to break this epic into implementable stories.
