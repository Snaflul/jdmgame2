extends CharacterBody3D

const SPEED = 20
const JUMP_VELOCITY = 5
const ACCELERATION = 10
const AIR_CONTROL = 0.3
const SENSITIVITY = .001
const DODGE_SPEED = 16      # Reduced speed for a snappy dodge
const DODGE_TIME = 0.18     # Shorter duration
const DODGE_COOLDOWN = 0.5

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
@onready var head = $Head
@onready var camera = $Head/Camera3D
@onready var mesh = $MeshInstance3D # Change if your model node has a different name

var rotating_camera := false
var dodge_timer := 0.0
var dodge_cooldown := 0.0
var dodge_direction := Vector3.ZERO
var is_dodging := false

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _unhandled_input(event):
	if event is InputEventMouseButton:
		if event.button_index == 2:
			rotating_camera = event.pressed

	if event is InputEventMouseMotion and rotating_camera:
		head.rotate_y(-event.relative.x * SENSITIVITY)
		camera.rotate_x(-event.relative.y * SENSITIVITY)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-40), deg_to_rad(60))

func _physics_process(delta):
	# Update timers
	if is_dodging:
		dodge_timer -= delta
		if dodge_timer <= 0.0:
			is_dodging = false
			dodge_cooldown = DODGE_COOLDOWN
			# Stop the dodge, allow mesh to fully rotate to movement direction
	elif dodge_cooldown > 0.0:
		dodge_cooldown -= delta

	# Dodge input
	if Input.is_action_just_pressed("dodge") and is_on_floor() and not is_dodging and dodge_cooldown <= 0.0:
		var input_dir = Input.get_vector("move_left", "move_right", "move_back", "move_forward")
		var forward_dir = -camera.global_transform.basis.z
		var right_dir = camera.global_transform.basis.x
		dodge_direction = (forward_dir * input_dir.y + right_dir * input_dir.x).normalized()
		if dodge_direction == Vector3.ZERO:
			dodge_direction = -camera.global_transform.basis.z.normalized() # Default forward
		dodge_timer = DODGE_TIME
		is_dodging = true

		# Rotate mesh to face dodge direction (Y axis only)
		if mesh:
			var target_yaw = atan2(dodge_direction.x, dodge_direction.z)
			mesh.rotation.y = lerp_angle(mesh.rotation.y, target_yaw, 0.5)
	
	# Movement
	if is_dodging:
		velocity.x = dodge_direction.x * DODGE_SPEED
		velocity.z = dodge_direction.z * DODGE_SPEED
		velocity.y = 0 # Optional: keep on ground
		# Snap model rotation to dodge direction
		if mesh:
			var target_yaw = atan2(dodge_direction.x, dodge_direction.z)
			mesh.rotation.y = lerp_angle(mesh.rotation.y, target_yaw, 0.35)
	else:
		if not is_on_floor():
			velocity.y -= gravity * delta

		if Input.is_action_just_pressed("move_jump") and is_on_floor():
			velocity.y = JUMP_VELOCITY

		var input_dir = Input.get_vector("move_left", "move_right", "move_back", "move_forward")
		var forward_dir = -camera.global_transform.basis.z
		var right_dir = camera.global_transform.basis.x
		var direction = (forward_dir * input_dir.y + right_dir * input_dir.x).normalized()

		var accel = ACCELERATION if is_on_floor() else ACCELERATION * AIR_CONTROL
		var target_vel = direction * SPEED

		velocity.x = move_toward(velocity.x, target_vel.x, accel * delta)
		velocity.z = move_toward(velocity.z, target_vel.z, accel * delta)

		# Face mesh in movement direction if moving and not dodging
		if mesh and direction != Vector3.ZERO:
			var target_yaw = atan2(direction.x, direction.z)
			mesh.rotation.y = lerp_angle(mesh.rotation.y, target_yaw, 0.12)

	move_and_slide()
