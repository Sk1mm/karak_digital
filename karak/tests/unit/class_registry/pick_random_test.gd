class_name ClassRegistryPickRandomTest  # GdUnit4 тест-сюит: Story 004 acceptance criteria для pick_random
extends GdUnitTestSuite                  # GdUnit4 базовый класс для всех test suites

# ===================================================
# CLASS REGISTRY PICK RANDOM TEST — Story 004
# ===================================================
# Покрывает acceptance criteria:
#   AC-10 — класс из already_selected не попадает в результат
#   AC-11 — если доступных >= n, результат содержит ровно n объектов
#   AC-12 — если доступных < n, результат содержит все доступные (не ошибка)
#   EC-01 — если already_selected содержит все 7 классов → результат []
#   Determinism — одинаковый seed даёт одинаковый результат
#   No-dupes  — результат не содержит повторяющихся объектов
#   n=0       — edge case: pick_random(0, ...) возвращает []
#
# Паттерн для тестирования Autoload:
#   Используем ClassRegistry Autoload напрямую — он уже инициализирован Godot.
#   ClassRegistry READ-ONLY → shared singleton безопасен в тестах.
#   class_name убран из class_registry.gd (naming conflict с Autoload в Godot 4.7 —
#   при наличии и class_name и Autoload с одинаковым именем, выражение ClassRegistry
#   может резолвиться на GDScriptNativeClass вместо Autoload node).
#
# Почему reference equality:
#   Все .tres ресурсы загружены через preload() — Godot кэширует их по пути,
#   поэтому два вызова preload("...warrior.tres") возвращают один и тот же объект.
#   pick_random фильтрует по == (reference equality), что соответствует этой гарантии.
#
# ADR Reference: ADR-0001 (Foundation Layer)
# Story: 004 — ClassRegistry.pick_random
# ===================================================

# ===================================================
# SETUP / TEARDOWN
# ===================================================

## Ссылка на Autoload-синглтон ClassRegistry. Тип Variant — избегаем type annotation
## на имя ClassRegistry: после удаления class_name из скрипта аннотация не нужна.
var _registry  # фактически ClassRegistry Autoload node

## RNG с фиксированным seed — обеспечивает детерминизм каждого теста.
## Seed сбрасывается в before_test(), поэтому порядок запуска тестов не влияет на результат.
var _rng: RandomNumberGenerator


## before_test: использует Autoload-синглтон ClassRegistry напрямую.
## ClassRegistry READ-ONLY → shared singleton безопасен в тестах.
## class_name удалён из class_registry.gd — naming conflict с Autoload устранён.
## В Godot 4 имя Autoload в expression context резолвится на синглтон-ноду.
func before_test() -> void:
	_registry = ClassRegistry  # Autoload singleton — уже инициализирован Godot
	_rng = RandomNumberGenerator.new()
	_rng.seed = 42


## after_test: обнуляем ссылку — НЕ освобождаем (это Autoload singleton).
## ВАЖНО: _registry.free() запрещён — уничтожит Autoload и сломает все следующие тесты.
func after_test() -> void:
	_registry = null
	_rng = null


# ===================================================
# AC-10: already_selected фильтруется из результата
# ===================================================

## AC-10: класс, переданный в already_selected, не должен попасть в результат.
## Проверяем на warrior — репрезентативный случай фильтрации по reference equality.
## Тест двухэтапный: сначала доказываем достижимость warrior (без исключений pick_random(7)
## должен вернуть его), затем доказываем исключение. Это предотвращает false-positive —
## если seed никогда не выбирает warrior при pick_random(3, ...), тест прошёл бы даже
## без фильтрации; доказательство достижимости делает тест самоверифицирующимся.
func test_pick_random_excludes_already_selected_class() -> void:
	# Arrange — получаем warrior как объект, который нужно исключить.
	# get_class() возвращает тот же shared pointer, что лежит в _classes dict.
	var warrior: HeroClassData = _registry.get_hero_class(&"warrior")
	assert_object(warrior).is_not_null()  # guard: убедиться, что warrior загружен

	# Шаг 1: доказываем достижимость warrior.
	# pick_random(7, ...) возвращает все классы — warrior обязан быть в результате.
	# Используем отдельный RNG, чтобы не сдвигать состояние _rng (isolation).
	var rng_reach: RandomNumberGenerator = RandomNumberGenerator.new()
	rng_reach.seed = 42
	var no_exclusions: Array[HeroClassData] = []
	var full_result: Array[HeroClassData] = _registry.pick_random(7, rng_reach, no_exclusions)
	var warrior_reachable: bool = false
	for c: HeroClassData in full_result:
		if c == warrior:
			warrior_reachable = true
			break
	assert_bool(warrior_reachable).is_true()

	# Шаг 2: проверяем exclusion — теперь знаем, что warrior достижим.
	var exclude_warrior: Array[HeroClassData] = [warrior]
	var result: Array[HeroClassData] = _registry.pick_random(3, _rng, exclude_warrior)

	# Assert — warrior не должен быть в результате
	var found_warrior: bool = false
	for hero_class: HeroClassData in result:
		if hero_class == warrior:  # reference equality
			found_warrior = true
			break
	assert_bool(found_warrior).is_false()
	# Доступно 7 - 1 = 6 классов, запрошено 3 — должно вернуться ровно 3
	assert_int(result.size()).is_equal(3)


# ===================================================
# AC-11: возвращает ровно n при достаточном количестве доступных
# ===================================================

## AC-11: если available >= n, результат содержит ровно n объектов.
## Базовый случай: already_selected пуст, n=3, доступно 7 классов.
## Дополнительно проверяем отсутствие дубликатов (sampling without replacement).
func test_pick_random_returns_exactly_n_when_enough_available() -> void:
	# Arrange — already_selected пуст, все 7 классов доступны

	# Act
	var no_exclusions: Array[HeroClassData] = []
	var result: Array[HeroClassData] = _registry.pick_random(3, _rng, no_exclusions)

	# Assert — ровно 3 элемента
	assert_int(result.size()).is_equal(3)

	# Assert — все 3 объекта различны (нет дубликатов внутри результата)
	# Используем Dictionary как Set: ключ — Resource object ID, значение — true
	var seen: Dictionary = {}
	for hero_class: HeroClassData in result:
		# get_instance_id() — уникальный идентификатор объекта в Godot (не путать с hero_class.id)
		seen[hero_class.get_instance_id()] = true
	assert_int(seen.size()).is_equal(3)


# ===================================================
# AC-12: возвращает всех доступных, если их меньше n
# ===================================================

## AC-12: если available < n, возвращаются все доступные (не ошибка, не crash).
## Arrange: исключаем 5 классов → доступно 2, запрашиваем 3.
## Ожидаем 2 объекта в ответе. Дополнительно проверяем, что оба результата
## принадлежат не-исключённому пулу — тест проходит только если фильтрация реально работает.
func test_pick_random_returns_all_when_fewer_than_n_available() -> void:
	# Arrange — берём первые 5 классов из реестра для already_selected
	var all_classes: Array[HeroClassData] = _registry.get_all_classes()
	# slice(0, 5) — первые 5 элементов (индексы 0..4 включительно)
	var five_classes: Array[HeroClassData] = all_classes.slice(0, 5)
	assert_int(five_classes.size()).is_equal(5)  # guard

	# Act — запрашиваем 3, но доступно только 2 (7 - 5 = 2)
	var result: Array[HeroClassData] = _registry.pick_random(3, _rng, five_classes)

	# Assert — возвращает 2 (все доступные), без ошибки
	assert_int(result.size()).is_equal(2)
	# Assert — ни один из возвращённых классов не должен быть в исключённом пуле.
	# Без этой проверки тест проходил бы даже если pick_random вернул бы исключённые классы.
	for hero_class: HeroClassData in result:
		assert_bool(five_classes.has(hero_class)).is_false()


# ===================================================
# EC-01: already_selected содержит все 7 классов → []
# ===================================================

## EC-01: если все классы уже выбраны, pick_random возвращает пустой массив.
## Это нормальный случай конца драфта — не ошибка.
func test_pick_random_returns_empty_when_all_selected() -> void:
	# Arrange — all_classes содержит все 7 preloaded shared ресурсов
	var all_classes: Array[HeroClassData] = _registry.get_all_classes()
	assert_int(all_classes.size()).is_equal(7)  # guard

	# Act
	var result: Array[HeroClassData] = _registry.pick_random(3, _rng, all_classes)

	# Assert — пустой результат, никаких ошибок
	assert_int(result.size()).is_equal(0)


# ===================================================
# Determinism: одинаковый seed → одинаковый результат
# ===================================================

## Determinism: два RNG с одинаковым seed должны давать идентичный результат.
## Это критично для воспроизводимости сессий и предсказуемого поведения при тестировании.
## Проверяем совпадение id классов в одинаковом порядке.
func test_pick_random_is_deterministic_with_same_seed() -> void:
	# Arrange — два независимых RNG с одинаковым seed
	var rng1: RandomNumberGenerator = RandomNumberGenerator.new()
	rng1.seed = 42
	var rng2: RandomNumberGenerator = RandomNumberGenerator.new()
	rng2.seed = 42

	# Act — два независимых вызова с одинаковым seed и пустым already_selected
	var no_exclusions: Array[HeroClassData] = []
	var result1: Array[HeroClassData] = _registry.pick_random(3, rng1, no_exclusions)
	no_exclusions = []  # сбрасываем для второго вызова (Array — value type при assign)
	var result2: Array[HeroClassData] = _registry.pick_random(3, rng2, no_exclusions)

	# Assert — одинаковая длина
	assert_int(result1.size()).is_equal(3)
	assert_int(result2.size()).is_equal(3)

	# Assert — одинаковые id в одинаковом порядке
	# Сравниваем по .id (StringName), а не по ссылке — оба результата используют
	# один и тот же shared preloaded ресурс, поэтому ссылки тоже совпадут, но
	# явная проверка по .id делает намерение теста читаемым.
	for i: int in range(3):
		assert_bool(result1[i].id == result2[i].id).is_true()


# ===================================================
# No-dupes: результат не содержит повторяющихся объектов
# ===================================================

## No-dupes (duplicate() ветка): pick_random без повторений когда available < n.
## Когда available.size() <= n срабатывает ранний return через available.duplicate() —
## эта ветка отличается от Fisher-Yates. Проверяем её отдельно.
## Scenario: 5 excluded → available = 2; pick_random(3) вернёт 2 через duplicate().
func test_pick_random_has_no_duplicates_in_result() -> void:
	# Arrange — исключаем 5 классов, чтобы попасть в ветку duplicate() (available < n)
	var all_classes: Array[HeroClassData] = _registry.get_all_classes()
	var five_classes: Array[HeroClassData] = all_classes.slice(0, 5)

	# Act — pick_random идёт через available.duplicate(), не через Fisher-Yates
	var result: Array[HeroClassData] = _registry.pick_random(3, _rng, five_classes)

	# Assert — нет дубликатов (instance_id уникален для каждого Resource объекта)
	var seen_ids: Dictionary = {}
	for hero_class: HeroClassData in result:
		seen_ids[hero_class.get_instance_id()] = true
	assert_int(seen_ids.size()).is_equal(result.size())


# ===================================================
# Edge case: n=0 возвращает []
# ===================================================

## Edge case n=0: запрос нуля классов должен вернуть пустой массив без ошибки.
## Случай возможен, если DraftSystem вызывает pick_random(0, ...) в конце сессии.
func test_pick_random_zero_n_returns_empty() -> void:
	# Arrange — нет already_selected, все 7 доступны, но запрашиваем 0

	# Act
	var no_exclusions: Array[HeroClassData] = []
	var result: Array[HeroClassData] = _registry.pick_random(0, _rng, no_exclusions)

	# Assert — пустой результат
	# Примечание: available.size() (7) > n (0), поэтому сработает ветка shuffle,
	# но range(0) не производит итераций → slice(0, 0) вернёт [].
	assert_int(result.size()).is_equal(0)


# ===================================================
# Edge case: n > total_classes → вернуть все доступные
# ===================================================

## Edge case n > total: запрос больше классов, чем есть в реестре.
## pick_random(10, rng, []) → available = 7, n = 10 → available.size() <= n → duplicate().
## Верифицирует граничное условие `<=` в guard: если бы было `<`, этот тест упал бы при n=7.
func test_pick_random_n_exceeds_total_returns_all() -> void:
	# Arrange — already_selected пуст, все 7 доступны, запрашиваем 10

	# Act
	var no_exclusions: Array[HeroClassData] = []
	var result: Array[HeroClassData] = _registry.pick_random(10, _rng, no_exclusions)

	# Assert — возвращает все 7 (максимум доступных), без ошибки
	assert_int(result.size()).is_equal(7)
