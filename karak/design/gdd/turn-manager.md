# TurnManager

> **Status**: Designed (retrofitted 2026-10-10 ×3)
> **Author**: game-designer + user
> **Last Updated**: 2026-10-10 (retrofitted I-01 I-03)
> **Implements Pillar**: Pillar 4 — «Честная случайность»

## Overview

TurnManager — система управления порядком ходов. Отслеживает чья сейчас очередь, сколько шагов осталось у активного игрока, и определяет когда ход завершается. Ход завершается при одном из трёх условий: бой с монстром (независимо от исхода), подбор предмета, или исчерпание всех шагов. Исключение — Мечник (`can_continue_turn_on_six`): победа в бою при выпавшей 6 не завершает его ход.

После завершения хода TurnManager переключает активного игрока (1→2→1→2...) и сбрасывает счётчик до 4. Нокаутированный игрок пропускает ход — TurnManager вызывает `clear_knockout()` вместо передачи управления. Исключение — Воин (`knockout_no_turn_skip`): нокаут не прерывает его ход.

Для игрока TurnManager невидим, но его присутствие ощущается в каждом решении: «у меня 2 шага осталось — рискую войти в дальнюю комнату или остановлюсь здесь?»

## Player Fantasy

TurnManager — это дефицит. Четыре шага — достаточно, чтобы добраться до интересного места, и недостаточно, чтобы сделать всё что хочется. Это и есть напряжение хода.

Каждый шаг — маленькое решение: потратить его на разведку или сохранить для отступления? Игрок считает шаги не потому что система заставляет — потому что их постоянно не хватает. Когда счётчик падает до 1 и впереди закрытая комната — это момент, где Pillar 4 («честная случайность») проявляется максимально: войти или нет, зная что назад уже не вернуться в этот ход.

TurnManager не виден — видны его последствия: чужой ход закончился, теперь твой. Переключение активного игрока — это смена перспективы за одним экраном.

## Detailed Design

### Core Rules

1. TurnManager хранит: `active_player_index: int` (0 или 1), `steps_remaining: int`, `steps_taken: int`, `turn_number: int`.

   - `steps_remaining` — сколько шагов ещё доступно в текущем ходу (4→0)
   - `steps_taken` — сколько шагов уже потрачено в текущем ходу (0→4); используется MovementSystem для детекции первого шага (Oracle `first_step_bonus`): `steps_taken == 0` до первого `spend_step()`

   **Публичный API** (дополнительно к `spend_step()` и `burn_steps()`):
   ```gdscript
   func add_step(n: int) -> void   # добавить n шагов к steps_remaining (для способностей классов / будущих расширений)
   ```
   `add_step(n)` увеличивает `steps_remaining` на `n`; не изменяет `steps_taken`. Вызов при `n <= 0` → `push_error`.

2. **Начало партии**: после сигнала `dungeon_initialized` → `active_player_index = 0`, `steps_remaining = STEPS_PER_TURN (4)`, `steps_taken = 0`, `turn_number = 1`. Испускается сигнал `turn_started(player)`.

3. **Расход шагов**: MovementSystem вызывает `spend_step()` при каждом перемещении → `steps_remaining -= 1`, `steps_taken += 1`.

4. **Завершение хода** — логика по сигналам:
   - `steps_remaining == 0` → немедленный конец хода
   - `combat_resolved(won=false, *)` → конец хода (поражение или ничья)
   - `combat_resolved(won=true, six_rolled=true)` (Мечник) → ход продолжается, `steps_remaining` сохраняется
   - `combat_resolved(won=true, six_rolled=false)` → переход в `AWAITING_LOOT`; ход НЕ завершается до `item_acquired`
   - `item_acquired` → конец хода (выход из `AWAITING_LOOT`)

5. **Переключение игрока**: сбросить `steps_remaining = STEPS_PER_TURN`, `steps_taken = 0`; испустить `turn_changed(from_player, to_player)`; `active_player_index = (active_player_index + 1) % 2` → проверить нокаут следующего игрока:
   - Если `next_player.is_knocked_out()` И НЕ `knockout_no_turn_skip` → вызвать `clear_knockout()`, испустить `turn_skipped(player)`, снова переключить
   - Если `knockout_no_turn_skip` (Воин) AND `is_knocked_out() == true` → вызвать `clear_knockout()` (сбросить флаг), затем дать Воину ход нормально — ход **не пропускается**
   - Если `knockout_no_turn_skip` (Воин) AND `is_knocked_out() == false` → дать Воину ход нормально

6. **Мечник** (`can_continue_turn_on_six`): CombatSystem при победе с любым кубиком = 6 испускает `combat_resolved(won=true, six_rolled=true)` → TurnManager НЕ завершает ход, `steps_remaining` сохраняется.

7. **Конец партии**: WinCondition испускает `game_over(winner)` → TurnManager переходит в состояние `GAME_OVER`, прекращает переключения.

8. **Фонтан** (`FOUNTAIN_STEP_BURN`): EncounterDispatcher при посещении фонтана вызывает `burn_steps()` → `steps_remaining = 0`, триггер конца хода.

### States and Transitions

| Состояние | Описание |
|-----------|----------|
| `IDLE` | До `dungeon_initialized` |
| `PLAYER_TURN` | Активный игрок ходит |
| `AWAITING_COMBAT` | Бой начат, ход приостановлен до `combat_resolved` |
| `AWAITING_LOOT` | Подбор предмета в процессе, до `item_acquired` |
| `GAME_OVER` | Партия завершена |

| Переход | Триггер |
|---------|---------|
| `IDLE` → `PLAYER_TURN` | `dungeon_initialized` |
| `PLAYER_TURN` → `AWAITING_COMBAT` | EncounterDispatcher: `combat_started` |
| `AWAITING_COMBAT` → `PLAYER_TURN` | `combat_resolved(won=true, six_rolled=true)` — Мечник продолжает ход |
| `AWAITING_COMBAT` → `AWAITING_LOOT` | `combat_resolved(won=true, six_rolled=false)` — победа, ждём лут |
| `AWAITING_COMBAT` → конец хода | `combat_resolved(won=false, *)` — поражение или ничья |
| `PLAYER_TURN` → `AWAITING_LOOT` | LootSystem: `loot_started` |
| `AWAITING_LOOT` → конец хода | `item_acquired` |
| `PLAYER_TURN` → конец хода | `steps_remaining == 0` или `burn_steps()` |
| Любое → `GAME_OVER` | WinCondition: `game_over(winner)` |

### Interactions with Other Systems

| Система | Направление | Что передаётся |
|---------|-------------|----------------|
| DungeonGenerator | ← слушает | `dungeon_initialized` → старт первого хода |
| PlayerState | ← слушает | сигнал `knocked_out` → пропуск хода; читает `is_knocked_out()`, `character_class` |
| WinCondition | ← слушает | `game_over(winner)` → GAME_OVER |
| PlayerState | → вызывает | `clear_knockout()` при пропуске хода |
| MovementSystem | ← вызывает | `spend_step()` — расход шага при движении |
| EncounterDispatcher | ← слушает | сигнал `combat_started` → переход в `AWAITING_COMBAT` |
| EncounterDispatcher | ← вызывает | метод `burn_steps()` при посещении FOUNTAIN → `steps_remaining = 0` |
| CombatSystem | ← слушает | `combat_resolved(won: bool, six_rolled: bool)` |
| LootSystem | ← слушает | `item_acquired` |
| HUD | ← слушает | `turn_started(player)`, `step_spent(steps_remaining)`, `turn_ended(player)`, `turn_changed(from_player, to_player)` |
| InventoryUI | ← слушает | `turn_changed(from_player, to_player)` — автозакрытие панели инвентаря |

## Formulas

TurnManager минималистичен математически — его логика в правилах и сигналах, а не в вычислениях.

### Формула 1: Бюджет шагов

```
steps_remaining_start = STEPS_PER_TURN = 4  (константа)
steps_remaining_after_move = steps_remaining - 1
turn_ends_by_steps = (steps_remaining == 0)
```

| Переменная | Значение | Описание |
|------------|----------|----------|
| `STEPS_PER_TURN` | 4 | Фиксированный бюджет на ход |
| `steps_remaining` | 0–4 | Текущий остаток шагов |
| `steps_taken` | 0–4 | Шагов потрачено в текущем ходу; инвариант: `steps_taken + steps_remaining == STEPS_PER_TURN + add_step_total` |
| Конец хода | `steps_remaining == 0` | Триггер от исчерпания |

> Бюджет всегда фиксирован: 4. Не бросок кубика, не класс-зависимый параметр.

### Формула 2: Переключение игрока

```
next_player_index = (active_player_index + 1) % 2
```

| Переменная | Значение | Описание |
|------------|----------|----------|
| `active_player_index` | 0 или 1 | Текущий активный игрок |
| `next_player_index` | 1 или 0 | Следующий в очереди |

> MVP фиксирует 2 игроков, но `% N` расширяется без изменений.

> Остальная логика TurnManager (нокаут-пропуск, Мечник, конец партии) управляется сигналами и флагами классов, не формулами.

## Edge Cases

- **EC-01** — ЕСЛИ `spend_step()` вызван при `steps_remaining == 0`: `push_error` — шаг не тратится, ход уже должен был завершиться. MovementSystem не должна вызывать `spend_step()` после конца хода.

- **EC-02** — ЕСЛИ оба игрока нокаутированы одновременно (теоретически невозможно: нокаут происходит в конце хода одного игрока, второй ещё не ходил): если всё же случилось — TurnManager испускает `turn_skipped` для первого, вызывает `clear_knockout()`, переключает к следующему. Если и следующий нокаутирован — аналогично. Игра продолжается, не GAME_OVER.

- **EC-03** — ЕСЛИ `combat_resolved` получен в состоянии `PLAYER_TURN` (не `AWAITING_COMBAT`): `push_error` — неожиданный сигнал, игнорируется. Бой всегда должен начинаться через `combat_started`.

- **EC-04** — ЕСЛИ `item_acquired` получен в состоянии `PLAYER_TURN` (не `AWAITING_LOOT`): аналогично EC-03 — `push_error`, игнорируется.

- **EC-05** — ЕСЛИ Мечник получает `combat_resolved(won=true, six_rolled=true)` при `steps_remaining == 0`: ход всё равно завершается — нет шагов для продолжения. `six_rolled=true` продлевает ход только при наличии остатка шагов.

- **EC-06** — ЕСЛИ `game_over(winner)` от WinCondition получен в середине хода: TurnManager немедленно переходит в `GAME_OVER`. Оставшиеся шаги не играются.

- **EC-07** — ЕСЛИ `burn_steps()` вызван при `steps_remaining == 0`: ноп — шаги уже 0, конец хода уже триггерится.

- **EC-08** — ЕСЛИ `turn_number` переполняется: `turn_number` используется только для HUD и аналитики, не для игровой логики. Не обрабатывать.

- **EC-09** — ЕСЛИ TurnManager находится в состоянии `GAME_OVER` и получает сигнал `item_acquired`: сигнал игнорируется. Guard в обработчике `_on_item_acquired`: `if state == GAME_OVER: return`. Это происходит в сценарии победы над Драконом: `combat_resolved` → `game_over` (WinCondition) → `GAME_OVER`; затем LootSystem эмитирует `item_acquired(player, null)` — его не нужно обрабатывать.

## Dependencies

### Зависимости входящие (TurnManager зависит от)

| Система | Тип | Что нужно |
|---------|-----|-----------|
| **PlayerState** | Жёсткая | `is_knocked_out() -> bool`, `clear_knockout()`, `character_class` (флаги `can_continue_turn_on_six`, `knockout_no_turn_skip`); сигнал `knocked_out` |
| **WinCondition** | Жёсткая | Сигнал `game_over(winner: PlayerState)` → переход в GAME_OVER |
| **DungeonGenerator** | Жёсткая | Сигнал `dungeon_initialized` — старт первого хода |

### Зависимости исходящие (зависят от TurnManager)

| Система | Что берёт | Статус |
|---------|-----------|--------|
| **MovementSystem** | Вызывает `spend_step()` при каждом перемещении; читает `steps_taken` для Oracle `first_step_bonus` | Спроектирована ✓ |
| **EncounterDispatcher** | Испускает `combat_started`; вызывает `burn_steps()` при фонтане | Спроектирован ✓ |
| **CombatSystem** | Испускает `combat_resolved(won: bool, six_rolled: bool)` | Спроектирована ✓ |
| **LootSystem** | Испускает `item_acquired` | Спроектирована ✓ |
| **KnockoutSystem** | Зависит от логики пропуска хода через TurnManager | Спроектирована ✓ |
| **HUD** | Подписан на `turn_started(player)`, `step_spent(steps_remaining)`, `turn_ended(player)`, `turn_skipped(player)`, `turn_changed(from_player, to_player)` | Спроектирован ✓ |
| **InventoryUI** | Подписан на `turn_changed(from_player, to_player)` — автозакрывается при смене хода | Спроектирован ✓ |

## Tuning Knobs

| Параметр | Значение | Безопасный диапазон | Влияние |
|----------|----------|---------------------|---------|
| `STEPS_PER_TURN` | 4 | 3–5 | Темп игры: меньше — быстрее ходы, меньше исследования; больше — длиннее ход, меньше напряжения дефицита |

> TurnManager содержит один tuning knob — `STEPS_PER_TURN`. Флаги классов (`can_continue_turn_on_six`, `knockout_no_turn_skip`) принадлежат ClassSystem GDD.

> **Нижняя граница**: 3 шага — минимум при котором игрок может уйти от стартового фонтана и вернуться. При 2 шагах половина ходов заканчивается прямо у фонтана.
> **Верхняя граница**: 5 шагов — при 6+ игрок стабильно успевает исследовать несколько комнат за ход, напряжение дефицита пропадает.

## Visual/Audio Requirements

[To be designed]

## UI Requirements

[To be designed]

## Acceptance Criteria

### AC-01 — Первый ход стартует после `dungeon_initialized`
- **Given** DungeonGenerator испустил `dungeon_initialized`
- **Then** `active_player_index == 0`, `steps_remaining == 4`, `turn_number == 1`
- **And** сигнал `turn_started(player_0)` испущен

### AC-02 — `spend_step()` уменьшает счётчик
- **Given** `steps_remaining == 3`
- **When** `spend_step()` вызван
- **Then** `steps_remaining == 2`, сигнал `step_spent(2)` испущен

### AC-03 — Ход завершается при `steps_remaining == 0`
- **Given** `steps_remaining == 1`
- **When** `spend_step()` вызван
- **Then** `steps_remaining == 0`, ход завершён, `turn_ended(player_0)` испущен, `active_player_index == 1`, `steps_remaining == 4`

### AC-04 — Ход завершается при `combat_resolved`
- **Given** состояние `AWAITING_COMBAT`, `steps_remaining == 2`
- **When** `combat_resolved(won=true, six_rolled=false)` получен
- **Then** ход завершён, переключение к следующему игроку

### AC-05 — Мечник продолжает ход после победы с 6
- **Given** Мечник (`can_continue_turn_on_six=true`), состояние `AWAITING_COMBAT`, `steps_remaining == 2`
- **When** CombatSystem вызывает `add_step(1)`, затем эмитирует `combat_resolved(won=true, six_rolled=true)`
- **Then** состояние → `PLAYER_TURN`, `steps_remaining == 3` (2 + 1 от `add_step`), ход не завершён

### AC-06 — Мечник не продолжает при поражении с 6
- **Given** Мечник, состояние `AWAITING_COMBAT`
- **When** `combat_resolved(won=false, six_rolled=true)` получен
- **Then** ход завершён (победа обязательна для продолжения)

### AC-07 — Ход завершается при `item_acquired`
- **Given** состояние `AWAITING_LOOT`
- **When** `item_acquired` получен
- **Then** ход завершён, переключение к следующему игроку

### AC-08 — Нокаутированный игрок пропускает ход
- **Given** player_1 `is_knocked_out() == true`, не Воин
- **When** ход переходит к player_1
- **Then** `clear_knockout()` вызван, `turn_skipped(player_1)` испущен, ход переходит обратно к player_0

### AC-09 — Воин не пропускает ход при нокауте
- **Given** player_1 Воин (`knockout_no_turn_skip=true`), `is_knocked_out() == true`
- **When** ход переходит к player_1
- **Then** player_1 ходит нормально, `clear_knockout()` **вызван** (флаг нокаута сброшен), `turn_skipped` не испущен

### AC-10 — `burn_steps()` завершает ход немедленно
- **Given** состояние `PLAYER_TURN`, `steps_remaining == 3`
- **When** `burn_steps()` вызван
- **Then** `steps_remaining == 0`, ход завершён

### AC-11 — `game_over(winner)` переводит в GAME_OVER
- **Given** любое состояние кроме `GAME_OVER`
- **When** WinCondition испускает `game_over(winner)`
- **Then** TurnManager в состоянии `GAME_OVER`, никаких переключений больше не происходит

### AC-12 — `spend_step()` при `steps_remaining == 0` → `push_error`
- **Given** `steps_remaining == 0`
- **When** `spend_step()` вызван
- **Then** `push_error` вызван, состояние не изменилось

## Open Questions

### OQ-01 — Нужен ли отдельный сигнал `loot_started` или достаточно `item_acquired`?

~~**RESOLVED** (2026-10-10, B-12)~~: схема подтверждена. EncounterDispatcher эмитирует `loot_started` → TurnManager переходит в `AWAITING_LOOT`. LootSystem эмитирует `item_acquired(player, item)` после успешной обработки → TurnManager выходит из `AWAITING_LOOT` и завершает ход. `AWAITING_LOOT` нужен для корректного игнорирования `spend_step()` во время анимации подбора. Для сундука `item = null` (VP не является ItemData). Для ключа с пола — `item = key_item`.

### OQ-02 — Что происходит если игрок не берёт предмет из сундука?

Если в сундуке предмет и инвентарь полный — игрок может отказаться от замены. В этом случае `item_acquired` не испускается. Как завершается ход?

**Provisional**: LootSystem испускает `loot_cancelled` → TurnManager выходит из `AWAITING_LOOT` в `PLAYER_TURN` с сохранением `steps_remaining`. Уточнить в LootSystem GDD.

### OQ-03 — Где хранится логика `knockout_no_turn_skip` — в TurnManager или KnockoutSystem?

Сейчас TurnManager читает флаг `knockout_no_turn_skip` напрямую из PlayerState. Альтернатива: KnockoutSystem полностью управляет нокаут-логикой и возвращает TurnManager'у только `should_skip: bool`.

**Provisional**: TurnManager читает флаг напрямую — проще при текущей архитектуре. Пересмотреть при проектировании KnockoutSystem.
