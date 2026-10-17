# Epic: ClassRegistry

> **Layer**: Foundation
> **GDD**: design/gdd/class-system.md
> **Architecture Module**: ClassRegistry (Autoload)
> **Status**: Ready
> **Manifest Version**: 2026-10-12
> **Stories**: 5 stories created

## Overview

ClassRegistry реализует базу данных семи классов героев и глобальный Autoload-реестр для доступа к ним. Эпик включает два компонента: `HeroClassData extends Resource` — read-only `.tres`-файлы для каждого из 7 классов со всеми флагами способностей — и `ClassRegistry extends Node` — Autoload, загружающий эти ресурсы в `_ready()` и предоставляющий `get_class(id)`, `get_all()`, `pick_random(n, rng)` API. Логики не содержит — только данные. Является bottleneck Foundation layer: от ClassRegistry зависят PlayerState (инициализация max_hp), CombatSystem, KnockoutSystem, MovementSystem, EncounterDispatcher.

## Governing ADRs

| ADR | Краткое решение | Engine Risk |
|-----|----------------|-------------|
| ADR-0001: Autoload Strategy | ClassRegistry — Autoload; read-only data only; ресурсы загружаются через preload() в _ready() | LOW |
| ADR-0003: PlayerState as Node | HeroClassData extends Resource (статичные данные классов); PlayerState extends Node (runtime-состояние) | LOW |

## GDD Requirements

| TR-ID | Требование | ADR-покрытие |
|-------|-----------|--------------|
| TR-class-001 | 7 классов героев как read-only HeroClassData Resources с флагами способностей | ADR-0003 ✅ |
| TR-class-002 | Глобальный ClassRegistry доступен из любой системы без import/preload | ADR-0001 ✅ |
| TR-class-003 | Выбор класса: N случайных классов из незанятого пула; character_class неизменен после выбора | ADR-0003 ✅ *(partial)* |

## Definition of Done

Эпик завершён когда:
- Все story реализованы, проревьюены и закрыты через `/story-done`
- Все acceptance criteria из `design/gdd/class-system.md` проверены (AC-01 — AC-14)
- Все Logic-story имеют проходящие тест-файлы в `tests/unit/class_registry/`
- `ClassRegistry` зарегистрирован в Project Settings → Autoload
- Все 7 `.tres` файлов созданы в `assets/data/classes/`

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | HeroClassData Resource Schema | Logic | Ready | ADR-0003 |
| 002 | 7 Class Data Files | Config/Data | Ready | ADR-0003 |
| 003 | ClassRegistry Autoload | Logic | Ready | ADR-0001 |
| 004 | pick_random — Class Selection Pool | Logic | Ready | ADR-0003 |
| 005 | Character Class Immutability Guard | Logic | Ready | ADR-0003 |

## Next Step

Run `/story-readiness production/epics/class-registry/story-001-hero-class-data-schema.md` to begin implementation.
