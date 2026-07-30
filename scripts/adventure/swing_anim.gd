extends RefCounted
class_name SwingAnim
## Builds a short attack strip: body + faction weapon swinging through a real arc.
## Closest match to classic JRPG swing frames without shipping new art sheets.

const FRAME_W := 64
const FRAME_H := 80
const FRAME_COUNT := 5


static func build_strip(base_tex: Texture2D, region: Rect2, shape: String, facing: Vector2, color: Color, is_special: bool = false) -> Dictionary:
	## Returns {texture: ImageTexture, frame_count: int, durations: Array}
	var face := WeaponData.cardinal(facing)
	var src := _frame_image(base_tex, region)
	if src == null:
		return {}
	# Sheets face rightish; mirror body when swinging left.
	if face.x < 0.0:
		src.flip_x()
		face = Vector2.LEFT
	var strip := Image.create(FRAME_W * FRAME_COUNT, FRAME_H, false, Image.FORMAT_RGBA8)
	strip.fill(Color(0, 0, 0, 0))
	var hand := _hand_pivot(face)
	var angles := _swing_angles(shape, face, is_special)
	var body_shift := _body_shifts(face, is_special)
	for i in FRAME_COUNT:
		var canvas := Image.create(FRAME_W, FRAME_H, false, Image.FORMAT_RGBA8)
		canvas.fill(Color(0, 0, 0, 0))
		var shift: Vector2i = body_shift[i]
		_blit(canvas, src, shift.x, shift.y)
		if i >= 1 and i <= 3:
			_soft_cover_static_weapon(canvas, face, src)
		var ang: float = angles[i]
		_draw_weapon(canvas, hand + shift, ang, shape, color, is_special)
		if i == 2 or i == 3:
			_draw_smear(canvas, hand + shift, ang, face, color, is_special, shape)
		strip.blit_rect(canvas, Rect2i(0, 0, FRAME_W, FRAME_H), Vector2i(i * FRAME_W, 0))
	var tex := ImageTexture.create_from_image(strip)
	return {
		"texture": tex,
		"frame_count": FRAME_COUNT,
		"durations": [0.06, 0.07, 0.05, 0.07, 0.08] if not is_special else [0.05, 0.08, 0.05, 0.08, 0.09],
		"hit_frame": 2,
	}


static func _frame_image(tex: Texture2D, region: Rect2) -> Image:
	if tex == null:
		return null
	var full := tex.get_image()
	if full == null:
		# Atlas/compressed fallback
		var img := Image.create(FRAME_W, FRAME_H, false, Image.FORMAT_RGBA8)
		return img
	if full.get_format() != Image.FORMAT_RGBA8:
		full = full.duplicate()
		full.convert(Image.FORMAT_RGBA8)
	var rx := int(region.position.x)
	var ry := int(region.position.y)
	var rw := int(region.size.x)
	var rh := int(region.size.y)
	if rw <= 0 or rh <= 0:
		rw = FRAME_W
		rh = FRAME_H
	if rx + rw > full.get_width() or ry + rh > full.get_height():
		return full.duplicate()
	return full.get_region(Rect2i(rx, ry, rw, rh))


static func _hand_pivot(face: Vector2) -> Vector2i:
	if face.x > 0.0:
		return Vector2i(42, 46)
	if face.x < 0.0:
		return Vector2i(22, 46)
	if face.y < 0.0:
		return Vector2i(34, 38)
	return Vector2i(36, 52)


static func _swing_angles(shape: String, face: Vector2, special: bool) -> Array:
	## Angles in radians; 0 = weapon tip pointing right. Grip at hand.
	var style := AttackPose.swing_style_for(shape)
	var side := 1.0 if face.x >= 0.0 else -1.0
	if face.x == 0.0:
		side = 1.0 if face.y >= 0.0 else -1.0
	var base := face.angle()
	if style == "thrust":
		return [
			base + side * 0.35,
			base + side * 0.55,
			base,
			base - side * 0.1,
			base + side * 0.2,
		]
	if style == "cast":
		return [
			base + PI * 0.5 * side,
			base + PI * 0.75 * side,
			base + PI * 0.15 * side,
			base,
			base + PI * 0.35 * side,
		]
	if style == "chop":
		return [
			base - side * 1.1,
			base - side * 1.6,
			base + side * 0.2,
			base + side * 1.1,
			base + side * 0.4,
		]
	# slash — big overhead/around arc like the reference
	var wide := 1.15 if special else 0.95
	return [
		base - side * (1.2 * wide), # ready / low-back
		base - side * (1.85 * wide), # wind-up over shoulder
		base - side * 0.15, # mid cut
		base + side * (1.35 * wide), # follow-through
		base + side * 0.55, # recover
	]


static func _body_shifts(face: Vector2, special: bool) -> Array:
	var dig := 2 if special else 1
	return [
		Vector2i(int(-face.x * 1), int(-face.y * 1)),
		Vector2i(int(-face.x * (3 + dig)), int(-face.y * 2) + 1),
		Vector2i(int(face.x * (4 + dig)), int(face.y * 3)),
		Vector2i(int(face.x * (5 + dig)), int(face.y * 2)),
		Vector2i(int(face.x * 1), 0),
	]


static func _blit(dst: Image, src: Image, ox: int, oy: int) -> void:
	for y in src.get_height():
		for x in src.get_width():
			var c := src.get_pixel(x, y)
			if c.a < 0.05:
				continue
			var dx := x + ox
			var dy := y + oy
			if dx < 0 or dy < 0 or dx >= dst.get_width() or dy >= dst.get_height():
				continue
			var under := dst.get_pixel(dx, dy)
			dst.set_pixel(dx, dy, _blend(under, c))


static func _blend(under: Color, over: Color) -> Color:
	var a := over.a + under.a * (1.0 - over.a)
	if a <= 0.001:
		return Color(0, 0, 0, 0)
	return Color(
		(over.r * over.a + under.r * under.a * (1.0 - over.a)) / a,
		(over.g * over.a + under.g * under.a * (1.0 - over.a)) / a,
		(over.b * over.a + under.b * under.a * (1.0 - over.a)) / a,
		a
	)


static func _soft_cover_static_weapon(canvas: Image, face: Vector2, src: Image) -> void:
	## Gently fade the original held-weapon side so the swung blade reads clearly.
	var x0 := 40 if face.x >= 0.0 else 0
	var x1 := 64 if face.x >= 0.0 else 24
	if face.x == 0.0:
		x0 = 30
		x1 = 50
	for y in range(34, 74):
		for x in range(x0, x1):
			if x < 0 or x >= FRAME_W:
				continue
			var c := canvas.get_pixel(x, y)
			if c.a < 0.1:
				continue
			# Only peel brighter edge pixels (often blade steel), keep torso
			if c.v > 0.55 and c.s < 0.35:
				c.a *= 0.15
				canvas.set_pixel(x, y, c)


static func _draw_weapon(img: Image, hand: Vector2i, angle: float, shape: String, color: Color, special: bool) -> void:
	var steel := WeaponData.finish_color(color, 1 if special else 0)
	var grip := Color(0.42, 0.28, 0.16)
	var dark := steel.darkened(0.35)
	var light := steel.lightened(0.35)
	match shape:
		"cutlass", "sword", "katana", "rapier", "bayonet", "dagger", "knife":
			var len_i := 26 if shape in ["cutlass", "sword", "katana"] else (22 if shape == "rapier" or shape == "bayonet" else 16)
			var thick := 2 if shape in ["dagger", "knife", "rapier"] else 3
			# blade along +angle from hand
			for i in len_i:
				var t := float(i) / float(len_i)
				var w := thick if i > 3 else thick + 1
				if shape == "cutlass" and i > len_i * 0.35:
					w = thick + 2
				var p := hand + _polar(angle, float(i))
				_disk(img, p, w, steel if i % 2 == 0 else light)
				if shape == "katana":
					_disk(img, p + _polar(angle + PI * 0.5, 1.0), 1, light)
			# guard + grip
			_disk(img, hand, 3, dark)
			for j in 5:
				_disk(img, hand + _polar(angle + PI, float(j + 1)), 2, grip)
			if shape == "cutlass":
				# curved tip notch
				var tip := hand + _polar(angle, float(len_i - 2))
				_disk(img, tip + _polar(angle + PI * 0.5, 2.0), 2, steel)
		"axe":
			for i in 18:
				_disk(img, hand + _polar(angle, float(i)), 2, grip.lightened(0.1))
			var head := hand + _polar(angle, 16.0)
			for a_i in range(-4, 5):
				for r_i in range(0, 7):
					_disk(img, head + _polar(angle + PI * 0.5, float(a_i)) + _polar(angle, float(r_i - 2)), 2, steel if r_i > 1 else dark)
		"staff", "rod":
			for i in 28:
				_disk(img, hand + _polar(angle, float(i - 8)), 2, grip.lightened(0.2) if i < 20 else steel)
			_disk(img, hand + _polar(angle, 18.0), 4, color.lightened(0.2))
			_disk(img, hand + _polar(angle, 18.0), 2, Color(1, 1, 1, 0.8))
		"lute":
			for i in 16:
				_disk(img, hand + _polar(angle, float(i)), 2, grip)
			var bowl := hand + _polar(angle, 12.0)
			for yy in range(-4, 5):
				for xx in range(-5, 6):
					if xx * xx + yy * yy <= 20:
						_disk(img, bowl + Vector2i(xx, yy), 1, Color(0.55, 0.35, 0.2))
		"flask", "bottle":
			for i in 12:
				_disk(img, hand + _polar(angle, float(i)), 3 if i > 2 else 2, color if i > 2 else steel)
		"fist":
			_disk(img, hand + _polar(angle, 6.0), 5, steel)
			_disk(img, hand + _polar(angle, 6.0), 3, light)
		_:
			for i in 22:
				_disk(img, hand + _polar(angle, float(i)), 3, steel)


static func _draw_smear(img: Image, hand: Vector2i, angle: float, face: Vector2, color: Color, special: bool, shape: String) -> void:
	var style := AttackPose.swing_style_for(shape)
	if style == "cast":
		for k in 6:
			var a := TAU * float(k) / 6.0
			_disk(img, hand + Vector2i(int(cos(a) * 10.0), int(sin(a) * 10.0)), 2, Color(color.r, color.g, color.b, 0.7))
		return
	if style == "thrust":
		for i in 10:
			_disk(img, hand + _polar(angle, float(8 + i * 2)), 2, Color(1, 1, 0.9, 0.55))
		return
	# Arc smear behind blade
	var side := 1.0 if face.x >= 0.0 else -1.0
	var span := 0.9 if special else 0.65
	for k in 7:
		var t := float(k) / 6.0
		var a := angle - side * span * (1.0 - t)
		var rad := 18.0 + t * 8.0
		var p := hand + _polar(a, rad)
		var c := Color(1.0, 1.0, 0.92, lerpf(0.75, 0.15, t))
		_disk(img, p, 3 if special else 2, c)
		_disk(img, p, 1, Color(color.r, color.g, color.b, c.a))


static func _polar(angle: float, radius: float) -> Vector2i:
	return Vector2i(int(round(cos(angle) * radius)), int(round(sin(angle) * radius)))


static func _disk(img: Image, p: Vector2i, radius: int, color: Color) -> void:
	for y in range(p.y - radius, p.y + radius + 1):
		for x in range(p.x - radius, p.x + radius + 1):
			if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
				continue
			if (x - p.x) * (x - p.x) + (y - p.y) * (y - p.y) <= radius * radius + 1:
				var under := img.get_pixel(x, y)
				var c := color
				if under.a > 0.1 and c.a < 1.0:
					c = under.lerp(Color(c.r, c.g, c.b, 1.0), c.a)
				elif under.a > 0.1:
					c = c
				img.set_pixel(x, y, c)
