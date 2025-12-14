extends Node3D

@onready var player: Player = $"Player"
@onready var camera: Camera = $"Camera"
@onready var photos_hud: Node = $"PhotosHUD"


func _ready() -> void:
	player.camera = camera
	camera.photo_taken.connect(_on_photo_taken)

	# Set camera reference for all people
	var people_node = get_node("People")
	for person in people_node.get_children():
		if person.has_method("set_camera"):
			person.set_camera(camera)
		else:
			person.camera = camera


func _calculate_photo_score(detected_objects: Array[Dictionary], fov: float) -> Dictionary:
	if detected_objects.is_empty():
		return {"score": 0, "breakdown": {}}

	var total_score: float = 0.0
	var breakdown: Dictionary = {}

	# 1. SUBJECT COUNT SCORE (0-50 points)
	# More people = more points!
	var num_subjects: int = detected_objects.size()
	var subject_score: float = min(50.0, num_subjects * 15.0)
	breakdown["subjects"] = subject_score
	total_score += subject_score

	# 2. FOV CHALLENGE SCORE (0-30 points)
	# Low FOV (zoomed in) = harder = more points
	# High FOV (wide angle) = easier = less points
	var fov_score: float = max(0, 30.0 * (1.0 - (fov - 10.0) / 110.0))
	breakdown["zoom"] = fov_score
	total_score += fov_score

	# 3. CENTERING SCORE (0-20 points)
	# Main subject should be centered
	var main_subject: Dictionary = detected_objects[0]
	var main_screen_pos: Vector2 = main_subject.screen_pos
	var center_offset: Vector2 = main_screen_pos - Vector2(0.5, 0.5)
	var center_distance: float = center_offset.length()
	var centering_score: float = max(0, 20.0 * (1.0 - center_distance * 2.0))
	breakdown["centering"] = centering_score
	total_score += centering_score

	# Cap at 100
	total_score = min(100.0, total_score)

	return {"score": total_score, "breakdown": breakdown}


func _on_photo_taken(detected_objects: Array[Dictionary], fov: float, image: Image) -> void:
	var photo_info_label: RichTextLabel = player.photo_info_label
	photo_info_label.clear()
	print("[MAIN] Photo taken with FOV: %.1f" % fov)

	# Display the photo on the PhotosHUD
	var texture: ImageTexture = ImageTexture.create_from_image(image)
	photos_hud.photo_texture.texture = texture

	# Calculate score
	var score_data: Dictionary = _calculate_photo_score(detected_objects, fov)
	var score: float = score_data.score
	var breakdown: Dictionary = score_data.breakdown

	# Display score with color based on quality
	var score_color: String = "red"
	if score >= 80:
		score_color = "green"
	elif score >= 60:
		score_color = "yellow"
	elif score >= 40:
		score_color = "orange"

	photo_info_label.append_text("[color=%s]SCORE: %d/100[/color]\n\n" % [score_color, int(score)])

	# Display photo info
	photo_info_label.append_text("Photo Info:\n")
	photo_info_label.append_text("FOV: %.1f\n" % fov)

	if detected_objects.is_empty():
		photo_info_label.append_text("[color=gray]No subjects in frame[/color]\n")
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
			print("[MAIN] - Captured: %s (%.1fm away)" % [obj_data.name, obj_data.distance])

		# Display counts on same line
		var count_text: String = ""
		for obj_type in object_counts.keys():
			if count_text != "":
				count_text += " "
			count_text += "x%d %s" % [object_counts[obj_type], obj_type]

		photo_info_label.append_text("[color=green]%s[/color]\n" % count_text)

		# Display score breakdown
		photo_info_label.append_text("\nScore Breakdown:\n")
		photo_info_label.append_text("  Subjects: %.0f/50\n" % breakdown.get("subjects", 0))
		photo_info_label.append_text("  Zoom: %.0f/30\n" % breakdown.get("zoom", 0))
		photo_info_label.append_text("  Centering: %.0f/20\n" % breakdown.get("centering", 0))

	print("[MAIN] Photo score: %d/100" % int(score))
