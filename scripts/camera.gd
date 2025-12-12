extends Node3D

@onready var sub_viewport: SubViewport = $SubViewport
@onready var sub_camera: Camera3D = $SubViewport/Camera3D
@onready var camera_pos: Node3D = $CameraPos


func _process(delta: float) -> void:
	sub_camera.transform = camera_pos.global_transform
