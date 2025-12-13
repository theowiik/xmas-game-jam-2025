extends Node3D

@onready var player: Node3D = $"Player"
@onready var camera: Node3D = $"Camera"


func _ready() -> void:
	player.camera = camera
