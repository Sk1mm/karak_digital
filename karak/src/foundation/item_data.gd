class_name ItemData  # READ-ONLY resource schema for a game item (stub — full definition in ItemDatabase epic)
extends Resource  # Pure data container — no Node, no mutable logic

# ===================================================
# ITEM DATA — Foundation Layer (Stub)
# ===================================================
# Минимальный stub, позволяющий полям PlayerState быть статически типизированными.
# Полная реализация (item_type, icon, sell_value и т.д.) — в ItemDatabase epic.
#
# Этот файл существует ТОЛЬКО для того, чтобы:
#   1. Array[ItemData] в PlayerState был типизированным (не Array)
#   2. Сигналы PlayerState принимали ItemData как типизированный параметр
#
# Consumers (текущие):
#   PlayerState — weapons: Array[ItemData], key: ItemData, scrolls: Array[ItemData]
#   (будущие) LootSystem, CombatSystem — полная реализация в ItemDatabase epic
#
# ADR Reference: ADR-0003 (PlayerState as Node — содержит ссылки на ItemData)
# TR Reference: TR-item-001 ("6 items as read-only ItemData with typed properties")
# ===================================================


# ===================================================
# СЕКЦИЯ: @export поля (базовая идентификация)
# ===================================================

@export var id: StringName  # Глобальный ID предмета — &"sword_basic", &"key", &"scroll_teleport" и т.д.

@export var attack_bonus: int = 0  # Бонус к атаке при использовании (только WEAPON items) — читает CombatSystem
