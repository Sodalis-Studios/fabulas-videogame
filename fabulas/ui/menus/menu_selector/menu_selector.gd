extends Control
class_name MenuSelector

## Shows which button of a menu is selected: the button grows a little and a
## marker sits to its left. It follows the focus, so it works the same with
## mouse, keyboard and controller (hovering a button selects it).
##
## Put it anywhere in the menu scene (outside containers, so they don't move
## it) and point `buttons_container` at the node that holds the buttons.

## Every Button inside this node (at any depth) is tracked.
@export var buttons_container: Control
## Marker image, e.g. a feather. If empty, an arrow is drawn instead. Import
## it with mipmaps so it stays smooth when drawn small.
@export var icon: Texture2D
## Size the marker is drawn at. Match the icon's proportions.
@export var marker_size := Vector2(42, 42)
## Tint of the marker. White keeps the icon's own colours.
@export var marker_color := Color(0.96, 0.93, 0.88)
## Space between the marker and the button's text.
@export var gap := 16.0
## Scale of the selected button (1 = no change).
@export var selected_scale := 1.12
## Point the button grows from, relative to its size: (0.5, 0.5) is the
## centre, (0, 0.5) the left edge (for left-aligned menus).
@export var grow_from := Vector2(0.5, 0.5)
## How fast the button grows and the marker slides (higher is faster).
@export var speed := 16.0

var _buttons: Array[Button] = []
var _was_visible := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Uses the icon's mipmaps, so it doesn't look jagged when shrunk.
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	top_level = true
	size = marker_size
	hide()
	if buttons_container:
		_collect_buttons(buttons_container)
	for button in _buttons:
		button.mouse_entered.connect(_on_button_hovered.bind(button))


func _process(delta: float) -> void:
	var weight := 1.0 - exp(-speed * delta)
	var focused := get_viewport().gui_get_focus_owner()
	var selected: Button = null

	for button in _buttons:
		var is_selected := button == focused and button.is_visible_in_tree()
		if is_selected:
			selected = button
		var target := Vector2.ONE * (selected_scale if is_selected else 1.0)
		# Containers reset the scale when they re-sort, so it's set again
		# every frame.
		button.pivot_offset = button.size * grow_from
		button.scale = button.scale.lerp(target, weight)

	if selected == null:
		hide()
		_was_visible = false
		return

	var target_position := _marker_position(selected)
	# Jump straight there when it appears, slide between buttons after that.
	global_position = target_position if not _was_visible \
			else global_position.lerp(target_position, weight)
	_was_visible = true
	show()


func _draw() -> void:
	if icon:
		draw_texture_rect(icon, Rect2(Vector2.ZERO, marker_size), false, marker_color)
		return
	# Arrow pointing right, at the button.
	var w := marker_size.x
	var h := marker_size.y
	draw_colored_polygon(PackedVector2Array([
		Vector2(w * 0.15, 0.0),
		Vector2(w, h * 0.5),
		Vector2(w * 0.15, h),
		Vector2(w * 0.4, h * 0.5),
	]), marker_color)


## Left of the text (not of the button's box), vertically centred on it.
func _marker_position(button: Button) -> Vector2:
	var rect := button.get_global_rect()
	# atr: the text on screen, which depends on the language.
	var text_width := button.get_theme_font("font").get_string_size(
			button.atr(button.text), HORIZONTAL_ALIGNMENT_LEFT, -1,
			button.get_theme_font_size("font_size")).x * button.scale.x
	var text_left := rect.get_center().x - text_width / 2.0
	return Vector2(text_left - gap - marker_size.x, rect.get_center().y - marker_size.y / 2.0)


func _collect_buttons(node: Node) -> void:
	for child in node.get_children():
		if child is Button:
			_buttons.append(child)
		_collect_buttons(child)


func _on_button_hovered(button: Button) -> void:
	# The button already plays its own hover sound.
	if button.focus_mode != Control.FOCUS_NONE and not button.has_focus():
		GameMenus.focus_quietly(button)
