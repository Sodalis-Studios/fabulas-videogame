extends "../base_menu/base_menu.gd"

## The save slot being played.


func _build() -> void:
	add_action("SAVE", "Save now", _save)
	add_action("DELETE_CHECKPOINT", "Delete checkpoint", _delete_checkpoint)


func refresh() -> void:
	get_option("SAVE").hint = SaveManager.get_slot_name(SaveManager.active_slot) \
			if SaveManager.active_slot >= 0 else "no game"
	get_option("DELETE_CHECKPOINT").hint = "" if CheckpointManager.checkpoint_active else "none"


func _save() -> String:
	if SaveManager.active_slot < 0:
		return "No game"
	SaveManager.save_game()
	return "Saved"


func _delete_checkpoint() -> String:
	if not CheckpointManager.checkpoint_active:
		return "None"
	CheckpointManager.clear_checkpoint()
	# The save game must forget it too.
	SaveManager.save_game()
	get_option("DELETE_CHECKPOINT").hint = "none"
	return "Deleted"
