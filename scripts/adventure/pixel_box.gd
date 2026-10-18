extends Node2D
## Filled rectangle drawn via CanvasItem (reliable under Node2D on mobile).
## Prefer this over ColorRect children of Node2D / Area2D.

var color: Color = Color.WHITE
var size: Vector2 = Vector2(8, 8)
var centered: bool = false


func configure(p_color: Color, p_size: Vector2, p_centered: bool = false) -> void:
	color = p_color
	size = p_size
	centered = p_centered
	queue_redraw()


func _draw() -> void:
	var origin := -size * 0.5 if centered else Vector2.ZERO
	draw_rect(Rect2(origin, size), color, true)
