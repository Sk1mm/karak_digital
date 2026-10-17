class_name PlayerStateKeyScrollsTest  # GdUnit4 тест-сюит: Story 005 — Key/Scrolls unit-тесты
extends GdUnitTestSuite  # GdUnit4 базовый класс для всех test suites

# ===================================================
# PLAYER STATE KEY SCROLLS TEST — Story 005
# ===================================================
# Покрывает acceptance criteria:
#   AC-19 — add_scroll при scrolls.size()==3 → false, size не изменился
#   AC-20 — set_key(new_key) при key!=null → push_error, key не изменился
#   AC-21 — set_key(null) при key==null → no-op (item_added/item_removed НЕ испущены)
#   AC-33 — remove_key() при key!=null → key==null, item_removed испущен
#   AC-34 — remove_key() при key==null → no-op, сигналы не испускаются
#   AC-35 — has_key property отражает наличие ключа корректно
#
# Сигналы для AC-22 — см. integration-тест player_state_key_signals_test.gd.
#
# Паттерн изоляции:
#   Каждый тест создаёт собственный инстанс PlayerState через _create_player_state().
#   auto_free() — GdUnit4 очищает инстансы после каждого теста.
#
# Паттерн signal assertion:
#   monitor_signals(ps) запускается ПЕРЕД действием.
#   assert_signal(monitor) проверяет испущен / не испущен ПОСЛЕ действия.
#   await нужен, так как GdUnit4 signal API асинхронный.
#
# ADR Reference: ADR-0002 (Typed signals)
# ADR Reference: ADR-0003 (PlayerState as Node)
# ADR Reference: ADR-0007 (SlotType как int до GameEnums)
# ADR Reference: ADR-0013 (Loot strategy — PlayerState не решает выбор)
# Story: 005 — Inventory Key, Scrolls, Accessors
# ===================================================


# ===================================================
# HELPERS
# ===================================================

## Создаёт минимально валидный HeroClassData для использования в тестах.
## Не сохраняется на диск — только in-memory Resource.
##
## Contract: возвращает HeroClassData с id, display_name и max_hp — минимум для
## прохождения assert(character_class != null) в PlayerState._ready().
func _create_hero_class() -> HeroClassData:
	# HeroClassData — Resource, не требует сцены и _ready(); безопасно для unit-тестов
	var hcd := HeroClassData.new()
	hcd.max_hp = 5
	hcd.id = &"test_hero"          # StringName literal — ADR: prefer &"name" syntax
	hcd.display_name = "Test Hero"
	return hcd


## Создаёт PlayerState, добавляет в Scene Tree (вызывает _ready()),
## регистрирует в auto_free для автоматической очистки после теста.
##
## Contract:
##   - player_id = 1 (допустимый диапазон 1–5 по AC-27)
##   - character_class с max_hp=5 (достаточно для всех key/scroll-тестов)
##   - Возвращённый инстанс автоматически освобождается GdUnit4 через auto_free()
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


## Создаёт ItemData с заданным id для использования в тестах.
## Используется для создания ключей и свитков — attack_bonus = 0 по умолчанию.
func _create_item(p_id: String) -> ItemData:
	var item := ItemData.new()
	item.id = StringName(p_id)  # dynamic id — не compile-time StringName literal
	item.attack_bonus = 0       # ключи и свитки не дают attack_bonus
	return item


# ===================================================
# AC-19: add_scroll при scrolls.size()==3 → false, size не изменился
# ===================================================

## AC-19: попытка добавить четвёртый свиток при уже заполненных 3 слотах →
##        возвращает false, scrolls.size() остаётся 3.
## Граничный случай: SCROLL_SLOTS == 3 — максимум строго ограничен (GDD).
func test_player_state_add_scroll_when_slots_full_returns_false() -> void:
	# Arrange — заполнить все три слота свитков
	var ps: PlayerState = _create_player_state()
	ps.add_scroll(_create_item("scroll_1"))
	ps.add_scroll(_create_item("scroll_2"))
	ps.add_scroll(_create_item("scroll_3"))
	assert_int(ps.scrolls.size()).is_equal(3)  # предусловие: ровно 3 свитка

	# Act — попытка добавить четвёртый
	var result: bool = ps.add_scroll(_create_item("scroll_overflow"))

	# Assert — отклонено, размер не изменился (AC-19)
	assert_bool(result).is_false()
	assert_int(ps.scrolls.size()).is_equal(3)


# ===================================================
# AC-20: set_key при key!=null → push_error, key не изменился
# ===================================================

## AC-20: попытка установить ключ когда слот уже занят →
##        push_error вызван с точным сообщением, key не изменился.
## KEY_SLOTS == 1: ключевой слот уникален — нельзя перезаписать напрямую.
func test_player_state_set_key_when_slot_occupied_pushes_error() -> void:
	# Arrange — поместить ключ в слот
	var ps: PlayerState = _create_player_state()
	var existing_key: ItemData = _create_item("key_existing")
	ps.set_key(existing_key)
	assert_object(ps.key).is_equal(existing_key)  # предусловие: ключ установлен

	var new_key: ItemData = _create_item("key_new")

	# Assert — push_error вызван (GdUnit4: assert_error с Callable)
	await assert_error(func() -> void: ps.set_key(new_key)) \
		.is_push_error("set_key: key slot already occupied")

	# Assert — key не изменился (AC-20)
	assert_object(ps.key).is_equal(existing_key)


# ===================================================
# AC-21: set_key(null) при key==null → no-op (сигналы НЕ испущены)
# ===================================================

## AC-21: set_key(null) когда ключа нет — no-op.
## Ни item_added, ни item_removed НЕ испускаются (нет реального изменения состояния).
func test_player_state_set_key_null_when_empty_is_noop_no_signals() -> void:
	# Arrange — ключа нет
	var ps: PlayerState = _create_player_state()
	assert_object(ps.key).is_null()  # предусловие: слот пуст

	var monitor := monitor_signals(ps)

	# Act
	ps.set_key(null)

	# Assert — сигналы НЕ испущены (AC-21): нет события при отсутствии изменений
	await assert_signal(monitor).is_not_emitted("item_added")
	await assert_signal(monitor).is_not_emitted("item_removed")

	# Assert — key по-прежнему null
	assert_object(ps.key).is_null()


# ===================================================
# AC-33: remove_key при key!=null → key==null, item_removed испущен
# ===================================================

## AC-33: remove_key() когда ключ есть →
##        key == null, has_key == false, item_removed(old_key, SLOT_KEY) испущен.
func test_player_state_remove_key_when_key_present_clears_key() -> void:
	# Arrange — поместить ключ в слот
	var ps: PlayerState = _create_player_state()
	var existing_key: ItemData = _create_item("key_to_remove")
	ps.set_key(existing_key)
	assert_bool(ps.has_key).is_true()  # предусловие: ключ есть

	var monitor := monitor_signals(ps)

	# Act
	ps.remove_key()

	# Assert — ключ удалён (AC-33)
	assert_object(ps.key).is_null()
	assert_bool(ps.has_key).is_false()

	# Assert — item_removed испущен с корректными аргументами (AC-33)
	await assert_signal(monitor).is_emitted("item_removed",
		[existing_key, PlayerState.SLOT_KEY])  # SLOT_KEY = 1 (не magic number — ADR-0007)


# ===================================================
# AC-34: remove_key при key==null → no-op
# ===================================================

## AC-34: remove_key() когда ключа нет — no-op.
## Ни item_removed, ни item_added НЕ испускаются.
func test_player_state_remove_key_when_empty_is_noop() -> void:
	# Arrange — ключа нет
	var ps: PlayerState = _create_player_state()
	assert_object(ps.key).is_null()  # предусловие: слот пуст

	var monitor := monitor_signals(ps)

	# Act
	ps.remove_key()

	# Assert — состояние не изменилось (AC-34)
	assert_object(ps.key).is_null()

	# Assert — сигналы НЕ испущены
	await assert_signal(monitor).is_not_emitted("item_removed")
	await assert_signal(monitor).is_not_emitted("item_added")


# ===================================================
# AC-35: has_key отражает наличие ключа корректно
# ===================================================

## AC-35a: set_key(some_key) → has_key == true.
## Computed property has_key основана на key != null — проверяем корректность.
func test_player_state_has_key_true_after_set_key() -> void:
	# Arrange
	var ps: PlayerState = _create_player_state()
	assert_bool(ps.has_key).is_false()  # предусловие: изначально false

	# Act
	ps.set_key(_create_item("key_ac35"))

	# Assert — has_key теперь true (AC-35)
	assert_bool(ps.has_key).is_true()


## AC-35b: set_key(some_key) затем remove_key() → has_key == false.
## has_key переходит true → false при удалении — single source of truth через key field.
func test_player_state_has_key_false_after_remove_key() -> void:
	# Arrange — установить ключ
	var ps: PlayerState = _create_player_state()
	ps.set_key(_create_item("key_ac35b"))
	assert_bool(ps.has_key).is_true()  # предусловие: ключ есть

	# Act
	ps.remove_key()

	# Assert — has_key вернулся в false (AC-35)
	assert_bool(ps.has_key).is_false()
