# GdUnit4 Known Error Patterns

Этот файл обновляется скиллом `/test-review` после каждого нового решённого кейса.
Перед диагностикой ошибки — сначала сверить с этим файлом.

---

## P-001: double-free → ссылка на Nil

**Симптом:**
```
Error: 'Invalid access to property or key 'X' on a base object of type 'Nil'.'
```
Переменная (например `mock_dungeon`) равна Nil во время теста, хотя была присвоена в `before_test`.

**Корневая причина:**
`auto_free(node_A)` + `auto_free(node_B)` + `node_A.add_child(node_B)`.
Когда GdUnit4 освобождает `node_A`, Godot также освобождает `node_B` (как дочерний узел).
Затем `auto_free` пробует освободить `node_B` снова → double-free → ссылка становится Nil.

**Решение:**
Никогда не использовать `add_child` для узлов под `auto_free`.
Вместо `gsm.add_child(mock_dungeon)` — просто `gsm.dungeon_ref = mock_dungeon` (прямое присваивание поля).

**Пример правильного кода:**
```gdscript
func before_test() -> void:
    gsm = auto_free(GameStateManager_.new())
    mock_dungeon = auto_free(LocalMockDungeon.new())
    gsm.dungeon_ref = mock_dungeon  # НЕ add_child!
```

---

## P-002: compile error в внешнем mock-файле → MockClass.new() возвращает null

**Симптом:**
```
Error: 'Invalid access to property or key 'X' on a base object of type 'Nil'.'
```
Mock-переменная Nil сразу, ещё до теста.
`auto_free` возвращает null если объект невалиден: `if not is_instance_valid(obj): return obj`.

**Корневая причина:**
Внешний файл с `class_name MockX` содержит проблему:
- Override встроенного метода Godot (`get_node_or_null`) без `@warning_ignore("native_method_override")`
- Конфликт имён с inner class в другом тестовом файле
- Любая другая причина, по которой Godot не может скомпилировать файл

**Решение:**
Использовать inner class прямо в тест-файле вместо отдельного `.gd` файла с `class_name`.

```gdscript
# Внутри test_file.gd
class LocalMockDungeon extends Node:
    var regenerate_calls: int = 0
    func regenerate() -> void: regenerate_calls += 1
    func generate_floor(_floor_index: int) -> Dictionary:
        return { "rooms": [Rect2i(1,1,5,5)], ... }
    # НЕ переопределять get_node_or_null — Node.get_node_or_null вернёт null сам
```

**Правило именования:** использовать `LocalMockX` (с префиксом `Local`) чтобы избежать конфликта с любыми глобальными `class_name`.

---

## P-003: gsm is Nil во всех тестах → compile error в тестируемом классе

**Симптом:**
```
Error: 'Invalid assignment of property or key 'X' on a base object of type 'Nil'.'
Error: 'Cannot call method 'queue_free' on a null value.'
```
Все тесты в файле падают с Nil, включая первую строку test body.

**Корневая причина:**
`GameStateManager_.new()` возвращает null потому что у класса compile error.
Типичная причина: присваивание свойства на объект объявленный как `const`:
```gdscript
const WARRIOR_DEF: ClassDefinition = preload("res://...")
# GDScript может выдать compile error на:
WARRIOR_DEF._initialized = false  # присваивание на const → ошибка в некоторых версиях
```

**Решение:**
Не изменять свойства `const`-объектов напрямую в GDScript.
Вместо этого — использовать `duplicate()`:
```gdscript
WARRIOR_DEF.duplicate().initialize(player_stats)
# duplicate() создаёт независимую копию; non-@export поля сбрасываются в дефолт
```

**Проверка:** если все тесты в файле падают с одинаковой ошибкой Nil — первым делом проверить GameStateManager.gd (или другой тестируемый класс) на compile error.

---

## P-004: add_child в before_test + after_test → gsm is Nil во всём файле

**Симптом:**
```
Error: 'Invalid assignment of property or key 'X' on a base object of type 'Nil'.'
Error: 'Cannot call method 'queue_free' on a null value.'  # в after_test
```
Обе ошибки в каждом тесте.

**Корневая причина:**
`add_child(gsm)` в `before_test` + `gsm.queue_free()` в `after_test` конфликтует с тем как GdUnit4 обрабатывает дочерние узлы тест-сьюта. При ошибке в `register_dungeon` (или любом вызове внутри `before_test`), GdUnit4 может прервать `before_test` не записав `gsm`.

**Решение:**
Для тестов с Node-mock без необходимости в scene tree — использовать `auto_free` без `add_child`.
`add_child` нужен только если тест проверяет поведение специфичное для scene tree (сигналы дерева, `_ready()`, `get_tree()`).

**Эталонный паттерн для GSM тестов без scene tree:**
```gdscript
func before_test() -> void:
    gsm = auto_free(GameStateManager_.new())
    gsm._skip_scene_change = true
    mock_dungeon = auto_free(LocalMockDungeon.new())
    gsm.dungeon_ref = mock_dungeon
    gsm._current_state  = GameStateManager_.GameState.DEATH
    gsm._previous_state = GameStateManager_.GameState.ARENA
# Нет after_test — auto_free сам всё чистит
```

---

## P-005: WARRIOR_DEF._initialized блокирует initialize() при рестарте

**Симптом:**
```
assert_int(gsm.player_stats.level).is_equal(1)  # FAILED: was '0'
```
После DEATH→DUNGEON перехода `player_stats.level == 0` вместо `1`.

**Корневая причина:**
`WARRIOR_DEF` — preload-singleton, общий для всех экземпляров.
После первого `WARRIOR_DEF.initialize(player_stats)` (в MAIN_MENU→DUNGEON), `_initialized = true`.
Повторный вызов `WARRIOR_DEF.initialize(...)` возвращает досрочно → статы не обновляются.

**Решение в production коде:**
`WARRIOR_DEF.duplicate().initialize(player_stats)`.
`duplicate()` создаёт копию Resource, в которой `non-@export` поля (`_initialized`) сбрасываются в дефолт (`false`).

**Решение в тестах (обойти проблему):**
Установить `_current_state = DEATH` напрямую, минуя MAIN_MENU→DUNGEON.
Тогда `WARRIOR_DEF._initialized` никогда не становится `true` до теста,
и `duplicate().initialize()` в DEATH handler гарантированно отработает.

---

## P-006: preload() несуществующего .tscn на уровне класса → 'new' in base 'GDScript'

**Симптом:**
```
Error: 'Invalid call. Nonexistent function 'new' in base 'GDScript'.'
```
Все тесты в файле падают с этой ошибкой. При этом статические константы класса (`ITEM_POOL_BY_FLOOR`) могут быть доступны и тест на них проходит.

**Корневая причина:**
```gdscript
const ITEM_FIGURE_SCENE: PackedScene = preload("res://src/entities/ItemFigure.tscn")
```
`preload()` выполняется при компиляции класса. Если файл не существует (например, `.tscn` ещё не создан в Godot Editor), класс не регистрируется как полноценный тип. Godot возвращает raw GDScript-объект, у которого нет метода `.new()`.

**Решение:**
Заменить `const ITEM_FIGURE_SCENE` на `const ITEM_FIGURE_SCENE_PATH: String` и использовать `load()` внутри метода, который реально спавнит объект:
```gdscript
# Вместо:
const ITEM_FIGURE_SCENE: PackedScene = preload("res://src/entities/ItemFigure.tscn")

# Использовать:
const ITEM_FIGURE_SCENE_PATH: String = "res://src/entities/ItemFigure.tscn"

func _spawn_item_in_room(...) -> void:
    var scene: PackedScene = load(ITEM_FIGURE_SCENE_PATH)
    var figure: ItemFigure = scene.instantiate() as ItemFigure
```

**Когда применять:**
Когда `.tscn` создаётся в Godot Editor (не через код) и может отсутствовать во время юнит-тестов.
Тесты, которые не вызывают метод со `load()`, работают нормально.

---

## Установленные паттерны тестов (GSM)

### Паттерн А: auto_free без scene tree (для unit-тестов состояний)
```gdscript
# Эталон: gsm_arena_guard_test.gd, gsm_restart_test.gd
func before_test() -> void:
    gsm = auto_free(GameStateManager_.new())
    gsm._skip_scene_change = true
    # Если нужен mock-dungeon:
    mock_dungeon = auto_free(LocalMockDungeon.new())
    gsm.dungeon_ref = mock_dungeon
    # Установить состояние напрямую:
    gsm._current_state  = GameStateManager_.GameState.TARGET_STATE
    gsm._previous_state = GameStateManager_.GameState.PREVIOUS_STATE
# НЕТ after_test
```

### Паттерн Б: add_child + after_test (когда нужен scene tree)
```gdscript
# Эталон: pause_state_test.gd
# MockDungeon — inner class в том же файле (НЕ отдельный файл с class_name)
class MockDungeon extends Node:
    func regenerate() -> void: pass
    ...

func before_test() -> void:
    gsm = GameStateManager_.new()
    add_child(gsm)
    mock_dungeon = MockDungeon.new()
    add_child(mock_dungeon)
    gsm.register_dungeon(mock_dungeon)

func after_test() -> void:
    if gsm.arena_ref != null:
        gsm.arena_ref.queue_free()
    gsm.queue_free()
    await get_tree().process_frame
# НЕ вызывать queue_free для mock_dungeon отдельно — он дочерний gsm
```

### Правило выбора паттерна:
- Нужен `get_tree()`, `_ready()`, сигналы дерева → Паттерн Б
- Всё остальное → Паттерн А (проще, надёжнее)
