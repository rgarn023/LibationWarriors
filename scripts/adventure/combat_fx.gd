extends RefCounted
class_name CombatFx
## Attack smear / impact VFX. Slash trails sell the swing; no second weapon mesh.


static func spawn_slash(parent: Node2D, origin: Vector2, facing: Vector2, color: Color, is_special: bool = false, style: String = "slash") -> void:
	var fx := _SlashSmear.new()
	fx.z_index = 30
	fx.position = origin
	fx.setup(facing, color, is_special, style)
	parent.add_child(fx)
	var dur := 0.2 if is_special else 0.16
	var tw := parent.get_tree().create_tween()
	tw.tween_property(fx, "scale", Vector2(1.25, 1.25) if is_special else Vector2(1.1, 1.1), dur * 0.7)
	tw.parallel().tween_property(fx, "modulate:a", 0.0, dur)
	tw.tween_callback(func():
		if is_instance_valid(fx):
			fx.queue_free()
	)


static func spawn_enemy_swipe(parent: Node2D, origin: Vector2, facing: Vector2, color: Color) -> void:
	spawn_slash(parent, origin, facing, color, false, "slash")


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


static func spawn_cast_burst(parent: Node2D, origin: Vector2, facing: Vector2, color: Color) -> void:
	var fx := _CastBurst.new()
	fx.z_index = 30
	fx.position = origin + facing * 8.0
	fx.setup(color)
	parent.add_child(fx)
	var tw := parent.get_tree().create_tween()
	tw.tween_property(fx, "scale", Vector2(1.6, 1.6), 0.14)
	tw.parallel().tween_property(fx, "modulate:a", 0.0, 0.16)
	tw.tween_callback(func():
		if is_instance_valid(fx):
			fx.queue_free()
	)


class _SlashSmear extends Node2D:
	var _facing: Vector2 = Vector2.DOWN
	var _color: Color = Color.WHITE
	var _special: bool = false
	var _style: String = "slash"

	func setup(facing: Vector2, color: Color, is_special: bool, style: String) -> void:
		_facing = facing.normalized() if facing != Vector2.ZERO else Vector2.DOWN
		_color = color
		_special = is_special
		_style = style
		queue_redraw()

	func _draw() -> void:
		var ang := _facing.angle()
		if _style == "thrust" or _style == "jab":
			var tip := _facing * (28.0 if _special else 20.0)
			draw_line(_facing * 4.0, tip, Color(1, 1, 0.9, 0.95), 3.0 if _special else 2.0)
			draw_line(_facing * 6.0, tip * 0.85, _color, 5.0 if _special else 3.5)
			draw_circle(tip, 3.0, Color(1, 1, 1, 0.9))
			return
		if _style == "cast":
			for j in 8:
				var a2 := TAU * float(j) / 8.0
				var p := Vector2(cos(a2), sin(a2)) * (14.0 if _special else 10.0)
				draw_circle(p, 2.5, _color)
			draw_circle(Vector2.ZERO, 5.0, Color(_color.r, _color.g, _color.b, 0.7))
			return
		# Thick JRPG crescent (backup VFX if SwordArc isn't used)
		var span := 2.0 if _special else 1.55
		if _style == "chop":
			span = 1.25 if _special else 1.0
		var radius := 34.0 if _special else 26.0
		var blades := 12 if _special else 10
		for i in blades:
			var t := float(i) / float(maxi(1, blades - 1))
			var a := ang - span * 0.55 + span * t
			if _style == "chop":
				a = ang - 1.0 + 1.7 * t
			var p1 := Vector2(cos(a), sin(a)) * (radius * 0.18)
			var p2 := Vector2(cos(a), sin(a)) * radius
			var width := lerpf(8.0, 2.0, t)
			var c := Color(1.0, 1.0, 0.95, lerpf(0.95, 0.2, t))
			draw_line(p1, p2, c, width)
			draw_line(p1, p2, Color(_color.r, _color.g, _color.b, c.a * 0.5), width * 0.4)
		var tip_a := ang + span * 0.42
		var tip := Vector2(cos(tip_a), sin(tip_a)) * radius
		draw_circle(tip, 4.0 if _special else 3.0, Color(1, 1, 1, 0.95))


class _SparkFx extends Node2D:
	var _color: Color = Color.WHITE

	func setup(color: Color) -> void:
		_color = color
		queue_redraw()

	func _draw() -> void:
		for i in 6:
			var a := TAU * float(i) / 6.0
			var p := Vector2(cos(a), sin(a)) * 5.0
			draw_rect(Rect2(p - Vector2(1.5, 1.5), Vector2(3, 3)), _color, true)


class _CastBurst extends Node2D:
	var _color: Color = Color.WHITE

	func setup(color: Color) -> void:
		_color = color
		queue_redraw()

	func _draw() -> void:
		draw_circle(Vector2.ZERO, 6.0, Color(_color.r, _color.g, _color.b, 0.75))
		for i in 6:
			var a := TAU * float(i) / 6.0
			draw_line(Vector2.ZERO, Vector2(cos(a), sin(a)) * 12.0, _color, 2.0)
