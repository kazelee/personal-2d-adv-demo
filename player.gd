class_name Player
extends CharacterBody2D

enum State {
	IDLE,
	RUNNING,
	JUMP,
	FALL,
	LANDING,
	WALL_SLIDING,
	WALL_JUMP,
	ATTACK_1,
	ATTACK_2,
	ATTACK_3,
}

# ":=" 表示强类型（初始化后就不能更改类型）
const GROUND_STATES := [
	State.IDLE, State.RUNNING, State.LANDING,
	State.ATTACK_1, State.ATTACK_2, State.ATTACK_3,
]
const RUN_SPEED := 160.0
const FLOOR_ACCELERATION := RUN_SPEED / 0.2
const AIR_ACCELERATION := RUN_SPEED / 0.1
# -300 2格高；-400 3格高
const JUMP_VELOCITY := -360.0
const WALL_JUMP_VELOCITY := Vector2(380, -280)

@export var can_combo: bool = false

var default_gravity := ProjectSettings.get("physics/2d/default_gravity") as float
var is_first_tick := false
var is_combo_requested := false

# 简便操作：1.选择节点；2.拖到脚本中；3.按住CTRL键后释放
@onready var graphics: Node2D = $Graphics
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var coyote_timer: Timer = $CoyoteTimer
@onready var jump_request_timer: Timer = $JumpRequestTimer
@onready var hand_checker: RayCast2D = $Graphics/HandChecker
@onready var foot_checker: RayCast2D = $Graphics/FootChecker
@onready var state_machine: Node = $StateMachine


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("jump"):
		jump_request_timer.start()
	if event.is_action_released("jump"):
		jump_request_timer.stop()
		if velocity.y < JUMP_VELOCITY / 2:
			velocity.y = JUMP_VELOCITY / 2

	if Input.is_action_just_pressed("attack") and can_combo:
		is_combo_requested = true


func tick_physics(state: State, delta: float) -> void:
	match state:
		State.IDLE:
			move(default_gravity, delta)

		State.RUNNING:
			move(default_gravity, delta)

		State.JUMP:
			# 确保第一帧时重力为0，避免出现“跳不起来”的情况
			move(0.0 if is_first_tick else default_gravity, delta)

		State.FALL:
			move(default_gravity, delta)

		State.LANDING:
			stand(default_gravity, delta)

		State.WALL_SLIDING:
			# 滑墙状态下重力会变小
			move(default_gravity / 3, delta)
			graphics.scale.x = get_wall_normal().x

		State.WALL_JUMP:
			if state_machine.state_time < 0.1:
				stand(0.0 if is_first_tick else default_gravity, delta)
				# 蹬墙跳开始的方向以墙面法线为准
				graphics.scale.x = get_wall_normal().x
			else:
				move(default_gravity, delta)

		State.ATTACK_1, State.ATTACK_2, State.ATTACK_3:
			stand(default_gravity, delta)

	is_first_tick = false


func move(gravity: float, delta: float) -> void:
	# get_axis(-,+) return (-1, 0, 1)
	var direction := Input.get_axis("move_left", "move_right")
	var acceleration := FLOOR_ACCELERATION if is_on_floor() else AIR_ACCELERATION
	# 加速度，从A到B步进C：从v到vmax步进a*dt
	velocity.x = move_toward(velocity.x, direction * RUN_SPEED, acceleration * delta)
	velocity.y += gravity * delta

	# 向左走的动画（反转贴图）
	if not is_zero_approx(direction):
		graphics.scale.x = -1 if direction < 0 else +1

	move_and_slide()


# 为landing状态特制的函数
func stand(gravity: float, delta: float) -> void:
	var acceleration := FLOOR_ACCELERATION if is_on_floor() else AIR_ACCELERATION
	# 加速度，从A到B步进C：从v到vmax步进a*dt
	velocity.x = move_toward(velocity.x, 0.0, acceleration * delta)
	velocity.y += gravity * delta

	move_and_slide()


# P8, #7, 11'30"
func can_wall_silde() -> bool:
	return is_on_wall() and hand_checker.is_colliding() and foot_checker.is_colliding()


func get_next_state(state: State) -> State:
	var can_jump := is_on_floor() or coyote_timer.time_left > 0
	var should_jump := can_jump and jump_request_timer.time_left > 0
	if should_jump:
		return State.JUMP

	if state in GROUND_STATES and not is_on_floor():
		return State.FALL

	var direction := Input.get_axis("move_left", "move_right")
	var is_still := is_zero_approx(direction) and is_zero_approx(velocity.x)

	match state:
		State.IDLE:
#			if not is_on_floor():
#				return State.FALL
			if Input.is_action_just_pressed("attack"):
				return State.ATTACK_1
			if not is_still:
				return State.RUNNING

		State.RUNNING:
#			if not is_on_floor():
#				return State.FALL
			if Input.is_action_just_pressed("attack"):
				return State.ATTACK_1
			if is_still:
				return State.IDLE

		State.JUMP:
			if velocity.y >= 0:
				return State.FALL

		State.FALL:
			if is_on_floor():
				# 如果角色横向移动，直接切换成running状态
				return State.LANDING if is_still else State.RUNNING
			# 角色的手和脚都与墙壁有碰撞才能爬墙；抽象成函数：P8, #7, 11'30"
			if can_wall_silde():
				return State.WALL_SLIDING

		State.LANDING:
			# 避免落地后有一小段时间无法移动
			if not is_still:
				return State.RUNNING
			if not animation_player.is_playing():
				return State.IDLE

		State.WALL_SLIDING:
			if jump_request_timer.time_left > 0:
				return State.WALL_JUMP
			if is_on_floor():
				return State.IDLE
			if not is_on_wall():
				return State.FALL

		State.WALL_JUMP:
			# P8, #7, almost 11'00", 11'30"
			if can_wall_silde() and not is_first_tick:
				return State.WALL_SLIDING
			if velocity.y >= 0:
				return State.FALL

		State.ATTACK_1:
			if not animation_player.is_playing():
				return State.ATTACK_2 if is_combo_requested else State.IDLE

		State.ATTACK_2:
			if not animation_player.is_playing():
				return State.ATTACK_3 if is_combo_requested else State.IDLE

		State.ATTACK_3:
			if not animation_player.is_playing():
				return State.IDLE

	return state


func transition_state(from: State, to: State) -> void:
	if from not in GROUND_STATES and to in GROUND_STATES:
		coyote_timer.stop()

	match to:
		State.IDLE:
			animation_player.play("idle")

		State.RUNNING:
			animation_player.play("running")

		State.JUMP:
			animation_player.play("jump")
			velocity.y = JUMP_VELOCITY
			coyote_timer.stop()
			jump_request_timer.stop()

		State.FALL:
			animation_player.play("fall")
			if from in GROUND_STATES:
				coyote_timer.start()

		State.LANDING:
			animation_player.play("landing")

		State.WALL_SLIDING:
			animation_player.play("wall_sliding")

		State.WALL_JUMP:
			animation_player.play("jump")
			velocity = WALL_JUMP_VELOCITY
			# wall jump v 默认向右，乘墙面法向量即可改变方向
			velocity.x *= get_wall_normal().x
			jump_request_timer.stop()

		State.ATTACK_1:
			animation_player.play("attack_1")
			is_combo_requested = false

		State.ATTACK_2:
			animation_player.play("attack_2")
			is_combo_requested = false

		State.ATTACK_3:
			animation_player.play("attack_3")
			is_combo_requested = false

	# 蹬墙跳“慢动作”效果
#	if to == State.WALL_JUMP:
#		Engine.time_scale = 0.3
#	if from == State.WALL_JUMP:
#		Engine.time_scale = 1.0

	is_first_tick = true
