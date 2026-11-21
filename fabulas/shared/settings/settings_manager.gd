extends Node

## Loads, applies and saves the player's settings (user://settings.cfg).
## Registered as the SettingsManager autoload, so settings are applied at
## startup no matter which scene runs first. Menus only read and write
## values through here; nothing else touches the file.

signal setting_changed(key: StringName, value: Variant)

const SAVE_PATH := "user://settings.cfg"

enum DisplayMode { WINDOWED, BORDERLESS, FULLSCREEN }

## Window sizes offered in windowed mode (filtered by what fits on screen).
const WINDOW_SIZES: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
]

## Frame rate caps offered in the menu. 0 means unlimited.
const FPS_LIMITS: Array[int] = [30, 60, 120, 0]

## Languages offered in the menu: locale -> its name in that language. The
## texts are in shared/localization/translations.csv.
const LANGUAGES := {
	"en": "English",
	"es": "Español",
	"fr": "Français",
	"de": "Deutsch",
	"it": "Italiano",
	"pt": "Português",
}

const DEFAULTS := {
	## Empty means not chosen yet: it follows the language of the system.
	&"language": "",
	&"camera_shake": 100.0,
	&"vibration": 100.0,
	&"show_play_time": false,
	&"master_volume": 100.0,
	&"music_volume": 100.0,
	&"sfx_volume": 100.0,
	&"voices_volume": 100.0,
	&"mute": false,
	&"display_mode": DisplayMode.WINDOWED,
	&"window_size": Vector2i(1280, 720),
	&"vsync": true,
	&"max_fps": 60,
	&"brightness": 1.0,
}

## Volume setting -> audio bus it controls.
const VOLUME_BUSES := {
	&"master_volume": &"Master",
	&"music_volume": &"Music",
	&"sfx_volume": &"SFX",
	&"voices_volume": &"Voices",
}

const AUDIO_KEYS: Array[StringName] = [
	&"master_volume", &"music_volume", &"sfx_volume", &"voices_volume", &"mute",
]

const GENERAL_KEYS: Array[StringName] = [
	&"language", &"camera_shake", &"vibration", &"show_play_time",
]

var _values := {}

## Volume of each bus in the bus layout, so the sliders scale the mix
## designed in the editor instead of overwriting it.
var _bus_base_db := {}


# ******************* LIFECYCLE *******************
func _ready() -> void:
	for key in VOLUME_BUSES:
		var idx := AudioServer.get_bus_index(VOLUME_BUSES[key])
		_bus_base_db[key] = AudioServer.get_bus_volume_db(idx) if idx != -1 else 0.0

	_load()
	for key in _values:
		_apply(key)


# ******************* PUBLIC API *******************
func get_value(key: StringName) -> Variant:
	return _values[key]


## Changes a setting and applies it right away. Call save() to persist it.
func set_value(key: StringName, value: Variant) -> void:
	assert(DEFAULTS.has(key), "Unknown setting: %s" % key)
	value = _sanitize(key, value)
	if _values[key] == value:
		return
	_values[key] = value
	_apply(key)
	setting_changed.emit(key, value)


## Restores everything but the language, which isn't a preference to undo by
## accident (the player might not be able to read the menu to set it back).
func restore_defaults() -> void:
	for key in DEFAULTS:
		if key != &"language":
			set_value(key, DEFAULTS[key])


func save() -> void:
	var config := ConfigFile.new()
	for key in _values:
		config.set_value(_section(key), key, _values[key])
	var error := config.save(SAVE_PATH)
	if error != OK:
		push_warning("SettingsManager: could not save settings (%s)" % error_string(error))


## Window sizes from WINDOW_SIZES that fit on the current screen.
func get_available_window_sizes() -> Array[Vector2i]:
	var usable := DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen()).size
	var sizes: Array[Vector2i] = []
	for size in WINDOW_SIZES:
		if size.x <= usable.x and size.y <= usable.y:
			sizes.append(size)
	if sizes.is_empty():
		sizes.append(WINDOW_SIZES[0])
	return sizes


# ******************* LOAD *******************
func _load() -> void:
	_values = DEFAULTS.duplicate()
	_values[&"language"] = _system_language()
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	for key in DEFAULTS:
		if config.has_section_key(_section(key), key):
			_values[key] = _sanitize(key, config.get_value(_section(key), key))


func _section(key: StringName) -> String:
	if key in GENERAL_KEYS:
		return "general"
	return "audio" if key in AUDIO_KEYS else "video"


## The system's language if the game has it, or English.
func _system_language() -> String:
	var language := OS.get_locale_language()
	return language if LANGUAGES.has(language) else "en"


## Returns a valid value for the setting, or its default if the value is
## of the wrong type or out of range (e.g. a hand-edited or old file).
func _sanitize(key: StringName, value: Variant) -> Variant:
	if key == &"language":
		return value if value is String and LANGUAGES.has(value) else _system_language()

	var default: Variant = DEFAULTS[key]
	match typeof(default):
		TYPE_FLOAT:
			if not (value is float or value is int):
				return default
			value = float(value)
		TYPE_INT:
			if not (value is int or value is float):
				return default
			value = int(value)
		_:
			if typeof(value) != typeof(default):
				return default

	match key:
		&"master_volume", &"music_volume", &"sfx_volume", &"voices_volume", \
				&"camera_shake", &"vibration":
			return clampf(value, 0.0, 100.0)
		&"brightness":
			return clampf(value, 0.5, 1.5)
		&"display_mode":
			return value if value in DisplayMode.values() else default
		&"max_fps":
			return value if value in FPS_LIMITS else default
		&"window_size":
			return value if value.x >= 640 and value.y >= 360 else default
	return value


# ******************* APPLY *******************
func _apply(key: StringName) -> void:
	match key:
		&"language":
			TranslationServer.set_locale(_values[&"language"])
		&"master_volume", &"music_volume", &"sfx_volume", &"voices_volume", &"mute":
			_apply_audio()
		&"display_mode", &"window_size":
			_apply_window()
		&"vsync":
			DisplayServer.window_set_vsync_mode(
				DisplayServer.VSYNC_ENABLED if _values[&"vsync"] else DisplayServer.VSYNC_DISABLED
			)
		&"max_fps":
			Engine.max_fps = _values[&"max_fps"]
		&"brightness":
			BrightnessManager.set_brightness(_values[&"brightness"])


func _apply_audio() -> void:
	for key in VOLUME_BUSES:
		var idx := AudioServer.get_bus_index(VOLUME_BUSES[key])
		if idx == -1:
			continue
		var volume: float = _values[key] / 100.0
		AudioServer.set_bus_volume_db(idx, _bus_base_db[key] + linear_to_db(maxf(volume, 0.0001)))
		var muted: bool = volume <= 0.0 or (key == &"master_volume" and _values[&"mute"])
		AudioServer.set_bus_mute(idx, muted)


func _apply_window() -> void:
	# The game window can't be resized or made fullscreen while it runs
	# embedded in the editor's Game tab.
	if Engine.is_embedded_in_editor():
		return

	match _values[&"display_mode"]:
		DisplayMode.FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		DisplayMode.BORDERLESS:
			# In Godot 4, WINDOW_MODE_FULLSCREEN is borderless fullscreen.
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		_:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
			# Resize on the next frame: right after leaving fullscreen the OS
			# may still be restoring the previous window size.
			_resize_and_center_window.call_deferred()


func _resize_and_center_window() -> void:
	var size: Vector2i = _values[&"window_size"]
	var available := get_available_window_sizes()
	if size not in available:
		size = available[-1]

	var screen := DisplayServer.window_get_current_screen()
	var usable := DisplayServer.screen_get_usable_rect(screen)
	DisplayServer.window_set_size(size)
	@warning_ignore("integer_division")
	DisplayServer.window_set_position(usable.position + (usable.size - size) / 2)
