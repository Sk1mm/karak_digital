class_name PlayerStatePositionTest  # GdUnit4 тест-сюит: Story 003 Position & Retreat — set_position, get_position, retreat
extends GdUnitTestSuite  # GdUnit4 базовый класс для всех test suites

# ===================================================
# PLAYER STATE POSITION TEST — Story 003
# ===================================================
# Покрывает acceptance criteria:
#   AC-07 — set_position(Vector2i(5,7)) из board_position=Vector2i(2,3) → корректный результат
#   AC-08 — set A → set B → retreat() → board_position == A
#   AC-09 — retreat дважды без set_position → оба вызова возвращают к A; previous_board_position не меняется
#   AC-10 — take_damage(1) + retreat() при hp=3 → get_hp()==2, get_position()==A
#   AC-11 — нокаут (hp=1→take_damage) + retreat → hp==1, is_knocked_out()==true, get_position()==A
#   AC-23 — retreat() до первого set_position() → get_position()==start_tile, НЕ Vector2i(0,0)
#
# Паттерн изоляции:
#   Каждый тест создаёт собственный инстанс PlayerState через _create_player_state().
#   Инстансы регистрируются через auto_free() — GdUnit4 очищает их после каждого теста.
#   Тесты полностью детерминированы: никаких random seed, никаких time-dependent assert.
#
# Паттерн Vector2i-ассерций:
#   GdUnit4 этой версии не имеет assert_vector2i().
#   Все Vector2i сравниваются через assert_int() по компонентам x и y отдельно.
#   Вспомогательный метод _assert_vec2i_eq() инкапсулирует этот паттерн.
#
# Ключевые особенности Story 003:
#   - Поля именованы board_position / previous_board_position (не position/previous_position)
#     чтобы избежать конфликта с Node2D.position: Vector2. Решение принято в code review Story 001.
#   - start_tile — @export поле, устанавливается ДО add_child (до _ready()).
#     _ready() копирует start_tile в board_position и previous_board_position.
#   - retreat() НЕ обновляет previous_board_position (EC-05, AC-09). Дважды подряд = идемпотентно.
#
# ADR Reference: ADR-0003 (PlayerState as Node)
# TR Reference: TR-player-state-004
# Story: 003 — Position & Retreat
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


## Создаёт PlayerState с заданными параметрами, добавляет в Scene Tree (вызывает _ready()),
## регистрирует в auto_free для автоматической очистки после теста.
##
## _ready() инициализирует board_position = start_tile и previous_board_position = start_tile.
## Для тестирования позиций важно передавать start_tile ДО add_child.
##
## Contract:
##   - p_current_hp <= p_max_hp всегда (вызывающий несёт ответственность)
##   - p_player_id должен быть 1–5 (assert в _ready() упадёт иначе — тест провалится)
##   - p_start_tile: стартовая позиция; если не указана — используется Vector2i(0, 2) (default из @export)
##   - Возвращённый инстанс автоматически освобождается GdUnit4 через auto_free()
func _create_player_state(
		p_max_hp: int,
		p_current_hp: int = -1,
		p_start_tile: Vector2i = Vector2i(0, 2)) -> PlayerState:
	# --- ШАГ 1: создать инстанс (без _ready()) ---
	var ps := PlayerState.new()

	# --- ШАГ 2: настроить @export поля до добавления в дерево ---
	# Имитирует Inspector: @export назначается ДО _ready() (Godot lifecycle гарантия).
	# start_tile обязательно назначается здесь — _ready() читает его при инициализации позиции.
	ps.player_id = 1
	ps.character_class = _create_hero_class(p_max_hp)
	ps.start_tile = p_start_tile  # AC-23: start_tile задаёт начальное board_position / previous_board_position

	# --- ШАГ 3: добавить в дерево — вызывает _ready() ---
	# _ready() устанавливает: max_hp, hp, board_position = start_tile, previous_board_position = start_tile
	add_child(auto_free(ps))

	# --- ШАГ 4: опционально переопределить hp после _ready() ---
	# _ready() всегда ставит hp = max_hp; если нужно частичное здоровье — перезаписываем
	if p_current_hp >= 0:
		ps.hp = p_current_hp  # прямая запись поля — обходит сигнальную логику намеренно

	return ps


## Проверяет что два Vector2i равны, сравнивая x и y через assert_int().
## GdUnit4 этой версии не имеет assert_vector2i() — используем разложение по компонентам.
##
## Contract:
##   - Если хотя бы один компонент не совпадает — тест падает с информацией о несовпадении.
func _assert_vec2i_eq(actual: Vector2i, expected: Vector2i) -> void:
	assert_int(actual.x).is_equal(expected.x)  # x-компонент
	assert_int(actual.y).is_equal(expected.y)  # y-компонент


## Проверяет что два Vector2i НЕ равны.
## Используется для AC-23: гарантия что позиция != Vector2i(0,0).
func _assert_vec2i_ne(actual: Vector2i, not_expected: Vector2i) -> void:
	# Хотя бы один компонент должен отличаться — проверяем через bool-равенство
	assert_bool(actual == not_expected).is_false()


# ===================================================
# AC-07: set_position сохраняет previous_board_position
# ===================================================

## AC-07: set_position(Vector2i(5,7)) из board_position=Vector2i(2,3)
## → get_position()==Vector2i(5,7), previous_board_position==Vector2i(2,3).
## Инвариант: set_position всегда сохраняет текущую позицию в previous ПЕРЕД изменением.
func test_player_state_set_position_updates_position_and_saves_previous() -> void:
	# Arrange — инициализируем с known start_tile, затем устанавливаем начальную позицию
	var ps: PlayerState = _create_player_state(5)
	# Устанавливаем board_position = Vector2i(2,3) как "стартовое" состояние перед тестом
	ps.set_position(Vector2i(2, 3))  # previous_board_position == start_tile, board_position == (2,3)

	# Act — переходим на новую позицию
	ps.set_position(Vector2i(5, 7))

	# Assert — текущая позиция обновлена (AC-07)
	_assert_vec2i_eq(ps.get_position(), Vector2i(5, 7))

	# Assert — предыдущая позиция сохранена (AC-07)
	_assert_vec2i_eq(ps.previous_board_position, Vector2i(2, 3))


## AC-07 дополнение: первый set_position — previous_board_position == start_tile.
## Проверяет что после первого вызова set_position previous_board_position содержит start_tile.
func test_player_state_set_position_first_call_previous_equals_start_tile() -> void:
	# Arrange — PlayerState с start_tile=Vector2i(1,1)
	var ps: PlayerState = _create_player_state(5, -1, Vector2i(1, 1))
	# Предусловие: после _ready() board_position == start_tile == (1,1)
	_assert_vec2i_eq(ps.get_position(), Vector2i(1, 1))

	# Act
	ps.set_position(Vector2i(3, 3))

	# Assert — предыдущая позиция == start_tile (первый вызов)
	_assert_vec2i_eq(ps.previous_board_position, Vector2i(1, 1))
	_assert_vec2i_eq(ps.get_position(), Vector2i(3, 3))


# ===================================================
# AC-08: retreat() возвращает на предыдущую позицию
# ===================================================

## AC-08: set_position(A) → set_position(B) → retreat() → get_position() == A.
## Инвариант: retreat возвращает на позицию, предшествующую последнему set_position.
func test_player_state_retreat_returns_to_previous_position() -> void:
	# Arrange
	var a: Vector2i = Vector2i(3, 3)
	var b: Vector2i = Vector2i(7, 9)
	var ps: PlayerState = _create_player_state(5)
	ps.set_position(a)  # board_position = A, previous = start_tile
	ps.set_position(b)  # board_position = B, previous = A

	# Act
	ps.retreat()

	# Assert — вернулись на A (AC-08)
	_assert_vec2i_eq(ps.get_position(), a)


# ===================================================
# AC-09: retreat() дважды без промежуточного set_position
# ===================================================

## AC-09: retreat дважды без промежуточного set_position → оба вызова возвращают к A.
## Ключевой инвариант: retreat НЕ обновляет previous_board_position (EC-05).
## Двойной retreat = идемпотентная операция (не вызывает дальнейшего "отката").
func test_player_state_retreat_twice_is_idempotent() -> void:
	# Arrange: set A → set B, затем first retreat
	var a: Vector2i = Vector2i(2, 0)
	var b: Vector2i = Vector2i(5, 5)
	var ps: PlayerState = _create_player_state(5)
	ps.set_position(a)
	ps.set_position(b)

	# Act — первый retreat
	ps.retreat()
	# Assert — после первого retreat: board_position == A
	_assert_vec2i_eq(ps.get_position(), a)

	# Act — второй retreat без промежуточного set_position
	ps.retreat()
	# Assert — после второго retreat: board_position всё ещё == A (AC-09)
	_assert_vec2i_eq(ps.get_position(), a)

	# Assert — previous_board_position не изменился при retreat (EC-05, AC-09)
	# previous_board_position должен оставаться равным A (значению до второго retreat'а)
	_assert_vec2i_eq(ps.previous_board_position, a)


## AC-09 дополнение: retreat трижды подряд — поведение стабильно.
## Тройной retreat без set_position не приводит к «переходу» на ещё более раннюю позицию.
func test_player_state_retreat_triple_stays_at_previous_position() -> void:
	# Arrange
	var a: Vector2i = Vector2i(1, 4)
	var b: Vector2i = Vector2i(6, 2)
	var ps: PlayerState = _create_player_state(5)
	ps.set_position(a)
	ps.set_position(b)

	# Act — три retreat подряд
	ps.retreat()
	ps.retreat()
	ps.retreat()

	# Assert — все три вернули к A
	_assert_vec2i_eq(ps.get_position(), a)


# ===================================================
# AC-10: take_damage(1) + retreat() — HP изменился, позиция восстановлена
# ===================================================

## AC-10: take_damage(1) + retreat() при hp=3
## → get_hp()==2, get_position()==A.
## Инвариант: take_damage и retreat независимы — урон не отменяется, позиция восстанавливается.
func test_player_state_take_damage_then_retreat_restores_position() -> void:
	# Arrange: hp=3, position=B, previous=A
	var a: Vector2i = Vector2i(0, 1)
	var b: Vector2i = Vector2i(4, 6)
	var ps: PlayerState = _create_player_state(5, 3)  # hp=3, max_hp=5
	ps.set_position(a)  # board_position = A, previous = start_tile
	ps.set_position(b)  # board_position = B, previous = A

	# Act — урон, затем retreat
	ps.take_damage(1)
	ps.retreat()

	# Assert — HP уменьшен (AC-10)
	assert_int(ps.get_hp()).is_equal(2)

	# Assert — позиция восстановлена на A (AC-10)
	_assert_vec2i_eq(ps.get_position(), a)


# ===================================================
# AC-11: нокаут + retreat() — нокаут сохранён, позиция восстановлена
# ===================================================

## AC-11: hp=1, take_damage(1) → нокаут + retreat()
## → hp==1, is_knocked_out()==true, get_position()==A.
## Инвариант: retreat не снимает нокаут; позиция восстанавливается независимо от HP-состояния.
func test_player_state_knockout_then_retreat_preserves_knockout_and_restores_position() -> void:
	# Arrange: hp=1 (летальный удар → нокаут), позиция B, previous = A
	var a: Vector2i = Vector2i(2, 2)
	var b: Vector2i = Vector2i(8, 3)
	var ps: PlayerState = _create_player_state(5, 1)  # hp=1, max_hp=5
	ps.set_position(a)
	ps.set_position(b)

	# Act — летальный удар вызывает нокаут, затем retreat
	ps.take_damage(1)  # hp=1→нокаут: hp==1, skip_next_turn=true
	ps.retreat()       # board_position = previous_board_position = A

	# Assert — нокаут сохранён (AC-11)
	assert_int(ps.get_hp()).is_equal(1)
	assert_bool(ps.is_knocked_out()).is_true()

	# Assert — позиция восстановлена (AC-11)
	_assert_vec2i_eq(ps.get_position(), a)


# ===================================================
# AC-23: retreat() до первого set_position()
# ===================================================

## AC-23: retreat() до первого set_position() → get_position()==start_tile, НЕ Vector2i(0,0).
## Инвариант: _ready() инициализирует board_position = start_tile и previous_board_position = start_tile.
## Если set_position() никогда не вызывался, retreat возвращает именно на start_tile.
func test_player_state_retreat_before_set_position_returns_to_start_tile() -> void:
	# Arrange — PlayerState с явным start_tile != Vector2i(0,0); set_position НЕ вызывается
	var custom_start: Vector2i = Vector2i(0, 2)
	var ps: PlayerState = _create_player_state(5, -1, custom_start)

	# Предусловие: board_position после _ready() == start_tile
	_assert_vec2i_eq(ps.get_position(), custom_start)

	# Act — retreat без предшествующего set_position
	ps.retreat()

	# Assert — вернулись на start_tile (AC-23).
	# Позитивная проверка точного значения достаточна — покрывает и «не (0,0)» и «именно start_tile».
	_assert_vec2i_eq(ps.get_position(), custom_start)


## AC-23 дополнение: start_tile с ненулевыми координатами.
## Дополнительная верификация с явно ненулевым start_tile.
func test_player_state_retreat_before_set_position_nonzero_start_tile() -> void:
	# Arrange — start_tile с обоими ненулевыми компонентами
	var start: Vector2i = Vector2i(3, 7)
	var ps: PlayerState = _create_player_state(5, -1, start)

	# Act — retreat до первого set_position
	ps.retreat()

	# Assert — board_position == start (3,7), а не (0,0)
	_assert_vec2i_eq(ps.get_position(), start)


# ===================================================
# Дополнительный тест: get_position() после _ready() без set_position
# ===================================================

## get_position() после _ready() без set_position() → возвращает start_tile.
## Проверяет что _ready() корректно инициализирует board_position из start_tile.
func test_player_state_get_position_after_ready_equals_start_tile() -> void:
	# Arrange
	var start: Vector2i = Vector2i(5, 1)
	var ps: PlayerState = _create_player_state(5, -1, start)

	# Act + Assert — без каких-либо вызовов set_position
	_assert_vec2i_eq(ps.get_position(), start)
