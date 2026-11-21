extends Control
class_name SettingsMenu

## Settings screen (language, video and audio). Changes apply as soon as they are made
## and are saved when the menu closes. The values live in the SettingsManager
## autoload; this scene only shows and edits them.
##
## There is a single instance, in the GameMenus autoload: open it with
## GameMenus.open_settings(), which also tells you when it closes.

signal closed

## Seconds before a display change is reverted if the player doesn't confirm it.
const CONFIRM_SECONDS := 10

## Row labels are dimmed, and the one of the row that has focus is shown at
## full strength.
const LABEL_COLOR := Color(0.96, 0.93, 0.88, 0.6)
const LABEL_FOCUS_COLOR := Color(0.96, 0.93, 0.88, 1.0)

@onready var _tabs: TabContainer = %Tabs
@onready var _language: OptionButton = %Language
@onready var _show_play_time: CheckButton = %ShowPlayTime
@onready var _display_mode: OptionButton = %DisplayMode
@onready var _window_size: OptionButton = %WindowSize
@onready var _vsync: CheckButton = %VSync
@onready var _max_fps: OptionButton = %MaxFps
@onready var _mute: CheckButton = %Mute
@onready var _restore_button: Button = %RestoreButton
@onready var _back_button: Button = %BackButton
@onready var _confirm: ConfirmDialog = %ConfirmDisplay
@onready var _confirm_timer: Timer = %ConfirmTimer

## Slider -> setting it edits. Each slider has a sibling "Value" label.
@onready var _sliders := {
	%CameraShake: &"camera_shake",
	%Vibration: &"vibration",
	%Brightness: &"brightness",
	%Master: &"master_volume",
	%Music: &"music_volume",
	%Sfx: &"sfx_volume",
	%Voices: &"voices_volume",
}

## Control that gets focus when each tab is shown, by tab index.
@onready var _first_control_per_tab: Array[Control] = [_language, _display_mode, %Master]

var _window_sizes: Array[Vector2i] = []
var _display_backup := {}
var _confirm_return_focus: Control
var _seconds_left := 0


# ******************* LIFECYCLE *******************
func _ready() -> void:
	_populate_static_options()
	_connect_controls()
	visibility_changed.connect(_on_visibility_changed)
	if visible:
		_on_visibility_changed()


func _unhandled_input(event: InputEvent) -> void:
	# While the display confirmation is open it handles the input itself.
	if not visible or _confirm.visible:
		return

	if event.is_action_pressed("ui_cancel"):
		close()
	elif event.is_action_pressed("menu_prev_tab"):
		_switch_tab(-1)
	elif event.is_action_pressed("menu_next_tab"):
		_switch_tab(1)
	else:
		return
	get_viewport().set_input_as_handled()


# ******************* PUBLIC API *******************
func open() -> void:
	show()


## Saves the settings, hides the menu and emits `closed`.
func close() -> void:
	if _confirm.visible:
		_revert_display()
	SettingsManager.save()
	hide()
	closed.emit()


# ******************* SETUP *******************
func _populate_static_options() -> void:
	_language.clear()
	for locale: String in SettingsManager.LANGUAGES:
		_language.add_item(SettingsManager.LANGUAGES[locale])

	_display_mode.clear()
	_display_mode.add_item("Windowed", SettingsManager.DisplayMode.WINDOWED)
	_display_mode.add_item("Borderless fullscreen", SettingsManager.DisplayMode.BORDERLESS)
	_display_mode.add_item("Fullscreen", SettingsManager.DisplayMode.FULLSCREEN)

	_max_fps.clear()
	for limit in SettingsManager.FPS_LIMITS:
		_max_fps.add_item(str(limit) if limit > 0 else "Unlimited")


func _connect_controls() -> void:
	_language.item_selected.connect(func(index: int) -> void:
		SettingsManager.set_value(&"language", SettingsManager.LANGUAGES.keys()[index]))
	_show_play_time.toggled.connect(func(on: bool) -> void:
		SettingsManager.set_value(&"show_play_time", on)
		_update_toggle_text(_show_play_time))
	_display_mode.item_selected.connect(func(index: int) -> void:
		_change_display(&"display_mode", _display_mode.get_item_id(index), _display_mode))
	_window_size.item_selected.connect(func(index: int) -> void:
		_change_display(&"window_size", _window_sizes[index], _window_size))
	_vsync.toggled.connect(func(on: bool) -> void:
		SettingsManager.set_value(&"vsync", on)
		_update_toggle_text(_vsync))
	_max_fps.item_selected.connect(func(index: int) -> void:
		SettingsManager.set_value(&"max_fps", SettingsManager.FPS_LIMITS[index]))
	_mute.toggled.connect(func(on: bool) -> void:
		SettingsManager.set_value(&"mute", on)
		_update_toggle_text(_mute))

	for slider: HSlider in _sliders:
		slider.value_changed.connect(_on_slider_changed.bind(slider))

	_restore_button.pressed.connect(_on_restore_pressed)
	_back_button.pressed.connect(close)
	_confirm.confirmed.connect(_keep_display)
	_confirm.canceled.connect(_revert_display)
	_confirm_timer.timeout.connect(_on_confirm_tick)

	# Highlight the label of the row that has focus.
	for control: Control in find_children("*", "Control", true, false):
		if control.focus_mode == FOCUS_NONE:
			continue
		var label := _row_label(control)
		if label:
			label.add_theme_color_override(&"font_color", LABEL_COLOR)
			control.focus_entered.connect(label.add_theme_color_override.bind(&"font_color", LABEL_FOCUS_COLOR))
			control.focus_exited.connect(label.add_theme_color_override.bind(&"font_color", LABEL_COLOR))


## The label in the same settings row as `control` (the cell to its left in
## the grid), or null if the control isn't in a settings row.
func _row_label(control: Control) -> Label:
	var cell: Node = control
	if not control.get_parent() is GridContainer:
		cell = control.get_parent()
	if not cell.get_parent() is GridContainer or cell.get_index() == 0:
		return null
	return cell.get_parent().get_child(cell.get_index() - 1) as Label


# ******************* REFRESH *******************
## Updates every control from SettingsManager without emitting signals.
func _refresh() -> void:
	_language.select(SettingsManager.LANGUAGES.keys().find(SettingsManager.get_value(&"language")))
	_show_play_time.set_pressed_no_signal(SettingsManager.get_value(&"show_play_time"))
	_update_toggle_text(_show_play_time)

	var mode: int = SettingsManager.get_value(&"display_mode")
	_display_mode.select(_display_mode.get_item_index(mode))

	var current_size: Vector2i = SettingsManager.get_value(&"window_size")
	_window_sizes = SettingsManager.get_available_window_sizes()
	_window_size.clear()
	for window_size in _window_sizes:
		_window_size.add_item("%d x %d" % [window_size.x, window_size.y])
	var size_index := _window_sizes.find(current_size)
	_window_size.select(size_index if size_index != -1 else _window_sizes.size() - 1)
	# The window size only matters in windowed mode.
	_window_size.disabled = mode != SettingsManager.DisplayMode.WINDOWED

	_vsync.set_pressed_no_signal(SettingsManager.get_value(&"vsync"))
	_update_toggle_text(_vsync)
	_max_fps.select(SettingsManager.FPS_LIMITS.find(SettingsManager.get_value(&"max_fps")))
	_mute.set_pressed_no_signal(SettingsManager.get_value(&"mute"))
	_update_toggle_text(_mute)

	for slider: HSlider in _sliders:
		slider.set_value_no_signal(SettingsManager.get_value(_sliders[slider]))
		_update_value_label(slider)


## The default switch icon is too small to read on its own, so the toggle
## also says On/Off (coloured by the theme's pressed/normal font colours).
func _update_toggle_text(toggle: CheckButton) -> void:
	toggle.text = "On" if toggle.button_pressed else "Off"


func _update_value_label(slider: HSlider) -> void:
	# Brightness goes from 0.5 to 1.5; show it as 50% to 150%.
	var percent := slider.value * 100.0 if _sliders[slider] == &"brightness" else slider.value
	slider.get_node("../Value").text = "%d%%" % roundi(percent)


# ******************* FOCUS AND TABS *******************
func _on_visibility_changed() -> void:
	if not visible:
		return
	_refresh()
	GameMenus.focus_quietly.call_deferred(_first_control_per_tab[_tabs.current_tab])


func _switch_tab(direction: int) -> void:
	_tabs.current_tab = wrapi(_tabs.current_tab + direction, 0, _tabs.get_tab_count())
	SoundManager.play_ui("EnterButton")
	GameMenus.focus_quietly(_first_control_per_tab[_tabs.current_tab])


# ******************* VALUE CHANGES *******************
func _on_slider_changed(value: float, slider: HSlider) -> void:
	SettingsManager.set_value(_sliders[slider], value)
	_update_value_label(slider)
	# A short pulse, so the player feels the strength they're choosing.
	if _sliders[slider] == &"vibration":
		InputDevice.vibrate(0.6, 0.15)


func _on_restore_pressed() -> void:
	SettingsManager.restore_defaults()
	_refresh()


# ******************* DISPLAY CONFIRMATION *******************
## Applies a display mode or window size change and asks the player to keep
## it; if they don't answer in CONFIRM_SECONDS, it goes back to the old one.
func _change_display(key: StringName, value: Variant, source: Control) -> void:
	if SettingsManager.get_value(key) == value:
		return
	_confirm_return_focus = source
	if not _confirm.visible:
		_display_backup = {
			&"display_mode": SettingsManager.get_value(&"display_mode"),
			&"window_size": SettingsManager.get_value(&"window_size"),
		}
	SettingsManager.set_value(key, value)
	_refresh()

	_seconds_left = CONFIRM_SECONDS
	_confirm.ask("Keep these display settings?", _countdown_text(), "Keep", "Revert")
	_confirm_timer.start(1.0)


func _on_confirm_tick() -> void:
	_seconds_left -= 1
	if _seconds_left <= 0:
		_confirm.hide()
		_revert_display()
	else:
		_confirm.set_message(_countdown_text())


func _countdown_text() -> String:
	return tr("Reverting in %d s") % _seconds_left


func _keep_display() -> void:
	_confirm_timer.stop()
	GameMenus.focus_quietly.call_deferred(_confirm_return_focus)


func _revert_display() -> void:
	_confirm_timer.stop()
	_confirm.hide()
	for key in _display_backup:
		SettingsManager.set_value(key, _display_backup[key])
	_refresh()
	# Back to the option that was changed.
	GameMenus.focus_quietly.call_deferred(_confirm_return_focus)
