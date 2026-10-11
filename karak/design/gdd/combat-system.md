# CombatSystem

> **Status**: Designed (pending /design-review)
> **Author**: game-designer + user
> **Last Updated**: 2026-10-10 (retrofitted I-06)
> **Implements Pillar**: Pillar 2 — «Сила ощутима», Pillar 4 — «Честная случайность»

## Overview

CombatSystem — разрешает столкновение игрока с монстром. Получает сигнал `combat_started(player, monster_data)` от EncounterDispatcher, проводит бросок кубика с учётом снаряжения и классовых способностей, сравнивает итог с `difficulty` монстра и определяет исход: победа или поражение.

При победе монстр удаляется с тайла (`TileSystem.clear_cell`), CombatSystem эмитирует `item_dropped(player, monster_data.id)` для всех монстров — LootSystem обрабатывает ключ по `monster_id == "SKELETON_KEY"` через таблицу дропа. WinCondition получает `dragon_killed` если `is_dragon`. При поражении игрок теряет 1 HP и возвращается на предыдущий тайл.

Для игрока CombatSystem — момент когда «сила ощутима» в прямом смысле: кубики падают, цифры складываются с бонусами от топора и свитка, итог сравнивается с числом монстра. Снаряжение не просто «число в инвентаре» — оно меняет вероятность победы прямо сейчас, в этом конкретном броске. Это сердце Pillar 2.

> **Design Decision — D-04 (Когнитивный бюджет боя)**: CombatSystem содержит до 4 последовательных фаз решений (auto-reroll → класс reroll → свиток → HP Чернокнижника), что создаёт 4–8 микрорешений за один бой для классов Воин и Чернокнижник. Это **намеренно**: игра проектируется для семейного hotseat — взрослый игрок управляет боевыми решениями, ребёнок 6+ участвует через броски кубиков и реакцию на результат. Pillar 3 («Просто войти»): ключевое правило «большее число побеждает» усваивается немедленно и доступно ребёнку. Дополнительные фазы (перебросок, свиток, HP) — взрослый слой глубины. Упрощение до одной фазы не планируется в MVP. (Resolved 2026-10-10)

## Player Fantasy

Бой — самый напряжённый момент в игре. Тайл перевёрнут, монстр виден, и теперь всё зависит от двух кубиков.

Игрок смотрит на число монстра — 9, Скелет-воин. Смотрит на свой топор — +3. Считает: нужно выбросить 6, чтобы выжить без дополнительных предметов. Это не бездумная случайность — это «Честная случайность» (Pillar 4): шанс понятен, риск осознан, и момент броска — это выбор принять этот риск.

Кубики падают. Пока они крутятся — ничего не ясно. Это длится секунду, но ощущается как несколько.

Результат. Победа — монстр исчезает, тайл расчищен, путь свободен. Ребёнок кричит «Я победил!» — потому что видит: его топор помог. Это Pillar 2 в действии: без снаряжения этот бой был бы проигран.

Поражение тоже честное — игрок получает удар, отступает, но понимает почему. Не «компьютер нечестный» — а «нужно найти лучшее оружие прежде чем атаковать Короля скелетов».

## Detailed Design

### Core Rules

1. **Триггер боя.** CombatSystem слушает сигнал `combat_started(player: PlayerState, monster_data: MonsterData)` от EncounterDispatcher. Каждый бой — атомарная операция: начинается и завершается до того, как любая другая система получает управление.

2. **Фаза броска.** CombatSystem вызывает `DiceSystem.roll(2, 6)` → получает `dice_state: Array[int]`.

3. **Авто-способности (до решения игрока).** Если `player.character_class.auto_reroll_on_one`: каждый кубик из `dice_state` со значением 1 перебрасывается немедленно через `DiceSystem.reroll_die(index, 6)`. Игрок не принимает решение — это автоматично. После каждого авто-переброска: `emit_signal("auto_reroll_triggered", die_index, new_value)` → CombatUI анимирует переброс.

4. **Добровольный перебросок класса (опционально).** После авто-перебросков CombatSystem переходит в состояние `PLAYER_CHOICE` и эмитирует:
   ```
   emit_signal("player_choice_requested", {
     "can_reroll": player.character_class.can_reroll_both_dice or can_reroll_one_die,
     "can_use_scroll": player.scrolls.any(...is MAGIC_ATTACK),
     "can_spend_hp": player.character_class.can_spend_hp_for_attack and player.hp > 1
   })
   ```
   CombatUI подписан на `player_choice_requested` и отображает доступные кнопки. Игрок получает возможность применить классовую способность:
   - **Воин** (`can_reroll_both_dice`): предложить перебросить оба кубика. Если игрок соглашается — `DiceSystem.roll(2, 6)`, второй результат обязателен.
   - **Воительница** (`can_reroll_one_die`): предложить переброс одного кубика. Игрок выбирает индекс → `DiceSystem.reroll_die(index, 6)`, второй результат обязателен.

5. **Применение свитка (опционально).** Если у игрока есть `scroll_magic_attack` в слоте: предложить использовать перед расчётом. Если используется: `scroll_bonus += scroll_magic_attack.combat_bonus` (= 1). `PlayerState.remove_scroll(scroll)` — вызывается для всех классов включая Волшебника (`magic_charge_no_discard` применяется **только** к scroll_teleport, не к scroll_magic_attack). Игрок может использовать несколько свитков последовательно.

6. **Применение HP Чернокнижника (опционально).** После броска, если `player.character_class.can_spend_hp_for_attack` и `player.hp > 1`: предложить потратить 1 HP для +1 к броску. Если соглашается: `hp_bonus = 1`, `PlayerState.take_damage(1)`. Если `player.hp == 1`: опция недоступна (нельзя нокаутировать себя до исхода боя).

7. **Расчёт итога атаки.**

   ```
   dice_sum       = sum(DiceSystem.get_dice_state())
   attack_total   = dice_sum
                  + player.get_attack_bonus()       ← sum оружий из PlayerState
                  + scroll_bonus                    ← из шага 5
                  + hp_bonus                        ← из шага 6
                  + first_step_bonus                ← player.character_class.first_step_combat_bonus, если бой на первом шаге хода
   ```

8. **Разрешение боя.**

   | Условие | Исход | Эффект |
   |---------|-------|--------|
   | `attack_total > difficulty` | Победа | Rule 9 |
   | `attack_total == difficulty` | Ничья → Поражение без урона | Rule 10b |
   | `attack_total < difficulty` | Поражение с уроном | Rule 10a |
   | `attack_total == difficulty` + Разбойница (`wins_on_draw`) | Победа | Rule 9 |

9. **При победе:**
   - `TileSystem.clear_cell(pos)` — монстр убран
   - Если `monster_data.vp_on_kill > 0` **и не** `monster_data.is_dragon`: `PlayerState.add_vp(monster_data.vp_on_kill)` — VP за Дракона выдаёт WinCondition (не CombatSystem), чтобы избежать двойного начисления
   - Если `monster_data.is_dragon`: `emit_signal("dragon_killed", player)` → WinCondition
   - Мечник (`can_continue_turn_on_six`): если хотя бы один кубик в финальном `dice_state` == 6 → `TurnManager.add_step(1)` + `emit_signal("combat_resolved", true, true)` — TurnManager получает `six_rolled=true` и НЕ завершает ход
   - Иначе: `emit_signal("combat_resolved", true, false)` — TurnManager переходит в AWAITING_LOOT
   - **Последним**: `emit_signal("item_dropped", player, monster_data.id)` → LootSystem проверяет таблицу дропа → `item_acquired(player, item_or_null)` → TurnManager (в AWAITING_LOOT) получает сигнал и завершает ход

   > **Порядок гарантии**: `combat_resolved` должен эмитироваться **до** `item_dropped`. GDScript-сигналы синхронны — если `item_dropped` идёт первым, `item_acquired` прилетит пока TurnManager ещё в AWAITING_COMBAT и будет проигнорирован (deadlock). При Мечнике с six_rolled=true TurnManager в TURN_ACTIVE получает `item_acquired` — PlayerState принимает предмет, TurnManager игнорирует сигнал, ход продолжается.

10. **При поражении и ничье:**
    - **10a — поражение** (`attack_total < difficulty`):
      1. `PlayerState.take_damage(1)` — синхронный сигнал `knocked_out` может немедленно вызвать KnockoutSystem, который телепортирует Воина на стартовый тайл
      2. Проверить: если `player.is_knocked_out() == true` — **пропустить** `retreat()` (KnockoutSystem уже установил позицию)
      3. Если НЕ в нокауте: `PlayerState.retreat()` — вернуть на предыдущую клетку
      4. `emit_signal("combat_resolved", false, false)` — TurnManager получает и завершает ход
    - **10b — ничья** (`attack_total == difficulty`, не Разбойница): урон НЕ наносится → `PlayerState.retreat()` → `emit_signal("combat_resolved", false, false)` — TurnManager получает и завершает ход

### States and Transitions

| Состояние | Описание |
|-----------|----------|
| `IDLE` | Ожидание сигнала от EncounterDispatcher |
| `ROLLING` | Бросок кубика + авто-перебросок (авто-способности) |
| `PLAYER_CHOICE` | Опциональные действия игрока: перебросок, свиток, HP Чернокнижника |
| `RESOLVING` | Расчёт `attack_total`, сравнение с `difficulty` |
| `WIN` | Обработка победы: clear_cell, VP, drop, is_dragon, Мечник |
| `LOSS` | Обработка поражения или ничьей: retreat, `combat_resolved(false, false)` |

```
IDLE → ROLLING → PLAYER_CHOICE → RESOLVING → WIN → IDLE
                                           → LOSS → IDLE
```

CombatSystem возвращается в `IDLE` после каждого боя.

### Interactions with Other Systems

| Система | Направление | Что передаётся |
|---------|-------------|----------------|
| EncounterDispatcher | upstream | `combat_started(player, monster_data)` — триггер |
| DiceSystem | вызывает | `roll(2,6)`, `reroll_die(i,6)`, `get_dice_state()` |
| PlayerState | читает/вызывает | `get_attack_bonus()`, `get_hp()`, `take_damage(1)`, `retreat()`, `remove_scroll()` |
| TileSystem | вызывает | `clear_cell(pos)` при победе |
| TurnManager | сигнал | `combat_resolved(won: bool, six_rolled: bool)` — TurnManager слушает и завершает ход; `add_step(1)` вызывается для Мечника при шестёрке до сигнала |
| LootSystem | сигнал | `item_dropped(player, monster_id)` — всегда при победе; LootSystem проверяет drop table |
| WinCondition | сигнал | `dragon_killed(player)` если `is_dragon` |
| CombatUI | сигнал | `combat_started`, `dice_rolled`, `combat_resolved(result)`, `auto_reroll_triggered(die_index, new_value)`, `player_choice_requested(available_actions)` |
| InventoryUI | сигнал | `combat_started` — принудительное закрытие панели инвентаря |

## Formulas

### Формула 1: Итог атаки

```
attack_total = dice_sum + attack_bonus + scroll_bonus + hp_bonus + first_step_bonus
```

**Переменные:**

| Переменная | Символ | Тип | Диапазон | Описание |
|------------|--------|-----|----------|----------|
| Сумма кубиков | `dice_sum` | int | 2–12 | `sum(DiceSystem.get_dice_state())` после всех перебросков |
| Бонус оружий | `attack_bonus` | int | 0–6 | `PlayerState.get_attack_bonus()` — сумма `combat_bonus` экипированных оружий (макс. 2 топора: 3+3=6) |
| Бонус свитков | `scroll_bonus` | int | 0–3 | Сумма `combat_bonus` использованных свитков `MAGIC_ATTACK` (макс. 3 свитка × 1 = 3) |
| Бонус HP Чернокнижника | `hp_bonus` | int | 0–1 | 1 если игрок потратил 1 HP; 0 иначе |
| Бонус первого шага Оракула | `first_step_bonus` | int | 0–1 | `first_step_combat_bonus` из ClassSystem; 1 только для Оракула и только на первом шаге хода |
| **Итог атаки** | `attack_total` | int | **2–23** | Финальное значение для сравнения с `difficulty` |

**Выходной диапазон:**
- Минимум: 2 (кубики 1+1, нет снаряжения)
- Максимум: 23 (кубики 12 + 2 топора 6 + 3 свитка 3 + hp_bonus 1 + first_step_bonus 1 = 23; теоретический максимум — ни один класс не может получить hp_bonus И first_step_bonus одновременно; практический максимум для любого класса = 22)
- Для победы над Драконом (`difficulty=15`): достаточно `attack_total >= 16`

**Пример:** dice_sum=7, топор(+3), нет свитков, не Чернокнижник, не Оракул → `attack_total = 7+3 = 10`. Против Скелета-воина (difficulty=9): 10 > 9 → победа.

---

### Формула 2: Условие исхода

```
result = WIN    если attack_total > difficulty
result = DRAW   если attack_total == difficulty
result = LOSS   если attack_total < difficulty

# Для Разбойницы (wins_on_draw = true):
result = WIN    если attack_total >= difficulty
```

**Пример вероятностей (без снаряжения, attack_bonus=0):**

| Монстр | difficulty | P(WIN) | P(DRAW) | P(LOSS) |
|--------|-----------|--------|---------|---------|
| Крыса | 5 | 83% | 3% | 14% |
| Паук | 6 | 72% | 6% | 22% |
| Мумия | 7 | 58% | 8% | 34% |
| Скелет-ключник | 8 | 42% | 8% | 50% |
| Скелет-воин | 9 | 28% | 8% | 64% |
| Король скелетов | 10 | 17% | 6% | 77% |
| Призрак | 12 | 3% | 3% | 94% |
| Дракон | 15 | **0%** | **0%** | **100%** |

> Победа над Драконом без снаряжения физически невозможна: max `dice_sum = 12 < 15`.

## Edge Cases

**EC-01: Воин перебросил — второй результат хуже.**
Перебросок добровольный, но второй результат обязателен. Если Воин решил перебросить и получил хуже — он обязан использовать второй результат. CombatSystem не позволяет отменить перебросок.

**EC-02: Мечник выбросил 1 на кубике — auto_reroll_on_one.**
`DiceSystem.reroll_die(index, 6)` повторяется для каждого кубика с 1 до тех пор, пока на нём больше не выпадает 1. Если кубик снова даёт 1 — перебрасывается снова. Оба кубика проверяются независимо; каждый перебрасывается столько раз, сколько нужно.

**EC-03: Мечник выбросил 6 — но проиграл бой.**
`can_continue_turn_on_six` проверяется только при победе (Rule 9). При поражении или ничье — флаг игнорируется, ход заканчивается обычно.

**EC-04: Чернокнижник тратит HP при hp=2 — поражение снижает ещё на 1.**
Чернокнижник потратил 1 HP → hp=1. Затем `attack_total < difficulty` → `PlayerState.take_damage(1)` → hp=0 → нокаут. Порядок: hp_bonus применяется до разрешения боя; take_damage при поражении — после.

**EC-05: Волшебник использует scroll_magic_attack — свиток ТРАТИТСЯ.**
`magic_charge_no_discard` применяется **только** к scroll_teleport (пространственная магия), но **не** к scroll_magic_attack (боевой заряд). `remove_scroll()` для scroll_magic_attack вызывается нормально для всех классов включая Волшебника. Уникальное преимущество Волшебника — scroll_teleport не расходуется (бесконечная телепортация) + `can_pass_through_walls` (мобильность).

**EC-06: Оракул — first_step_combat_bonus.**
Бонус +1 применяется если бой начался на первом шаге хода, то есть первым действием хода стало вытягивание тайла с монстром. `first_step_bonus = 1` если `TurnManager.steps_taken == 1` при получении сигнала `combat_started`.

Примечание: `TurnManager.spend_step()` вызывается **до** `combat_started` (MovementSystem Rule 2: spend_step → set_position → cell_entered → combat_started). Поэтому к моменту получения `combat_started` `steps_taken` уже равно 1 для первого шага. Проверять `steps_taken == 1`, а не `== 0`.

**EC-07: attack_total == difficulty — Разбойница.**
`wins_on_draw = true` → ничья считается победой. Rule 9 применяется полностью: `TileSystem.clear_cell`, `item_dropped(player, monster_data.id)`, `dragon_killed` если `is_dragon`.

**EC-08: attack_total == difficulty — не Разбойница.**
Ничья. Урон НЕ наносится. `retreat()` + `emit_signal("combat_resolved", false, false)`. Игрок может вернуться на этот тайл и попробовать снова.

**EC-09: Несколько свитков `MAGIC_ATTACK` в бою.**
Каждый свиток предлагается последовательно. Игрок может использовать 1, 2 или все 3. Каждый использованный тратится для всех классов включая Волшебника (scroll_magic_attack не подпадает под `magic_charge_no_discard`). `scroll_bonus` суммируется.

**EC-10: Дракон победой заканчивает партию.**
`is_dragon = true` → `emit_signal("dragon_killed", player)`. WinCondition обрабатывает завершение. CombatSystem не знает о конце игры — это зона WinCondition.

## Dependencies

### Upstream (CombatSystem зависит от)

| Система | Что использует |
|---------|----------------|
| **EncounterDispatcher** | Сигнал `combat_started(player, monster_data)` — триггер боя |
| **DiceSystem** | `roll(2,6)`, `reroll_die(index,6)`, `get_dice_state()` |
| **PlayerState** | `get_attack_bonus()`, `get_hp()`, `take_damage(1)`, `retreat()`, `remove_scroll(scroll)`, `character_class` |
| **MonsterDatabase** | `monster_data.difficulty`, `monster_data.drops_key`, `monster_data.is_dragon`, `monster_data.vp_on_kill` |
| **ItemDatabase** | `scroll.combat_bonus`, `scroll.is_consumable`, `class.magic_charge_no_discard` |
| **ClassSystem** | `can_reroll_both_dice`, `wins_on_draw`, `can_spend_hp_for_attack`, `auto_reroll_on_one`, `can_continue_turn_on_six`, `can_reroll_one_die`, `first_step_combat_bonus`, `magic_charge_no_discard` |
| **TurnManager** | Читает `steps_taken` (для Оракула); вызывает `add_step(1)` для Мечника; слушает `combat_resolved(won, six_rolled)` |
| **TileSystem** | `clear_cell(pos)` при победе |

### Downstream (зависит от CombatSystem)

| Система | Что ожидает |
|---------|-------------|
| **CombatUI** | Сигналы `combat_started`, `dice_rolled`, `combat_resolved(result)`, `auto_reroll_triggered(die_index, new_value)`, `player_choice_requested(available_actions: Dictionary)` |
| **LootSystem** | Сигнал `item_dropped(player, monster_id)` — при каждой победе; LootSystem проверяет drop table по monster_id |
| **WinCondition** | Сигнал `dragon_killed(player)` — если `is_dragon` |
| **InventoryUI** | Сигнал `combat_started` — принудительное закрытие панели инвентаря при начале боя |

### Обратные ссылки

- **DiceSystem GDD**: упоминает CombatSystem как единственного потребителя `roll()` и `reroll_die()` ✓
- **MonsterDatabase GDD**: упоминает CombatSystem как читателя `difficulty` ✓
- **PlayerState GDD**: упоминает CombatSystem как вызывателя `take_damage`, `retreat`, `remove_scroll` ✓
- **ClassSystem GDD**: упоминает CombatSystem как читателя 8 флагов ✓

## Tuning Knobs

| Параметр | Значение | Безопасный диапазон | Влияние |
|----------|----------|---------------------|---------|
| `DICE_COUNT` | 2 | 1–2 | Количество кубиков; 1 кубик = меньший разброс, менее интересные перебросы классов |
| `DICE_SIDES` | 6 | 4–8 | Граней на кубике; изменение смещает все вероятности, требует пересмотра всей таблицы сложностей |
| `HP_LOSS_ON_DEFEAT` | 1 | 1–2 | Урон при поражении в бою; >1 делает бой более рискованным, нокаут приходит быстрее |
| `HP_LOSS_ON_DRAW` | 0 | 0–1 | Урон при ничье; 0 = ничья мягкая (можно повторить попытку), 1 = ничья как поражение |
| `SWORDSMAN_TURN_BONUS` | +1 шаг | +1 | Бонус Мечника при 6; увеличение делает Мечника сильнее, но усложняет баланс |
| `ORACLE_FIRST_STEP_BONUS` | 1 | 0–2 | Бонус Оракула на первом шаге; 0 = убрать особенность; >1 = очень сильная агрессивная стратегия |
| `WARLOCK_HP_COST` | 1 | 1 | HP за +1 атаки у Чернокнижника; не менять — иначе сломается баланс способности |

> Изменение `DICE_COUNT` или `DICE_SIDES` требует пересчёта всей таблицы вероятностей в Формуле 2 и пересмотра значений `difficulty` в MonsterDatabase.

## Visual/Audio Requirements

CombatSystem эмитирует сигналы — визуальное оформление делегируется CombatUI и TileRevealVFX:
- `combat_started` → CombatUI показывает монстра и интерфейс боя
- `dice_rolled(dice_state)` → CombatUI анимирует кубики (DiceSystem также эмитирует `dice_rolled`)
- `combat_resolved(WIN/DRAW/LOSS)` → CombatUI показывает результат; TileRevealVFX убирает монстра при победе

CombatSystem сам не производит визуальных или аудио-эффектов.

## UI Requirements

- **Фаза броска**: показать кубики и их значения
- **Перебросок Воина / Воительницы**: кнопка «Перебросить» / «Оставить»
- **Выбор кубика Воительницы**: тап/клик на конкретный кубик
- **Свиток MAGIC_ATTACK**: кнопка «Использовать свиток»; показать текущий `scroll_bonus`
- **HP Чернокнижника**: кнопка «Потратить 1 HP (+1 к броску)»; показать предупреждение если hp=2
- **Итог**: показать `attack_total` vs `difficulty` явно — игрок должен понять результат без объяснений (Pillar 4)
- Реализация — в CombatUI GDD

## Acceptance Criteria

**AC-01:** `attack_total > difficulty` → сигнал `combat_resolved(WIN)` эмитирован, `TileSystem.clear_cell(pos)` вызван.

**AC-02:** `attack_total < difficulty` → `PlayerState.take_damage(1)` вызван, `PlayerState.retreat()` вызван (или пропущен если `is_knocked_out()==true`), `combat_resolved(false, false)` эмитирован. (Resolved B-13 2026-10-10)

**AC-03:** `attack_total == difficulty`, не Разбойница → `take_damage` НЕ вызван, `retreat()` вызван, `combat_resolved(false, false)` эмитирован. (Resolved B-13 2026-10-10)

**AC-04:** `attack_total == difficulty`, Разбойница (`wins_on_draw=true`) → исход WIN, `clear_cell` вызван.

**AC-05:** Воин применяет перебросок → `DiceSystem.roll(2,6)` вызван второй раз; финальный `attack_total` использует второй результат.

**AC-06:** Воин отказывается от перебросока → второй `DiceSystem.roll` не вызван; финальный `attack_total` использует первый результат.

**AC-07:** Мечник выбросил `[1, 3]` → `DiceSystem.reroll_die(0, 6)` вызван; если новый результат снова 1 — вызван повторно до тех пор, пока не выпадет не-1.

**AC-08:** Мечник победил с 6 в `dice_state` → `TurnManager.add_step(1)` вызван; `combat_resolved(true, true)` эмитирован; TurnManager ход НЕ завершает. (Resolved B-13 2026-10-10)

**AC-09:** Мечник победил без 6 в `dice_state` → `TurnManager.add_step(1)` не вызван; `combat_resolved(true, false)` эмитирован; TurnManager ход завершает. (Resolved B-13 2026-10-10)

**AC-10:** Свиток `scroll_magic_attack` использован → `scroll_bonus = 1` добавлен к `attack_total`; `PlayerState.remove_scroll()` вызван для всех классов включая Волшебника.

**AC-11:** Волшебник использует `scroll_magic_attack` → `remove_scroll()` вызван; свиток расходуется. Волшебник использует `scroll_teleport` (вне боя, через EncounterDispatcher) → `remove_scroll()` НЕ вызван; свиток остаётся в слоте.

**AC-12:** Чернокнижник тратит 1 HP → `PlayerState.take_damage(1)` вызван ДО вычисления финального `attack_total`; `hp_bonus = 1` включён в `attack_total`.

**AC-13:** Чернокнижник при `hp=1` → опция траты HP недоступна.

**AC-14:** Оракул, бой на первом шаге хода (`steps_taken==1`) → `first_step_bonus = 1` включён в `attack_total`.

**AC-15:** Оракул, бой не на первом шаге (`steps_taken > 1`) → `first_step_bonus = 0`.

**AC-16:** `monster_data.id = &"skeleton_key"`, победа → сигнал `item_dropped(player, &"skeleton_key")` эмитирован; LootSystem обрабатывает ключ через таблицу дропа. Отдельного `key_dropped` нет. (Resolved B-02 2026-10-10)

**AC-17:** `monster_data.is_dragon = true`, победа → сигнал `dragon_killed(player)` эмитирован.

**AC-18:** Бой завершён (любой исход) → CombatSystem возвращается в состояние `IDLE`; следующий `combat_started` обрабатывается корректно.

**AC-19 — item_dropped при победе.**
GIVEN победа над любым монстром (monster_id="goblin")
WHEN `attack_total > difficulty`
THEN сигнал `item_dropped(player, "goblin")` эмитирован; LootSystem получает его.

**AC-20 — auto_reroll_triggered при авто-перебросе.**
GIVEN Мечник, `dice_state = [1, 4]`
WHEN `DiceSystem.reroll_die(0, 6)` вызван автоматически
THEN сигнал `auto_reroll_triggered(0, new_value)` эмитирован с корректным `new_value`.

**AC-21 — player_choice_requested с корректными флагами.**
GIVEN Чернокнижник с hp=3 и scroll_magic_attack в слоте
WHEN авто-способности завершены
THEN сигнал `player_choice_requested({"can_reroll": false, "can_use_scroll": true, "can_spend_hp": true})` эмитирован.

**AC-22 — Warrior в нокауте не делает retreat.**
GIVEN Воин, hp=1, position=B, previous_position=A
WHEN `take_damage(1)` → нокаут → KnockoutSystem телепортирует на start_tile=S
THEN `retreat()` не вызван; `get_position() == S` (не A).

## Open Questions

**OQ-01: VP хранятся в PlayerState или WinCondition?** — ~~RESOLVED~~ (2026-10-09)
PlayerState retrofit добавил `vp: float` и `add_vp(amount: float)`. CombatSystem вызывает `PlayerState.add_vp(monster_data.vp_on_kill)` при победе над монстром с vp_on_kill > 0.

**OQ-02: Порядок применения опциональных действий (шаги 4-6).**
Текущий порядок: перебросок → свиток → HP Чернокнижника. Может ли Чернокнижник сначала использовать свиток, а потом решить про HP? Или порядок фиксирован? Пока порядок зафиксирован в Detailed Design — уточнить при проектировании CombatUI.

**OQ-03: `steps_taken` в TurnManager.** — ~~RESOLVED~~ (2026-10-09 — TurnManager retrofit)
TurnManager retrofit добавит поле `steps_taken: int` и метод `add_step(n: int)`. CombatSystem читает `TurnManager.steps_taken` для `first_step_bonus` Оракула.

**OQ-04: Сигнал `dice_rolled` — от DiceSystem или CombatSystem?**
DiceSystem OQ-03 предполагает сигнал `dice_rolled(dice_state)` из DiceSystem. Если DiceSystem его эмитирует — CombatSystem не должен дублировать. Согласовать при проектировании CombatUI.
