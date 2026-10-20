class_name FastTrail extends Line2D

## Self-contained speed trail. Watches its own parent Player and decides
## entirely on its own when to grow and when to fade — nothing outside this
## script needs to know it exists.

# ====================== CONSTANTS ======================
## Multiplier over the theoretical max Y velocity of a normal jump, so the
## trail only activates when something (like a LaunchPlatform boost) pushes
## velocity meaningfully above what regular movement can reach.
const TRAIL_ACTIVATION_MARGIN: float = 1.2

# ====================== EXPORTED VARIABLES ======================
@export var max_points: int = 20
## How many points per second are trimmed off while fading out. Higher = faster fade.
@export var fade_rate: float = 60.0

# ====================== REFERENCE VARIABLES ======================
@onready var player: Player = get_parent()

# ====================== LOCAL VARIABLES ======================
var _is_active: bool = false
var _current_max_points: float = 0.0

# *********************** BUILT IN CALLBACKS **********************
func _ready() -> void:
	top_level = true
	points = PackedVector2Array()

func _physics_process(delta: float) -> void:
	var trail_threshold: float = player.player_movement_stats.jump_force * TRAIL_ACTIVATION_MARGIN
	# Apex = the frame where velocity.y flips from negative (rising) to
	# non-negative (falling). More reliable than comparing against ~0,
	# since gravity can skip straight past a near-zero value in one step.
	var reached_apex: bool = player.velocity.y >= 0.0
	
	if not _is_active and player.velocity.y < trail_threshold:
		_is_active = true
	elif _is_active and reached_apex:
		_is_active = false
	
	# The head always tracks the Player, active or not — only the target
	# length changes. While active it's pinned at max_points; while fading
	# it decays toward 0 over time, so the trail "eats itself" from the
	# tail while the head keeps riding along with the Player instead of
	# being left behind at a frozen position.
	if _is_active:
		_current_max_points = max_points
	else:
		_current_max_points = max(_current_max_points - fade_rate * delta, 0.0)
	
	_insert_point(player.global_position, int(_current_max_points))
	
# ******************* PRIVATE FUNCTIONS *******************
func _insert_point(pos: Vector2, max_count: int) -> void:
	var updated_points := points
	updated_points.insert(0, pos)
	if updated_points.size() > max_count:
		updated_points.resize(max_count)
	points = updated_points
