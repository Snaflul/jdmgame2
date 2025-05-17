extends CharacterBody3D

@onready var nav = $NavigationAgent3D

var speed = 3.5

func _physics_process(delta):
	if nav == null or nav.is_navigation_finished():
		velocity = Vector3.ZERO
		move_and_slide()
		return

	var next_location = nav.get_next_path_position()
	var direction = (next_location - global_transform.origin).normalized()
	direction.y = 0  # Stay grounded

	velocity = direction * speed
	look_at(next_location, Vector3.UP)
	move_and_slide()

func set_target_position(target_pos: Vector3):
	if nav:
		nav.target_position = target_pos
