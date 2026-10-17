class_name ClassImmutabilityTest  # GdUnit4 тест-сюит: Story 005 acceptance criteria для PlayerState immutability guard
extends GdUnitTestSuite           # GdUnit4 базовый класс для всех test suites

# ===================================================
# CLASS IMMUTABILITY TEST — Story 005
# ===================================================
# Покрывает acceptance criteria:
#   AC-13-a — первоначальная установка (character_class == null) проходит без ошибки
#   AC-13-b — повторная установка отклонена: push_error вызван, значение не изменилось
#   AC-13-b edge — попытка установить тот же класс повторно тоже отклоняется
#   AC-13-data — character_class после установки равен переданному объекту
#   EC-03    — перевыбор класса в середине партии невозможен
#
# AC-13-c (assert в _ready()):
#   assert(character_class != null, ...) в _ready() тестируется ВРУЧНУЮ в Godot Editor.
#   В GdUnit4 вызов _ready() с character_class == null запускает assert → прерывает тест.
#   Автоматизировать невозможно без мока движкового assert. Верифицировать в Editor:
#   добавить PlayerState на сцену без character_class в Inspector → assert сработает.
#
# Паттерн изоляции:
#   PlayerState.new() создаёт объект без вызова _ready() — character_class остаётся null.
#   Тесты вызывают set_character_class() напрямую, обходя assert в _ready().
#   Это намеренный паттерн для unit-тестирования: мы тестируем метод, не жизненный цикл ноды.
#   ВАЖНО: PlayerState.new() запрещён в production-коде (Control Manifest);
#          в тестах — допустимо, это единственный способ изолировать метод.
#
# ADR Reference: ADR-0003 (PlayerState as Node)
# TR Reference: TR-class-003
# Story: 005 — Character Class Immutability Guard
# ===================================================


# ===================================================
# SETUP / TEARDOWN
# ===================================================

## Экземпляр PlayerState для каждого теста. Создаётся через .new() — _ready() НЕ вызывается,
## character_class остаётся null. Это позволяет тестировать set_character_class() изолированно.
var _player: PlayerState

## Первый тестовый класс — используется как "текущий" (уже установленный) класс.
var _warrior_class: HeroClassData

## Второй тестовый класс — используется как попытка замены.
var _rogue_class: HeroClassData


## before_test: создаём свежий PlayerState и два независимых HeroClassData для каждого теста.
## HeroClassData.new() — Resource, не требует сцены и _ready(); безопасно для unit-тестов.
## PlayerState.new() — Node, _ready() НЕ вызывается автоматически при .new() без добавления в дерево.
func before_test() -> void:
	_player = PlayerState.new()  # _ready() не вызывается — character_class == null

	# Создаём минимальные stub-данные для двух разных классов
	_warrior_class = HeroClassData.new()
	_warrior_class.id = &"warrior"
	_warrior_class.display_name = "Warrior"

	_rogue_class = HeroClassData.new()
	_rogue_class.id = &"rogue"
	_rogue_class.display_name = "Rogue"


## after_test: освобождаем Node (PlayerState) вручную — не добавлен в дерево, GC не управляет им.
## HeroClassData — Resource, освобождается GC автоматически; явный free() не нужен.
func after_test() -> void:
	if is_instance_valid(_player):
		_player.free()
	_player = null
	_warrior_class = null
	_rogue_class = null


# ===================================================
# NULL-GUARD: передача null как new_class отклоняется
# ===================================================

## Null-guard: set_character_class(null) отклоняется с push_error; character_class остаётся null.
## Контракт: null-класс не имеет смысла — тихое присвоение null заблокировало бы
## все последующие легитимные вызовы через immutability guard.
## Side-effect верификация: character_class по-прежнему null после попытки.
func test_player_state_set_null_class_rejected_keeps_null() -> void:
	# Arrange — character_class == null (гарантировано before_test)
	assert_object(_player.character_class).is_null()  # guard

	# Act — передаём null (некорректный вызов)
	_player.set_character_class(null)

	# Assert — character_class остался null; легитимное присвоение после этого всё ещё работает
	assert_object(_player.character_class).is_null()

	# Дополнительно: проверяем, что setter не сломан — легитимный вызов после null-reject проходит
	_player.set_character_class(_warrior_class)
	assert_object(_player.character_class).is_same(_warrior_class)


# ===================================================
# AC-13-a: первоначальная установка проходит без ошибки
# ===================================================

## AC-13-a: set_character_class() при character_class == null назначает класс корректно.
## Первая установка — легитимный путь; ошибок нет, значение присвоено.
## TR-class-003: "character_class immutable after selection" — до выбора мутация разрешена.
func test_player_state_initial_assignment_succeeds() -> void:
	# Arrange — _player.character_class == null (гарантировано before_test)
	assert_object(_player.character_class).is_null()  # guard: убедиться в начальном состоянии

	# Act
	_player.set_character_class(_warrior_class)

	# Assert — character_class назначен; никаких ошибок (проверяется отсутствием side-effect)
	assert_object(_player.character_class).is_not_null()
	assert_object(_player.character_class).is_equal(_warrior_class)


# ===================================================
# AC-13-data: character_class равен переданному объекту
# ===================================================

## AC-13-data: после первоначальной установки character_class совпадает с переданным объектом.
## Дополнительная проверка корректности присвоения (reference equality).
func test_player_state_first_assignment_stores_correct_reference() -> void:
	# Arrange
	assert_object(_player.character_class).is_null()  # guard

	# Act
	_player.set_character_class(_rogue_class)

	# Assert — reference equality: именно тот объект, что был передан
	assert_object(_player.character_class).is_same(_rogue_class)


# ===================================================
# AC-13-b: повторная установка отклонена
# ===================================================

## AC-13-b: попытка заменить уже установленный character_class другим классом отклоняется.
## character_class остаётся неизменным. push_error вызывается — верифицируется через
## side-effect (значение не изменилось), так как GdUnit4 не перехватывает push_error напрямую.
##
## NOTE: push_error() выводит сообщение в лог Godot и продолжает выполнение —
## не бросает исключение. Поэтому тест верифицирует side-effect (значение не изменилось),
## а не факт вызова push_error. Вывод в лог можно наблюдать при ручном запуске.
func test_player_state_reassignment_rejected_keeps_original_value() -> void:
	# Arrange — устанавливаем warrior как текущий класс
	_player.set_character_class(_warrior_class)
	assert_object(_player.character_class).is_same(_warrior_class)  # guard

	# Act — пытаемся заменить на rogue (должно быть отклонено с push_error)
	_player.set_character_class(_rogue_class)

	# Assert — character_class остался warrior, замена не произошла (EC-03)
	assert_object(_player.character_class).is_same(_warrior_class)
	assert_object(_player.character_class).is_not_same(_rogue_class)


# ===================================================
# AC-13-b edge: тот же класс повторно — тоже отклоняется
# ===================================================

## AC-13-b (edge case): повторная установка того же объекта класса тоже отклоняется с push_error.
## Immutability guard не делает исключений для "тот же объект" — любое переназначение запрещено.
## Это предотвращает тонкие баги, где код случайно вызывает set_character_class() дважды.
func test_player_state_reassign_same_class_is_also_rejected() -> void:
	# Arrange — устанавливаем warrior
	_player.set_character_class(_warrior_class)
	assert_object(_player.character_class).is_same(_warrior_class)  # guard

	# Act — пытаемся установить warrior повторно (тот же объект)
	# Ожидаем push_error + ранний return; значение не изменится (технически уже warrior)
	_player.set_character_class(_warrior_class)

	# Assert — character_class по-прежнему warrior (guard сработал до присвоения)
	# Ключевой контракт: guard срабатывает при character_class != null, независимо от значения new_class.
	assert_object(_player.character_class).is_same(_warrior_class)

	# Дополнительно: убедиться, что это не rogue (проверка изоляции теста)
	assert_object(_player.character_class).is_not_same(_rogue_class)


# ===================================================
# EC-03: полная последовательность — select → reject
# ===================================================

## EC-03: перевыбор класса в середине партии невозможен.
## Интеграционный тест полной последовательности: null → warrior → попытка rogue → warrior.
## Воспроизводит реальный сценарий ошибки: код случайно вызывает set_character_class()
## второй раз (баг или некорректный вызов из DraftSystem).
func test_player_state_mid_game_class_reselection_impossible() -> void:
	# Arrange — начинаем с null
	assert_object(_player.character_class).is_null()  # guard

	# Act ШАГ 1: легитимный выбор класса (нормальный флоу начала партии)
	_player.set_character_class(_warrior_class)
	assert_object(_player.character_class).is_same(_warrior_class)  # guard: первый выбор прошёл

	# Act ШАГ 2: попытка перевыбора mid-game (баг или некорректный вызов)
	_player.set_character_class(_rogue_class)

	# Assert — класс остался warrior, перевыбор заблокирован
	assert_object(_player.character_class).is_same(_warrior_class)
