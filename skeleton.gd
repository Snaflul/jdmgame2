extends CharacterBody3D

@onready var nav: NavigationAgent3D = $NavigationAgent3D
@export var speed := 3.5
@export var player_path: NodePath  # Drag your player node here in the editor

var player: Node3D

func _ready():
	if has_node(player_path):
		player = get_node(player_path)

func _physics_process(_delta):
	if !player or !nav:
		return

	nav.target_position = player.global_transform.origin

	if nav.is_navigation_finished():
		velocity = Vector3.ZERO
		move_and_slide()
		return

	var next_position = nav.get_next_path_position()
	var direction = (next_position - global_transform.origin).normalized()
	direction.y = 0  # Ignore vertical difference

	velocity = direction * speed

	if not global_transform.origin.is_equal_approx(next_position):
		look_at(next_position, Vector3.UP)

	move_and_slide()
