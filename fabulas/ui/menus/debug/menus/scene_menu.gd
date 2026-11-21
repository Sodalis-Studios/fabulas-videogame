extends "../base_menu/base_menu.gd"

## Jumps to any scene of SceneManager (the ones that exist), and to the
## teleport markers inside Level Complete (its DebugTeleport node: Level1,
## Level2...).

const LEVEL_COMPLETE_MARKERS := 5
## Pieces of Level Complete: on their own they have no player.
const LEVEL_COMPLETE_PARTS: Array[SceneManager.SceneID] = [
	SceneManager.SceneID.LEVEL_1_INTRODUCTION,
	SceneManager.SceneID.LEVEL_2_MOVING_PLATFORMS,
	SceneManager.SceneID.LEVEL_3_MAZE,
]


func _build() -> void:
	for scene_id: SceneManager.SceneID in SceneManager.SCENES:
		if scene_id in LEVEL_COMPLETE_PARTS \
				or not ResourceLoader.exists(SceneManager.SCENES[scene_id]):
			continue
		var id_name: String = SceneManager.SceneID.find_key(scene_id)
		add_action(id_name, id_name.capitalize(), _go_to.bind(scene_id, ""))
	for i in range(1, LEVEL_COMPLETE_MARKERS + 1):
		add_action("LEVEL_COMPLETE_%d" % i, "Level Complete › %d" % i,
				_go_to.bind(SceneManager.SceneID.LEVEL_COMPLETE, "Level%d" % i))


func _go_to(scene_id: SceneManager.SceneID, marker_name: String) -> void:
	DebugMenu.go_to_scene(scene_id, marker_name)


## Marks the scene being played.
func refresh() -> void:
	var current: String = SceneManager.SceneID.find_key(SceneManager.get_current_scene_id())
	for option in options:
		option.hint = "here" if option.option_id == current else ""
