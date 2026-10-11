# Godot Breaking Changes — 4.3 → 4.7.2

Last verified: 2026-10-07

---

## 4.3 → 4.4

Source: https://docs.godotengine.org/en/4.4/tutorials/migrating/upgrading_to_godot_4.4.html

### Core

| Change | Old Behavior | New Behavior | GDScript compat |
|--------|-------------|--------------|-----------------|
| `@export_file` paths | Stored as `res://` path | Stored as `uid://` reference | Compatible (auto-migrated) |
| `store_8/16/32/64/buffer/double/float/half/line/real/string/var` | Returns `void` | Returns `bool` (success indicator) | Compatible (return value is new) |

### Rendering

- No major GDScript-affecting rendering changes.

---

## 4.4 → 4.5

Source: https://docs.godotengine.org/en/4.5/tutorials/migrating/upgrading_to_godot_4.5.html

### Core / Networking

| Change | Old API | New API | Notes |
|--------|---------|---------|-------|
| RPC scope setter | `set_scope(...)` | `set_method(...)` | Method renamed |
| RPC config getter | `get_rpc_config()` | `get_node_rpc_config()` | Method renamed |
| Node name type | `set_name(String)` | `set_name(StringName)` | StringName migration — `&"name"` syntax preferred |

---

## 4.5 → 4.6

Source: https://docs.godotengine.org/en/4.6/tutorials/migrating/upgrading_to_godot_4.6.html

### Core

| Change | Old Behavior | New Behavior | Notes |
|--------|-------------|--------------|-------|
| `Quaternion` default init | Could initialize to `(0,0,0,0)` (invalid) | Always initializes to identity `(0,0,0,1)` | **Breaking**: code relying on zero-init will behave differently |

### Physics

| Change | Old Default | New Default | Notes |
|--------|-------------|-------------|-------|
| 3D physics engine | GodotPhysics | **Jolt** | New projects default to Jolt. 2D physics unchanged. |

### Rendering

| Change | Old Behavior | New Behavior | Notes |
|--------|-------------|--------------|-------|
| Glow post-processing | Applied after tone-mapping | Applied **before** tone-mapping, uses screen blend | Glow appearance may change in existing projects |
| Windows default renderer | Vulkan | **Direct3D 12** | PC/Windows new default |

---

## 4.6 → 4.7

Source: https://docs.godotengine.org/en/stable/tutorials/migrating/upgrading_to_godot_4.7.html

### Animation

| Change | Notes |
|--------|-------|
| `AnimationTree` BlendSpace internals | Projects using custom BlendSpace internals may need to retest blend behavior |

### GDExtension

| Change | Old | New | Notes |
|--------|-----|-----|-------|
| `Object::ConnectFlags` binding | Enum | **Bitfield** | Affects GDExtension code only — not GDScript |

### UI (New Features, Not Breaking)

- `Control` nodes now support `position`, `rotation`, `scale` transforms without breaking container layout
- `VirtualJoystick` system added (mobile touch controls)

### Rendering (New, Not Breaking)

- HDR output support added
- `AreaLight3D` node added (rectangular light sources)
- `DrawableTexture` added (runtime texture painting)

---

## Summary: What Matters for This Project (Karak Digital)

This is a **2D board game** using GDScript. Most breaking changes above affect 3D or GDExtension:

| Change | Impact on Karak |
|--------|----------------|
| `@export_file` uid migration | Low — auto-migrated by editor |
| `store_*` returns bool | None — not used in 2D board games |
| RPC renames | None — no networking |
| `Quaternion` init fix | None — no 3D |
| Jolt default physics | None — using 2D physics |
| Glow before tone-mapping | Low — 2D, minimal post-processing |
| BlendSpace changes | None — minimal animation |
| `Control` transforms | Potential benefit — UI layout improvements |
