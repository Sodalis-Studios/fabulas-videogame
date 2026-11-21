extends Node2D

## Last checkpoint touched in the current game. It's stored in the save slot
## being played (see SaveManager), which also fills it when a game is loaded.

var current_scene: SceneManager.SceneID
var checkpoint_active: bool = false
var checkpoint_position: Vector2

func _ready() -> void:
	SignalBus.checkpoint_activated.connect(_on_checkpoint_activated)


func _on_checkpoint_activated( position_checkpoint: Vector2):

	checkpoint_position = position_checkpoint
	checkpoint_active = true
	current_scene = SceneManager.get_current_scene_id()

	SaveManager.save_game()


func clear_checkpoint() -> void:
	checkpoint_active = false
	checkpoint_position = Vector2.ZERO
	current_scene = SceneManager.SceneID.MAIN_MENU
