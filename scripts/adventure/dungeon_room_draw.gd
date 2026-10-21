extends Sprite2D
## Bakes a detailed dungeon room into an ImageTexture.
## Sprite2D is reliable on Android mobile; bare CanvasItem._draw was not showing.

var floor_c: Color = Color(0.35, 0.32, 0.36)
var wall_c: Color = Color(0.55, 0.5, 0.46)
var accent_c: Color = Color(0.85, 0.7, 0.4)
var theme_name: String = ""
var room_w: int = 16
var room_h: int = 11
var tile: int = 16
var doors: Dictionary = {}
var locked_dirs: Dictionary = {}
var kind: String = "empty"
var torch_phase: float = 0.0
var door_gap_tiles: int = 3
var _base_img: Image
var _needs_full_bake: bool = true


func configure(p_floor: Color, p_wall: Color, p_accent: Color, p_theme: String, p_doors: Dictionary, p_locked: Dictionary, p_kind: String) -> void:
	floor_c = p_floor.lightened(0.12)
	wall_c = p_wall.lightened(0.1)
	accent_c = p_accent
	theme_name = p_theme.to_lower()
	doors = p_doors.duplicate()
	locked_dirs = p_locked.duplicate()
	kind = p_kind
	centered = false
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = -10
	_needs_full_bake = true
	_bake()


func set_torch_phase(t: float) -> void:
	torch_phase = t
	if _base_img == null:
		_bake()
		return
	var frame := _base_img.duplicate()
	_paint_torches(frame)
	texture = ImageTexture.create_from_image(frame)


func _bake() -> void:
	var rw := room_w * tile
	var rh := room_h * tile
	var img := Image.create(rw, rh, false, Image.FORMAT_RGBA8)
	# Bright floor base so room reads against dark clear color
	img.fill(floor_c.darkened(0.05))
	# Stone tiles
	for y in range(1, room_h - 1):
		for x in range(1, room_w - 1):
			var n := (x * 17 + y * 31) % 6
			var shade_opts: Array[float] = [-0.06, -0.02, 0.04, 0.08, 0.1, -0.04]
			var shade: float = shade_opts[n]
			var c := floor_c.lightened(shade) if shade >= 0.0 else floor_c.darkened(-shade)
			_fill(img, x * tile + 1, y * tile + 1, tile - 2, tile - 2, c)
			_fill(img, x * tile, y * tile, tile, 1, floor_c.darkened(0.18))
			if n == 2 or n == 5:
				_fill(img, x * tile + 5, y * tile + 6, 2, 2, floor_c.lightened(0.15))
			if (x + y * 3) % 11 == 0:
				_fill(img, x * tile + 3, y * tile + 8, 9, 1, floor_c.darkened(0.22))
	# Carpet
	_fill(img, int(tile * 4.5), tile * 3, tile * 7, tile * 5, Color(accent_c.r * 0.45, accent_c.g * 0.4, accent_c.b * 0.42, 1))
	_fill(img, int(tile * 4.5), tile * 3, tile * 7, 2, accent_c)
	_fill(img, int(tile * 4.5), tile * 3 + tile * 5 - 2, tile * 7, 2, accent_c)
	_fill(img, int(rw * 0.5) - 5, int(rh * 0.5) - 5, 10, 10, accent_c.lightened(0.15))
	_fill(img, int(rw * 0.5) - 3, int(rh * 0.5) - 3, 6, 6, floor_c)
	# Walls
	_paint_wall_row(img, 0, 0, rw, tile, "n")
	_paint_wall_row(img, 0, (room_h - 1) * tile, rw, tile, "s")
	_paint_wall_col(img, 0, 0, tile, rh, "w")
	_paint_wall_col(img, (room_w - 1) * tile, 0, tile, rh, "e")
	# Pillars (clear of door lanes)
	for p in [Vector2i(int(tile * 3.2), int(tile * 3.0)), Vector2i(int(tile * 12.0), int(tile * 3.0)), Vector2i(int(tile * 3.2), int(tile * 7.0)), Vector2i(int(tile * 12.0), int(tile * 7.0))]:
		_fill(img, p.x, p.y - 2, 10, 3, accent_c)
		_fill(img, p.x, p.y, 10, 16, wall_c.darkened(0.05))
		_fill(img, p.x + 1, p.y + 2, 3, 12, wall_c.lightened(0.15))
	# Banners
	for bx in [tile * 5, tile * 10]:
		_fill(img, bx, int(tile * 1.2), 2, 18, Color(0.45, 0.4, 0.3))
		_fill(img, bx - 5, int(tile * 1.35), 12, 16, accent_c.darkened(0.05))
		_fill(img, bx - 5, int(tile * 1.35) + 5, 12, 3, accent_c.lightened(0.2))
	_paint_theme_props(img)
	# Bright doorway markers
	var gap := door_gap_tiles * tile
	for d in doors.keys():
		if locked_dirs.get(str(d), false) or locked_dirs.get(d, false):
			continue
		match str(d):
			"n":
				_fill(img, int(rw * 0.5) - gap / 2, tile, gap, 4, accent_c.lightened(0.45))
				_fill(img, int(rw * 0.5) - 5, tile + 5, 10, 6, Color(1, 0.95, 0.55, 1))
			"s":
				_fill(img, int(rw * 0.5) - gap / 2, (room_h - 1) * tile - 4, gap, 4, accent_c.lightened(0.45))
				_fill(img, int(rw * 0.5) - 5, (room_h - 1) * tile - 11, 10, 6, Color(1, 0.95, 0.55, 1))
			"w":
				_fill(img, tile, int(rh * 0.5) - gap / 2, 4, gap, accent_c.lightened(0.45))
				_fill(img, tile + 5, int(rh * 0.5) - 5, 6, 10, Color(1, 0.95, 0.55, 1))
			"e":
				_fill(img, (room_w - 1) * tile - 4, int(rh * 0.5) - gap / 2, 4, gap, accent_c.lightened(0.45))
				_fill(img, (room_w - 1) * tile - 11, int(rh * 0.5) - 5, 6, 10, Color(1, 0.95, 0.55, 1))
	if kind == "boss":
		_fill(img, int(tile * 4.5), int(tile * 1.55), tile * 7, 12, Color(0.55, 0.15, 0.18, 1))
		_fill(img, int(rw * 0.5) - 4, int(tile * 1.7), 8, 8, Color(0.9, 0.85, 0.75))
	# Corner shade
	var vg := Color(0, 0, 0, 0.28)
	_fill(img, tile, tile, tile * 2, tile * 2, vg)
	_fill(img, (room_w - 3) * tile, tile, tile * 2, tile * 2, vg)
	_fill(img, tile, (room_h - 3) * tile, tile * 2, tile * 2, vg)
	_fill(img, (room_w - 3) * tile, (room_h - 3) * tile, tile * 2, tile * 2, vg)
	# Keep torch-less base; flicker paints onto a duplicate
	_base_img = img
	var framed := img.duplicate()
	_paint_torches(framed)
	texture = ImageTexture.create_from_image(framed)
	_needs_full_bake = false


func _paint_torches(img: Image) -> void:
	var flicker := 0.55 + 0.35 * absf(sin(torch_phase * 6.0))
	var flame := Color(1.0, flicker, 0.18, 1.0)
	for tp in [Vector2i(int(tile * 2.2), int(tile * 1.35)), Vector2i(int(tile * 13.5), int(tile * 1.35)), Vector2i(int(tile * 2.2), int(tile * 8.6)), Vector2i(int(tile * 13.5), int(tile * 8.6))]:
		_fill(img, tp.x - 4, tp.y - 3, 14, 14, Color(1.0, 0.5, 0.1, 0.35))
		_fill(img, tp.x, tp.y, 5, 7, flame)
		_fill(img, tp.x - 2, tp.y + 7, 8, 4, Color(0.35, 0.3, 0.22))


func _paint_wall_row(img: Image, x: int, y: int, w: int, h: int, dir: String) -> void:
	var has := doors.has(dir) or doors.has(StringName(dir))
	var locked: bool = locked_dirs.get(dir, false) or locked_dirs.get(str(dir), false)
	var gap := door_gap_tiles * tile
	if not has or locked:
		_fill_wall(img, x, y, w, h)
		if locked and has:
			_fill(img, x + int(w * 0.5) - gap / 2, y, gap, h, Color(0.65, 0.55, 0.2))
		return
	var gap_x := x + int(w * 0.5) - gap / 2
	_fill_wall(img, x, y, gap_x - x, h)
	_fill_wall(img, gap_x + gap, y, x + w - (gap_x + gap), h)
	_fill(img, gap_x - 2, y, 2, h, accent_c)
	_fill(img, gap_x + gap, y, 2, h, accent_c)
	_fill(img, gap_x, y, gap, h, floor_c.lightened(0.12))


func _paint_wall_col(img: Image, x: int, y: int, w: int, h: int, dir: String) -> void:
	var has := doors.has(dir) or doors.has(StringName(dir))
	var locked: bool = locked_dirs.get(dir, false) or locked_dirs.get(str(dir), false)
	var gap := door_gap_tiles * tile
	if not has or locked:
		_fill_wall(img, x, y, w, h)
		if locked and has:
			_fill(img, x, y + int(h * 0.5) - gap / 2, w, gap, Color(0.65, 0.55, 0.2))
		return
	var gap_y := y + int(h * 0.5) - gap / 2
	_fill_wall(img, x, y, w, gap_y - y)
	_fill_wall(img, x, gap_y + gap, w, y + h - (gap_y + gap))
	_fill(img, x, gap_y - 2, w, 2, accent_c)
	_fill(img, x, gap_y + gap, w, 2, accent_c)
	_fill(img, x, gap_y, w, gap, floor_c.lightened(0.12))


func _fill_wall(img: Image, x: int, y: int, w: int, h: int) -> void:
	if w <= 0 or h <= 0:
		return
	_fill(img, x, y, w, h, wall_c)
	var yy := y
	while yy < y + h:
		var c := wall_c.lightened(0.1) if ((yy / 8) % 2 == 0) else wall_c.darkened(0.08)
		_fill(img, x, yy, w, 1, c)
		yy += 8
	_fill(img, x + 1, y + 1, maxi(1, w - 2), 2, wall_c.lightened(0.2))


func _paint_theme_props(img: Image) -> void:
	if "cave" in theme_name or "mine" in theme_name or "catacomb" in theme_name:
		for i in range(6):
			_fill(img, int(tile * (3 + i * 1.7)), int(tile * 8.2) - (i % 2) * 4, 6 + i % 3, 10 + i % 5, wall_c.lightened(0.08))
	elif "forest" in theme_name or "thorn" in theme_name:
		for i in range(5):
			_fill(img, int(tile * (2.5 + i * 2.2)), int(tile * (3.5 + (i % 3))), 14, 3, Color(0.3, 0.48, 0.22))
			_fill(img, int(tile * (2.5 + i * 2.2)) + 4, int(tile * (3.5 + (i % 3))) - 4, 5, 5, accent_c)
	elif "tower" in theme_name or "ruin" in theme_name or "ashen" in theme_name:
		for wx in [int(tile * 4.0), int(tile * 11.0)]:
			_fill(img, wx, int(tile * 1.15), 14, 18, floor_c.darkened(0.2))
			_fill(img, wx + 2, int(tile * 1.15) + 3, 10, 12, Color(accent_c.r, accent_c.g, accent_c.b, 0.55))
	elif "crypt" in theme_name or "keep" in theme_name:
		for i in range(3):
			_fill(img, int(tile * (3.5 + i * 3.5)), int(tile * 7.6), 18, 8, wall_c.darkened(0.12))
			_fill(img, int(tile * (3.5 + i * 3.5)), int(tile * 7.6) - 2, 18, 3, accent_c.darkened(0.2))
	else:
		for i in range(4):
			_fill(img, int(tile * (3.2 + i * 2.5)), int(tile * 7.5), 12, 12, Color(0.5, 0.34, 0.18))
			_fill(img, int(tile * (3.2 + i * 2.5)), int(tile * 7.5) + 5, 12, 2, Color(0.65, 0.5, 0.28))
	for i in range(8):
		_fill(img, int(tile * (3.5 + (i % 5) * 1.6)), int(tile * (7.8 + (i % 3) * 0.4)), 4 + (i % 4), 2 + (i % 3), wall_c.darkened(0.05))


func _fill(img: Image, x: int, y: int, w: int, h: int, color: Color) -> void:
	if w <= 0 or h <= 0:
		return
	var rw := img.get_width()
	var rh := img.get_height()
	var x0 := clampi(x, 0, rw)
	var y0 := clampi(y, 0, rh)
	var x1 := clampi(x + w, 0, rw)
	var y1 := clampi(y + h, 0, rh)
	if x1 <= x0 or y1 <= y0:
		return
	# Blend semi-transparent over existing pixels
	if color.a >= 0.999:
		img.fill_rect(Rect2i(x0, y0, x1 - x0, y1 - y0), color)
		return
	for py in range(y0, y1):
		for px in range(x0, x1):
			var base := img.get_pixel(px, py)
			img.set_pixel(px, py, base.lerp(Color(color.r, color.g, color.b, 1), color.a))
