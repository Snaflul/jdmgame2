extends ProgressBar

@export var max_health: int = 100
var current_health: int = max_health

func _ready():
	update_bar()

func update_bar():
	value = current_health

func take_damage(amount: int):
	current_health = max(current_health - amount, 0)
	update_bar()
	
	
	
