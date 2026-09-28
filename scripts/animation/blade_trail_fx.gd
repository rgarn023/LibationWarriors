extends Node2D
class_name BladeTrailFx
## Tiny supplemental slash near the blade. Not the primary attack visual.
## Lifetime covers main-slash + impact only; never larger than ~1.25× character height.


var _life: float = 0.12
var _max_life: float = 0.12
var _facing: Vector2 = Vector2.LEFT
var _color: Color = Color(1, 1, 0.95, 0.7)
var _char_height: float = 34.0


func play(facing: Vector2, char_height: float, color: Color = Color(1, 1, 0.95, 0.75)) -> void:
	_facing = WeaponData.cardinal(facing)
	_char_height = maxf(8.0, char_height)
	_color = color
	_max_life = 0.12
	_life = _max_life
	z_index = 20
	queue_redraw()


func _process(delta: float) -> void:
	_life -= delta
	queue_redraw()
	if _life <= 0.0:
		queue_free()


func _draw() -> void:
	var t := 1.0 - clampf(_life / _max_life, 0.0, 1.0)
	var alpha := (1.0 - t) * _color.a
	var reach := minf(_char_height * 1.15, _char_height * 1.25)
	var hand := _facing * 4.0 + Vector2(0, -2.0)
	var tip := hand + _facing * reach * 0.55
	var perp := Vector2(-_facing.y, _facing.x)
	# Thin arc close to the blade tip — never a screen-filling crescent.
	var c := Color(_color.r, _color.g, _color.b, alpha)
	draw_line(hand + perp * 2.0, tip, c, 2.0)
	draw_line(hand, tip + perp * 1.5, Color(1, 1, 1, alpha * 0.7), 1.0)
