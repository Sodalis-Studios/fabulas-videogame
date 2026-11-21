extends "../base_menu/base_menu.gd"

## First page of the debug menu: opens each section. Back closes the menu.

## Page node → text shown.
const SECTIONS := {
	"CheatsMenu": "Cheats",
	"SceneMenu": "Scenes",
	"DisplayMenu": "Display",
	"SaveMenu": "Save",
}


func _build() -> void:
	for page: String in SECTIONS:
		var option := add_option(page, SECTIONS[page], Kind.SUBMENU)
		option.activated.connect(get_parent().show_menu.bind(page))


## Shows a summary of what's on in each section.
func refresh() -> void:
	var cheats: PackedStringArray = []
	if DebugMenu.god_mode:
		cheats.append("god")
	if DebugMenu.game_speed != 1.0:
		cheats.append(DebugMenu.speed_text())
	get_option("CheatsMenu").hint = " ".join(cheats)

	var display: PackedStringArray = []
	if DebugMenu.show_info_panel:
		display.append("info")
	if DebugMenu.show_collisions:
		display.append("collisions")
	get_option("DisplayMenu").hint = " ".join(display)

	get_option("SaveMenu").hint = SaveManager.get_slot_name(SaveManager.active_slot) \
			if SaveManager.active_slot >= 0 else "no game"


func on_back() -> void:
	DebugMenu.close()
