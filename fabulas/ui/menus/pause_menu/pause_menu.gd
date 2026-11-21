extends Control
class_name PauseMenu

## Pause screen: a panel on the left with the game blurred behind it. The
## panel shows either the buttons or the game statistics. It lives in the
## GameMenus autoload, which opens it and reacts to its signals; this scene
## only handles its own buttons, focus, animation and the exit confirmation.

signal resume_requested
signal settings_requested
signal exit_requested

const OPEN_TIME := 0.25
## Extra distance the panel starts off screen when opening, so the border
## drawn outside it (the column) is hidden too.
const OFFSCREEN_EXTRA := 160.0

@onready var _side: Control = $Side
@onready var _blur_material: ShaderMaterial = $Blur.material
@onready var _main_view: Control = %MainView
@onready var _stats_view: Control = %StatsView
@onready var _stats_grid: GridContainer = %StatsGrid
@onready var _resume_button: Button = %ResumeButton
@onready var _stats_button: Button = %StatsButton
@onready var _settings_button: Button = %SettingsButton
@onready var _exit_button: Button = %ExitButton
@onready var _stats_back_button: Button = %StatsBackButton
@onready var _confirm_exit: ConfirmDialog = %ConfirmExit

var _tween: Tween


func _ready() -> void:
	_resume_button.pressed.connect(resume_requested.emit)
	_stats_button.pressed.connect(_show_stats)
	_settings_button.pressed.connect(settings_requested.emit)
	_exit_button.pressed.connect(_ask_exit)
	_stats_back_button.pressed.connect(_show_main)
	_confirm_exit.confirmed.connect(exit_requested.emit)
	_confirm_exit.canceled.connect(_on_exit_canceled)


func _unhandled_input(event: InputEvent) -> void:
	# While Settings or the exit dialog is open only the blurred background
	# is showing, and those handle their own input.
	if not visible or not _side.visible:
		return
	# In the statistics, Back (Esc / B) returns to the buttons.
	if _stats_view.visible and event.is_action_pressed("ui_cancel"):
		_show_main()
	# Pause (Esc / Start) or Back (Esc / B) closes the pause menu.
	elif event.is_action_pressed("Pause") or event.is_action_pressed("ui_cancel"):
		resume_requested.emit()
	else:
		return
	get_viewport().set_input_as_handled()


## Shows the menu with Resume selected: the panel slides in from the left
## while the game fades into the blur.
func open() -> void:
	show()
	_side.show()
	_set_view(false)
	GameMenus.focus_quietly(_resume_button)
	_animate_in()


## Hides the panel but keeps the blurred game behind the Settings menu.
func hide_panel() -> void:
	_side.hide()


## Shows the panel again after Settings closes, with Settings selected.
func return_from_settings() -> void:
	show()
	_side.show()
	GameMenus.focus_quietly(_settings_button)


func close() -> void:
	if _tween:
		_tween.kill()
	_confirm_exit.hide()
	_side.show()
	hide()


# ******************* VIEWS *******************
func _show_stats() -> void:
	_fill_stats()
	_set_view(true)
	GameMenus.focus_quietly(_stats_back_button)


func _show_main() -> void:
	_set_view(false)
	GameMenus.focus_quietly(_stats_button)


func _set_view(stats: bool) -> void:
	_main_view.visible = not stats
	_stats_view.visible = stats


## One row per statistic: the name (dimmed) and its value.
func _fill_stats() -> void:
	for child in _stats_grid.get_children():
		child.queue_free()
	for row: Array in SaveManager.get_stats_list():
		var name_label := Label.new()
		name_label.text = row[0]
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.add_theme_color_override(&"font_color", Color(0.96, 0.93, 0.88, 0.6))
		var value_label := Label.new()
		value_label.text = row[1]
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_stats_grid.add_child(name_label)
		_stats_grid.add_child(value_label)


# ******************* ANIMATION *******************
func _animate_in() -> void:
	if _tween:
		_tween.kill()
	# Further than its width, so the column that sticks out of its right edge
	# starts off screen too.
	_side.position.x = -_side.size.x - OFFSCREEN_EXTRA
	_blur_material.set_shader_parameter("amount", 0.0)
	_tween = create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_side, "position:x", 0.0, OPEN_TIME)
	_tween.tween_method(_set_blur, 0.0, 1.0, OPEN_TIME)


func _set_blur(value: float) -> void:
	_blur_material.set_shader_parameter("amount", value)


# ******************* EXIT *******************
func _ask_exit() -> void:
	var message := "Your progress will be lost."
	if SaveManager.active_slot >= 0:
		message = "You'll continue from your last checkpoint." \
				if CheckpointManager.checkpoint_active \
				else "You'll continue from the start of this level."
	# Only the dialog over the blurred game, without the panel behind it.
	_side.hide()
	_confirm_exit.ask("Exit to the main menu?", message, "Exit", "Cancel", false)


func _on_exit_canceled() -> void:
	_side.show()
	GameMenus.focus_quietly(_exit_button)
