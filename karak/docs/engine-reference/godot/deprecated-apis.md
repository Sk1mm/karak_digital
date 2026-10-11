# Godot Deprecated APIs — 4.3 → 4.7.2

Last verified: 2026-10-07

Use this as a "don't use X, use Y instead" reference.

---

## GDScript / Core

| Deprecated | Replacement | Since | Notes |
|-----------|-------------|-------|-------|
| `set_scope(...)` on RPC | `set_method(...)` | 4.5 | RPC API rename |
| `get_rpc_config()` | `get_node_rpc_config()` | 4.5 | RPC API rename |
| `String` for `set_name()` | `StringName` (`&"name"`) | 4.5 | Prefer `&"name"` syntax |

## Physics

| Deprecated | Replacement | Since | Notes |
|-----------|-------------|-------|-------|
| GodotPhysics 3D (as default) | Jolt 3D | 4.6 | 2D physics unchanged — no impact for this project |

## Rendering

| Deprecated | Replacement | Since | Notes |
|-----------|-------------|-------|-------|
| Vulkan as Windows default | Direct3D 12 | 4.6 | Only affects renderer choice in Project Settings |

---

## Safe APIs (Confirmed Working in 4.7.2 for 2D)

These core 2D APIs remain stable across 4.3 → 4.7.2:

- `TileMapLayer` (replaced `TileMap` in 4.3 — already current)
- `Node2D`, `Sprite2D`, `AnimatedSprite2D`
- `Area2D`, `CollisionShape2D`, `PhysicsBody2D`
- `Control`, `Label`, `Button`, `Panel`, `MarginContainer`, `HBoxContainer`, `VBoxContainer`
- `CanvasLayer`
- `Signal` / `connect()` / `emit()` syntax
- `@export`, `@onready`
- `get_tree()`, `get_node()`, `$NodePath`
- `ResourceLoader`, `preload()`, `load()`
