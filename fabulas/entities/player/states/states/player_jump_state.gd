extends PlayerStateBase

var has_cut_jump: bool = false

func start() -> void:
	player.play_animation(PlayerAnimations.JUMP)
	SoundManager.play_sfx("Jump")
	
	has_cut_jump = false
	
	player.coyote_timer.stop()
	player.jump_buffer_timer.stop()
	
	player.velocity.y = player.player_movement_stats.jump_force + player.boost_velocity.y

	# _debug_jump_state()
	
	##### This could be needed to consume the boost velocity and avoid bugs in the future #####
	# player.boost_velocity = Vector2.ZERO

func end() -> void:
	has_cut_jump = false

func on_physics_process(delta: float) -> void:
	player.handle_animation(direction)
	player.velocity.x = direction * player.player_movement_stats.speed_air
	
	if not Input.is_action_pressed("jump") and player.velocity.y < 0 and not has_cut_jump:
		player.velocity.y *= player.player_movement_stats.variable_jump_multiplier
		has_cut_jump = true
		
	if player.velocity.y >= 0:
		player.ledge_hop_time_left = player.player_movement_stats.ledge_hop_window
		state_machine.change_state(PlayerStatesNames.FALLING)
	
	super.on_physics_process(delta)

# ******************* DEBUG FUNCTIONS *******************
func _debug_jump_state() -> void:
	var debug_data: Array = [
		"=== JUMP STATE EXECUTED ===",
		"Jump Force Base: %s" % player.player_movement_stats.jump_force,
		"Boost Velocity Y: %s" % player.boost_velocity.y,
		"Final Velocity Y: %s" % player.velocity.y,
		"Is Cut Jump Active: %s" % has_cut_jump,
		"==========================="
	]
	
	player.print_debug(debug_data)
