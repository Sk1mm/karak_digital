class_name ClassRegistryTest  # GdUnit4 тест-сюит: smoke tests для Sprint 00
extends GdUnitTestSuite  # GdUnit4 базовый класс

# ===================================================
# CLASS REGISTRY TEST — Sprint 00
# ===================================================
# Два теста без внешних зависимостей:
#   1. GdUnit4 фреймворк работает (assert проходит)
#   2. Dictionary[Vector2i, RefCounted] typed syntax работает в Godot 4.7.2
#      (закрывает open question из ADR-0004 architecture review)
# ===================================================

## Подтверждает что GdUnit4 загружен и assert работает.
## Нет внешних зависимостей — этот тест не может упасть по причинам вне фреймворка.
func test_gdunit4_framework_is_operational() -> void:
	assert_bool(true).is_true()


## Smoke-тест: Dictionary[Vector2i, RefCounted] typed syntax компилируется
## и корректно работает в Godot 4.7.2.
##
## Закрывает open question из ADR-0004: typed Dictionary с Vector2i ключом
## не был верифицирован на версии 4.7.x (за пределами LLM knowledge cutoff).
## Если тест падает с ParseError или crash — откатиться на untyped Dictionary.
func test_typed_dictionary_vector2i_compiles_and_stores() -> void:
	# --- Arrange ---
	# Vector2i хешируется по значению (x, y), не по ссылке объекта.
	var grid: Dictionary[Vector2i, RefCounted] = {}

	# --- Act ---
	grid[Vector2i(1, 2)] = RefCounted.new()
	var retrieved: RefCounted = grid[Vector2i(1, 2)]

	# --- Assert ---
	assert_object(retrieved).is_not_null()
