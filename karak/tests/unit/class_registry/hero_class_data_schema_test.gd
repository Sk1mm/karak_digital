class_name HeroClassDataSchemaTest  # GdUnit4 тест-сюит: schema validation для HeroClassData
extends GdUnitTestSuite  # GdUnit4 базовый класс

# ===================================================
# HERO CLASS DATA SCHEMA TEST
# ===================================================
# Проверяет:
#   AC-schema-1 — HeroClassData.new() создаётся без ошибок, дефолты корректны
#   AC-schema-2 — все 19 @export полей доступны без ошибок "Invalid get index"
#   AC-14       — in-memory мутация работает (Resource не immutable в GDScript)
#   Доп.        — тип поля id == TYPE_STRING_NAME
#
# ADR Reference: ADR-0003
# Зависимости: только HeroClassData (нет внешних сцен, нет файловой системы)
# ===================================================


# --- AC-schema-1: instantiation + базовые дефолты ---

## AC-schema-1 (базовая): HeroClassData.new() не null, max_hp == 5,
## first_step_combat_bonus == 0.
func test_hero_class_data_instantiation_returns_non_null_with_correct_numeric_defaults() -> void:
	# Arrange / Act
	var data := HeroClassData.new()

	# Assert
	assert_object(data).is_not_null()
	assert_int(data.max_hp).is_equal(5)
	assert_int(data.first_step_combat_bonus).is_equal(0)


## AC-schema-1 (COMBAT section): все boolean-флаги секции COMBAT == false по умолчанию.
func test_hero_class_data_defaults_combat_flags_are_false() -> void:
	# Arrange
	var data := HeroClassData.new()

	# Assert — каждый COMBAT флаг должен быть false
	assert_bool(data.can_reroll_both_dice).is_false()
	assert_bool(data.wins_on_draw).is_false()
	assert_bool(data.can_spend_hp_for_attack).is_false()
	assert_bool(data.auto_reroll_on_one).is_false()
	assert_bool(data.can_continue_turn_on_six).is_false()
	assert_bool(data.can_reroll_one_die).is_false()


## AC-schema-1 (KNOCKOUT section): все boolean-флаги секции KNOCKOUT == false по умолчанию.
func test_hero_class_data_defaults_knockout_flags_are_false() -> void:
	# Arrange
	var data := HeroClassData.new()

	# Assert — каждый KNOCKOUT флаг должен быть false
	assert_bool(data.knockout_teleport_to_start).is_false()
	assert_bool(data.knockout_no_turn_skip).is_false()
	assert_bool(data.knockout_full_heal).is_false()


## AC-schema-1 (MOVEMENT section): все boolean-флаги секции MOVEMENT == false по умолчанию.
func test_hero_class_data_defaults_movement_flags_are_false() -> void:
	# Arrange
	var data := HeroClassData.new()

	# Assert — каждый MOVEMENT флаг должен быть false
	assert_bool(data.can_bypass_monster_free).is_false()
	assert_bool(data.can_bypass_monster_cost).is_false()
	assert_bool(data.can_pass_through_walls).is_false()
	assert_bool(data.can_swap_positions).is_false()


## AC-schema-1 (TILE/DUNGEON section): boolean-флаг секции TILE/DUNGEON == false по умолчанию.
func test_hero_class_data_defaults_tile_dungeon_flags_are_false() -> void:
	# Arrange
	var data := HeroClassData.new()

	# Assert
	assert_bool(data.choose_encounter_from_two).is_false()


## AC-schema-1 (ITEMS section): boolean-флаг секции ITEMS == false по умолчанию.
func test_hero_class_data_defaults_items_flags_are_false() -> void:
	# Arrange
	var data := HeroClassData.new()

	# Assert
	assert_bool(data.magic_charge_no_discard).is_false()


# --- AC-schema-2: все 19 полей доступны ---

## AC-schema-2: обращение ко всем 19 @export полям не вызывает "Invalid get index".
## Если поле отсутствует — GDScript бросает ошибку ещё на этапе парсинга/присвоения,
## поэтому сам факт компиляции и выполнения этой функции без ошибок = проверка.
func test_hero_class_data_all_19_fields_are_accessible() -> void:
	# Arrange
	var data := HeroClassData.new()

	# Act — читаем все 19 полей в локальные переменные со статическими типами
	# Если хотя бы одно поле отсутствует — тест упадёт с "Invalid get index"

	# Base fields (3)
	var _id: StringName          = data.id
	var _display_name: String    = data.display_name
	var _max_hp: int             = data.max_hp

	# COMBAT (7)
	var _can_reroll_both_dice: bool      = data.can_reroll_both_dice
	var _wins_on_draw: bool              = data.wins_on_draw
	var _can_spend_hp_for_attack: bool   = data.can_spend_hp_for_attack
	var _auto_reroll_on_one: bool        = data.auto_reroll_on_one
	var _can_continue_turn_on_six: bool  = data.can_continue_turn_on_six
	var _can_reroll_one_die: bool        = data.can_reroll_one_die
	var _first_step_combat_bonus: int    = data.first_step_combat_bonus

	# KNOCKOUT (3)
	var _knockout_teleport_to_start: bool = data.knockout_teleport_to_start
	var _knockout_no_turn_skip: bool      = data.knockout_no_turn_skip
	var _knockout_full_heal: bool         = data.knockout_full_heal

	# MOVEMENT (4)
	var _can_bypass_monster_free: bool  = data.can_bypass_monster_free
	var _can_bypass_monster_cost: bool  = data.can_bypass_monster_cost
	var _can_pass_through_walls: bool   = data.can_pass_through_walls
	var _can_swap_positions: bool       = data.can_swap_positions

	# TILE/DUNGEON (1)
	var _choose_encounter_from_two: bool = data.choose_encounter_from_two

	# ITEMS (1)
	var _magic_charge_no_discard: bool = data.magic_charge_no_discard

	# Assert — если дошли до этой строки, все 19 полей читаются без ошибок
	# Используем хотя бы одно значение, чтобы компилятор не оптимизировал переменные
	assert_int(_max_hp).is_equal(5)
	assert_bool(_can_reroll_both_dice).is_false()
	assert_bool(_magic_charge_no_discard).is_false()


# --- AC-14: in-memory мутация ---

## AC-14: Resource не immutable в памяти GDScript — изменение поля in-memory применяется.
## Read-only контракт обеспечивается тем, что система НИКОГДА не вызывает ResourceSaver.save()
## на экземпляре HeroClassData. Это system-level контракт, не assertable в unit тесте.
##
## AC-14: Resource is not immutable in-memory; read-only contract is enforced by
## not calling ResourceSaver.save() — which is a system-level contract, not assertable here.
func test_hero_class_data_in_memory_mutation_applies_change() -> void:
	# Arrange
	var data := HeroClassData.new()
	assert_int(data.max_hp).is_equal(5)  # проверяем начальное состояние

	# Act — изменяем in-memory (ожидаемое поведение GDScript Resource)
	data.max_hp = 99

	# Assert — изменение применилось в памяти
	# Это НЕ означает что .tres файл изменился — он не трогался
	assert_int(data.max_hp).is_equal(99)


## AC-14 (изоляция): duplicate() создаёт независимую копию — мутация копии не затрагивает оригинал.
## Это покрывает runtime-риск: потребитель, получивший shared Resource из load(),
## должен вызывать duplicate() перед мутацией — иначе corrupts shared state для всех потребителей.
## ClassRegistry (Story 003) обязан возвращать .duplicate() при выдаче экземпляра классу.
func test_hero_class_data_duplicate_isolates_mutation_from_original() -> void:
	# Arrange
	var original := HeroClassData.new()
	# original.max_hp == 5 (default)

	# Act — потребитель берёт копию и мутирует её
	var copy: HeroClassData = original.duplicate() as HeroClassData
	copy.max_hp = 99

	# Assert — оригинал не затронут мутацией копии
	assert_int(original.max_hp).is_equal(5)
	assert_int(copy.max_hp).is_equal(99)


# --- Дополнительно: тип поля id ---

## Дополнительно: поле id имеет тип StringName (TYPE_STRING_NAME), не String.
## StringName — более эффективный тип для частых сравнений (идентификаторов).
func test_hero_class_data_id_field_type_is_string_name() -> void:
	# Arrange
	var data := HeroClassData.new()
	data.id = &"warrior"  # назначаем StringName литерал

	# Act
	var id_type: int = typeof(data.id)

	# Assert — TYPE_STRING_NAME == 9 в Godot 4.x
	assert_int(id_type).is_equal(TYPE_STRING_NAME)
