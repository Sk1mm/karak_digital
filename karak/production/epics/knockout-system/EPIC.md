# Epic: KnockoutSystem

> **Layer**: Feature *(Core в systems-index.md)*
> **GDD**: design/gdd/knockout-system.md
> **Architecture Module**: KnockoutSystem (Node, stateless)
> **Status**: Ready
> **Manifest Version**: 2026-10-11
> **Stories**: Not yet created — run `/create-stories knockout-system`

## Overview

KnockoutSystem — stateless обработчик нокаута. Слушает сигнал `knocked_out` от PlayerState. Стандартный путь: HP игрока = 1 + `skip_next_turn = true`. Warrior-исключение: телепортация на стартовый тайл (Vector2i(0,0)) + `heal_full()` + ход не пропускается (`knockout_no_turn_skip`). Читает флаги из `player.character_class` и вызывает мутирующие методы PlayerState. Не хранит никакого состояния между вызовами.

## Governing ADRs

| ADR | Краткое решение | Engine Risk |
|-----|----------------|-------------|
| ADR-0008: Stateless Feature Systems | KnockoutSystem — stateless; нет persistent var-полей | LOW |

## GDD Requirements

| TR-ID | Требование | ADR-покрытие |
|-------|-----------|--------------|
| TR-knockout-001 | Урон до 0 HP → HP=1 + skip_next_turn=true | ADR-0008 ✅ |
| TR-knockout-002 | Warrior-исключение: телепортация к старту + heal_full + без пропуска хода | ADR-0008 ✅ |

## Definition of Done

Эпик завершён когда:
- Все story реализованы, проревьюены и закрыты через `/story-done`
- Все acceptance criteria из `design/gdd/knockout-system.md` проверены
- Все Logic-story имеют проходящие тест-файлы в `tests/unit/knockout_system/`
- Файл не содержит `var`-полей кроме `@export` и `@onready` (grep-проверка)
- Warrior-нокаут не устанавливает `skip_next_turn = true`
- Стандартный нокаут оставляет HP = 1 (не 0)

## Next Step

Run `/create-stories knockout-system` to break this epic into implementable stories.
