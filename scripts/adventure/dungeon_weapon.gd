extends Sprite2D
## Temporary facing-directed weapon swing / cast pose (Sprite2D-baked for Android).

var _life: float = 0.22
var _max_life: float = 0.22
var _face: Vector2 = Vector2.DOWN
var _base_pos: Vector2 = Vector2.ZERO
var _arc: float = 1.1


func play(origin: Vector2, facing: Vector2, shape: String, color: Color, is_special: bool = false) -> void:
	_face = WeaponData.cardinal(facing)
	_max_life = 0.28 if is_special else 0.2
	_life = _max_life
	_arc = 1.35 if is_special else 0.95
	centered = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = 25
	_base_pos = origin + _face * (10.0 if shape != "fist" else 6.0)
	position = _base_pos
	texture = _bake(shape, color, is_special)
	rotation = _face.angle() + PI * 0.5 - _arc * 0.5
	scale = Vector2(1.15, 1.15) if is_special else Vector2.ONE


func _process(delta: float) -> void:
	_life -= delta
	var t := 1.0 - clampf(_life / _max_life, 0.0, 1.0)
	rotation = _face.angle() + PI * 0.5 - _arc * 0.5 + _arc * t
	position = _base_pos + _face * (t * 4.0)
	modulate.a = 1.0 - t * 0.15
	if _life <= 0.0:
		queue_free()


func _bake(shape: String, color: Color, is_special: bool) -> Texture2D:
	var img := Image.create(28, 28, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var steel := color
	var grip := Color(0.4, 0.28, 0.16)
	var glow := color.lightened(0.35) if is_special else color
	match shape:
		"cutlass", "sword", "katana", "rapier", "bayonet", "dagger", "knife":
			var thick := 3 if shape in ["cutlass", "sword", "katana"] else 2
			_fill(img, 13, 2, thick, 18, steel)
			_fill(img, 10, 18, 8, 2, grip.lightened(0.2))
			_fill(img, 12, 20, 4, 6, grip)
			if shape == "cutlass":
				_fill(img, 15, 4, 4, 3, steel)
			if shape == "katana":
				_fill(img, 12, 2, 1, 16, glow)
		"axe":
			_fill(img, 13, 6, 3, 16, grip)
			_fill(img, 6, 4, 16, 8, steel)
			_fill(img, 8, 5, 12, 5, glow)
		"staff", "rod", "lute":
			_fill(img, 13, 2, 2, 22, grip.lightened(0.15))
			_fill(img, 10, 2, 8, 6, glow)
			if shape == "lute":
				_fill(img, 8, 8, 12, 8, Color(0.55, 0.35, 0.2))
		"flask", "bottle":
			_fill(img, 11, 6, 6, 12, glow)
			_fill(img, 12, 3, 4, 4, steel)
			_fill(img, 10, 16, 8, 3, grip)
		"fist":
			_fill(img, 8, 8, 12, 10, steel)
			_fill(img, 10, 10, 8, 6, glow)
		_:
			_fill(img, 13, 3, 3, 18, steel)
			_fill(img, 12, 20, 4, 5, grip)
	return ImageTexture.create_from_image(img)


func _fill(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	if w <= 0 or h <= 0:
		return
	var x0 := clampi(x, 0, img.get_width())
	var y0 := clampi(y, 0, img.get_height())
	var x1 := clampi(x + w, 0, img.get_width())
	var y1 := clampi(y + h, 0, img.get_height())
	if x1 > x0 and y1 > y0:
		img.fill_rect(Rect2i(x0, y0, x1 - x0, y1 - y0), c)
