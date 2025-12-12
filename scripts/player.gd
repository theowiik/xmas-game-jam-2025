extends Sprite2D


func _ready():
	print("Player is ready")


func _physics_process(delta):
	var input_vector = get_input()

	if input_vector == Vector2.ZERO:
		return

	input_vector = input_vector.normalized()
	position += input_vector * 200 * delta


func get_input() -> Vector2:
	var input_vector = Vector2.ZERO

	if Input.is_action_pressed("ui_right"):
		input_vector.x += 1

	if Input.is_action_pressed("ui_left"):
		input_vector.x -= 1

	if Input.is_action_pressed("ui_down"):
		input_vector.y += 1

	if Input.is_action_pressed("ui_up"):
		input_vector.y -= 1

	return input_vector
