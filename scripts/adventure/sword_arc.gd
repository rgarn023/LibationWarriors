extends Node2D
class_name SwordArc
## Chrono Trigger-style melee: wind-up → snappy slash with a thick white crescent
## smear → follow-through. Blade rides the leading edge of the arc.


const LIFE_NORMAL := 0.32
const LIFE_SPECIAL := 0.38

var _t: float = 0.0
var _life: float = LIFE_NORMAL
var _face: Vector2 = Vector2.LEFT
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
	## Hold wind-up, snap through the cut, ease into recover.
	if p < 0.30:
		return (p / 0.30) * 0.18
	if p < 0.48:
		var u := (p - 0.30) / 0.18
		## Ease-in-out cubed for a violent mid-slash
		var s := u * u * (3.0 - 2.0 * u)
		return 0.18 + s * 0.62
	var u2 := (p - 0.48) / 0.52
	return 0.8 + (1.0 - (1.0 - u2) * (1.0 - u2)) * 0.2


func _draw_slash() -> void:
	## Reference: raised behind shoulder → snappy diagonal cut → low follow-through,
	## with a huge white/blue crescent smear on the active frames.
	var start: float
	var end: float
	if _face == Vector2.LEFT:
		start = PI + 1.15 ## raised behind head
		end = PI - 1.25 ## low in front
	elif _face == Vector2.RIGHT:
		start = -1.15
		end = 1.25
	elif _face == Vector2.UP:
		start = -PI * 0.5 - 1.2
		end = -PI * 0.5 + 1.2
	else:
		start = PI * 0.5 - 1.2
		end = PI * 0.5 + 1.2

	var e := _ease_strike(_progress)
	var ang := lerpf(start, end, e)
	var hand := _hand_local()
	var radius := 34.0 if _special else 28.0

	## Crescent only during the violent part of the swing
	if _progress >= 0.28 and _progress <= 0.72:
		var fade := 1.0
		if _progress < 0.36:
			fade = (_progress - 0.28) / 0.08
		elif _progress > 0.58:
			fade = 1.0 - (_progress - 0.58) / 0.14
		fade = clampf(fade, 0.0, 1.0)
		var trail_from := lerpf(start, ang, 0.08)
		_draw_crescent(hand, trail_from, ang, radius * 0.28, radius * 1.08, fade)
		## Leading flash
		var tip := hand + Vector2(cos(ang), sin(ang)) * radius
		draw_circle(tip, 4.0 if _special else 3.0, Color(1, 1, 1, 0.95 * fade))
		draw_circle(tip, 2.0, Color(0.75, 0.9, 1.0, 0.85 * fade))

	## Blade visible on wind-up, strike edge, and follow-through
	_draw_blade(hand, ang, radius * 0.9)


func _draw_crescent(hand: Vector2, a0: float, a1: float, r_in: float, r_out: float, alpha: float) -> void:
	## Filled pie-band (the big white CT slash trail).
	var steps := 18
	var outer: PackedVector2Array = PackedVector2Array()
	var inner: PackedVector2Array = PackedVector2Array()
	for i in steps:
		var t := float(i) / float(steps - 1)
		var a := lerpf(a0, a1, t)
		outer.append(hand + Vector2(cos(a), sin(a)) * r_out)
		inner.append(hand + Vector2(cos(a), sin(a)) * r_in)
	var pts := PackedVector2Array()
	for p in outer:
		pts.append(p)
	for i in range(inner.size() - 1, -1, -1):
		pts.append(inner[i])
	if pts.size() >= 3:
		## Soft blue-white fill
		draw_colored_polygon(pts, Color(0.85, 0.95, 1.0, 0.55 * alpha))
		## Brighter core band (slightly thinner)
		var core := PackedVector2Array()
		var mid_in := (r_in + r_out) * 0.42
		var mid_out := r_out * 0.98
		for i in steps:
			var t := float(i) / float(steps - 1)
			var a := lerpf(a0, a1, t)
			core.append(hand + Vector2(cos(a), sin(a)) * mid_out)
		for i in range(steps - 1, -1, -1):
			var t := float(i) / float(steps - 1)
			var a := lerpf(a0, a1, t)
			core.append(hand + Vector2(cos(a), sin(a)) * mid_in)
		draw_colored_polygon(core, Color(1.0, 1.0, 1.0, 0.88 * alpha))
		## Jagged leading rim
		for i in range(1, steps):
			var t := float(i) / float(steps - 1)
			var a := lerpf(a0, a1, t)
			var p := hand + Vector2(cos(a), sin(a)) * r_out
			var w := lerpf(2.5, 5.5, t)
			draw_circle(p, w * 0.35, Color(1, 1, 1, (0.5 + 0.5 * t) * alpha))


func _draw_chop() -> void:
	var start := -2.0
	var end := 1.4
	if _face == Vector2.LEFT:
		start = PI + 1.4
		end = PI - 0.9
	elif _face == Vector2.RIGHT:
		start = -1.4
		end = 0.9
	var e := _ease_strike(_progress)
	var ang := lerpf(start, end, e)
	var hand := _hand_local() + Vector2(0, lerpf(-8.0, 5.0, e))
	if _progress >= 0.28 and _progress <= 0.7:
		var fade := clampf(1.0 - absf(_progress - 0.45) / 0.25, 0.0, 1.0)
		_draw_crescent(hand, lerpf(start, ang, 0.1), ang, 8.0, 30.0, fade)
	_draw_blade(hand, ang, 26.0)


func _draw_thrust() -> void:
	var hand := _hand_local()
	var e := _ease_strike(_progress)
	var reach := lerpf(-4.0, 22.0 if _special else 16.0, e if _progress < 0.55 else lerpf(1.0, 0.35, (_progress - 0.55) / 0.45))
	var tip := hand + _face * (10.0 + reach)
	var grip := hand + _face * (reach * 0.15)
	if _progress > 0.25 and _progress < 0.7:
		draw_line(grip, tip + _face * 6.0, Color(1, 1, 0.95, 0.9), 5.0 if _special else 3.5)
		draw_circle(tip + _face * 4.0, 4.0, Color(1, 1, 1, 0.9))
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
	## Grip near the painted hand (sheets face left: sword hand is toward viewer).
	if _face == Vector2.RIGHT:
		return Vector2(5, 3)
	if _face == Vector2.LEFT:
		return Vector2(-4, 3)
	if _face == Vector2.UP:
		return Vector2(1, -5)
	return Vector2(1, 6)


func _draw_blade(hand: Vector2, angle: float, length: float) -> void:
	var dir := Vector2(cos(angle), sin(angle))
	var perp := Vector2(-dir.y, dir.x)
	var steel := _color.lightened(0.2)
	var edge := Color(0.95, 0.98, 1.0, 1.0)
	var dark := steel.darkened(0.5)
	var grip_c := Color(0.42, 0.28, 0.16)
	var tip := hand + dir * length
	var guard := hand + dir * 2.5
	var pommel := hand - dir * 5.5

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
			var thick := 3.4 if _shape in ["cutlass", "sword", "katana"] else (2.2 if _shape in ["rapier", "bayonet"] else 2.0)
			if _shape == "cutlass":
				var mid := hand + dir * (length * 0.55) + perp * 2.8
				_draw_thick_poly(hand + dir * 4.0, mid, tip, thick, steel, edge)
			else:
				var half := perp * (thick * 0.5)
				draw_colored_polygon(PackedVector2Array([
					guard + half, tip + perp * 0.3, tip - perp * 0.3, guard - half
				]), steel)
				draw_line(guard, tip, edge, 1.1)
			draw_line(hand + perp * 4.5, hand - perp * 4.5, dark, 2.2)
			draw_line(hand, pommel, grip_c, 2.6)
			draw_circle(pommel, 1.7, dark)


func _draw_thick_poly(a: Vector2, b: Vector2, c: Vector2, thick: float, fill: Color, highlight: Color) -> void:
	var d1 := (b - a).normalized()
	var d2 := (c - b).normalized()
	var p1 := Vector2(-d1.y, d1.x) * (thick * 0.5)
	var p2 := Vector2(-d2.y, d2.x) * (thick * 0.35)
	var pts := PackedVector2Array([a + p1, b + p1, c, b - p2, a - p1])
	draw_colored_polygon(pts, fill)
	draw_line(a, c, highlight, 1.0)
