extends CharacterBody3D

const SPEED = 2.5
const JUMP_VELOCITY = 5
const SENSITIVITY = 0.002

# Dodge variables
const DODGE_TIME = 1.167
const DODGE_FAST_TIME = 0.2
const DODGE_FAST_SPEED = 13.0
const DODGE_SLOW_SPEED = 2.5
const DODGE_COOLDOWN = 1.25

const AIR_CONTROL = 0.03
const SPRINT_MULTIPLIER = 1.5
const BASE_FOV = 70.0
const SPRINT_FOV = 85.0
const FOV_LERP_SPEED = 12.0

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var stam_bar = get_node("/root/root/CanvasLayer/StamBar")
@onready var health_bar = get_node("/root/root/CanvasLayer/HealthBar")

var target_rotation_y := 0.0
const ROTATION_LERP_SPEED = 10.0

@onready var head = $Head
@onready var camera = $Head/Camera3D
@onready var body = $body
@onready var playermodel = $mesh/playermodel

# AnimationTree references
@onready var animtree = $AnimationTree

var dodge_timer := 0.0
var dodge_cooldown := 0.0
var dodge_direction := Vector3.ZERO
var is_dodging := false
var elapsed_dodge_time := 0.0

var in_air := false
var locked_air_velocity := Vector3.ZERO

# Animation blend variables
var walk_blend := 0.0
const WALK_BLEND_SPEED = 8.0
var sprint_blend := 0.0
const SPRINT_BLEND_SPEED = 8.0
var dodge_blend := 0.0
const DODGE_BLEND_SPEED = 20.0

func _ready():
	# Ensure all relevant animations are looping
	$AnimationPlayer.get_animation("Walk").loop = true
	$AnimationPlayer.get_animation("Idle").loop = true
	$AnimationPlayer.get_animation("Sprint").loop = true
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	camera.fov = BASE_FOV

	if animtree:
		animtree.active = true

func _unhandled_input(event):
	if event is InputEventMouseMotion:
		head.rotate_y(-event.relative.x * SENSITIVITY)
		camera.rotate_x(-event.relative.y * SENSITIVITY)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-40), deg_to_rad(60))

func _physics_process(delta):
	var sprinting = Input.is_action_pressed("sprint") and not is_dodging and is_on_floor() and stam_bar.current_stam > 0
	var current_speed = SPEED * (SPRINT_MULTIPLIER if sprinting else 1.0)

	var desired_fov = (SPRINT_FOV if sprinting else BASE_FOV)
	camera.fov = lerp(camera.fov, desired_fov, FOV_LERP_SPEED * delta)
	
	if sprinting:
		stam_bar.stam_used(10 * delta)

	if is_dodging:
		dodge_timer -= delta
		elapsed_dodge_time += delta
		if dodge_timer <= 0.0:
			is_dodging = false
			dodge_cooldown = DODGE_COOLDOWN
	else:
		elapsed_dodge_time = 0.0
		if dodge_cooldown > 0.0:
			dodge_cooldown -= delta

	# Dodge input (activate dodge)
	if Input.is_action_just_pressed("dodge") and is_on_floor() and not is_dodging and dodge_cooldown <= 0.0 and stam_bar.current_stam >= 10:
		stam_bar.stam_used(10)
		
		var input_dir = Input.get_vector("move_left", "move_right", "move_back", "move_forward")
		var forward_dir = -camera.global_transform.basis.z
		var right_dir = camera.global_transform.basis.x
		dodge_direction = (forward_dir * input_dir.y + right_dir * input_dir.x).normalized()
		if dodge_direction == Vector3.ZERO:
			dodge_direction = -camera.global_transform.basis.z.normalized()

		dodge_timer = DODGE_TIME
		is_dodging = true
		elapsed_dodge_time = 0.0
		target_rotation_y = atan2(dodge_direction.x, dodge_direction.z)

	if is_dodging:
		var speed
		if elapsed_dodge_time < DODGE_FAST_TIME:
			speed = DODGE_FAST_SPEED
		else:
			speed = DODGE_SLOW_SPEED
		velocity.x = dodge_direction.x * speed
		velocity.z = dodge_direction.z * speed
		velocity.y = 0
	elif not is_on_floor():
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
			target_rotation_y = atan2(velocity.x, velocity.z)
	else:
		in_air = false
		if Input.is_action_just_pressed("move_jump") and stam_bar.current_stam >= 10:
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
			target_rotation_y = atan2(direction.x, direction.z)
		else:
			velocity.x = 0
			velocity.z = 0
			
	playermodel.rotation.y = lerp_angle(playermodel.rotation.y, target_rotation_y, ROTATION_LERP_SPEED * delta)

	# --- AnimationTree blend logic (Godot 4.x) ---
	var input_dir = Input.get_vector("move_left", "move_right", "move_back", "move_forward")
	var is_walking = input_dir.length() > 0.01 and is_on_floor() and not is_dodging
	var target_walk_blend = 1.0 if is_walking else 0.0
	walk_blend = lerp(walk_blend, target_walk_blend, WALK_BLEND_SPEED * delta)

	var target_sprint_blend = 1.0 if sprinting else 0.0
	sprint_blend = lerp(sprint_blend, target_sprint_blend, SPRINT_BLEND_SPEED * delta)

	var target_dodge_blend = 1.0 if is_dodging else 0.0
	dodge_blend = lerp(dodge_blend, target_dodge_blend, DODGE_BLEND_SPEED * delta)

	if animtree:
		animtree["parameters/Walk/blend_amount"] = walk_blend
		animtree["parameters/Sprint/blend_amount"] = sprint_blend
		animtree["parameters/Dodge/blend_amount"] = dodge_blend

	move_and_slide()
