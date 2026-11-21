extends Node2D

## Camera controller driven by [CameraZone] with Tween transitions that follows a specific node.

# ====================== REFERENCE VARIABLES ======================
@onready var camera: Camera2D = $Camera2D

# ====================== EXPORT VARIABLES ======================
@export_category("Target Node")
@export var followed_node: Node2D

@export_category("Screen Shake")
## How fast the camera calms down. Higher = faster.
@export var trauma_decay: float = 2.0
## Maximum distance in pixels the camera can move.
@export var max_shake_offset: Vector2 = Vector2(80.0, 80.0)
## Maximum rotation in radians the camera can tilt.
@export var max_shake_roll: float = 0.05

# ====================== LOCAL VARIABLES ======================
var trauma: float = 0.0

# ====================== CAMERA ZONE VARIABLES ======================
var active_zones: Array[CameraZone] = []
var current_zone: CameraZone = null

var is_transitioning: bool = false
var transition_tween: Tween = null
var transition_start_pos: Vector2
var transition_start_zoom: Vector2
var transition_weight: float = 0.0

# *********************** BUILT IN CALLBACKS **********************
func _ready() -> void:
	add_to_group("camera_rig")
	SignalBus.player_entered_camera_zone.connect(_on_player_entered_camera_zone)
	SignalBus.player_exited_camera_zone.connect(_on_player_exited_camera_zone)
	SignalBus.camera_shake_request.connect(_on_camera_shake_request)
	
	if (CheckpointManager.checkpoint_active and SceneManager.get_current_scene_id() == CheckpointManager.current_scene):
		global_position = CheckpointManager.checkpoint_position

func _process(delta: float) -> void:
	if followed_node == null:
		push_warning("followed_node is null")
		return

	if active_zones.is_empty():
		return
	
	var live_target := _calculate_target_position(current_zone)

	if is_transitioning:
		# Dynamic transitioning between zones
		global_position = transition_start_pos.lerp(live_target, transition_weight)
		camera.zoom = transition_start_zoom.lerp(current_zone.zone_zoom, transition_weight)
	else:
		# Normal following behaviour
		global_position.x = lerp(global_position.x, live_target.x, current_zone.zone_follow_speed * delta)
		global_position.y = lerp(global_position.y, live_target.y, current_zone.zone_follow_speed * delta)
		camera.zoom = camera.zoom.lerp(current_zone.zone_zoom, current_zone.zone_follow_speed * delta)

	if trauma > 0.0:
		trauma = max(trauma - trauma_decay * delta, 0.0)
		_apply_shake()
	else:
		# Security reset
		camera.offset = Vector2.ZERO
		camera.rotation = 0.0
		
# *********************** ZONES CALLBACKS **********************
func _on_player_entered_camera_zone(zone: CameraZone) -> void:
	if not active_zones.has(zone):
		active_zones.append(zone)
		_sort_zones()
		_update_current_zone()

func _on_player_exited_camera_zone(zone: CameraZone) -> void:
	if active_zones.has(zone):
		active_zones.erase(zone)
		_sort_zones()
		_update_current_zone()

# *********************** PRIVATE METHODS **********************
func _apply_shake() -> void:
	# Square the trauma to make strong shakes more intense but decay faster
	var amount: float = trauma * trauma * SettingsManager.get_value(&"camera_shake") / 100.0

	# Apply random noise to offeset and rotation based on trauma amount
	camera.offset.x = max_shake_offset.x * amount * randf_range(-1.0, 1.0)
	camera.offset.y = max_shake_offset.y * amount * randf_range(-1.0, 1.0)
	camera.rotation = max_shake_roll * amount * randf_range(-1.0, 1.0)

func _sort_zones() -> void:
	active_zones.sort_custom(func(zoneA, zoneB): return zoneA.zone_priority > zoneB.zone_priority)

func _update_current_zone() -> void:
	var top_zone: CameraZone = active_zones[0] if not active_zones.is_empty() else null
	
	if top_zone != current_zone:
		current_zone = top_zone
		if current_zone != null:
			_start_zone_transition(current_zone)
		else:
			is_transitioning = false
			if transition_tween and transition_tween.is_running():
				transition_tween.kill()

func _start_zone_transition(zone: CameraZone) -> void:
	if followed_node == null: return
	if transition_tween and transition_tween.is_running(): transition_tween.kill()

	is_transitioning = true
	transition_weight = 0.0 # Starts at 0%
	transition_start_pos = global_position
	transition_start_zoom = camera.zoom

	transition_tween = create_tween()
	transition_tween.set_trans(zone.transition_trans_type).set_ease(zone.transition_ease_type)

	transition_tween.tween_property(self, "transition_weight", 1.0, zone.transition_duration)
	transition_tween.finished.connect(func(): is_transitioning = false)

func _calculate_target_position(zone: CameraZone) -> Vector2:
	var zone_center := zone.get_zone_center()
	
	var target_x: float
	if zone.zone_follow_x:
		target_x = followed_node.global_position.x + zone.zone_offset_x
	else:
		target_x = zone_center.x + zone.zone_offset_x

	var target_y: float
	if zone.zone_follow_y:
		target_y = followed_node.global_position.y + zone.zone_offset_y
	else:
		target_y = zone_center.y + zone.zone_offset_y

	var target_pos := Vector2(target_x, target_y)

	target_pos = _apply_custom_limits(target_pos, zone, zone.zone_zoom)

	return target_pos

func _apply_custom_limits(desired_pos: Vector2, zone: CameraZone, current_zoom: Vector2) -> Vector2:
	var limits := zone.get_camera_limits()
	if limits.is_empty():
		return desired_pos

	# Resolución base del viewport definida en el proyecto
	var vp_w: float = ProjectSettings.get_setting("display/window/size/viewport_width", 1920)
	var vp_h: float = ProjectSettings.get_setting("display/window/size/viewport_height", 1080)

	# Distancia desde el centro de la cámara hasta sus bordes (considerando el zoom)
	var cam_half_w := (vp_w / current_zoom.x) / 2.0
	var cam_half_h := (vp_h / current_zoom.y) / 2.0

	var clamped_x := desired_pos.x
	var clamped_y := desired_pos.y

	# --- Restricción Eje X ---
	var min_x: float = limits["left"] + cam_half_w
	var max_x: float = limits["right"] - cam_half_w
	if min_x > max_x:
		# Si la habitación es más estrecha que la pantalla, centramos la cámara en la zona
		clamped_x = (limits["left"] + limits["right"]) / 2.0
	else:
		clamped_x = clamp(desired_pos.x, min_x, max_x)

	# --- Restricción Eje Y ---
	var min_y: float = limits["top"] + cam_half_h
	var max_y: float = limits["bottom"] - cam_half_h
	if min_y > max_y:
		# Si la habitación es más baja que la pantalla, centramos la cámara en la zona
		clamped_y = (limits["top"] + limits["bottom"]) / 2.0
	else:
		clamped_y = clamp(desired_pos.y, min_y, max_y)

	return Vector2(clamped_x, clamped_y)

# *********************** SIGNAL CALLBACKS **********************
func _on_camera_shake_request(amount: float) -> void:
	# Add trauma to the camera but clamp it between 0.0 and 1.0 to avoid excessive shaking
	trauma = clamp(trauma + amount, 0.0, 1.0)

# *********************** PUBLIC METHODS **********************

func activate() -> void:
	camera.make_current()

func deactivate() -> void:
	camera.make_current()
