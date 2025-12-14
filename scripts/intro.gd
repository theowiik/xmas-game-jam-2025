extends Control

@onready var show_1 = $Show1
@onready var show_2 = $Show2
@onready var show_3 = $Show3
@onready var music = $AudioStreamPlayer


func _ready():
	show_1.modulate.a = 0
	show_2.modulate.a = 0
	show_3.modulate.a = 0

	await play_intro_sequence()


func play_intro_sequence():
	await get_tree().create_timer(2.0).timeout

	# Fade in show_1
	await fade_in(show_1, 1.0)
	await get_tree().create_timer(3.0).timeout

	# Fade in show_2
	await fade_in(show_2, 1.0)
	await get_tree().create_timer(6.0).timeout

	# Fade in show_3
	await fade_in(show_3, 1.0)
	await get_tree().create_timer(6.0).timeout

	# Fade out all shows and music
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(show_1, "modulate:a", 0.0, 1.0)
	tween.tween_property(show_2, "modulate:a", 0.0, 1.0)
	tween.tween_property(show_3, "modulate:a", 0.0, 1.0)
	if music:
		tween.tween_property(music, "volume_db", -80, 1.0)
	await tween.finished

	get_tree().change_scene_to_file("res://scenes/main.tscn")


func fade_in(node: Node, duration: float):
	var tween = create_tween()
	tween.tween_property(node, "modulate:a", 1.0, duration)
	await tween.finished
