# PlayerState

> **Status**: Designed (pending /design-review)
> **Author**: game-designer + user
> **Last Updated**: 2026-10-10 (retrofitted H-01, I-01, I-02)
> **Implements Pillar**: Foundation — все 4 пиллара опираются на PlayerState

## Overview

PlayerState — центральное хранилище данных одного игрока. Содержит всё, что известно о герое в любой момент игры: текущее HP, список экипированных предметов (и суммарный бонус к атаке), позицию на доске, а также флаг живой/мёртвый. 8 из 17 MVP-систем читают или изменяют PlayerState — это данных-узкое место: если структура определена неверно, ломается всё выше.

Для игрока PlayerState невидим, но именно он делает возможным ощущение «мой герой становится сильнее» (Pillar 2: «Сила ощутима») и честность «я понимаю, почему проиграл» (Pillar 4: «Честная случайность»).

## Player Fantasy

PlayerState — честное зеркало: всегда показывает игроку, кто его герой прямо сейчас. Слабый в начале — и это видно. Сильный к финалу — и это заслуженно. Каждый найденный предмет, каждый полученный удар немедленно отражаются, и все решения принимаются на основе того, что видишь.

Игрок не гадает — он читает ситуацию. После проигранного боя смотрит на оставшееся HP и на сложность следующего монстра — и сам приходит к выводу «нет, сейчас не надо». Это не фрустрация, это информированный выбор. Именно поэтому PlayerState не должен прятать данные и не должен перегружать: если состояние нельзя прочитать за секунду — зеркало врёт.

## Detailed Design

### Core Rules

1. PlayerState хранит все персистентные данные одного героя на протяжении партии.
2. Инвентарь: **оружие** (2 слота), **ключ** (1 слот), **свитки** (3 слота).
3. `attack_bonus` — кэш суммы `attack_bonus` всех оружий. Пересчитывается при изменении оружейных слотов.
4. `set_position()` автоматически сохраняет текущую позицию в `previous_position` перед сменой.
5. При проигрыше боя CombatSystem вызывает `retreat()` — позиция возвращается к `previous_position`.
6. При поражении (roll + attack_bonus < difficulty) дополнительно вызывается `take_damage(1)`.
7. При `hp <= 0`: `hp` → 1, `skip_next_turn` → `true`. Позиция и инвентарь не меняются.
8. Победа: `has_killed_dragon = true` — терминальное состояние, не может быть отменено.

### States and Transitions

| Состояние | `skip_next_turn` | `has_killed_dragon` |
|-----------|------------------|---------------------|
| **ALIVE** | `false` | `false` |
| **KNOCKED OUT** | `true` | `false` |
| **WINNER** | `false` | `true` |

- `ALIVE` → `KNOCKED OUT`: `take_damage()` снижает HP до 0
- `KNOCKED OUT` → `ALIVE`: TurnManager пропускает ход, вызывает `clear_knockout()`
- `ALIVE` → `WINNER`: WinCondition вызывает `mark_dragon_killed()`

### Поля

```
player_id: int               # 1–5, номер игрока в партии
hp: int                      # 1–5 (0 невозможен в устойчивом состоянии)
max_hp: int                  # 5 по умолчанию; класс может изменить (provisional)
position: Vector2i           # текущий тайл на доске
previous_position: Vector2i  # тайл перед последним ходом (для retreat)
weapons: Array[ItemData]     # макс. 2
key: ItemData                # nullable — ключ от сундука
scrolls: Array[ItemData]     # макс. 3
chests_opened: int           # счётчик, 0+, неограниченный
vp: float                    # очки победы, 0.0+; накапливаются через add_vp()
attack_bonus: int            # кэш: sum(weapon.attack_bonus)
skip_next_turn: bool         # флаг нокаута
has_killed_dragon: bool      # флаг победы
character_class: HeroClass   # provisional (ClassSystem не спроектирована)
```

### Публичные методы

```gdscript
# Чтение
func get_attack_bonus() -> int
func get_position() -> Vector2i
func get_hp() -> int
func get_items_by_slot(slot: String) -> Array[ItemData]
func is_knocked_out() -> bool
func has_won() -> bool
var has_key: bool: get: return key != null     # геттер-свойство; true если ключ в слоте

# Мутации
func set_position(pos: Vector2i) -> void      # previous_position = position; position = pos
func retreat() -> void                         # position = previous_position
func take_damage(amount: int) -> void          # hp -= amount; если hp<=0 → нокаут
func heal_full() -> void                       # hp = max_hp; испускает hp_changed(max_hp, max_hp)
func add_vp(amount: float) -> void             # vp += amount; amount >= 0 (отрицательное → push_error); испускает vp_changed(vp)
func add_weapon(item: ItemData) -> bool        # false если оба слота заняты
func replace_weapon(old: ItemData, new: ItemData) -> void
func set_key(item: ItemData) -> void
func remove_key() -> void                      # key = null; испускает item_removed(key, "key")
func add_scroll(item: ItemData) -> bool        # false если все 3 слота заняты
func remove_scroll(item: ItemData) -> void
func replace_scroll(old: ItemData, new: ItemData) -> void
func increment_chests() -> void
func clear_knockout() -> void                  # сбрасывает skip_next_turn
func mark_dragon_killed() -> void

# Сигналы
signal hp_changed(new_hp: int, max_hp: int)
signal vp_changed(new_vp: float)
signal item_added(item: ItemData, slot_type: String)
signal item_removed(item: ItemData, slot_type: String)
signal knocked_out
signal knockout_cleared
```

### Interactions with Other Systems

| Система | Направление | Что передаётся |
|---------|-------------|----------------|
| ClassSystem | ← читает | `character_class`, `max_hp` (provisional) |
| TurnManager | ← подписан на сигнал | `knocked_out` → пропустить ход |
| CombatSystem | → читает/вызывает | `get_attack_bonus()`, `take_damage(1)`, `retreat()` |
| LootSystem | → вызывает | `add_weapon()`, `replace_weapon()`, `set_key()`, `add_scroll()`, `replace_scroll()`, `increment_chests()`, `add_vp(CHEST_VP)` |
| EncounterDispatcher | → читает/вызывает | `has_key` (проверка перед сундуком), `remove_key()` (после открытия), `heal_full()` (фонтан), `get_position()` |
| KnockoutSystem | → вызывает | `clear_knockout()`, `heal_full()` (Воин при нокауте) |
| WinCondition | → читает/вызывает | `vp` (сравнение при убийстве Дракона), `mark_dragon_killed()` |
| HUD | ← подписан на сигналы | `hp_changed`, `vp_changed`, `item_added`, `item_removed` |
| InventoryUI | ← подписан на сигналы | `item_added`, `item_removed` |

## Formulas

### Формула 1: `attack_bonus` (постоянный кэш, хранится в PlayerState)

```
attack_bonus = Σ weapon.attack_bonus  для всех weapon в weapons
```

| Переменная | Тип | Диапазон | Описание |
|-----------|-----|----------|----------|
| `weapon.attack_bonus` | `int` | 0–? | Бонус атаки одного оружия (определяется ItemDatabase) |
| `attack_bonus` | `int` | 0–? | Итоговый постоянный бонус; 0 если нет оружий |

**Диапазон вывода:** 0 (нет оружий) до `2 × max_weapon_bonus` (оба слота заполнены).
**Пример:** оружие +2 и оружие +1 → `attack_bonus = 3`

---

### Формула 2: `effective_attack` (только во время боя, НЕ хранится в PlayerState)

```
effective_attack = dice_roll + attack_bonus + scroll_bonus
```

| Переменная | Тип | Диапазон | Описание |
|-----------|-----|----------|----------|
| `dice_roll` | `int` | 1–6 | Бросок кубика (DiceSystem) |
| `attack_bonus` | `int` | 0–? | Постоянный бонус из PlayerState |
| `scroll_bonus` | `int` | 0–? | Бонус активированного свитка атаки; 0 если свиток не использован |

**Вычисляется CombatSystem** в момент боя — не кэшируется.
Если свиток активирован — CombatSystem вызывает `player_state.remove_scroll(scroll)` после расчёта.
Конкретные значения `weapon.attack_bonus` и `scroll_bonus` определяются в GDD ItemDatabase.

## Edge Cases

### HP и нокаут

- **EC-01** — ЕСЛИ `take_damage(0)` вызван: no-op, сигнал не испускается.
- **EC-02** — ЕСЛИ `take_damage(-1)` или любое отрицательное: `push_error`, HP не меняется. `take_damage` — не хил.
- **EC-03** — ЕСЛИ `clear_knockout()` вызван на живом игроке: no-op.

### Бой и отступление

- **EC-04** — ЕСЛИ `retreat()` вызван до первого хода (`previous_position` не инициализирована): возврат на стартовый тайл. Стартовый тайл задаётся явно при инициализации PlayerState — не `Vector2i(0,0)` по умолчанию.
- **EC-05** — ЕСЛИ `retreat()` вызван дважды без промежуточного `set_position()`: второй вызов возвращает на ту же позицию. `previous_position` не обновляется самим `retreat()`.
- **EC-06** — ЕСЛИ поражение в бою снижает HP до 0: порядок — сначала `take_damage(1)` (hp→1, `skip_next_turn=true`, сигнал `knocked_out`). CombatSystem Rule 10a проверяет `is_knocked_out()` **перед** вызовом `retreat()`: если `true` — `retreat()` не вызывается. Для Воина: KnockoutSystem уже выполнил `set_position(start_tile)` — `retreat()` перетёр бы эту позицию, поэтому он пропускается. Для остальных классов: KnockoutSystem позицию не меняет, `is_knocked_out() == true` → `retreat()` тоже пропускается — игрок остаётся на тайле монстра (отступит позже через TurnManager). (Resolved B-10 2026-10-10)

### Инвентарь — оружие

- **EC-07** — ЕСЛИ `add_weapon()` вызван при 2/2 занятых слотах: возвращает `false`. LootSystem предлагает игроку выбрать замену через `replace_weapon(old, new)`.
- **EC-08** — ЕСЛИ `replace_weapon(old, new)` вызван: удаляет `old` из `weapons`, добавляет `new`, пересчитывает `attack_bonus`. Испускает `item_removed(old)` и `item_added(new)`. Фактический дроп `old` на текущий тайл — ответственность LootSystem/DungeonGenerator, не PlayerState.
- **EC-09** — ЕСЛИ `replace_weapon(old, new)` вызван где `old` не в `weapons`: `push_error`, `weapons` не меняется, `new` не теряется (LootSystem обрабатывает возврат).
- **EC-10** — ЕСЛИ `weapons` пуст: `attack_bonus = 0`. Валидное начальное состояние.

### Инвентарь — свитки

- **EC-11** — ЕСЛИ `add_scroll()` вызван при 3/3 занятых слотах: возвращает `false`. LootSystem предлагает замену через `replace_scroll(old, new)`.
- **EC-12** — ЕСЛИ `replace_scroll(old, new)` вызван: удаляет `old`, добавляет `new`. Дроп `old` на тайл — ответственность LootSystem.
- **EC-13** — ЕСЛИ `remove_scroll()` вызван со свитком не из `scrolls`: `push_error`, `scrolls` не меняется.
- **EC-14** — ЕСЛИ CombatSystem активирует два свитка в одном бою: второй `remove_scroll()` попадёт под EC-13 если первый уже потрачен.

### Инвентарь — ключ

- **EC-15** — ЕСЛИ `set_key(null)` при `key != null`: штатное удаление после открытия сундука, испускается `item_removed`.
- **EC-16** — ЕСЛИ `set_key(null)` при `key == null`: no-op.
- **EC-17** — ЕСЛИ `set_key(new)` при `key != null`: нельзя. `push_error`, ключ не заменяется. Игрок должен сначала использовать имеющийся ключ.

### Позиция

- **EC-18** — ЕСЛИ `set_position(pos)` где `pos == position`: `previous_position = position`. `retreat()` после этого вернёт на ту же клетку. Не ошибка — TurnManager не должен допускать, но PlayerState принимает.

### Победа

- **EC-19** — ЕСЛИ `take_damage()` вызван после `has_killed_dragon=true`: урон применяется обычно. PlayerState не завершает партию самостоятельно — это забота WinCondition.
- **EC-20** — ЕСЛИ `mark_dragon_killed()` вызван повторно: no-op, сигнал `won` повторно не испускается.

### player_id и chests_opened

- **EC-21** — ЕСЛИ PlayerState создаётся с `player_id=0` или `player_id > 5`: assert при инициализации. Объект с невалидным ID не создаётся.
- **EC-22** — ЕСЛИ `increment_chests()` вызван без ключа в слоте: PlayerState не проверяет наличие ключа. Это ответственность LootSystem. Счётчик увеличивается.

### VP и лечение

- **EC-23** — ЕСЛИ `add_vp(amount)` где `amount < 0`: `push_error`, `vp` не меняется. VP не может уменьшаться.
- **EC-24** — ЕСЛИ `heal_full()` вызван при `hp == max_hp`: no-op, сигнал `hp_changed` не испускается.
- **EC-25** — ЕСЛИ `remove_key()` вызван при `key == null`: no-op (аналог EC-16). Если `key != null` — `key = null`, испускается `item_removed`.

## Dependencies

### Зависимости входящие (PlayerState зависит от)

| Система | Тип | Что нужно | Статус |
|---------|-----|-----------|--------|
| ClassSystem | Жёсткая | `character_class` → определяет `max_hp` и модификаторы | Спроектирована ✓ |
| ItemDatabase | Жёсткая | Тип `ItemData` — структура данных предметов | Спроектирована ✓ |

### Зависимости исходящие (зависят от PlayerState)

| Система | Что берёт из PlayerState |
|---------|--------------------------|
| TurnManager | Подписан на `knocked_out`; читает `is_knocked_out()` |
| CombatSystem | `get_attack_bonus()`, `take_damage(1)`, `retreat()` |
| LootSystem | `add_weapon()`, `replace_weapon()`, `set_key()`, `add_scroll()`, `replace_scroll()`, `increment_chests()` |
| KnockoutSystem | `clear_knockout()` |
| WinCondition | `has_won()`, `mark_dragon_killed()` |
| HUD | Подписан на `hp_changed`, `vp_changed`, `item_added`, `item_removed` |
| InventoryUI | Подписан на `item_added`, `item_removed`; читает `get_items_by_slot()` |

### Provisional assumptions

- `character_class` и переменный `max_hp` зависят от ClassSystem. До её проектирования: `max_hp = 5` hardcoded.
- `ItemData` — структура данных определяется в GDD ItemDatabase. PlayerState использует её как непрозрачный тип.

## Tuning Knobs

| Параметр | Текущее значение | Безопасный диапазон | Что ломается за пределами | Влияет на |
|----------|-----------------|---------------------|--------------------------|-----------|
| `MAX_HP` | 5 | 3–8 | <3: слишком мало ходов до нокаута, игра ощущается хаотичной; >8: нокаут теряет вес, Pillar 4 ослабевает | Продолжительность партии, значимость поражений |
| `WEAPON_SLOTS` | 2 | 1–3 | 1: нет ощущения «сборки» героя; >3: attack_bonus становится слишком большим для баланса | Pillar 2 («сила ощутима»), сложность монстров |
| `SCROLL_SLOTS` | 3 | 2–4 | <2: свитки редко используются; >4: UI инвентаря перегружается | Частота использования свитков, читаемость UI |
| `HP_RECOVERY_ON_KNOCKOUT` | 1 | 1–2 | >2: нокаут слишком мягкий, comeback механика сломана | Значимость нокаута |

*Изменение `WEAPON_SLOTS` требует обновления GDD ItemDatabase и пересмотра таблицы сложности монстров в GDD CombatSystem.*

## Acceptance Criteria

Все критерии — тип **Logic**. Gate: **BLOCKING** — автотест в `tests/unit/player_state/` на каждый критерий обязателен перед закрытием story. AC-17 и AC-22 дополнительно требуют интеграционного теста с заглушкой подписчика (HUD/InventoryUI).

---

**AC-01 — Инициализация инвентаря**
**GIVEN** создан новый PlayerState с валидным `player_id`
**WHEN** читаются поля инвентаря
**THEN** `weapons` — пустой массив; `key` == null; `scrolls` — пустой массив; `attack_bonus` == 0

**AC-02 — attack_bonus с двумя оружиями**
**GIVEN** PlayerState с пустым `weapons`
**WHEN** добавлены `weapon_a(+2)` и `weapon_b(+1)`
**THEN** `get_attack_bonus()` == 3

**AC-03 — attack_bonus не включает свитки**
**GIVEN** одно оружие `attack_bonus=2` и один свиток `scroll_bonus=3`
**WHEN** вызван `get_attack_bonus()`
**THEN** возвращает 2

**AC-04 — attack_bonus пересчитывается при добавлении оружия**
**GIVEN** одно оружие `+1` → `attack_bonus==1`
**WHEN** добавлено второе оружие `+3`
**THEN** `get_attack_bonus()` == 4 немедленно

**AC-05 — attack_bonus пересчитывается при замене оружия**
**GIVEN** два оружия `+2` и `+1` → `attack_bonus==3`
**WHEN** `replace_weapon(weapon_+1, weapon_+4)`
**THEN** `get_attack_bonus()` == 6

**AC-06 — attack_bonus == 0 при пустом weapons**
**GIVEN** PlayerState без оружий
**WHEN** `get_attack_bonus()`
**THEN** возвращает 0

**AC-07 — set_position сохраняет previous_position**
**GIVEN** `position = Vector2i(2,3)`
**WHEN** `set_position(Vector2i(5,7))`
**THEN** `get_position()` == Vector2i(5,7); `previous_position` == Vector2i(2,3)

**AC-08 — retreat возвращает на previous_position**
**GIVEN** `set_position(A)`, затем `set_position(B)`
**WHEN** `retreat()`
**THEN** `get_position()` == A

**AC-09 — retreat дважды без промежуточного set_position**
**GIVEN** `set_position(A)`, `set_position(B)`
**WHEN** `retreat()` вызван дважды подряд
**THEN** оба вызова возвращают позицию к A; `previous_position` не изменяется вторым вызовом

**AC-10 — поражение в бою: take_damage + retreat**
**GIVEN** hp=3, position=B, previous_position=A
**WHEN** `take_damage(1)`, затем `retreat()`
**THEN** `get_hp()` == 2; `get_position()` == A

**AC-11 — порядок при поражении, снижающем HP до 0**
**GIVEN** hp=1, position=B, previous_position=A
**WHEN** `take_damage(1)`, затем `retreat()`
**THEN** после take_damage: hp==1, skip_next_turn==true, сигнал `knocked_out` испущен; после retreat: position==A

**AC-12 — нокаут при hp <= 0**
**GIVEN** hp=1
**WHEN** `take_damage(1)`
**THEN** `get_hp()`==1; `is_knocked_out()`==true; `skip_next_turn`==true; сигналы `knocked_out` и `hp_changed(1, max_hp)` испущены

**AC-13 — нокаут не меняет позицию и инвентарь**
**GIVEN** два оружия, ключ, hp=1, position=Vector2i(3,3)
**WHEN** `take_damage(1)`
**THEN** position не изменилась; weapons.size()==2; key != null

**AC-14 — has_killed_dragon — терминальное состояние**
**GIVEN** `has_killed_dragon=false`
**WHEN** `mark_dragon_killed()`
**THEN** `has_won()`==true; сигнал `won` испущен один раз

**AC-15 — mark_dragon_killed повторно — no-op**
**GIVEN** `has_killed_dragon=true`
**WHEN** `mark_dragon_killed()` повторно
**THEN** `has_won()`==true; сигнал `won` не испускается повторно

**AC-16 — add_weapon при заполненных слотах**
**GIVEN** weapons.size()==2
**WHEN** `add_weapon(weapon_c)`
**THEN** возвращает false; weapons.size()==2; attack_bonus не изменился

**AC-17 — replace_weapon испускает сигналы**
**GIVEN** `weapon_old` в `weapons`
**WHEN** `replace_weapon(weapon_old, weapon_new)`
**THEN** сигнал `item_removed(weapon_old, "weapon")` испущен; сигнал `item_added(weapon_new, "weapon")` испущен; weapon_old отсутствует; weapon_new присутствует

**AC-18 — replace_weapon с невалидным old**
**GIVEN** `weapons=[weapon_a]`
**WHEN** `replace_weapon(weapon_unknown, weapon_new)`
**THEN** push_error вызван; `weapons==[weapon_a]`; attack_bonus не изменился

**AC-19 — add_scroll при заполненных слотах**
**GIVEN** scrolls.size()==3
**WHEN** `add_scroll(scroll_new)`
**THEN** возвращает false; scrolls.size()==3

**AC-20 — set_key при занятом слоте**
**GIVEN** `key != null`
**WHEN** `set_key(new_key)` где new_key != null
**THEN** push_error вызван; key не изменился

**AC-21 — set_key(null) при пустом слоте**
**GIVEN** `key == null`
**WHEN** `set_key(null)`
**THEN** key==null; сигналы не испускаются

**AC-22 — set_key(null) при занятом слоте**
**GIVEN** `key == some_key`
**WHEN** `set_key(null)`
**THEN** key==null; сигнал `item_removed(some_key, "key")` испущен

**AC-23 — retreat до первого set_position**
**GIVEN** PlayerState инициализирован с start_tile=Vector2i(0,2); set_position не вызывался
**WHEN** `retreat()`
**THEN** `get_position()` == Vector2i(0,2)

**AC-24 — take_damage(0) — no-op**
**GIVEN** hp=3
**WHEN** `take_damage(0)`
**THEN** `get_hp()`==3; сигнал `hp_changed` не испущен

**AC-25 — take_damage с отрицательным значением**
**GIVEN** hp=3
**WHEN** `take_damage(-1)`
**THEN** push_error вызван; `get_hp()`==3

**AC-26 — clear_knockout на живом игроке**
**GIVEN** `skip_next_turn=false`
**WHEN** `clear_knockout()`
**THEN** `is_knocked_out()`==false; сигнал `knockout_cleared` не испущен

**AC-27 — player_id вне диапазона**
**GIVEN** попытка создать PlayerState с player_id=0 или player_id=6
**WHEN** инициализация
**THEN** assert вызван; объект не создаётся

**AC-28 — effective_attack не хранится в PlayerState**
**GIVEN** PlayerState с оружием и свитком
**WHEN** инспектируются все публичные поля
**THEN** поле `effective_attack` отсутствует

**AC-29 — add_vp накапливает VP**
**GIVEN** `vp == 0.0`
**WHEN** `add_vp(3.0)`, затем `add_vp(1.5)`
**THEN** `vp == 4.5`

**AC-30 — add_vp с отрицательным — push_error, no-op**
**GIVEN** `vp == 2.0`
**WHEN** `add_vp(-1.0)`
**THEN** push_error вызван; `vp == 2.0`

**AC-31 — heal_full восстанавливает HP до max_hp**
**GIVEN** hp=2, max_hp=5
**WHEN** `heal_full()`
**THEN** `get_hp()==5`; сигнал `hp_changed(5, 5)` испущен

**AC-32 — heal_full при max HP — no-op**
**GIVEN** hp=5, max_hp=5
**WHEN** `heal_full()`
**THEN** `get_hp()==5`; сигнал `hp_changed` не испущен

**AC-33 — remove_key убирает ключ и испускает сигнал**
**GIVEN** `key == some_key`
**WHEN** `remove_key()`
**THEN** `has_key == false`; `key == null`; сигнал `item_removed(some_key, "key")` испущен

**AC-34 — remove_key при пустом слоте — no-op**
**GIVEN** `key == null`
**WHEN** `remove_key()`
**THEN** `has_key == false`; сигналы не испускаются

**AC-35 — has_key отражает наличие ключа**
**GIVEN** PlayerState без ключа
**WHEN** `set_key(some_key)`
**THEN** `has_key == true`
**WHEN** `remove_key()`
**THEN** `has_key == false`

## Open Questions

| # | Вопрос | Владелец | Блокирует |
|---|--------|----------|-----------|
| OQ-01 | `character_class` и переменный `max_hp` — provisional до проектирования ClassSystem | ClassSystem GDD | Tuning Knob MAX_HP, модификаторы класса |
| OQ-02 | Структура `ItemData` (поля, типы) — provisional до проектирования ItemDatabase | ItemDatabase GDD | Типы в инвентаре, replace_weapon/scroll интерфейс |
| OQ-03 | Концепт игры указывал 2 игрока — обновить game-concept.md на 2–5 | — | game-concept.md |
| OQ-04 | Свитки перенесены в MVP (концепт указывал Post-MVP) — обновить game-concept.md | — | game-concept.md |
