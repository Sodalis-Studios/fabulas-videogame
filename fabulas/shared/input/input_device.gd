extends Node

## Knows whether the player is using the keyboard/mouse or a controller, so
## the menus can show the right button names (see InputHint).
##
## It listens to the window directly because it has to see every event, also
## the ones a menu marks as handled.

signal changed(using_controller: bool)

## How far a stick or trigger must move to count, so drift doesn't.
const STICK_THRESHOLD := 0.5
## Pixels the mouse must move at once to count, so a bump on the desk doesn't.
const MOUSE_THRESHOLD := 4.0

var using_controller := false:
	set(value):
		if value == using_controller:
			return
		using_controller = value
		changed.emit(value)

## The controller used last, which is the one that vibrates.
var _device := 0


func _ready() -> void:
	get_window().window_input.connect(_on_window_input)
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	# Whatever shakes the screen (a hit, a launch...) is also felt in the hands.
	SignalBus.camera_shake_request.connect(_on_camera_shake_request)


## Vibrates the controller in use, scaled by the Vibration setting. Does
## nothing when playing with the keyboard.
func vibrate(strength: float, duration: float) -> void:
	if not using_controller:
		return
	var amount := clampf(strength * SettingsManager.get_value(&"vibration") / 100.0, 0.0, 1.0)
	if amount > 0.0:
		Input.start_joy_vibration(_device, amount * 0.6, amount, duration)


func _on_camera_shake_request(trauma: float) -> void:
	vibrate(trauma * 1.5, 0.25)


func _on_window_input(event: InputEvent) -> void:
	if event is InputEventJoypadButton:
		if event.is_pressed():
			_device = event.device
			using_controller = true
	elif event is InputEventJoypadMotion:
		if absf(event.axis_value) >= STICK_THRESHOLD:
			_device = event.device
			using_controller = true
	elif event is InputEventKey or event is InputEventMouseButton:
		if event.is_pressed():
			using_controller = false
	elif event is InputEventMouseMotion:
		if event.relative.length() >= MOUSE_THRESHOLD:
			using_controller = false


func _on_joy_connection_changed(_device: int, _connected: bool) -> void:
	if Input.get_connected_joypads().is_empty():
		using_controller = false
