class_name PlayerStateWeaponSignalsTest  # GdUnit4 integration: Story 004 — weapon signals AC-17
extends GdUnitTestSuite  # GdUnit4 базовый класс для всех test suites

# ===================================================
# PLAYER STATE WEAPON SIGNALS TEST — Story 004 (Integration)
# ===================================================
# Покрывает acceptance criteria:
#   AC-17 — replace_weapon(old, new) → item_removed(old, SLOT_WEAPON) +
#            item_added(new, SLOT_WEAPON) испущены в правильном порядке
#
# Integration-тест: проверяет полную цепочку взаимодействия сигналов,
# включая порядок испускания (item_removed ДО item_added).
#
# ADR Reference: ADR-0002 (Typed signals — item_added/item_removed)
# ADR Reference: ADR-0003 (PlayerState as Node)
# ADR Reference: ADR-0013 (Weapon replacement via PlayerState API)
# TR Reference: TR-player-state-006
# Story: 004 — Inventory Weapons (Integration)
# ===================================================


# ===================================================
# HELPERS
# ===================================================

## Создаёт минимально валидный HeroClassData для использования в тестах.
func _create_hero_class() -> HeroClassData:
	# HeroClassData — Resource, не требует сцены и _ready(); безопасно для тестов
	var hcd := HeroClassData.new()
	hcd.max_hp = 5
	hcd.id = &"test_hero"          # StringName literal — ADR: prefer &"name" syntax
	hcd.display_name = "Test Hero"
	return hcd


## Создаёт PlayerState, добавляет в Scene Tree (вызывает _ready()),
## регистрирует в auto_free для автоматической очистки после теста.
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


## Создаёт ItemData с заданным attack_bonus для использования в тестах.
func _create_weapon(p_attack_bonus: int) -> ItemData:
	var item := ItemData.new()
	item.id = StringName("test_weapon_%d" % p_attack_bonus)  # dynamic id — не compile-time StringName literal
	item.attack_bonus = p_attack_bonus
	return item


# ===================================================
# AC-17: replace_weapon испускает оба сигнала
# ===================================================

## AC-17: replace_weapon(old, new) → item_removed(old, SLOT_WEAPON) +
##        item_added(new, SLOT_WEAPON) испущены.
## Использует GdUnit4 monitor_signals / assert_signal.
func test_player_state_replace_weapon_emits_item_removed_and_item_added() -> void:
	# Arrange — одно оружие в слоте; подписываем монитор сигналов
	var ps: PlayerState = _create_player_state()
	var weapon_old: ItemData = _create_weapon(2)
	var weapon_new: ItemData = _create_weapon(4)

	ps.add_weapon(weapon_old)

	var monitor := monitor_signals(ps)

	# Act
	ps.replace_weapon(weapon_old, weapon_new)

	# Assert — item_removed(weapon_old, 0) испущен
	await assert_signal(monitor).is_emitted("item_removed", [weapon_old, PlayerState.SLOT_WEAPON])

	# Assert — item_added(weapon_new, 0) испущен
	await assert_signal(monitor).is_emitted("item_added", [weapon_new, PlayerState.SLOT_WEAPON])


## AC-17 порядок: item_removed испускается ДО item_added.
## Регрессия: HUD/InventoryUI получает removed ДО added — чтобы слот освободился ДО заполнения.
func test_player_state_replace_weapon_emits_removed_before_added() -> void:
	# Arrange — lambda-счётчик порядка испускания
	var ps: PlayerState = _create_player_state()
	var weapon_old: ItemData = _create_weapon(1)
	var weapon_new: ItemData = _create_weapon(3)

	ps.add_weapon(weapon_old)

	var order: Array[String] = []
	ps.item_removed.connect(func(_item: ItemData, _slot: int) -> void:
		order.append("item_removed"))
	ps.item_added.connect(func(_item: ItemData, _slot: int) -> void:
		order.append("item_added"))

	# Act
	ps.replace_weapon(weapon_old, weapon_new)

	# Assert — порядок: removed ПЕРЕД added
	assert_array(order).is_equal(["item_removed", "item_added"])


## AC-17 edge case: после replace_weapon weapons содержит new_item, old отсутствует.
func test_player_state_replace_weapon_updates_weapons_array() -> void:
	# Arrange
	var ps: PlayerState = _create_player_state()
	var weapon_old: ItemData = _create_weapon(1)
	var weapon_new: ItemData = _create_weapon(3)
	ps.add_weapon(weapon_old)

	# Act
	ps.replace_weapon(weapon_old, weapon_new)

	# Assert — old ушёл, new присутствует
	var weapons: Array[ItemData] = ps.get_weapons()
	assert_int(weapons.size()).is_equal(1)
	assert_bool(weapons.has(weapon_old)).is_false()
	assert_bool(weapons.has(weapon_new)).is_true()
