class_name PlayerStateKeySignalsTest  # GdUnit4 integration: Story 005 — key signals AC-22
extends GdUnitTestSuite  # GdUnit4 базовый класс для всех test suites

# ===================================================
# PLAYER STATE KEY SIGNALS TEST — Story 005 (Integration)
# ===================================================
# Покрывает acceptance criteria:
#   AC-22 — set_key(null) при key!=null → key==null, item_removed(old_key, SLOT_KEY) испущен
#
# Дополнительный edge case:
#   set_key(valid_key) при key==null → item_added(key, SLOT_KEY) испущен
#   (позитивный путь — проверяет полный lifecycle ключа)
#
# Integration-тест: проверяет полную сигнальную цепочку.
# Сигналы — основной механизм оповещения HUD об изменениях инвентаря (ADR-0002).
#
# ADR Reference: ADR-0002 (Typed signals — item_added/item_removed)
# ADR Reference: ADR-0003 (PlayerState as Node)
# ADR Reference: ADR-0007 (SlotType как int до GameEnums — SLOT_KEY = 1)
# Story: 005 — Inventory Key, Scrolls, Accessors (Integration)
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


## Создаёт ItemData для ключа (attack_bonus = 0).
func _create_key(p_id: String) -> ItemData:
	var item := ItemData.new()
	item.id = StringName(p_id)  # dynamic id — не compile-time StringName literal
	item.attack_bonus = 0       # ключи не дают attack_bonus
	return item


# ===================================================
# AC-22: set_key(null) при key!=null → item_removed(old_key, SLOT_KEY) испущен
# ===================================================

## AC-22: set_key(null) при заполненном слоте →
##        key == null, item_removed(old_key, SLOT_KEY) испущен с корректными аргументами.
## Это основной signal-тест для операции "сдать ключ" (использовать для входа в замок).
func test_player_state_set_key_null_emits_item_removed() -> void:
	# Arrange — поместить ключ в слот
	var ps: PlayerState = _create_player_state()
	var existing_key: ItemData = _create_key("dungeon_key")
	ps.set_key(existing_key)
	assert_bool(ps.has_key).is_true()  # предусловие: ключ в слоте

	var monitor := monitor_signals(ps)

	# Act — "использовать" ключ (удалить через set_key(null))
	ps.set_key(null)

	# Assert — ключ удалён из state
	assert_object(ps.key).is_null()
	assert_bool(ps.has_key).is_false()

	# Assert — item_removed(old_key, SLOT_KEY) испущен с корректными аргументами (AC-22)
	# SLOT_KEY = 1 — int константа (ADR-0007); не передаём magic number 1 напрямую
	await assert_signal(monitor).is_emitted("item_removed",
		[existing_key, PlayerState.SLOT_KEY])

	# Assert — item_added НЕ испущен (удаление — не добавление)
	await assert_signal(monitor).is_not_emitted("item_added")


## Edge case (позитивный путь): set_key(valid_key) при key==null →
##        item_added(key, SLOT_KEY) испущен, item_removed НЕ испущен.
## Проверяет полный lifecycle: добавление, затем удаление ключа.
func test_player_state_set_key_with_item_emits_item_added() -> void:
	# Arrange — слот пуст
	var ps: PlayerState = _create_player_state()
	assert_object(ps.key).is_null()  # предусловие: нет ключа

	var new_key: ItemData = _create_key("new_dungeon_key")
	var monitor := monitor_signals(ps)

	# Act — подобрать ключ
	ps.set_key(new_key)

	# Assert — ключ установлен
	assert_object(ps.key).is_equal(new_key)
	assert_bool(ps.has_key).is_true()

	# Assert — item_added(new_key, SLOT_KEY) испущен (ADR-0002)
	await assert_signal(monitor).is_emitted("item_added",
		[new_key, PlayerState.SLOT_KEY])

	# Assert — item_removed НЕ испущен (добавление — не удаление)
	await assert_signal(monitor).is_not_emitted("item_removed")
