class_name ClassRegistryInitTest  # GdUnit4 тест-сюит: Story 003 acceptance criteria для ClassRegistry
extends GdUnitTestSuite           # GdUnit4 базовый класс для всех test suites

# ===================================================
# CLASS REGISTRY INIT TEST — Story 003
# ===================================================
# Покрывает acceptance criteria:
#   AC-01 — get_all_classes() возвращает ровно 7 HeroClassData объектов
#   AC-01 — все 7 объектов имеют уникальные id (нет дубликатов)
#   AC-02 — get_class(id) возвращает правильный объект по ID
#   AC-03 — get_class(&"nonexistent") возвращает null, без краша
#   AC-04 — get_class(&"") возвращает null, без краша
#   AC-05 — все объекты в get_all_classes() являются экземплярами HeroClassData
#
# Паттерн для тестирования Autoload:
#   Используем ClassRegistry Autoload напрямую — он уже инициализирован Godot.
#   class_name ClassRegistry удалён из class_registry.gd (naming conflict с Autoload
#   в Godot 4.7 — expression "ClassRegistry" резолвился на GDScriptNativeClass).
#   ClassRegistry READ-ONLY → shared singleton безопасен в тестах.
#
# ADR Reference: ADR-0001 (Foundation Layer)
# Story: 003 — ClassRegistry Autoload
# ===================================================

# ===================================================
# SETUP / TEARDOWN
# ===================================================

## Ссылка на Autoload-синглтон ClassRegistry. Тип Variant — не :ClassRegistry,
## т.к. class_name удалён из скрипта для устранения naming conflict с Autoload.
var _registry  # фактически ClassRegistry Autoload node


## before_test: присваивает Autoload-синглтон ClassRegistry.
## ClassRegistry READ-ONLY → shared singleton безопасен в тестах.
func before_test() -> void:
	_registry = ClassRegistry  # Autoload singleton — уже инициализирован Godot


## after_test: обнуляем ссылку — НЕ освобождаем (это Autoload singleton).
func after_test() -> void:
	_registry = null


# ===================================================
# AC-01: get_all_classes() возвращает ровно 7 объектов
# ===================================================

## AC-01: get_all_classes() должен возвращать ровно 7 HeroClassData объектов.
## Игра поддерживает 7 классов героев: warrior, rogue, wizard, warlock,
## swordsman, oracle, swordswoman.
func test_class_registry_get_all_classes_returns_seven_items() -> void:
	# Arrange — _registry уже инициализирован в before_test()

	# Act
	var classes: Array[HeroClassData] = _registry.get_all_classes()

	# Assert
	assert_int(classes.size()).is_equal(7)


# ===================================================
# AC-01: все id уникальны
# ===================================================

## AC-01: каждый из 7 HeroClassData объектов должен иметь уникальный id.
## Дубликат id означал бы, что один класс перезаписал другой в словаре.
func test_class_registry_get_all_classes_ids_are_unique() -> void:
	# Arrange
	var classes: Array[HeroClassData] = _registry.get_all_classes()

	# Act — собираем все id в Set через Dictionary (Godot не имеет встроенного Set)
	var seen_ids: Dictionary = {}
	for hero_class: HeroClassData in classes:
		seen_ids[hero_class.id] = true

	# Assert — количество уникальных id == количество объектов
	assert_int(seen_ids.size()).is_equal(classes.size())


# ===================================================
# AC-01: все 7 ожидаемых id присутствуют
# ===================================================

## AC-01: get_all_classes() должен содержать все 7 известных id классов.
## Проверяет, что ни один класс не был пропущен при загрузке.
func test_class_registry_get_all_classes_contains_expected_ids() -> void:
	# Arrange
	var classes: Array[HeroClassData] = _registry.get_all_classes()

	# Собираем реальные id в Dictionary для O(1) проверки принадлежности
	var actual_ids: Dictionary = {}
	for hero_class: HeroClassData in classes:
		actual_ids[hero_class.id] = true

	# Assert — каждый из 7 ожидаемых id должен присутствовать
	assert_bool(actual_ids.has(&"warrior")).is_true()
	assert_bool(actual_ids.has(&"rogue")).is_true()
	assert_bool(actual_ids.has(&"wizard")).is_true()
	assert_bool(actual_ids.has(&"warlock")).is_true()
	assert_bool(actual_ids.has(&"swordsman")).is_true()
	assert_bool(actual_ids.has(&"oracle")).is_true()
	assert_bool(actual_ids.has(&"swordswoman")).is_true()


# ===================================================
# AC-02: get_class(id) возвращает правильный объект
# ===================================================

## AC-02: get_class(&"warrior") возвращает HeroClassData с id == &"warrior".
## Мы проверяем warrior как репрезентативный случай корректного поиска.
## Дополнительно проверяем несколько флагов warrior, чтобы убедиться,
## что возвращён именно warrior, а не произвольный объект.
func test_class_registry_get_class_warrior_returns_correct_data() -> void:
	# Arrange — warrior.tres должен иметь: id == &"warrior", max_hp == 5,
	# knockout_teleport_to_start == true, knockout_no_turn_skip == true,
	# knockout_full_heal == true, can_reroll_both_dice == true

	# Act
	var warrior: HeroClassData = _registry.get_hero_class(&"warrior")

	# Assert — объект не null и имеет корректный id
	assert_object(warrior).is_not_null()
	# StringName сравнивается напрямую через == без конвертации в String (AC-02)
	assert_bool(warrior.id == &"warrior").is_true()
	# Assert — warrior-specific флаги соответствуют данным warrior.tres (AC-01-c)
	assert_int(warrior.max_hp).is_equal(5)
	assert_bool(warrior.can_reroll_both_dice).is_true()
	assert_bool(warrior.knockout_teleport_to_start).is_true()
	assert_bool(warrior.knockout_no_turn_skip).is_true()
	assert_bool(warrior.knockout_full_heal).is_true()


# ===================================================
# AC-03: get_class(&"nonexistent") возвращает null
# ===================================================

## AC-03: get_class() с несуществующим id должен возвращать null без краша.
## push_error вызывается внутри (проверить логи вручную при необходимости),
## но тест проверяет только возвращаемое значение и отсутствие исключений.
func test_class_registry_get_class_unknown_id_returns_null() -> void:
	# Arrange — &"nonexistent" заведомо отсутствует в реестре

	# Act
	var result: HeroClassData = _registry.get_hero_class(&"nonexistent")

	# Assert — возвращает null, нет краша
	assert_object(result).is_null()


# ===================================================
# AC-04: get_class(&"") возвращает null
# ===================================================

## AC-04: get_class() с пустым StringName должен возвращать null без краша.
## Пустой id — это программная ошибка; ClassRegistry должен gracefully отклонить его.
func test_class_registry_get_class_empty_stringname_returns_null() -> void:
	# Arrange — &"" — пустой StringName

	# Act
	var result: HeroClassData = _registry.get_hero_class(&"")

	# Assert — возвращает null, нет краша
	assert_object(result).is_null()


# ===================================================
# AC-05: все объекты — экземпляры HeroClassData
# ===================================================

## AC-05: каждый элемент, возвращённый get_all_classes(), должен быть
## экземпляром HeroClassData. Защищает от случайной загрузки неверного .tres.
func test_class_registry_get_all_classes_are_hero_class_data_instances() -> void:
	# Arrange
	var classes: Array[HeroClassData] = _registry.get_all_classes()

	# Act + Assert — проверяем тип каждого элемента
	for hero_class: HeroClassData in classes:
		# is_instance_of() проверяет через GDScript is-оператор
		assert_bool(hero_class is HeroClassData).is_true()
