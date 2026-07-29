extends RefCounted
class_name CombatFx
## Pixel slash / special burst VFX using Node2D draw (no ColorRect under Node2D).


static func spawn_slash(parent: Node2D, origin: Vector2, facing: Vector2, color: Color, is_special: bool = false) -> void:
	var fx := _SlashFx.new()
	fx.z_index = 30
	fx.position = origin
	fx.setup(facing, color, is_special)
	parent.add_child(fx)
	var tw := parent.get_tree().create_tween()
	tw.tween_property(fx, "scale", Vector2(1.35, 1.35) if is_special else Vector2(1.15, 1.15), 0.14)
	tw.parallel().tween_property(fx, "modulate:a", 0.0, 0.18)
	tw.tween_callback(func():
		if is_instance_valid(fx):
			fx.queue_free()
	)


static func spawn_enemy_swipe(parent: Node2D, origin: Vector2, facing: Vector2, color: Color) -> void:
	var fx := _SwipeFx.new()
	fx.z_index = 28
	fx.position = origin
	fx.setup(facing, color)
	parent.add_child(fx)
	var tw := parent.get_tree().create_tween()
	tw.tween_property(fx, "modulate:a", 0.0, 0.16)
	tw.tween_callback(func():
		if is_instance_valid(fx):
			fx.queue_free()
	)


static func spawn_hit_spark(parent: Node2D, pos: Vector2, color: Color) -> void:
	var fx := _SparkFx.new()
	fx.z_index = 32
	fx.position = pos
	fx.setup(color)
	parent.add_child(fx)
	var tw := parent.get_tree().create_tween()
	tw.tween_property(fx, "scale", Vector2(1.8, 1.8), 0.12)
	tw.parallel().tween_property(fx, "modulate:a", 0.0, 0.14)
	tw.tween_callback(func():
		if is_instance_valid(fx):
			fx.queue_free()
	)


class _SlashFx extends Node2D:
	var _facing: Vector2 = Vector2.DOWN
	var _color: Color = Color.WHITE
	var _special: bool = false

	func setup(facing: Vector2, color: Color, is_special: bool) -> void:
		_facing = facing.normalized() if facing != Vector2.ZERO else Vector2.DOWN
		_color = color
		_special = is_special
		queue_redraw()

	func _draw() -> void:
		var ang := _facing.angle()
		var span := 1.35 if _special else 0.95
		var radius := 26.0 if _special else 18.0
		var blades := 7 if _special else 5
		for i in blades:
			var t := float(i) / float(maxi(1, blades - 1))
			var a := ang - span * 0.5 + span * t
			var p1 := Vector2(cos(a), sin(a)) * (radius * 0.35)
			var p2 := Vector2(cos(a), sin(a)) * radius
			draw_line(p1, p2, _color if not _special else _color.lightened(0.25), 3.0 if _special else 2.0)
			draw_rect(Rect2(p2 - Vector2(1.5, 1.5), Vector2(3, 3)), Color(1, 1, 0.85, 0.95), true)
		if _special:
			for j in 10:
				var a2 := TAU * float(j) / 10.0
				var p := Vector2(cos(a2), sin(a2)) * 22.0
				draw_rect(Rect2(p - Vector2(2, 2), Vector2(4, 4)), _color, true)
			draw_rect(Rect2(-8, -8, 16, 16), Color(_color.r, _color.g, _color.b, 0.55), true)


class _SwipeFx extends Node2D:
	var _facing: Vector2 = Vector2.LEFT
	var _color: Color = Color.WHITE

	func setup(facing: Vector2, color: Color) -> void:
		_facing = facing.normalized() if facing != Vector2.ZERO else Vector2.LEFT
		_color = color
		queue_redraw()

	func _draw() -> void:
		var ang := _facing.angle()
		for i in 4:
			var t := float(i) / 3.0
			var a := ang - 0.55 + 1.1 * t
			var p := Vector2(cos(a), sin(a)) * 14.0
			var c := Color(_color.r, _color.g * 0.5, _color.b * 0.5, 0.9)
			draw_line(p * 0.4, p * 1.15, c, 3.0)


class _SparkFx extends Node2D:
	var _color: Color = Color.WHITE

	func setup(color: Color) -> void:
		_color = color
		queue_redraw()

	func _draw() -> void:
		for i in 5:
			var a := TAU * float(i) / 5.0
			var p := Vector2(cos(a), sin(a)) * 4.0
			draw_rect(Rect2(p - Vector2(1.5, 1.5), Vector2(3, 3)), _color, true)
