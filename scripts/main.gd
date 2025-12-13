extends Node3D

@onready var player: Node3D = $"Player"
@onready var camera: Node3D = $"Camera"


func _ready() -> void:
	player.camera = camera

	# Set camera reference for all people
	var people_node = get_node("People")
	for person in people_node.get_children():
		if person.has_method("set_camera"):
			person.set_camera(camera)
		else:
			person.camera = camera
