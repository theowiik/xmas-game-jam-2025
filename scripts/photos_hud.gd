extends Control

@onready var photos_container: GridContainer = $CenterContainer/PhotosContainer
@onready var overall_score_label: RichTextLabel = $OverallScoreLabel

const PHOTO_SUMMARY_CARD = preload("res://objects/photo_summary_card.tscn")

var photo_scores: Array[int] = []
var is_final_screen_open: bool = false

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	visible = false
	# Clear example cards
	for child in photos_container.get_children():
		child.queue_free()


func _unhandled_key_input(event: InputEvent) -> void:
	# Don't allow manual opening - only toggling mouse capture during gameplay
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE and not is_final_screen_open:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	# Capture mouse on click during gameplay (not on final screen)
	if event is InputEventMouseButton and event.pressed and not is_final_screen_open:
		if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func add_photo(texture: ImageTexture, score: int, detected_objects: Array[Dictionary]) -> bool:
	# Store the score
	photo_scores.append(score)

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
		# Count objects by type
		var object_counts: Dictionary = {}
		for obj_data in detected_objects:
			var obj_type: String = obj_data.get("type", "unknown")
			if object_counts.has(obj_type):
				object_counts[obj_type] += 1
			else:
				object_counts[obj_type] = 1

		# Display counts
		var count_parts: Array[String] = []
		for obj_type in object_counts.keys():
			count_parts.append("%dx %s" % [object_counts[obj_type], obj_type])
		objects_text = ", ".join(count_parts)

	label.text = "[center]%s\n[color=%s]Score: %d/100[/color][/center]" % [objects_text, score_color, score]

	# Return true if this is the last photo
	return photo_scores.size() >= 5


func show_final_screen() -> void:
	is_final_screen_open = true
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	# Calculate overall score
	var overall_score: int = 0
	for score in photo_scores:
		overall_score += score

	# Determine color based on overall score
	var score_color: String = "red"
	if overall_score >= 400:
		score_color = "green"
	elif overall_score >= 300:
		score_color = "yellow"
	elif overall_score >= 200:
		score_color = "orange"

	# Update the overall score label
	overall_score_label.text = "[center][font_size=60][color=%s]OVERALL SCORE: %d/500[/color][/font_size][/center]" % [score_color, overall_score]

	print("[PHOTOS_HUD] Final screen opened. Overall score: %d" % overall_score)


func _on_exit_button_pressed() -> void:
	# Open the photos directory in the native file explorer
	var photos_dir: String = ProjectSettings.globalize_path("user://")
	OS.shell_open(photos_dir)

	# Wait a moment to ensure the file explorer opens before quitting
	await get_tree().create_timer(0.2).timeout
	get_tree().quit()
