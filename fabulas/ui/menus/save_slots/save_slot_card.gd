extends VBoxContainer
class_name SaveSlotCard

## One save slot in the slot selection screen: a square card that starts or
## continues the game, and Rename and Delete buttons under it when the slot
## is used.

signal play_requested(slot: int)
signal rename_requested(slot: int)
signal delete_requested(slot: int)

## Slot index (0, 1 or 2).
@export var slot := 0
## Scale of the card while it's selected.
@export var selected_scale := 1.04

@onready var card: Button = $Card
@onready var rename_button: Button = %RenameButton
@onready var delete_button: Button = %DeleteButton
@onready var _actions: Control = %Actions
@onready var _slot_label: Label = %SlotLabel
@onready var _empty_box: Control = %Empty
@onready var _info_box: Control = %Info
@onready var _scene_label: Label = %SceneLabel
@onready var _time_label: Label = %TimeLabel
@onready var _date_label: Label = %DateLabel


func _ready() -> void:
	card.pressed.connect(func() -> void: play_requested.emit(slot))
	rename_button.pressed.connect(func() -> void: rename_requested.emit(slot))
	delete_button.pressed.connect(func() -> void: delete_requested.emit(slot))
	# Hovering selects, like in the other menus. The buttons already play
	# their own hover sound.
	for button: Button in [card, rename_button, delete_button]:
		button.mouse_entered.connect(func() -> void:
			if button.visible and not button.has_focus():
				GameMenus.focus_quietly(button))
	_link_action_focus()
	# The player's own name for the game: "Start" must stay "Start".
	_slot_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	refresh()


func _process(delta: float) -> void:
	# Grow from the centre while selected. Set every frame because the
	# container resets the scale when it re-sorts.
	card.pivot_offset = card.size / 2.0
	var target := Vector2.ONE * (selected_scale if card.has_focus() else 1.0)
	card.scale = card.scale.lerp(target, 1.0 - exp(-16.0 * delta))


func is_empty() -> bool:
	return not SaveManager.has_save(slot)


## Reads the slot again and updates what the card shows.
func refresh() -> void:
	var info := SaveManager.get_slot_info(slot)
	_slot_label.text = SaveManager.get_slot_name(slot)
	_empty_box.visible = info.is_empty()
	_info_box.visible = not info.is_empty()
	_actions.visible = not info.is_empty()
	if info.is_empty():
		return
	_scene_label.text = info.scene_name
	_time_label.text = SaveManager.format_play_time(info.play_time)
	_date_label.text = SaveManager.format_date(info.last_played)


## Left/right switch between Rename and Delete and up goes back to the card;
## otherwise the big card next to them would take the focus.
func _link_action_focus() -> void:
	for button: Button in [rename_button, delete_button]:
		var other := delete_button if button == rename_button else rename_button
		button.focus_neighbor_left = other.get_path()
		button.focus_neighbor_right = other.get_path()
		button.focus_neighbor_top = card.get_path()
		button.focus_neighbor_bottom = button.get_path()
