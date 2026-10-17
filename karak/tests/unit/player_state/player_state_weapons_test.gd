class_name PlayerStateWeaponsTest  # GdUnit4 тест-сюит: Story 004 Inventory Weapons — unit-тесты
extends GdUnitTestSuite  # GdUnit4 базовый класс для всех test suites

# ===================================================
# PLAYER STATE WEAPONS TEST — Story 004
# ===================================================
# Покрывает acceptance criteria:
#   AC-02 — weapon(+2) + weapon(+1) → get_attack_bonus()==3
#   AC-03 — свиток не влияет на attack_bonus
#   AC-04 — attack_bonus пересчитан немедленно после add_weapon
#   AC-05 — replace_weapon пересчитывает attack_bonus
#   AC-06 — пустой weapons → get_attack_bonus()==0
#   AC-16 — add_weapon при заполненных слотах → false, нет изменений
#   AC-18 — replace_weapon(unknown, new) → push_error, weapons не изменён
#
# Сигналы НЕ тестируются здесь — см. integration-тест player_state_weapon_signals_test.gd (AC-17).
#
# ADR Reference: ADR-0003 (PlayerState as Node)
# ADR Reference: ADR-0013 (Loot Weapon Replacement Strategy)
# TR Reference: TR-player-state-006
# Story: 004 — Inventory Weapons
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


## Создаёт PlayerState, добавляет в Scene Tree (вызывает _ready()),
## регистрирует в auto_free для автоматической очистки после теста.
##
## Contract:
##   - player_id = 1 (допустимый диапазон 1–5 по AC-27)
##   - character_class с max_hp=5 (достаточно для всех weapon-тестов)
##   - Возвращённый инстанс автоматически освобождается GdUnit4 через auto_free()
func _create_player_state() -> PlayerState:
	# --- ШАГ 1: создать инстанс (без _ready()) ---
	var ps := PlayerState.new()

	# --- ШАГ 2: настроить @export поля до добавления в дерево ---
	# Имитирует Inspector: @export назначается ДО _ready() (Godot lifecycle гарантия)
	ps.player_id = 1
	ps.character_class = _create_hero_class(5)

	# --- ШАГ 3: добавить в дерево — вызывает _ready() ---
	# auto_free() регистрирует ноду для автоматической очистки после теста
	add_child(auto_free(ps))

	return ps


## Создаёт ItemData с заданным attack_bonus для использования в тестах.
func _create_weapon(p_attack_bonus: int) -> ItemData:
	var item := ItemData.new()
	item.id = StringName("test_weapon_%d" % p_attack_bonus)  # dynamic id — не compile-time StringName literal
	item.attack_bonus = p_attack_bonus
	return item


## Создаёт ItemData-свиток (attack_bonus = 0 по дизайну GDD).
## Свитки дают combat_bonus, а не attack_bonus — AC-03.
func _create_scroll(p_combat_bonus: int) -> ItemData:
	var item := ItemData.new()
	item.id = StringName("test_scroll_%d" % p_combat_bonus)  # dynamic id — не compile-time StringName literal
	item.attack_bonus = 0  # свитки не добавляют attack_bonus (AC-03)
	return item


# ===================================================
# AC-06: пустой weapons → attack_bonus == 0
# ===================================================

## AC-06: сразу после создания weapons пуст → get_attack_bonus() == 0.
## Граничный случай: нет оружий — нет бонуса (EC-10 GDD).
func test_player_state_get_attack_bonus_with_no_weapons_returns_zero() -> void:
	# Arrange
	var ps: PlayerState = _create_player_state()
	assert_int(ps.weapons.size()).is_equal(0)  # предусловие

	# Act + Assert
	assert_int(ps.get_attack_bonus()).is_equal(0)


# ===================================================
# AC-02: два оружия → attack_bonus == сумма
# ===================================================

## AC-02: weapon(+2) + weapon(+1) → get_attack_bonus() == 3.
## Формула: attack_bonus = Σ weapon.attack_bonus (только оружие).
func test_player_state_get_attack_bonus_with_two_weapons_returns_sum() -> void:
	# Arrange
	var ps: PlayerState = _create_player_state()
	var w_a: ItemData = _create_weapon(2)
	var w_b: ItemData = _create_weapon(1)

	# Act
	ps.add_weapon(w_a)
	ps.add_weapon(w_b)

	# Assert
	assert_int(ps.get_attack_bonus()).is_equal(3)


# ===================================================
# AC-03: свиток не влияет на attack_bonus
# ===================================================

## AC-03: одно оружие (+2) + один свиток (combat_bonus=3) → get_attack_bonus() == 2.
## Свитки не участвуют в формуле attack_bonus.
func test_player_state_get_attack_bonus_excludes_scrolls() -> void:
	# Arrange — одно оружие, один свиток
	var ps: PlayerState = _create_player_state()
	var weapon: ItemData = _create_weapon(2)
	var scroll: ItemData = _create_scroll(3)

	ps.add_weapon(weapon)
	ps.scrolls.append(scroll)  # прямое добавление — set_scroll ещё не реализован (Story 005)

	# Act + Assert — только оружие в формуле
	assert_int(ps.get_attack_bonus()).is_equal(2)


# ===================================================
# AC-04: attack_bonus пересчитывается немедленно
# ===================================================

## AC-04: одно оружие (+1) → attack_bonus==1; добавляем второе (+3) → attack_bonus==4 немедленно.
## Нет отложенных вычислений — кэш обновляется синхронно в add_weapon.
func test_player_state_add_weapon_recalculates_attack_bonus_immediately() -> void:
	# Arrange — одно оружие
	var ps: PlayerState = _create_player_state()
	ps.add_weapon(_create_weapon(1))
	assert_int(ps.get_attack_bonus()).is_equal(1)  # предусловие

	# Act — добавить второе
	ps.add_weapon(_create_weapon(3))

	# Assert — кэш обновлён немедленно (AC-04)
	assert_int(ps.get_attack_bonus()).is_equal(4)


# ===================================================
# AC-05: replace_weapon пересчитывает attack_bonus
# ===================================================

## AC-05: weapons=[w1(+2), w2(+1)], attack_bonus==3;
##        replace_weapon(w2, w3) где w3.attack_bonus=4 → attack_bonus==6.
func test_player_state_replace_weapon_recalculates_attack_bonus() -> void:
	# Arrange
	var ps: PlayerState = _create_player_state()
	var w1: ItemData = _create_weapon(2)
	var w2: ItemData = _create_weapon(1)
	var w3: ItemData = _create_weapon(4)

	ps.add_weapon(w1)
	ps.add_weapon(w2)
	assert_int(ps.get_attack_bonus()).is_equal(3)  # предусловие

	# Act
	ps.replace_weapon(w2, w3)

	# Assert
	assert_int(ps.get_attack_bonus()).is_equal(6)


# ===================================================
# AC-16: add_weapon при заполненных слотах → false
# ===================================================

## AC-16: добавить третье оружие при weapons.size()==2 → возвращает false,
##        weapons.size() не изменился, attack_bonus не изменился.
func test_player_state_add_weapon_when_slots_full_returns_false() -> void:
	# Arrange — заполнить оба слота
	var ps: PlayerState = _create_player_state()
	ps.add_weapon(_create_weapon(1))
	ps.add_weapon(_create_weapon(2))
	assert_int(ps.weapons.size()).is_equal(2)  # предусловие
	var bonus_before: int = ps.get_attack_bonus()

	# Act
	var result: bool = ps.add_weapon(_create_weapon(5))

	# Assert
	assert_bool(result).is_false()
	assert_int(ps.weapons.size()).is_equal(2)                    # размер не изменился
	assert_int(ps.get_attack_bonus()).is_equal(bonus_before)     # attack_bonus не изменился


## AC-16 дополнение: get_weapons() при заполненных слотах содержит ровно 2 элемента.
func test_player_state_get_weapons_after_two_adds_returns_two_items() -> void:
	# Arrange
	var ps: PlayerState = _create_player_state()
	var w1: ItemData = _create_weapon(1)
	var w2: ItemData = _create_weapon(2)

	# Act
	ps.add_weapon(w1)
	ps.add_weapon(w2)

	# Assert
	var weapons: Array[ItemData] = ps.get_weapons()
	assert_int(weapons.size()).is_equal(2)
	assert_object(weapons[0]).is_equal(w1)
	assert_object(weapons[1]).is_equal(w2)


# ===================================================
# AC-18: replace_weapon с невалидным old → push_error, no change
# ===================================================

## AC-18: replace_weapon(unknown, new) при weapons==[weapon_a] →
##        push_error вызван, weapons не изменён, attack_bonus не изменился.
func test_player_state_replace_weapon_with_unknown_old_pushes_error() -> void:
	# Arrange
	var ps: PlayerState = _create_player_state()
	var weapon_a: ItemData = _create_weapon(2)
	var weapon_unknown: ItemData = _create_weapon(5)
	var weapon_new: ItemData = _create_weapon(3)

	ps.add_weapon(weapon_a)
	var bonus_before: int = ps.get_attack_bonus()

	# Assert — push_error вызван (GdUnit4: assert_error с Callable)
	await assert_error(func() -> void: ps.replace_weapon(weapon_unknown, weapon_new)) \
		.is_push_error(
			"PlayerState.replace_weapon: old item not found in weapons. " +
			"Attempted to replace an item not in the weapon slots. AC-18."
		)

	# Assert — состояние не изменилось
	assert_int(ps.weapons.size()).is_equal(1)
	assert_object(ps.weapons[0]).is_equal(weapon_a)
	assert_int(ps.get_attack_bonus()).is_equal(bonus_before)
