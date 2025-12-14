extends Node3D

@onready var player: Player = $"Player"
@onready var camera: Camera = $"Camera"
@onready var photos_hud: Node = $"PhotosHUD"


func _ready() -> void:
	player.camera = camera
	camera.photo_taken.connect(player._on_photo_taken)

	# Set camera reference for all people
	var people_node = get_node("People")
	for person in people_node.get_children():
		if person.has_method("set_camera"):
			person.set_camera(camera)
		else:
			person.camera = camera
