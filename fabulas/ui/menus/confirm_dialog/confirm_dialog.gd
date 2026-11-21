extends Control
class_name ConfirmDialog

## Modal yes/no popup for the menus. Call ask() and listen to `confirmed` or
## `canceled`; the dialog hides itself after either. Esc / B counts as cancel,
## and keyboard/controller focus can't leave the dialog while it is open.

signal confirmed
signal canceled

@onready var _title: Label = %Title
@onready var _message: Label = %Message
@onready var _confirm_button: Button = %ConfirmButton
@onready var _cancel_button: Button = %CancelButton


func _ready() -> void:
	hide()
	_confirm_button.pressed.connect(_answer.bind(true))
	_cancel_button.pressed.connect(_answer.bind(false))
	_trap_focus()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		_answer(false)
	# Swallow everything else too (tab switching, pause...) while open.
	get_viewport().set_input_as_handled()


## Shows the dialog. `focus_confirm` picks which button starts focused; use
## false for destructive actions so a quick double press doesn't confirm.
func ask(title: String, message: String, confirm_text := "Yes", cancel_text := "No",
		focus_confirm := true) -> void:
	_title.text = title
	set_message(message)
	_confirm_button.text = confirm_text
	_cancel_button.text = cancel_text
	show()
	# Deferred so it wins over whatever control takes focus back this frame
	# (e.g. an option popup returning focus to its button).
	GameMenus.focus_quietly.call_deferred(_confirm_button if focus_confirm else _cancel_button)


## Changes the message while the dialog is open (e.g. a countdown).
func set_message(message: String) -> void:
	_message.text = message
	_message.visible = not message.is_empty()


func _answer(accepted: bool) -> void:
	if not visible:
		return
	hide()
	if accepted:
		confirmed.emit()
	else:
		canceled.emit()


func _trap_focus() -> void:
	for button: Button in [_confirm_button, _cancel_button]:
		var other := _cancel_button if button == _confirm_button else _confirm_button
		var own_path := button.get_path()
		button.focus_neighbor_top = own_path
		button.focus_neighbor_bottom = own_path
		button.focus_neighbor_left = other.get_path()
		button.focus_neighbor_right = other.get_path()
		button.focus_next = other.get_path()
		button.focus_previous = other.get_path()
