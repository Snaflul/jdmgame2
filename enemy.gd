extends CharacterBody3D

@export var move_speed: float = 4.0
@export var attack_range: float = 1.5
@onready var navigation_agent: NavigationAgent3D = $NavigationAgent3D
@onready var health_bar = get_node("../CanvasLayer/HealthBar")

var health = 80
var player: CharacterBody3D = null
var attack_cooldown: float = 1.0  # seconds
var attack_timer: float = 0.0


func _ready() -> void:
	player = $"../CharacterBody3D"

func _physics_process(delta: float) -> void:
	if player == null:
		return

	navigation_agent.set_target_position(player.global_position)
	var next_position: Vector3 = navigation_agent.get_next_path_position()
	
	var distance_to_player = global_position.distance_to(player.global_position)

	attack_timer += delta  # increment cooldown timer

	if distance_to_player <= attack_range:
		velocity = Vector3.ZERO
		move_and_slide()
		
		if attack_timer >= attack_cooldown:
			attack_player()
			attack_timer = 0.0
	else:
		if navigation_agent.is_navigation_finished():
			velocity = Vector3.ZERO
			move_and_slide()
			return

		velocity = global_position.direction_to(next_position) * move_speed
		move_and_slide()

	# Look at the player (optional, or look at next_position)
	var my_pos = global_transform.origin
	var target_y = Vector3(player.global_position.x, my_pos.y, player.global_position.z)
	look_at(target_y, Vector3.UP)
	rotate_y(deg_to_rad(180))

func attack_player():
	health_bar.take_damage(20)
	
	if is_equal_approx(health_bar.current_health, 0):
		print("bro's dead LOL")
