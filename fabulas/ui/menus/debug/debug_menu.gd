extends CanvasLayer

## Autoload for the Debug Menu: keeps the state of every cheat/toggle and
## emits a signal when one changes, so the player, the HUD, etc. can react.
##
## Only works when the game is run from the Godot editor. In an exported game
## it stays off (the node is kept because other scripts read its state).
##
## While it's open it takes all keyboard/controller input, so nothing behind
## it (the game, the pause menu, the settings) reacts to the same keys.

# ====================== SIGNALS ======================
signal collisions_visibility_changed(value: bool)
signal god_mode_changed(value: bool)
signal info_panel_changed(value: bool)

# ====================== CONSTANTS ======================
## Values of the "Game speed" cheat (Engine.time_scale).
const GAME_SPEEDS: Array[float] = [0.25, 0.5, 1.0, 1.5, 2.0]

## Page node → title shown at the top.
const PAGE_TITLES := {
	"MainMenu": "DEBUG",
	"CheatsMenu": "DEBUG › CHEATS",
	"SceneMenu": "DEBUG › SCENES",
	"DisplayMenu": "DEBUG › DISPLAY",
	"SaveMenu": "DEBUG › SAVE",
}

# ====================== REFERENCES ======================
@onready var menu_container: DebugMenuContainer = %MenuContainer
@onready var title_label: Label = %TitleLabel
@onready var info_panel: CanvasLayer = $InfoPanel
@onready var badge: CanvasLayer = $Badge
@onready var badge_label: Label = %BadgeLabel

# ====================== STATE ======================
## False in an exported game: the menu can't be opened.
var enabled := OS.has_feature("editor")
var is_open := false

var show_collisions: bool = false:
	set(value):
		show_collisions = value
		collisions_visibility_changed.emit(value)

var god_mode: bool = false:
	set(value):
		god_mode = value
		god_mode_changed.emit(value)
		_update_badge()

var show_info_panel: bool = false:
	set(value):
		show_info_panel = value
		info_panel_changed.emit(value)

## Engine.time_scale while no effect changes it (the knockback freeze frame
## multiplies it and gives it back afterwards).
var game_speed: float = 1.0:
	set(value):
		game_speed = value
		Engine.time_scale = value
		_update_badge()

## Whether the game was already paused when the menu opened (pause menu,
## main menu...), so closing the menu leaves it as it was.
var _was_paused := false
## Control that had the focus before opening, given back on close.
var _previous_focus: Control


# ************************ CALLBACKS ************************
func _ready() -> void:
	visible = false
	# Development tool: it stays in English.
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	if not enabled:
		# Nothing of it runs: no input, no info panel, no badge.
		process_mode = Node.PROCESS_MODE_DISABLED
		info_panel.process_mode = Node.PROCESS_MODE_DISABLED
		info_panel.visible = false
		badge.visible = false
		return
	process_mode = Node.PROCESS_MODE_ALWAYS  # Keeps working while the game is paused.
	collisions_visibility_changed.connect(_on_collisions_visibility_changed)
	menu_container.page_changed.connect(_on_page_changed)
	_update_badge()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_menu"):
		toggle()
		get_viewport().set_input_as_handled()
		return
	if not is_open:
		return
	# Keys and controller go to the menu only. The mouse is left alone.
	if event is InputEventKey or event is InputEventJoypadButton \
			or event is InputEventJoypadMotion:
		menu_container.handle_input(event)
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	# While the collisions are visible they're redrawn every frame, so moving
	# shapes are drawn where they are.
	if show_collisions and get_tree().current_scene:
		_refresh_collision_shapes(get_tree().current_scene)


# ******************* PUBLIC METHODS *******************
func toggle() -> void:
	if is_open:
		close()
	else:
		open()


func open() -> void:
	if is_open or not enabled:
		return
	is_open = true
	_was_paused = get_tree().paused
	get_tree().paused = true
	# Nothing behind keeps the focus, so the arrows don't move it.
	_previous_focus = get_viewport().gui_get_focus_owner()
	if _previous_focus:
		_previous_focus.release_focus()
	menu_container.show_menu("MainMenu")
	visible = true
	_update_badge()


## Closes the menu and leaves the game paused or running, as it was before.
func close() -> void:
	if not is_open:
		return
	is_open = false
	visible = false
	get_tree().paused = _was_paused
	if is_instance_valid(_previous_focus) and _previous_focus.is_visible_in_tree():
		GameMenus.focus_quietly(_previous_focus)
	_previous_focus = null
	_update_badge()


## The game speed as shown in the menu ("x0.5", "x2"...).
func speed_text(speed := game_speed) -> String:
	return "x" + String.num(speed).trim_suffix(".0")


## Closes the menu and any game menu behind it and goes to `scene_id`
## (optionally to one of its debug teleport markers).
func go_to_scene(scene_id: SceneManager.SceneID, marker_name := "") -> void:
	close()
	GameMenus.close_all()
	# A fade still playing from this scene would unpause the next one (e.g.
	# the main menu) when it ends.
	if TransitionsScreen.animation_player.is_playing():
		TransitionsScreen.animation_player.stop()
		TransitionsScreen.color_rect.visible = false
	if scene_id == SceneManager.SceneID.MAIN_MENU:
		# Same as exiting from the pause menu.
		SaveManager.leave_game()
	SceneManager.goto(scene_id, marker_name)


# ******************* SIGNAL CALLBACKS *******************
func _on_collisions_visibility_changed(value: bool) -> void:
	get_tree().debug_collisions_hint = value
	_refresh_collision_shapes(get_tree().root)


func _on_page_changed(page_name: String) -> void:
	title_label.text = PAGE_TITLES.get(page_name, "DEBUG")


# ******************* PRIVATE METHODS *******************
## The corner label that reminds which cheats are on while playing.
func _update_badge() -> void:
	if not is_node_ready() or not enabled:
		return
	var parts: PackedStringArray = []
	if god_mode:
		parts.append("GOD")
	if game_speed != 1.0:
		parts.append(speed_text())
	badge_label.text = "  ".join(parts)
	badge.visible = not parts.is_empty() and not is_open


func _refresh_collision_shapes(node: Node) -> void:
	if node is CollisionShape2D or node is CollisionPolygon2D:
		node.queue_redraw()
	for child in node.get_children():
		_refresh_collision_shapes(child)
