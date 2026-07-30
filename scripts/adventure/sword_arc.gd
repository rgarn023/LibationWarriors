extends Node2D
class_name SwordArc
## Classic JRPG melee swing: the carried blade rotates through a wide arc with a
## thick white crescent smear (Chrono Trigger / SNES slash style).


const LIFE_NORMAL := 0.28
const LIFE_SPECIAL := 0.34

var _t: float = 0.0
var _life: float = LIFE_NORMAL
var _face: Vector2 = Vector2.RIGHT
var _shape: String = "sword"
var _color: Color = Color(0.8, 0.8, 0.9)
var _special: bool = false
var _style: String = "slash"
var _progress: float = 0.0


func play(facing: Vector2, shape: String, color: Color, is_special: bool = false, style: String = "slash") -> void:
	_face = WeaponData.cardinal(facing)
	_shape = shape
	_color = color
	_special = is_special
	_style = style
	_life = LIFE_SPECIAL if is_special else LIFE_NORMAL
	_t = _life
	_progress = 0.0
	z_index = 28
	z_as_relative = true
	queue_redraw()


func _process(delta: float) -> void:
	_t -= delta
	_progress = 1.0 - clampf(_t / maxf(0.001, _life), 0.0, 1.0)
	queue_redraw()
	if _t <= 0.0:
		queue_free()


func _draw() -> void:
	match _style:
		"thrust", "jab":
			_draw_thrust()
		"cast":
			_draw_cast()
		"chop", "slam":
			_draw_chop()
		_:
			_draw_slash()


func _ease_strike(p: float) -> float:
	## Slow wind-up, snappy cut, soft recover.
	if p < 0.28:
		return (p / 0.28) * 0.22
	if p < 0.55:
		var u := (p - 0.28) / 0.27
		return 0.22 + u * u * 0.58
	var u2 := (p - 0.55) / 0.45
	return 0.8 + (1.0 - (1.0 - u2) * (1.0 - u2)) * 0.2


func _draw_slash() -> void:
	var side := 1.0 if _face.x >= 0.0 else -1.0
	if _face.x == 0.0:
		side = 1.0
	var base := _face.angle()
	var start := base - side * (2.05 if _special else 1.75)
	var end := base + side * (1.45 if _special else 1.15)
	var e := _ease_strike(_progress)
	var ang := lerpf(start, end, e)
	var hand := _hand_local()
	var radius := 30.0 if _special else 24.0

	# Crescent smear — solid fan wedges (the iconic JRPG look)
	if _progress > 0.18 and _progress < 0.85:
		var smear_a := clampf((_progress - 0.18) / 0.2, 0.0, 1.0)
		if _progress > 0.55:
			smear_a = clampf(1.0 - (_progress - 0.55) / 0.3, 0.0, 1.0)
		var trail_start := lerpf(start, ang, 0.15)
		var blades := 11 if _special else 9
		for i in blades:
			var t := float(i) / float(blades - 1)
			var a := lerpf(trail_start, ang, t)
			var inner := radius * 0.22
			var outer := radius * lerpf(0.75, 1.05, t)
			var p0 := hand + Vector2(cos(a), sin(a)) * inner
			var p1 := hand + Vector2(cos(a), sin(a)) * outer
			var w := lerpf(7.0, 2.0, t) * (1.15 if _special else 1.0)
			var c := Color(1.0, 1.0, 0.95, smear_a * lerpf(0.95, 0.25, t))
			draw_line(p0, p1, c, w)
			# tinted core
			var c2 := Color(_color.r, _color.g, _color.b, c.a * 0.55)
			draw_line(p0, p1, c2, w * 0.45)
		# Leading edge flash
		var tip := hand + Vector2(cos(ang), sin(ang)) * radius
		draw_circle(tip, 3.5 if _special else 2.5, Color(1, 1, 1, smear_a))

	# Carried blade at current angle
	_draw_blade(hand, ang, radius * 0.92)


func _draw_chop() -> void:
	var side := 1.0 if _face.x >= 0.0 else -1.0
	var base := _face.angle()
	var start := base - side * 1.4 - 0.9
	var end := base + side * 0.4 + 0.9
	var e := _ease_strike(_progress)
	var ang := lerpf(start, end, e)
	var hand := _hand_local() + Vector2(0, lerpf(-6.0, 4.0, e))
	if _progress > 0.2 and _progress < 0.8:
		var a0 := lerpf(start, ang, 0.2)
		for i in 8:
			var t := float(i) / 7.0
			var a := lerpf(a0, ang, t)
			var p0 := hand + Vector2(cos(a), sin(a)) * 6.0
			var p1 := hand + Vector2(cos(a), sin(a)) * 26.0
			draw_line(p0, p1, Color(1, 1, 0.92, lerpf(0.9, 0.2, t)), lerpf(6.0, 2.0, t))
	_draw_blade(hand, ang, 26.0)


func _draw_thrust() -> void:
	var hand := _hand_local()
	var e := _ease_strike(_progress)
	var reach := lerpf(-4.0, 22.0 if _special else 16.0, e if _progress < 0.55 else lerpf(1.0, 0.35, (_progress - 0.55) / 0.45))
	var tip := hand + _face * (10.0 + reach)
	var grip := hand + _face * (reach * 0.15)
	if _progress > 0.25 and _progress < 0.7:
		draw_line(grip, tip + _face * 6.0, Color(1, 1, 0.9, 0.85), 4.0 if _special else 3.0)
	_draw_blade(grip, _face.angle(), 18.0)


func _draw_cast() -> void:
	var hand := _hand_local() + Vector2(0, lerpf(-8.0, -2.0, _progress))
	var pulse := 0.5 + 0.5 * sin(_progress * TAU * 2.0)
	for j in 8:
		var a := TAU * float(j) / 8.0 + _progress * 3.0
		var p := hand + Vector2(cos(a), sin(a)) * (10.0 + 4.0 * pulse)
		draw_circle(p, 2.2, Color(_color.r, _color.g, _color.b, 0.85))
	draw_circle(hand, 5.0, Color(_color.r, _color.g, _color.b, 0.7))
	_draw_blade(hand, _face.angle() + PI * 0.5, 14.0)


func _hand_local() -> Vector2:
	## Offset from character center toward the striking hand.
	if _face == Vector2.RIGHT:
		return Vector2(6, 2)
	if _face == Vector2.LEFT:
		return Vector2(-6, 2)
	if _face == Vector2.UP:
		return Vector2(2, -4)
	return Vector2(2, 5)


func _draw_blade(hand: Vector2, angle: float, length: float) -> void:
	var dir := Vector2(cos(angle), sin(angle))
	var perp := Vector2(-dir.y, dir.x)
	var steel := _color.lightened(0.15)
	var edge := Color(1, 1, 1, 0.95)
	var dark := steel.darkened(0.45)
	var grip_c := Color(0.42, 0.28, 0.16)
	var tip := hand + dir * length
	var guard := hand + dir * 3.0
	var pommel := hand - dir * 5.0

	match _shape:
		"axe":
			draw_line(hand - dir * 2.0, hand + dir * (length * 0.7), grip_c.lightened(0.1), 3.0)
			var head := hand + dir * (length * 0.65)
			var pts := PackedVector2Array([
				head - perp * 8.0 - dir * 2.0,
				head - perp * 10.0 + dir * 4.0,
				head + perp * 2.0 + dir * 5.0,
				head + perp * 3.0 - dir * 1.0,
			])
			draw_colored_polygon(pts, steel)
			draw_polyline(pts + PackedVector2Array([pts[0]]), dark, 1.0, true)
		"fist":
			draw_circle(hand + dir * 6.0, 5.0, steel)
			draw_circle(hand + dir * 6.0, 3.0, edge)
		"staff", "rod", "lute":
			draw_line(pommel, tip, grip_c.lightened(0.2), 3.0)
			draw_circle(tip, 4.5, _color.lightened(0.2))
			draw_circle(tip, 2.0, edge)
		"flask", "bottle":
			draw_line(hand, hand + dir * 8.0, steel, 2.0)
			draw_rect(Rect2(hand + dir * 6.0 - Vector2(4, 4), Vector2(8, 10)), _color, true)
		_:
			# Sword / cutlass / katana / dagger family — tapered blade + guard
			var thick := 3.2 if _shape in ["cutlass", "sword", "katana"] else (2.2 if _shape in ["rapier", "bayonet"] else 2.0)
			if _shape == "cutlass":
				# Slight curve via mid control point
				var mid := hand + dir * (length * 0.55) + perp * (2.5 * (1.0 if _face.x >= 0.0 else -1.0))
				_draw_thick_poly(hand + dir * 4.0, mid, tip, thick, steel, edge)
			else:
				var half := perp * (thick * 0.5)
				var base_l := guard + half
				var base_r := guard - half
				var tip_l := tip + perp * 0.4
				var tip_r := tip - perp * 0.4
				draw_colored_polygon(PackedVector2Array([base_l, tip_l, tip_r, base_r]), steel)
				draw_line(guard, tip, edge, 1.0)
			# Guard + grip
			draw_line(hand + perp * 4.0, hand - perp * 4.0, dark, 2.0)
			draw_line(hand, pommel, grip_c, 2.5)
			draw_circle(pommel, 1.6, dark)


func _draw_thick_poly(a: Vector2, b: Vector2, c: Vector2, thick: float, fill: Color, highlight: Color) -> void:
	var d1 := (b - a).normalized()
	var d2 := (c - b).normalized()
	var p1 := Vector2(-d1.y, d1.x) * (thick * 0.5)
	var p2 := Vector2(-d2.y, d2.x) * (thick * 0.35)
	var pts := PackedVector2Array([a + p1, b + p1, c, b - p2, a - p1])
	draw_colored_polygon(pts, fill)
	draw_line(a, c, highlight, 1.0)
