# Code Reference

**Последнее обновление**: 2026-10-17
**Последняя story**: PlayerState VP, Win Condition, Chests (story-006)

Живой справочник по всем реализованным классам проекта.
Обновляется автоматически при закрытии каждой story через `/story-done`.

---

## Foundation Layer

### `src/foundation/hero_class_data.gd`

**Class**: `HeroClassData` | **Extends**: `Resource`

READ-ONLY схема данных одного класса героя. Определяет идентификатор, отображаемое имя, базовые параметры и набор булевых флагов способностей. Логики не содержит — только данные. Загружается один раз через ClassRegistry (Story 003), разделяется между всеми системами без риска state corruption при соблюдении контракта: потребители не вызывают `ResourceSaver.save()` на экземпляре.

**ADR**: ADR-0003 | **TR-ID**: TR-class-001

#### Переменные

| Переменная | Тип | Описание |
|------------|-----|----------|
| `id` | `StringName` | Уникальный идентификатор класса: `&"warrior"`, `&"rogue"` и т.д. Используется ClassRegistry как ключ |
| `display_name` | `String` | Отображаемое имя для UI: «Воин», «Разбойница» и т.д. |
| `max_hp` | `int` | Базовый HP класса (дефолт: `5`). Читает `PlayerState._ready()` для инициализации |
| `can_reroll_both_dice` | `bool` | **Воин** — перебросить оба кубика в бою; второй результат обязателен. Читает CombatSystem |
| `wins_on_draw` | `bool` | **Разбойница** — победа при ничье в бою. Читает CombatSystem |
| `can_spend_hp_for_attack` | `bool` | **Чернокнижник** — -1 HP → +1 к силе атаки (опционально). Читает CombatSystem |
| `auto_reroll_on_one` | `bool` | **Мечник** — автоматически перебросить кубик с 1. Читает CombatSystem |
| `can_continue_turn_on_six` | `bool` | **Мечник** — при победе с 6 продолжить ход. Читает CombatSystem/TurnManager (ADR-0012) |
| `can_reroll_one_die` | `bool` | **Воительница** — переброс одного кубика; второй результат обязателен. Читает CombatSystem |
| `first_step_combat_bonus` | `int` | **Оракул** — +1 к силе если бой на первом шаге хода (дефолт: `0`). Читает CombatSystem |
| `knockout_teleport_to_start` | `bool` | **Воин** — телепорт к фонтану вместо стандартного нокаута. Читает KnockoutSystem |
| `knockout_no_turn_skip` | `bool` | **Воин** — не пропускать ход после нокаута. Читает KnockoutSystem |
| `knockout_full_heal` | `bool` | **Воин** — восстановить весь HP при нокауте. Читает KnockoutSystem |
| `can_bypass_monster_free` | `bool` | **Разбойница** — обойти монстра без боя и штрафа. Читает MovementSystem (ADR-0011) |
| `can_bypass_monster_cost` | `bool` | **Воительница** — обойти монстра за -1 шаг, -1 HP. Читает MovementSystem (ADR-0011) |
| `can_pass_through_walls` | `bool` | **Волшебник** — проходить сквозь стены. Читает MovementSystem (ADR-0011) |
| `can_swap_positions` | `bool` | **Чернокнижник** — обменяться позицией: -4 шага. Читает MovementSystem (ADR-0011) |
| `choose_encounter_from_two` | `bool` | **Оракул** — выбрать из 2 случайных вариантов на тайле. Читает EncounterDispatcher |
| `magic_charge_no_discard` | `bool` | **Волшебник** — `scroll_teleport` не расходуется; `scroll_magic_attack` расходуется нормально. Читает LootSystem/CombatSystem |

---

### `src/foundation/item_data.gd`

**Class**: `ItemData` | **Extends**: `Resource`

READ-ONLY minimal stub схемы игрового предмета. Существует для статической типизации полей `PlayerState` (`Array[ItemData]`, `key: ItemData`) и сигналов (`item_added(item: ItemData, ...)`). Полная реализация (item_type, icon, sell_value) — в ItemDatabase epic.

**ADR**: ADR-0001 | **TR-ID**: TR-item-001 (частично)

#### Переменные

| Переменная | Тип | Описание |
|------------|-----|----------|
| `id` | `StringName` | Глобальный ID предмета: `&"sword_basic"`, `&"key"`, `&"scroll_teleport"` и т.д. |
| `attack_bonus` | `int` | Бонус к атаке при использовании (только WEAPON items, дефолт: `0`). Читает CombatSystem |

---

### `src/foundation/player_state.gd`

**Class**: `PlayerState` | **Extends**: `Node`

Runtime-состояние одного игрока. Хранит все поля состояния (HP, VP, позиция, инвентарь, флаги хода), объявляет 7 типизированных сигналов, реализует полный HP lifecycle (take_damage, heal_full, knockout, clear_knockout), позиционный lifecycle (set_position, retreat), оружейный lifecycle (add_weapon, replace_weapon, get_weapons, get_attack_bonus) и key/scroll lifecycle (set_key, remove_key, get_scrolls, add_scroll, remove_scroll, replace_scroll). Размещается как in-scene Node (два независимых инстанса на партию), не Autoload. Реализует полный VP lifecycle (add_vp, has_won, mark_dragon_killed, increment_chests) — Story 006 завершена. PlayerState epic COMPLETE.

**ADR**: ADR-0003, ADR-0002, ADR-0007, ADR-0013 | **TR-ID**: TR-player-state-001, TR-player-state-006, TR-class-003

#### Сигналы

| Сигнал | Параметры | Когда |
|--------|-----------|-------|
| `hp_changed` | `new_hp: int, max_hp: int` | При изменении HP (урон, лечение, knockout) |
| `vp_changed` | `new_vp: float` | При изменении VP |
| `item_added` | `item: ItemData, slot_type: int` | При добавлении предмета в инвентарь (`slot_type` = `GameEnums.SlotType` как int — ADR-0007) |
| `item_removed` | `item: ItemData, slot_type: int` | При удалении предмета из инвентаря |
| `knocked_out` | — | Когда HP падает до 0 |
| `knockout_cleared` | — | Когда игрок восстанавливается после нокаута |
| `won` | — | Когда игрок выполнил условие победы (AC-14) |

#### Переменные

| Переменная | Тип | Описание |
|------------|-----|----------|
| `character_class` | `HeroClassData` | `@export` — назначается в Inspector до старта; неизменен после. Runtime-переназначение перехватывается `set_character_class()` |
| `player_id` | `int` | `@export` — идентификатор игрока (1–5). Валидируется `assert` в `_ready()` |
| `start_tile` | `Vector2i` | `@export` — стартовая позиция на доске, назначается в Inspector. `_ready()` копирует в `board_position` и `previous_board_position`. AC-23: retreat до первого хода возвращает именно сюда |
| `hp` | `int` | Текущие HP. Инициализируется из `character_class.max_hp` в `_ready()` |
| `max_hp` | `int` | Максимальные HP. Устанавливается из `character_class.max_hp` в `_ready()` |
| `vp` | `float` | Очки победы (дефолт: `0.0`) |
| `board_position` | `Vector2i` | Текущая позиция на игровой доске (tile coordinates). Именовано `board_position` (не `position`) — избегает конфликта с `Node2D.position` |
| `previous_board_position` | `Vector2i` | Позиция до последнего хода. Используется KnockoutSystem для retreat |
| `weapons` | `Array[ItemData]` | Оружия в инвентаре (макс. 2 слота, enforced в Story 004) |
| `key` | `ItemData` | Ключ (nullable). `null` — ключа нет |
| `scrolls` | `Array[ItemData]` | Свитки в инвентаре |
| `chests_opened` | `int` | Счётчик открытых сундуков (для VP) |
| `attack_bonus` | `int` | Кэш суммарного бонуса к атаке от оружий (дефолт: `0`). Пересчитывается в `_recalculate_attack_bonus()` при любом изменении `weapons`. CombatSystem вычисляет `effective_attack` сам (AC-28) |
| `skip_next_turn` | `bool` | Флаг пропуска следующего хода (устанавливает KnockoutSystem) |
| `has_killed_dragon` | `bool` | Флаг убийства дракона. Устанавливается через `mark_dragon_killed()`. Терминальный — once set, cannot be unset. WinConditionSystem читает через `has_won()` |
| `has_key` *(computed)* | `bool` | `get: return key != null` — read-only, нет setter |

#### Константы

| Константа | Тип | Описание |
|-----------|-----|----------|
| `WEAPON_SLOTS` | `int = 2` | Максимальное количество оружейных слотов. Enforced в `add_weapon` |
| `KEY_SLOTS` | `int = 1` | Документирует дизайн-ограничение: одновременно только один ключ. Guard в `set_key()` использует прямое сравнение `key != null` |
| `SCROLL_SLOTS` | `int = 3` | Максимальное количество слотов свитков. Enforced в `add_scroll` |
| `SLOT_WEAPON` | `int = 0` | Временный slot_type для сигналов `item_added/item_removed` (оружие). Замена: `GameEnums.SlotType.WEAPON` — ADR-0007 |
| `SLOT_KEY` | `int = 1` | Временный slot_type для сигналов (ключ). Замена: `GameEnums.SlotType.KEY` — ADR-0007 |
| `SLOT_SCROLL` | `int = 2` | Временный slot_type для сигналов (свитки). Замена: `GameEnums.SlotType.SCROLL` — ADR-0007 |

#### Методы

**`_ready() -> void`**
Четыре шага: (1) `assert(player_id >= 1 and player_id <= 5, ...)` — AC-27; (2) `assert(character_class != null, ...)` — EC-03; (3) `max_hp = character_class.max_hp`, `hp = max_hp`; (4) `board_position = start_tile`, `previous_board_position = start_tile` — AC-23. Сигналы НЕ подключаются — только `GameScene._wire_signals()`.

**`set_character_class(new_class: HeroClassData) -> void`**
Единственный runtime-канал установки `character_class`. Тройной guard: (1) `new_class == null` → `push_error`; (2) `character_class != null` → `push_error` с id обоих классов; (3) иначе — первичное присвоение. Inspector-назначение (@export) обходит этот метод — легитимно.

**`get_hp() -> int`**
Геттер текущего HP. Только чтение, не изменяет состояние. Инвариант: `1 ≤ hp ≤ max_hp` в устойчивом состоянии (нокаут зажимает в 1, не в 0). TR-player-state-003.

**`is_knocked_out() -> bool`**
Возвращает `skip_next_turn`. True = игрок нокаутирован, должен пропустить следующий ход. Только чтение.

**`take_damage(amount: int) -> void`**
Применяет урон. `amount < 0` → `push_error`, return (AC-25). `amount == 0` → no-op, сигнал не испускается (AC-24). `amount > 0` → `hp -= amount`; если `hp ≤ 0`: зажать в 1, `skip_next_turn = true`, испустить `hp_changed(1, max_hp)` затем `knocked_out()` (AC-12). Иначе — испустить `hp_changed(new_hp, max_hp)`. Position/inventory не изменяется (AC-13). TR-player-state-003, TR-player-state-005.

**`heal_full() -> void`**
Восстанавливает HP до `max_hp`. Если `hp == max_hp` → no-op, сигнал не испускается (AC-32). Иначе → `hp = max_hp`, испустить `hp_changed(max_hp, max_hp)` (AC-31). Не снимает нокаут — для этого `clear_knockout()`.

**`clear_knockout() -> void`**
Снимает флаг нокаута. Если `skip_next_turn == false` → no-op, `knockout_cleared` не испускается (AC-26). Иначе → `skip_next_turn = false`, испустить `knockout_cleared`. Вызывается TurnManager в начале хода нокаутированного игрока.

**`get_position() -> Vector2i`**
Геттер текущей позиции на доске. Только чтение, не изменяет состояние. До первого `set_position()` возвращает `start_tile`. TR-player-state-004.

**`set_position(pos: Vector2i) -> void`**
Обновляет позицию. Порядок критичен: (1) `previous_board_position = board_position` — сохранить текущую; (2) `board_position = pos`. Позволяет `retreat()` вернуть игрока. Не валидирует `pos` против карты — ответственность MovementSystem. Сигналы не испускаются (нет `position_changed` в ADR-0002). AC-07, TR-player-state-004.

**`retreat() -> void`**
Возвращает игрока на `previous_board_position`. `previous_board_position` НЕ обновляется — двойной retreat идемпотентен (EC-05, AC-09). Не влияет на HP, инвентарь, флаги — только позиция (AC-10, AC-11). До первого `set_position()` возвращает на `start_tile` (AC-23).

**`get_attack_bonus() -> int`**
Геттер кэша `attack_bonus`. Только чтение. Формула (GDD): `Σ weapon.attack_bonus` для всех оружий в `weapons[]` — свитки не учитываются (AC-03). При пустом weapons → 0 (AC-06). TR-player-state-006.

**`get_weapons() -> Array[ItemData]`**
Возвращает прямую ссылку на `weapons[]` (без копирования). Pure reader — ADR-0013: LootSystem читает для определения слабейшего оружия. Caller не должен мутировать возвращённый массив (нарушит кэш `attack_bonus` и сигнальный контракт).

**`add_weapon(item: ItemData) -> bool`**
Добавляет оружие в инвентарь. Если `weapons.size() >= WEAPON_SLOTS` → `false`, состояние не изменяется (AC-16). Иначе: `weapons.append(item)` → `_recalculate_attack_bonus()` → `item_added.emit(item, SLOT_WEAPON)` → `true`. AC-04: пересчёт синхронный, немедленный.

**`replace_weapon(old: ItemData, new_item: ItemData) -> void`**
Заменяет оружие по ссылке. `weapons.find(old) == -1` → `push_error`, return без изменений (AC-18). Иначе: `weapons[idx] = new_item` → `_recalculate_attack_bonus()` → `item_removed.emit(old, SLOT_WEAPON)` → `item_added.emit(new_item, SLOT_WEAPON)`. Порядок сигналов: removed ДО added (AC-17). PlayerState не решает какое оружие заменить — это LootSystem (ADR-0013).

**`set_key(item: ItemData) -> void`**
Управляет nullable ключевым слотом. Четыре ветки: (1) `item != null && key != null` → `push_error("set_key: key slot already occupied")`, return (AC-20); (2) `item == null && key == null` → no-op, сигналы не испускаются (AC-21); (3) `item == null && key != null` → сохранить old_key, `key = null`, `item_removed.emit(old_key, SLOT_KEY)` (AC-22); (4) `item != null && key == null` → `key = item`, `item_added.emit(key, SLOT_KEY)`.

**`remove_key() -> void`**
Явное удаление ключа. Если `key == null` → no-op, сигналы не испускаются (AC-34). Иначе → сохранить old_key, `key = null`, `item_removed.emit(old_key, SLOT_KEY)` (AC-33). Семантически идентичен `set_key(null)`, но выражает intent удаления.

**`get_scrolls() -> Array[ItemData]`**
Возвращает прямую ссылку на `scrolls[]` (без копирования). Pure reader — ADR-0013: LootSystem читает для FIFO-замены (`scrolls[0]` = oldest). Caller не должен мутировать возвращённый массив.

**`add_scroll(item: ItemData) -> bool`**
Добавляет свиток в инвентарь. Если `scrolls.size() >= SCROLL_SLOTS` → `false`, состояние не изменяется (AC-19). Иначе: `scrolls.append(item)` → `item_added.emit(item, SLOT_SCROLL)` → `true`.

**`remove_scroll(item: ItemData) -> void`**
Удаляет свиток по ссылке. `scrolls.find(item) == -1` → `push_error("remove_scroll: item not found in scrolls")`, return. Иначе: `scrolls.remove_at(idx)` → `item_removed.emit(item, SLOT_SCROLL)`.

**`replace_scroll(old: ItemData, new_item: ItemData) -> void`**
Заменяет свиток по ссылке (ADR-0013 FIFO: LootSystem передаёт `scrolls[0]` как old). `scrolls.find(old) == -1` → `push_error("replace_scroll: old item not found in scrolls")`, return. Иначе: `scrolls[idx] = new_item` → `item_removed.emit(old, SLOT_SCROLL)` → `item_added.emit(new_item, SLOT_SCROLL)`.

**`has_won() -> bool`**
Возвращает `has_killed_dragon`. Делегирует к флагу — единственный источник истины (ADR-0003). WinConditionSystem вызывает этот метод для проверки победы; PlayerState только хранит флаг. Только чтение. AC-14.

**`add_vp(amount: float) -> void`**
Добавляет VP. `amount < 0.0` → `push_error`, return без изменений (AC-30). При `amount >= 0.0` (включая 0.0): `vp += amount`, `vp_changed.emit(vp)`. Нулевой amount допустим — `vp_changed` испускается с текущим vp. Источники VP определяются LootSystem/WinCondition, не PlayerState. AC-29, AC-30.

**`mark_dragon_killed() -> void`**
Терминальная операция. Если `has_killed_dragon == true` → no-op, `won` не испускается (AC-15). Иначе: `has_killed_dragon = true` → `won.emit()`. Порядок критичен: флаг до сигнала — слушатель может синхронно вызвать `has_won()` и получить `true`. PlayerState НЕ завершает партию; не начисляет VP (ADR-0014 — WinCondition вызовет `add_vp(1.5)` отдельно). AC-14, AC-15.

**`increment_chests() -> void`**
Безусловно увеличивает `chests_opened += 1`. Не проверяет наличие ключа — это ответственность LootSystem (GDD EC-22). Не испускает сигналов — WinConditionSystem читает поле напрямую при подсчёте VP.

**`_recalculate_attack_bonus() -> void`** *(private)*
Пересчитывает кэш `attack_bonus` полным проходом по `weapons[]`. `attack_bonus = Σ w.attack_bonus`. O(1) практически (max 2 элемента). Вызывается только из `add_weapon` и `replace_weapon`.

---

## Data Assets

### `assets/data/classes/` — 7 файлов HeroClassData

**Тип**: `.tres` (Godot Resource, `script_class="HeroClassData"`) | **Формат**: format=3

Статические данные 7 классов героев. Каждый файл — отдельный экземпляр `HeroClassData` с заполненными `id`, `display_name`, `max_hp` и набором флагов способностей. Загружаются ClassRegistry (Story 003) через `preload()` / `load()`.

**ADR**: ADR-0003 | **TR-ID**: TR-class-001

| Файл | `id` | `display_name` | Уникальные флаги (`true`) |
|------|------|----------------|--------------------------|
| `warrior.tres` | `&"warrior"` | Воин | `can_reroll_both_dice`, `knockout_teleport_to_start`, `knockout_no_turn_skip`, `knockout_full_heal` |
| `rogue.tres` | `&"rogue"` | Разбойница | `wins_on_draw`, `can_bypass_monster_free` |
| `wizard.tres` | `&"wizard"` | Волшебник | `magic_charge_no_discard`, `can_pass_through_walls` |
| `warlock.tres` | `&"warlock"` | Чернокнижник | `can_spend_hp_for_attack`, `can_swap_positions` |
| `swordsman.tres` | `&"swordsman"` | Мечник | `auto_reroll_on_one`, `can_continue_turn_on_six` |
| `oracle.tres` | `&"oracle"` | Оракул | `choose_encounter_from_two`; `first_step_combat_bonus = 1` |
| `swordswoman.tres` | `&"swordswoman"` | Воительница | `can_reroll_one_die`, `can_bypass_monster_cost` |

Все классы: `max_hp = 5`. Все прочие boolean-флаги = `false`. UIDs назначаются Godot при первом открытии проекта.

---

### `src/foundation/class_registry.gd`

**Class**: *(class_name удалён — naming conflict с Autoload)* | **Extends**: `Node`

READ-ONLY Autoload: индекс всех 7 `HeroClassData` ресурсов. Загружает `.tres` файлы через `preload()` в `_ready()` и предоставляет O(1) lookup по `StringName` id. Никакого изменяемого состояния — только данные и выборка.

Регистрируется в Project Settings → Autoload (имя `ClassRegistry`, путь `res://src/foundation/class_registry.gd`). После регистрации доступен из любого скрипта без `preload` или `@export`. `class_name` намеренно отсутствует: в Godot 4.7 naming conflict между `class_name ClassRegistry` и Autoload `ClassRegistry` делает expression недоступным.

**ADR**: ADR-0001, ADR-0003 | **TR-ID**: TR-class-002, TR-class-003

#### Константы

| Константа | Тип | Описание |
|-----------|-----|----------|
| `CLASS_OFFER_COUNT` | `int = 3` | Сколько классов предлагать за один выбор (драфт). Tuning knob: safe range 2–5 (GDD §Draft System) |

#### Переменные

| Переменная | Тип | Описание |
|------------|-----|----------|
| `_classes` | `Dictionary` | `StringName → HeroClassData`. Заполняется в `_ready()`, не изменяется после. Untyped: Godot 4 не поддерживает `Dictionary[K, V]` в объявлении |

#### Методы

**`get_hero_class(id: StringName) -> HeroClassData`**
O(1) Dictionary lookup. Возвращает shared Resource reference (caller не должен мутировать). Пустой `id` или неизвестный → `push_error` + `null`. Неверный тип ресурса → отдельный `push_error` с указанием реального типа. Именован `get_hero_class` (не `get_class`) — `get_class()` зарезервирован в `Object` Godot 4.

**`get_all_classes() -> Array[HeroClassData]`**
Возвращает новый typed Array из всех 7 объектов (порядок = порядок preload в `_ready()`). Использует `result.assign(_classes.values())` для typed Array из untyped Dictionary values.

**`pick_random(n: int, rng: RandomNumberGenerator, already_selected: Array[HeroClassData] = []) -> Array[HeroClassData]`**
Возвращает `n` случайных классов из тех, что не входят в `already_selected`. Фильтрация по reference equality (одни и те же `.tres` shared objects). Если доступных ≤ n → возвращает все доступные через `available.duplicate()`. Иначе — частичный Fisher-Yates shuffle (O(n)): первые `n` позиций перемешиваются in-place, возвращается `available.slice(0, n)`. RNG передаётся снаружи (DI) — детерминизм при фиксированном seed гарантирован. Autoload stateless: состояние выборов хранится у caller'а.
