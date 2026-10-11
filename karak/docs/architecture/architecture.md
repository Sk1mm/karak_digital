# Karak Digital — Master Architecture

## Document Status
- Version: 1
- Last Updated: 2026-10-10
- Engine: Godot 4.7.2 (GDScript)
- GDDs Covered: 18 MVP systems (design/gdd/)
- ADRs Referenced: [to be created — see Required ADRs section]
- Review Mode: lean
- Technical Director Sign-Off: 2026-10-10 — APPROVED (lean mode; Godot Specialist + GDScript Specialist consulted on Phases 3–4)
- Lead Programmer Feasibility: skipped (lean mode)

---

## Engine Knowledge Gap Summary

Engine: Godot 4.7.2. LLM training data covers ~4.3.

**No HIGH RISK domains** — all post-4.3 breaking changes affect 3D, GDExtension, or networking (none used by Karak Digital).

**One MEDIUM RISK domain:**
- `TileMapLayer` (since 4.3): `TileMap` is deprecated. All dungeon rendering must use `TileMapLayer` nodes. Verified in `docs/engine-reference/godot/current-best-practices.md`.

All other 2D APIs used by this project (`CanvasLayer`, `Control`, `Signal`, `@export`, `Tween`, `Area2D`) are stable across 4.3–4.7.2.

---

## System Layer Map

```
┌─────────────────────────────────────────────────────────────────┐
│  PRESENTATION LAYER                                             │
│  HUD · CombatUI · InventoryUI · TileRevealVFX                  │
├─────────────────────────────────────────────────────────────────┤
│  FEATURE LAYER  (Core Loop)                                     │
│  DungeonGenerator · TurnManager · MovementSystem               │
│  EncounterDispatcher · CombatSystem · LootSystem               │
│  KnockoutSystem · WinCondition                                  │
├─────────────────────────────────────────────────────────────────┤
│  CORE LAYER  (Game State + Data)                                │
│  PlayerState [×N] · TileSystem · DiceSystem                    │
├─────────────────────────────────────────────────────────────────┤
│  FOUNDATION LAYER  (Autoloads — Global Data)                   │
│  ClassRegistry · ItemDatabase · MonsterDatabase                │
├─────────────────────────────────────────────────────────────────┤
│  PLATFORM LAYER                                                 │
│  Godot 4.7.2 Engine                                            │
└─────────────────────────────────────────────────────────────────┘
```

### Layer Assignments

| System | Layer | Node Type | Autoload? | Instanced? |
|--------|-------|-----------|-----------|------------|
| **ClassRegistry** | Foundation | Node | ✓ Autoload | — |
| **ItemDatabase** | Foundation | Node | ✓ Autoload | — |
| **MonsterDatabase** | Foundation | Node | ✓ Autoload | — |
| **PlayerState** | Core | Resource / Node | ✗ | ✓ ×N (one per player) |
| **TileSystem** | Core | Node2D / TileMapLayer | ✗ | ✓ per session |
| **DiceSystem** | Core | Node | ✗ | ✓ per session |
| **DungeonGenerator** | Feature | Node | ✗ | ✓ one-shot per session |
| **TurnManager** | Feature | Node | ✗ | ✓ per session |
| **MovementSystem** | Feature | Node | ✗ | ✓ per session |
| **EncounterDispatcher** | Feature | Node | ✗ | ✓ per session |
| **CombatSystem** | Feature | Node | ✗ | ✓ per session |
| **LootSystem** | Feature | Node | ✗ | ✓ per session |
| **KnockoutSystem** | Feature | Node | ✗ | ✓ per session |
| **WinCondition** | Feature | Node | ✗ | ✓ per session |
| **HUD** | Presentation | CanvasLayer (layer=10) | ✗ | ✓ per session |
| **CombatUI** | Presentation | CanvasLayer (layer=11) | ✗ | ✓ per session |
| **InventoryUI** | Presentation | CanvasLayer (layer≤10) | ✗ | ✓ per session |
| **TileRevealVFX** | Presentation | Node2D | ✗ | ✓ per session |

### Layer Rules

1. **Foundation** → Autoload singletons; read-only data, no mutable game state. Accessible from any layer.
2. **Core** → Mutable game state. `PlayerState` and `TileSystem` are the single source of truth for hero and dungeon state. Never accessed by Presentation directly (only via signals).
3. **Feature** → Stateless or ephemeral state. Implement the core loop by coordinating Core layer objects. Emit signals; do not call Presentation layer.
4. **Presentation** → Reads Core state only via signals and `@export` references. Never modifies game state. Never calls Feature layer methods directly (only emits UI signals consumed by Feature).
5. **Strict downward dependency**: each layer may only depend on layers below it. No upward calls. Cross-layer communication only via signals.

---

## Module Ownership

### Foundation Layer (Autoloads)

| Модуль | Owns | Exposes | Consumes | Engine API |
|--------|------|---------|----------|------------|
| **ClassRegistry** | `HeroClass` ресурсы (7 типов); константы классов | `get_class(id) → HeroClass`; `get_all() → Array[HeroClass]`; `pick_random(n) → Array[HeroClass]` | — | `Resource`, `RandomNumberGenerator` |
| **ItemDatabase** | `ItemData` ресурсы (6 типов) | `get_item(id: StringName) → ItemData` | — | `Resource` |
| **MonsterDatabase** | `MonsterData` ресурсы (8 типов) | `get_monster(id: StringName) → MonsterData` | — | `Resource` |

### Core Layer

| Модуль | Owns | Exposes | Consumes | Engine API |
|--------|------|---------|----------|------------|
| **PlayerState** | `hp`, `position`, `previous_position`, `weapons[]`, `key`, `scrolls[]`, `vp: float`, `skip_next_turn`, `character_class`; cache `attack_bonus` | Методы мутации + читаемые свойства; сигналы: `hp_changed`, `vp_changed`, `item_added`, `item_removed`, `knocked_out`, `knockout_cleared` | ClassRegistry (только при инициализации) | typed signals |
| **TileSystem** | `DungeonCell` grid (`Dictionary[Vector2i, DungeonCell]`); tile pool; event token pool | `get_cell()`, `get_exits()`, `is_revealed()`, `is_cleared()`, `draw_tile()`, `place_cell()`, `reveal_cell()`, `clear_cell()`, `draw_event_token()`, `place_loose_key()`, `remove_loose_key()`, `has_loose_key()`; сигнал: `cell_revealed` | — | `TileMapLayer` ⚠️ не `TileMap`; `Vector2i` |
| **DiceSystem** | `dice_state: Array[int]`; `RNG` с seed | `roll(n, sides)`, `reroll_die(index, sides)`, `get_dice_state()`, `set_seed(seed)` | — | `RandomNumberGenerator` |

### Feature Layer

| Модуль | Owns | Emits | Consumes |
|--------|------|-------|----------|
| **DungeonGenerator** | — (одноразовый) | `dungeon_initialized` | TileSystem.init_pools(); PlayerState.set_position() |
| **TurnManager** | `active_player_index`, `steps_remaining`, `steps_taken`, `turn_number`; FSM state | `turn_started`, `turn_ended`, `turn_changed`, `step_spent`, `turn_skipped` | `game_over`, `dungeon_initialized`, `knocked_out`, `combat_resolved`, `item_acquired` |
| **MovementSystem** | — (stateless) | `cell_entered`, `cell_highlighted`, `step_taken` | TileSystem; TurnManager; PlayerState; ClassRegistry |
| **EncounterDispatcher** | — (stateless) | `combat_started`, `loot_started` | `tile_reveal_complete`; TileSystem; PlayerState; ClassRegistry |
| **CombatSystem** | Бой-локальный: `scroll_bonus`, `hp_bonus`, `first_step_bonus` (сбрасываются после боя) | `combat_resolved`, `item_dropped`, `dragon_killed`, `dice_rolled`, `auto_reroll_triggered`, `player_choice_requested` | `combat_started`; DiceSystem; PlayerState; ClassRegistry; ItemDatabase; MonsterDatabase |
| **LootSystem** | — (stateless) | `item_acquired` | `loot_started`, `item_dropped`, `cell_entered`; PlayerState; ItemDatabase; TileSystem |
| **KnockoutSystem** | — (stateless) | — | `knocked_out`; PlayerState; ClassRegistry |
| **WinCondition** | — (stateless) | `game_over(winner: PlayerState)` | `dragon_killed`; PlayerState |

### Presentation Layer

| Модуль | Owns | Emits | Consumes |
|--------|------|-------|----------|
| **HUD** | Визуальное состояние панелей игроков; экран результата | — | `hp_changed`, `vp_changed`, `item_added`, `item_removed`, `knocked_out`, `knockout_cleared`, `turn_started`, `step_spent`, `turn_ended`, `turn_skipped`, `game_over` |
| **CombatUI** | Локальный UI-контекст боя (кнопки, breakdown-строка) | `player_action_taken(action, payload)` *(см. примечание)* | `combat_started`, `dice_rolled`, `auto_reroll_triggered`, `player_choice_requested`, `combat_resolved` |
| **InventoryUI** | — (read-only reflector) | — | `item_added`, `item_removed`, `turn_changed`, `combat_started` |
| **TileRevealVFX** | — (animation-only) | `tile_reveal_complete(player, pos)` | `cell_entered` |

> **Примечание — CombatUI ↔ CombatSystem (допустимое исключение):**
> CombatUI эмитирует `player_action_taken` → CombatSystem слушает. Это единственная
> Presentation→Feature связь через сигнал (не прямой вызов). Допустимо как MVC-петля:
> CombatSystem = Controller, CombatUI = View. Все остальные Presentation-модули строго
> read-only и не влияют на game state.

### Dependency Diagram

```
[Platform: Godot 4.7.2]
         ↑
[Foundation: ClassRegistry · ItemDatabase · MonsterDatabase]  ← Autoloads
         ↑
[Core: PlayerState · TileSystem · DiceSystem]
         ↑
[Feature: DungeonGenerator → TurnManager ↔ MovementSystem ↔ EncounterDispatcher
          ↕                    ↕
          CombatSystem ← LootSystem · KnockoutSystem · WinCondition]
         ↑
[Presentation: HUD · CombatUI ⇄ CombatSystem · InventoryUI · TileRevealVFX]
                              (единственная обратная связь — сигнал)
```

---

## Data Flow

### DF-1: Порядок инициализации (Boot Order)

```
Старт приложения
  │
  ▼
1. Godot регистрирует Autoloads (Project Settings → Autoload):
   ClassRegistry → ItemDatabase → MonsterDatabase
   (все три готовы до загрузки любой сцены)
  │
  ▼
2. GameScene загружается; все child nodes проходят _ready() снизу вверх:
   TileSystem._ready()
   DiceSystem._ready()
   PlayerState[0]._ready() · PlayerState[1]._ready()
   DungeonGenerator._ready()  ← НЕ вызывает init() здесь
   TurnManager._ready()
   MovementSystem._ready()
   EncounterDispatcher._ready()
   CombatSystem._ready()
   LootSystem._ready()
   KnockoutSystem._ready()
   WinCondition._ready()
   [Presentation nodes._ready()]
  │
  ▼
3. GameScene._ready() — всё готово; явная оркестрация:
   a. _wire_signals()  ← подключает ВСЕ cross-system сигналы в одном месте
   b. dungeon_generator.init()
        ├─ TileSystem.init_pools(tile_pool, event_pool)
        ├─ PlayerState[i].set_position(Vector2i(0,0))  для каждого игрока
        └─ emit dungeon_initialized
              ▼
           TurnManager._on_dungeon_initialized()
              └─ emit turn_started(player[0])
                    ▼
                   HUD [активирует панель P1]
```

> **Решение DS-1 (Godot Specialist)**: `init()` вызывается из `GameScene._ready()`, не из `DungeonGenerator._ready()`. Порядок инициализации читается в одном месте и не зависит от позиции нод в Scene Tree.

---

### DF-2: Signal Wiring Architecture

Все cross-system соединения подключаются централизованно:

```gdscript
# GameScene._ready():
func _wire_signals() -> void:
    # Foundation → ничего не эмитируют

    # Core → Feature
    player_state_0.knocked_out.connect(knockout_system._on_knocked_out)
    player_state_1.knocked_out.connect(knockout_system._on_knocked_out)
    tile_system.cell_revealed.connect(...)  # если нужно

    # Feature → Feature
    dungeon_generator.dungeon_initialized.connect(turn_manager._on_dungeon_initialized)
    combat_system.combat_resolved.connect(turn_manager._on_combat_resolved)
    combat_system.item_dropped.connect(loot_system._on_item_dropped)
    combat_system.dragon_killed.connect(win_condition._on_dragon_killed)
    loot_system.item_acquired.connect(turn_manager._on_item_acquired)
    loot_system.cell_entered.connect(loot_system._on_cell_entered)  # self
    movement_system.cell_entered.connect(tile_reveal_vfx._on_cell_entered)
    tile_reveal_vfx.tile_reveal_complete.connect(encounter_dispatcher._on_tile_reveal_complete)
    win_condition.game_over.connect(turn_manager._on_game_over)

    # Feature → Presentation
    win_condition.game_over.connect(hud._on_game_over)
    combat_system.dice_rolled.connect(combat_ui._on_dice_rolled)
    combat_system.auto_reroll_triggered.connect(combat_ui._on_auto_reroll_triggered)
    combat_system.player_choice_requested.connect(combat_ui._on_player_choice_requested)
    combat_system.combat_resolved.connect(combat_ui._on_combat_resolved)

    # Core → Presentation
    player_state_0.hp_changed.connect(hud._on_hp_changed.bind(0))
    player_state_0.vp_changed.connect(hud._on_vp_changed.bind(0))
    player_state_0.item_added.connect(hud._on_item_added.bind(0))
    player_state_0.item_removed.connect(hud._on_item_removed.bind(0))
    player_state_0.knocked_out.connect(hud._on_knocked_out.bind(0))
    player_state_0.knockout_cleared.connect(hud._on_knockout_cleared.bind(0))
    # (аналогично для player_state_1)
    turn_manager.turn_started.connect(hud._on_turn_started)
    turn_manager.step_spent.connect(hud._on_step_spent)
    turn_manager.turn_ended.connect(hud._on_turn_ended)
    turn_manager.turn_skipped.connect(hud._on_turn_skipped)
    player_state_0.item_added.connect(inventory_ui._on_item_added.bind(0))
    # ...
    turn_manager.turn_changed.connect(inventory_ui._on_turn_changed)

    # Presentation → Feature (единственное исключение)
    combat_ui.player_action_taken.connect(combat_system._on_player_action_taken)
```

> **Решение DS-2 (Godot Specialist)**: Весь граф зависимостей виден в `_wire_signals()`. Системы не подключают чужие сигналы в своих `_ready()`.

---

### DF-3: Основной игровой поток (один ход)

```
[Игрок кликает на тайл]
         │
         ▼
MovementSystem
  ├─ TileSystem.place_cell() / PlayerState.set_position()
  ├─ TurnManager.spend_step()
  └─ emit cell_entered(player, pos)
         │
         ▼
TileRevealVFX  [анимация flip 0.4s; Tween]
  ├─ TileSystem.reveal_cell(pos)
  └─ emit tile_reveal_complete(player, pos)
         │
         ▼
EncounterDispatcher  [маршрутизация по cell.category + event_type]
  │
  ├─MONSTER──► emit combat_started(player, monster_data)
  │                     │
  │                     ▼
  │             CombatSystem
  │               ├─ DiceSystem.roll(2,6) → emit dice_rolled → CombatUI [анимация]
  │               ├─ emit player_choice_requested → CombatUI [кнопки]
  │               ├─ ◄── player_action_taken ── CombatUI [решение игрока]
  │               ├─ emit combat_resolved(won, six_rolled) → TurnManager
  │               ├─ emit item_dropped(player, monster_id) → LootSystem
  │               │     └─► PlayerState.add_item() → emit item_acquired → TurnManager
  │               └─ [if dragon] emit dragon_killed → WinCondition
  │                                   └─► add_vp(1.5) + emit game_over(winner)
  │                                         ├─► TurnManager [→ GAME_OVER]
  │                                         └─► HUD [экран результата]
  │
  ├─CHEST+KEY─► emit loot_started(player, pos)
  │                     │
  │                     ▼
  │             LootSystem
  │               ├─ PlayerState.add_vp(1.0) + TileSystem.clear_cell()
  │               └─ emit item_acquired(player, null) → TurnManager [конец хода]
  │
  ├─FOUNTAIN──► [UI выбор] → PlayerState.heal_full() + TurnManager.burn_steps()
  │
  └─PORTAL────► [UI выбор] → PlayerState.set_position() + TurnManager.spend_step()
```

---

### DF-4: Knockout каскад

```
CombatSystem: PlayerState.take_damage(1) → hp = 0
  │
  ▼
PlayerState: emit knocked_out(player)
  ├─► KnockoutSystem
  │     ├─[Warrior: knockout_teleport_to_start] set_position(start) + heal_full()
  │     └─[Другие] no-op
  └─► HUD: панель → KNOCKED_OUT state

При следующей смене хода:
TurnManager._on_turn_change()
  ├─[Warrior: knockout_no_turn_skip] clear_knockout() → ход не пропускается
  └─[Другие] clear_knockout() + emit turn_skipped → следующий игрок
                                        │
                                        ▼
                                       HUD [иконка пропуска 0.5с]
```

---

### Типы передачи данных

| Тип | Когда используется | Пример |
|-----|-------------------|--------|
| **Signal (async)** | Уведомление о событии; несколько получателей | `hp_changed`, `combat_resolved` |
| **Direct method call** | Один вызывающий, один получатель; нужен возврат | `TileSystem.get_cell()`, `DiceSystem.roll()` |
| **@export ref** | Постоянные зависимости; инициализируются в Inspector | TurnManager → @export PlayerState[] |
| **Autoload access** | Глобальные read-only данные | `ItemDatabase.get_item(&"axe")` |

---

## API Boundaries

> Все типы — GDScript 4.7.2. Enum-значения передаются как `int` (GDScript не поддерживает
> `Array[EnumType]` — только `Array[int]`). Направления и типы предметов документируются
> через `GameEnums` (`class_name GameEnums` — не Autoload, не инстанцируется).

### GameEnums (глобальные enum-ы)

```gdscript
class_name GameEnums

enum Direction      { NORTH, EAST, SOUTH, WEST }
enum ItemType       { WEAPON, KEY, SCROLL }
enum ScrollType     { NONE, MAGIC_ATTACK, TELEPORT }
enum CombatOutcome  { WIN, DRAW, LOSS }
```

---

### Foundation Autoloads

```gdscript
## ClassRegistry (Autoload "ClassRegistry")
## Pure read-only. Never mutated after _ready().
func get_class(id: StringName) -> HeroClassData   ## null если не найден
func get_all() -> Array[HeroClassData]
func pick_random(n: int, rng: RandomNumberGenerator) -> Array[HeroClassData]
    ## Pre: 1 ≤ n ≤ 7; Post: Array[n], без повторов

## ItemDatabase (Autoload "ItemDatabase")
func get_item(id: StringName) -> ItemData         ## null если не найден

## MonsterDatabase (Autoload "MonsterDatabase")
func get_monster(id: StringName) -> MonsterData   ## null если не найден
```

---

### Core Layer

```gdscript
## PlayerState (Node; ×N экземпляров — один на игрока)
signal hp_changed(new_hp: int)
signal vp_changed(new_vp: float)                         ## float: Dragon = 1.5 VP
signal item_added(item: ItemData, slot_type: int)        ## slot_type — GameEnums.ItemType
signal item_removed(item: ItemData, slot_type: int)
signal knocked_out()
signal knockout_cleared()

func take_damage(amount: int) -> void
    ## Post: hp = max(0, hp - amount); если hp == 0 → emit knocked_out

func heal_full() -> void
    ## Post: hp = character_class.max_hp

func add_vp(amount: float) -> void
    ## Pre: amount > 0

func set_position(pos: Vector2i) -> void
    ## Post: previous_position = old position; position = pos

func retreat() -> void
    ## Post: position = previous_position (возврат на предыдущую клетку)
    ## Contract: previous_position задаётся set_position() при каждом перемещении

func get_attack_bonus() -> int
    ## Returns: сумма combat_bonus всех weapon слотов (0–6)

func add_item(item: ItemData) -> bool
    ## Returns: true если предмет добавлен; false если слот заполнен

func remove_item(item: ItemData) -> void
func is_knocked_out() -> bool
func clear_knockout() -> void
    ## Post: skip_next_turn = false; emit knockout_cleared


## TileSystem (Node)
signal cell_revealed(pos: Vector2i, cell: DungeonCell)

func get_cell(pos: Vector2i) -> DungeonCell
    ## assert(cell != null) — запрос несуществующей позиции — это баг, не edge case

func get_exits(pos: Vector2i) -> Array[int]
    ## Returns: Array of GameEnums.Direction values

func is_revealed(pos: Vector2i) -> bool
func is_cleared(pos: Vector2i) -> bool
func has_loose_key(pos: Vector2i) -> bool
func draw_tile() -> TileData
func draw_event_token() -> EventToken
func place_cell(pos: Vector2i, tile: TileData, rotation: int) -> void
func reveal_cell(pos: Vector2i) -> void
    ## Post: cell.is_revealed = true; emit cell_revealed
func clear_cell(pos: Vector2i) -> void
    ## Post: cell.is_cleared = true; монстр/сундук убраны с тайла
func init_pools(tiles: Array[TileData], tokens: Array[EventToken]) -> void
    ## Pre: вызывается ровно один раз (из GameScene._ready() через DungeonGenerator.init())
    ## assert вызова до первого draw_tile() / draw_event_token()


## DiceSystem (Node)
signal dice_rolled(results: Array[int])  ## emit после roll() и reroll_die()

func roll(dice_count: int, sides: int) -> Array[int]
    ## Post: внутренний dice_state обновлён; emit dice_rolled

func reroll_die(index: int, sides: int) -> void
    ## Post: dice_state[index] обновлён; emit dice_rolled

func get_dice_state() -> Array[int]
    ## Returns: текущий dice_state (readonly snapshot)

func set_seed(seed: int) -> void
func get_seed() -> int
    ## Для детерминированного воспроизведения (тесты, debug)
```

---

### Feature Layer (ключевые контракты)

```gdscript
## TurnManager (Node)
signal turn_started(player: PlayerState)
    ## Emit: начало хода; HUD активирует панель; InventoryUI перезакрывается
signal turn_ended(player: PlayerState)
    ## Emit: конец хода перед переключением игрока
signal step_spent(steps_remaining: int)
signal turn_skipped(player: PlayerState)

## NB: turn_changed убран — turn_started достаточен для всех слушателей.
## InventoryUI и HUD подписываются на turn_started.

func spend_step() -> void
    ## Pre: steps_remaining > 0; иначе push_error
func add_step(n: int) -> void
    ## Pre: n > 0; иначе push_error
func burn_steps() -> void
    ## Post: steps_remaining = 0 → триггер конца хода

func get_current_player() -> PlayerState
    ## Для начальной отрисовки HUD без ожидания сигнала
func get_steps_remaining() -> int
    ## Для начальной отрисовки HUD


## WinCondition (Node)
signal game_over(winner: PlayerState)
    ## Post: TurnManager → GAME_OVER; HUD → экран результата
    ## Блокировка мутаций PlayerState после game_over — ответственность TurnManager
    ## (GAME_OVER state игнорирует все game-flow сигналы; см. TurnManager EC-09)


## CombatUI (Presentation→Feature: единственная обратная связь)

## CombatAction (Resource — typed command object)
class_name CombatAction
extends Resource

enum Type { REROLL_BOTH, REROLL_ONE, USE_SCROLL, SPEND_HP, CONFIRM }

@export var type: CombatAction.Type
@export var die_index: int = -1          ## для REROLL_ONE: индекс кубика (0 или 1)
@export var item_id: StringName = &""    ## для USE_SCROLL: id свитка

## CombatUI signal
signal player_action_taken(action: CombatAction)
    ## CombatSystem слушает; единственная Presentation→Feature связь через сигнал
```

---

### Инварианты

1. `PlayerState.hp` ∈ [0, max_hp]. Никогда отрицательный, никогда > max_hp.
2. `TileSystem` — единственный мутатор `DungeonCell`. Никто другой не пишет в grid напрямую.
3. `PlayerState` — единственный мутатор инвентаря и HP игрока.
4. После `game_over` сигнала — TurnManager в GAME_OVER state игнорирует все game-flow сигналы, эффективно блокируя дальнейшие мутации PlayerState.
5. Autoloads (`ClassRegistry`, `ItemDatabase`, `MonsterDatabase`) — строго read-only после `_ready()`. Никакой мутации их данных во время партии.
6. `init_pools()` вызывается ровно один раз до любого `draw_tile()` / `draw_event_token()`.

---

## ADR Audit

Существующих ADR нет — `docs/architecture/` был пуст до начала этой сессии.
Все решения приняты в ходе `/create-architecture` и зафиксированы ниже.

---

## Required ADRs

### Foundation — создать до начала любого кода

| ADR | Решение | TR покрытие |
|-----|---------|-------------|
| **ADR-001: Autoload Strategy** | ClassRegistry, ItemDatabase, MonsterDatabase — Autoloads; PlayerState — Node ×N; без EventBus | TR-cs-010, TR-md-001 |
| **ADR-002: Signal Wiring Pattern** | Централизованный `_wire_signals()` в GameScene._ready(); системы не подключают чужие сигналы в своих `_ready()` | TR-ps-012..017 |
| **ADR-003: PlayerState as Node** | PlayerState extends Node (не Resource); HeroClassData extends Resource (pure data) | TR-ps-001..017 |
| **ADR-004: TileSystem and TileMapLayer** | TileSystem использует TileMapLayer (не TileMap) | TR-ts-001..014 |

### Core — создать до реализации соответствующей системы

| ADR | Решение | TR покрытие |
|-----|---------|-------------|
| **ADR-005: DungeonGenerator Init Pattern** | `init()` вызывается из `GameScene._ready()`, не из `DungeonGenerator._ready()` | TR-dg-001..008 |
| **ADR-006: CombatAction as Resource** | `player_action_taken` передаёт typed `CombatAction` Resource, не Dictionary | TR-cu-006 |
| **ADR-007: GameEnums Global Class** | Все shared enum-ы в `GameEnums` (class_name, не Autoload); enum в сигналах передаётся как `int` | TR-ts-005, TR-ts-002..004 |
| **ADR-008: Stateless Feature Systems** | EncounterDispatcher, LootSystem, KnockoutSystem — stateless; TurnManager — единственный оркестратор FSM | TR-ed-009, TR-ks-005 |

### Presentation — создать до реализации UI

| ADR | Решение | TR покрытие |
|-----|---------|-------------|
| **ADR-009: CanvasLayer Hierarchy** | CombatUI layer=11 > HUD layer=10 ≥ InventoryUI; единственная Presentation→Feature связь — `player_action_taken` сигнал | TR-cu-001, TR-cu-007 |

---

## Architecture Principles

Пять принципов, выведенных из game-concept.md, GDDs и технических ограничений:

1. **Сигналы — единственный способ межсистемной коммуникации вверх по слоям.**
   Feature-системы не вызывают методы Presentation-слоя напрямую. Единственное
   исключение — `CombatUI.player_action_taken` (Presentation→Feature через сигнал).

2. **PlayerState и TileSystem — единственные источники истины.**
   Любая другая система читает их состояние через публичный API, но не хранит копий.
   Если данные устарели — это баг в читающей системе.

3. **Feature-системы без состояния там, где это возможно.**
   EncounterDispatcher, LootSystem, KnockoutSystem, WinCondition — stateless.
   TurnManager — единственный явный FSM-оркестратор игрового цикла.

4. **Зависимости через @export, не через get_node() или пути.**
   Все ссылки между системами назначаются в Inspector. Нет хардкода путей нод.
   Нарушение этого правила делает сцену нетестируемой.

5. **Инициализация — явная и централизованная.**
   `GameScene._ready()` владеет порядком init() и _wire_signals(). Никакая
   child-нода не инициирует game-flow в своём собственном `_ready()`.

---

## Open Questions

Решения, отложенные до реализации соответствующей системы:

| # | Вопрос | Затрагивает | Решить до |
|---|--------|-------------|-----------|
| OQ-1 | Алгоритм генерации подземелья: простой рандом с flood-fill проверкой vs Wave Function Collapse | DungeonGenerator | реализации DungeonGenerator |
| OQ-2 | Сохранение партии (save/load): нужно ли в MVP? Если да — PlayerState потребует `to_save_data() -> Resource` | PlayerState | конца MVP sprint |
| OQ-3 | Визуальное представление тайлов: один TileMapLayer со всеми тайлами или отдельные слои (ground/monsters/items)? | TileSystem | реализации TileSystem |
| OQ-4 | Как EncounterDispatcher ожидает выбора игрока (FOUNTAIN/PORTAL: «войти или нет?»): await + Signal или явный UI-callback? | EncounterDispatcher, UI | реализации EncounterDispatcher |
| OQ-5 | Туториал: объяснение правил органически через первую партию или отдельный guided mode? | UX | Post-MVP |
