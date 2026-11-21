extends CanvasLayer

## Small clock in the top left corner with the time played in this game.
## Turned on in Settings > General. It only shows while there's a player on
## screen, so never in the main menu, the cutscenes or during a fade.

@onready var _label: Label = $Time

var _shown_seconds := -1


func _process(_delta: float) -> void:
	visible = SettingsManager.get_value(&"show_play_time") \
			and not TransitionsScreen.color_rect.visible \
			and get_tree().get_first_node_in_group("player") != null
	if not visible:
		return
	var seconds := int(SaveManager.play_time)
	if seconds != _shown_seconds:
		_shown_seconds = seconds
		_label.text = _clock_text(seconds)


## "4:07" or "1:04:07".
func _clock_text(total: int) -> String:
	@warning_ignore("integer_division")
	var hours := total / 3600
	@warning_ignore("integer_division")
	var minutes := (total % 3600) / 60
	if hours > 0:
		return "%d:%02d:%02d" % [hours, minutes, total % 60]
	return "%d:%02d" % [minutes, total % 60]
