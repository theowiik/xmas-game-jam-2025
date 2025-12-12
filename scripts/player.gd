class_name Player extends CharacterBody3D

@onready var view_pivot: Node3D = $ViewPivot
var jump_velocity: float = 4.5
var gravity: float = 9.82
var speed: float = 5.0


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _process(delta: float) -> void:
	move(delta)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_tree().quit()

	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var mouse_delta: Vector2 = event.relative
		rotate_y(deg_to_rad(-mouse_delta.x * 0.1))
		view_pivot.rotate_x(deg_to_rad(-mouse_delta.y * 0.1))
		view_pivot.rotation.x = clamp(view_pivot.rotation.x, deg_to_rad(-89), deg_to_rad(89))


func move(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

	if Input.is_action_just_pressed("JUMP") and is_on_floor():
		velocity.y = jump_velocity

	var input_dir := Input.get_vector("WALK_LEFT", "WALK_RIGHT", "WALK_FORWARD", "WALK_BACK")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	if direction != Vector3.ZERO:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)

	move_and_slide()
