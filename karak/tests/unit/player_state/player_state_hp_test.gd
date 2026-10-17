class_name PlayerStateHpTest  # GdUnit4 тест-сюит: Story 002 HP management — take_damage, heal_full, knockout
extends GdUnitTestSuite  # GdUnit4 базовый класс для всех test suites

# ===================================================
# PLAYER STATE HP TEST — Story 002
# ===================================================
# Покрывает acceptance criteria:
#   AC-12 — take_damage(1) при hp=1 → hp==1, knockout, оба сигнала испущены
#   AC-13 — нокаут не меняет board_position, weapons, key
#   AC-24 — take_damage(0) → hp не меняется, hp_changed НЕ испускается
#   AC-25 — take_damage(-1) → hp не меняется (push_error логируется, не исключение)
#   AC-26 — clear_knockout() при skip_next_turn=false → no-op, knockout_cleared НЕ испускается
#   AC-31 — heal_full() при hp=2, max_hp=5 → hp==5, hp_changed(5,5) испущен
#   AC-32 — heal_full() при hp==max_hp → no-op, hp_changed НЕ испускается
#
# Паттерн изоляции:
#   Каждый тест создаёт собственный инстанс PlayerState через _create_player_state().
#   Инстансы регистрируются через auto_free() — GdUnit4 очищает их после каждого теста.
#   Тесты полностью детерминированы: никаких random seed, никаких time-dependent assert.
#
# Паттерн signal assertion:
#   monitor_signals(ps) запускается ПЕРЕД действием.
#   assert_signal(monitor) проверяет испущен / не испущен сигнал ПОСЛЕ действия.
#   await нужен, так как GdUnit4 signal API асинхронный.
#
# ADR Reference: ADR-0002 (Typed signals)
# ADR Reference: ADR-0003 (PlayerState as Node)
# TR Reference: TR-player-state-003, TR-player-state-005
# Story: 002 — HP Management
# ===================================================


# ===================================================
# HELPERS
# ===================================================

## Создаёт минимально валидный HeroClassData для использования в тестах.
## Не сохраняется на диск — только in-memory Resource.
##
## Contract: возвращает HeroClassData с id, display_name и max_hp — минимум для
## прохождения assert(character_class != null) в PlayerState._ready().
func _create_hero_class(p_max_hp: int) -> HeroClassData:
	# HeroClassData — Resource, не требует сцены и _ready(); безопасно для unit-тестов
	var hcd := HeroClassData.new()
	hcd.max_hp = p_max_hp
	hcd.id = &"test_hero"          # StringName literal — ADR: prefer &"name" syntax
	hcd.display_name = "Test Hero"
	return hcd


## Создаёт PlayerState с заданным max_hp, добавляет в Scene Tree (вызывает _ready()),
## регистрирует в auto_free для автоматической очистки после теста.
##
## Дополнительно устанавливает hp в p_current_hp ПОСЛЕ _ready(), чтобы тестировать
## состояние частичного здоровья (например, hp=2 при max_hp=5 для AC-31).
##
## Contract:
##   - p_current_hp <= p_max_hp всегда (вызывающий несёт ответственность)
##   - p_player_id должен быть 1–5 (assert в _ready() упадёт иначе — тест провалится)
##   - Возвращённый инстанс автоматически освобождается GdUnit4 через auto_free()
func _create_player_state(p_max_hp: int, p_current_hp: int = -1) -> PlayerState:
	# --- ШАГ 1: создать инстанс (без _ready()) ---
	var ps := PlayerState.new()

	# --- ШАГ 2: настроить @export поля до добавления в дерево ---
	# Имитирует Inspector: @export назначается ДО _ready() (Godot lifecycle гарантия)
	ps.player_id = 1
	ps.character_class = _create_hero_class(p_max_hp)

	# --- ШАГ 3: добавить в дерево — вызывает _ready() который ставит hp = max_hp ---
	# auto_free() регистрирует ноду для автоматической очистки после теста
	add_child(auto_free(ps))

	# --- ШАГ 4: опционально переопределить hp после _ready() ---
	# _ready() всегда ставит hp = max_hp; если нужно частичное здоровье — перезаписываем
	if p_current_hp >= 0:
		ps.hp = p_current_hp  # прямая запись поля — обходит сигнальную логику намеренно

	return ps


# ===================================================
# AC-12: take_damage(1) при hp=1 → knockout
# ===================================================

## AC-12: take_damage(1) при hp=1 — летальный удар.
## Ожидаем: get_hp()==1 (пол минимума), is_knocked_out()==true,
##          skip_next_turn==true, сигналы knocked_out и hp_changed(1, max_hp) испущены.
##
## Инвариант (дизайн): hp никогда не падает ниже 1 — нокаут, а не смерть.
func test_player_state_take_damage_at_min_hp_triggers_knockout() -> void:
	# Arrange — hp=1, max_hp=5: один удар любой силы вызывает нокаут
	var ps: PlayerState = _create_player_state(5, 1)
	var monitor := monitor_signals(ps)

	# Act
	ps.take_damage(1)

	# Assert — состояние после нокаута
	assert_int(ps.get_hp()).is_equal(1)            # hp зафиксирован на 1 (не 0)
	assert_bool(ps.is_knocked_out()).is_true()      # is_knocked_out() отражает skip_next_turn
	assert_bool(ps.skip_next_turn).is_true()        # прямое поле тоже должно быть true

	# Assert — оба сигнала испущены (AC-12).
	# is_emitted() без аргументов в GdUnit4 ожидает сигнал БЕЗ аргументов.
	# hp_changed всегда испускается с (new_hp: int, max_hp: int) — нужно передавать аргументы.
	# knocked_out не имеет аргументов — is_emitted() без аргументов корректно.
	# Точные значения hp_changed верифицируются в следующем тест-кейсе.
	await assert_signal(monitor).is_emitted("hp_changed", [1, 5])
	await assert_signal(monitor).is_emitted("knocked_out")


## AC-12 дополнение: hp_changed испущен с корректными аргументами (new_hp=1, max_hp=5).
## Отдельная функция — assert_signal с аргументами изолирован от проверки состояния.
func test_player_state_take_damage_at_min_hp_emits_hp_changed_with_correct_args() -> void:
	# Arrange
	var ps: PlayerState = _create_player_state(5, 1)
	var monitor := monitor_signals(ps)

	# Act
	ps.take_damage(1)

	# Assert — hp_changed испущен с new_hp=1 и max_hp=5
	await assert_signal(monitor).is_emitted("hp_changed", [1, 5])


# ===================================================
# AC-12 дополнение: порядок сигналов hp_changed → knocked_out
# ===================================================

## AC-12 порядок: при нокауте hp_changed испускается ПЕРЕД knocked_out.
## Это контрактный инвариант (см. player_state.gd строки 284–285): HUD должен получить
## hp_changed и обновить UI ДО того, как KnockoutSystem реагирует на knocked_out.
## Регрессия: если порядок перепутается — HUD покажет старый hp во время обработки нокаута.
##
## GdUnit4 assert_signal не поддерживает is_emitted_before() — используем lambda-счётчик:
## подключаемся к сигналам напрямую и заполняем массив порядка вызовов.
func test_player_state_knockout_emits_hp_changed_before_knocked_out() -> void:
	# Arrange — подключить счётчик порядка ДО действия
	var ps: PlayerState = _create_player_state(5, 1)
	var order: Array[String] = []  # заполняется в порядке испускания сигналов

	ps.hp_changed.connect(func(_new_hp: int, _max_hp: int) -> void:
		order.append("hp_changed"))

	ps.knocked_out.connect(func() -> void:
		order.append("knocked_out"))

	# Act
	ps.take_damage(1)

	# Assert — оба сигнала испущены в правильном порядке (ADR-0003 сигнальный контракт)
	assert_array(order).is_equal(["hp_changed", "knocked_out"])


# ===================================================
# AC-13: нокаут не меняет board_position, weapons, key
# ===================================================

## AC-13: после нокаута board_position, weapons и key остаются неизменными.
## take_damage изменяет ТОЛЬКО hp, skip_next_turn и испускает сигналы.
## Инвентарь и позиция — ответственность KnockoutSystem, не PlayerState.take_damage.
func test_player_state_knockout_preserves_position_weapons_key() -> void:
	# Arrange — расставляем непустое состояние инвентаря и позиции
	var ps: PlayerState = _create_player_state(5, 1)

	var sword := ItemData.new()
	sword.id = &"sword_basic"
	sword.attack_bonus = 2

	var key := ItemData.new()
	key.id = &"key"

	ps.board_position = Vector2i(3, 4)
	ps.weapons.append(sword)
	ps.key = key

	# Запоминаем исходные значения
	var pos_before: Vector2i = ps.board_position
	var weapons_size_before: int = ps.weapons.size()

	# Act — наносим летальный удар (нокаут)
	ps.take_damage(1)

	# Assert — всё кроме hp и skip_next_turn не изменилось (AC-13)
	assert_int(ps.board_position.x).is_equal(pos_before.x)
	assert_int(ps.board_position.y).is_equal(pos_before.y)
	assert_int(ps.weapons.size()).is_equal(weapons_size_before)
	assert_object(ps.key).is_not_null()
	assert_object(ps.key).is_equal(key)


# ===================================================
# AC-24: take_damage(0) — no-op
# ===================================================

## AC-24: take_damage(0) — ноль урона, hp не меняется, сигнал hp_changed НЕ испускается.
## Нулевой удар не является событием — сигнал ЗАПРЕЩЁН согласно инварианту.
func test_player_state_take_damage_zero_is_noop() -> void:
	# Arrange
	var ps: PlayerState = _create_player_state(5, 3)
	var monitor := monitor_signals(ps)

	# Act
	ps.take_damage(0)

	# Assert — hp не изменился
	assert_int(ps.get_hp()).is_equal(3)

	# Assert — сигнал hp_changed НЕ испущен (AC-24)
	await assert_signal(monitor).is_not_emitted("hp_changed")


# ===================================================
# AC-25: take_damage(-1) — ошибка, hp не меняется
# ===================================================

## AC-25: take_damage(-1) — отрицательный урон запрещён.
## push_error вызывается (выводит в лог, НЕ бросает исключение в GDScript),
## hp остаётся неизменным. Сигналы не испускаются.
##
## GdUnit4 6.x: assert_error(callable).is_push_error(msg) — принимает Callable.
## Callable оборачивает вызов, который должен вызвать push_error.
## Тест провалится если push_error НЕ был вызван (пустой no-op тоже провалит тест).
func test_player_state_take_damage_negative_is_error() -> void:
	# Arrange
	var ps: PlayerState = _create_player_state(5, 4)
	var monitor := monitor_signals(ps)

	# Assert — push_error вызван с корректным сообщением (AC-25).
	# assert_error() оборачивает вызов в Callable: верифицирует что именно push_error
	# был вызван, а не просто что hp не изменился (тест не пройдёт при тихом no-op).
	await assert_error(func() -> void: ps.take_damage(-1)) \
		.is_push_error("take_damage: amount must be >= 0, got -1")

	# Assert — hp не изменился после отрицательного урона (AC-25)
	assert_int(ps.get_hp()).is_equal(4)

	# Assert — никакой сигнал не испущен
	await assert_signal(monitor).is_not_emitted("hp_changed")
	await assert_signal(monitor).is_not_emitted("knocked_out")


# ===================================================
# AC-26: clear_knockout() при skip_next_turn=false — no-op
# ===================================================

## AC-26: clear_knockout() когда игрок не в нокауте (skip_next_turn=false) — no-op.
## Метод не меняет состояние и НЕ испускает knockout_cleared.
func test_player_state_clear_knockout_on_live_player_is_noop() -> void:
	# Arrange — стандартный игрок, не в нокауте (skip_next_turn по умолчанию false)
	var ps: PlayerState = _create_player_state(5, 4)
	assert_bool(ps.skip_next_turn).is_false()  # предусловие: не в нокауте

	var monitor := monitor_signals(ps)

	# Act
	ps.clear_knockout()

	# Assert — состояние не изменилось
	assert_bool(ps.skip_next_turn).is_false()

	# Assert — сигнал knockout_cleared НЕ испущен (AC-26)
	await assert_signal(monitor).is_not_emitted("knockout_cleared")


## AC-26 дополнение: clear_knockout() при skip_next_turn=true — испускает knockout_cleared.
## Проверяет позитивный путь: сигнал испускается только когда реально была очистка.
func test_player_state_clear_knockout_on_knocked_out_player_emits_signal() -> void:
	# Arrange — игрок в нокауте: принудительно устанавливаем skip_next_turn
	var ps: PlayerState = _create_player_state(5, 1)
	ps.skip_next_turn = true  # симулируем нокаут без вызова take_damage
	var monitor := monitor_signals(ps)

	# Act
	ps.clear_knockout()

	# Assert — флаг снят
	assert_bool(ps.skip_next_turn).is_false()

	# Assert — сигнал knockout_cleared испущен
	await assert_signal(monitor).is_emitted("knockout_cleared")


# ===================================================
# AC-31: heal_full() при частичном здоровье
# ===================================================

## AC-31: heal_full() при hp=2, max_hp=5 → hp становится 5, hp_changed(5,5) испущен.
## Полное лечение восстанавливает HP до максимума и уведомляет слушателей.
func test_player_state_heal_full_restores_hp() -> void:
	# Arrange — частичное здоровье: hp=2 из 5
	var ps: PlayerState = _create_player_state(5, 2)
	var monitor := monitor_signals(ps)

	# Act
	ps.heal_full()

	# Assert — hp восстановлен до максимума (AC-31)
	assert_int(ps.get_hp()).is_equal(5)

	# Assert — hp_changed(5, 5) испущен
	await assert_signal(monitor).is_emitted("hp_changed", [5, 5])


## AC-31 дополнение: heal_full() при hp=1 (после нокаута) восстанавливает до max_hp.
## Проверяет поведение при минимальном стартовом HP (граничный случай).
func test_player_state_heal_full_from_knockout_hp_restores_to_max() -> void:
	# Arrange — hp=1 (типичное состояние после нокаута), max_hp=5
	var ps: PlayerState = _create_player_state(5, 1)
	var monitor := monitor_signals(ps)

	# Act
	ps.heal_full()

	# Assert
	assert_int(ps.get_hp()).is_equal(5)
	await assert_signal(monitor).is_emitted("hp_changed", [5, 5])


# ===================================================
# AC-32: heal_full() при hp==max_hp — no-op
# ===================================================

## AC-32: heal_full() когда hp уже на максимуме — no-op.
## Метод не меняет HP и НЕ испускает hp_changed (нет реального изменения).
func test_player_state_heal_full_at_max_is_noop() -> void:
	# Arrange — PlayerState после _ready() имеет hp == max_hp (5 == 5)
	var ps: PlayerState = _create_player_state(5)  # hp останется 5 (max)
	assert_int(ps.get_hp()).is_equal(5)  # предусловие: уже на максимуме

	var monitor := monitor_signals(ps)

	# Act
	ps.heal_full()

	# Assert — hp не изменился (AC-32)
	assert_int(ps.get_hp()).is_equal(5)

	# Assert — сигнал hp_changed НЕ испущен (AC-32)
	await assert_signal(monitor).is_not_emitted("hp_changed")


# ===================================================
# Дополнительный тест: нормальный урон без нокаута
# ===================================================

## Нормальный урон (не летальный): hp уменьшается на amount, hp_changed испущен,
## knocked_out НЕ испущен, skip_next_turn остаётся false.
## Проверяет основной (не-граничный) путь take_damage.
func test_player_state_take_damage_normal_reduces_hp_and_emits_hp_changed() -> void:
	# Arrange — hp=5, max_hp=5; наносим 2 урона (не летальный)
	var ps: PlayerState = _create_player_state(5, 5)
	var monitor := monitor_signals(ps)

	# Act
	ps.take_damage(2)

	# Assert — hp уменьшился корректно
	assert_int(ps.get_hp()).is_equal(3)
	assert_bool(ps.is_knocked_out()).is_false()
	assert_bool(ps.skip_next_turn).is_false()

	# Assert — hp_changed испущен с корректными аргументами, knocked_out НЕ испущен
	await assert_signal(monitor).is_emitted("hp_changed", [3, 5])
	await assert_signal(monitor).is_not_emitted("knocked_out")
