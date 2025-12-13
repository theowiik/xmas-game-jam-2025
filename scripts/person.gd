extends CharacterBody3D

@onready var agent: NavigationAgent3D = $NavigationAgent3D
var speed: float = 5.0

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		var random_pos := Vector3.ZERO
		random_pos.x = randf_range(-5.0, 5.0)
		random_pos.z = randf_range(-5.0, 5.0)
		agent.set_target_position(random_pos)

func _physics_process(delta: float) -> void:
	var destination = agent.get_next_path_position()
	var local_destination = destination - global_position
	var direction = local_destination.normalized()
	
	velocity = direction * speed
	move_and_slide()
