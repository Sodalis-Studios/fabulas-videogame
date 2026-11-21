extends CanvasLayer

## Menus shared by the whole game: the pause menu and the settings menu.
## Registered as the GameMenus autoload, so any level or cutscene can be
## paused without including these menus in its own scene, and the main menu
## uses the same settings menu.
##
## Also plays the UI sound whenever the player moves the focus between
## controls (keyboard/controller), anywhere in the game.

@onready var pause_menu: PauseMenu = $PauseMenu
@onready var settings_menu: SettingsMenu = $SettingsMenu

var _quiet_focus := false


func _ready() -> void:
	pause_menu.resume_requested.connect(resume)
	pause_menu.settings_requested.connect(_on_pause_settings_requested)
	pause_menu.exit_requested.connect(_on_pause_exit_requested)
	get_viewport().gui_focus_changed.connect(_on_gui_focus_changed)


func _unhandled_input(event: InputEvent) -> void:
	# The open menus get input before this node (they're its children), so
	# this only sees Pause when no menu has handled it.
	if event.is_action_pressed("Pause") and can_pause():
		pause()
		get_viewport().set_input_as_handled()


# ******************* PAUSE *******************
## Pausing is only allowed while the game is running. The tree is already
## paused in the main menu, during scene transitions and while the debug menu
## is open; pausing on top of those would let Resume unpause them early.
func can_pause() -> bool:
	if get_tree().paused or pause_menu.visible or settings_menu.visible:
		return false
	# The screen is covered by a transition (fading in or fully black).
	if TransitionsScreen.color_rect.visible:
		return false
	return true


func pause() -> void:
	get_tree().paused = true
	pause_menu.open()


func resume() -> void:
	pause_menu.close()
	get_tree().paused = false


## Closes every menu here and unpauses the game. For when the scene is
## changed from outside these menus (the debug menu).
func close_all() -> void:
	if settings_menu.visible:
		settings_menu.close()
	pause_menu.close()
	get_tree().paused = false


func _on_pause_settings_requested() -> void:
	pause_menu.hide_panel()
	open_settings(pause_menu.return_from_settings)


func _on_pause_exit_requested() -> void:
	pause_menu.close()
	SaveManager.leave_game()
	# The main menu keeps the tree paused itself.
	SceneManager.goto(SceneManager.SceneID.MAIN_MENU)


# ******************* SETTINGS *******************
## Opens the settings menu and calls `on_closed` once when it closes.
func open_settings(on_closed: Callable) -> void:
	if not settings_menu.closed.is_connected(on_closed):
		settings_menu.closed.connect(on_closed, CONNECT_ONE_SHOT)
	settings_menu.open()


# ******************* FOCUS *******************
## Gives focus to `control` without playing the focus sound. Use it when a
## menu moves the focus itself (on open, after closing a popup...), so the
## sound only plays when the player moves it.
func focus_quietly(control: Control) -> void:
	_quiet_focus = true
	control.grab_focus()
	_quiet_focus = false


func _on_gui_focus_changed(_control: Control) -> void:
	# Mouse clicks already play the button's own click sound.
	if _quiet_focus or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		return
	SoundManager.play_ui("EnterButton")
