class_name Player
extends CharacterBody2D

## Main Player controller script

# ====================== REFERENCE VARIABLES ======================
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var state_machine: StateMachine = $StateMachine
@onready var coyote_timer: Timer = $Timers/CoyoteTimer
@onready var jump_buffer_timer: Timer = $Timers/JumpBufferTimer
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var knockback_particles: GPUParticles2D = $KnockbackParticles

# ====================== RESOURCES ======================
@export var player_movement_stats: PlayerMovementStats

# ====================== LOCAL VARIABLES ======================
var is_god_mode: bool = false
var boost_velocity: Vector2 = Vector2.ZERO
## Tiempo restante para poder hacer ledge hop (se activa en el punto más alto del salto)
var ledge_hop_time_left: float = 0.0

# *********************** BUILT IN CALLBACKS **********************
func _ready() -> void:
	add_to_group("player")
	hurtbox.took_knockback.connect(_on_hurtbox_took_knockback)
	if (CheckpointManager.checkpoint_active and SceneManager.get_current_scene_id() == CheckpointManager.current_scene):
		global_position = CheckpointManager.checkpoint_position
		TransitionsScreen.fade_in()
		
# ******************* LOCAL FUNCTIONS *******************	
func play_animation(animation_name: String) -> void:
	animated_sprite_2d.play(animation_name)

func handle_animation(direction: float) -> void:
	if direction < 0:
		animated_sprite_2d.flip_h = true
	elif direction > 0:
		animated_sprite_2d.flip_h = false

func get_current_gravity() -> float:
	if velocity.y > 0:
		return player_movement_stats.fall_gravity
	return player_movement_stats.jump_gravity

func received_knockback(knockback_dir: Vector2) -> void:
	if is_god_mode or DebugMenu.god_mode:
		return
	
	velocity = knockback_dir

	state_machine.change_state(PlayerStatesNames.KNOCKBACK)

func toggle_god_mode() -> void:
	is_god_mode = !is_god_mode
	if is_god_mode:
		state_machine.change_state(PlayerStatesNames.GODFLY)
	else:
		state_machine.change_state(PlayerStatesNames.FALLING)
		
func print_debug(variables: Array) -> void:
	for i in variables:
		print(i)
		


func try_ledge_hop(direction: float) -> bool:
	# Only if it's inside the hop window
	if ledge_hop_time_left <= 0.0:
		return false
	# is touching towards the wall
	if direction == 0 or not is_on_wall_only():
		return false
	# Only if it's pushing towards the wall
	if signf(get_wall_normal().x) == signf(direction):
		return false

	var stats := player_movement_stats
	# forward is 2 pixels towards where it's going
	var forward := Vector2(signf(direction) * 2.0, 0)

	# looks for the corner
	for h in range(1, int(stats.ledge_hop_max_height) + 1):
		var up := Vector2(0, -h)
		
		# Simulates the movement and checks if it collides or not
		if test_move(global_transform, up):
			return false 
			
		# simulates the movement and two pixels forward
		if not test_move(global_transform.translated(up), forward):
			
			# Velocity to rise h px: v = √(2·g·h). The margin makes up for the height lost in the physics steps.
			var hop_velocity := -sqrt(2.0 * stats.jump_gravity * (h + stats.ledge_hop_margin))
			# Only if it's not already rising faster than that
			if velocity.y > hop_velocity:
				velocity.y = hop_velocity
				ledge_hop_time_left = 0.0  # Only does it once per jump
				return true
			return false
	return false
# ******************* SIGNALS CALLBACKS *******************
func _on_hurtbox_took_knockback(knockback_dir: Vector2) -> void:
	received_knockback(knockback_dir)



var _last_surface: String = "default"

func get_surface() -> String:
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		var layer := collision.get_collider() as TileMapLayer
		if layer == null or collision.get_normal().y > -0.5:
			continue
		if layer.tile_set == null or layer.tile_set.get_custom_data_layer_by_name("surface") == -1:
			continue
		var point := collision.get_position() - collision.get_normal()
		var cell := layer.local_to_map(layer.to_local(point))
		var data := layer.get_cell_tile_data(cell)
		if data:
			var surface = data.get_custom_data("surface")
			if surface is String and surface != "":
				_last_surface = surface
				return surface
	# Sin colisión de suelo en este frame: usa la última superficie conocida
	return _last_surface
