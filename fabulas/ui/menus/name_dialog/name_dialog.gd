extends Control
class_name NameDialog

## Popup to write a short name with the keyboard, the controller or the mouse.
## Call ask() and listen to `confirmed` or `canceled`; it hides itself after
## either.
##
## The physical keyboard types directly. The on-screen keys are for the
## controller (and the mouse): the focus stays on them, so both can be mixed.

signal confirmed(text: String)
signal canceled

const KEY_SCENE := preload("res://ui/menus/name_dialog/name_key.tscn")
const CHARACTER_ROWS: Array[String] = [
	"1234567890",
	"ABCDEFGHIJ",
	"KLMNÑOPQRS",
	"TUVWXYZ-.'",
]
const CARET := "_"

@onready var max_length: int = SaveManager.NAME_MAX_LENGTH
@onready var _title: Label = %Title
@onready var _name_label: Label = %NameLabel
@onready var _counter: Label = %Counter
@onready var _character_grid: GridContainer = %CharacterGrid
@onready var _action_row: HBoxContainer = %ActionRow

var _text := ""
var _placeholder := ""
var _upper := true
## Every on-screen key, row by row, for the focus navigation.
var _rows: Array[Array] = []
var _character_keys: Array[Button] = []
var _first_key: Button


func _ready() -> void:
	hide()
	# What the player writes is never translated.
	_name_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_build_keys()
	_link_focus()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey:
		_handle_key(event)
	elif event is InputEventJoypadButton:
		_handle_joypad_button(event)


func _unhandled_input(_event: InputEvent) -> void:
	# Nothing behind reacts while it's open.
	if visible:
		get_viewport().set_input_as_handled()


## Shows the dialog with `current` written. While it's empty it shows
## `placeholder`, which is what an empty name will end up being.
func ask(title: String, current: String, placeholder: String) -> void:
	_title.text = title
	_text = current.left(max_length)
	_placeholder = placeholder
	_set_upper(_text.is_empty())
	_update_name()
	show()
	# Deferred so it wins over whatever takes the focus back this frame.
	GameMenus.focus_quietly.call_deferred(_first_key)


# ******************* INPUT *******************
func _handle_key(event: InputEventKey) -> void:
	# The arrows move the focus through the on-screen keys.
	if event.keycode in [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT]:
		_ensure_focus()
		return
	get_viewport().set_input_as_handled()
	if not event.pressed:
		return
	match event.keycode:
		KEY_ENTER, KEY_KP_ENTER:
			if not event.echo:
				_accept()
		KEY_ESCAPE:
			if not event.echo:
				_cancel()
		KEY_BACKSPACE:
			_delete_last()
		_:
			# AltGr counts as Ctrl+Alt and is needed for some characters.
			var shortcut := event.is_command_or_control_pressed() and not event.alt_pressed
			if event.unicode >= 32 and not shortcut:
				_type(char(event.unicode))


func _handle_joypad_button(event: InputEventJoypadButton) -> void:
	_ensure_focus()
	match event.button_index:
		JOY_BUTTON_B:
			if event.pressed:
				_cancel()
		JOY_BUTTON_START:
			if event.pressed:
				_accept()
		JOY_BUTTON_LEFT_SHOULDER:
			if event.pressed:
				_delete_last()
		JOY_BUTTON_RIGHT_SHOULDER:
			if event.pressed:
				_type(" ")
		_:
			return  # A and the D-pad go to the focused key.
	get_viewport().set_input_as_handled()


## Clicking the background can leave no key selected.
func _ensure_focus() -> void:
	if get_viewport().gui_get_focus_owner() == null:
		GameMenus.focus_quietly(_first_key)


# ******************* TEXT *******************
func _type(character: String) -> void:
	if _text.length() >= max_length:
		return
	# Characters the font can't draw would show as an empty box.
	if not _name_label.get_theme_font("font").has_char(character.unicode_at(0)):
		return
	# No name can start with a space.
	if character == " " and _text.is_empty():
		return
	var was_empty := _text.is_empty()
	_text += character
	# Capital first letter, then lower case, like a phone keyboard.
	if was_empty and _upper:
		_set_upper(false)
	_update_name()


func _delete_last() -> void:
	_text = _text.left(-1)
	if _text.is_empty():
		_set_upper(true)
	_update_name()


func _clear() -> void:
	_text = ""
	_set_upper(true)
	_update_name()


func _set_upper(value: bool) -> void:
	_upper = value
	for key in _character_keys:
		key.text = key.text.to_upper() if value else key.text.to_lower()


func _update_name() -> void:
	var showing_placeholder := _text.is_empty()
	_name_label.text = _placeholder if showing_placeholder else _text + CARET
	_name_label.modulate.a = 0.4 if showing_placeholder else 1.0
	_counter.text = "%d / %d" % [_text.length(), max_length]


func _accept() -> void:
	hide()
	confirmed.emit(SaveManager.clean_name(_text))


func _cancel() -> void:
	hide()
	canceled.emit()


# ******************* KEYS *******************
func _build_keys() -> void:
	for row_text in CHARACTER_ROWS:
		var row: Array[Button] = []
		for character in row_text:
			var key := _add_key(_character_grid, character)
			key.pressed.connect(func() -> void: _type(key.text))
			_character_keys.append(key)
			row.append(key)
		_rows.append(row)
	_first_key = _rows[1][0]

	var actions: Array[Button] = [
		_add_key(_action_row, "Aa", _toggle_case),
		_add_key(_action_row, "Space", _type.bind(" ")),
		_add_key(_action_row, "Delete", _delete_last),
		_add_key(_action_row, "Clear", _clear),
		_add_key(_action_row, "OK", _accept),
	]
	for key in actions:
		key.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.append(actions)


func _add_key(parent: Control, text: String, on_pressed := Callable()) -> Button:
	var key: Button = KEY_SCENE.instantiate()
	key.text = text
	parent.add_child(key)
	if on_pressed.is_valid():
		key.pressed.connect(on_pressed)
	# Hovering selects, like in the other menus.
	key.mouse_entered.connect(func() -> void:
		if not key.has_focus():
			GameMenus.focus_quietly(key))
	return key


func _toggle_case() -> void:
	_set_upper(not _upper)


## The focus wraps around and can't leave the keys.
func _link_focus() -> void:
	for y in _rows.size():
		var row: Array = _rows[y]
		var above: Array = _rows[wrapi(y - 1, 0, _rows.size())]
		var below: Array = _rows[wrapi(y + 1, 0, _rows.size())]
		for x in row.size():
			var key: Button = row[x]
			var left: Button = row[wrapi(x - 1, 0, row.size())]
			var right: Button = row[wrapi(x + 1, 0, row.size())]
			key.focus_neighbor_left = left.get_path()
			key.focus_neighbor_right = right.get_path()
			key.focus_previous = left.get_path()
			key.focus_next = right.get_path()
			key.focus_neighbor_top = _same_column(x, row, above).get_path()
			key.focus_neighbor_bottom = _same_column(x, row, below).get_path()


## The key of `other` at the same horizontal position as `x` in `row`
## (the rows don't all have the same number of keys).
func _same_column(x: int, row: Array, other: Array) -> Button:
	var position_in_row := (x + 0.5) / row.size()
	return other[int(position_in_row * other.size())]
