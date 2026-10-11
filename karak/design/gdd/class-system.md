# ClassSystem

> **Status**: Designed (pending /design-review)
> **Author**: game-designer + user
> **Last Updated**: 2026-10-07
> **Implements Pillar**: Pillar 2 — «Сила ощутима» (классы определяют стартовый профиль героя)

## Overview

ClassSystem — база данных семи классов героев и единственный источник правды о том, чем одни герои отличаются от других. Каждый класс содержит идентификатор, имя, базовые параметры (`max_hp`) и набор флагов способностей — булевых значений и числовых модификаторов, которые другие системы проверяют в нужный момент.

ClassSystem не управляет логикой игры напрямую. Она поставляет данные — CombatSystem, MovementSystem, KnockoutSystem и DungeonGenerator сами читают `player.character_class` и применяют класс-специфичное поведение. Это сохраняет ClassSystem на уровне Foundation: только данные, без игровой логики.

`HeroClass` — тип данных (ресурс/объект), который ClassSystem определяет и предоставляет PlayerState. В MVP: 7 классов, у каждого уникальная комбинация из 1–2 пассивных способностей.

Для игрока: ClassSystem — это *почему мой герой играется иначе*. Воин перебрасывает оба кубика в бою и не теряет ход после нокаута. Разбойница побеждает при ничье и обходит монстров. Волшебник не тратит «Магический заряд» и ходит сквозь стены. Каждый выбор класса — это обещание уникального стиля игры на всю партию.

## Player Fantasy

Перед первым ходом каждый игрок видит несколько карточек героев и выбирает одну. Это единственное решение, которое принимается *до* того, как подземелье открылось — и оно определяет, кем ты будешь всю партию.

Момент выбора класса — маленькая самоидентификация: «Я возьму Разбойницу» не означает просто «+1 в бою при ничье». Это значит «я буду агрессивным, я пройду мимо слабых монстров и подберусь к дракону раньше». Способности класса — это не бонусы, это стиль игры.

Ребёнок выбирает Воина потому что «он дерётся лучше всех». Взрослый выбирает Чернокнижника потому что хочет поменяться местами с соперником в критический момент. Оба правы — ClassSystem не делает один выбор оптимальным.

На протяжении партии класс остаётся молчаливым напоминанием о своём обещании: когда Воин перебросил оба кубика и выиграл бой, который должен был проиграть — это не удача, это его особенность.

## Detailed Design

### Core Rules

1. `HeroClass` — это Godot `Resource`. Каждый из 7 классов — это отдельный `.tres` файл с полями `@export`. Логики нет — только данные.
2. `ClassRegistry` — Autoload, хранящий ссылки на все 7 ресурсов `HeroClass`. Инициализируется при старте игры.
3. **Выбор класса**: перед первым ходом каждому игроку предлагается N случайных классов (из не занятых другими игроками). Игрок выбирает один. `PlayerState.character_class` устанавливается один раз и неизменен до конца партии.
4. **Класс — только чтение**: после выбора все системы обращаются к `player.character_class.[flag]` для проверки способностей. ClassSystem не вызывает методы других систем.
5. Все `max_hp = 5`. Нет классов с разным базовым HP.

### Структура HeroClass Resource

```gdscript
class_name HeroClass
extends Resource

@export var id: StringName               # &"warrior", &"rogue", ...
@export var display_name: String         # "Воин", "Разбойница", ...
@export var max_hp: int = 5

# === COMBAT (читает CombatSystem) ===
@export var can_reroll_both_dice: bool = false      # Воин — перебросить оба; использовать второй бросок
@export var wins_on_draw: bool = false               # Разбойница — победа при ничье
@export var can_spend_hp_for_attack: bool = false    # Чернокнижник — 1 HP → +1 к силе (опционально)
@export var auto_reroll_on_one: bool = false         # Мечник — автоперебросить любой кубик с 1
@export var can_continue_turn_on_six: bool = false   # Мечник — при 6 на кубике продолжить ход
@export var can_reroll_one_die: bool = false         # Воительница — переброс одного кубика; второй результат
@export var first_step_combat_bonus: int = 0         # Оракул — +1 если бой на первом шаге

# === KNOCKOUT (читает KnockoutSystem) ===
@export var knockout_teleport_to_start: bool = false # Воин — перемещение к фонтану вместо стандартного нокаута
@export var knockout_no_turn_skip: bool = false      # Воин — не пропускать ход
@export var knockout_full_heal: bool = false         # Воин — восстановить весь HP

# === MOVEMENT (читает MovementSystem) ===
@export var can_bypass_monster_free: bool = false    # Разбойница — обойти монстра без штрафа
@export var can_bypass_monster_cost: bool = false    # Воительница — обойти монстра: -1 шаг, -1 HP
@export var can_pass_through_walls: bool = false     # Волшебник — проходить сквозь стены
@export var can_swap_positions: bool = false         # Чернокнижник — обменяться позицией: -4 шага

# === TILE/DUNGEON (читает EncounterDispatcher) ===
@export var choose_encounter_from_two: bool = false  # Оракул — выбрать из 2 случайных вариантов на тайле

# === ITEMS (читает CombatSystem/LootSystem) ===
@export var magic_charge_no_discard: bool = false    # Волшебник — не тратить scroll_teleport (только! не scroll_magic_attack)
```

### Таблица классов

| Класс | Способность 1 | Способность 2 |
|-------|--------------|--------------|
| **Воин** | `can_reroll_both_dice` — перебросить оба кубика в бою (обязателен второй результат) | `knockout_teleport_to_start` + `knockout_no_turn_skip` + `knockout_full_heal` |
| **Разбойница** | `wins_on_draw` — победа при ничье | `can_bypass_monster_free` — обойти монстра без боя и штрафа |
| **Волшебник** | `magic_charge_no_discard` — scroll_teleport не тратится (бесконечная телепортация); scroll_magic_attack расходуется нормально | `can_pass_through_walls` — движение сквозь стены |
| **Чернокнижник** | `can_spend_hp_for_attack` — опционально: -1 HP → +1 к силе | `can_swap_positions` — обменяться позицией с героем: -4 шага |
| **Мечник** | `auto_reroll_on_one` — автоматически перебросить каждый кубик с 1 | `can_continue_turn_on_six` — при 6 на кубике продолжить ход |
| **Оракул** | `first_step_combat_bonus = 1` — +1 к силе, если бой на первом шаге | `choose_encounter_from_two` — выбор из 2 случайных вариантов на тайле |
| **Воительница** | `can_reroll_one_die` — переброс одного кубика (обязателен второй результат) | `can_bypass_monster_cost` — обойти монстра: -1 шаг, -1 HP |

### States and Transitions

ClassSystem не имеет состояний — данные статичны. Состояние есть у **выбора класса в PlayerState**:

| Состояние | Условие |
|-----------|---------|
| `UNSELECTED` | `player.character_class == null` — до выбора в начале партии |
| `SELECTED` | `player.character_class != null` — после выбора, неизменно до конца |

`SELECTED` — терминальное состояние на время партии.

### Interactions with Other Systems

| Система | Что читает из ClassSystem |
|---------|--------------------------|
| **CombatSystem** | `can_reroll_both_dice`, `wins_on_draw`, `can_spend_hp_for_attack`, `auto_reroll_on_one`, `can_continue_turn_on_six`, `can_reroll_one_die`, `first_step_combat_bonus`, `magic_charge_no_discard` |
| **KnockoutSystem** | `knockout_teleport_to_start`, `knockout_no_turn_skip`, `knockout_full_heal` |
| **MovementSystem** | `can_bypass_monster_free`, `can_bypass_monster_cost`, `can_pass_through_walls`, `can_swap_positions` |
| **EncounterDispatcher** | `choose_encounter_from_two` |
| **PlayerState** | `max_hp` при инициализации |

## Formulas

### Формула 1: Выбор классов для предложения

```
offered_classes = random_sample(available_classes, N)
available_classes = all_classes − already_selected_by_other_players
```

| Переменная | Тип | Диапазон | Описание |
|-----------|-----|----------|----------|
| `N` | `int` | 2–4 | Количество классов, предлагаемых одному игроку |
| `all_classes` | `Array[HeroClass]` | 7 | Все 7 классов |
| `available_classes` | `Array[HeroClass]` | 2–7 | Классы, не занятые ранее выбравшими игроками |
| `offered_classes` | `Array[HeroClass]` | N | Случайная выборка без повторений |

**Диапазон вывода:** всегда N классов (если доступных меньше N — предлагаются все доступные).

---

### Формула 2: Эффективная сила Оракула

```
effective_attack = dice_roll + attack_bonus + scroll_bonus + first_step_bonus
first_step_bonus = first_step_combat_bonus  если бой начался на первом шаге хода, иначе 0
```

*Применяется в CombatSystem. `first_step_combat_bonus = 1` для Оракула, `0` для всех остальных.*

---

### Формула 3: Стоимость обхода монстра (Воительница)

```
bypass_cost = 2 steps + 1 HP
remaining_steps = steps_remaining − 2
player_hp_after = player_hp − 1
```

*Если `steps_remaining < 2` или `player_hp == 1` (обход снизит HP до 0) — обход недоступен.*

---

### Формула 4: Стоимость смены позиций (Чернокнижник)

```
swap_cost = 4 steps
remaining_steps = steps_remaining − 4
```

*Если `steps_remaining < 4` — смена позиций недоступна.*

## Edge Cases

### Выбор класса

- **EC-01** — ЕСЛИ при выборе классов доступных меньше N: предлагаются все доступные (не ошибка).
- **EC-02** — ЕСЛИ все 7 классов заняты (8+ игроков): невозможная ситуация при ограничении в 5 игроков. assert если `player_count > 7`.
- **EC-03** — ЕСЛИ `character_class` уже установлен и вызывается повторная установка: `push_error`, класс не меняется. Перевыбор класса в середине партии недопустим.

### Способности Воина

- **EC-04** — ЕСЛИ Воин использует `can_reroll_both_dice`, второй бросок хуже первого: игрок обязан использовать второй результат — выбора нет.
- **EC-05** — ЕСЛИ Воин получает нокаут: `KnockoutSystem` применяет альтернативный путь — восстановление всего HP, телепортация на стартовый тайл, ход не пропускается. Игрок не переходит в состояние `KNOCKED_OUT`.

### Способности Разбойницы

- **EC-06** — ЕСЛИ Разбойница использует `can_bypass_monster_free` на тайле с Драконом: доступно — Дракон не является исключением, обход применим как к обычным монстрам, так и к боссу.

### Способности Чернокнижника

- **EC-07** — ЕСЛИ `can_spend_hp_for_attack` при `hp == 1`: трата HP снизит до 0 → нокаут. Система должна предупредить игрока. Если игрок подтверждает — нокаут происходит после боя (порядок: бой → результат → нокаут если hp=0).
- **EC-08** — ЕСЛИ `can_swap_positions` при `steps_remaining < 4`: действие недоступно. MovementSystem не разрешает его.
- **EC-09** — ЕСЛИ Чернокнижник меняется позицией с нокаутированным игроком: доступно — нокаутированный игрок перемещается. Его `skip_next_turn` не сбрасывается.

### Способности Мечника

- **EC-10** — ЕСЛИ `auto_reroll_on_one` при использовании двух кубиков: каждый кубик с 1 перебрасывается независимо. Если оба выпали 1 — оба перебрасываются.
- **EC-11** — ЕСЛИ `can_continue_turn_on_six` и бой проигран: способность не активируется при проигрыше — только при победе с 6 на кубике.

### Способности Воительницы

- **EC-12** — ЕСЛИ `can_reroll_one_die` при одном кубике: применимо — игрок выбирает этот единственный кубик и перебрасывает его. Второй результат обязателен.
- **EC-13** — ЕСЛИ `can_bypass_monster_cost` при `hp == 1`: обход недоступен (станет 0 HP → нокаут без боя). MovementSystem блокирует.

### Способности Волшебника

- **EC-14** — ЕСЛИ `magic_charge_no_discard` и у Волшебника нет «Магического заряда»: флаг игнорируется, нет эффекта.
- **EC-15** — ЕСЛИ `can_pass_through_walls` и стены отсутствуют на карте: флаг не применяется, MovementSystem разрешает движение стандартно.

### Способности Оракула

- **EC-16** — ЕСЛИ `choose_encounter_from_two` и на тайле остался только один жетон события: предлагается один вариант. Это единственный случай когда Оракул не получает выбор — когда пул жетонов конкретного типа исчерпан до последнего.
- **EC-17** — ЕСЛИ `first_step_combat_bonus` и «первый шаг» не отслеживается MovementSystem: MovementSystem обязана передавать `is_first_step: bool` в CombatSystem. Это cross-system контракт.

## Dependencies

### Зависимости входящие (ClassSystem зависит от)

Нет. ClassSystem — Foundation layer без зависимостей. Все данные статичны и задаются при создании `.tres` файлов.

### Зависимости исходящие (зависят от ClassSystem)

| Система | Что берёт из ClassSystem | Статус |
|---------|--------------------------|--------|
| **PlayerState** | `HeroClass` тип; `max_hp` при инициализации | Спроектирована ✓ |
| **CombatSystem** | 8 флагов + `first_step_combat_bonus` | Спроектирована ✓ |
| **KnockoutSystem** | 3 флага нокаута Воина | Спроектирована ✓ |
| **MovementSystem** | 4 флага движения | Спроектирована ✓ |
| **EncounterDispatcher** | `choose_encounter_from_two` | Спроектирована ✓ |

### Provisional assumptions

- Количество предлагаемых классов `N` не определено — зависит от дизайна выбора героя (возможно, MainMenu или отдельный экран выбора). Пока `N = 3` как разумный дефолт.
- `ClassRegistry` как Autoload — реализационное решение, подлежит утверждению в ADR при проектировании архитектуры.

## Tuning Knobs

| Параметр | Текущее значение | Безопасный диапазон | Что ломается за пределами | Влияет на |
|----------|-----------------|---------------------|--------------------------|-----------|
| `CLASS_OFFER_COUNT` (N) | 3 | 2–5 | <2: выбор бессмысленный; >5: слишком долго читать способности перед началом игры (Pillar 3: «просто войти») | Ощущение выбора, темп старта партии |
| `WARLOCK_SWAP_COST` | 4 шага | 2–5 | <2: слишком дёшево, смена позиций становится имбой в endgame; >5: способность почти никогда не применима | Баланс Чернокнижника |
| `WARRIOR_KNOCKOUT_HEAL` | полный HP (= `max_hp`) | `max_hp` | Изменение меняет силу способности фундаментально — пересмотреть как отдельный дизайн-выбор | Ценность нокаута Воина |

*Все три параметра влияют на баланс между классами. Изменение любого требует playtest с актуальным числовым балансом монстров (CombatSystem GDD).*

## Visual/Audio Requirements

Нет специфичных требований на уровне ClassSystem — визуальное представление классов (иконки, карточки героев) относится к MainMenu / UI GDD.

## UI Requirements

Экран выбора класса — вне scope ClassSystem. ClassSystem поставляет данные; UI читает `display_name`, `id` и флаги для отображения способностей. Спецификация экрана — в MainMenu GDD.

## Acceptance Criteria

Все критерии — тип **Logic**. Gate: **BLOCKING**. Автотесты в `tests/unit/class_system/`.

---

**AC-01 — Инициализация ClassRegistry**
**GIVEN** игра запущена
**WHEN** ClassRegistry инициализирован
**THEN** `get_all_classes()` возвращает ровно 7 объектов `HeroClass`; у каждого уникальный `id`

**AC-02 — max_hp у всех классов**
**GIVEN** ClassRegistry загружен
**WHEN** проверяются все 7 классов
**THEN** у каждого `max_hp == 5`

**AC-03 — Уникальность флагов Воина**
**GIVEN** класс Воин загружен
**WHEN** проверяются флаги
**THEN** `can_reroll_both_dice == true`, `knockout_teleport_to_start == true`, `knockout_no_turn_skip == true`, `knockout_full_heal == true`; у всех остальных 6 классов эти флаги == false

**AC-04 — Уникальность флагов Разбойницы**
**GIVEN** класс Разбойница загружен
**WHEN** проверяются флаги
**THEN** `wins_on_draw == true`, `can_bypass_monster_free == true`; у других классов == false

**AC-05 — Уникальность флагов Волшебника**
**GIVEN** класс Волшебник загружен
**WHEN** проверяются флаги
**THEN** `magic_charge_no_discard == true`, `can_pass_through_walls == true`; у других классов == false

**AC-06 — Уникальность флагов Чернокнижника**
**GIVEN** класс Чернокнижник загружен
**WHEN** проверяются флаги
**THEN** `can_spend_hp_for_attack == true`, `can_swap_positions == true`; у других классов == false

**AC-07 — Уникальность флагов Мечника**
**GIVEN** класс Мечник загружен
**WHEN** проверяются флаги
**THEN** `auto_reroll_on_one == true`, `can_continue_turn_on_six == true`; у других классов == false

**AC-08 — Уникальность флагов Оракула**
**GIVEN** класс Оракул загружен
**WHEN** проверяются флаги
**THEN** `first_step_combat_bonus == 1`, `choose_encounter_from_two == true`; у других классов `first_step_combat_bonus == 0`

**AC-09 — Уникальность флагов Воительницы**
**GIVEN** класс Воительница загружен
**WHEN** проверяются флаги
**THEN** `can_reroll_one_die == true`, `can_bypass_monster_cost == true`; у других классов == false

**AC-10 — Выбор класса — нет повторений**
**GIVEN** Игрок 1 выбрал класс X
**WHEN** Игрок 2 получает список предлагаемых классов
**THEN** класс X отсутствует в предложении

**AC-11 — Выбор класса — ровно N предложений**
**GIVEN** доступно ≥ N классов
**WHEN** формируется список предложений для игрока
**THEN** длина списка == `CLASS_OFFER_COUNT`

**AC-12 — Выбор класса — менее N доступных**
**GIVEN** доступно < N классов (поздние игроки в партии на 5 человек)
**WHEN** формируется список предложений
**THEN** предлагаются все доступные классы (длина < N, не ошибка)

**AC-13 — Повторная установка character_class**
**GIVEN** `player.character_class` уже установлен
**WHEN** попытка установить другой класс
**THEN** `push_error` вызван; `character_class` не изменился

**AC-14 — Неизменность данных HeroClass**
**GIVEN** `HeroClass` ресурс загружен
**WHEN** внешний код пытается изменить поле ресурса
**THEN** поле не изменяется (Resource — read-only в runtime)

## Open Questions

| # | Вопрос | Владелец | Блокирует |
|---|--------|----------|-----------|
| OQ-01 | `CLASS_OFFER_COUNT = 3` — provisional. Нужно ли показывать все 7 или ограниченный выбор? Ответит дизайн экрана выбора класса (возможно, MainMenu или отдельный экран) | MainMenu GDD | Formulas, UX |
| OQ-02 | **RESOLVED**: `magic_charge_no_discard` применяется только к `scroll_teleport` (пространственная магия — тематично для Волшебника). `scroll_magic_attack` расходуется нормально для всех классов. Это устраняет доминирующую стратегию (permanent +3 combat) и сохраняет уникальность Волшебника как специалиста по мобильности. | — | CLOSED |
| OQ-03 | `can_continue_turn_on_six` — что именно получает Мечник: дополнительный ход или право продолжить текущий ход (ещё один тайл)? Уточнить при проектировании CombatSystem | CombatSystem GDD | Поведение TurnManager |
| OQ-04 | `choose_encounter_from_two` для Оракула — случайные 2 варианта из какого пула? Из всех типов тайлов или только из типов, которые могут появиться на данной позиции? | EncounterDispatcher GDD | Реализация выборки |
| OQ-05 | `ClassRegistry` как Autoload — нужен ли отдельный ADR или достаточно упомянуть в Architecture GDD? | `/create-architecture` | Реализация |
