# DiceSystem

> **Status**: Designed
> **Author**: game-designer + user
> **Last Updated**: 2026-10-07
> **Implements Pillar**: Pillar 4 — «Честная случайность»

## Overview

DiceSystem — примитив броска кубика: единственный источник случайных чисел для боевых механик. Система предоставляет одну операцию: `roll(dice_count, sides)` → возвращает результат броска. CombatSystem использует DiceSystem для броска атаки против сложности монстра; классовые способности некоторых героев (перебросить кубик, бросить два кубика) реализуются через повторные вызовы `roll()`. DiceSystem не знает контекста вызова — нет разницы между обычным броском и классовым. Генератор случайных чисел имеет явный `seed`, что позволяет воспроизводить результаты в тестах.

> **Примечание**: движение не использует кубик — у каждого игрока фиксировано 4 шага в ход (MovementSystem зависит от TurnManager и DungeonGenerator, но не от DiceSystem). Зависимость MovementSystem → DiceSystem в systems-index.md требует исправления.

## Player Fantasy

DiceSystem — инфраструктурный слой без прямого игрового взаимодействия. Игрок не «использует» DiceSystem — он бросает кубик в бою, а CombatSystem интерпретирует результат. Эмоциональный момент («бросок кубика как напряжение и разрядка») принадлежит CombatSystem и CombatUI, а не DiceSystem.

## Detailed Design

### Core Rules

1. DiceSystem хранит текущее состояние броска в `dice_state: Array[int]` — массив значений каждого кубика.
2. `roll(dice_count: int, sides: int)` — инициализирует `dice_state` из `dice_count` новых случайных значений в диапазоне [1, sides]. Стандартный боевой бросок: `roll(2, 6)` → `dice_state = [die_1, die_2]`.
3. `reroll_die(index: int, sides: int)` — перебрасывает один кубик по индексу: обновляет только `dice_state[index]`, остальные значения не меняются.
4. `get_dice_state() -> Array[int]` — возвращает текущий `dice_state`. CombatSystem суммирует результаты самостоятельно.
5. Перебросок по типу класса:
   - `can_reroll_both_dice` (Воин) → CombatSystem вызывает `roll(2, 6)` заново — `dice_state` полностью заменяется
   - `can_reroll_one_die` (Воительница) → CombatSystem вызывает `reroll_die(chosen_index, 6)` — второй кубик сохраняется
   - `auto_reroll_on_one` (Мечник) → CombatSystem вызывает `reroll_die(i, 6)` для каждого кубика с `dice_state[i] == 1`
6. DiceSystem использует единственный экземпляр `RandomNumberGenerator` с явным `seed`. Для тестов: `set_seed(value: int)`.

### States and Transitions

DiceSystem имеет состояние `dice_state`, которое меняется при каждом `roll()` и `reroll_die()`.

| Операция | Описание |
|----------|----------|
| `roll(n, sides)` | Инициализировать `dice_state` из n новых значений [1..sides] |
| `reroll_die(index, sides)` | Обновить `dice_state[index]` новым значением; остальные без изменений |
| `get_dice_state()` | Вернуть текущий `dice_state: Array[int]` |
| `set_seed(value)` | Установить seed RNG (тесты и replay) |

### Interactions with Other Systems

| Система | Направление | Что передаётся |
|---------|-------------|----------------|
| CombatSystem | → вызывает | `roll(2, 6)` для боевого броска; `reroll_die(index, 6)` или `roll(2, 6)` для перебросков; `get_dice_state()` для чтения результатов |
| ClassSystem | → читает (через CombatSystem) | Флаги `can_reroll_both_dice`, `can_reroll_one_die`, `auto_reroll_on_one` определяют тип вызова |

## Formulas

### Формула 1: Базовый бросок

```
roll(n, sides) = [rng.randi_range(1, sides), ..., rng.randi_range(1, sides)]  (n раз)
```

**Переменные:**

| Переменная | Символ | Тип | Диапазон | Описание |
|------------|--------|-----|----------|----------|
| Количество кубиков | n | int | 1–2 | Обычно 2 для боя; 1 для перебросков |
| Граней на кубике | sides | int | 6 | Всегда 6 в текущей игре |
| Результат одного кубика | die_i | int | 1–6 | Равномерно распределённое случайное число |

**Выходной диапазон:** массив из n элементов; каждый от 1 до sides.

**Пример:** `roll(2, 6)` → `[3, 5]`; сумма = 8.

---

### Формула 2: Итоговый результат броска (в контексте CombatSystem)

```
attack_total = sum(dice_results) + combat_bonus
```

**Переменные:**

| Переменная | Символ | Тип | Диапазон | Описание |
|------------|--------|-----|----------|----------|
| Результаты броска | dice_results | Array[int] | [1..6, 1..6] | Вывод `roll(2, 6)` |
| Сумма кубиков | sum | int | 2–12 | Арифметическая сумма |
| Боевой бонус | combat_bonus | int | 0–N | Бонус от снаряжения/класса; определяет CombatSystem |
| Итог атаки | attack_total | int | 2–(12+N) | Сравнивается со сложностью монстра |

**Выходной диапазон:** 2–12 без бонусов; выше с бонусами от снаряжения.

**Пример:** `roll(2, 6)` → `[3, 5]`; combat_bonus = 2 (топор); attack_total = 10.

> **Примечание**: Формула 2 принадлежит CombatSystem — она здесь только для контекста. DiceSystem отвечает только за Формулу 1.

## Edge Cases

- **EC-01** — ЕСЛИ `dice_count == 0`: `roll(0, 6)` инициализирует `dice_state = []`. Не ошибка.
- **EC-02** — ЕСЛИ `sides <= 0`: `push_error` + `dice_state` не изменяется.
- **EC-03** — ЕСЛИ Мечник (`auto_reroll_on_one`) бросил `[1, 1]`: CombatSystem вызывает `reroll_die(0, 6)` → `dice_state[0]` обновляется, `dice_state[1]` без изменений; затем `reroll_die(1, 6)` → `dice_state[1]` обновляется. Итог: оба переброшены независимо, последовательно.
- **EC-04** — ЕСЛИ Воин (`can_reroll_both_dice`) использует перебросок: CombatSystem вызывает `roll(2, 6)` заново — `dice_state` полностью заменяется. Перебросок добровольный или обязательный — **provisional**, уточнить в CombatSystem GDD.
- **EC-05** — ЕСЛИ Воительница (`can_reroll_one_die`) перебрасывает: CombatSystem вызывает `reroll_die(chosen_index, 6)` — второй кубик остаётся в `dice_state` без изменений.
- **EC-06** — ЕСЛИ `reroll_die(index)` вызван с `index` вне диапазона `dice_state`: `push_error`, `dice_state` не изменяется.
- **EC-07** — ЕСЛИ `set_seed()` вызван между `roll()` и `reroll_die()`: следующий `reroll_die()` использует новый seed. Допустимо — только для тестов.

## Dependencies

### Зависимости входящие (DiceSystem зависит от)

Нет. DiceSystem — Foundation layer, нет зависимостей.

### Зависимости исходящие (зависят от DiceSystem)

| Система | Что берёт из DiceSystem | Статус |
|---------|--------------------------|--------|
| **CombatSystem** | `roll(2, 6)`, `reroll_die(index, 6)`, `get_dice_state()` — весь боевой рандом | Спроектирована ✓ |

> **Примечание**: MovementSystem **не зависит** от DiceSystem — движение фиксировано (4 шага в ход). systems-index.md исправлен.

## Tuning Knobs

### TK-01: Параметры кубика

| Параметр | Значение | Безопасный диапазон | Влияние |
|----------|----------|---------------------|---------|
| `DICE_COUNT` | 2 | 1–2 | Количество кубиков в боевом броске; снижение до 1 уменьшает разброс результатов |
| `DICE_SIDES` | 6 | 4–8 | Количество граней; 4d → результаты теснее к центру, 8d → больший разброс |

### TK-02: Параметры движения (не кубик)

| Параметр | Значение | Безопасный диапазон | Влияние |
|----------|----------|---------------------|---------|
| `STEPS_PER_TURN` | 4 | 3–6 | Фиксированное количество шагов в ход; принадлежит MovementSystem / TurnManager |

> **Примечание**: `STEPS_PER_TURN` здесь только для справки. Значение хранится и настраивается в MovementSystem GDD.

## Visual/Audio Requirements

[To be designed]

## UI Requirements

[To be designed]

## Acceptance Criteria

### AC-01 — `roll(2, 6)` инициализирует dice_state корректно
- **Given** DiceSystem инициализирован
- **When** `roll(2, 6)` вызван
- **Then** `get_dice_state().size() == 2` AND оба значения в диапазоне [1, 6]

### AC-02 — `reroll_die` меняет только один кубик
- **Given** `dice_state == [3, 5]` после `roll(2, 6)` с фиксированным seed
- **When** `reroll_die(0, 6)` вызван
- **Then** `dice_state[1] == 5` (неизменён) AND `dice_state[0]` в диапазоне [1, 6]

### AC-03 — `reroll_die` с некорректным индексом: push_error
- **Given** `dice_state.size() == 2`
- **When** `reroll_die(5, 6)` вызван
- **Then** `push_error` вызван AND `dice_state` не изменился

### AC-04 — `roll` с `dice_count == 0` возвращает пустой массив
- **When** `roll(0, 6)` вызван
- **Then** `get_dice_state() == []`

### AC-05 — `roll` с `sides <= 0` вызывает push_error
- **When** `roll(2, 0)` вызван
- **Then** `push_error` вызван AND `dice_state` не изменился

### AC-06 — Детерминированность при фиксированном seed
- **Given** `set_seed(42)` вызван
- **When** `roll(2, 6)` вызван дважды подряд (без сброса seed)
- **Then** результаты отличаются (RNG продвигается вперёд, не возвращает одно значение)

### AC-07 — Повторный seed даёт воспроизводимый результат
- **Given** `set_seed(42)` → `roll(2, 6)` → записать результат A
- **When** `set_seed(42)` → `roll(2, 6)` повторно
- **Then** результат == A

### AC-08 — Воин: полный перебросок заменяет оба кубика
- **Given** `dice_state == [1, 2]` с seed X
- **When** `roll(2, 6)` вызван повторно с тем же seed
- **Then** `dice_state` полностью заменён новыми значениями

## Open Questions

### OQ-01 — Перебросок Воина: добровольный или обязательный?

Флаг `can_reroll_both_dice` — игрок выбирает, использовать ли способность, или она срабатывает автоматически? Влияет на тактическую глубину.

**Provisional**: добровольный (игрок решает после первого броска). Уточнить в CombatSystem GDD.

---

### OQ-02 — Один DiceSystem на игру или по одному на игрока?

Если DiceSystem — Autoload (singleton), все игроки используют один RNG. Если per-player — каждый игрок имеет независимый RNG и seed.

**Provisional**: один Autoload singleton. Уточнить при архитектурном решении (ADR).

---

### OQ-03 — Нужен ли сигнал `dice_rolled(dice_state: Array[int])`?

CombatUI должен анимировать бросок кубика. Если DiceSystem испускает сигнал после каждого `roll()` и `reroll_die()`, CombatUI может подписаться и показать анимацию.

**Provisional**: сигнал нужен. Уточнить при проектировании CombatUI.
