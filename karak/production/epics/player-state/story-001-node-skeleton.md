# Story 001: PlayerState Node Skeleton — поля, сигналы, player_id guard

> **Epic**: PlayerState
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-10-12

## Context

**GDD**: `design/gdd/player-state.md`
**Requirement**: `TR-player-state-001`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003: PlayerState as Node
**ADR Decision Summary**: PlayerState extends Node (не Resource) — размещается в SceneTree как in-scene нод, два независимых инстанса по одному на каждого игрока. `character_class: HeroClassData` назначается в Inspector через @export.

**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: Node и Resource base classes стабильны с Godot 4.0. @export для HeroClassData работает корректно.

**Control Manifest Rules (Core layer)**:
- Required: PlayerState extends Node — НЕ Autoload (ADR-0001)
- Required: Все сигналы типизированы: `signal hp_changed(new_hp: int, max_hp: int)` (ADR-0002)
- Forbidden: PlayerState никогда не регистрируется как Autoload (ADR-0001)
- Forbidden: PlayerState не подключает сигналы других систем в `_ready()` — только GameScene._wire_signals() (ADR-0002)

---

## Acceptance Criteria

*From GDD `design/gdd/player-state.md`, scoped to this story:*

- [ ] AC-01: После создания PlayerState с валидным player_id: `weapons==[]`, `key==null`, `scrolls==[]`, `attack_bonus==0`
- [ ] AC-27: PlayerState с `player_id=0` или `player_id=6` → assert при инициализации, объект не создаётся
- [ ] AC-28: Поле `effective_attack` отсутствует в публичном API PlayerState

---

## Implementation Notes

*Derived from ADR-0003 Implementation Guidelines:*

Создать `src/foundation/player_state.gd`:

```gdscript
class_name PlayerState
extends Node

# Все сигналы — типизированы (ADR-0002)
signal hp_changed(new_hp: int, max_hp: int)
signal vp_changed(new_vp: float)
signal item_added(item: ItemData, slot_type: String)
signal item_removed(item: ItemData, slot_type: String)
signal knocked_out()
signal knockout_cleared()
signal won()  # AC-14 требует сигнал won

# @export — назначается в Inspector
@export var character_class: HeroClassData
@export var player_id: int = 1  # 1–5, валидируется в _ready()

var hp: int
var max_hp: int
var vp: float = 0.0
var position: Vector2i
var previous_position: Vector2i
var weapons: Array[ItemData] = []
var key: ItemData  # nullable
var scrolls: Array[ItemData] = []
var chests_opened: int = 0
var attack_bonus: int = 0
var skip_next_turn: bool = false
var has_killed_dragon: bool = false

var has_key: bool:
    get: return key != null

func _ready() -> void:
    assert(player_id >= 1 and player_id <= 5,
        "PlayerState: player_id must be 1–5, got %d" % player_id)
    assert(character_class != null,
        "PlayerState: character_class must be assigned in Inspector")
    max_hp = character_class.max_hp
    hp = max_hp
```

**Важно**: `effective_attack` — НЕ поле PlayerState. Вычисляется CombatSystem в момент боя.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: take_damage(), heal_full(), knockout logic
- Story 003: set_position(), retreat()
- Story 004: add_weapon(), replace_weapon(), attack_bonus cache
- Story 005: set_key(), add_scroll() и связанные методы
- Story 006: add_vp(), mark_dragon_killed()

---

## QA Test Cases

*Written at story creation. Developer implements against these.*

- **AC-01**: Инициализация инвентаря
  - Given: PlayerState создан с валидным player_id=1 и HeroClassData с max_hp=5
  - When: читаются поля инвентаря
  - Then: `weapons.size()==0`, `key==null`, `scrolls.size()==0`, `attack_bonus==0`
  - Edge cases: player_id=1 (минимум), player_id=5 (максимум)

- **AC-27**: player_id вне диапазона — assert
  - Given: попытка создать PlayerState
  - When: player_id=0
  - Then: assert выброшен, объект не создаётся
  - Edge cases: player_id=0, player_id=6, player_id=-1

- **AC-28**: effective_attack не существует
  - Given: PlayerState создан
  - When: инспектируются публичные поля и методы
  - Then: поле `effective_attack` отсутствует в объекте
  - Edge cases: N/A

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/player_state/player_state_skeleton_test.gd` — должен существовать и проходить

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: ClassRegistry epic (DONE) — HeroClassData Resource должен существовать
- Unlocks: Story 002, 003, 004, 005, 006 (все зависят от skeleton)

---

## Completion Notes
**Completed**: 2026-10-17
**Criteria**: 3/3 passing (AC-27 негативные edge cases — manual verification required)
**Deviations**:
- ADVISORY: `position`/`previous_position` → `board_position`/`previous_board_position` (code review recommendation — избегает конфликта с Node2D.position)
- ADVISORY (scope): создан `src/foundation/item_data.gd` — не указан в scope, но необходим для компиляции `Array[ItemData]` в PlayerState
**Test Evidence**: `tests/unit/player_state/player_state_skeleton_test.gd` — 5 test functions (AC-01 ×2, AC-27 ×2, AC-28 ×1)
**Code Review**: Complete — APPROVED WITH SUGGESTIONS (все suggestions применены)
