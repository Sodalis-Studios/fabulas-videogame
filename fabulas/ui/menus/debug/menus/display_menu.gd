extends "../base_menu/base_menu.gd"

## What's drawn on screen: the info panel and the collision shapes.


func _build() -> void:
	add_option("INFO", "Info panel", Kind.TOGGLE).toggled.connect(
			func(value: bool) -> void: DebugMenu.show_info_panel = value)
	add_option("COLLISIONS", "Collisions", Kind.TOGGLE).toggled.connect(
			func(value: bool) -> void: DebugMenu.show_collisions = value)


func refresh() -> void:
	get_option("INFO").set_toggle(DebugMenu.show_info_panel)
	get_option("COLLISIONS").set_toggle(DebugMenu.show_collisions)
