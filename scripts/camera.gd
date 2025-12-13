extends Node3D

@onready var sub_viewport: SubViewport = $SubViewport
@onready var sub_camera: Camera3D = $SubViewport/Camera3D
@onready var camera_pos: Node3D = $CameraPos

var target_fov: float = 75.0
var zoom_speed: float = 8.0


func _ready() -> void:
	target_fov = sub_camera.fov


func _process(delta: float) -> void:
	sub_camera.transform = camera_pos.global_transform
	sub_camera.fov = lerp(sub_camera.fov, target_fov, zoom_speed * delta)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ZOOM_IN"):
		target_fov = max(10.0, target_fov - 5.0)
	elif event.is_action_pressed("ZOOM_OUT"):
		target_fov = min(120.0, target_fov + 5.0)
