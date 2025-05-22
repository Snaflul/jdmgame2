extends CharacterBody3D

# === Constants ===
const WALK_SPEED := 2.5
const SPRINT_SPEED := 5.5
const ACCEL := 8.0
const DECEL := 10.0
const TURN_SPEED := 6.0
var GRAVITY := 9.8
const JUMP_VELOCITY := 5.5
const ROLL_DURATION := 1.167
const ROLL_SPEED := 6.5
const SPRINT_JUMP_REQUIRED_TIME := 1.0

# === Node Paths ===
@onready var anim_tree: AnimationTree = $AnimationTree
@onready var anim_state: AnimationNodeStateMachinePlayback = anim_tree.get("parameters/playback")
@onready var mesh: Node3D = $mesh/playermodel
@onready var cam_pivot: Node3D = $CameraPivot
@onready var cam: Camera3D = $CameraPivot/Camera3D

# === State Tracking ===
enum PlayerState { IDLE, WALK, SPRINT, ROLL, JUMP }
var state: PlayerState = PlayerState.IDLE

var move_input := Vector2.ZERO
var move_dir := Vector3.ZERO
var locked_dir := Vector3.ZERO

var sprinting := false
var sprint_time := 0.0
var can_jump := false
var roll_timer := 0.0
var jumping := false
var jump_locked_velocity := Vector3.ZERO

# === Camera Orbit State ===
var cam_yaw := 0.0     # Horizontal angle (degrees)
var cam_pitch := 20.0  # Vertical angle (degrees, limited)
var cam_distance := 3.0
var cam_height := 1.5
var cam_follow_speed := 8.0
var mouse_sensitivity := 0.12

# Camera centering timer
var center_camera_timer := 0.0
var center_camera_wait := 1.0 # seconds to wait before recentering camera behind player

func _ready():
	GRAVITY = ProjectSettings.get_setting("physics/3d/default_gravity")
	anim_tree.active = true
	anim_state.travel("Idle")
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _input(event):
	if event is InputEventMouseMotion:
		cam_yaw -= event.relative.x * mouse_sensitivity
		cam_pitch -= event.relative.y * mouse_sensitivity
		cam_pitch = clamp(cam_pitch, -35, 65)
		if cam_yaw > 360.0: cam_yaw -= 360.0
		elif cam_yaw < -360.0: cam_yaw += 360.0
		center_camera_timer = 0.0 # Reset timer on any mouse move
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _physics_process(delta):
	handle_input()
	handle_state_machine(delta)
	handle_camera_orbit(delta)
	update_animation_state()

func handle_input():
	move_input = Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_back") - Input.get_action_strength("move_forward")
	)
	move_input = move_input.normalized()

	# --- FIX: Reverse the forward vector logic ---
	if move_input.length() > 0.1:
		var yaw_rad = deg_to_rad(cam_yaw)
		var cam_forward = Vector3(sin(yaw_rad), 0, cos(yaw_rad)).normalized()
		var cam_right = Vector3(cos(yaw_rad), 0, -sin(yaw_rad)).normalized()
		move_dir = (cam_right * move_input.x + cam_forward * move_input.y).normalized()
		center_camera_timer = 0.0 # Reset timer if moving
	else:
		move_dir = Vector3.ZERO

func handle_state_machine(delta):
	match state:
		PlayerState.IDLE, PlayerState.WALK, PlayerState.SPRINT:
			handle_grounded_states(delta)
		PlayerState.JUMP:
			handle_jump_state(delta)
		PlayerState.ROLL:
			handle_roll_state(delta)

func handle_grounded_states(delta):
	var wants_sprint = Input.is_action_pressed("move_sprint") and move_input.length() > 0.1
	if wants_sprint:
		sprinting = true
		sprint_time += delta
	else:
		sprinting = false
		sprint_time = 0.0

	can_jump = sprinting and sprint_time >= SPRINT_JUMP_REQUIRED_TIME

	var roll_pressed = Input.is_action_just_pressed("move_roll")
	var jump_eligible = can_jump and roll_pressed

	if jump_eligible:
		state = PlayerState.JUMP
		jumping = true
		anim_state.travel("Jump")
		jump_locked_velocity = move_dir * SPRINT_SPEED
		velocity = jump_locked_velocity + Vector3.UP * JUMP_VELOCITY
		return
	elif roll_pressed:
		state = PlayerState.ROLL
		roll_timer = 0.0
		anim_state.travel("Roll")
		locked_dir = move_dir if move_dir.length() > 0.1 else -global_transform.basis.z
		return

	var target_speed = WALK_SPEED
	if sprinting:
		target_speed = SPRINT_SPEED
	elif move_input.length() < 0.1:
		target_speed = 0.0

	var current_speed = velocity.length()
	var speed_diff = target_speed - current_speed
	var accel = ACCEL if speed_diff > 0 else DECEL
	var step_speed = clamp(current_speed + accel * delta * sign(speed_diff), 0, target_speed)
	if target_speed > 0.0:
		velocity = move_dir * step_speed
	else:
		velocity = velocity.move_toward(Vector3.ZERO, DECEL * delta)

	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0.0

	# --- FIX: Only rotate player when moving ---
	if move_dir.length() > 0.1:
		var target_rot = global_transform.basis.get_euler().y
		var desired_rot = atan2(-move_dir.x, -move_dir.z)
		var new_yaw = lerp_angle(target_rot, desired_rot, TURN_SPEED * delta)
		rotation.y = new_yaw

	self.velocity = velocity
	move_and_slide()

	# --- FIX: State transitions ---
	if state == PlayerState.ROLL or state == PlayerState.JUMP:
		return # Don't change state if rolling or jumping
	if move_input.length() < 0.1:
		state = PlayerState.IDLE
	elif sprinting:
		state = PlayerState.SPRINT
	else:
		state = PlayerState.WALK

func handle_jump_state(delta):
	velocity.y -= GRAVITY * delta
	velocity.x = jump_locked_velocity.x
	velocity.z = jump_locked_velocity.z

	self.velocity = velocity
	move_and_slide()

	if is_on_floor():
		jumping = false
		state = PlayerState.IDLE
		anim_state.travel("Idle")

func handle_roll_state(delta):
	roll_timer += delta
	if roll_timer < ROLL_DURATION:
		var roll_velocity = locked_dir * ROLL_SPEED
		velocity.x = roll_velocity.x
		velocity.z = roll_velocity.z
		velocity.y -= GRAVITY * delta
		self.velocity = velocity
		move_and_slide()
	else:
		state = PlayerState.IDLE if move_input.length() < 0.1 else PlayerState.WALK
		anim_state.travel("Idle" if state == PlayerState.IDLE else "Walk")

func handle_camera_orbit(delta):
	# CameraPivot follows player smoothly
	var pivot_target = global_transform.origin
	cam_pivot.global_transform.origin = cam_pivot.global_transform.origin.lerp(pivot_target, clamp(cam_follow_speed * delta, 0, 1))
	
	# --- Camera orbit doesn't follow player rotation immediately ---
	# Only recenter camera if not moving for a certain time
	if move_input.length() < 0.1 and state == PlayerState.IDLE:
		center_camera_timer += delta
		if center_camera_timer > center_camera_wait:
			# Slowly rotate camera behind player
			var target_yaw = rad_to_deg(global_transform.basis.get_euler().y)
			cam_yaw = lerp_angle(cam_yaw, target_yaw, delta * 1.5)
	else:
		center_camera_timer = 0.0

	# Set orbit rotation
	cam_pivot.rotation_degrees.x = cam_pitch
	cam_pivot.rotation_degrees.y = cam_yaw
	cam_pivot.rotation_degrees.z = 0

	# Camera stays at offset from pivot (set in editor, e.g. (0, cam_height, -cam_distance))
	cam.position = Vector3(0, cam_height, -cam_distance)

func update_animation_state():
	match state:
		PlayerState.IDLE:
			anim_state.travel("Idle")
		PlayerState.WALK:
			anim_state.travel("Walk")
		PlayerState.SPRINT:
			anim_state.travel("Sprint")
		PlayerState.JUMP:
			anim_state.travel("Jump")
		PlayerState.ROLL:
			anim_state.travel("Roll")
