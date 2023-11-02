class_name StateMachine
extends Node

# 避免枚举默认为0，导致“从0变到0”
var current_state: int = -1:
	# 使用父节点的函数为变量赋值
	set(v):
		owner.transition_state(current_state, v)
		current_state = v
		state_time = 0

# 在状态机中实现Timer的效果
var state_time: float


func _ready() -> void:
	# 确保父节点ready，避免初始化后调用父节点函数而父节点unready
	await owner.ready
	current_state = 0


func _physics_process(delta: float) -> void:
	while true:
		var next := owner.get_next_state(current_state) as int
		if current_state == next:
			break
		current_state = next

	# 使用方无需定义physics_process，只需定义此函数
	owner.tick_physics(current_state, delta)
	state_time += delta
