extends Control

@onready var photo_texture: TextureRect = $PhotoTexture
@onready var photos_container: VBoxContainer = $ScrollContainer/PhotosContainer

const PHOTO_SUMMARY_CARD = preload("res://objects/photo_summary_card.tscn")

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# Clear example cards
	for child in photos_container.get_children():
		child.queue_free()


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		visible = !visible
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if visible else Input.MOUSE_MODE_CAPTURED


func add_photo(texture: ImageTexture, score: int, detected_objects: Array[Dictionary]) -> void:
	var card = PHOTO_SUMMARY_CARD.instantiate()
	photos_container.add_child(card)

	# Set the photo texture
	var texture_rect = card.get_node("TextureRect")
	texture_rect.texture = texture

	# Create nice text with score and detected objects
	var label = card.get_node("Label")
	var score_color := "red"
	if score >= 80:
		score_color = "green"
	elif score >= 60:
		score_color = "yellow"
	elif score >= 40:
		score_color = "orange"

	# Build text with objects detected
	var objects_text := ""
	if detected_objects.is_empty():
		objects_text = "No subjects"
	else:
		# Count objects by type (strip trailing numbers from names)
		var object_counts: Dictionary = {}
		for obj_data in detected_objects:
			var obj_name: String = obj_data.name
			# Extract base type by removing trailing digits
			var base_type: String = obj_name.rstrip("0123456789")
			if object_counts.has(base_type):
				object_counts[base_type] += 1
			else:
				object_counts[base_type] = 1

		# Display counts
		var count_parts: Array[String] = []
		for obj_type in object_counts.keys():
			count_parts.append("%dx %s" % [object_counts[obj_type], obj_type])
		objects_text = ", ".join(count_parts)

	label.text = "[center]%s\n[color=%s]Score: %d/100[/color][/center]" % [objects_text, score_color, score]


func _on_exit_button_pressed() -> void:
	get_tree().quit()
