# WinCondition

> **Status**: Designed
> **Author**: game-designer + user
> **Last Updated**: 2026-10-08
> **Implements Pillar**: Pillar 2 — «Сила ощутима», Pillar 4 — «Честная случайность»

## Overview

WinCondition следит за накоплением очков победы (VP) и определяет победителя по завершении партии. Игра заканчивается когда любой игрок убивает Дракона: CombatSystem эмитирует `dragon_killed(player)`, WinCondition начисляет убийце 1.5 VP и сравнивает итоговые суммы всех игроков. Победитель — тот, у кого больше VP. VP накапливаются из трёх источников: открытые сундуки (1 VP каждый, через LootSystem), убитый Призрак (`vp_on_kill` из MonsterDatabase), убитый Дракон (1.5 VP). VP хранится в PlayerState (`add_vp()`); WinCondition только читает финальные значения и объявляет победителя.

## Player Fantasy

Победа не приходит внезапно. Каждый убитый Призрак, каждый открытый сундук — это шаг к финалу, который игрок видит в своём счётчике VP. Дракон — не просто финальный босс, это рычаг: убить его означает закончить игру. Но если у тебя меньше очков — ты проиграл, даже убив Дракона. Это создаёт напряжение: нападать на Дракона первым или копить VP, пока соперник его не упредил? Момент объявления результата — простой и честный: вот VP каждого, вот победитель. Pillar 4 в действии: исход не случаен — он сложился из каждого выбора за всю партию.

## Detailed Design

### Core Rules

1. **Триггер завершения игры.** WinCondition слушает сигнал `dragon_killed(player)` от CombatSystem. При получении сигнала игра переходит в состояние `GAME_OVER` — новые ходы не начинаются.

2. **Начисление VP за Дракона.** WinCondition вызывает `player.add_vp(1.5)`. Убийца получает 1.5 VP немедленно до подведения итогов.

3. **Подведение итогов.** WinCondition читает `player.vp` у каждого игрока и определяет победителя: `winner = argmax(player.vp for player in players)`.

4. **Ничья.** Если VP равны — победа объявляется тому, кто убил Дракона (он завершил игру).

5. **WinCondition stateless.** Не хранит собственного состояния. Все VP — в PlayerState.

### States and Transitions

| Состояние | Описание | Переход из | Переход в |
|---|---|---|---|
| `PLAYING` | Идёт нормальная игра | Старт партии | `GAME_OVER` при `dragon_killed` |
| `GAME_OVER` | Игра завершена, объявляется победитель | `PLAYING` | — (финальное состояние) |

### Interactions with Other Systems

| Система | Роль | Что получает WinCondition | Что отдаёт |
|---|---|---|---|
| CombatSystem | upstream | Сигнал `dragon_killed(player)` | — |
| PlayerState | downstream | — | `add_vp(1.5)` (убийце), `player.vp` (чтение у всех) |
| TurnManager | downstream | — | Сигнал `game_over(winner)` — TurnManager останавливает цикл ходов |
| HUD | downstream | — | Сигнал `game_over(winner)` — HUD отображает экран результата |

## Formulas

### Источники VP (полная таблица)

| Источник | Количество VP | Кто начисляет |
|---|---|---|
| Открытый сундук | 1.0 | LootSystem → `PlayerState.add_vp(1)` |
| Убитый Призрак | `vp_on_kill` (MonsterDatabase) | CombatSystem → `PlayerState.add_vp(vp_on_kill)` |
| Убитый Дракон | 1.5 | WinCondition → `PlayerState.add_vp(1.5)` |

### Определение победителя

```
winner = player with max(player.vp)
tie-break: player who killed the Dragon
```

### Ничья — правило убийцы

```
if player_1.vp == player_2.vp:
    winner = dragon_killer
```

**Примечание:** VP — тип `float` (из-за 1.5). Ничья через float-сравнение (`==`) возможна только если оба игрока набрали ровно одинаковое количество VP включая долю 0.5 от дракона. Поскольку только убийца получает 1.5, и дракон убивается ровно один раз, ничья возможна только если другой игрок ранее набрал VP ≥ 1.5 через сундуки/монстров.

## Edge Cases

**EC-01: `dragon_killed` получен дважды.**
Теоретически невозможно — Дракон уникален на карте (один тайл). После первого `dragon_killed` игра переходит в `GAME_OVER` и TurnManager останавливает цикл ходов. Второй сигнал не может быть испущен. Если получен — `push_error`, игнорировать.

**EC-02: Ничья по VP — математически невозможна.**
Dragon VP = 1.5 — единственный дробный источник. Убийца Дракона всегда набирает X + 1.5 (дробная сумма). Все остальные источники VP целочисленные (1 за сундук, целое `vp_on_kill` за Призрака) → сумма второго игрока всегда целое число. Целое ≠ дробное → равенство VP невозможно. Tie-break правило в Formulas — формальная защита, на практике не срабатывает.

**EC-03: `dragon_killed` до начала партии (ошибка инициализации).**
`push_error`. Дракон не должен существовать до старта. Защита на стороне DungeonGenerator.

**EC-04: У игрока отрицательный VP (теоретически невозможно).**
VP только добавляется, никогда не убавляется. Стартовое значение 0. `add_vp()` принимает только положительные значения. Не обрабатывается.

## Dependencies

### Upstream (WinCondition зависит от)

| Система | Что использует |
|---|---|
| **CombatSystem** | Сигнал `dragon_killed(player)` — триггер завершения игры |
| **PlayerState** | `player.vp` — чтение итоговых VP; `add_vp(1.5)` — начисление VP убийце |

### Downstream (зависит от WinCondition)

| Система | Что ожидает |
|---|---|
| **TurnManager** | Сигнал `game_over(winner)` — останавливает цикл ходов |
| **HUD** | Сигнал `game_over(winner)` — отображает экран результата |

### Обратные ссылки

- **CombatSystem GDD** должен содержать сигнал `dragon_killed(player)` — проверить при retrofit.
- **PlayerState GDD** должен содержать поле `vp: float` и метод `add_vp(amount: float)` — добавить при retrofit PlayerState.
- **game-concept.md** содержит устаревшее описание победного условия («убить Дракона первым») — требует исправления.

## Tuning Knobs

| Параметр | Текущее значение | Безопасный диапазон | Что регулирует |
|---|---|---|---|
| `VP_DRAGON_KILL` | 1.5 | 1.0–3.0 | Ценность убийства Дракона; должна быть дробной (x.5) для математической защиты от ничьей |
| `VP_CHEST` | 1.0 | — | Владелец: LootSystem |
| `vp_on_kill` (Призрак) | определяется в MonsterDatabase | — | Владелец: MonsterDatabase |

**Примечание:** `VP_DRAGON_KILL` должен оставаться дробным (целое + 0.5) для сохранения математической невозможности ничьей. Изменение на целое число потребует добавления явного tie-break правила.

## Visual/Audio Requirements

WinCondition делегирует всё визуальное:
- **HUD** — отображает экран победы/поражения при `game_over(winner)`
- Анимация победы/поражения — ответственность HUD или будущего VFX-компонента

WinCondition не производит визуальных эффектов и не воспроизводит звук.

## UI Requirements

WinCondition не управляет UI напрямую. Экран результата («Победитель: [Игрок X] — [VP] очков») — ответственность HUD.

## Acceptance Criteria

**AC-01:** `dragon_killed(player_A)` получен → `player_A.vp += 1.5`.

**AC-02:** `dragon_killed(player_A)` получен → сигнал `game_over(winner)` испущен до конца того же кадра.

**AC-03:** `dragon_killed(player_A)` получен → TurnManager не начинает новый ход.

**AC-04:** `dragon_killed(player_A)` получен, `player_A.vp > player_B.vp` → `winner == player_A`.

**AC-05:** `dragon_killed(player_A)` получен, `player_A.vp < player_B.vp` → `winner == player_B`.

**AC-06:** После `game_over` повторный `dragon_killed` → `push_error`, состояние не меняется.

## Open Questions

**OQ-01: `dragon_killed` в CombatSystem GDD.**
CombatSystem GDD описывает WIN-исход боя, но не содержит явного сигнала `dragon_killed(player)`. Необходимо добавить при retrofit CombatSystem.

**OQ-02: `vp: float` и `add_vp()` в PlayerState GDD.**
PlayerState GDD ещё не спроектирован. Поле `vp: float` и метод `add_vp(amount: float)` должны быть включены в его дизайн.

**OQ-03: `game_over(winner)` — кто слушает.**
TurnManager и HUD указаны как downstream. Нужно убедиться, что обе системы подписываются на этот сигнал при проектировании их GDDs.
