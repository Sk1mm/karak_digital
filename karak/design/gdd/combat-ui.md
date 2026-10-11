# CombatUI

> **Status**: Designed
> **Author**: game-designer + user
> **Last Updated**: 2026-10-09
> **Implements Pillar**: Pillar 2 — «Сила ощутима», Pillar 4 — «Честная случайность»

## Overview

CombatUI — модальный экран боя, перекрывающий игровое поле на время поединка. Подписывается на три сигнала CombatSystem: `combat_started(player, monster_data)` — открывает панель и показывает монстра; `dice_rolled(dice_state)` — анимирует кубики; `combat_resolved(result)` — показывает итог и закрывает панель. В фазе `PLAYER_CHOICE` CombatUI отображает кнопки для опциональных действий (перебросок класса, свитки, HP Чернокнижника) и передаёт решения игрока обратно в CombatSystem.

Для игрока CombatUI — это полный экран боя: монстр виден крупно, кубики падают с анимацией, цифры складываются на глазах, итог `attack_total vs difficulty` отображён явно. Каждое решение — перебросить или нет, потратить свиток или сберечь — подкреплено визуальным контекстом: текущий `attack_total`, `difficulty` монстра, запас свитков. Бой прозрачен (Pillar 4) и ощущается значимым (Pillar 2).

## Player Fantasy

CombatUI — это момент когда снаряжение из «числа в инвентаре» превращается в спасение. Экран боя открывается, монстр стоит напротив, и вся подготовка последних минут сводится к одному броску.

Кубики упали: 6. Без топора — это поражение (6 < 9, Скелет-воин). Но на экране, прямо под результатом броска, видна строка: `+3 Топор`. Итог скакнул до 9. Ничья — и есть ещё свиток: ещё `+1`, итого 10. Монстр повержен. Ребёнок не просто видит победу — он видит, что его топор её сделал. Не "компьютер помог" — а "мой топор помог".

Экран CombatUI построен вокруг этого момента: каждая кнопка (свиток, перебросок, HP) — не абстрактная опция, а инструмент с понятным эффектом. Нажал «Использовать свиток» — `attack_total` на экране вырос на 1, прямо на глазах. До и после — видно.

Поражение тоже честное: `attack_total` и `difficulty` стоят рядом, разница очевидна. Ребёнок не злится на «компьютер нечестный» — он понимает: «Нужен был второй топор».

## Detailed Design

### Core Rules

1. **Слой и модальность.** CombatUI — `CanvasLayer(layer=11)` поверх HUD (layer=10). При открытии затемняет поле через `Backdrop (ColorRect, alpha=0.6)`. Пока CombatUI видима — HUD остаётся доступен для чтения, но клики по полю не проходят.

2. **Триггер открытия.** CombatUI слушает сигнал `CombatSystem.combat_started(player, monster_data)`. При получении: сохранить `player` и `monster_data`, запустить анимацию открытия (Tween 0.3с), отобразить имя монстра и `difficulty`.

3. **Фаза ROLLING_ANIM.** После `combat_started` → ждать `CombatSystem.dice_rolled(dice_state: Array[int])`. При получении: показать оба кубика с их значениями, запустить анимацию падения (0.5–0.8с).
   - `dice_rolled` эмитирует CombatSystem — это сигнал первичного броска.
   - **Авто-реролл Мечника** (`auto_reroll_on_one`): если кубик упал на 1, CombatSystem эмитирует `auto_reroll_triggered(die_index: int, new_value: int)` для каждого автоматического переброска. CombatUI слушает этот сигнал и анимирует каждый шаг: кубик с индексом `die_index` кратко «перемешивается» и показывает `new_value`. Если перебросков несколько — анимируются последовательно. После всех авто-перебросков поступает финальный `dice_rolled` с итоговым `dice_state`.
   - Порядок сигналов для Мечника при броске `[1, 3]`: `dice_rolled([1,3])` → `auto_reroll_triggered(0, ?)` (может повторяться если снова 1) → финальный `dice_rolled([X, 3])`.

   > **Retrofit flag**: CombatSystem GDD требует добавить сигнал `auto_reroll_triggered(die_index: int, new_value: int)` в секции Interactions и Signals.

4. **Фаза CHOICE_REROLL.** Активируется если `available_actions.can_reroll_both == true` или `can_reroll_one == true` (из `player_choice_requested`):
   - **Воин** (`can_reroll_both`): кнопка «Перебросить оба». Кнопка «Оставить» — пропустить.
   - **Воительница** (`can_reroll_one`): оба кубика кликабельны (TextureButton). Клик на кубик → `player_action_taken("reroll_one", index)`. Кнопка «Оставить» — пропустить.
   - После перебросока: CombatSystem эмитирует новый `dice_rolled` → CombatUI возвращается в ROLLING_ANIM → затем переходит в CHOICE_BONUSES.

5. **Фаза CHOICE_BONUSES.** Показывает доступные бонусные опции из `available_actions`:
   - Свитки `MAGIC_ATTACK`: по одной кнопке на каждый свиток в `available_actions.scrolls`. Кнопка показывает `«+1»`. После использования — кнопка становится неактивной (disabled). `scroll_bonus` отражается в строке `AttackBreakdown`.
   - HP Чернокнижника: кнопка `«Потратить 1 HP (+1)»`. Disabled если `can_spend_hp == false` (hp=1). После использования — кнопка disabled; `hp_bonus` отражается в строке.
   - Кнопка «Готово» (ConfirmButton): всегда видна в CHOICE_BONUSES, завершает фазу. Эмитирует `player_action_taken("confirm_done", null)`.

6. **Строка attack_total (AttackBreakdown).** Всегда видна в CHOICE_REROLL и CHOICE_BONUSES. Формат: `«[dice_sum] + [attack_bonus] (оружие) + [scroll_bonus] (свитки) + [hp_bonus] (HP) = [total]»`. Обновляется немедленно при каждом использовании бонуса — игрок видит изменение в реальном времени.

7. **Сравнение с difficulty.** Рядом со строкой attack_total — постоянный лейбл `«vs [difficulty]»`. После нажатия «Готово» — анимация сравнения: если `total > difficulty` → зелёный цвет + `«> »`; ничья → жёлтый + `«= »`; поражение → красный + `«< »`.

8. **Коммуникация CombatUI → CombatSystem.** CombatSystem в `PLAYER_CHOICE` эмитирует `player_choice_requested(available_actions: Dictionary)` и выполняет `await player_action_taken`. CombatUI слушает `player_choice_requested`, показывает кнопки, и при каждом действии игрока эмитирует `player_action_taken(action_type: String, payload: Variant)`. Нет прямых ссылок между нодами — только сигналы.

9. **Фаза RESULT.** CombatSystem эмитирует `combat_resolved(won: bool, six_rolled: bool)`. CombatUI конвертирует локально: `won=true → "WIN"`; `won=false AND attack_total == difficulty → "DRAW"`; `won=false AND attack_total < difficulty → "LOSS"`. Показывает результат: «ПОБЕДА!», «ПОРАЖЕНИЕ», «НИЧЬЯ». Оба числа (`attack_total` и `difficulty`) отображены явно. Задержка 1.5с → автозакрытие. Нажатие любой кнопки = досрочное закрытие.

10. **Закрытие.** Tween 0.3с, затем `visible = false`. CombatUI возвращается в состояние `HIDDEN` — готова к следующему бою.

### States and Transitions

| Состояние | Описание | Активные элементы |
|-----------|----------|-------------------|
| `HIDDEN` | Невидима, ожидает `combat_started` | — |
| `OPENING` | Tween открытия 0.3с | Backdrop + Panel |
| `ROLLING_ANIM` | Анимация кубиков 0.5–0.8с | Die_0, Die_1, MonsterSection |
| `CHOICE_REROLL` | Кнопки переброска (если есть класс) | RerollBothButton / Die_0 Die_1 + SkipRerollButton |
| `CHOICE_BONUSES` | Бонусные кнопки + AttackBreakdown | ScrollButtons, SpendHPButton, ConfirmButton, AttackBreakdown |
| `RESOLVING_ANIM` | Анимация сравнения | AttackBreakdown с цветом, CompareLabel |
| `RESULT` | Итог 1.5с | ResultSection |
| `CLOSING` | Tween закрытия 0.3с | — |

| Переход | Триггер |
|---------|---------|
| `HIDDEN → OPENING` | `CombatSystem.combat_started` |
| `OPENING → ROLLING_ANIM` | Tween завершён |
| `ROLLING_ANIM → CHOICE_REROLL` | `dice_rolled` + `can_reroll_*` = true |
| `ROLLING_ANIM → CHOICE_BONUSES` | `dice_rolled` + нет классового переброска |
| `CHOICE_REROLL → ROLLING_ANIM` | Игрок выбрал перебросок → новый `dice_rolled` |
| `CHOICE_REROLL → CHOICE_BONUSES` | Игрок нажал «Оставить» (пропустить перебросок) |
| `CHOICE_BONUSES → RESOLVING_ANIM` | Игрок нажал «Готово» |
| `RESOLVING_ANIM → RESULT` | `combat_resolved(won, six_rolled)` |
| `RESULT → CLOSING` | Таймер 1.5с или нажатие кнопки |
| `CLOSING → HIDDEN` | Tween завершён |

### Interactions with Other Systems

| Система | Направление | Что передаётся |
|---------|-------------|----------------|
| CombatSystem | ← подписан | `combat_started(player, monster_data)`, `dice_rolled(dice_state)`, `auto_reroll_triggered(die_index, new_value)`, `player_choice_requested(available_actions)`, `combat_resolved(won: bool, six_rolled: bool)` |
| CombatSystem | → эмитирует | `player_action_taken(action_type, payload)` — решения игрока |
| HUD | ← нет | HUD не передаёт данные CombatUI напрямую |

CombatUI является leaf-нодой в смысле отображения: не модифицирует PlayerState, TurnManager или CombatSystem напрямую. Единственное взаимодействие вниз — сигнал `player_action_taken`.

## Formulas

### Формула 1: AttackBreakdown — строка разбивки

```
breakdown_string = dice_sum + join_nonzero(bonuses) + " = " + attack_total
```

Вспомогательная операция `join_nonzero` добавляет `" + X (метка)"` только для частей где `value > 0`. Части с `value == 0` пропускаются. `dice_sum` всегда включается (якорь строки).

**Переменные:**

| Переменная | Символ | Тип | Диапазон | Описание |
|-----------|--------|-----|----------|----------|
| Сумма кубиков | `dice_sum` | int | 2–12 | Из `available_actions`; всегда показывается |
| Бонус оружий | `attack_bonus` | int | 0–6 | Из `available_actions`; скрыть если 0 |
| Бонус свитков | `scroll_bonus` | int | 0–3 | Накоплен локально в CombatUI; скрыть если 0 |
| Бонус HP | `hp_bonus` | int | 0–1 | Локальный флаг CombatUI; скрыть если 0 |
| Бонус Оракула | `first_step_bonus` | int | 0–1 | Из `available_actions`; скрыть если 0 |
| **Итоговая строка** | `breakdown_string` | String | — | Отображаемая строка |

**Выходной диапазон:** строка, минимум `"2 = 2"`, максимум `"12 + 6 (оружие) + 3 (свитки) + 1 (HP) + 1 (Оракул) = 23"`.

**Примеры:**
```
attack_bonus=3, scroll_bonus=0 → "6 + 3 (оружие) = 9"
attack_bonus=3, scroll_bonus=1 → "6 + 3 (оружие) + 1 (свитки) = 10"
attack_bonus=0, hp_bonus=1     → "7 + 1 (HP) = 8"
все бонусы = 0                 → "4 = 4"
```

Строка пересчитывается немедленно при каждом `player_action_taken` в CHOICE_BONUSES.

---

### Формула 2: Видимость и состояние кнопок

```
button_visible  = f(available_actions, current_phase)
button_disabled = f(resource_state)
```

**Переменные:**

| Переменная | Символ | Тип | Диапазон | Описание |
|-----------|--------|-----|----------|----------|
| Воин | `can_reroll_both` | bool | — | Из `available_actions` |
| Воительница | `can_reroll_one` | bool | — | Из `available_actions` |
| Чернокнижник | `can_spend_hp_class` | bool | — | Из `available_actions` |
| HP игрока | `hp` | int | 1–5 | Из `available_actions` |
| Свитки | `scrolls` | Array | size 0–3 | Из `available_actions.scrolls` |
| Использован свиток i | `scroll_used[i]` | bool | — | Локальный флаг CombatUI |
| Потрачен HP | `hp_already_spent` | bool | — | Локальный флаг CombatUI |

| Кнопка | visible | disabled |
|--------|---------|----------|
| RerollBothButton | `can_reroll_both` | — |
| SkipRerollButton | `can_reroll_both OR can_reroll_one` | — |
| Die_0 / Die_1 | `can_reroll_one` | — |
| ScrollButton[i] | `scrolls.size() > i` | `scroll_used[i]` |
| SpendHPButton | `can_spend_hp_class` | `hp <= 1 OR hp_already_spent` |
| ConfirmButton | true (всегда в CHOICE_BONUSES) | — |

> **SpendHPButton при `hp=1`**: `visible=true, disabled=true` — Чернокнижник видит кнопку, понимает ограничение (Pillar 4). Не скрывать.

---

### Формула 3: Цвет сравнения `attack_total vs difficulty`

```
если wins_on_draw == false:
    compare_color = GREEN   если attack_total > difficulty
    compare_color = YELLOW  если attack_total == difficulty
    compare_color = RED     если attack_total < difficulty

если wins_on_draw == true (Разбойница):
    compare_color = GREEN   если attack_total >= difficulty   ← ничья = победа
    compare_color = RED     если attack_total < difficulty
```

**Переменные:**

| Переменная | Символ | Тип | Диапазон | Описание |
|-----------|--------|-----|----------|----------|
| Итог атаки | `attack_total` | int | 2–22 | Из `available_actions` |
| Сложность | `difficulty` | int | 5–15 | Из `monster_data.difficulty` |
| Флаг Разбойницы | `wins_on_draw` | bool | — | Из ClassSystem через `available_actions` |
| **Цвет** | `compare_color` | enum | GREEN/YELLOW/RED | Применяется к CompareLabel |

**Оператор рядом с числами:**
- GREEN `>` — `"attack_total > difficulty"`; GREEN с `>=` для Разбойницы при ничье
- YELLOW `=` — `"attack_total = difficulty"`
- RED `<` — `"attack_total < difficulty"`

---

### Формула 4: Анимация кубиков

```
die_display_value(t) = randi_range(1, 6)    если t < anim_duration
die_display_value(t) = final_value           если t >= anim_duration

die_texture_index    = die_display_value - 1   (индекс 0–5)
frame_interval       = 0.08с                   (≈ 12 смен в секунду)
frames_count         = floor(anim_duration / frame_interval)
```

**Переменные:**

| Переменная | Символ | Тип | Диапазон | Описание |
|-----------|--------|-----|----------|----------|
| Время | `t` | float | 0–anim_duration | С начала анимации |
| Длительность | `anim_duration` | float | 0.5–0.8 | Tuning knob |
| Финальное значение | `final_value` | int | 1–6 | Из `dice_state` — известно до старта анимации |
| Отображаемое | `die_display_value` | int | 1–6 | Псевдослучайное до финала |
| Индекс текстуры | `die_texture_index` | int | 0–5 | Из 6 текстур кубика |

**Пример:** `anim_duration=0.6`, `final_value=4`: за 7 кадров — случайные значения, 8-й фиксирует 4.

> Промежуточные значения — только визуал. `final_value` из `dice_state` уже определён CombatSystem.

Та же формула применяется к `auto_reroll_triggered`: при получении сигнала запускается короткая анимация (0.3с) только для кубика `die_index`, затем показывается `new_value`.

## Edge Cases

### Группа A: Последовательность сигналов

**EC-UI-01 — Если `auto_reroll_triggered` приходит пока идёт предыдущая авто-реролл анимация**: CombatUI ставит сигналы в очередь и анимирует строго по порядку — следующая анимация начинается только после завершения предыдущей. Без очереди Мечник с `[1, 1]` даст наложение анимаций.

**EC-UI-02 — Если `auto_reroll_triggered` приходит пока ещё идёт анимация первичного `dice_rolled`**: Авто-реролл ставится в очередь и обрабатывается только после завершения анимации `dice_rolled` (минимальная задержка = `anim_duration`).

**EC-UI-03 — Если `combat_resolved` приходит пока CHOICE_BONUSES ещё открыт**: По архитектуре невозможно (CombatSystem в `await`), но если произошло — это баг CombatSystem. CombatUI переходит в RESOLVING_ANIM принудительно + `push_error` в лог.

**EC-UI-04 — Если `combat_started` приходит пока CombatUI в состоянии `CLOSING`**: Прервать текущий Tween закрытия, сбросить локальное состояние, немедленно начать новый бой с OPENING.

### Группа B: Логика кнопок и обязательность действий

**EC-UI-05 — Если Воин нажал «Перебросить» и новый результат хуже**: Обязателен по правилам. Кнопка «Перебросить оба» содержит визуальную метку «Результат обязателен» (не диалог). После нажатия — немедленно `disabled=true`, отменить нельзя.

**EC-UI-06 — Если Воительница перебросила кубик и выпало то же значение**: CombatUI всё равно запускает анимацию перемешивания (0.3с). Анимацию нельзя пропускать — игрок должен видеть что бросок состоялся (Pillar 4).

**EC-UI-07 — Если Воительница в CHOICE_REROLL кликнула на один кубик**: Оба кубика немедленно переводятся в `disabled` (не ждать завершения анимации). `can_reroll_one` = один кубик за бой, не два.

### Группа C: Бонусы и пустые состояния

**EC-UI-08 — Если все 3 свитка использованы в CHOICE_BONUSES**: Все `ScrollButton[i]` — `disabled=true` с меткой «Использован» (не просто серый цвет). Если ещё и `can_spend_hp_class=false` — остаётся только ConfirmButton. Валидное состояние.

**EC-UI-09 — Если у Чернокнижника нет свитков и `hp=1` в CHOICE_BONUSES**: SpendHPButton — `visible=true, disabled=true`. Под кнопкой показывается текст «Нет доступных усилений». Только ConfirmButton активна.

**EC-UI-10 — Если Волшебник использовал свиток (`magic_charge_no_discard=true`)**: После первого нажатия `scroll_used[i] = true` → кнопка `disabled`. В PlayerState свиток остаётся, но в рамках текущего боя нажать повторно нельзя.

### Группа D: Граничные значения формул

**EC-UI-11 — Если `attack_total` пересекает `difficulty` в процессе CHOICE_BONUSES**: `compare_color` обновляется в реальном времени при каждом действии. Цвет меняется красный → жёлтый → зелёный по мере добавления бонусов (Pillar 2 + Pillar 4).

**EC-UI-12 — Если `attack_total == difficulty` у Разбойницы (`wins_on_draw=true`)**: `compare_color = GREEN`. `wins_on_draw` обязан присутствовать в `available_actions`, иначе Формула 3 даст ошибочный жёлтый цвет.

**EC-UI-13 — Если AttackBreakdown достигает максимальной длины** (`"12 + 6 (оружие) + 3 (свитки) + 1 (HP) + 1 (Оракул) = 23"`, ~46 символов): Шрифт не выходит за рамки панели. Тестировать с этим вводом обязательно.

### Группа E: Переходы состояний

**EC-UI-14 — Если игрок нажал «Оставить» в CHOICE_REROLL**: Переход в CHOICE_BONUSES без нового `dice_rolled`. `dice_sum` из первичного броска используется напрямую. Нет промежуточного ROLLING_ANIM.

**EC-UI-15 — Если CombatUI получает новый `combat_started` (следующий бой)**: Обязательный сброс всех локальных флагов: `scroll_used[]` → все false, `hp_already_spent` → false, `scroll_bonus` → 0, `hp_bonus` → 0. Без сброса — утечка флагов из предыдущего боя (критический баг).

**EC-UI-16 — Если между «Готово» и приходом `combat_resolved` есть временной зазор**: В RESOLVING_ANIM запускается нейтральная анимация (числа «сходятся»). Финальный цвет и оператор (`>`, `=`, `<`) применяются только при получении `combat_resolved`.

## Dependencies

### Зависимости входящие (CombatUI зависит от)

| Система | Тип | Что нужно | Статус |
|---------|-----|-----------|--------|
| **CombatSystem** | Жёсткая | Сигналы: `combat_started`, `dice_rolled`, `auto_reroll_triggered`, `player_choice_requested`, `combat_resolved`; `await player_action_taken` | Designed ✓ — требует retrofit: добавить `auto_reroll_triggered` и `player_choice_requested` |

### Зависимости исходящие (зависят от CombatUI)

Нет — CombatUI является leaf-нодой. Никакая система не зависит от CombatUI напрямую.

### Зависимости косвенные (через `available_actions`)

| Система | Что ожидается | Статус |
|---------|--------------|--------|
| **ClassSystem** | Флаги `can_reroll_both`, `can_reroll_one`, `can_spend_hp_class`, `auto_reroll_on_one`, `magic_charge_no_discard`, `wins_on_draw` — в `available_actions` | Designed ✓ |
| **ItemDatabase** | `ItemData.icon: Texture2D` + `ItemData.combat_bonus: int` — для кнопок свитков | Not Started |
| **MonsterDatabase** | `MonsterData.name: String`, `MonsterData.difficulty: int` — для заголовка панели | Designed ✓ |
| **PlayerState** | `PlayerState.hp: int` — в `available_actions` для SpendHPButton | Designed ✓ |

### Bidirectional check

- **CombatSystem GDD**, Downstream: «CombatUI — Сигналы `combat_started`, `dice_rolled`, `combat_resolved`» ✓
  → Retrofit required: добавить `auto_reroll_triggered(die_index, new_value)` и `player_choice_requested(available_actions)` в секцию Downstream CombatSystem GDD.

## Tuning Knobs

| Параметр | Значение | Безопасный диапазон | Что ломается за пределами |
|----------|----------|---------------------|--------------------------|
| `OPEN_DURATION_MS` | 300 | 150–500 | <150: мигание вместо открытия; >500: задержка перед боем раздражает |
| `CLOSE_DURATION_MS` | 300 | 150–500 | Аналогично открытию |
| `DICE_ANIM_DURATION` | 0.6с | 0.5–0.8 | <0.5: кубики не успели «упасть»; >0.8: темп боя замедляется |
| `AUTO_REROLL_ANIM_DURATION` | 0.3с | 0.2–0.5 | <0.2: авто-реролл Мечника незаметен; >0.5: каждый авто-реролл затягивает бой |
| `DICE_FRAME_INTERVAL` | 0.08с | 0.06–0.12 | <0.06: мелькание слишком быстрое; >0.12: анимация кажется подтормаживающей |
| `RESULT_DISPLAY_DURATION_MS` | 1500 | 1000–2500 | <1000: ребёнок не успел прочитать; >2500: тормозит темп игры |
| `BACKDROP_ALPHA` | 0.6 | 0.4–0.8 | <0.4: игровое поле «просвечивает» слишком сильно; >0.8: поле неразличимо под модалью |
| `COMPARE_ANIM_DURATION_MS` | 300 | 200–500 | Анимация сравнения чисел в RESOLVING_ANIM; >500: задержка перед отображением результата |

## Visual/Audio Requirements

### Панель и backdrop

- **Backdrop**: `ColorRect`, `#0D0D1A`, alpha=0.6 — синеватый, не чёрный (ощущение ночного подземелья)
- **CombatPanel**: 480×600px, фон `#1A1A2E` alpha=0.95, рамка 4px `#C0A060` (золото — важное событие), скругление 12px, drop shadow 6px `#00000088`

### Монстр-секция

- Спрайт монстра: 160×160px, жирный outline 3–4px `#1A0A00`, тот же стиль что HUD-иконки
- Имя: bold 18–20px, `#F5DEB3`, stroke 2px `#1A0A00`
- Difficulty badge справа от имени: цифра + цветной tag, фон `#1A0A00` с скруглением 4px

| Difficulty | Цвет badge |
|-----------|-----------|
| 5–7 | `#6ABF69` (зелёный) |
| 8–10 | `#E8A020` (оранжевый) |
| 11–15 | `#E84040` (красный) |

### Кубики d6

- Форма: скруглённые углы radius 12px, 64×64px, stroke 3px `#5A3000`, drop shadow 4px `#00000066`
- Фон кубика: `#C0A060` → `#FFD700` с ростом значения; кубик-6 — золотой + outer glow 4px `#FFD70080`
- Анимация rolling: scale 1.0→0.95→1.05→1.0 + rotation ±3° на каждой смене значения (не полный оборот — Compatibility renderer)
- auto_reroll_triggered: тот же rolling-эффект, 0.3с, только для кубика `die_index`

### AttackBreakdown

Горизонтальная строка, каждый бонус — отдельный элемент с иконкой:

| Тип | Цвет | Иконка 16px |
|-----|------|-------------|
| `dice_sum` | `#F5DEB3` | кубик |
| `attack_bonus` | `#C0A060` (золото оружия, как в HUD) | оружие |
| `scroll_bonus` | `#A080D0` (рунический, как в HUD) | свиток |
| `hp_bonus` | `#E8403A` (красный HP, как в HUD) | сердечко |
| `first_step_bonus` | `#6AAAF0` (синий) | звезда |
| `= total` | `#FFFFFF` bold 22px | — |
| `vs difficulty` | по Формуле 3 (GREEN/YELLOW/RED) | — |

При добавлении бонуса: total fade-out 0.1с → scale 1.0→1.2→1.0 за 0.2с (микро-подтверждение прироста).

### Кнопки

- **Normal**: фон `#2A3A5A`, рамка 3px `#4A6A9A`, radius 8px, drop shadow 3px вниз (физический вес)
- **Hover**: фон `#3A4A6A`, inner glow 2px `#6A9ACA40`; shadow убирается
- **Pressed**: shadow=0, контент сдвинут +2px вниз (кнопка «вдавлена»)
- **Disabled**: фон `#1A1A2E`, рамка `#4A4A6A`, opacity 60% + метка под основным текстом (`«Использован»`, `«HP = 1»`)
- **RerollBothButton**: badge `⚠` `#E8A020` в верхнем углу — постоянный предупредительный маркер (без диалога)
- **ConfirmButton (CTA)**: фон `#2A5A2A`, рамка `#4A9A4A`, 160×48px — визуально отличается от остальных

### Экран результата

| Результат | Фон-flash | Текст | Анимация |
|-----------|-----------|-------|----------|
| WIN | `#FFD70040` 1 кадр → fade 0.3с | «ПОБЕДА!» 48px bold `#FFD700`, stroke 4px `#5A3000` | scale bounce 0.5→1.3→1.0 (0.5с) + 8–12 звёздочек `#FFD700` разлетаются |
| LOSS | — | «ПОРАЖЕНИЕ» 40px bold `#E84040`, stroke 4px `#1A0A00` | scale 1.0→0.9→1.0 (0.4с) + micro-shake панели ±6px (3 осц., 0.4с) |
| DRAW | — | «НИЧЬЯ» 36px `#E8C040` | нейтральный fade-in |

### Приоритеты анимаций для MVP

| Приоритет | Анимация | MVP |
|-----------|----------|-----|
| P0 обязательно | Кубики rolling | Да |
| P0 обязательно | AttackBreakdown live-update + compare_color | Да |
| P0 обязательно | Открытие/закрытие панели Tween 0.3с | Да |
| P1 важно | WIN flash | Желательно |
| P2 polish | LOSS micro-shake, die bounce при финале | После MVP |
| P3 nice-to-have | Частицы WIN, auto-reroll rolling анимация | После MVP |

### Аудио

| Событие | Звук | Длительность | Характер |
|---------|------|--------------|----------|
| Панель открывается | «вух» деревянной двери | 0.3с | Подземелье, вес |
| Кубики rolling (loop) | деревянный стук-грохот | 0.5–0.8с | Нарастание напряжения |
| Кубики stopped | «бах» приземления | 0.2с | Удар о стол |
| Бонус добавлен | «дзинь» монеты | 0.1с | Ценность, прирост |
| WIN | мажорный аккорд + короткая фанфара | 0.5с | Праздник |
| LOSS | низкий «бум» | 0.3с | Cartoon, не мрачный |
| Кнопка disabled (попытка нажать) | глухой щелчок | 0.1с | Мягкий отказ |
| Свиток использован | «шорох свитка» | 0.2с | Пергамент |
| Панель закрывается | обратный «вух» | 0.2с | Мягче открытия |

**Ограничения**: все звуки CombatUI 80–100% от громкости боя; никаких резких alarm-звуков; аудитория 5–10 лет.

> **📌 Asset Spec**: Visual/Audio требования определены. После утверждения арт-библии запустить `/asset-spec system:combat-ui` для per-asset спецификаций и промптов генерации.

## UI Requirements

### Раскладка экрана

CombatUI — модальная панель по центру экрана поверх игрового поля:

```
┌──────────────────────────────────────────────┐
│ [Backdrop: #0D0D1A, alpha=0.6, full_rect]    │
│                                              │
│    ┌────────────────────────────────┐        │
│    │  CombatPanel (480×600px)       │        │
│    │                                │        │
│    │  [Monster: 160×160px]          │        │
│    │  Monster Name  [DIFF badge]    │        │
│    ├────────────────────────────────┤        │
│    │  [Die_0 64px]  [Die_1 64px]    │        │
│    ├────────────────────────────────┤        │
│    │  6 + 3(⚔) = [9]  vs  [8]       │        │
│    ├────────────────────────────────┤        │
│    │  [Reroll / Skip Reroll]        │        │
│    │  [Scroll +1] [Scroll +1]       │        │
│    │  [Spend HP +1]                 │        │
│    │  [       Готово       ]        │        │
│    ├────────────────────────────────┤        │
│    │  [ResultSection — hidden]      │        │
│    └────────────────────────────────┘        │
└──────────────────────────────────────────────┘
```

### Структура нод (Godot 4.7)

```
CanvasLayer (layer=11)
└── CombatUI (Control, anchors=full_rect)
    ├── Backdrop (ColorRect, full_rect, color=#0D0D1A, alpha=0.6)
    └── CombatPanel (PanelContainer, anchors=center, size=480×600)
        ├── MonsterSection (VBoxContainer)
        │   ├── MonsterSprite (TextureRect, 160×160)
        │   ├── MonsterName (Label)
        │   └── DifficultyBadge (HBoxContainer)
        │       ├── DiffLabel (Label)
        │       └── DiffTag (Panel + Label)
        ├── DiceSection (HBoxContainer, gap=8px)
        │   ├── Die_0 (TextureButton, 64×64)
        │   └── Die_1 (TextureButton, 64×64)
        ├── BreakdownSection (HBoxContainer)
        │   ├── AttackBreakdown (Label — динамически пересчитывается)
        │   └── CompareLabel (Label — "vs 9", цвет по Формуле 3)
        ├── ActionSection (VBoxContainer)
        │   ├── RerollBothButton (Button, мин. 120×44px) ← visible = can_reroll_both
        │   ├── SkipRerollButton (Button)               ← visible = can_reroll_*
        │   ├── ScrollButtons (VBoxContainer)            ← по одной на каждый свиток
        │   ├── SpendHPButton (Button)                  ← visible = can_spend_hp_class
        │   └── ConfirmButton (Button, 160×48px)        ← всегда в CHOICE_BONUSES
        └── ResultSection (VBoxContainer, visible=false)
            ├── ResultLabel (Label, 48px)
            └── CompareResultLabel (Label)              ← "attack_total > difficulty"
```

### Размеры элементов

| Элемент | Размер | Обоснование |
|---------|--------|-------------|
| CombatPanel | 480×600px | ~50% ширины экрана 1920px; читается на 1366px |
| MonsterSprite | 160×160px | Доминанта панели — монстр главный объект встречи |
| Кубик (Die) | 64×64px | Крупный для ребёнка; два кубика + 8px gap = 136px |
| Кнопки action | мин. 120×44px | WCAG минимум кликабельности 44px |
| ConfirmButton | 160×48px | CTA выделяется размером |

### Кликабельность

- **Die_0, Die_1**: `mouse_filter = MOUSE_FILTER_STOP` только в `CHOICE_REROLL` при `can_reroll_one=true`; иначе `MOUSE_FILTER_IGNORE`
- **Backdrop**: `mouse_filter = MOUSE_FILTER_STOP` — поглощает клики, игровое поле недоступно пока CombatUI открыт
- **ResultSection**: нажатие любой области = досрочное закрытие (аналог «тап для продолжения»)
- **Кнопки disabled**: через Godot Button `disabled=true` — автоматически блокируют ввод

### Инициализация

- CombatUI получает ссылку на CombatSystem через `@export var combat_system: CombatSystem`
- `_ready()`: `assert(combat_system != null)` + `connect()` на все сигналы
- Начальное состояние: `visible=false`, все локальные флаги сброшены (`scroll_used=[]`, `hp_already_spent=false`)
- Die_0, Die_1: `mouse_filter = MOUSE_FILTER_IGNORE` по умолчанию

> **📌 UX Flag — CombatUI**: Этот раздел содержит UI требования. Перед написанием epic-ов запустить `/ux-design` для создания UX-спека экрана боя **до** написания stories.

## Acceptance Criteria

Gate: **BLOCKING** (Logic) — автотест в `tests/unit/combat_ui/` обязателен до Done.
Gate: ADVISORY — скриншот + sign-off или ручной walkthrough в `production/qa/evidence/`.

### Слой и открытие (Core Rules 1–2)

**AC-CUI-01** `UI · ADVISORY`
GIVEN HUD отображается на CanvasLayer(layer=10), WHEN получен `combat_started`, THEN CombatUI (layer=11) поверх HUD; Backdrop блокирует клики по полю; HUD остаётся читаемым.

**AC-CUI-02** `Logic · BLOCKING`
GIVEN HIDDEN, WHEN CombatSystem эмитирует `combat_started(player, monster_data)`, THEN Tween 0.3с запущен; после завершения — OPENING→ROLLING_ANIM; имя монстра и difficulty отображены.

### State Machine Transitions

**AC-CUI-03** `Logic · BLOCKING`
GIVEN HIDDEN, WHEN `combat_started`, THEN состояние → OPENING; Backdrop и CombatPanel visible.

**AC-CUI-04** `Logic · BLOCKING`
GIVEN OPENING, WHEN Tween 0.3с завершён, THEN состояние → ROLLING_ANIM; кнопки скрыты; Die_0 и Die_1 показаны.

**AC-CUI-05** `Logic · BLOCKING`
GIVEN ROLLING_ANIM, WHEN `dice_rolled` и `can_reroll_both == true OR can_reroll_one == true`, THEN после анимации кубиков → CHOICE_REROLL; соответствующие кнопки/кубики кликабельны.

**AC-CUI-06** `Logic · BLOCKING`
GIVEN ROLLING_ANIM, WHEN `dice_rolled` и нет классового переброска, THEN после анимации → CHOICE_BONUSES напрямую; кнопки перебросков не показаны.

**AC-CUI-07** `Logic · BLOCKING`
GIVEN CHOICE_REROLL, WHEN игрок выбрал перебросок, THEN `player_action_taken` эмитирован; → ROLLING_ANIM; после нового `dice_rolled` → CHOICE_BONUSES.

**AC-CUI-08** `Logic · BLOCKING`
GIVEN CHOICE_REROLL, WHEN игрок нажал «Оставить», THEN → CHOICE_BONUSES напрямую без нового `dice_rolled`; `dice_sum` из первичного броска используется в AttackBreakdown.

**AC-CUI-09** `Logic · BLOCKING`
GIVEN CHOICE_BONUSES, WHEN «Готово» нажата, THEN `player_action_taken("confirm_done", null)` эмитирован; → RESOLVING_ANIM; анимация сравнения чисел запущена.

**AC-CUI-10** `Logic · BLOCKING`
GIVEN RESOLVING_ANIM, WHEN `combat_resolved(result)`, THEN → RESULT; финальный цвет CompareLabel и оператор применены; текст WIN/LOSS/DRAW отображён.

**AC-CUI-11** `Logic · BLOCKING`
GIVEN RESULT, WHEN 1.5с прошло без нажатий, THEN → CLOSING; Tween 0.3с запущен.

**AC-CUI-12** `UI · ADVISORY`
GIVEN RESULT, WHEN клик в ResultSection до 1.5с, THEN → CLOSING немедленно.

**AC-CUI-13** `Logic · BLOCKING`
GIVEN CLOSING, WHEN Tween 0.3с завершён, THEN `visible=false`; → HIDDEN; все локальные флаги сброшены.

### Core Rules 3–5 — Кубики и перебросок класса

**AC-CUI-14** `Logic · BLOCKING`
GIVEN ROLLING_ANIM после `dice_rolled`, WHEN `auto_reroll_triggered(die_index, new_value)`, THEN только кубик `die_index` запускает rolling 0.3с и показывает `new_value`; второй кубик не затронут.

**AC-CUI-15** `Logic · BLOCKING`
GIVEN CHOICE_REROLL, `can_reroll_both=true`, THEN RerollBothButton visible=true; SkipRerollButton visible=true; Die_0/Die_1 mouse_filter=IGNORE.

**AC-CUI-16** `Logic · BLOCKING`
GIVEN CHOICE_REROLL, `can_reroll_one=true`, THEN Die_0 и Die_1 mouse_filter=STOP; RerollBothButton visible=false; SkipRerollButton visible=true.

### Core Rules 6–8 — CHOICE_BONUSES и сигналы

**AC-CUI-17** `Logic · BLOCKING`
GIVEN CHOICE_BONUSES, `scrolls.size()=2`, THEN ровно 2 ScrollButton; обе показывают «+1»; ConfirmButton всегда visible.

**AC-CUI-18** `Logic · BLOCKING`
GIVEN CHOICE_BONUSES, `can_spend_hp_class=true`, `hp=1`, THEN SpendHPButton visible=true, disabled=true. Не скрыта.

**AC-CUI-19** `Logic · BLOCKING`
GIVEN CHOICE_BONUSES, WHEN ScrollButton[0] нажата, THEN `player_action_taken("use_scroll", 0)` эмитирован.

**AC-CUI-20** `Logic · BLOCKING`
GIVEN бой с Воином + свиток + Чернокнижник, THEN CHOICE_REROLL предшествует CHOICE_BONUSES; внутри CHOICE_BONUSES свитки и HP доступны одновременно.

### Formula 1 — AttackBreakdown

**AC-CUI-21** `Logic · BLOCKING`
GIVEN `attack_bonus=0, scroll_bonus=0, hp_bonus=0`, THEN строка = `"[dice_sum] = [dice_sum]"`; нет `"(оружие)"`, `"(свитки)"`, `"(HP)"`.

**AC-CUI-22** `Logic · BLOCKING`
GIVEN `attack_bonus=3, scroll_bonus=0`, THEN строка содержит `"+ 3 (оружие)"` и НЕ содержит `"(свитки)"`, `"(HP)"`.

**AC-CUI-23** `Logic · BLOCKING`
GIVEN строка `"6 + 3 (оружие) = 9"`, WHEN свиток использован, THEN строка немедленно → `"6 + 3 (оружие) + 1 (свитки) = 10"`.

**AC-CUI-24** `UI · ADVISORY`
GIVEN `dice_sum=12, attack_bonus=6, scroll_bonus=3, hp_bonus=1, first_step_bonus=1`, THEN строка = `"12 + 6 (оружие) + 3 (свитки) + 1 (HP) + 1 (Оракул) = 23"`; текст не выходит за рамки CombatPanel.

### Formula 2 — Кнопки

**AC-CUI-25** `Logic · BLOCKING`
GIVEN ScrollButton[0] активна, WHEN нажата, THEN ScrollButton[0].disabled=true; ScrollButton[1] остаётся enabled.

**AC-CUI-26** `Logic · BLOCKING`
GIVEN `can_spend_hp_class=true, hp=2`, WHEN SpendHPButton нажата, THEN disabled=true; `hp_already_spent=true`; повторное нажатие невозможно.

**AC-CUI-27** `Logic · BLOCKING`
GIVEN все свитки использованы, `can_spend_hp_class=false`, THEN ConfirmButton visible=true, enabled=true.

### Formula 3 — compare_color

**AC-CUI-28** `Logic · BLOCKING`
GIVEN `attack_total=10, difficulty=9, wins_on_draw=false`, WHEN `combat_resolved(true, false)`, THEN CombatUI вычисляет «WIN» (attack_total > difficulty); CompareLabel = GREEN, оператор `">"`.

**AC-CUI-29** `Logic · BLOCKING`
GIVEN `attack_total=9, difficulty=9, wins_on_draw=false`, WHEN `combat_resolved(false, false)`, THEN CombatUI вычисляет «DRAW» (attack_total == difficulty, won=false); CompareLabel = YELLOW, оператор `"="`.

**AC-CUI-30** `Logic · BLOCKING`
GIVEN `attack_total=7, difficulty=9`, WHEN `combat_resolved(false, false)`, THEN CombatUI вычисляет «LOSS» (attack_total < difficulty); CompareLabel = RED, оператор `"<"`.

**AC-CUI-31** `Logic · BLOCKING`
GIVEN `attack_total=9, difficulty=9, wins_on_draw=true`, WHEN `combat_resolved(true, false)` (Разбойница, ничья=победа), THEN CombatUI вычисляет «WIN»; CompareLabel = GREEN, оператор `">="`. Не YELLOW, не RED.

**AC-CUI-32** `Logic · BLOCKING`
GIVEN CHOICE_BONUSES, `attack_total=8 < difficulty=9` (CompareLabel=RED), WHEN свиток использован (`attack_total=9`), THEN CompareLabel → YELLOW без нажатия «Готово».

### Formula 4 — Анимация кубиков

**AC-CUI-33** `Logic · BLOCKING`
GIVEN ROLLING_ANIM, WHEN `dice_rolled([4, 2])`, THEN оба кубика показывают псевдослучайные значения 0.5–0.8с; по истечении Die_0=4, Die_1=2.

**AC-CUI-34** `Logic · BLOCKING`
GIVEN `dice_rolled([3, 5])`, анимация завершена, THEN Die_0=3, Die_1=5; промежуточные значения не влияют на логику.

**AC-CUI-35** `Logic · BLOCKING`
GIVEN ROLLING_ANIM после `dice_rolled([1, 3])`, WHEN `auto_reroll_triggered(0, 4)`, THEN Die_0: rolling 0.3с → показывает 4; Die_1 остаётся 3.

### Edge Cases — обязательные

**AC-CUI-36** `Logic · BLOCKING` *(EC-UI-01)*
GIVEN Мечник бросил `[1, 1]`, первый `auto_reroll_triggered(0, X)` ещё анимируется, WHEN приходит `auto_reroll_triggered(1, Y)`, THEN второй помещён в очередь; анимация Die_1 начинается только после завершения Die_0.

**AC-CUI-37** `Logic · BLOCKING` *(EC-UI-02)*
GIVEN ROLLING_ANIM, анимация `dice_rolled` ещё идёт, WHEN `auto_reroll_triggered`, THEN в очередь; обрабатывается только после завершения `dice_rolled` анимации.

**AC-CUI-38** `Logic · BLOCKING` *(EC-UI-04)*
GIVEN CLOSING (Tween идёт), WHEN `combat_started`, THEN Tween прерван; флаги сброшены; OPENING для нового боя начинается немедленно.

**AC-CUI-39** `Logic · BLOCKING` *(EC-UI-07)*
GIVEN CHOICE_REROLL, `can_reroll_one=true`, WHEN Die_0 кликнут, THEN Die_0 и Die_1 немедленно disabled; не после завершения анимации.

**AC-CUI-40** `Logic · BLOCKING` *(EC-UI-10)*
GIVEN Волшебник (`magic_charge_no_discard=true`), ScrollButton[0] активна, WHEN нажата, THEN `scroll_used[0]=true`; disabled=true; в следующем бою кнопка сбросится.

**AC-CUI-41** `Logic · BLOCKING` *(EC-UI-15)*
GIVEN бой завершён (`scroll_used=[true,true]`, `hp_already_spent=true`, `scroll_bonus=2`), WHEN новый `combat_started`, THEN все флаги сброшены; новый бой с чистым состоянием.

### Дополнительные

**AC-CUI-42** `Logic · BLOCKING`
GIVEN `attack_total=7 < difficulty=9` (RED), WHEN 2 свитка (+2) → `attack_total=9`, THEN → YELLOW; ещё +1 → `attack_total=10` → GREEN; live-обновление.

**AC-CUI-43** `Logic · BLOCKING`
GIVEN CHOICE_REROLL, «Оставить» нажата, THEN → CHOICE_BONUSES без ROLLING_ANIM; `dice_sum` из первичного броска в AttackBreakdown.

**AC-CUI-44** `UI · ADVISORY`
GIVEN `can_spend_hp_class=true, hp=1, scrolls.size()=0`, THEN SpendHPButton visible=true, disabled=true; текст «Нет доступных усилений»; только ConfirmButton активна.

**AC-CUI-45** `UI · ADVISORY`
GIVEN Воин, RerollBothButton нажата, THEN disabled=true немедленно; badge ⚠ «Результат обязателен» был виден до нажатия.

**AC-CUI-46** `UI · ADVISORY`
GIVEN Воительница перебросила, `new_value == old_value`, THEN rolling анимация 0.3с запускается в любом случае; не пропускается.

**AC-CUI-47** `UI · ADVISORY`
GIVEN 3 свитка использованы, THEN все 3 ScrollButton disabled с меткой «Использован» (не просто серый).

**AC-CUI-48** `UI · ADVISORY`
GIVEN RESOLVING_ANIM, `combat_resolved` ещё не пришёл, THEN нейтральная анимация сравнения; финальный цвет применён только после `combat_resolved`.

**AC-CUI-49** `Logic · BLOCKING`
GIVEN CHOICE_BONUSES, WHEN `combat_resolved` получен (баг CombatSystem), THEN → RESOLVING_ANIM принудительно; `push_error` в лог; UI не зависает.

## Open Questions

| # | Вопрос | Владелец | Блокирует |
|---|--------|----------|-----------|
| OQ-CUI-01 | Точная структура `available_actions: Dictionary` — поля, типы, все ли флаги передаются? CombatSystem GDD должен задокументировать контракт до реализации. | CombatSystem retrofit | Реализация CombatUI |
| OQ-CUI-02 | `hp` в `available_actions` — передаётся из CombatSystem или CombatUI читает напрямую из PlayerState? | CombatSystem GDD | Инициализация CombatUI |
| OQ-CUI-03 | `wins_on_draw` в `available_actions` — кто его туда кладёт? ClassSystem → CombatSystem → `available_actions`? | CombatSystem GDD | Формула 3 |
| OQ-CUI-04 | `auto_reroll_triggered` для MVP: если анимация авто-реролла P3 (nice-to-have), нужен ли сигнал в MVP или финальный `dice_state` достаточен для корректного отображения? | MVP scope | Core Rule 3 |
| OQ-CUI-05 | Шрифт — конкретный font-файл для CombatUI? Должен быть согласован с HUD при создании арт-библии. | Арт-библия | Разработка UI |
