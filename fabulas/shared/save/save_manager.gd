extends Node

## Save games: three slots, one file each (user://save_1.cfg ...).
##
## A slot stores where the player is (scene + checkpoint), the play time, the
## statistics (jumps, hits taken) and when it was last played. The game is saved when it starts, when a level is
## entered, when a checkpoint is touched, when exiting to the main menu and
## when the window is closed.
##
## Scenes run straight from the editor have no active slot, so they never
## touch the saves.

const SLOT_COUNT := 3
const SAVE_PATH := "user://save_%d.cfg"
const SECTION := "game"
const STATS_SECTION := "stats"
## Longest name a game can have.
const NAME_MAX_LENGTH := 16

## Counted statistics and the name shown for each, in display order. To add
## one, add it here and call `add_stat` when it happens.
const STAT_NAMES := {
	&"jumps": "Jumps",
	&"hits": "Hits taken",
}

## Names shown in the slot cards. Scenes missing here use the file name.
const SCENE_NAMES := {
	SceneManager.SceneID.INTRO_CUTSCENE: "Intro",
	SceneManager.SceneID.LEVEL_0_START: "Level Start",
}

## Zones of Level Complete from the bottom up: the height where each one
## starts (the Y of its node in level_complete.tscn) and the name shown.
const LEVEL_COMPLETE_ZONES := [
	[0.0, "Beginning"],
	[-21888.0, "Moving Platforms"],
	[-40321.0, "Maze"],
	[-51905.0, "Temporary Platforms"],
]

## Slot being played, or -1 when no game is running (main menu, or a scene
## run from the editor).
var active_slot := -1
## Seconds played in the current game. Only counts while the game isn't
## paused.
var play_time := 0.0
## Statistics of the current game, by key of STAT_NAMES.
var stats := {}

var _scene_path := ""
var _created := 0
## Name the player gave to the current game. Empty uses `default_name`.
var _game_name := ""


func _ready() -> void:
	_reset_stats()
	SignalBus.player_jumped.connect(add_stat.bind(&"jumps"))
	SignalBus.player_hit.connect(add_stat.bind(&"hits"))


func _process(delta: float) -> void:
	# Stops by itself while the tree is paused (pause menu, main menu).
	# Also counts in scenes run from the editor, so the pause menu shows
	# something there too; it's only saved when a slot is active.
	play_time += delta


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()


# ******************* SLOTS *******************
func has_save(slot: int) -> bool:
	return FileAccess.file_exists(SAVE_PATH % (slot + 1))


## What a slot card shows, or an empty dictionary if the slot is empty:
## {"name": String, "scene_name": String, "play_time": float,
## "last_played": int (unix)}.
func get_slot_info(slot: int) -> Dictionary:
	var config := _load(slot)
	if config == null:
		return {}
	var game_name: String = config.get_value(SECTION, "name", "")
	return {
		"name": game_name if game_name != "" else default_name(slot),
		"scene_name": _scene_name(config),
		"play_time": float(config.get_value(SECTION, "play_time", 0.0)),
		"last_played": int(config.get_value(SECTION, "last_played", 0)),
	}


## The slot played most recently, or -1 if all are empty.
func get_last_played_slot() -> int:
	var best := -1
	var best_time := -1
	for slot in SLOT_COUNT:
		var info := get_slot_info(slot)
		if not info.is_empty() and info.last_played > best_time:
			best = slot
			best_time = info.last_played
	return best


func delete_slot(slot: int) -> void:
	if has_save(slot):
		DirAccess.remove_absolute(SAVE_PATH % (slot + 1))


## Name shown for a slot: the one the player gave it, or "Game 1"...
func get_slot_name(slot: int) -> String:
	var info := get_slot_info(slot)
	return info.name if not info.is_empty() else default_name(slot)


## Changes the name of a saved game. An empty name goes back to the default.
func rename_slot(slot: int, new_name: String) -> void:
	var config := _load(slot)
	if config == null:
		return
	var clean := clean_name(new_name)
	config.set_value(SECTION, "name", clean)
	if slot == active_slot:
		_game_name = clean
	var error := config.save(SAVE_PATH % (slot + 1))
	if error != OK:
		push_error("Couldn't rename slot %d: %s" % [slot + 1, error_string(error)])


func default_name(slot: int) -> String:
	return tr("Game %d") % (slot + 1)


func clean_name(text: String) -> String:
	return text.strip_edges().left(NAME_MAX_LENGTH).strip_edges()


# ******************* PLAYING *******************
## Starts a new game in `slot` (overwriting it) from the intro.
func start_new_game(slot: int, game_name := "") -> void:
	active_slot = slot
	_game_name = clean_name(game_name)
	play_time = 0.0
	_reset_stats()
	_created = int(Time.get_unix_time_from_system())
	CheckpointManager.clear_checkpoint()
	# Entering the scene saves the slot.
	SceneManager.goto(SceneManager.SceneID.INTRO_CUTSCENE)


## Loads `slot` and goes to where it was saved.
func continue_game(slot: int) -> void:
	var config := _load(slot)
	if config == null:
		start_new_game(slot)
		return

	active_slot = slot
	_game_name = config.get_value(SECTION, "name", "")
	play_time = float(config.get_value(SECTION, "play_time", 0.0))
	_created = int(config.get_value(SECTION, "created", 0))
	for key in STAT_NAMES:
		stats[key] = int(config.get_value(STATS_SECTION, key, 0))

	var scene_id := _scene_id(config.get_value(SECTION, "scene", ""))
	CheckpointManager.checkpoint_active = config.get_value(SECTION, "checkpoint_active", false)
	CheckpointManager.checkpoint_position = config.get_value(SECTION, "checkpoint_position", Vector2.ZERO)
	CheckpointManager.current_scene = scene_id
	SceneManager.goto(scene_id)


## Saves and stops playing the slot (when going back to the main menu).
func leave_game() -> void:
	save_game()
	active_slot = -1


## Called by SceneManager before changing scene.
func on_scene_entered(scene_id: SceneManager.SceneID) -> void:
	if active_slot < 0 or scene_id == SceneManager.SceneID.MAIN_MENU:
		return
	_scene_path = SceneManager.SCENES[scene_id]
	# A checkpoint only counts in its own level: entering another level
	# starts it from the beginning.
	if CheckpointManager.current_scene != scene_id:
		CheckpointManager.checkpoint_active = false
	save_game()


## Writes the active slot. Does nothing if no slot is being played.
func save_game() -> void:
	if active_slot < 0:
		return
	var config := ConfigFile.new()
	config.set_value(SECTION, "name", _game_name)
	config.set_value(SECTION, "scene", _scene_path)
	config.set_value(SECTION, "checkpoint_active", CheckpointManager.checkpoint_active)
	config.set_value(SECTION, "checkpoint_position", CheckpointManager.checkpoint_position)
	config.set_value(SECTION, "play_time", play_time)
	config.set_value(SECTION, "created", _created)
	config.set_value(SECTION, "last_played", int(Time.get_unix_time_from_system()))
	for key in STAT_NAMES:
		config.set_value(STATS_SECTION, key, stats.get(key, 0))
	var error := config.save(SAVE_PATH % (active_slot + 1))
	if error != OK:
		push_error("Couldn't save slot %d: %s" % [active_slot + 1, error_string(error)])


# ******************* STATISTICS *******************
func add_stat(key: StringName, amount := 1) -> void:
	stats[key] = stats.get(key, 0) + amount


## Statistics of the current game ready to show, in order:
## [["Play time", "12m 30s"], ["Jumps", "154"], ...].
func get_stats_list() -> Array:
	var list := [["Play time", format_play_time(play_time)]]
	for key in STAT_NAMES:
		list.append([STAT_NAMES[key], str(stats.get(key, 0))])
	return list


func _reset_stats() -> void:
	stats = {}
	for key in STAT_NAMES:
		stats[key] = 0


# ******************* FORMATTING *******************
## "1h 05m" or "12m 30s".
static func format_play_time(seconds: float) -> String:
	var total := int(seconds)
	@warning_ignore("integer_division")
	var hours := total / 3600
	@warning_ignore("integer_division")
	var minutes := (total % 3600) / 60
	if hours > 0:
		return "%dh %02dm" % [hours, minutes]
	return "%dm %02ds" % [minutes, total % 60]


## "20 Nov 2026, 08:38" in the player's time zone.
static func format_date(unix_time: int) -> String:
	const MONTHS := ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
			"Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
	var local: int = unix_time + int(Time.get_time_zone_from_system().bias) * 60
	var date := Time.get_datetime_dict_from_unix_time(local)
	var month := TranslationServer.translate(MONTHS[date.month - 1])
	return "%d %s %d, %02d:%02d" % [date.day, month, date.year, date.hour, date.minute]


# ******************* HELPERS *******************
func _load(slot: int) -> ConfigFile:
	if not has_save(slot):
		return null
	var config := ConfigFile.new()
	if config.load(SAVE_PATH % (slot + 1)) != OK:
		return null
	return config


func _scene_id(path: String) -> SceneManager.SceneID:
	for id in SceneManager.SCENES:
		if SceneManager.SCENES[id] == path:
			return id
	# Unknown or missing scene: start from the first level.
	return SceneManager.SceneID.LEVEL_0_START


func _scene_name(config: ConfigFile) -> String:
	var path: String = config.get_value(SECTION, "scene", "")
	var id := _scene_id(path)
	if id == SceneManager.SceneID.LEVEL_COMPLETE:
		return _zone_name(config)
	if SCENE_NAMES.has(id):
		return SCENE_NAMES[id]
	return path.get_file().get_basename().capitalize()


## The zone of Level Complete where the game continues: the one holding the
## last checkpoint, or the first one without a checkpoint.
func _zone_name(config: ConfigFile) -> String:
	var zone_name: String = LEVEL_COMPLETE_ZONES[0][1]
	if not config.get_value(SECTION, "checkpoint_active", false):
		return zone_name
	var checkpoint: Vector2 = config.get_value(SECTION, "checkpoint_position", Vector2.ZERO)
	for zone: Array in LEVEL_COMPLETE_ZONES:
		if checkpoint.y <= zone[0]:
			zone_name = zone[1]
	return zone_name
