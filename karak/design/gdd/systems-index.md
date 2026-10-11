# Systems Index: Karak Digital

> **Status**: Approved
> **Created**: 2026-10-07
> **Last Updated**: 2026-10-07
> **Source Concept**: design/gdd/game-concept.md

---

## Overview

Karak Digital — цифровая адаптация настольного dungeon crawler'а. Механическая
основа проста: процедурно генерируемое подземелье из тайлов, пошаговое движение
двух игроков (hotseat), бой через бросок кубика против сложности монстра, сбор
снаряжения. Цель — убить Дракона (обычный тайл) первым.

Все 17 MVP-систем обслуживают один 30-секундный loop: выбрать тайл →
переместиться → раскрыть → разрешить встречу → передать ход. Pillar 1 («каждый
тайл — маленькая история») требует качественного Tile Reveal VFX; Pillar 2
(«сила ощутима») требует чёткого Combat UI.

---

## Systems Enumeration

| # | Система | Категория | Приоритет | Статус | GDD | Зависит от |
|---|---------|-----------|-----------|--------|-----|------------|
| 1 | PlayerState | Foundation | MVP | Needs Revision | design/gdd/player-state.md | ClassSystem |
| 2 | ClassSystem | Foundation | MVP | Needs Revision | design/gdd/class-system.md | — |
| 3 | TileSystem | Foundation | MVP | Needs Revision | design/gdd/tile-system.md | — |
| 4 | DiceSystem | Foundation | MVP | Designed ✓ | design/gdd/dice-system.md | — |
| 5 | MonsterDatabase | Foundation | MVP | Needs Revision | design/gdd/monster-database.md | — |
| 6 | ItemDatabase | Foundation | MVP | Needs Revision | design/gdd/item-database.md | — |
| 7 | DungeonGenerator | Core | MVP | Needs Revision | design/gdd/dungeon-generator.md | TileSystem |
| 8 | TurnManager | Core | MVP | Needs Revision | design/gdd/turn-manager.md | PlayerState |
| 9 | MovementSystem | Core | MVP | Needs Revision | design/gdd/movement-system.md | DungeonGenerator, TurnManager |
| 10 | EncounterDispatcher | Core | MVP | Needs Revision | design/gdd/encounter-dispatcher.md | TileSystem, PlayerState |
| 11 | CombatSystem | Core | MVP | Needs Revision | design/gdd/combat-system.md | DiceSystem, MonsterDatabase, PlayerState, ItemDatabase |
| 12 | LootSystem | Core | MVP | Needs Revision | design/gdd/loot-system.md | ItemDatabase, PlayerState |
| 13 | KnockoutSystem | Core | MVP | Needs Revision | design/gdd/knockout-system.md | PlayerState, TurnManager |
| 14 | WinCondition | Core | MVP | Needs Revision | design/gdd/win-condition.md | PlayerState, TileSystem |
| 15 | HUD | Presentation | MVP | Designed ✓ | design/gdd/hud.md | PlayerState, TurnManager |
| 16 | CombatUI | Presentation | MVP | Needs Revision | design/gdd/combat-ui.md | CombatSystem |
| 17 | TileRevealVFX | Presentation | MVP | Designed ✓ | design/gdd/tile-reveal-vfx.md | EncounterDispatcher |
| 18 | InventoryUI | Presentation | MVP | Designed ✓ | design/gdd/inventory-ui.md | PlayerState, ItemDatabase |
| 19 | MainMenu | Meta | Post-MVP | Not Started | — | PlayerState |

---

## Категории

| Категория | Описание |
|-----------|----------|
| **Foundation** | Данные и состояние, от которых зависит всё остальное |
| **Core** | Игровые системы, реализующие core loop |
| **Presentation** | UI и VFX, обёртывающие gameplay |
| **Meta** | Системы вне core loop (меню, онбординг) |

---

## Priority Tiers

| Tier | Определение |
|------|-------------|
| **MVP** | Необходимо для core loop — без этих систем нельзя протестировать «интересно ли?» |
| **Post-MVP** | Можно добавить после первого играбельного прототипа |

---

## Dependency Map

### Foundation Layer (нет зависимостей)

1. **PlayerState** — хранит HP, экипировку и позицию каждого игрока; от него зависят 8 систем → bottleneck
2. **ClassSystem** — определяет классы героев (базовые статы, модификаторы); PlayerState зависит от него
3. **TileSystem** — определяет типы тайлов (пусто, монстр, предмет, сундук, дракон); от него зависят 4 системы → bottleneck
4. **DiceSystem** — примитив броска кубика (1d6); используется в движении и бою
5. **MonsterDatabase** — данные монстров (name, difficulty); простая структура данных
6. **ItemDatabase** — данные предметов (оружие, ключи, свитки + их статы); простая структура данных

### Core Layer (зависят от Foundation)

1. **DungeonGenerator** — depends on: TileSystem
2. **TurnManager** — depends on: PlayerState
3. **MovementSystem** — depends on: DungeonGenerator, TurnManager
4. **EncounterDispatcher** — depends on: TileSystem, PlayerState
5. **CombatSystem** — depends on: DiceSystem, MonsterDatabase, PlayerState, ItemDatabase
6. **LootSystem** — depends on: ItemDatabase, PlayerState
7. **KnockoutSystem** — depends on: PlayerState, TurnManager (смерть = пропуск хода + восстановление 1 HP)
8. **WinCondition** — depends on: PlayerState, TileSystem

### Presentation Layer (зависят от Core)

1. **HUD** — depends on: PlayerState, TurnManager
2. **CombatUI** — depends on: CombatSystem
3. **TileRevealVFX** — depends on: EncounterDispatcher
4. **InventoryUI** — depends on: PlayerState, ItemDatabase

### Meta Layer

1. **MainMenu** — depends on: PlayerState (инициализация)

---

## Circular Dependencies

Круговых зависимостей не обнаружено.

---

## Recommended Design Order

| # | Система | Приоритет | Слой | Агент | Усилие |
|---|---------|-----------|------|-------|--------|
| 1 | PlayerState | MVP | Foundation | game-designer | S |
| 2 | TileSystem | MVP | Foundation | game-designer | S |
| 3 | DiceSystem | MVP | Foundation | game-designer | S |
| 4 | MonsterDatabase | MVP | Foundation | game-designer | S |
| 5 | ItemDatabase | MVP | Foundation | game-designer | S |
| 6 | DungeonGenerator | MVP | Core | game-designer + systems-designer | L |
| 7 | TurnManager | MVP | Core | game-designer | S |
| 8 | MovementSystem | MVP | Core | game-designer | S |
| 9 | EncounterDispatcher | MVP | Core | game-designer | S |
| 10 | CombatSystem | MVP | Core | game-designer + systems-designer | M |
| 11 | LootSystem | MVP | Core | game-designer | S |
| 12 | KnockoutSystem | MVP | Core | game-designer | S |
| 13 | WinCondition | MVP | Core | game-designer | S |
| 14 | HUD | MVP | Presentation | game-designer + ux-designer | S |
| 15 | CombatUI | MVP | Presentation | game-designer + ux-designer | M |
| 16 | TileRevealVFX | MVP | Presentation | game-designer + art-director | S |
| 17 | InventoryUI | MVP | Presentation | game-designer + ux-designer | S |

*Усилие: S = 1 сессия, M = 2–3 сессии, L = 4+ сессий*

---

## High-Risk Systems

| Система | Тип риска | Описание | Митигация |
|---------|-----------|----------|-----------|
| DungeonGenerator | Технический | Гарантия связности подземелья (все тайлы достижимы) без изолированных кластеров | Прототипировать первым: flood fill vs WFC |
| CombatSystem | Дизайн | Баланс difficulty монстров vs. бонусы снаряжения без предварительного playtest может быть сломан | Spreadsheet-расчёт до реализации; ранний playtest |

---

## Progress Tracker

| Метрика | Значение |
|---------|----------|
| Всего систем | 18 |
| GDD начаты | 18 |
| GDD проверены | 18 (cross-review + ретрофиты) |
| GDD утверждены | 18 (Designed ✓) |
| MVP систем спроектировано | 18 / 18 |
| GDD требуют ревизии | 0 — все блокеры закрыты (ретрофиты 4–10) |
| Cross-GDD review | design/gdd/gdd-cross-review-2026-10-10i.md — **PASS** (0 BLOCKING) |
| Post-MVP систем спроектировано | 0 / 1 |
| Last Updated | 2026-10-11 |

---

## Next Steps

- [x] Утвердить перечень систем
- [ ] Спроектировать MVP-системы в порядке design order (`/design-system PlayerState`)
- [ ] Запустить `/design-review` на каждый завершённый GDD
- [ ] Прототипировать DungeonGenerator рано (`/prototype dungeon-generation`)
- [ ] Запустить `/gate-check pre-production` когда все MVP GDDs готовы
