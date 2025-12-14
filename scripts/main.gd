extends Node3D

@onready var player: Player = $"Player"
@onready var camera: Camera = $"Camera"
@onready var photos_hud: Node = $"PhotosHUD"
@onready var printer_player: AudioStreamPlayer = $PrinterPlayer
@onready var music_player: AudioStreamPlayer = $AudioStreamPlayer

var is_printing: bool = false
var cancel_printing: bool = false

const MAX_PHOTOS: int = 5


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


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		# Open the photos directory when closing via window X button
		var photos_dir: String = ProjectSettings.globalize_path("user://")
		OS.shell_open(photos_dir)
		await get_tree().create_timer(0.2).timeout
		get_tree().quit()


func _calculate_photo_score(detected_objects: Array[Dictionary], fov: float) -> Dictionary:
	if detected_objects.is_empty():
		return {"score": 0, "breakdown": {}}

	var total_score: float = 0.0
	var breakdown: Dictionary = {}

	# 1. SUBJECT SCORE (0-50 points)
	# Different subjects have different base values
	# Score from least to most: store < person < reindeer < santa
	var subject_score: float = 0.0
	for obj_data in detected_objects:
		var obj_type: String = obj_data.get("type", "unknown")
		match obj_type:
			"santa":
				subject_score += 25.0
			"reindeer":
				subject_score += 15.0
			"person":
				subject_score += 10.0
			"store":
				subject_score += 5.0
			"tree":
				subject_score += 5.0
			_:
				subject_score += 5.0
	subject_score = min(50.0, subject_score)
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
	# Cancel any previous printing
	if is_printing:
		cancel_printing = true
		await get_tree().create_timer(0.1).timeout  # Wait briefly for cancellation

	var photo_info_label: RichTextLabel = player.photo_info_label
	photo_info_label.clear()
	print("[MAIN] Photo taken with FOV: %.1f" % fov)

	# Calculate score
	var score_data: Dictionary = _calculate_photo_score(detected_objects, fov)
	var score: float = score_data.score
	var breakdown: Dictionary = score_data.breakdown

	# Add the photo to the PhotosHUD
	var texture: ImageTexture = ImageTexture.create_from_image(image)
	var is_last_photo: bool = photos_hud.add_photo(texture, int(score), detected_objects)

	# Lower music volume if it's the last photo
	if is_last_photo:
		var tween = create_tween()
		tween.tween_property(music_player, "volume_db", -30.0, 1.0)

	# Initial delay before printing starts
	await get_tree().create_timer(1.0).timeout

	# Print data line by line with delays
	cancel_printing = false
	is_printing = true
	await _print_photo_data_animated(photo_info_label, detected_objects, fov, score, breakdown)
	is_printing = false

	# If this was the last photo, show the final screen after printing
	if is_last_photo:
		# Hide photo info label
		photo_info_label.visible = false

		# Show final screen
		photos_hud.show_final_screen()
	else:
		# Re-enable photo taking after printing is complete
		camera.can_take_photo = true

	print("[MAIN] Photo score: %d/100" % int(score))


func _print_photo_data_animated(
	photo_info_label: RichTextLabel,
	detected_objects: Array[Dictionary],
	fov: float,
	score: float,
	breakdown: Dictionary
) -> void:
	var line_delay: float = 0.5  # Delay between each line
	var pitch_variations: Array[float] = [1.0, 1.1, 0.95, 1.05, 0.9, 1.15, 0.85, 1.2]
	var pitch_index: int = 0

	# Display photo info
	if cancel_printing:
		return
	photo_info_label.append_text("Photo Info:\n")
	printer_player.pitch_scale = pitch_variations[pitch_index % pitch_variations.size()]
	printer_player.play()
	pitch_index += 1
	await get_tree().create_timer(line_delay).timeout

	if cancel_printing:
		return
	photo_info_label.append_text("FOV: %.1f\n" % fov)
	printer_player.pitch_scale = pitch_variations[pitch_index % pitch_variations.size()]
	printer_player.play()
	pitch_index += 1
	await get_tree().create_timer(line_delay).timeout

	if detected_objects.is_empty():
		if cancel_printing:
			return
		photo_info_label.append_text("[color=gray]No subjects in frame[/color]\n")
		printer_player.pitch_scale = pitch_variations[pitch_index % pitch_variations.size()]
		printer_player.play()
		pitch_index += 1
		await get_tree().create_timer(line_delay).timeout
	else:
		# Count objects by type
		var object_counts: Dictionary = {}
		for obj_data in detected_objects:
			var obj_type: String = obj_data.get("type", "unknown")
			if object_counts.has(obj_type):
				object_counts[obj_type] += 1
			else:
				object_counts[obj_type] = 1
			print(
				(
					"[MAIN] - Captured: %s [%s] (%.1fm away)"
					% [obj_data.name, obj_type, obj_data.distance]
				)
			)

		# Display counts on same line
		var count_text: String = ""
		for obj_type in object_counts.keys():
			if count_text != "":
				count_text += " "
			count_text += "x%d %s" % [object_counts[obj_type], obj_type]

		if cancel_printing:
			return
		photo_info_label.append_text("[color=green]%s[/color]\n" % count_text)
		printer_player.pitch_scale = pitch_variations[pitch_index % pitch_variations.size()]
		printer_player.play()
		pitch_index += 1
		await get_tree().create_timer(line_delay).timeout

		# Display score breakdown
		if cancel_printing:
			return
		photo_info_label.append_text("\nScore Breakdown:\n")
		printer_player.pitch_scale = pitch_variations[pitch_index % pitch_variations.size()]
		printer_player.play()
		pitch_index += 1
		await get_tree().create_timer(line_delay).timeout

		if cancel_printing:
			return
		photo_info_label.append_text("  Subjects: %.0f/50\n" % breakdown.get("subjects", 0))
		printer_player.pitch_scale = pitch_variations[pitch_index % pitch_variations.size()]
		printer_player.play()
		pitch_index += 1
		await get_tree().create_timer(line_delay).timeout

		if cancel_printing:
			return
		photo_info_label.append_text("  Zoom: %.0f/30\n" % breakdown.get("zoom", 0))
		printer_player.pitch_scale = pitch_variations[pitch_index % pitch_variations.size()]
		printer_player.play()
		pitch_index += 1
		await get_tree().create_timer(line_delay).timeout

		if cancel_printing:
			return
		photo_info_label.append_text("  Centering: %.0f/20\n" % breakdown.get("centering", 0))
		printer_player.pitch_scale = pitch_variations[pitch_index % pitch_variations.size()]
		printer_player.play()
		pitch_index += 1
		await get_tree().create_timer(line_delay).timeout

	# Display score with color based on quality (at the bottom)
	var score_color: String = "red"
	if score >= 80:
		score_color = "green"
	elif score >= 60:
		score_color = "#B8860B"
	elif score >= 40:
		score_color = "orange"

	if cancel_printing:
		return
	photo_info_label.append_text("\n[color=%s]SCORE: %d/100[/color]\n" % [score_color, int(score)])
	printer_player.pitch_scale = pitch_variations[pitch_index % pitch_variations.size()]
	printer_player.play()
	pitch_index += 1
	await get_tree().create_timer(line_delay).timeout
