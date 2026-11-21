extends "../base_menu/base_menu.gd"

## Cheats for the player and the game.

func _build() -> void:
	add_option("GODFLY", "God Mode", Kind.TOGGLE).toggled.connect(
			func(value: bool) -> void: DebugMenu.god_mode = value)
	var speed_names := PackedStringArray()
	for speed in DebugMenu.GAME_SPEEDS:
		speed_names.append(DebugMenu.speed_text(speed))
	add_option("SPEED", "Game speed", Kind.CHOICE, speed_names).choice_changed.connect(
			func(index: int) -> void: DebugMenu.game_speed = DebugMenu.GAME_SPEEDS[index])
	add_action("CHECKPOINT", "Go to checkpoint", _go_to_checkpoint)
	add_action("RELOAD", "Reload level", _reload_level)
	add_action("KEYS", "Give all keys", _give_all_keys)


func refresh() -> void:
	get_option("GODFLY").set_toggle(DebugMenu.god_mode)
	get_option("SPEED").set_choice(DebugMenu.GAME_SPEEDS.find(DebugMenu.game_speed))
	get_option("CHECKPOINT").hint = "" if _has_checkpoint() else "none"


## Moves the player to the checkpoint of this level, without reloading it.
func _go_to_checkpoint() -> String:
	var player: Player = get_tree().get_first_node_in_group("player")
	if player == null:
		return "No player"
	if not _has_checkpoint():
		return "No checkpoint"
	player.global_position = CheckpointManager.checkpoint_position
	player.velocity = Vector2.ZERO
	return "Done"


## Starts the level again (from the checkpoint, if there's one).
func _reload_level() -> String:
	if get_tree().get_first_node_in_group("player") == null:
		return "Not in a level"
	DebugMenu.go_to_scene(SceneManager.get_current_scene_id())
	return ""


## Same as picking up every key (the HUD and the maze listen to it).
func _give_all_keys() -> String:
	SignalBus.blue_key_take.emit()
	SignalBus.white_key_take.emit()
	SignalBus.purple_key_take.emit()
	return "Done"


func _has_checkpoint() -> bool:
	return CheckpointManager.checkpoint_active \
			and CheckpointManager.current_scene == SceneManager.get_current_scene_id()
