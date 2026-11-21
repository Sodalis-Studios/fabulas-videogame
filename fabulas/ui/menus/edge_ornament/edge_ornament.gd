@tool
extends Node2D
class_name EdgeOrnament

## Decorative border: draws `texture` repeated from top to bottom along one
## edge of its parent Control (for example the side panel of the pause menu).
##
## It's a Node2D on purpose: containers such as a PanelContainer resize every
## Control child, but leave a Node2D alone. It still moves, hides and shows
## together with its parent, and follows its size.

enum Edge { RIGHT, LEFT }

## Image of one piece of the border, made so it repeats without a seam.
@export var texture: Texture2D:
	set(value):
		texture = value
		queue_redraw()
## Edge of the parent it's drawn on.
@export var edge := Edge.RIGHT:
	set(value):
		edge = value
		queue_redraw()
## Width it's drawn at. The height of each piece keeps the image's proportions.
@export var width := 72.0:
	set(value):
		width = value
		queue_redraw()
## How much of it sits outside the parent: 0.5 centres it on the edge, 0 keeps
## it all inside.
@export_range(0.0, 1.0) var overhang := 0.5:
	set(value):
		overhang = value
		queue_redraw()
## Tint. White keeps the image's own colours.
@export var tint := Color.WHITE:
	set(value):
		tint = value
		queue_redraw()


func _ready() -> void:
	# Uses the image's mipmaps, so it doesn't look jagged when shrunk.
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var parent := get_parent() as Control
	if parent:
		parent.resized.connect(queue_redraw)


func _draw() -> void:
	var parent := get_parent() as Control
	if parent == null or texture == null:
		return
	var image_size := texture.get_size()
	# Whole pixels, so the pieces meet without a hairline between them.
	var piece_height := roundf(width * image_size.y / image_size.x)
	var x := parent.size.x - width * (1.0 - overhang) if edge == Edge.RIGHT \
			else -width * overhang
	var y := 0.0
	while y < parent.size.y:
		# The last piece is cut at the bottom of the parent.
		var height := minf(piece_height, parent.size.y - y)
		var source := Rect2(Vector2.ZERO, Vector2(image_size.x, image_size.y * height / piece_height))
		draw_texture_rect_region(texture, Rect2(x, y, width, height), source, tint)
		y += piece_height
