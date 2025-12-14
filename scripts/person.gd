extends CharacterBody3D

@onready var agent: NavigationAgent3D = $NavigationAgent3D
@onready var idle_sprite: Sprite3D = $IdleSprite
@onready var smile_sprite: Sprite3D = $SmileSprite
@onready var see_camera_label: Label3D = $SeeCameraLabel
@onready var smile_player: AudioStreamPlayer3D = $SmilePlayer

var smile_sounds: Array[AudioStream] = []

var speed: float = 5.0
var min_wait_time: float = 0.5
var max_wait_time: float = 2.0
var wait_time: float = 0.0
var current_wait_time: float = 0.0
var is_waiting: bool = false
var is_smiling: bool = false

var camera: Node3D = null

# Smile FOV thresholds - at reference distance, FOV must be <= this to smile
var reference_distance: float = 5.0  # Distance at which reference FOV is used
var reference_fov: float = 50.0  # FOV threshold at reference distance


func _ready() -> void:
	# Camera reference will be set by Main.gd

	# Load all .wav files from the smile directory
	var dir = DirAccess.open("res://assets/sfx/smile")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".wav"):
				var sound = load("res://assets/sfx/smile/" + file_name)
				if sound:
					smile_sounds.append(sound)
			file_name = dir.get_next()
		dir.list_dir_end()


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

		# Calculate distance to camera and required FOV
		var distance_to_camera: float = cam.global_position.distance_to(global_position)
		var current_fov: float = cam.fov

		# Calculate required FOV based on distance
		# Farther away = need lower FOV (more zoom) to smile
		var required_fov: float = reference_fov * (reference_distance / distance_to_camera)
		var is_zoomed_enough: bool = current_fov <= required_fov

		# If centered (within a small threshold) AND zoomed in enough, show smile sprite
		if center_distance < 0.15 and is_zoomed_enough:  # Roughly centered and zoomed enough
			smile_sprite.visible = true
			idle_sprite.visible = false
			see_camera_label.visible = true

			# Play random smile sound when starting to smile
			if not is_smiling:
				smile_player.stream = smile_sounds[randi() % smile_sounds.size()]
				smile_player.play()
				is_smiling = true
		else:
			# Just in frame, show idle sprite
			smile_sprite.visible = false
			idle_sprite.visible = true
			see_camera_label.visible = false
			is_smiling = false
	else:
		# Not in frame, show idle sprite
		smile_sprite.visible = false
		idle_sprite.visible = true
		see_camera_label.visible = false
		is_smiling = false


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
