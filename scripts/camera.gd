class_name Camera extends Node3D

signal photo_taken(detected_objects: Array[Dictionary], fov: float, image: Image)

@onready var sub_viewport: SubViewport = $SubViewport
@onready var camera: Camera3D = $SubViewport/Camera3D
@onready var camera_pos: Node3D = $CameraPos
@onready var shutter_player: AudioStreamPlayer = $ShutterPlayer
@onready var canvas_layer: CanvasLayer = $SubViewport/CanvasLayer
@onready var fov_label: Label = $SubViewport/CanvasLayer/FovLabel
@onready var photos_label: Label = $SubViewport/CanvasLayer/PhotosLabel

var target_fov: float = 75.0
var zoom_speed: float = 8.0

const MAX_PHOTOS: int = 5
var photos_taken: int = 0


func _ready() -> void:
	target_fov = camera.fov
	_update_photos_label()


func _process(delta: float) -> void:
	camera.transform = camera_pos.global_transform
	camera.fov = lerp(camera.fov, target_fov, zoom_speed * delta)
	fov_label.text = "FOV: %d" % int(camera.fov)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ZOOM_IN"):
		target_fov = max(10.0, target_fov - 5.0)
	elif event.is_action_pressed("ZOOM_OUT"):
		target_fov = min(120.0, target_fov + 5.0)
	elif event.is_action_pressed("PHOTO"):
		_take_photo()


func _take_photo() -> void:
	if photos_taken >= MAX_PHOTOS:
		print("No photos remaining!")
		return

	print("I took a photo of...")

	# Hide the HUD before capturing the photo
	canvas_layer.visible = false

	# Wait for the physics frame to ensure the viewport renders without the HUD
	await get_tree().physics_frame
	await get_tree().physics_frame

	var img: Image = sub_viewport.get_texture().get_image()

	# Show the HUD again
	canvas_layer.visible = true

	_find_objects_in_view(img)
	_save_photo(img)
	shutter_player.play()

	photos_taken += 1
	_update_photos_label()


func _find_objects_in_view(img: Image) -> void:
	var photogenic_objects: Array[Node] = get_tree().get_nodes_in_group("photogenic")
	var detected_objects: Array[Dictionary] = []
	var viewport_size: Vector2 = sub_viewport.get_visible_rect().size

	for obj in photogenic_objects:
		if obj is Node3D:
			var obj_3d: Node3D = obj as Node3D
			if _is_in_camera_view(obj_3d):
				var dist: float = camera.global_position.distance_to(obj_3d.global_position)
				var screen_pos: Vector2 = camera.unproject_position(obj_3d.global_position)
				# Normalize screen position (0-1 range, where 0.5, 0.5 is center)
				var normalized_pos: Vector2 = screen_pos / viewport_size

				# Determine object type from groups
				var obj_type: String = "unknown"
				if obj_3d.is_in_group("santa"):
					obj_type = "santa"
				elif obj_3d.is_in_group("reindeer"):
					obj_type = "reindeer"
				elif obj_3d.is_in_group("person"):
					obj_type = "person"
				elif obj_3d.is_in_group("store"):
					obj_type = "store"
				elif obj_3d.is_in_group("tree"):
					obj_type = "tree"

				detected_objects.append(
					{"name": obj_3d.name, "type": obj_type, "distance": dist, "screen_pos": normalized_pos}
				)

	detected_objects.sort_custom(func(a, b): return a.distance < b.distance)

	photo_taken.emit(detected_objects, camera.fov, img)


func _is_in_camera_view(node: Node3D) -> bool:
	var obj_pos: Vector3 = node.global_position
	var cam_transform: Transform3D = camera.global_transform

	var to_object: Vector3 = obj_pos - cam_transform.origin
	var camera_forward: Vector3 = -cam_transform.basis.z
	var dot_product: float = to_object.dot(camera_forward)

	if dot_product <= 0:
		return false

	var screen_pos: Vector2 = camera.unproject_position(obj_pos)
	var viewport_size: Vector2 = sub_viewport.get_visible_rect().size

	var margin: float = 0.0  # No margin - must be actually visible in viewport
	if screen_pos.x < -margin or screen_pos.x > viewport_size.x + margin:
		return false
	if screen_pos.y < -margin or screen_pos.y > viewport_size.y + margin:
		return false

	return true


func _save_photo(img: Image) -> void:
	var file_path: String = "user://photo_%s.png" % Time.get_unix_time_from_system()
	var err: Error = img.save_png(file_path)

	if err == OK:
		print("Photo saved to: ", file_path)
		print("Real place to find the photo: ", ProjectSettings.globalize_path(file_path))
	else:
		print("Failed to save photo: ", err)


func _update_photos_label() -> void:
	photos_label.text = "%d/%d photos" % [photos_taken, MAX_PHOTOS]
