extends Control
class_name SaveSlotsMenu

## Slot selection screen, opened from Start in the main menu. Each slot can
## start a new game (asking for its name), continue a saved one, be renamed or
## be deleted (with confirmation).

## The player picked a slot. The menu that opened this one starts the game.
## `game_name` is only used by a new game.
signal slot_chosen(slot: int, game_name: String)
signal closed

@onready var _cards: Array[SaveSlotCard] = [%Slot1, %Slot2, %Slot3]
@onready var _confirm_delete: ConfirmDialog = %ConfirmDelete
@onready var _name_dialog: NameDialog = %NameDialog

var _slot_to_delete := -1
var _slot_to_name := -1
## Whether the name dialog is renaming a save or naming a new game.
var _renaming := false


func _ready() -> void:
	for card in _cards:
		card.play_requested.connect(_on_play_requested)
		card.rename_requested.connect(_ask_name.bind(true))
		card.delete_requested.connect(_ask_delete)
	_confirm_delete.confirmed.connect(_on_delete_confirmed)
	_confirm_delete.canceled.connect(_on_delete_canceled)
	_name_dialog.confirmed.connect(_on_name_confirmed)
	_name_dialog.canceled.connect(_on_name_canceled)


func _unhandled_input(event: InputEvent) -> void:
	# The dialogs handle their own input while they're open.
	if not visible or _confirm_delete.visible or _name_dialog.visible:
		return
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


## Shows the slots with the last played one selected (or the first).
func open() -> void:
	for card in _cards:
		card.refresh()
	show()
	var slot := maxi(SaveManager.get_last_played_slot(), 0)
	GameMenus.focus_quietly(_cards[slot].card)


func close() -> void:
	_confirm_delete.hide()
	_name_dialog.hide()
	hide()
	closed.emit()


func _on_play_requested(slot: int) -> void:
	if _cards[slot].is_empty():
		_ask_name(slot, false)
	else:
		slot_chosen.emit(slot, "")


# ******************* NAME *******************
func _ask_name(slot: int, renaming: bool) -> void:
	_slot_to_name = slot
	_renaming = renaming
	var default_name := SaveManager.default_name(slot)
	var current := SaveManager.get_slot_name(slot) if renaming else ""
	if current == default_name:
		current = ""
	_name_dialog.ask("Rename game" if renaming else "Name your game", current, default_name)


func _on_name_confirmed(game_name: String) -> void:
	if not _renaming:
		slot_chosen.emit(_slot_to_name, game_name)
		return
	SaveManager.rename_slot(_slot_to_name, game_name)
	var card := _cards[_slot_to_name]
	card.refresh()
	GameMenus.focus_quietly(card.rename_button)


func _on_name_canceled() -> void:
	var card := _cards[_slot_to_name]
	GameMenus.focus_quietly(card.rename_button if _renaming else card.card)


# ******************* DELETE *******************
func _ask_delete(slot: int) -> void:
	_slot_to_delete = slot
	_confirm_delete.ask(tr("Delete %s?") % SaveManager.get_slot_name(slot),
			"This save will be lost forever.", "Delete", "Cancel", false)


func _on_delete_confirmed() -> void:
	SaveManager.delete_slot(_slot_to_delete)
	var card := _cards[_slot_to_delete]
	card.refresh()
	# Its Delete button is gone now, so select the card itself.
	GameMenus.focus_quietly(card.card)


func _on_delete_canceled() -> void:
	GameMenus.focus_quietly(_cards[_slot_to_delete].delete_button)
