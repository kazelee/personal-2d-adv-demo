extends Node
class_name Stats

signal health_changed

@export var max_health: int = 3

# 节点ready后再初始化，避免了export值更改无法同步变更的问题
@onready var health: int = max_health:
	set(v):
		# 限制health的范围在0-max之间
		v = clampi(v, 0, max_health)
		if health == v:
			return
		health = v
		health_changed.emit()
