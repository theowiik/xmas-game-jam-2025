extends Node3D

@onready var sub_viewport: SubViewport = $SubViewport
@onready var camera: Camera3D = $SubViewport/Camera3D
@onready var camera_pos: Node3D = $CameraPos

var target_fov: float = 75.0
var zoom_speed: float = 8.0


func _ready() -> void:
	target_fov = camera.fov


func _process(delta: float) -> void:
	camera.transform = camera_pos.global_transform
	camera.fov = lerp(camera.fov, target_fov, zoom_speed * delta)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ZOOM_IN"):
		target_fov = max(10.0, target_fov - 5.0)
	elif event.is_action_pressed("ZOOM_OUT"):
		target_fov = min(120.0, target_fov + 5.0)
	elif event.is_action_pressed("PHOTO"):
		_take_photo()

func _take_photo() -> void:
	print("I took a photo of...")
	_find_objects_in_view()
	_save_photo()

func _find_objects_in_view() -> void:
	var photogenic_objects: Array[Node] = get_tree().get_nodes_in_group("photogenic")
	var detected_objects: Array[Dictionary] = []

	for obj in photogenic_objects:
		if obj is Node3D:
			var obj_3d: Node3D = obj as Node3D
			if _is_in_camera_view(obj_3d):
				var dist: float = camera.global_position.distance_to(obj_3d.global_position)
				detected_objects.append({
					"name": obj_3d.name,
					"distance": dist
				})

	detected_objects.sort_custom(func(a, b): return a.distance < b.distance)

	print("\n=== Photo Contents ===")
	if detected_objects.is_empty():
		print("Nothing interesting in frame")
	else:
		for obj_data in detected_objects:
			print("  - %s (%.1fm away)" % [obj_data.name, obj_data.distance])
	print("======================\n")

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

	var margin: float = 100.0
	if screen_pos.x < -margin or screen_pos.x > viewport_size.x + margin:
		return false
	if screen_pos.y < -margin or screen_pos.y > viewport_size.y + margin:
		return false

	return true

func _save_photo() -> void:
	var img: Image = sub_viewport.get_texture().get_image()
	var file_path: String = "user://photo_%s.png" % Time.get_unix_time_from_system()
	var err: Error = img.save_png(file_path)

	if err == OK:
		print("Photo saved to: ", file_path)
		print("Real place to find the photo: ", ProjectSettings.globalize_path(file_path))
	else:
		print("Failed to save photo: ", err)
