# Epic: MonsterDatabase

> **Layer**: Foundation
> **GDD**: design/gdd/monster-database.md
> **Architecture Module**: MonsterDatabase (Autoload)
> **Status**: Ready
> **Manifest Version**: 2026-10-12
> **Stories**: Not yet created — run `/create-stories monster-database`

## Overview

MonsterDatabase реализует базу данных восьми монстров игры и глобальный Autoload-реестр для их поиска. Эпик включает `MonsterData extends Resource` — read-only `.tres`-файлы для каждого из 8 монстров (включая Дракона) с полями `id`, `display_name`, `difficulty` и `drop_item_id` — и `MonsterDatabase extends Node` — Autoload с API `get_monster(id: StringName) → MonsterData`. Нет логики; только данные и lookup. Необходим CombatSystem, EncounterDispatcher, LootSystem.

## Governing ADRs

| ADR | Краткое решение | Engine Risk |
|-----|----------------|-------------|
| ADR-0001: Autoload Strategy | MonsterDatabase — Autoload; read-only data; ресурсы загружаются через preload() в _ready() | LOW |

## GDD Requirements

| TR-ID | Требование | ADR-покрытие |
|-------|-----------|--------------|
| TR-monster-001 | 8 монстров как read-only MonsterData со значениями сложности, глобально доступны | ADR-0001 ✅ |

## Definition of Done

Эпик завершён когда:
- Все story реализованы, проревьюены и закрыты через `/story-done`
- Все acceptance criteria из `design/gdd/monster-database.md` проверены
- Все Logic-story имеют проходящие тест-файлы в `tests/unit/monster_database/`
- `MonsterDatabase` зарегистрирован в Project Settings → Autoload
- Все 8 `.tres` файлов созданы в `assets/data/monsters/`

## Next Step

Run `/create-stories monster-database` to break this epic into implementable stories.
