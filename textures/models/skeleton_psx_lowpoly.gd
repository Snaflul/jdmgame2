extends Node3D

@onready var nav = $"../NavigationAgent3D"
@onready var target = $"../CharacterBody3D"

var speed = 3.5

func _process(delta):
	if nav == null:
		print("NavigationAgent3D node not found!")
		return

	var next_location = nav.get_next_path_position()
	var direction = (next_location - global_transform.origin).normalized()
	direction.y = 0

	if direction.length() > 0.1:
		look_at(next_location, Vector3.UP)
		translate(direction * speed * delta)

func target_position(target_pos):
	if nav != null:
		nav.target_position = target_pos
	else:
		print("Cannot set target, NavigationAgent3D is null.")
