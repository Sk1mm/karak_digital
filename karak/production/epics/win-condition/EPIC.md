# Epic: WinCondition

> **Layer**: Feature *(Core в systems-index.md)*
> **GDD**: design/gdd/win-condition.md
> **Architecture Module**: WinCondition (Node, stateless)
> **Status**: Ready
> **Manifest Version**: 2026-10-11
> **Stories**: Not yet created — run `/create-stories win-condition`

## Overview

WinCondition — stateless финальный арбитр игры. Слушает `dragon_killed` от CombatSystem, вычисляет победителя по накопленным VP игроков и эмитирует `game_over(winner: PlayerState)`. Расчёт VP: сундуки = 1.0, Ghost-монстр = 1.0, Dragon = 1.5; при ничье победа отдаётся игроку убившему Дракона. После `game_over` TurnManager переходит в GAME_OVER и блокирует дальнейшие мутации состояния.

## Governing ADRs

| ADR | Краткое решение | Engine Risk |
|-----|----------------|-------------|
| ADR-0008: Stateless Feature Systems | WinCondition — stateless; нет persistent var-полей | LOW |
| ADR-0014: WinCondition VP Sources and Tiebreak Rule | Distributed `add_vp()`; VP_DRAGON=1.5; победитель по max(vp); ничья → убийца Дракона | LOW |

## GDD Requirements

| TR-ID | Требование | ADR-покрытие |
|-------|-----------|--------------|
| TR-win-001 | Убийство Дракона запускает сигнал game_over | ADR-0008 ✅ |
| TR-win-002 | Расчёт VP: сундуки (1.0), Ghost (`vp_on_kill`), Dragon (1.5); tiebreak убийце Дракона | ADR-0014 ✅ |

## Definition of Done

Эпик завершён когда:
- Все story реализованы, проревьюены и закрыты через `/story-done`
- Все acceptance criteria из `design/gdd/win-condition.md` проверены
- Все Logic-story имеют проходящие тест-файлы в `tests/unit/win_condition/`
- `game_over` эмитируется ровно один раз за сессию
- Файл не содержит `var`-полей кроме `@export` и `@onready` (grep-проверка)
- Story для TR-win-002 разблокирована (ADR-0014 Accepted)

## Next Step

Run `/create-stories win-condition` to break this epic into implementable stories.
