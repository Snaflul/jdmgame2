extends ProgressBar

@export var max_stam: int = 100
var current_stam: float = max_stam

@export var regen_delay: float = 1.0  # Time to wait before regenerating
@export var regen_rate: float = 15.0 # Stamina per second

var time_since_use: float = 0.0
var used_stamina: bool = false

func _ready():
	update_bar()

func _process(delta):
	if current_stam < max_stam:
		if used_stamina:
			time_since_use += delta
			if time_since_use >= regen_delay:
				used_stamina = false  # Done waiting, start regenerating
		else:
			current_stam += regen_rate * delta
			current_stam = min(current_stam, max_stam)
			update_bar()

func stam_used(amount: float):
	current_stam = max(current_stam - amount, 0)
	used_stamina = true
	time_since_use = 0.0  # Reset regen delay timer
	update_bar()

func update_bar():
	value = current_stam
