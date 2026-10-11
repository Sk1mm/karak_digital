# Godot Current Best Practices — 4.4 to 4.7.2

Last verified: 2026-10-07

Practices that changed or were introduced after Godot 4.3 (LLM knowledge cutoff).

---

## TileMap → TileMapLayer (Since 4.3, Confirmed in 4.7)

`TileMap` is deprecated. Use `TileMapLayer` nodes instead.
- One `TileMapLayer` per logical layer (ground, walls, objects, etc.)
- Each layer is its own node — cleaner scene tree
- API is similar but per-layer instead of indexed

```gdscript
# OLD (deprecated)
$TileMap.set_cell(0, Vector2i(x, y), source_id, atlas_coords)

# NEW
$GroundLayer.set_cell(Vector2i(x, y), source_id, atlas_coords)
```

---

## StringName Literals (Since 4.3, Best Practice in 4.5+)

Use `&"name"` for StringName literals — avoids String→StringName conversion at runtime:

```gdscript
# Prefer
$Node.set_name(&"Player")
signal_name = &"health_changed"

# OK but slightly less efficient
$Node.set_name("Player")
```

---

## Static Typing (Godot 4.x Best Practice)

Always use static types in GDScript for performance and error detection:

```gdscript
# Good
var health: int = 100
func take_damage(amount: int) -> void:
    health -= amount

# Avoid
var health = 100
func take_damage(amount):
    health -= amount
```

---

## @export and @onready (Stable, Confirmed 4.7)

```gdscript
# @onready — safe pattern
@onready var sprite: Sprite2D = $Sprite2D
@onready var label: Label = %HealthLabel  # unique name selector

# @export — use typed exports
@export var move_speed: float = 200.0
@export var monster_data: MonsterResource
```

---

## Signal Architecture (Godot 4.x)

```gdscript
# Define with types
signal health_changed(new_health: int, max_health: int)

# Connect — prefer Callable syntax
health_changed.connect(_on_health_changed)

# Emit
health_changed.emit(current_health, max_health)
```

---

## Control Node Transforms (New in 4.7)

Since 4.7, `Control` nodes support `position`, `rotation`, `scale` without breaking container behavior.
This enables UI animations (shake, bounce) without workarounds:

```gdscript
# Animate UI element position directly (4.7+)
var tween = create_tween()
tween.tween_property($DamageLabel, "position", Vector2(0, -50), 0.5)
```

---

## Physics: 2D vs 3D Note

- **2D physics**: Unchanged — GodotPhysics 2D is still default and recommended for 2D games
- **3D physics**: Jolt is now default for new projects (4.6+) — irrelevant for Karak Digital
