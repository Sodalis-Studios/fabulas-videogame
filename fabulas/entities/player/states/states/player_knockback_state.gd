class_name PlayerKnockbackState
extends PlayerStateBase

# ====================== EXPORT VARIABLES ======================
@export_category("Ragdoll Physics")
## How much energy is kept after a bounce (0.0 to 1.0). 0.4 means it loses 60% speed per impact.
@export var bounce_elasticity: float = 0.4
## Multiplier applied to the base fall gravity to make the ragdoll feel heavier.
@export var knockback_gravity_multiplier: float = 1.0
## Friction applied in the air to drastically slow down the initial explosive knockback.
@export var air_drag: float = 2000.0

@export_category("Ragdoll Behaviour")
## Time in seconds before the player regains control mid-air.
@export var knockback_duration: float = 1.0
## The minimum speed required to keep bouncing. Below this, the player recovers control.
@export var minimum_bounce_velocity: float = 100.0
## How much the player can steer their trajectory while in ragdoll.
@export var air_control_acceleration: float = 1500.0

@export_category("Game Feel & Juicy")
## How long the game freezes when the player takes a hit.
@export var freeze_frame_duration: float = 0.1
## How much the game slows down during the freeze frame.
@export var time_scale_during_freeze_frame: float = 0.3
## How much the player squashes when taking a hit.
@export var squash_scale: Vector2 = Vector2(1.5, 0.75)
## How long the squash effect lasts before returning to normal.
@export var squash_duration: float = 0.4

# ====================== LOCAL VARIABLES ======================
var knockback_tween: Tween
var blink_tween: Tween
var knockback_velocity_x: float = 0.0
var player_velocity_x: float = 0.0

# *********************** STATE MACHINE CALLBACKS **********************
func start() -> void:
	SignalBus.player_hit.emit()

	# Player uncontrolled/falling animation
	player.play_animation(PlayerAnimations.FALL) # TODO: Replace with ragdoll animation

	knockback_velocity_x = player.velocity.x
	player_velocity_x = 0.0

	# Adjust knockback particles direction based on the horizontal knockback velocity
	if knockback_velocity_x != 0:
		var dir: float = -sign(knockback_velocity_x)
		player.knockback_particles.process_material.direction = Vector3(dir, -0.5, 0.0)

	# Emit knockback particles
	player.knockback_particles.restart()

	# Applay squash and stretch effect for juicy feedback
	_apply_squash_and_stretch()
	
	# Start the knockback timer and blinking effect
	_start_knockback_timer()
	_start_blinking_effect()

	# Apply freeze frame if possible
	if freeze_frame_duration > 0.0:
		_apply_freeze_frame()

	# Request camera shake
	SignalBus.camera_shake_request.emit(0.45)

func on_physics_process(delta: float) -> void:
	# Custom handling gravity
	var current_gravity: float = player.player_movement_stats.jump_gravity
	if player.velocity.y > 0:
		current_gravity = player.player_movement_stats.fall_gravity * knockback_gravity_multiplier
		
	# Apex Hang Time: If velocity is close to 0 on the Y axis, halve the gravity for a floaty apex
	if abs(player.velocity.y) < 150.0:
		current_gravity *= 0.5
		
	player.velocity.y += current_gravity * delta

	# Directional Influence (DI)
	# Applied after drag so the player can still steer slightly
	if direction != 0:
		player_velocity_x += direction * air_control_acceleration * delta
	else:
		player_velocity_x = move_toward(player_velocity_x, 0.0, (air_control_acceleration * 0.5) * delta)

	knockback_velocity_x = move_toward(knockback_velocity_x, 0.0, air_drag * delta)

	player.velocity.x = knockback_velocity_x + player_velocity_x

	# Ragdoll visual juice
	player.animated_sprite_2d.rotation += player.velocity.x * delta * 0.01
	
	# Pure Physics Movement
	var collision: KinematicCollision2D = player.move_and_collide(player.velocity * delta)
	
	# Bounce & Exit Conditions
	if collision:
		var normal: Vector2 = collision.get_normal()
			
		# Wall/Ceiling Bounce: Apply mathematical reflection directly to velocity
		player.velocity = player.velocity.bounce(normal) * bounce_elasticity

		_apply_squash_and_stretch()

		knockback_velocity_x = player.velocity.x
		player_velocity_x = 0.0

		# Low Energy Tech (Exit Condition C): Recover if the bounce left us with no momentum
		if player.velocity.length() < minimum_bounce_velocity:
			player.velocity.x = 0.0 # Stabilize horizontal movement before returning control
			_exit_knockback()

func end() -> void:
	# Reset rotation to 0 when exiting knockback
	player.animated_sprite_2d.rotation = 0.0
	player.animated_sprite_2d.scale = Vector2.ONE

	# Clean up knockback tween
	if knockback_tween and knockback_tween.is_valid():
		knockback_tween.kill()
		
	# Clean up blinking tween
	if blink_tween and blink_tween.is_valid():
		blink_tween.kill()
		
	if player.animated_sprite_2d.material:
		player.animated_sprite_2d.material.set_shader_parameter("flash_modifier", 0.0)

	Engine.time_scale = DebugMenu.game_speed

# ******************* PRIVATE METHODS *******************
func _start_knockback_timer() -> void:
	if knockback_tween and knockback_tween.is_valid():
		knockback_tween.kill()
		
	knockback_tween = create_tween()
	knockback_tween.tween_callback(_exit_knockback).set_delay(knockback_duration)

func _start_blinking_effect() -> void:
	if blink_tween and blink_tween.is_valid():
		blink_tween.kill()
		
	blink_tween = create_tween()
	blink_tween.set_loops()
	
	var sprite_material: Material = player.animated_sprite_2d.material
	if sprite_material:
		blink_tween.tween_property(sprite_material, "shader_parameter/flash_modifier", 1.0, 0.15)
		blink_tween.tween_property(sprite_material, "shader_parameter/flash_modifier", 0.0, 0.15)

func _apply_freeze_frame() -> void:
	Engine.time_scale = time_scale_during_freeze_frame * DebugMenu.game_speed
	
	var timer: SceneTreeTimer = get_tree().create_timer(freeze_frame_duration, true, false, true)

	timer.timeout.connect(func(): Engine.time_scale = DebugMenu.game_speed)

func _apply_squash_and_stretch() -> void:
	player.animated_sprite_2d.scale = squash_scale
	
	var squash_tween: Tween = create_tween()
	squash_tween.bind_node(player.animated_sprite_2d)
	
	squash_tween.set_trans(Tween.TRANS_ELASTIC)
	squash_tween.set_ease(Tween.EASE_OUT)
	
	squash_tween.tween_property(player.animated_sprite_2d, "scale", Vector2.ONE, squash_duration)

func _exit_knockback() -> void:
	state_machine.change_state(PlayerStatesNames.FALLING)
