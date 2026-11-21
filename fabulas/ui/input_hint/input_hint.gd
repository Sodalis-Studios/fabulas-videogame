extends Label
class_name InputHint

## Label with the controls of a menu: shows one text or the other depending on
## whether the player is using the keyboard or a controller.

@export_multiline var keyboard_text := ""
@export_multiline var controller_text := ""


func _ready() -> void:
	InputDevice.changed.connect(_update_text)
	_update_text(InputDevice.using_controller)


func _update_text(using_controller: bool) -> void:
	text = controller_text if using_controller else keyboard_text
