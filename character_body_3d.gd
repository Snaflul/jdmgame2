extends CharacterBody3D

const SPEED = 5.8
const JUMP_VELOCITY = 5
const SENSITIVITY = 0.002
const DODGE_SPEED = 13
const DODGE_TIME = 0.27
const DODGE_COOLDOWN = 0.5
const AIR_CONTROL = 0.06
const SPRINT_MULTIPLIER = 1.5
const BASE_FOV = 70.0
const SPRINT_FOV = 85.0
const FOV_LERP_SPEED = 12.0
const SPRINT_DODGE_MULTIPLIER = 1.35 # Sprinting makes dodge 35% further

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var stam_bar = get_node("/root/root/CanvasLayer/StamBar")


@onready var head = $Head
@onready var camera = $Head/Camera3D
@onready var body = $body

var dodge_timer := 0.0
var dodge_cooldown := 0.0
var dodge_direction := Vector3.ZERO
var is_dodging := false

var in_air := false
var locked_air_velocity := Vector3.ZERO

var current_dodge_speed := DODGE_SPEED
var current_dodge_time := DODGE_TIME
var far_dodge := false

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	camera.fov = BASE_FOV

func _unhandled_input(event):
	if event is InputEventMouseMotion:
		head.rotate_y(-event.relative.x * SENSITIVITY)
		camera.rotate_x(-event.relative.y * SENSITIVITY)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-40), deg_to_rad(60))

func _physics_process(delta):
	var sprinting = Input.is_action_pressed("sprint") and not is_dodging and is_on_floor() and stam_bar.current_stam > 0
	var current_speed = SPEED * (SPRINT_MULTIPLIER if sprinting else 1.0)

	# FOV: If sprinting OR in a far dodge, use SPRINT_FOV
	var desired_fov = (SPRINT_FOV if sprinting or far_dodge else BASE_FOV)
	camera.fov = lerp(camera.fov, desired_fov, FOV_LERP_SPEED * delta)
	
	if(sprinting):
		stam_bar.stam_used(10*delta)

	
	# Timers
	if is_dodging:
		dodge_timer -= delta
		if dodge_timer <= 0.0:
			is_dodging = false
			dodge_cooldown = DODGE_COOLDOWN
			far_dodge = false
	elif dodge_cooldown > 0.0:
		dodge_cooldown -= delta
	
	# Dodge
	if Input.is_action_just_pressed("dodge") and is_on_floor() and not is_dodging and dodge_cooldown <= 0.0 && stam_bar.current_stam >= 10:
		stam_bar.stam_used(10)
		
		var input_dir = Input.get_vector("move_left", "move_right", "move_back", "move_forward")
		var forward_dir = -camera.global_transform.basis.z
		var right_dir = camera.global_transform.basis.x
		dodge_direction = (forward_dir * input_dir.y + right_dir * input_dir.x).normalized()
		
		
		if dodge_direction == Vector3.ZERO:
			dodge_direction = -camera.global_transform.basis.z.normalized()

		# Determine dodge distance based on sprinting
		if Input.is_action_pressed("sprint"):
			current_dodge_speed = DODGE_SPEED * SPRINT_DODGE_MULTIPLIER
			current_dodge_time = DODGE_TIME * SPRINT_DODGE_MULTIPLIER
			far_dodge = true
		else:
			current_dodge_speed = DODGE_SPEED
			current_dodge_time = DODGE_TIME
			far_dodge = false

		dodge_timer = current_dodge_time
		is_dodging = true
		body.rotation.y = atan2(dodge_direction.x, dodge_direction.z)

	# Main movement and velocity logic
	if is_dodging:
		velocity.x = dodge_direction.x * current_dodge_speed
		velocity.z = dodge_direction.z * current_dodge_speed
		velocity.y = 0  # stay grounded
	elif not is_on_floor():
		# In air: allow a tiny bit of air control
		if not in_air:
			in_air = true
			locked_air_velocity.x = velocity.x
			locked_air_velocity.z = velocity.z
		velocity.y -= gravity * delta

		var input_dir = Input.get_vector("move_left", "move_right", "move_back", "move_forward")
		var forward_dir = -camera.global_transform.basis.z
		var right_dir = camera.global_transform.basis.x
		var air_direction = (forward_dir * input_dir.y + right_dir * input_dir.x).normalized()

		if air_direction != Vector3.ZERO:
			velocity.x = lerp(velocity.x, air_direction.x * current_speed, AIR_CONTROL)
			velocity.z = lerp(velocity.z, air_direction.z * current_speed, AIR_CONTROL)
			body.rotation.y = atan2(velocity.x, velocity.z)
	else:
		in_air = false
		if Input.is_action_just_pressed("move_jump") && stam_bar.current_stam >= 10:
			stam_bar.stam_used(10)
			velocity.y = JUMP_VELOCITY
			locked_air_velocity.x = velocity.x
			locked_air_velocity.z = velocity.z
		var input_dir = Input.get_vector("move_left", "move_right", "move_back", "move_forward")
		var forward_dir = -camera.global_transform.basis.z
		var right_dir = camera.global_transform.basis.x
		var direction = (forward_dir * input_dir.y + right_dir * input_dir.x).normalized()

		if direction != Vector3.ZERO:
			velocity.x = direction.x * current_speed
			velocity.z = direction.z * current_speed
			body.rotation.y = atan2(direction.x, direction.z)
		else:
			velocity.x = 0
			velocity.z = 0

	move_and_slide()
