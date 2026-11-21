extends Control
class_name DebugMenuContainer

## Holds the debug pages (its children) and shows one at a time. The
## DebugMenu autoload sends it the input, and it passes it on to the page
## being shown.

signal page_changed(page_name: String)

var _current: Control


func show_menu(menu_name: String) -> void:
	for page: Control in get_children():
		page.visible = false
	_current = get_node(menu_name)
	_current.refresh()
	_current.visible = true
	page_changed.emit(menu_name)


func handle_input(event: InputEvent) -> void:
	if _current:
		_current.handle_input(event)
