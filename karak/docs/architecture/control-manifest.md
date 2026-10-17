# Control Manifest

> **Engine**: Godot 4.7.2 (GDScript)
> **Last Updated**: 2026-10-12
> **Manifest Version**: 2026-10-12
> **ADRs Covered**: ADR-0001, ADR-0002, ADR-0003, ADR-0004, ADR-0005, ADR-0006, ADR-0007, ADR-0008, ADR-0009, ADR-0011, ADR-0012, ADR-0013, ADR-0014, ADR-0015
> **Status**: Active — regenerate with `/create-control-manifest update` when ADRs change

`Manifest Version` is the date this manifest was generated. Story files embed
this date when created. `/story-readiness` compares a story's embedded version
to this field to detect stories written against stale rules. Always matches
`Last Updated` — they are the same date, serving different consumers.

This manifest is a programmer's quick-reference extracted from all Accepted ADRs,
technical preferences, and engine reference docs. For the reasoning behind each
rule, see the referenced ADR.

---

## Foundation Layer Rules

*Applies to: scene management, event architecture, autoloads, engine initialisation, CanvasLayer setup*

### Required Patterns

- **Только `ClassRegistry`, `ItemDatabase`, `MonsterDatabase` являются Autoload** — только read-only data-реестры регистрируются в Project Settings → Autoload — источник: ADR-0001
- **Все системы с изменяемым состоянием — in-scene Node** — подключаются через `@export` в GameScene, не через Autoload — источник: ADR-0001
- **Ресурсы в Autoload загружаются через `preload()` в `_ready()`** — не через Inspector-слоты `@export` — источник: ADR-0001
- **Все межсистемные соединения сигналов — только в `GameScene._wire_signals()`** — ни одна система не подключает сигналы других систем в своём `_ready()` — источник: ADR-0002
- **Порядок в `GameScene._ready()`**: `dungeon_generator.initialize()` → `_wire_signals()` — источник: ADR-0002
- **Обязательна типизация сигналов**: `signal hp_changed(new_hp: int)` — нетипизированные сигналы запрещены — источник: ADR-0002
- **Callable-синтаксис для `connect()`**: `signal_name.connect(target._on_method)` — источник: ADR-0002
- **`DungeonGenerator.initialize()` откладывает отправку `dungeon_initialized`** через `call_deferred()` — так сигнал гарантированно уйдёт после `_wire_signals()` — источник: ADR-0005
- **Защита от двойной инициализации**: `if _initialized: push_error(...); return` — первый оператор в `initialize()` — источник: ADR-0005
- **`GameEnums` — plain `class_name` файл без `extends`** — не Autoload, не инстанциируется, не импортируется — источник: ADR-0007
- **Все межсистемные enum живут в `GameEnums`** — доступ из любого скрипта через `GameEnums.EnumName.VALUE` без `preload` — источник: ADR-0007
- **Enum-параметры в сигналах типизируются как `int`** — с комментарием `## field: GameEnums.EnumType` — источник: ADR-0007
- **Назначение слоёв CanvasLayer — в Inspector**: `HUD` = layer 10; `CombatUI` = layer 11; `InventoryUI` = layer 10 — источник: ADR-0009
- **`TileRevealVFX` — `extends Node2D` в пространстве сцены** — НЕ CanvasLayer; следует за позициями тайлов при движении камеры — источник: ADR-0009
- **Переключение видимости CanvasLayer через `visible = true/false`** — НЕ `queue_free()`/`instantiate()`, иначе состояние нода теряется — источник: ADR-0009

### Forbidden Approaches

- **Никогда не делать Autoload из системы с изменяемым состоянием** — источник: ADR-0001
- **Никогда не использовать EventBus Autoload** (глобальный ретранслятор сигналов) — источник: ADR-0001
- **Никогда не добавлять изменяемое игровое состояние в Autoload-классы** — источник: ADR-0001
- **Никогда не использовать строковый `connect()`**: `connect("signal_name", target, "method")` — устаревший паттерн Godot 3 — источник: ADR-0002
- **Никогда не подключать внешние сигналы в `_ready()` самих систем** — источник: ADR-0002
- **Никогда не эмитировать `dungeon_initialized` синхронно** — уйдёт до `_wire_signals()`, TurnManager не получит сигнал — источник: ADR-0005
- **Никогда не использовать `await` в `GameScene._ready()`** — async в `_ready()` создаёт баги порядка — источник: ADR-0005
- **Никогда не регистрировать `GameEnums` как Autoload** — `class_name` даёт тот же глобальный доступ с нулевым cost — источник: ADR-0007
- **Никогда не делать `preload("res://...game_enums.gd")`** — не нужно, `class_name` уже глобальный — источник: ADR-0007
- **Никогда не добавлять методы или логику в `GameEnums.gd`** — только объявления enum — источник: ADR-0007
- **Никогда не делать `TileRevealVFX` как `CanvasLayer`** — анимации тайлов съедут с позиций при движении камеры — источник: ADR-0009
- **Никогда не ставить `CombatUI` на layer 10** — при равных layer-значениях порядок рендеринга зависит от позиции в дереве сцены — источник: ADR-0009
- **Никогда не делать прямой вызов методов Presentation→Feature** — единственный одобренный P→F канал: сигнал `CombatUI.player_action_taken` — источник: ADR-0009
- **Никогда не добавлять новый сигнал Presentation→Feature без обновления ADR-0009** — источник: ADR-0009

---

## Core Layer Rules

*Applies to: PlayerState, TileSystem, DungeonCell, MovementSystem, TurnManager, LootSystem, WinCondition, loose key*

### Required Patterns

- **`PlayerState extends Node`** — in-scene Node, два независимых инстанса: `player_state_0`, `player_state_1` — источник: ADR-0003
- **`HeroClassData extends Resource`** — статическое определение класса, только чтение — источник: ADR-0003
- **`assert(character_class != null, ...)` в `PlayerState._ready()`** — предотвращает запуск без привязки класса — источник: ADR-0003
- **`TileMapLayer` вместо `TileMap`** — `TileMap` deprecated с Godot 4.3 — источник: ADR-0004
- **`DungeonCell` — plain GDScript класс без `extends`** — не Resource, не Node; только runtime-данные — источник: ADR-0004
- **Сетка тайлов: `Dictionary[Vector2i, DungeonCell]`** (sparse: только размещённые тайлы) — источник: ADR-0004
- **`MovementSystem` читает флаги класса напрямую из `player.character_class`** — dot-notation на boolean полях `HeroClassData`; никаких strategy-объектов — источник: ADR-0011
- **Константы MovementSystem**: `PORTAL_ENTER_COST = 1`, `PORTAL_TELEPORT_COST = 1`, `SWAP_COST = 4`, `SWORDWOMAN_BYPASS_STEP_COST = 2` — источник: ADR-0011
- **Проверка Swordwoman bypass: `steps_remaining >= 2` ДО bypass** — bypass стоит 2 шага; 1 шага недостаточно — источник: ADR-0011
- **`CombatSystem` вызывает `TurnManager.add_step(1)` ДО `emit combat_resolved`** для победы Swordsman с 6 — источник: ADR-0012
- **Сигнал `combat_resolved` имеет подпись `(won: bool, six_rolled: bool)`** — все слушатели обязаны включать второй параметр — источник: ADR-0012
- **Для не-Swordsman всегда эмитировать `combat_resolved(won, false)`** — источник: ADR-0012
- **`TurnManager.add_step(n: int)`**: проверка `n <= 0 → push_error`; не изменяет `steps_taken` — источник: ADR-0012
- **Автозамена оружия: заменять слабейшее по `attack_bonus`** — tie-break = index 0 (старший слот) — источник: ADR-0013
- **Замена свитков: FIFO** — заменять `scrolls[0]` (самый старый) — источник: ADR-0013
- **`PlayerState` должен иметь `get_weapons() -> Array[ItemData]` и `get_scrolls() -> Array[ItemData]`** — требуется LootSystem — источник: ADR-0013
- **`is_empty()` guard перед обращением к `weapons[0]`** — `push_error` при пустом массиве — источник: ADR-0013
- **`item_acquired` эмитируется на ВСЕХ путях LootSystem** — включая путь `place_loose_key`; TurnManager должен всегда выходить из `AWAITING_LOOT` — источник: ADR-0013, ADR-0015
- **Распределённое накопление VP**: LootSystem → `add_vp(1.0)` за сундук; CombatSystem → `add_vp(vp_on_kill)` за Ghost; WinCondition → `add_vp(1.5)` за Dragon — источник: ADR-0014
- **`VP_DRAGON_KILL = 1.5`** — дробное значение обязательно; делает ничью математически невозможной — источник: ADR-0014
- **`DungeonCell.loose_key: bool = false`** — состояние ключа на полу, независимо от `is_cleared` — источник: ADR-0015
- **`TileSystem` предоставляет три метода**: `has_loose_key(pos)`, `place_loose_key(pos)` (идемпотентен), `remove_loose_key(pos)` — с guard на отсутствующую позицию — источник: ADR-0015
- **`clear_cell()` НЕ трогает `loose_key`** — это отдельный lifecycle — источник: ADR-0015
- **`LootSystem` подключается к `cell_entered` ПЕРВЫМ** в `_wire_signals()` — сигналы Godot синхронны; pickup должен завершиться до других обработчиков `cell_entered` — источник: ADR-0015

### Forbidden Approaches

- **Никогда не использовать устаревший нод `TileMap`** — источник: ADR-0004
- **Никогда не реализовывать `PlayerState extends Resource`** — нет `_ready()`, нет сигналов, риск разделения состояния — источник: ADR-0003
- **Никогда не создавать `PlayerState` через `PlayerState.new()`** — должен размещаться в дереве сцены — источник: ADR-0003
- **Никогда не делать `DungeonCell extends Resource` или `extends Node`** — plain class без base type — источник: ADR-0004
- **Никогда не хранить сетку как `Array[Array]`** — Dictionary идиоматичнее для sparse-данных — источник: ADR-0004
- **Никогда не вызывать `set_cell()` с индексом слоя первым аргументом** — устаревший паттерн `TileMap` — источник: ADR-0004
- **Никогда не использовать Strategy-паттерн для class abilities MovementSystem** — 4 boolean флага с прямыми условиями достаточны — источник: ADR-0011
- **Никогда не эмитировать `combat_resolved` до `add_step(1)` для Swordsman** — FSM читает `steps_remaining` во время перехода; порядок нарушение = тихий баг — источник: ADR-0012
- **Никогда не накапливать VP в `WinCondition`** — сделает её stateful (нарушение ADR-0008) — источник: ADR-0014
- **Никогда не создавать EventBus для VP** — прямые вызовы `add_vp()` проще — источник: ADR-0014
- **Никогда не менять `VP_DRAGON_KILL` на целое число без обновления ADR** — источник: ADR-0014
- **Никогда не хранить позиции ключей в `LootSystem`** — LootSystem должен оставаться stateless; TileSystem — единственный владелец состояния тайлов — источник: ADR-0015
- **Никогда не использовать Node2D-entity для loose key** — визуальный рендеринг ключа на полу — задача TileRevealVFX — источник: ADR-0015

### Performance Guardrails

- **MovementSystem**: O(1) на ход — 4 boolean flag read, без аллокаций — источник: ADR-0011
- **`DungeonCell.loose_key`**: +1 byte на ячейку (≈80 bytes на всё подземелье) — источник: ADR-0015

---

## Feature Layer Rules

*Applies to: stateless Feature systems, CombatSystem, TurnManager FSM, signal payloads*

### Required Patterns

- **`CombatOptions extends Resource`; `CombatAction extends Resource`** — типизированные payload для сигналов боевой системы — источник: ADR-0006
- **Все signal payload типизированы** — Resource или примитивы; не plain `Dictionary` — источник: ADR-0006
- **Stateless-системы (`EncounterDispatcher`, `LootSystem`, `KnockoutSystem`, `WinCondition`) несут заголовок**: `## STATELESS. This system holds no persistent game state.` — источник: ADR-0008
- **В stateless-системах нет `var` полей** (исключение: `@export`, `@onready`) — источник: ADR-0008
- **`TurnManager` — единственная Feature-система с разрешённым persistent-состоянием** (FSM state + счётчики ходов) — источник: ADR-0008
- **`CombatSystem._on_combat_started()`: блок сброса — ПЕРВЫЙ оператор** — `_scroll_bonus = 0`, `_hp_bonus = 0` и т.д. до любой условной логики — источник: ADR-0008

### Forbidden Approaches

- **Никогда не использовать `Dictionary` как payload сигнала** — нет статической типизации, опечатки в ключах дают `null` без ошибки — источник: ADR-0006
- **Никогда не добавлять методы или side-эффекты в `CombatOptions`/`CombatAction`** — это чистые data-носители — источник: ADR-0006
- **Никогда не добавлять persistent `var` поля в stateless-системы** — источник: ADR-0008
- **Никогда не пропускать или откладывать блок сброса в `CombatSystem`** — бонусы прошлого боя перейдут в следующий — источник: ADR-0008

---

## Presentation Layer Rules

*Applies to: HUD, CombatUI, InventoryUI, TileRevealVFX*

### Required Patterns

- **`HUD` и `InventoryUI` — PURE READER** — реагируют на сигналы Core/Feature; никогда не эмитируют сигналы влияющие на игровое состояние — источник: ADR-0009
- **Заголовочный комментарий на `HUD`, `InventoryUI`, `TileRevealVFX`**: `## PURE READER — emits no signals; only reacts to Core and Feature signals.` — источник: ADR-0009
- **`CombatUI.player_action_taken` подключается в `GameScene._wire_signals()`** — не в `CombatUI._ready()` — источник: ADR-0009
- **Анимация UI: `Control.position` / `rotation` / `scale` анимируются напрямую через `Tween`** — Godot 4.7 поддерживает прямую манипуляцию Control transforms — источник: ADR-0009 + current-best-practices.md

### Forbidden Approaches

- **`HUD`, `InventoryUI`, `TileRevealVFX` не должны эмитировать сигналы, потребляемые Feature или Core** — единственный одобренный P→F сигнал: `CombatUI.player_action_taken` — источник: ADR-0009
- **Никогда не добавлять новый сигнал Presentation→Feature без обновления ADR-0009** — источник: ADR-0009

---

## Global Rules (All Layers)

### Naming Conventions

| Элемент | Соглашение | Пример |
|---------|-----------|---------|
| Классы | PascalCase | `PlayerController` |
| Переменные | snake_case | `move_speed` |
| Функции | snake_case | `take_damage()` |
| Сигналы | snake_case прошедшее время | `health_changed` |
| Файлы | snake_case совпадает с классом | `player_controller.gd` |
| Сцены | PascalCase совпадает с корневым нодом | `PlayerController.tscn` |
| Константы | UPPER_SNAKE_CASE | `MAX_HEALTH` |

### Performance Budgets

| Параметр | Значение |
|--------|-------|
| Целевой FPS | 60 |
| Бюджет кадра | 16.6 мс |
| Draw calls | ≤ 100 |
| Потребление памяти | ≤ 512 МБ |

### Approved Libraries / Addons

— Не настроено (добавить при появлении одобренных зависимостей через `/architecture-decision`)

### Forbidden APIs (Godot 4.7.2)

| Deprecated | Замена | С версии |
|-----------|--------|---------|
| `TileMap` нод | `TileMapLayer` | 4.3 |
| `set_scope(...)` на RPC | `set_method(...)` | 4.5 |
| `get_rpc_config()` | `get_node_rpc_config()` | 4.5 |
| `String` в `set_name()` | `StringName` (`&"name"`) | 4.5 |

Источник: `docs/engine-reference/godot/deprecated-apis.md`

### Cross-Cutting Constraints

- **Статическая типизация обязательна** — все переменные, параметры функций и return types в GDScript должны быть статически типизированы — источник: current-best-practices.md
- **StringName literals** (`&"name"`) везде, где ожидается `StringName` — избегает конверсии `String → StringName` в runtime — источник: current-best-practices.md
- **`@export` и `@onready` с явными типами**: `@export var speed: float`; `@onready var label: Label = $Label` — источник: current-best-practices.md
- **Gameplay-значения data-driven** — никаких hardcoded балансовых чисел в GDScript логике; определять как константы или загружать из ресурсов — источник: coding-standards.md
- **Все публичные методы юнит-тестируемы через dependency injection** — избегать синглтонов для тестируемой логики — источник: coding-standards.md
- **Детальные комментарии обязательны в каждом implementation-файле** — следовать стилю `src/gameplay/dungeon_generator.gd`: section headers, doc-comments на публичных методах, `# --- ШАГ N ---` блоки, ссылки на ADR на неочевидных строках — источник: coding-standards.md
