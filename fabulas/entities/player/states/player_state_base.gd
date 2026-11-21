class_name PlayerStateBase extends StateBase 

## Base class for player movement states

# ====================== LOCAL VARIABLES ======================
var direction: float:
	get:
		return Input.get_axis("move_left", "move_right")

var player: Player:
	set(value):
		controlled_node = value
	get:
		return controlled_node as Player

# ====================== LOCAL FUNCTIONS ======================
func handle_gravity(delta: float) -> void:
	if not player.is_on_floor():
		player.velocity.y += player.get_current_gravity() * delta

func on_physics_process(delta: float) -> void:
	handle_gravity(delta)
	player.move_and_slide()
