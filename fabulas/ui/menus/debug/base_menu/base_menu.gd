extends Control

## Base of every debug page: a list of options moved with up/down. Accept
## activates the selected one, left/right change its value and Back returns
## to the first page. The input comes from the DebugMenu autoload.
##
## Each page creates its options in `_build()` with `add_option()`, and shows
## the current values in `refresh()` (called every time the page is shown).

const OPTION_SCENE := preload("res://ui/buttons/on_off_button/menu_option.tscn")
const Kind := DebugMenuOption.Kind

@onready var option_list: VBoxContainer = $VBoxContainer

var options: Array[DebugMenuOption] = []
var selected_index := 0


func _ready() -> void:
	_build()
	for option in option_list.get_children():
		if option is DebugMenuOption and option.visible:
			options.append(option)
	if not options.is_empty():
		options[selected_index].select()


## Override to create the page's options.
func _build() -> void:
	pass


## Override to show the current state in the options.
func refresh() -> void:
	pass


func add_option(id: String, text: String, kind: Kind, choices := PackedStringArray()) -> DebugMenuOption:
	var option: DebugMenuOption = OPTION_SCENE.instantiate()
	option.option_id = id
	option.label = text
	option.kind = kind
	option.choices = choices
	option_list.add_child(option)
	return option


## An option that runs `callable` on accept. `callable` may return a short
## text to show instead of "Done".
func add_action(id: String, text: String, callable: Callable) -> DebugMenuOption:
	var option := add_option(id, text, Kind.ACTION)
	option.action = callable
	return option


func get_option(id: String) -> DebugMenuOption:
	for option in options:
		if option.option_id == id:
			return option
	return null


func handle_input(event: InputEvent) -> void:
	if options.is_empty():
		return
	if event.is_action_pressed("ui_down", true):
		_move_selection(1)
	elif event.is_action_pressed("ui_up", true):
		_move_selection(-1)
	elif event.is_action_pressed("ui_right", true):
		options[selected_index].step(1)
	elif event.is_action_pressed("ui_left", true):
		options[selected_index].step(-1)
	elif event.is_action_pressed("ui_accept"):
		on_accept()
	elif event.is_action_pressed("ui_cancel"):
		on_back()


func _move_selection(direction: int) -> void:
	options[selected_index].deselect()
	selected_index = wrapi(selected_index + direction, 0, options.size())
	options[selected_index].select()


func on_accept() -> void:
	options[selected_index].activate()


func on_back() -> void:
	get_parent().show_menu("MainMenu")
