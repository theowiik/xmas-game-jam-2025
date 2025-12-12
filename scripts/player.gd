class_name Player extends CharacterBody3D

@onready var view_pivot: Node3D = $ViewPivot
@onready var desired_camera_position: Node3D = $ViewPivot/DesiredCameraPosition

var camera: Node3D = null

var jump_velocity: float = 4.5
var gravity: float = 9.82
var speed: float = 5.0

var rotation_smoothing: float = 5.0
var camera_position_smoothing: float = 15.0
var camera_rotation_smoothing: float = 15.0

var target_rotation_y: float = 0.0
var target_rotation_x: float = 0.0
var current_rotation_x: float = 0.0

var bob_time: float = 0.0
var bob_speed: float = 12.0
var bob_intensity: float = 0.08
var bob_sway: float = 0.05


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _process(delta: float) -> void:
	move(delta)
	smooth_rotation(delta)
	apply_camera_bob(delta)
	smooth_camera(delta)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_tree().quit()

	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var mouse_delta: Vector2 = event.relative
		target_rotation_y += deg_to_rad(-mouse_delta.x * 0.1)
		target_rotation_x += deg_to_rad(-mouse_delta.y * 0.1)
		target_rotation_x = clamp(target_rotation_x, deg_to_rad(-60), deg_to_rad(60))


func smooth_rotation(delta: float) -> void:
	rotation.y = lerp_angle(rotation.y, target_rotation_y, rotation_smoothing * delta)
	current_rotation_x = lerp(current_rotation_x, target_rotation_x, rotation_smoothing * delta)
	view_pivot.rotation.x = current_rotation_x


func apply_camera_bob(delta: float) -> void:
	var velocity_2d := Vector2(velocity.x, velocity.z)
	var is_moving := velocity_2d.length() > 0.1 and is_on_floor()

	if is_moving:
		bob_time += delta * bob_speed
	else:
		bob_time = lerp(bob_time, 0.0, delta * 10.0)

	var bob_offset_y := sin(bob_time) * bob_intensity
	var bob_offset_x := cos(bob_time * 0.5) * bob_sway

	view_pivot.position.y = bob_offset_y
	view_pivot.position.x = bob_offset_x


func smooth_camera(delta: float) -> void:
	if camera == null:
		return

	camera.global_position = camera.global_position.lerp(
		desired_camera_position.global_position,
		camera_position_smoothing * delta
	)

	camera.global_rotation = camera.global_rotation.lerp(
		desired_camera_position.global_rotation,
		camera_rotation_smoothing * delta
	)


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
