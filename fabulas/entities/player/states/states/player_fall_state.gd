extends PlayerStateBase

## Landing this many times faster than after a full jump vibrates the
## controller. 1.4 is a fall about twice as high as a jump.
const HARD_LANDING_RATIO := 1.4

## Fastest the player has gone during this fall.
var _fall_speed := 0.0


func start() -> void:
	_fall_speed = 0.0
	player.play_animation(PlayerAnimations.FALL)


func end() -> void:
	player.ledge_hop_time_left = 0.0

func on_physics_process(delta: float) -> void:
	player.handle_animation(direction)

	player.velocity.x = direction * player.player_movement_stats.speed_air

	if player.is_on_floor():
		if _fall_speed >= _hard_landing_speed():
			InputDevice.vibrate(0.35, 0.12)
		if direction == 0:
			state_machine.change_state(PlayerStatesNames.IDLE)
		elif direction != 0:
			state_machine.change_state(PlayerStatesNames.RUNNING)
	else:
		_fall_speed = maxf(_fall_speed, player.velocity.y)

	super.on_physics_process(delta)
	player.try_ledge_hop(direction)
	player.ledge_hop_time_left -= delta

func on_input(event: InputEvent) -> void:
	if event.is_action_pressed("jump") and not player.coyote_timer.is_stopped():
		state_machine.change_state(PlayerStatesNames.JUMPING)
	elif event.is_action_pressed("jump"):
		player.jump_buffer_timer.start()


func _hard_landing_speed() -> float:
	return absf(player.player_movement_stats.jump_force) * HARD_LANDING_RATIO \
			* sqrt(player.player_movement_stats.fall_gravity / player.player_movement_stats.jump_gravity)
