extends Node

var current_scene_id: SceneID
var teleport_marker: String = ""

enum SceneID {
	MAIN_MENU,
	INTRO_CUTSCENE,
	LEVEL_ISAAC,
	LEVEL_JOA,
	LEVEL_0_START,
	LEVEL_1_INTRODUCTION,
	LEVEL_2_MOVING_PLATFORMS,
	LEVEL_3_MAZE,
	LEVEL_COMPLETE
}

const SCENES := {
	SceneID.MAIN_MENU: "res://ui/menus/main_menu/main_menu.tscn",
	SceneID.INTRO_CUTSCENE: "res://worlds/scenes/cutscenes/intro/cutscene_intro1.tscn",
	SceneID.LEVEL_ISAAC: "res://worlds/Level_isaac/Level_isaac.tscn",
	SceneID.LEVEL_JOA: "res://worlds/level_test/level_test.tscn",
	SceneID.LEVEL_0_START: "res://worlds/level_0_start/level_0_start.tscn",
	SceneID.LEVEL_1_INTRODUCTION: "res://worlds/level_1_introduction/level_1_introduction.tscn",
	SceneID.LEVEL_2_MOVING_PLATFORMS: "res://worlds/level_2_moving_platforms/level_2_moving_platforms.tscn",
	SceneID.LEVEL_3_MAZE: "res://worlds/Level_3_maze/Level_3_maze.tscn",
	SceneID.LEVEL_COMPLETE: "res://worlds/level_complete/level_complete.tscn"
}

func goto(scene_id: SceneID, marker_name: String = "") -> void:
	current_scene_id = scene_id
	teleport_marker = marker_name
	SaveManager.on_scene_entered(scene_id)

	get_tree().call_deferred(
		"change_scene_to_file",
		SCENES[scene_id]
	)


func get_current_scene_id() -> SceneID:
	var current_path := get_tree().current_scene.scene_file_path

	for id in SCENES:
		if SCENES[id] == current_path:
			return id

	return current_scene_id
