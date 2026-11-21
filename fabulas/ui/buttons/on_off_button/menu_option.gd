extends HBoxContainer
class_name DebugMenuOption

## One row of the debug menu. Depending on `kind` it is:
## - TOGGLE: ON/OFF, switched with accept.
## - CHOICE: a list of values, changed with left/right (or accept).
## - ACTION: runs `action` and briefly shows what happened ("Done"...).
## - SUBMENU: opens another page.

signal toggled(value: bool)
signal choice_changed(index: int)
signal activated

enum Kind { TOGGLE, CHOICE, ACTION, SUBMENU }

const ON_COLOR := Color(0.55, 0.9, 0.55)
const OFF_COLOR := Color(1, 1, 1, 0.45)
const VALUE_COLOR := Color(1, 1, 1, 0.85)
const FEEDBACK_COLOR := Color(1, 0.85, 0.4)
const FEEDBACK_TIME := 1.2

@onready var arrow_label: Label = $ArrowLabel
@onready var name_label: Label = $NameLabel
@onready var value_label: Label = $ValueLabel

@export var option_id := ""
## Text shown in the row. Empty keeps the one set in the scene.
@export var label := ""
@export var kind := Kind.TOGGLE
## Values of a CHOICE option.
@export var choices: PackedStringArray = []

## Run by an ACTION option. It can return a short text to show instead of
## "Done" (e.g. "No checkpoint").
var action: Callable
## Dim text shown on the right of an ACTION or SUBMENU row (e.g. "here").
var hint := "":
	set(value):
		hint = value
		if is_node_ready():
			_update_value()
var state := false
var choice_index := 0

var _feedback_tween: Tween


func _ready() -> void:
	if label != "":
		name_label.text = label
	deselect()
	_update_value()


func select() -> void:
	arrow_label.text = "▶"
	name_label.modulate = Color.WHITE


func deselect() -> void:
	arrow_label.text = ""
	name_label.modulate = Color(1, 1, 1, 0.7)


## Accept on this row.
func activate() -> void:
	match kind:
		Kind.TOGGLE:
			set_toggle(not state)
			toggled.emit(state)
		Kind.CHOICE:
			step(1)
		Kind.ACTION:
			var result: Variant = action.call() if action.is_valid() else null
			_show_feedback(result if result is String and result != "" else "Done")
			activated.emit()
		Kind.SUBMENU:
			activated.emit()


## Left/right on this row: changes the value of a CHOICE.
func step(direction: int) -> void:
	if kind != Kind.CHOICE or choices.is_empty():
		return
	set_choice(wrapi(choice_index + direction, 0, choices.size()))
	choice_changed.emit(choice_index)


## Sets the value without emitting anything (to show the current state).
func set_toggle(new_state: bool) -> void:
	state = new_state
	_update_value()


## Sets the value without emitting anything (to show the current state).
func set_choice(index: int) -> void:
	choice_index = clampi(index, 0, maxi(choices.size() - 1, 0))
	_update_value()


func _update_value() -> void:
	value_label.visible = true
	value_label.modulate = VALUE_COLOR
	match kind:
		Kind.TOGGLE:
			value_label.text = "ON" if state else "OFF"
			value_label.modulate = ON_COLOR if state else OFF_COLOR
		Kind.CHOICE:
			value_label.text = "◀ %s ▶" % choices[choice_index] if choices.size() > 0 else ""
		Kind.ACTION:
			value_label.text = hint
			value_label.modulate = OFF_COLOR
		Kind.SUBMENU:
			value_label.text = "%s  ›" % hint if hint != "" else "›"


func _show_feedback(text: String) -> void:
	if _feedback_tween:
		_feedback_tween.kill()
	# The action may have closed the menu or changed scene.
	if not is_inside_tree():
		return
	value_label.text = text
	value_label.modulate = FEEDBACK_COLOR
	# The game is paused while the menu is open; this node keeps processing.
	_feedback_tween = create_tween()
	_feedback_tween.tween_interval(FEEDBACK_TIME)
	_feedback_tween.tween_callback(_update_value)
