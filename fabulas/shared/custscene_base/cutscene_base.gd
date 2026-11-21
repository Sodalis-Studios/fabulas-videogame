class_name CutsceneBase
extends Node

## Seconds Accept must be held to skip, so a stray press doesn't skip it.
const SKIP_HOLD_TIME := 0.7

@export var next_scene: String = ""
var slides: Array = []
var current_index: int = 0

@onready var texture_rect = $CanvasLayer/TextureRect
@onready var label = $CanvasLayer/Panel/Label
@onready var color_rect = $CanvasLayer/ColorRect
@onready var anim = $AnimationPlayer
@onready var timer: Timer = $Timer
@onready var skip_button: Button = $CanvasLayer/Saltar
@onready var skip_fill: Control = $CanvasLayer/Saltar/Fill

var _holding_skip := false
var _skip_progress := 0.0
var _finished := false


func _ready() -> void:
	anim.animation_finished.connect(_on_animation_finished)
	timer.one_shot = true
	timer.timeout.connect(_on_timer_timeout)
	InputDevice.changed.connect(_update_skip_text)
	_update_skip_text(InputDevice.using_controller)
	skip_fill.scale.x = 0.0
	_load_slide(0)


func _unhandled_input(event: InputEvent) -> void:
	# Only a new press counts: not a key still held from the previous menu.
	if event.is_action_pressed("ui_accept"):
		_holding_skip = true
		get_viewport().set_input_as_handled()
	elif event.is_action_released("ui_accept"):
		_holding_skip = false


func _process(delta: float) -> void:
	# It may have been released while the game was paused.
	if not Input.is_action_pressed("ui_accept"):
		_holding_skip = false
	var change := delta / SKIP_HOLD_TIME
	_skip_progress = clampf(_skip_progress + (change if _holding_skip else -change * 3.0), 0.0, 1.0)
	skip_fill.scale.x = _skip_progress
	if _skip_progress >= 1.0:
		_on_saltar_pressed()


func _update_skip_text(using_controller: bool) -> void:
	skip_button.text = "Hold A to skip" if using_controller else "Hold Enter to skip"


func _load_slide(index: int) -> void:
	var slide = slides[index]
	texture_rect.texture = slide["image"]
	label.text = slide["text"]
	SoundManager.play_voice(slide["voice"])
	anim.play("slide_in")
	timer.wait_time = slide.get("duration", 5.0)
	timer.start()

func _on_timer_timeout() -> void:
	anim.play("slide_out")

func _on_animation_finished(anim_name: String) -> void:
	if anim_name == "slide_out":
		current_index += 1
		if current_index >= slides.size():
			_finish()
		else:
			_load_slide(current_index)
	elif anim_name == "fade_out":
		get_tree().change_scene_to_file(next_scene)

func _finish() -> void:
	if _finished:
		return
	_finished = true
	set_process(false)
	timer.stop()
	anim.play("fade_out")
	SoundManager.stop_voice()
	SoundManager.stop_music()
	SceneManager.goto(SceneManager.SceneID.LEVEL_0_START)

func _on_saltar_pressed() -> void:
	timer.stop()
	anim.stop()
	_finish()
