class_name Player extends CharacterBody3D

@onready var view_pivot: Node3D = $ViewPivot
@onready var desired_camera_position: Node3D = $ViewPivot/DesiredCameraPosition
@onready var photo_info_label: RichTextLabel = $ViewPivot/Camera3D/CanvasGroup/PhotoInfoLabel

var camera: Camera = null

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


func _process(delta: float) -> void:
	move(delta)
	look(delta)
	camera_shake(delta)
	move_camera(delta)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
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


func _calculate_photo_score(detected_objects: Array[Dictionary], fov: float) -> Dictionary:
	if detected_objects.is_empty():
		return {"score": 0, "breakdown": {}}

	var total_score: float = 0.0
	var breakdown: Dictionary = {}

	# 1. SUBJECT COUNT SCORE (0-50 points)
	# More people = more points!
	var num_subjects: int = detected_objects.size()
	var subject_score: float = min(50.0, num_subjects * 15.0)
	breakdown["subjects"] = subject_score
	total_score += subject_score

	# 2. FOV CHALLENGE SCORE (0-30 points)
	# Low FOV (zoomed in) = harder = more points
	# High FOV (wide angle) = easier = less points
	var fov_score: float = max(0, 30.0 * (1.0 - (fov - 10.0) / 110.0))
	breakdown["zoom"] = fov_score
	total_score += fov_score

	# 3. CENTERING SCORE (0-20 points)
	# Main subject should be centered
	var main_subject: Dictionary = detected_objects[0]
	var main_screen_pos: Vector2 = main_subject.screen_pos
	var center_offset: Vector2 = main_screen_pos - Vector2(0.5, 0.5)
	var center_distance: float = center_offset.length()
	var centering_score: float = max(0, 20.0 * (1.0 - center_distance * 2.0))
	breakdown["centering"] = centering_score
	total_score += centering_score

	# Cap at 100
	total_score = min(100.0, total_score)

	return {"score": total_score, "breakdown": breakdown}


func _on_photo_taken(detected_objects: Array[Dictionary], fov: float) -> void:
	photo_info_label.clear()
	print("[PLAYER] Photo taken with FOV: %.1f" % fov)

	# Calculate score
	var score_data: Dictionary = _calculate_photo_score(detected_objects, fov)
	var score: float = score_data.score
	var breakdown: Dictionary = score_data.breakdown

	# Display score with color based on quality
	var score_color: String = "red"
	if score >= 80:
		score_color = "green"
	elif score >= 60:
		score_color = "yellow"
	elif score >= 40:
		score_color = "orange"

	photo_info_label.append_text("[color=%s]SCORE: %d/100[/color]\n\n" % [score_color, int(score)])

	# Display photo info
	photo_info_label.append_text("Photo Info:\n")
	photo_info_label.append_text("FOV: %.1f\n" % fov)

	if detected_objects.is_empty():
		photo_info_label.append_text("[color=gray]No subjects in frame[/color]\n")
	else:
		for obj_data in detected_objects:
			photo_info_label.append_text(
				"[color=green]%s (%.1fm away)[/color]\n" % [obj_data.name, obj_data.distance]
			)
			print("[PLAYER] - Captured: %s (%.1fm away)" % [obj_data.name, obj_data.distance])

		# Display score breakdown
		photo_info_label.append_text("\nScore Breakdown:\n")
		photo_info_label.append_text("  Subjects: %.0f/50\n" % breakdown.get("subjects", 0))
		photo_info_label.append_text("  Zoom: %.0f/30\n" % breakdown.get("zoom", 0))
		photo_info_label.append_text("  Centering: %.0f/20\n" % breakdown.get("centering", 0))

	print("[PLAYER] Photo score: %d/100" % int(score))
