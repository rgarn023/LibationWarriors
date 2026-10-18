extends Sprite2D
## Clothing overlays for in-world warrior sprites (cape, sash, belt, crest).
## Baked to ImageTexture so it renders on Android mobile like character sheets.

var warrior: Warrior
var body_scale: float = 0.42
var show_cape: bool = true


func configure(w: Warrior, sc: float = 0.42, cape: bool = true) -> void:
	warrior = w
	body_scale = sc
	show_cape = cape
	centered = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = 1
	_bake()


func _bake() -> void:
	if warrior == null:
		return
	var primary := warrior.outfit_primary()
	var secondary := warrior.outfit_secondary()
	var accent := warrior.outfit_accent()
	var s := body_scale * 64.0
	var tw := int(ceili(s * 0.9))
	var th := int(ceili(s * 0.9))
	tw = maxi(tw, 24)
	th = maxi(th, 28)
	var img := Image.create(tw, th, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var cx := tw * 0.5
	var cy := th * 0.45
	if show_cape:
		var cape_a := 0.55 + 0.1 * float(warrior.variant_pattern % 3)
		_fill(img, int(cx - s * 0.28), int(cy - s * 0.05), int(s * 0.18), int(s * 0.55), Color(secondary.r, secondary.g, secondary.b, cape_a))
		_fill(img, int(cx + s * 0.10), int(cy - s * 0.05), int(s * 0.18), int(s * 0.55), Color(secondary.r, secondary.g, secondary.b, cape_a))
	match warrior.variant_pattern % 6:
		1:
			_fill(img, int(cx - s * 0.32), int(cy - s * 0.22), int(s * 0.2), int(s * 0.12), primary)
			_fill(img, int(cx + s * 0.12), int(cy - s * 0.22), int(s * 0.2), int(s * 0.12), primary)
			_fill(img, int(cx - s * 0.32), int(cy - s * 0.18), int(s * 0.2), int(s * 0.04), accent)
			_fill(img, int(cx + s * 0.12), int(cy - s * 0.18), int(s * 0.2), int(s * 0.04), accent)
		2:
			_fill(img, int(cx - s * 0.22), int(cy + s * 0.02), int(s * 0.44), int(s * 0.14), Color(primary.r, primary.g, primary.b, 0.85))
			_fill(img, int(cx - s * 0.18), int(cy + s * 0.06), int(s * 0.36), int(s * 0.04), secondary)
		3:
			_fill(img, int(cx - s * 0.16), int(cy - s * 0.12), int(s * 0.32), int(s * 0.28), Color(primary.r, primary.g, primary.b, 0.75))
			_fill(img, int(cx - s * 0.06), int(cy - s * 0.02), int(s * 0.12), int(s * 0.08), accent)
		4:
			_fill(img, int(cx - s * 0.05), int(cy - s * 0.18), int(s * 0.1), int(s * 0.08), accent)
			for i in 5:
				var ox := int(cx - s * 0.2 + float(i % 3) * s * 0.12)
				var oy := int(cy + s * 0.05 + float(i % 2) * s * 0.1)
				_fill(img, ox, oy, 3, 3, primary)
		5:
			_fill(img, int(cx - s * 0.2), int(cy + s * 0.08), int(s * 0.4), int(s * 0.06), secondary)
			_fill(img, int(cx - s * 0.2), int(cy + s * 0.15), int(s * 0.4), int(s * 0.05), primary)
			_fill(img, int(cx - s * 0.2), int(cy + s * 0.21), int(s * 0.4), int(s * 0.04), accent)
		_:
			_fill(img, int(cx - s * 0.2), int(cy + s * 0.05), int(s * 0.4), int(s * 0.1), primary)
			_fill(img, int(cx - s * 0.2), int(cy + s * 0.08), int(s * 0.4), int(s * 0.03), accent)
	_fill(img, int(cx - s * 0.06), int(cy + s * 0.12), int(s * 0.12), int(s * 0.08), accent)
	var crest := warrior.variant_crest % 5
	if crest > 0:
		match crest:
			1:
				_fill(img, int(cx - s * 0.05), int(cy - s * 0.05), int(s * 0.1), int(s * 0.1), accent)
			2:
				_fill(img, int(cx - s * 0.05), int(cy - s * 0.05), int(s * 0.1), int(s * 0.1), secondary)
			3:
				_fill(img, int(cx - 1), int(cy - s * 0.08), 3, int(s * 0.16), accent)
				_fill(img, int(cx - s * 0.06), int(cy - 1), int(s * 0.12), 3, accent)
			_:
				_fill(img, int(cx - s * 0.08), int(cy), int(s * 0.16), 3, accent)
				_fill(img, int(cx - s * 0.06), int(cy + 4), int(s * 0.12), 3, accent)
	var wx := int(cx + s * 0.28)
	var wcol := Color(0.7, 0.72, 0.75, 0.85)
	match warrior.variant_weapon_style % 4:
		1:
			wcol = Color(0.9, 0.92, 1.0, 0.9)
		2:
			wcol = Color(0.25, 0.28, 0.35, 0.9)
		3:
			wcol = Color(0.95, 0.8, 0.35, 0.9)
	_fill(img, wx, int(cy - s * 0.15), 3, int(s * 0.35), wcol)
	texture = ImageTexture.create_from_image(img)


func _fill(img: Image, x: int, y: int, w: int, h: int, color: Color) -> void:
	if w <= 0 or h <= 0:
		return
	var x0 := clampi(x, 0, img.get_width())
	var y0 := clampi(y, 0, img.get_height())
	var x1 := clampi(x + w, 0, img.get_width())
	var y1 := clampi(y + h, 0, img.get_height())
	if x1 <= x0 or y1 <= y0:
		return
	if color.a >= 0.999:
		img.fill_rect(Rect2i(x0, y0, x1 - x0, y1 - y0), color)
		return
	for py in range(y0, y1):
		for px in range(x0, x1):
			var base := img.get_pixel(px, py)
			img.set_pixel(px, py, base.lerp(Color(color.r, color.g, color.b, 1), color.a))
