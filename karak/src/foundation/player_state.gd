class_name PlayerState  # Runtime mutable state одного игрока на протяжении всей партии
extends Node  # In-scene Node — ADR-0003: PlayerState extends Node (ЗАПРЕЩЕНО: extends Resource)

# ===================================================
# PLAYER STATE — Foundation Layer (Full Skeleton)
# ===================================================
# Хранит ВСЁ mutable runtime-состояние одного игрока: HP, VP, позицию, инвентарь,
# флаги поворота. Является единственным источником истины о состоянии игрока в партии.
#
# Два независимых инстанса PlayerState существуют одновременно — по одному на каждого
# игрока. Оба назначаются в Inspector до начала партии и не пересоздаются в рантайме.
#
# Lifecycle:
#   1. Inspector назначает character_class и player_id до запуска
#   2. _ready() валидирует оба поля и инициализирует max_hp / hp
#   3. Все дальнейшие мутации — через публичные методы (реализуются в Story 002–006)
#   4. Сигналы соединяет ТОЛЬКО GameScene._wire_signals() — не _ready()
#
# ЗАПРЕЩЕНО:
#   - Добавлять поле effective_attack (AC-28 — это ответственность CombatSystem)
#   - Подключать внешние сигналы в _ready() (только GameScene._wire_signals())
#   - Регистрировать как Autoload (каждый игрок — отдельный инстанс, не singleton)
#   - PlayerState.new() в production-коде (инстанциировать через сцену)
#
# ADR Reference: ADR-0003 (PlayerState as Node)
# ADR Reference: ADR-0002 (Typed signals)
# ADR Reference: ADR-0007 (SlotType enum — сигналы item_added/item_removed используют int до появления GameEnums)
# TR Reference: TR-class-003 ("character_class immutable after selection")
# Control Manifest — Foundation Layer
# ===================================================


# ===================================================
# СЕКЦИЯ: Сигналы (все типизированы — ADR-0002)
# ===================================================

## Испускается при изменении HP игрока (урон, лечение, knockout).
## Слушатель: HUD — обновляет HP bar.
signal hp_changed(new_hp: int, max_hp: int)

## Испускается при изменении VP (очки победы: сундуки, убийство дракона, бонусы).
## Слушатель: HUD, WinConditionSystem.
signal vp_changed(new_vp: float)

## Испускается при добавлении предмета в инвентарь.
## slot_type: GameEnums.SlotType (передаётся как int до появления GameEnums — ADR-0007)
## Слушатель: HUD — обновляет иконку предмета в слоте.
signal item_added(item: ItemData, slot_type: int)

## Испускается при удалении предмета из инвентаря (использование свитка, потеря ключа).
## slot_type: GameEnums.SlotType (int — ADR-0007)
## Слушатель: HUD — очищает иконку слота.
signal item_removed(item: ItemData, slot_type: int)

## Испускается когда HP падает до 0 (knockout event).
## Слушатель: KnockoutSystem — запускает логику нокаута.
signal knocked_out()

## Испускается когда игрок восстанавливается после нокаута.
## Слушатель: KnockoutSystem, TurnManager — разрешает следующий ход.
signal knockout_cleared()

## Испускается когда игрок выполнил условие победы.
## Слушатель: WinConditionSystem — завершает партию. (AC-14)
signal won()


# ===================================================
# СЕКЦИЯ: @export поля (назначаются в Inspector до первого хода)
# ===================================================

## Класс героя, выбранный для этого игрока.
## Назначается в Inspector до старта партии; после установки — неизменен до конца партии.
## TR-class-003: "character_class immutable after selection"
##
## ВАЖНО: @export позволяет Godot напрямую присвоить значение через Inspector,
## обходя setter. Это намеренно — Inspector-назначение происходит ДО _ready(),
## что является легитимным каналом первоначальной инициализации.
## Runtime-переназначение (через код) перехватывается setter'ом set_character_class().
@export var character_class: HeroClassData  # assigned in Inspector per player — immutable after _ready()

## Идентификатор игрока в текущей партии (1–5 включительно).
## Используется для идентификации инстанса PlayerState в GameScene и TurnManager.
## Валидируется в _ready(): assert(player_id >= 1 and player_id <= 5). (AC-27)
@export var player_id: int = 1  # 1–5 inclusive — validated in _ready() (AC-27)

## Стартовая позиция игрока на доске. Назначается в Inspector до первого хода.
## Используется для инициализации board_position и previous_board_position в _ready().
## AC-23: retreat() до первого set_position() возвращает именно на start_tile, не на Vector2i(0,0).
@export var start_tile: Vector2i = Vector2i(0, 2)  # default overridden in Inspector (AC-23)


# ===================================================
# СЕКЦИЯ: Константы
# ===================================================

## Максимальное количество оружейных слотов в инвентаре (GDD: player-state.md).
const WEAPON_SLOTS: int = 2

## Максимальное количество слотов ключа (всегда 1 — только один ключ за раз).
## Используется в set_key() для guard-проверки занятости слота.
const KEY_SLOTS: int = 1

## Максимальное количество слотов свитков в инвентаре (GDD: player-state.md).
## add_scroll() отклоняет добавление при scrolls.size() >= SCROLL_SLOTS (AC-19).
const SCROLL_SLOTS: int = 3

## Временный slot_type для сигналов item_added/item_removed для оружия.
## Замена: GameEnums.SlotType.WEAPON когда GameEnums будет реализован (ADR-0007).
const SLOT_WEAPON: int = 0

## Временный slot_type для сигналов item_added/item_removed для ключа.
## Замена: GameEnums.SlotType.KEY когда GameEnums будет реализован (ADR-0007).
const SLOT_KEY: int = 1

## Временный slot_type для сигналов item_added/item_removed для свитков.
## Замена: GameEnums.SlotType.SCROLL когда GameEnums будет реализован (ADR-0007).
const SLOT_SCROLL: int = 2


# ===================================================
# СЕКЦИЯ: Публичные переменные состояния
# ===================================================

## Текущие HP игрока. Инициализируется из character_class.max_hp в _ready().
## Диапазон: 0 ≤ hp ≤ max_hp. При hp == 0 испускается knocked_out.
var hp: int

## Максимальные HP игрока. Устанавливается из character_class.max_hp в _ready().
## Не меняется в течение партии (никаких permanent buffs в текущем дизайне).
var max_hp: int

## Очки победы (VP). Начальное значение 0.0.
## Накапливаются через: открытие сундуков, убийство дракона, бонусные условия.
var vp: float = 0.0

## Текущая позиция игрока на игровой доске (tile coordinates).
## (0, 0) — до начала партии (не размещён); реальная позиция устанавливается в Story 003.
## Названо board_position (не position) — избегает конфликта с Node2D.position: Vector2.
var board_position: Vector2i

## Позиция на доске перед последним ходом. Используется KnockoutSystem для retreat.
## Инициализируется вместе с board_position в Story 003.
var previous_board_position: Vector2i

## Список оружий в инвентаре. Максимум 2 слота (enforced в Story 004 — add_weapon/replace_weapon).
## ItemData — stub из Foundation; полная реализация в ItemDatabase epic.
var weapons: Array[ItemData] = []

## Ключ в инвентаре. null — ключа нет; не null — ключ есть.
## Computed property has_key проверяет это поле. (AC-01: initial null)
var key: ItemData  # nullable — null means no key (AC-01)

## Список свитков в инвентаре. Количество не ограничено на уровне PlayerState
## (ограничения — ответственность LootSystem / GDD).
var scrolls: Array[ItemData] = []

## Счётчик открытых сундуков за партию. Используется WinConditionSystem для подсчёта VP.
var chests_opened: int = 0

## Суммарный бонус к атаке от предметов (не от класса — это attack_bonus ItemData).
## Начальное значение 0. (AC-01: initial 0)
## ЗАПРЕЩЕНО: effective_attack (AC-28) — CombatSystem вычисляет итоговую атаку сам.
var attack_bonus: int = 0  # item-sourced attack bonus — CombatSystem reads this (AC-01, AC-28)

## Флаг пропуска следующего хода. Устанавливается KnockoutSystem после нокаута.
## Снимается TurnManager в начале хода (если warrior с knockout_no_turn_skip — не устанавливается).
var skip_next_turn: bool = false

## Флаг убийства дракона в этой партии. Устанавливается в Story 006 (mark_dragon_killed).
## Используется WinConditionSystem для подсчёта VP.
var has_killed_dragon: bool = false


# ===================================================
# СЕКЦИЯ: Computed properties
# ===================================================

## Возвращает true если у игрока есть ключ (key != null).
## AC-01: при инициализации key == null → has_key == false.
## Слушатели: UI (иконка ключа), DungeonSystem (проверка прохода в замок).
var has_key: bool:
	get: return key != null  # delegate to key field — single source of truth


# ===================================================
# ВСТРОЕННЫЕ ВИРТУАЛЬНЫЕ МЕТОДЫ
# ===================================================

## Инициализация при входе в Scene Tree.
## Валидирует player_id (AC-27) и character_class (EC-03), затем инициализирует HP.
## assert'ы срабатывают только в debug builds; в release — игнорируются (приемлемо по ADR-0003).
##
## ВАЖНО: signal connections здесь ЗАПРЕЩЕНЫ — только GameScene._wire_signals().
func _ready() -> void:
	# --- ШАГ 1: guard — player_id должен быть в диапазоне 1–5 (AC-27) ---
	# Значение за пределами диапазона означает некорректную настройку Inspector.
	# assert прерывает выполнение в debug, предотвращая молчаливые ошибки в логике ходов.
	assert(player_id >= 1 and player_id <= 5,
		"PlayerState: player_id must be 1–5, got %d" % player_id)  # AC-27

	# --- ШАГ 2: guard — character_class обязан быть назначен в Inspector ---
	# Если character_class == null — сцена настроена некорректно.
	# assert прерывает выполнение в debug, предотвращая молчаливые ошибки позже в партии.
	assert(character_class != null,
		"PlayerState requires character_class set in Inspector before _ready(). EC-03.")

	# --- ШАГ 3: инициализация HP из character_class ---
	# max_hp берётся из Resource; hp начинает на максимуме (полное здоровье в начале партии).
	max_hp = character_class.max_hp  # read-only access to HeroClassData — never write back
	hp = max_hp

	# --- ШАГ 4: инициализация позиции из start_tile (AC-23) ---
	# Оба поля инициализируются одинаково: если set_position() ещё не вызывался,
	# retreat() должен вернуть игрока именно на start_tile — не на Vector2i(0,0).
	# start_tile назначается в Inspector до _ready(); здесь только копирование.
	board_position = start_tile
	previous_board_position = start_tile


# ===================================================
# ПУБЛИЧНЫЕ МЕТОДЫ
# ===================================================

## Устанавливает character_class при первоначальном выборе класса.
## После первой установки любая попытка переназначения отклоняется с push_error.
##
## Contract:
##   - Вызывать только когда character_class == null (первый и единственный раз).
##   - Вызов при уже установленном character_class — ошибка (EC-03: перевыбор запрещён).
##   - push_error не бросает исключение в GDScript — выводит в лог и продолжает выполнение;
##     character_class при этом НЕ изменяется.
##   - Inspector-назначение (@export) обходит этот метод — это намеренно и легитимно.
##
## TR-class-003: "character_class immutable after selection"
## AC-13: повторная установка отклонена; первоначальная — проходит без ошибки.
func set_character_class(new_class: HeroClassData) -> void:
	# --- ШАГ 1: null-guard на входной параметр ---
	# null-класс не имеет смысла — отклонить немедленно, не допуская тихого
	# перевода character_class в null и блокировки последующих легитимных вызовов.
	if new_class == null:
		push_error("PlayerState: set_character_class() called with null — new_class must be a valid HeroClassData.")
		return

	# --- ШАГ 2: immutability guard (EC-03) ---
	# Если character_class уже установлен — любое переназначение запрещено,
	# даже если передаётся тот же объект. Это предотвращает случайный баг
	# или намеренный обход mid-game class switch.
	if character_class != null:
		push_error(
			"PlayerState: character_class already set — cannot change class mid-game. " +
			"EC-03: mid-game class reselection is forbidden. " +
			"Current class: %s, Attempted: %s" % [character_class.id, new_class.id]
		)
		return  # character_class остаётся неизменным

	# --- ШАГ 3: первоначальное назначение (легитимный путь) ---
	# character_class == null и new_class валиден — первая установка, разрешено.
	character_class = new_class


## Возвращает текущее количество HP игрока.
##
## Contract:
##   - Только чтение; не изменяет состояние.
##   - Диапазон возвращаемого значения: 1 ≤ hp ≤ max_hp (нокаут зажимает hp в 1, не в 0).
##
## TR-player-state-003: "HP clamped to [0, max_hp]"
func get_hp() -> int:
	return hp  # прямой доступ к полю — single source of truth


## Возвращает true если игрок находится в состоянии нокаута (должен пропустить ход).
##
## Contract:
##   - Только чтение; не изменяет состояние.
##   - Нокаут: skip_next_turn == true (устанавливается в take_damage при hp ≤ 0).
##   - Снимается через clear_knockout() после пропуска хода.
##
## AC-12: после take_damage(1) при hp=1 → is_knocked_out() == true
func is_knocked_out() -> bool:
	return skip_next_turn  # skip_next_turn — единственный флаг нокаута (ADR-0003)


## Применяет урон к игроку. При hp ≤ 0 переводит игрока в нокаут.
##
## Contract:
##   - amount должен быть >= 0; отрицательное значение — push_error, метод прерывается (AC-25).
##   - amount == 0 → no-op, сигнал hp_changed НЕ испускается (AC-24).
##   - При нокауте: hp зажимается в 1, skip_next_turn = true (TR-player-state-005).
##   - Position, weapons, key, scrolls при нокауте НЕ изменяются (AC-13).
##   - Сигналы hp_changed и knocked_out испускаются только при реальном изменении состояния.
##
## AC-12: take_damage(1) при hp=1 → hp==1, skip_next_turn==true, knocked_out + hp_changed(1, max_hp) испущены
## AC-13: нокаут не трогает position/weapons/key
## AC-24: take_damage(0) → hp не меняется, hp_changed НЕ испущен
## AC-25: take_damage(-1) → push_error, hp не меняется
## TR-player-state-003: "HP clamped to [0, max_hp]"
## TR-player-state-005: "HP knockout: hp<=0 sets hp=1, skip_next_turn=true; position/inventory unchanged"
func take_damage(amount: int) -> void:
	# --- ШАГ 1: валидация входного параметра ---
	# Отрицательный урон не имеет смысла в данной механике.
	# push_error выводит в лог и возвращает управление без изменения состояния (AC-25).
	if amount < 0:
		push_error("take_damage: amount must be >= 0, got %d" % amount)
		return

	# --- ШАГ 2: no-op при нулевом уроне (AC-24) ---
	# Сигнал hp_changed НЕ испускается — состояние не изменилось.
	# Это правило приоритетнее любых downstream-эффектов.
	if amount == 0:
		return

	# --- ШАГ 3: применить урон ---
	hp -= amount

	# --- ШАГ 4: проверка нокаута (TR-player-state-005) ---
	# Если hp упало до 0 или ниже — нокаут. HP зажимается в 1, а не в 0:
	# игрок остаётся «живым» но теряет следующий ход.
	# Position, weapons, key остаются неизменными (AC-13) — мы их не трогаем.
	if hp <= 0:
		hp = 1  # зажать в 1, не в 0 — нокаут не равен смерти (TR-player-state-005)
		skip_next_turn = true
		hp_changed.emit(hp, max_hp)  # испустить с hp=1 до knocked_out (порядок важен для слушателей HUD)
		knocked_out.emit()
		return

	# --- ШАГ 5: обычный урон без нокаута ---
	hp_changed.emit(hp, max_hp)


## Восстанавливает HP игрока до максимума (полное лечение).
##
## Contract:
##   - Если hp уже равен max_hp → no-op, сигнал hp_changed НЕ испускается (AC-32).
##   - Не снимает нокаут: clear_knockout() вызывается отдельно.
##   - hp устанавливается точно в max_hp (не clamp — max_hp неизменен в партии).
##
## AC-31: heal_full() при hp=2, max_hp=5 → hp==5, hp_changed(5, 5) испущен
## AC-32: heal_full() при hp==max_hp → no-op, hp_changed НЕ испущен
func heal_full() -> void:
	# --- ШАГ 1: no-op если HP уже максимален (AC-32) ---
	# Сигнал не испускается — правило: сигналы только при реальном изменении состояния (ADR-0002).
	if hp == max_hp:
		return

	# --- ШАГ 2: восстановить HP до максимума ---
	hp = max_hp
	hp_changed.emit(hp, max_hp)  # hp и max_hp равны — HUD показывает полную шкалу


## Снимает флаг нокаута после того, как игрок пропустил ход.
##
## Contract:
##   - Если skip_next_turn == false → no-op, knockout_cleared НЕ испускается (AC-26).
##   - Не изменяет hp — лечение происходит отдельно через heal_full().
##   - Вызывается TurnManager'ом в начале хода нокаутированного игрока.
##
## AC-26: clear_knockout() при живом игроке (skip_next_turn=false) → no-op, knockout_cleared НЕ испущен
func clear_knockout() -> void:
	# --- ШАГ 1: no-op на живом игроке (AC-26) ---
	# Сигнал не испускается — состояние и так чистое.
	if not skip_next_turn:
		return

	# --- ШАГ 2: снять флаг нокаута ---
	skip_next_turn = false
	knockout_cleared.emit()  # TurnManager слушает — разрешает следующий ход игроку


## Возвращает текущую позицию игрока на доске (tile coordinates).
##
## Contract:
##   - Только чтение; не изменяет состояние.
##   - До первого set_position() возвращает start_tile (инициализировано в _ready()).
##
## TR-player-state-004: "set_position() saves previous_position; retreat() restores it"
func get_position() -> Vector2i:
	return board_position  # прямой доступ к полю — single source of truth


## Устанавливает новую позицию игрока на доске. Сохраняет текущую как previous.
##
## Contract:
##   - Всегда сохраняет текущий board_position в previous_board_position ПЕРЕД обновлением.
##   - Это позволяет retreat() вернуть игрока на предыдущую позицию.
##   - Не валидирует pos против карты — ответственность MovementSystem (AC-core-manifest).
##
## AC-07: set_position(Vector2i(5,7)) из board_position=Vector2i(2,3)
##        → board_position==Vector2i(5,7), previous_board_position==Vector2i(2,3)
## TR-player-state-004: "set_position() saves previous_position; retreat() restores it"
func set_position(pos: Vector2i) -> void:
	# --- ШАГ 1: сохранить текущую позицию как previous (AC-07) ---
	# Это обязательно: retreat() обращается к previous_board_position.
	# Порядок критичен: сначала save, потом assign.
	previous_board_position = board_position

	# --- ШАГ 2: обновить текущую позицию ---
	board_position = pos


## Возвращает игрока на позицию до последнего set_position().
##
## Contract:
##   - Восстанавливает board_position = previous_board_position.
##   - НЕ обновляет previous_board_position (EC-05, AC-09).
##   - Двойной retreat() без промежуточного set_position() — оба вызова возвращают к той же позиции.
##   - Не влияет на HP, инвентарь, флаги — только позиция (AC-10, AC-11).
##   - До первого set_position(): previous_board_position == start_tile (AC-23).
##
## AC-08: set_position(A) → set_position(B) → retreat() → board_position == A
## AC-09: retreat дважды без промежуточного set_position → оба возвращают к A
## AC-10: take_damage(1) + retreat() → hp уменьшен, позиция возвращена на A
## AC-11: нокаут + retreat() → нокаут сохранён, позиция возвращена на A
## AC-23: retreat() до first set_position() → board_position == start_tile
## EC-05 (GDD): previous_board_position НЕ изменяется при retreat() — это по дизайну
## Control Manifest Core: retreat() не обновляет previous_board_position (AC-09, EC-05)
func retreat() -> void:
	# Восстановить позицию на previous_board_position.
	# previous_board_position НЕ обновляется — EC-05, AC-09: двойной retreat корректен.
	board_position = previous_board_position


## Возвращает суммарный бонус к атаке от всех оружий в инвентаре.
##
## Contract:
##   - Только чтение; не изменяет состояние.
##   - Формула (GDD): attack_bonus = Σ weapon.attack_bonus только для оружий (не свитки).
##   - При пустом weapons → 0.
##
## AC-02: weapon(+2) + weapon(+1) → 3
## AC-03: свитки не влияют на attack_bonus
## AC-06: пустые weapons → 0
## TR-player-state-006
func get_attack_bonus() -> int:
	return attack_bonus  # кэш, пересчитывается в _recalculate_attack_bonus()


## Возвращает список оружий игрока (0–2 ItemData).
##
## Contract:
##   - Чистый reader — возвращает прямую ссылку на массив, без копирования.
##   - LootSystem читает этот массив для определения слабейшего оружия (ADR-0013).
##   - Не изменяет состояние.
##
## TR-player-state-006 / ADR-0013
func get_weapons() -> Array[ItemData]:
	return weapons  # прямая ссылка — LootSystem читает для replace_weakest_weapon


## Добавляет оружие в инвентарь.
##
## Contract:
##   - Если weapons.size() < WEAPON_SLOTS — добавляет, пересчитывает attack_bonus,
##     испускает item_added(item, SLOT_WEAPON), возвращает true.
##   - Если weapons.size() >= WEAPON_SLOTS — возвращает false без изменений (AC-16).
##   - item не должен быть null (вызывающий гарантирует это; нет null-guard — не по контракту).
##
## AC-16: add_weapon при заполненных слотах → false, weapons.size() не изменился
## TR-player-state-006
func add_weapon(item: ItemData) -> bool:
	# --- ШАГ 1: проверить наличие свободного слота (AC-16) ---
	# Если оба слота заняты — отклонить без изменений.
	if weapons.size() >= WEAPON_SLOTS:
		return false

	# --- ШАГ 2: добавить оружие в массив ---
	weapons.append(item)

	# --- ШАГ 3: пересчитать attack_bonus кэш ---
	# Кэш пересчитывается немедленно (AC-04): следующий get_attack_bonus() вернёт новое значение.
	_recalculate_attack_bonus()

	# --- ШАГ 4: испустить сигнал о добавлении предмета ---
	# slot_type = SLOT_WEAPON (int 0) — временная константа до появления GameEnums (ADR-0007).
	item_added.emit(item, SLOT_WEAPON)

	return true


## Заменяет оружие в инвентаре: old → new_item.
##
## Contract:
##   - Находит old в weapons по ссылке (Array.find).
##   - Если old не найден — push_error, weapons не изменяется (AC-18).
##   - При успехе: weapons[idx] = new_item, пересчитывает attack_bonus,
##     испускает item_removed(old, SLOT_WEAPON) + item_added(new_item, SLOT_WEAPON) (AC-17).
##   - Логика выбора слабейшего оружия — в LootSystem (ADR-0013: PlayerState не решает).
##
## AC-05: replace_weapon(w2, w3) при weapons=[w1,w2] → attack_bonus = w1.bonus + w3.bonus
## AC-17: испускает item_removed(old, SLOT_WEAPON) + item_added(new_item, SLOT_WEAPON)
## AC-18: replace_weapon(unknown, new) → push_error, weapons не изменился
## TR-player-state-006 / ADR-0013
func replace_weapon(old: ItemData, new_item: ItemData) -> void:
	# --- ШАГ 1: найти old в weapons ---
	# Array.find() возвращает -1 если элемент не найден.
	var idx: int = weapons.find(old)

	# --- ШАГ 2: валидация — old должен быть в weapons (AC-18) ---
	if idx == -1:
		push_error(
			"PlayerState.replace_weapon: old item not found in weapons. " +
			"Attempted to replace an item not in the weapon slots. AC-18."
		)
		return  # weapons не изменяется (AC-18)

	# --- ШАГ 3: заменить слот ---
	weapons[idx] = new_item

	# --- ШАГ 4: пересчитать attack_bonus кэш немедленно (AC-05) ---
	_recalculate_attack_bonus()

	# --- ШАГ 5: испустить сигналы удаления old и добавления new_item (AC-17) ---
	# Порядок: item_removed ПЕРЕД item_added — old ушёл, new_item пришёл.
	# slot_type = SLOT_WEAPON (int 0) — до появления GameEnums (ADR-0007).
	item_removed.emit(old, SLOT_WEAPON)
	item_added.emit(new_item, SLOT_WEAPON)


## Устанавливает ключ в инвентарь или удаляет его (set_key(null)).
##
## Contract:
##   - item != null при key != null → push_error, key не изменяется (AC-20).
##   - item == null при key == null → no-op, сигналы НЕ испускаются (AC-21).
##   - item == null при key != null → удалить ключ: key = null,
##     item_removed(old_key, SLOT_KEY) испущен (AC-22).
##   - item != null при key == null → добавить ключ: key = item,
##     item_added(item, SLOT_KEY) испущен.
##
## AC-20: set_key(new_key) при key!=null → push_error, key не изменился
## AC-21: set_key(null) при key==null → no-op, сигналы не испускаются
## AC-22: set_key(null) при key!=null → key==null, item_removed(old_key, SLOT_KEY) испущен
## ADR-0007: slot_type передаётся как int до появления GameEnums
func set_key(item: ItemData) -> void:
	# --- ШАГ 1: guard — нельзя перезаписать занятый ключевой слот (AC-20) ---
	# KEY_SLOTS == 1: в отличие от оружий, ключ уникален.
	# push_error не бросает исключение — продолжает выполнение, key остаётся прежним.
	if item != null and key != null:
		push_error("set_key: key slot already occupied")
		return

	# --- ШАГ 2: no-op при set_key(null) когда ключа нет (AC-21) ---
	# Ни сигналы, ни state не меняются — это не событие.
	if item == null and key == null:
		return

	# --- ШАГ 3: удаление ключа — set_key(null) при key!=null (AC-22) ---
	# Сохраняем ссылку до обнуления: сигнал должен нести old_key, не null.
	if item == null:
		var old_key: ItemData = key
		key = null
		item_removed.emit(old_key, SLOT_KEY)  # SLOT_KEY = 1 (ADR-0007)
		return

	# --- ШАГ 4: добавление ключа — key==null, item валиден ---
	key = item
	item_added.emit(key, SLOT_KEY)  # SLOT_KEY = 1 (ADR-0007)


## Удаляет ключ из инвентаря. Вариант no-arg для явного API удаления.
##
## Contract:
##   - Если key == null → no-op, сигналы НЕ испускаются (AC-34).
##   - Если key != null → key = null, item_removed(old_key, SLOT_KEY) испущен (AC-33).
##   - Идентичен set_key(null) по логике, но явный intent: "убрать ключ".
##
## AC-33: remove_key() при key!=null → key==null, item_removed испущен
## AC-34: remove_key() при key==null → no-op, сигналы не испускаются
func remove_key() -> void:
	# --- ШАГ 1: no-op если ключа нет (AC-34) ---
	# Удалять нечего — молча выходим, сигналы не испускаем.
	if key == null:
		return

	# --- ШАГ 2: сохранить ссылку до обнуления (AC-33) ---
	# item_removed должен нести ItemData, а не null — сохраняем до изменения поля.
	var old_key: ItemData = key
	key = null
	item_removed.emit(old_key, SLOT_KEY)  # SLOT_KEY = 1 (ADR-0007)


## Возвращает список свитков игрока (0–3 ItemData).
##
## Contract:
##   - Только чтение; не изменяет состояние.
##   - Возвращает прямую ссылку на массив (не копию) — как get_weapons().
##
## TR-player-state-006 / ADR-0013 (по аналогии с оружиями)
func get_scrolls() -> Array[ItemData]:
	return scrolls  # прямая ссылка — single source of truth


## Добавляет свиток в инвентарь.
##
## Contract:
##   - Если scrolls.size() < SCROLL_SLOTS — добавляет, испускает item_added(item, SLOT_SCROLL),
##     возвращает true.
##   - Если scrolls.size() >= SCROLL_SLOTS — возвращает false без изменений (AC-19).
##   - item не должен быть null (вызывающий гарантирует; нет null-guard по контракту).
##
## AC-19: add_scroll при scrolls.size()==3 → false, scrolls.size() не изменился
func add_scroll(item: ItemData) -> bool:
	# --- ШАГ 1: проверить наличие свободного слота (AC-19) ---
	# SCROLL_SLOTS == 3: максимум три свитка одновременно (GDD).
	if scrolls.size() >= SCROLL_SLOTS:
		return false

	# --- ШАГ 2: добавить свиток в массив ---
	scrolls.append(item)

	# --- ШАГ 3: испустить сигнал добавления (SLOT_SCROLL = 2, ADR-0007) ---
	item_added.emit(item, SLOT_SCROLL)

	return true


## Удаляет свиток из инвентаря по ссылке.
##
## Contract:
##   - Если item не найден в scrolls → push_error, scrolls не изменяется.
##   - При успехе: scrolls[idx] удаляется, item_removed(item, SLOT_SCROLL) испущен.
##
## Используется LootSystem при использовании / потере свитка.
func remove_scroll(item: ItemData) -> void:
	# --- ШАГ 1: найти свиток по ссылке ---
	# Array.find() возвращает -1 если не найден — guard против тихого no-op.
	var idx: int = scrolls.find(item)

	# --- ШАГ 2: валидация — свиток должен быть в массиве ---
	if idx == -1:
		push_error("remove_scroll: item not found in scrolls")
		return

	# --- ШАГ 3: удалить из массива ---
	scrolls.remove_at(idx)

	# --- ШАГ 4: испустить сигнал удаления ---
	item_removed.emit(item, SLOT_SCROLL)  # SLOT_SCROLL = 2 (ADR-0007)


## Заменяет свиток в инвентаре: old → new_item.
##
## Contract:
##   - Находит old в scrolls по ссылке (Array.find).
##   - Если old не найден → push_error, scrolls не изменяется.
##   - При успехе: scrolls[idx] = new_item,
##     item_removed(old, SLOT_SCROLL) + item_added(new_item, SLOT_SCROLL) испущены.
##   - Порядок сигналов: item_removed ДО item_added (по аналогии с replace_weapon — AC-17).
##
## Используется LootSystem при замене свитка (ADR-0013 паттерн).
func replace_scroll(old: ItemData, new_item: ItemData) -> void:
	# --- ШАГ 1: найти old в scrolls ---
	var idx: int = scrolls.find(old)

	# --- ШАГ 2: валидация ---
	if idx == -1:
		push_error("replace_scroll: old item not found in scrolls")
		return

	# --- ШАГ 3: заменить слот ---
	scrolls[idx] = new_item

	# --- ШАГ 4: испустить сигналы удаления old и добавления new_item ---
	# Порядок: removed ПЕРЕД added — по контракту ADR-0002 и аналогии с replace_weapon (AC-17).
	item_removed.emit(old, SLOT_SCROLL)       # SLOT_SCROLL = 2 (ADR-0007)
	item_added.emit(new_item, SLOT_SCROLL)    # SLOT_SCROLL = 2 (ADR-0007)


## Возвращает true если игрок выполнил условие победы (убил дракона).
##
## Contract:
##   - Только чтение; не изменяет состояние.
##   - Делегирует к has_killed_dragon — единственный источник истины (ADR-0003).
##   - WinConditionSystem вызывает этот метод для проверки победы — PlayerState только хранит флаг.
##
## AC-14: после mark_dragon_killed() → has_won() == true
func has_won() -> bool:
	return has_killed_dragon  # единственное условие победы в текущем дизайне (GDD win-condition.md)


## Добавляет очки победы (VP) игроку.
##
## Contract:
##   - amount должен быть >= 0.0; отрицательное — push_error, vp не изменяется (AC-30).
##   - При успехе: vp += amount, испускается vp_changed(new_vp).
##   - Нулевой amount допустим; vp_changed испускается с текущим vp (no-op по значению).
##   - Дробные значения допустимы (float — GDD позволяет 0.5 VP за сундук и т.д.).
##   - Источники VP (сундуки, дракон, бонусы) определяются LootSystem — не PlayerState.
##
## AC-29: add_vp(3.0) → add_vp(1.5) → vp==4.5, vp_changed испущен дважды (3.0, 4.5)
## AC-30: add_vp(-1.0) → push_error вызван, vp не изменился
func add_vp(amount: float) -> void:
	# --- ШАГ 1: валидация входного параметра (AC-30) ---
	# Отрицательный VP не имеет смысла — VP только накапливается, не вычитается.
	# push_error выводит в лог и возвращает управление без изменения состояния (AC-30).
	if amount < 0.0:
		push_error("add_vp: amount must be >= 0, got %f" % amount)
		return

	# --- ШАГ 2: добавить VP и испустить сигнал (AC-29) ---
	# vp_changed передаёт итоговое значение (не дельту) — HUD отображает total, не diff.
	vp += amount
	vp_changed.emit(vp)  # vp уже обновлён — слушатель получает актуальное значение


## Отмечает что игрок убил дракона. Устанавливает флаг и испускает сигнал победы.
##
## Contract:
##   - Если has_killed_dragon == false → has_killed_dragon = true, испускается won() (AC-14).
##   - Если has_killed_dragon == true → no-op, won() НЕ испускается повторно (AC-15).
##   - Терминальное состояние: once set, cannot be unset (ADR-0003).
##   - PlayerState НЕ завершает партию — WinConditionSystem получает сигнал won() и управляет flow.
##   - Не начисляет VP за дракона — это ответственность LootSystem / WinConditionSystem (GDD).
##
## AC-14: mark_dragon_killed() при has_killed_dragon==false → has_killed_dragon==true, won() испущен 1 раз
## AC-15: повторный mark_dragon_killed() при has_killed_dragon==true → no-op, won() НЕ испускается
func mark_dragon_killed() -> void:
	# --- ШАГ 1: guard — терминальное состояние (AC-15) ---
	# Если дракон уже убит — no-op. Повторный won() сломал бы WinConditionSystem.
	# Этот guard — единственная защита от double-emit: PlayerState сам отвечает за идемпотентность.
	if has_killed_dragon:
		return  # терминальное состояние — no-op (AC-15)

	# --- ШАГ 2: установить флаг и испустить сигнал победы (AC-14) ---
	# Порядок: сначала флаг, потом сигнал — слушатель может вызвать has_won() синхронно.
	has_killed_dragon = true
	won.emit()  # WinConditionSystem слушает — завершает партию (AC-14)


## Увеличивает счётчик открытых сундуков на 1.
##
## Contract:
##   - Всегда увеличивает chests_opened; не проверяет наличие ключа.
##   - Наличие ключа — ответственность LootSystem (GDD EC-22); PlayerState только считает.
##   - Не испускает сигналов — WinConditionSystem читает chests_opened напрямую при подсчёте VP.
##
## GDD EC-22: проверка ключа — ответственность LootSystem, не PlayerState
func increment_chests() -> void:
	# PlayerState не проверяет наличие ключа — это ответственность LootSystem (GDD EC-22).
	# Счётчик увеличивается безусловно при вызове: вызывающий гарантирует что ключ был.
	chests_opened += 1  # WinConditionSystem читает это поле для подсчёта VP


# ===================================================
# ПРИВАТНЫЕ МЕТОДЫ
# ===================================================

## Пересчитывает кэш attack_bonus из всех оружий в weapons.
##
## Формула (GDD): attack_bonus = Σ weapon.attack_bonus для всех weapon в weapons.
## Только оружия участвуют в формуле — свитки не учитываются (AC-03).
## При пустом weapons → attack_bonus = 0 (AC-06, EC-10 GDD).
##
## Вызывается после любого изменения weapons (add_weapon, replace_weapon).
func _recalculate_attack_bonus() -> void:
	# --- ШАГ 1: обнулить аккумулятор ---
	var bonus: int = 0

	# --- ШАГ 2: суммировать attack_bonus каждого оружия ---
	# Только элементы weapons[] участвуют — scrolls не итерируются (AC-03).
	for w: ItemData in weapons:
		bonus += w.attack_bonus  # attack_bonus — поле ItemData (ItemDatabase GDD)

	# --- ШАГ 3: записать кэш ---
	# attack_bonus хранится как кэш — не вычисляется при каждом get_attack_bonus().
	attack_bonus = bonus
