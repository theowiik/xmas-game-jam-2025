extends CharacterBody3D

@onready var agent: NavigationAgent3D = $NavigationAgent3D
@onready var idle_sprite: Sprite3D = $IdleSprite
@onready var smile_sprite: Sprite3D = $SmileSprite
@onready var see_camera_label: Label3D = $SeeCameraLabel
@onready var smile_player: AudioStreamPlayer3D = $SmilePlayer

var speed: float = 5.0
var min_wait_time: float = 0.5
var max_wait_time: float = 2.0
var wait_time: float = 0.0
var current_wait_time: float = 0.0
var is_waiting: bool = false

var camera: Node3D = null
var default_color: Color = Color.WHITE
var in_frame_color: Color = Color(0.3, 1.0, 0.3)  # Green tint
var centered_color: Color = Color(1.0, 1.0, 0.3)  # Yellow tint


func _ready() -> void:
	# Camera reference will be set by Main.gd
	pass


func _process(_delta: float) -> void:
	if camera == null:
		return

	# Check if we're in the camera's view
	if camera._is_in_camera_view(self):
		var cam = camera.get_node("SubViewport/Camera3D")
		var sub_viewport = camera.get_node("SubViewport")
		var viewport_size: Vector2 = sub_viewport.get_visible_rect().size

		# Get screen position
		var screen_pos: Vector2 = cam.unproject_position(global_position)
		var normalized_pos: Vector2 = screen_pos / viewport_size

		# Calculate distance from center
		var center_offset: Vector2 = normalized_pos - Vector2(0.5, 0.5)
		var center_distance: float = center_offset.length()

		# If centered (within a small threshold), show smile sprite
		if center_distance < 0.15:  # Roughly centered
			smile_sprite.visible = true
			idle_sprite.visible = false
			smile_sprite.modulate = centered_color
			see_camera_label.visible = true
		else:
			# Just in frame, show idle sprite with green tint
			smile_sprite.visible = false
			idle_sprite.visible = true
			idle_sprite.modulate = in_frame_color
			see_camera_label.visible = false
	else:
		# Not in frame, show idle sprite with default color
		smile_sprite.visible = false
		idle_sprite.visible = true
		idle_sprite.modulate = default_color
		see_camera_label.visible = false


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
