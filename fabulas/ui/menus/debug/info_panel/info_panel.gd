extends CanvasLayer

@onready var fps_label: Label = $PanelContainer/VBoxContainer/FPSLabel
@onready var state_label: Label = $PanelContainer/VBoxContainer/StateLabel
@onready var position_label: Label = $PanelContainer/VBoxContainer/PositionLabel
@onready var velocity_label: Label = $PanelContainer/VBoxContainer/VelocityLabel
@onready var memory_label: Label = $PanelContainer/VBoxContainer/MemoryLabel
@onready var objects_label: Label = $PanelContainer/VBoxContainer/ObjectsLabel
@onready var scene_label: Label = $PanelContainer/VBoxContainer/SceneLabel
@onready var game_label: Label = $PanelContainer/VBoxContainer/GameLabel

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = DebugMenu.show_info_panel
	DebugMenu.info_panel_changed.connect(_on_visibility_changed)

func _on_visibility_changed(value: bool) -> void:
	visible = value

func _process(_delta: float) -> void:
	if not visible:
		return

	var player := get_tree().get_first_node_in_group("player")

	fps_label.text = "FPS: %d (%.1f ms)   Speed: %s" % [Engine.get_frames_per_second(),
			get_process_delta_time() * 1000.0, DebugMenu.speed_text(Engine.time_scale)]

	var scene := get_tree().current_scene
	scene_label.text = "Scene: %s" % (scene.scene_file_path.get_file() if scene else "-")
	var checkpoint := "-"
	if CheckpointManager.checkpoint_active:
		checkpoint = "(%.0f, %.0f) in %s" % [CheckpointManager.checkpoint_position.x,
				CheckpointManager.checkpoint_position.y,
				str(SceneManager.SceneID.find_key(CheckpointManager.current_scene)).capitalize()]
	game_label.text = "Game: %s   Checkpoint: %s" % [
			"%d" % (SaveManager.active_slot + 1) if SaveManager.active_slot >= 0 else "-",
			checkpoint]

	if player:
		# The state machine starts on the frame after the player appears.
		var state: Node = player.state_machine.current_state
		state_label.text = "State: %s" % (str(state.name) if state else "-")
		position_label.text = "Pos: (%.1f, %.1f)" % [player.global_position.x, player.global_position.y]
		velocity_label.text = "Vel: (%.1f, %.1f)" % [player.velocity.x, player.velocity.y]
	else:
		state_label.text = "State: -"
		position_label.text = "Pos: -"
		velocity_label.text = "Vel: -"

	var mem_mb: float = Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0
	memory_label.text = "Mem: %.2f MB" % mem_mb
	objects_label.text = "Objects: %d | Nodes: %d | Draw calls: %d" % [
		Performance.get_monitor(Performance.OBJECT_COUNT),
		Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	]
