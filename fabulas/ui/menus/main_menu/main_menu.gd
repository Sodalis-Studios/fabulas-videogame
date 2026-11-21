extends Control
class_name MainMenu


@onready var buttons: Control = $MarginContainer
@onready var start_button: Button = $MarginContainer/VBoxContainer/Start
@onready var settings_button: Button = $MarginContainer/VBoxContainer/settings
@onready var save_slots: SaveSlotsMenu = $SaveSlotsMenu

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	get_tree().paused = true
	SoundManager.play_music("Menu")
	save_slots.slot_chosen.connect(_on_slot_chosen)
	save_slots.closed.connect(_on_save_slots_closed)
	# Start selected so the menu works with keyboard and controller.
	GameMenus.focus_quietly.call_deferred(start_button)


func _on_start_pressed() -> void:
	# Only the buttons are hidden, so the background stays behind the slots.
	buttons.visible = false
	save_slots.open()


func _on_save_slots_closed() -> void:
	buttons.visible = true
	GameMenus.focus_quietly(start_button)


func _on_slot_chosen(slot: int, game_name: String) -> void:
	get_tree().paused = false
	SoundManager.stop_music()

	if SaveManager.has_save(slot):
		SaveManager.continue_game(slot)
	else:
		SaveManager.start_new_game(slot, game_name)

func _on_exit_pressed() -> void:
	get_tree().quit()

func _on_settings_closed():
	# Only the buttons are hidden while Settings is open, so the background
	# stays visible behind it.
	buttons.visible = true
	GameMenus.focus_quietly(settings_button)


func _on_settings_pressed() -> void:
	buttons.visible = false
	GameMenus.open_settings(_on_settings_closed)
