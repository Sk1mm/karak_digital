class_name PlayerStateSkeletonTest  # GdUnit4 тест-сюит: Story 001 acceptance criteria для PlayerState skeleton
extends GdUnitTestSuite           # GdUnit4 базовый класс для всех test suites

# ===================================================
# PLAYER STATE SKELETON TEST — Story 001
# ===================================================
# Покрывает acceptance criteria:
#   AC-01 — начальные значения инвентаря (weapons, key, scrolls, attack_bonus)
#   AC-27 — валидация player_id: граничные позитивные значения (1 и 5) не вызывают assert
#   AC-28 — поле effective_attack ОТСУТСТВУЕТ в PlayerState
#
# AC-27 (негативные случаи — player_id=0, player_id=6, player_id=-1):
#   GDScript assert() прерывает выполнение в debug builds — его нельзя поймать в unit-тестах
#   как исключение. Автоматизировать негативные граничные случаи невозможно без мока
#   движкового assert. Покрываем только позитивные граничные значения (1 и 5).
#   Негативные случаи верифицировать вручную в Godot Editor: создать PlayerState с
#   player_id=0 (или 6/-1) в Inspector → assert сработает при запуске сцены.
#
# Паттерн изоляции:
#   PlayerState.new() создаёт объект без вызова _ready() — поля остаются в дефолтах.
#   Для тестов, которым нужен полностью инициализированный объект, мы:
#     1. Создаём PlayerState.new()
#     2. Назначаем character_class и player_id вручную (до вызова _ready())
#     3. Добавляем в дерево через auto_free() — это вызывает _ready()
#   ВАЖНО: PlayerState.new() без add_child() запрещён в production-коде (Control Manifest);
#          в тестах — допустимо для изолированного тестирования начальных полей.
#
# ADR Reference: ADR-0003 (PlayerState as Node)
# ADR Reference: ADR-0007 (SlotType как int в сигналах)
# Story: 001 — PlayerState Node Skeleton
# ===================================================


# ===================================================
# HELPERS
# ===================================================

## Создаёт минимальный валидный HeroClassData для использования в тестах.
## Не сохраняется на диск — только in-memory Resource.
##
## Contract: возвращает HeroClassData с id, display_name и max_hp — минимум для
## прохождения assert(character_class != null) в PlayerState._ready().
func _create_valid_hero_class(p_max_hp: int = 5) -> HeroClassData:
	# HeroClassData.new() — Resource, не требует сцены и _ready(); безопасно для unit-тестов
	var hcd := HeroClassData.new()
	hcd.max_hp = p_max_hp
	hcd.id = &"test_hero"       # StringName literal — ADR: prefer &"name" syntax
	hcd.display_name = "Test Hero"
	return hcd


## Создаёт PlayerState, добавляет в Scene Tree (вызывает _ready()) и регистрирует в auto_free.
## player_id и character_class назначаются ДО добавления в дерево, чтобы _ready() их видел.
##
## Contract:
##   - p_player_id должен быть в диапазоне 1–5 (иначе assert в _ready() — тест упадёт)
##   - p_max_hp >= 1 (разумное ограничение для тестов)
##   - Возвращённый инстанс автоматически освобождается GdUnit4 через auto_free()
func _create_ready_player_state(p_player_id: int = 1, p_max_hp: int = 5) -> PlayerState:
	# --- ШАГ 1: создать инстанс (без _ready()) ---
	var ps := PlayerState.new()

	# --- ШАГ 2: настроить поля до добавления в дерево ---
	# Это имитирует Inspector: @export поля назначаются ДО _ready() (Godot lifecycle гарантия)
	ps.player_id = p_player_id
	ps.character_class = _create_valid_hero_class(p_max_hp)

	# --- ШАГ 3: добавить в дерево — это вызовет _ready() ---
	# auto_free() регистрирует ноду для автоматической очистки после теста
	add_child(auto_free(ps))

	return ps


# ===================================================
# AC-01: инвентарные поля инициализированы в пустое состояние
# ===================================================

## AC-01: после создания PlayerState с валидным player_id=1 и HeroClassData(max_hp=5):
##   weapons.size() == 0, key == null, scrolls.size() == 0.
## Гарантирует, что инвентарь начинается пустым — не сохраняет данные от предыдущих тестов.
func test_player_state_inventory_fields_initialized_to_empty_on_valid_player_id() -> void:
	# Arrange — создаём полностью инициализированный PlayerState (через _ready())
	var ps: PlayerState = _create_ready_player_state(1, 5)

	# Assert — все инвентарные поля пусты (AC-01)
	assert_int(ps.weapons.size()).is_equal(0)
	assert_object(ps.key).is_null()
	assert_int(ps.scrolls.size()).is_equal(0)


# ===================================================
# AC-01: attack_bonus инициализирован в 0
# ===================================================

## AC-01: attack_bonus == 0 после инициализации PlayerState.
## attack_bonus — суммарный бонус от предметов; начинает с нуля (ни одного предмета нет).
## ЗАПРЕЩЕНО смешивать с effective_attack (AC-28) — это разные вещи.
func test_player_state_attack_bonus_initialized_to_zero() -> void:
	# Arrange
	var ps: PlayerState = _create_ready_player_state(1, 5)

	# Assert — attack_bonus начинает с 0 (AC-01)
	assert_int(ps.attack_bonus).is_equal(0)


# ===================================================
# AC-27: граничное минимальное значение player_id=1 не вызывает assert
# ===================================================

## AC-27 (позитивный граничный): player_id=1 (минимально допустимое значение) проходит _ready()
## без assert. Если assert сработал бы — тест не дошёл бы до assert_int.
##
## NOTE: негативные граничные случаи (player_id=0, player_id=6, player_id=-1) тестируются
## вручную в Godot Editor — GDScript assert() нельзя поймать в unit-тестах (см. шапку файла).
func test_player_state_player_id_boundary_min_does_not_assert() -> void:
	# Arrange + Act — создаём PlayerState с player_id=1 (минимальный валидный)
	# Если assert в _ready() сработает — тест упадёт до этой строки
	var ps: PlayerState = _create_ready_player_state(1, 5)

	# Assert — объект создан, player_id сохранён корректно
	assert_int(ps.player_id).is_equal(1)
	# hp инициализирован из max_hp — дополнительная проверка что _ready() прошёл
	assert_int(ps.hp).is_equal(5)


# ===================================================
# AC-27: граничное максимальное значение player_id=5 не вызывает assert
# ===================================================

## AC-27 (позитивный граничный): player_id=5 (максимально допустимое значение) проходит _ready()
## без assert. Проверяет что верхняя граница диапазона 1–5 включительна.
func test_player_state_player_id_boundary_max_does_not_assert() -> void:
	# Arrange + Act — создаём PlayerState с player_id=5 (максимальный валидный)
	var ps: PlayerState = _create_ready_player_state(5, 5)

	# Assert — объект создан, player_id сохранён корректно
	assert_int(ps.player_id).is_equal(5)
	# hp инициализирован из max_hp — подтверждение что _ready() завершился успешно
	assert_int(ps.hp).is_equal(5)


# ===================================================
# AC-28: поле effective_attack отсутствует в PlayerState
# ===================================================

## AC-28: поле effective_attack НЕ должно существовать в PlayerState.
## CombatSystem вычисляет итоговую атаку самостоятельно — PlayerState хранит только
## компоненты (attack_bonus от предметов, character_class для базового значения).
##
## Метод get() возвращает null если поле не существует — используем это как проверку.
## Если поле будет добавлено по ошибке — тест сразу провалится.
func test_player_state_effective_attack_field_does_not_exist() -> void:
	# Arrange — используем PlayerState.new() без _ready() (поле не должно существовать
	# независимо от состояния инициализации)
	var ps := PlayerState.new()
	# Регистрируем для очистки после теста (Node — требует явного освобождения)
	auto_free(ps)

	# Act — пытаемся прочитать несуществующее поле через get()
	# get() возвращает null для отсутствующих полей, не бросает ошибку
	var result: Variant = ps.get("effective_attack")

	# Assert — поле отсутствует (AC-28)
	assert_object(result).is_null()
