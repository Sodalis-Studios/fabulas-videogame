extends PlayerStateBase

func start() -> void:
	player.play_animation(PlayerAnimations.FALL)


func end() -> void:
	player.ledge_hop_time_left = 0.0

func on_physics_process(delta: float) -> void:
	player.handle_animation(direction)
	
	player.velocity.x = direction * player.player_movement_stats.speed_air
	
	if player.is_on_floor():
		if direction == 0:
			state_machine.change_state(PlayerStatesNames.IDLE)
		elif direction != 0:
			state_machine.change_state(PlayerStatesNames.RUNNING)
	
	super.on_physics_process(delta)
	player.try_ledge_hop(direction)
	player.ledge_hop_time_left -= delta

func on_input(event: InputEvent) -> void:
	if event.is_action_pressed("jump") and not player.coyote_timer.is_stopped():
		state_machine.change_state(PlayerStatesNames.JUMPING)
	elif event.is_action_pressed("jump"):
		player.jump_buffer_timer.start()
