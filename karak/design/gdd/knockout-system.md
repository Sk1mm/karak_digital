# KnockoutSystem

> **Status**: Designed (retrofitted 2026-10-10)
> **Author**: game-designer + user
> **Last Updated**: 2026-10-10
> **Implements Pillar**: Pillar 4 — «Честная случайность», Pillar 3 — «Просто войти, сложно насытиться»

## Overview

KnockoutSystem определяет что происходит с игроком при поражении в бою, снижающем HP до нуля: герой «вырублен» — теряет 1 HP ниже минимума не бывает, но пропускает следующий ход и остаётся с 1 HP. Позиция: CombatSystem уже отступил игрока на предыдущий тайл (`retreat()`). Для игрока нокаут — это штраф без окончательности: один потерянный ход, слабость до следующего фонтана, но снаряжение и очки в сохранности. Исключение: Воин (`knockout_no_turn_skip`) не пропускает ход даже при нокауте. KnockoutSystem не хранит собственного состояния — он координирует PlayerState (флаг нокаута) и TurnManager (логику пропуска хода).

## Player Fantasy

Нокаут — это не смерть. Это урок с ценой. Герой остался жив — с минимальным HP, с потерянным ходом, пока соперник успевает продвинуться вперёд. Ребёнок понимает: «мне не повезло в бою — придётся подождать». Взрослый видит: «я недооценил монстра — надо искать фонтан». Ощущение не фрустрации, а азарта comeback: один слабый ход — и снова в игре. Pillar 4 в действии: нокаут всегда справедлив — ты знаешь почему произошло.

## Detailed Design

### Core Rules

1. **Триггер.** KnockoutSystem слушает сигнал `knocked_out(player)` от PlayerState. Сигнал испускается когда `take_damage()` снижает HP до 0. К этому моменту PlayerState уже установил: `hp = 1`, `skip_next_turn = true`. CombatSystem уже вызвал `retreat()`.

2. **Стандартный нокаут** (все классы кроме Воина).
   - KnockoutSystem ничего дополнительно не делает.
   - Игрок остаётся на тайле монстра (CombatSystem Rule 10a: `is_knocked_out() == true` → `retreat()` пропускается), с `hp = 1`, `skip_next_turn = true`.
   - TurnManager при следующем переключении: `is_knocked_out() == true` → `clear_knockout()` + `turn_skipped(player)` + передаёт ход.

3. **Воин (`knockout_no_turn_skip = true`).**
   - KnockoutSystem вызывает `player.set_position(DungeonGenerator.get_start_tile())`.
   - KnockoutSystem вызывает `player.heal_full()`.
   - KnockoutSystem **не вызывает** `player.clear_knockout()` — флаг `skip_next_turn` остаётся `true` до момента переключения хода.
   - Причина: CombatSystem Rule 10a шаг 2 проверяет `is_knocked_out()` **после** обработки сигнала `knocked_out`; если `clear_knockout()` вызван здесь — CombatSystem увидит `false` и вызовет `retreat()`, перетерев позицию start_tile.
   - Воин оказывается на стартовом тайле с полным HP, `skip_next_turn = true` (временно).
   - TurnManager при следующем переключении хода: `knockout_no_turn_skip == true` AND `is_knocked_out() == true` → вызывает `clear_knockout()` (сбрасывает флаг) → даёт Воину его ход нормально.

### States and Transitions

KnockoutSystem stateless — нет собственных состояний. Получил сигнал → применил правило по классу → завершил работу.

### Interactions with Other Systems

| Система | Роль | Что получает KnockoutSystem | Что отдаёт |
|---|---|---|---|
| PlayerState | upstream | Сигнал `knocked_out(player)` | `set_position(start_tile)`, `heal_full()` — только для Воина; `clear_knockout()` не вызывается здесь (делегировано TurnManager) |
| ClassSystem | upstream | `player.knockout_no_turn_skip` — флаг класса | — |
| DungeonGenerator | upstream | `get_start_tile() -> Vector2i` — позиция стартового тайла | — |
| TurnManager | downstream | — | Неявно: `is_knocked_out()` вернёт false для Воина, true для остальных |

## Formulas

KnockoutSystem не содержит математических формул. Все числовые параметры определены в зависимых системах:

| Параметр | Значение | Владелец |
|---|---|---|
| `HP_RECOVERY_ON_KNOCKOUT` | 1 | PlayerState — `hp` устанавливается в 1 при нокауте |
| `WARRIOR_HEAL_ON_KNOCKOUT` | `max_hp` | PlayerState — `heal_full()` восстанавливает до `max_hp` |
| `start_tile` | позиция стартового тайла | DungeonGenerator — `get_start_tile()` |

Логика ветвления:

```
on knocked_out(player):
    if player.knockout_no_turn_skip:
        player.set_position(DungeonGenerator.get_start_tile())
        player.heal_full()
        # НЕ вызывать clear_knockout() здесь — CombatSystem должен
        # увидеть is_knocked_out() == true при проверке Rule 10a шаг 2
    # else: TurnManager обработает при следующем переключении

# TurnManager при переключении:
# if next_player.knockout_no_turn_skip AND next_player.is_knocked_out():
#     next_player.clear_knockout()  ← здесь безопасно, CombatSystem уже завершил
#     дать Воину его ход (не пропускать)
```

## Edge Cases

**EC-01: Оба игрока нокаутированы в один ход.**
Теоретически невозможно — нокаут происходит в конце хода одного игрока, второй ещё не ходил. Если всё же произошло: KnockoutSystem обрабатывает каждый сигнал независимо. TurnManager обрабатывает пропуск обоих по цепочке (TurnManager EC-02).

**EC-02: `knocked_out` для Воина, `DungeonGenerator.get_start_tile()` недоступен.**
Критическая ошибка инициализации — `push_error`. Стартовый тайл должен быть определён до начала партии.

**EC-03: `heal_full()` для Воина с hp=1 (минимум после нокаута).**
`heal_full()` устанавливает `hp = max_hp`. Если `max_hp > 1` — HP возрастает до максимума. Это намеренно: Воин получает полное восстановление при нокауте независимо от начального HP.

## Dependencies

### Upstream (KnockoutSystem зависит от)

| Система | Что использует |
|---|---|
| **PlayerState** | Сигнал `knocked_out(player)` — триггер; `player.knockout_no_turn_skip` — флаг класса |
| **DungeonGenerator** | `get_start_tile() -> Vector2i` — позиция стартового тайла для Воина |

### Downstream (зависит от KnockoutSystem)

| Система | Что ожидает |
|---|---|
| **PlayerState** | Вызовы `set_position()`, `heal_full()`, `clear_knockout()` — только для Воина |
| **TurnManager** | При переключении хода: для Воина (`knockout_no_turn_skip` AND `is_knocked_out()`) → вызывает `clear_knockout()` и даёт ход нормально; для остальных → вызывает `clear_knockout()` + `turn_skipped` |

### Обратные ссылки

- **TurnManager GDD OQ-03** закрыт: `knockout_no_turn_skip` остаётся в TurnManager как проверка при переключении, но для Воина `is_knocked_out()` вернёт false — проверка не сработает. KnockoutSystem берёт ответственность за немедленный сброс нокаута Воина.
- **DungeonGenerator GDD** должен экспортировать `get_start_tile()` — проверить при проектировании архитектуры.

## Tuning Knobs

| Параметр | Текущее значение | Безопасный диапазон | Что регулирует |
|---|---|---|---|
| `HP_RECOVERY_ON_KNOCKOUT` | 1 | 1–3 | HP после нокаута для всех кроме Воина; владелец — PlayerState |
| Воин: полное лечение при нокауте | `max_hp` | — | Константа класса, не tuning knob — изменение в ClassSystem |

KnockoutSystem не имеет собственных tuning knobs — все параметры принадлежат PlayerState и ClassSystem.

## Visual/Audio Requirements

KnockoutSystem делегирует:
- **HUD** — отображает `turn_skipped(player)` и смену хода
- Анимация нокаута (герой падает) — ответственность TileRevealVFX или отдельного VFX-компонента
- Телепортация Воина на старт — визуальный эффект перемещения: ответственность HUD или будущего MovementVFX

KnockoutSystem не производит визуальных эффектов и не воспроизводит звук.

## UI Requirements

KnockoutSystem не управляет UI напрямую. Уведомление «Воин телепортировался на стартовый тайл» — ответственность HUD.

## Acceptance Criteria

**AC-01:** `knocked_out(player)` получен, класс не Воин → `player.skip_next_turn == true`, `player.hp == 1`, позиция не изменена KnockoutSystem (игрок остаётся на тайле монстра — CombatSystem пропускает retreat). KnockoutSystem не вызывал `set_position`, `heal_full` или `clear_knockout`.

**AC-02:** `knocked_out(player)` получен для Воина → `player.hp == max_hp`, `player.position == start_tile`, `player.is_knocked_out() == true` (флаг не сброшен — TurnManager сбросит при переключении). (Resolved B-10 2026-10-10)

**AC-03:** После AC-02 TurnManager переключает ход к Воину → `clear_knockout()` вызван TurnManager'ом (Воин, `knockout_no_turn_skip`), `turn_skipped` не испущен, Воин получает ход нормально.

**AC-04:** Стандартный нокаут → при следующем переключении TurnManager: `clear_knockout()` вызван, `turn_skipped(player)` испущен, ход переходит к другому игроку.

**AC-05:** CombatSystem Rule 10a: после `take_damage(1)` для Воина → `is_knocked_out() == true` → CombatSystem пропускает `retreat()` → позиция == start_tile (не previous_position). (Resolved B-10 2026-10-10)

## Open Questions

**OQ-01: `heal_full()` в PlayerState.**
PlayerState GDD содержит `heal_full()` в контексте фонтана (EncounterDispatcher). Нужно убедиться что этот же метод доступен для KnockoutSystem. Проверить при retrofit PlayerState или проектировании ClassSystem.

**OQ-02: `get_start_tile()` в DungeonGenerator.**
DungeonGenerator GDD описывает генерацию тайлов, но не экспортирует явный метод `get_start_tile()`. Необходимо добавить при проектировании архитектуры.
