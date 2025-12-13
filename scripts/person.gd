extends CharacterBody3D

@onready var agent: NavigationAgent3D = $NavigationAgent3D
var speed: float = 5.0
var min_wait_time: float = 0.5
var max_wait_time: float = 2.0
var wait_time: float = 0.0
var current_wait_time: float = 0.0
var is_waiting: bool = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		move_to_random_position()


func move_to_random_position() -> void:
	var random_offset := Vector3.ZERO
	random_offset.x = randf_range(-5.0, 5.0)
	random_offset.z = randf_range(-5.0, 5.0)
	var target_pos = global_position + random_offset
	agent.set_target_position(target_pos)
	is_waiting = false


func _physics_process(delta: float) -> void:
	if is_waiting:
		current_wait_time += delta
		if current_wait_time >= wait_time:
			current_wait_time = 0.0
			move_to_random_position()
		return

	var destination = agent.get_next_path_position()
	var local_destination = destination - global_position
	var direction = local_destination.normalized()

	if agent.is_navigation_finished():
		is_waiting = true
		wait_time = randf_range(min_wait_time, max_wait_time)
		velocity = Vector3.ZERO
	else:
		velocity = direction * speed

	move_and_slide()
