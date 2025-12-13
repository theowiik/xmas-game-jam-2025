class_name Player extends CharacterBody3D

@onready var view_pivot: Node3D = $ViewPivot
@onready var desired_camera_position: Node3D = $ViewPivot/DesiredCameraPosition

var camera: Node3D = null

var jump_velocity: float = 4.5
var gravity: float = 9.82
var speed: float = 5.0

var look_speed: float = 0.8
var player_rotation_smoothing: float = 5.0
var camera_position_smoothing: float = 15.0
var camera_rotation_smoothing: float = 15.0

var target_rotation_y: float = 0.0
var target_rotation_x: float = 0.0
var current_rotation_x: float = 0.0

var bob_time: float = 0.0
var bob_speed: float = 12.0
var bob_intensity: float = 0.08
var bob_sway: float = 0.05

# Physics-based camera rotation
var camera_angular_velocity: Vector3 = Vector3.ZERO
var camera_roll_intensity: float = 0.15  # How much the camera rolls when turning (z-axis)
var camera_tilt_intensity: float = 0.1  # How much the camera tilts on lateral movement (z-axis)
var camera_yaw_sway: float = 0.08  # How much the camera sways when moving (y-axis)
var camera_angular_damping: float = 8.0  # How fast angular velocity dampens
var previous_rotation_y: float = 0.0


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _process(delta: float) -> void:
	move(delta)
	look(delta)
	camera_shake(delta)
	move_camera(delta)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_tree().quit()

	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var mouse_delta: Vector2 = event.relative
		target_rotation_y = deg_to_rad(-mouse_delta.x * look_speed)
		target_rotation_x = deg_to_rad(-mouse_delta.y * look_speed)


func look(delta: float) -> void:
	var rotation_delta_y = target_rotation_y * player_rotation_smoothing * delta
	rotation.y += rotation_delta_y

	# Track rotation velocity for physics-based camera
	var rotation_velocity_y = (rotation.y - previous_rotation_y) / delta if delta > 0 else 0
	previous_rotation_y = rotation.y

	# Apply angular velocity based on turning speed (for camera roll)
	camera_angular_velocity.z = -rotation_velocity_y * camera_roll_intensity

	current_rotation_x += target_rotation_x * player_rotation_smoothing * delta
	current_rotation_x = clamp(current_rotation_x, deg_to_rad(-60), deg_to_rad(60))
	view_pivot.rotation.x = current_rotation_x

	target_rotation_y = lerp(target_rotation_y, 0.0, 10.0 * delta)
	target_rotation_x = lerp(target_rotation_x, 0.0, 10.0 * delta)


func camera_shake(delta: float) -> void:
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


func move_camera(delta: float) -> void:
	if camera == null:
		return

	camera.global_position = camera.global_position.lerp(
		desired_camera_position.global_position, camera_position_smoothing * delta
	)

	# Calculate lateral movement tilt based on velocity
	var velocity_2d := Vector2(velocity.x, velocity.z)
	var player_right := transform.basis.x
	var player_forward := -transform.basis.z
	var lateral_velocity := velocity.dot(player_right)
	var forward_velocity := velocity.dot(player_forward)
	var lateral_tilt := lateral_velocity * camera_tilt_intensity

	# Add lateral tilt to angular velocity (z-axis)
	camera_angular_velocity.z += lateral_tilt * delta * 10.0

	# Add forward/backward sway to angular velocity (y-axis)
	var yaw_sway := sin(bob_time * 0.5) * forward_velocity * camera_yaw_sway
	camera_angular_velocity.y += yaw_sway * delta * 10.0

	# Apply damping to angular velocity
	camera_angular_velocity = camera_angular_velocity.lerp(
		Vector3.ZERO, camera_angular_damping * delta
	)

	# Get the target rotation from desired camera position
	var target_quat := desired_camera_position.global_transform.basis.get_rotation_quaternion()

	# Apply physics-based rotation (angular velocity) on top of target rotation
	var physics_rotation := Basis.from_euler(camera_angular_velocity)
	var combined_basis := Basis(target_quat) * physics_rotation

	# Smoothly interpolate to the combined rotation
	var current_quat := camera.global_transform.basis.get_rotation_quaternion()
	var target_physics_quat := combined_basis.get_rotation_quaternion()
	var interpolated_quat := current_quat.slerp(
		target_physics_quat, camera_rotation_smoothing * delta
	)

	camera.global_transform.basis = Basis(interpolated_quat)


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
