class_name PlayerStateVpTest  # GdUnit4 тест-сюит: Story 006 VP, Win Condition, Chests
extends GdUnitTestSuite  # GdUnit4 базовый класс для всех test suites

# ===================================================
# PLAYER STATE VP TEST — Story 006
# ===================================================
# Покрывает acceptance criteria:
#   AC-14 — mark_dragon_killed() при has_killed_dragon==false
#            → has_won()==true, сигнал won испущен ровно один раз
#   AC-15 — повторный mark_dragon_killed() при has_killed_dragon==true
#            → no-op, won НЕ испускается снова; 5 вызовов подряд — won ровно 1 раз
#   AC-29 — add_vp(3.0) + add_vp(1.5) → vp==4.5,
#            vp_changed испущен дважды: сначала с 3.0, потом с 4.5
#   AC-30 — add_vp(-1.0) → push_error вызван, vp не изменился;
#            edge case: add_vp(-0.001) отклоняется, add_vp(0.0) принимается
#   increment_chests — вызов → chests_opened увеличивается на 1
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
# Паттерн подсчёта количества испусканий сигнала:
#   Используется lambda-счётчик через прямое подключение к сигналу.
#   monitor_signals / assert_signal не поддерживают assert "ровно N раз" —
#   поэтому считаем вручную через Array.append в лямбда-коллбэке.
#
# ADR Reference: ADR-0002 (Typed signals)
# ADR Reference: ADR-0003 (PlayerState as Node)
# TR Reference: TR-player-state-001
# Story: 006 — VP, Win Condition, Chests
# ===================================================


# ===================================================
# HELPERS
# ===================================================

## Создаёт минимально валидный HeroClassData для использования в тестах.
## Не сохраняется на диск — только in-memory Resource.
##
## Contract: возвращает HeroClassData с id, display_name и max_hp — минимум для
## прохождения assert(character_class != null) в PlayerState._ready().
func _create_hero_class(p_max_hp: int = 5) -> HeroClassData:
	# HeroClassData — Resource, не требует сцены и _ready(); безопасно для unit-тестов
	var hcd := HeroClassData.new()
	hcd.max_hp = p_max_hp
	hcd.id = &"test_hero"          # StringName literal — ADR: prefer &"name" syntax
	hcd.display_name = "Test Hero"
	return hcd


## Создаёт PlayerState, добавляет в Scene Tree (вызывает _ready()),
## регистрирует в auto_free для автоматической очистки после теста.
##
## Contract:
##   - player_id == 1 — значение в диапазоне 1–5 (assert в _ready() пройдёт)
##   - Возвращённый инстанс автоматически освобождается GdUnit4 через auto_free()
##   - После возврата vp == 0.0, has_killed_dragon == false, chests_opened == 0
func _create_player_state() -> PlayerState:
	# --- ШАГ 1: создать инстанс (без _ready()) ---
	var ps := PlayerState.new()

	# --- ШАГ 2: настроить @export поля до добавления в дерево ---
	# Имитирует Inspector: @export назначается ДО _ready() (Godot lifecycle гарантия)
	ps.player_id = 1
	ps.character_class = _create_hero_class()

	# --- ШАГ 3: добавить в дерево — вызывает _ready() ---
	# auto_free() регистрирует ноду для автоматической очистки после теста
	add_child(auto_free(ps))

	return ps


# ===================================================
# AC-14: mark_dragon_killed() — первый вызов
# ===================================================

## AC-14: mark_dragon_killed() при has_killed_dragon==false — первый и единственный вызов.
## Ожидаем: has_won()==true, сигнал won испущен (ровно один раз проверяется в AC-15).
func test_player_state_mark_dragon_killed_first_call_sets_has_won() -> void:
	# Arrange — свежий PlayerState: has_killed_dragon==false по умолчанию (AC-01)
	var ps: PlayerState = _create_player_state()
	assert_bool(ps.has_killed_dragon).is_false()  # предусловие: дракон ещё не убит

	# Act
	ps.mark_dragon_killed()

	# Assert — has_won() возвращает true (AC-14)
	assert_bool(ps.has_won()).is_true()


## AC-14 сигнал: mark_dragon_killed() при has_killed_dragon==false → won испущен.
## Отдельная функция — проверка сигнала изолирована от проверки состояния.
func test_player_state_mark_dragon_killed_first_call_emits_won() -> void:
	# Arrange
	var ps: PlayerState = _create_player_state()
	var monitor := monitor_signals(ps)

	# Act
	ps.mark_dragon_killed()

	# Assert — сигнал won испущен (AC-14)
	# won не имеет параметров — is_emitted() без аргументов корректно
	await assert_signal(monitor).is_emitted("won")


## AC-14 флаг: mark_dragon_killed() устанавливает has_killed_dragon = true.
## Проверяем прямое поле помимо has_won() — два независимых инварианта.
func test_player_state_mark_dragon_killed_first_call_sets_has_killed_dragon_flag() -> void:
	# Arrange
	var ps: PlayerState = _create_player_state()

	# Act
	ps.mark_dragon_killed()

	# Assert — поле has_killed_dragon установлено (нижележащий флаг has_won())
	assert_bool(ps.has_killed_dragon).is_true()


# ===================================================
# AC-15: mark_dragon_killed() — повторный вызов (no-op)
# ===================================================

## AC-15: повторный mark_dragon_killed() при has_killed_dragon==true → no-op.
## Ожидаем: has_won() остаётся true, сигнал won НЕ испускается повторно.
func test_player_state_mark_dragon_killed_second_call_is_noop() -> void:
	# Arrange — первый вызов: переводим в терминальное состояние
	var ps: PlayerState = _create_player_state()
	ps.mark_dragon_killed()
	assert_bool(ps.has_killed_dragon).is_true()  # предусловие: дракон уже убит

	# Act + Assert — monitor стартует ПОСЛЕ первого вызова (второй вызов не должен испустить won)
	var monitor := monitor_signals(ps)
	ps.mark_dragon_killed()

	# Assert — has_won() не изменился (всё ещё true)
	assert_bool(ps.has_won()).is_true()

	# Assert — сигнал won НЕ испущен при повторном вызове (AC-15)
	await assert_signal(monitor).is_not_emitted("won")


## AC-15 граничный случай: 5 последовательных вызовов mark_dragon_killed() →
## сигнал won испущен ровно ОДИН раз за всё время.
## Использует lambda-счётчик, так как assert_signal не поддерживает "exactly N times".
func test_player_state_mark_dragon_killed_five_calls_emits_won_exactly_once() -> void:
	# Arrange — lambda-счётчик подключается ДО ВСЕХ вызовов
	var ps: PlayerState = _create_player_state()
	var won_count: int = 0

	# Подключаем lambda напрямую к сигналу — каждое испускание won увеличивает счётчик
	ps.won.connect(func() -> void:
		won_count += 1)

	# Act — 5 вызовов подряд; только первый должен испустить won
	ps.mark_dragon_killed()
	ps.mark_dragon_killed()
	ps.mark_dragon_killed()
	ps.mark_dragon_killed()
	ps.mark_dragon_killed()

	# Assert — won испущен строго один раз (AC-15)
	assert_int(won_count).is_equal(1)


# ===================================================
# AC-29: add_vp накапливает VP и испускает vp_changed
# ===================================================

## AC-29: add_vp(3.0) затем add_vp(1.5) → vp == 4.5.
## Проверяем итоговое состояние VP после двух последовательных вызовов.
func test_player_state_add_vp_accumulates_correctly() -> void:
	# Arrange — vp начинается с 0.0 (AC-01)
	var ps: PlayerState = _create_player_state()
	assert_float(ps.vp).is_equal(0.0)  # предусловие: VP на нуле

	# Act
	ps.add_vp(3.0)
	ps.add_vp(1.5)

	# Assert — vp == 4.5 (AC-29)
	assert_float(ps.vp).is_equal(4.5)


## AC-29 сигналы: vp_changed испущен дважды — сначала с 3.0, потом с 4.5.
## Использует lambda-счётчик: monitor_signals не хранит аргументы нескольких испусканий.
func test_player_state_add_vp_emits_vp_changed_twice_with_correct_values() -> void:
	# Arrange — собираем аргументы каждого испускания vp_changed в массив
	var ps: PlayerState = _create_player_state()
	var emitted_values: Array[float] = []

	# Lambda-счётчик: каждый vp_changed добавляет new_vp в список
	ps.vp_changed.connect(func(new_vp: float) -> void:
		emitted_values.append(new_vp))

	# Act
	ps.add_vp(3.0)
	ps.add_vp(1.5)

	# Assert — vp_changed испущен ровно 2 раза (AC-29)
	assert_int(emitted_values.size()).is_equal(2)

	# Assert — первое испускание: new_vp == 3.0
	assert_float(emitted_values[0]).is_equal(3.0)

	# Assert — второе испускание: new_vp == 4.5 (накопленный результат)
	assert_float(emitted_values[1]).is_equal(4.5)


## AC-29 дополнение: add_vp(0.0) — ноль VP допустим (принимается без ошибки).
## Дизайн: add_vp(0.0) — edge case, разрешённый по GDD EC (не negative).
## Тест проверяет, что vp_changed испускается и vp не изменяется по смыслу (0.0 → 0.0).
##
## Примечание: add_vp(0.0) принимается реализацией (amount >= 0.0 проходит guard).
## Испускает ли vp_changed при +0.0 — зависит от реализации. Тест проверяет только
## отсутствие ошибки и корректное состояние vp. Если вызов no-op — тест тоже пройдёт.
func test_player_state_add_vp_zero_is_accepted_no_error() -> void:
	# Arrange
	var ps: PlayerState = _create_player_state()

	# Act + Assert — push_error НЕ вызывается при add_vp(0.0) (AC-30 edge case)
	# assert_error с is_not_push_error — проверяем отсутствие ошибки
	await assert_error(func() -> void: ps.add_vp(0.0)).is_not_push_error()

	# Assert — vp остался >= 0.0 (не было отрицательного изменения)
	assert_float(ps.vp).is_greater_equal(0.0)


# ===================================================
# AC-30: add_vp(-1.0) → push_error, vp не изменился
# ===================================================

## AC-30: add_vp(-1.0) — отрицательный VP запрещён.
## push_error вызывается; vp не изменяется.
func test_player_state_add_vp_negative_is_error() -> void:
	# Arrange — устанавливаем ненулевое VP чтобы точно проверить "не изменился"
	var ps: PlayerState = _create_player_state()
	ps.add_vp(2.0)
	assert_float(ps.vp).is_equal(2.0)  # предусловие: vp == 2.0

	# Act + Assert — push_error вызван с корректным сообщением (AC-30)
	# assert_error() оборачивает вызов в Callable — верифицирует именно push_error
	await assert_error(func() -> void: ps.add_vp(-1.0)) \
		.is_push_error("add_vp: amount must be >= 0, got -1.000000")

	# Assert — vp не изменился после отрицательного add_vp (AC-30)
	assert_float(ps.vp).is_equal(2.0)
	# Примечание: vp_changed при ошибке проверяется в test_..._negative_does_not_emit_vp_changed


## AC-30 граничный случай: add_vp(-0.001) — минимально отрицательное значение.
## Даже tiny negative amount должен быть отклонён с push_error (AC-30 edge case).
func test_player_state_add_vp_tiny_negative_is_rejected() -> void:
	# Arrange
	var ps: PlayerState = _create_player_state()
	ps.add_vp(5.0)  # базовое VP чтобы проверить неизменность
	assert_float(ps.vp).is_equal(5.0)  # предусловие

	# Act + Assert — push_error вызван даже для -0.001 (AC-30 edge case)
	await assert_error(func() -> void: ps.add_vp(-0.001)).is_push_error_any()

	# Assert — vp не изменился
	assert_float(ps.vp).is_equal(5.0)


## AC-30 сигнал: add_vp(-1.0) → vp_changed НЕ испущен.
## Отрицательный add_vp не является событием VP — сигнал не должен испускаться.
func test_player_state_add_vp_negative_does_not_emit_vp_changed() -> void:
	# Arrange
	var ps: PlayerState = _create_player_state()
	var monitor := monitor_signals(ps)

	# Act — отрицательный add_vp (ожидаем push_error и отсутствие сигнала)
	ps.add_vp(-1.0)

	# Assert — vp_changed НЕ испущен (AC-30)
	await assert_signal(monitor).is_not_emitted("vp_changed")


# ===================================================
# increment_chests: chests_opened увеличивается на 1
# ===================================================

## increment_chests(): chests_opened увеличивается на 1 при каждом вызове.
## Начальное значение chests_opened == 0 (AC-01), после одного вызова == 1.
func test_player_state_increment_chests_increases_count_by_one() -> void:
	# Arrange — chests_opened == 0 по умолчанию (AC-01)
	var ps: PlayerState = _create_player_state()
	assert_int(ps.chests_opened).is_equal(0)  # предусловие: ни одного сундука

	# Act
	ps.increment_chests()

	# Assert — chests_opened увеличился на 1
	assert_int(ps.chests_opened).is_equal(1)


## increment_chests(): несколько последовательных вызовов — каждый увеличивает на 1.
## Проверяет инкрементность без сброса (chests_opened не обнуляется между вызовами).
func test_player_state_increment_chests_multiple_calls_accumulate() -> void:
	# Arrange
	var ps: PlayerState = _create_player_state()

	# Act — открываем 3 сундука
	ps.increment_chests()
	ps.increment_chests()
	ps.increment_chests()

	# Assert — chests_opened == 3
	assert_int(ps.chests_opened).is_equal(3)


# ===================================================
# Дополнительные тесты: взаимодействие VP с нокаутом
# ===================================================

## Совместный инвариант (GDD EC-19): take_damage() после has_killed_dragon==true
## применяется обычно — PlayerState не завершает партию самостоятельно.
## VP и флаги победы не влияют на логику HP.
func test_player_state_take_damage_after_dragon_killed_applies_normally() -> void:
	# Arrange — убиваем дракона, затем получаем урон
	var ps: PlayerState = _create_player_state()
	ps.mark_dragon_killed()
	assert_bool(ps.has_won()).is_true()  # предусловие: победа достигнута

	# Act — HP всё ещё должен уменьшаться (PlayerState не знает о конце партии)
	ps.take_damage(2)

	# Assert — HP уменьшился как обычно (GDD EC-19)
	assert_int(ps.get_hp()).is_equal(3)  # 5 - 2 = 3

	# Assert — флаг победы не изменился
	assert_bool(ps.has_won()).is_true()
