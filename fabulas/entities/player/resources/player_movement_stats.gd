class_name PlayerMovementStats extends Resource

## Movement configuration for the [Player]

@export_category("Movement")
@export var speed_floor: float = 300.0
@export var speed_air: float = 200.0
@export var jump_force: float = -300.0

@export_category("Gravity")
@export var jump_gravity: float = 980.0
@export var fall_gravity: float = 1400.0

@export_category("Jump")
@export_range(0.0, 1.0, 0.025) var variable_jump_multiplier: float = 0.5

@export_category("Ledge Hop")
## Max pixels the player can fall short of a ledge and still get help
@export var ledge_hop_max_height: float = 20.0
## Extra pixels added to the hop to make up for height lost to physics steps
@export var ledge_hop_margin: float = 3.0
## Seconds after the jump's apex during which the ledge hop is available
@export var ledge_hop_window: float = 0.1
