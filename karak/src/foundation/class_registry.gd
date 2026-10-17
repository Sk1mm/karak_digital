# class_name убран намеренно — naming conflict с Autoload "ClassRegistry".
# В Godot 4.7 при наличии и class_name ClassRegistry и Autoload ClassRegistry
# expression "ClassRegistry" может резолвиться на GDScriptNativeClass вместо Autoload node.
# Autoload регистрируется через Project Settings по пути файла — class_name не нужен.
# Доступ: ClassRegistry.get_hero_class(...) через Autoload global name.
extends Node  # Must be Node to register as Autoload in Project Settings

# ===================================================
# CLASS REGISTRY — Foundation Layer
# ===================================================
# READ-ONLY. Never add mutable game state here.
#
# Purpose:
#   Loads all 7 HeroClassData .tres resources once at startup and exposes
#   them as an O(1) Dictionary lookup keyed by StringName id.
#
# Consumers:
#   DraftSystem      — calls get_all_classes() to populate hero picker
#   PlayerState      — calls get_class(id) to read max_hp on character creation
#   UI               — calls get_class(id) to read display_name for labels
#   Any future system that needs class stats at runtime
#
# Autoload registration (done once by the user in Godot Editor):
#   Project Settings → Autoload → Name: ClassRegistry
#   Path: res://src/foundation/class_registry.gd
#
# After registration, any script can call:
#   ClassRegistry.get_class(&"warrior")
#   ClassRegistry.get_all_classes()
#   without preload or @export.
#
# ADR Reference: ADR-0001 (Foundation Layer — no mutable state in Autoloads)
# Control Manifest: Only ClassRegistry, ItemDatabase, MonsterDatabase are Autoloads
#
# Forbidden: @export fields for .tres files (use preload in _ready only)
# Forbidden: mutable game state (counters, runtime flags, per-session data)
# Performance guardrail: get_class() is O(1) Dictionary lookup — no allocations per call
# ===================================================

# ===================================================
# CONSTANTS
# ===================================================

## Сколько классов предлагать игроку за один выбор (драфт).
## Tuning knob: безопасный диапазон 2–5 (GDD §Draft System).
## Вынесен в константу, чтобы значение не дублировалось по всему коду (DraftSystem, UI).
## ADR Reference: ADR-0001 (Foundation Layer — data-driven, no magic numbers in methods)
const CLASS_OFFER_COUNT: int = 3


# ===================================================
# PRIVATE STATE
# ===================================================

## Internal map from StringName id → HeroClassData resource.
## Populated once in _ready(), never modified after.
## Untyped Dictionary because Godot 4.x does not support Dictionary[StringName, HeroClassData] syntax.
var _classes: Dictionary = {}


# ===================================================
# BUILT-IN VIRTUAL METHODS
# ===================================================

## _ready: loads all 7 HeroClassData .tres resources and indexes them by id.
## Called automatically by Godot when the Autoload node enters the scene tree.
## After _ready returns, _classes is immutable for the lifetime of the session.
func _ready() -> void:
	# --- ШАГ 0: guard against double initialisation ---
	# Autoload _ready() is called once by Godot; in unit tests _ready() is called manually.
	# A second call would silently overwrite the same keys — no data loss here, but it
	# indicates a test setup error and should be caught early.
	# push_error (not assert) — avoids Godot debug crash in unit tests while still logging.
	if not _classes.is_empty():
		push_error("ClassRegistry._ready() called more than once.")
		return

	# --- ШАГ 1: preload all 7 .tres resources ---
	# Using preload() (compile-time) rather than load() (runtime) so that:
	#   a) Godot validates paths at export/import time, not silently at runtime
	#   b) Resources are guaranteed present before any other Autoload or scene uses them
	# Paths use res:// — uid:// refs are assigned by Godot on first open and are NOT
	# portable across machines until the project has been opened in the editor (ADR-0001).
	var all_resources: Array[HeroClassData] = [
		preload("res://assets/data/classes/warrior.tres"),
		preload("res://assets/data/classes/rogue.tres"),
		preload("res://assets/data/classes/wizard.tres"),
		preload("res://assets/data/classes/warlock.tres"),
		preload("res://assets/data/classes/swordsman.tres"),
		preload("res://assets/data/classes/oracle.tres"),
		preload("res://assets/data/classes/swordswoman.tres"),
	]

	# --- ШАГ 2: index each resource by its StringName id ---
	# Dictionary key is StringName (via &"..." literal in .tres id field) for O(1) lookup.
	# If two .tres files share the same id, the second silently overwrites the first —
	# that would be a data authoring error caught by AC-01 (unique ids test).
	for hero_class: HeroClassData in all_resources:
		_classes[hero_class.id] = hero_class


# ===================================================
# PUBLIC METHODS
# ===================================================

## Returns the HeroClassData for the given id, or null if not found.
## Note: named get_hero_class (not get_class) because get_class() is a reserved
## built-in method of Object in Godot 4 that returns String — cannot override.
## Contract:
##   - O(1) Dictionary lookup — no allocations.
##   - Returns the shared Resource reference directly (caller must not mutate it).
##     If mutation is needed, caller must call .duplicate() (Resource.duplicate()).
##   - Emits push_error and returns null for unknown ids — no crash.
##   - Accepts StringName literals: get_hero_class(&"warrior")
func get_hero_class(id: StringName) -> HeroClassData:
	# --- ШАГ 1: guard against empty id ---
	# An empty StringName is a programming error — reject early with a clear message.
	if id == &"":
		push_error("ClassRegistry.get_class: id must not be empty.")
		return null

	# --- ШАГ 2: Dictionary lookup ---
	# _classes.get(key, default) returns Variant — null if the key is absent.
	var raw: Variant = _classes.get(id, null)

	# --- ШАГ 3: guard against unknown id ---
	if raw == null:
		push_error("ClassRegistry.get_class: unknown id '%s'. Check .tres id fields." % id)
		return null

	# --- ШАГ 4: guard against wrong resource type ---
	# Catches data-authoring bugs where a .tres of the wrong type was placed under the same id.
	# Using `as` alone would silently return null with a misleading "unknown id" error (ADR-0001).
	if not raw is HeroClassData:
		push_error("ClassRegistry.get_class: id '%s' maps to %s, expected HeroClassData." % [id, (raw as Object).get_class()])
		return null

	return raw as HeroClassData


## Returns all registered HeroClassData objects as an Array.
## Contract:
##   - Always returns exactly 7 items after _ready() completes.
##   - Order is insertion order (matches the preload list in _ready).
##   - Returns a new Array wrapper each call, but the HeroClassData references inside
##     are shared — callers must not mutate the Resource objects.
##   - O(n) where n == 7 — effectively O(1) for this fixed dataset.
func get_all_classes() -> Array[HeroClassData]:
	# --- ШАГ 1: copy Dictionary values into a typed Array ---
	# _classes.values() returns an untyped Array; we cast each element to build
	# the typed Array[HeroClassData] required by static typing rules.
	var result: Array[HeroClassData] = []
	result.assign(_classes.values())
	return result


## Возвращает n случайных HeroClassData из тех, что ещё не выбраны.
## Contract:
##   - already_selected фильтруется по ссылке (reference equality) — один и тот же
##     .tres Resource, загруженный через preload, имеет одинаковый указатель.
##   - Если доступных классов меньше или ровно n — возвращает все доступные (не ошибка).
##   - RNG передаётся снаружи (dependency injection) — никогда не создаётся внутри метода.
##     Это гарантирует детерминизм при тестировании и воспроизводимость при фиксированном seed.
##   - Использует частичный Fisher-Yates shuffle: перемешиваются только первые n позиций,
##     что даёт O(n) вместо O(total) при полном shuffle.
##   - Возвращает новый Array; ссылки внутри — shared (не дублировать без необходимости).
##   - Forbidden: не создавать новый RandomNumberGenerator внутри метода (нарушает DI-правило).
##   - Forbidden: не добавлять мутабельное состояние в Autoload (ADR-0001).
## Story 004 — ClassRegistry.pick_random
func pick_random(n: int, rng: RandomNumberGenerator,
		already_selected: Array[HeroClassData] = []) -> Array[HeroClassData]:
	# --- ШАГ 0: guard на некорректный n ---
	# n < 0 — программная ошибка caller'а; молча вернуть [] без warning — тихий баг.
	# push_warning (не push_error) — не прерывает поток, но появляется в Godot Output.
	if n < 0:
		push_warning("ClassRegistry.pick_random: n must be >= 0, got %d." % n)
		return []

	# --- ШАГ 1: собрать список доступных классов ---
	# Фильтруем get_all_classes() по принципу reference equality.
	# GDScript == на Resource-объектах проверяет идентичность указателя для одного и того же
	# .tres, загруженного через preload — это именно то, что нам нужно (AC-10).
	# Мы не используем id-сравнение намеренно: если caller передал другой экземпляр
	# с тем же id, это всё равно разный объект и он не должен фильтроваться.
	var available: Array[HeroClassData] = []
	for hero_class: HeroClassData in get_all_classes():
		var is_excluded: bool = false
		for excluded: HeroClassData in already_selected:
			if excluded == hero_class:  # reference equality (same preloaded Resource ptr)
				is_excluded = true
				break
		if not is_excluded:
			available.append(hero_class)

	# --- ШАГ 2: вернуть все доступные, если их меньше или ровно n (AC-12) ---
	# Это не ошибка — caller запросил "до n", и мы отдаём максимум что есть.
	if available.size() <= n:
		return available.duplicate()

	# --- ШАГ 3: частичный Fisher-Yates shuffle (первые n позиций) ---
	# Алгоритм: для i от 0 до n-1 выбираем случайный индекс j из [i, size-1],
	# меняем местами available[i] и available[j].
	# После n итераций первые n элементов — корректная случайная выборка без повторений.
	# O(n) по времени и O(1) по дополнительной памяти (shuffle in-place).
	var size: int = available.size()
	for i: int in range(n):
		# randi_range(i, size - 1) — включительно с обоих концов (Godot 4 API).
		# Передаём rng снаружи — детерминизм и тестируемость (DI, ADR-0001).
		var j: int = rng.randi_range(i, size - 1)
		# Swap: временная переменная, тип явный для static-typing требований.
		var tmp: HeroClassData = available[i]
		available[i] = available[j]
		available[j] = tmp

	# --- ШАГ 4: вернуть первые n элементов после shuffle ---
	# slice(0, n) возвращает новый Array с элементами [0 .. n-1] включительно.
	# Не используем resize() + assign() чтобы не мутировать available (читаемость).
	return available.slice(0, n)
