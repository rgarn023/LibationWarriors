extends Node2D
## Draws a detailed dungeon room with CanvasItem._draw (reliable on mobile).
## ColorRect-under-Node2D can fail to render on some Android builds.

var floor_c: Color = Color(0.22, 0.2, 0.24)
var wall_c: Color = Color(0.4, 0.36, 0.34)
var accent_c: Color = Color(0.7, 0.55, 0.35)
var theme_name: String = ""
var room_w: int = 16
var room_h: int = 11
var tile: int = 16
var doors: Dictionary = {} ## dir -> true if open visual gap
var locked_dirs: Dictionary = {}
var kind: String = "empty"
var torch_phase: float = 0.0


func configure(p_floor: Color, p_wall: Color, p_accent: Color, p_theme: String, p_doors: Dictionary, p_locked: Dictionary, p_kind: String) -> void:
	floor_c = p_floor
	wall_c = p_wall
	accent_c = p_accent
	theme_name = p_theme.to_lower()
	doors = p_doors.duplicate()
	locked_dirs = p_locked.duplicate()
	kind = p_kind
	queue_redraw()


func set_torch_phase(t: float) -> void:
	torch_phase = t
	queue_redraw()


func _draw() -> void:
	var rw := room_w * tile
	var rh := room_h * tile
	# Floor base
	draw_rect(Rect2(0, 0, rw, rh), floor_c.darkened(0.1), true)
	# Stone tiles
	for y in range(1, room_h - 1):
		for x in range(1, room_w - 1):
			var n := (x * 17 + y * 31) % 6
			var shade := [-0.08, -0.03, 0.02, 0.06, 0.09, -0.05][n]
			var c := floor_c.lightened(shade) if shade >= 0.0 else floor_c.darkened(-shade)
			draw_rect(Rect2(x * tile + 1, y * tile + 1, tile - 2, tile - 2), c, true)
			draw_rect(Rect2(x * tile, y * tile, tile, 1), floor_c.darkened(0.22), true)
			if n == 2 or n == 5:
				draw_rect(Rect2(x * tile + 5, y * tile + 6, 2, 2), floor_c.lightened(0.12), true)
			if (x + y * 3) % 11 == 0:
				draw_rect(Rect2(x * tile + 3, y * tile + 8, 9, 1), floor_c.darkened(0.28), true)
	# Carpet
	var carpet := Rect2(tile * 4.5, tile * 3, tile * 7, tile * 5)
	draw_rect(carpet, Color(accent_c.r * 0.3, accent_c.g * 0.3, accent_c.b * 0.32, 0.7), true)
	draw_rect(Rect2(carpet.position, Vector2(carpet.size.x, 2)), accent_c, true)
	draw_rect(Rect2(carpet.position + Vector2(0, carpet.size.y - 2), Vector2(carpet.size.x, 2)), accent_c, true)
	draw_rect(Rect2(rw * 0.5 - 5, rh * 0.5 - 5, 10, 10), accent_c.lightened(0.1), true)
	draw_rect(Rect2(rw * 0.5 - 3, rh * 0.5 - 3, 6, 6), floor_c, true)
	# Walls with door gaps
	_draw_wall_row(Rect2(0, 0, rw, tile), "n")
	_draw_wall_row(Rect2(0, (room_h - 1) * tile, rw, tile), "s")
	_draw_wall_col(Rect2(0, 0, tile, rh), "w")
	_draw_wall_col(Rect2((room_w - 1) * tile, 0, tile, rh), "e")
	# Pillars
	for p in [Vector2(tile * 2.8, tile * 2.5), Vector2(tile * 12.5, tile * 2.5), Vector2(tile * 2.8, tile * 7.2), Vector2(tile * 12.5, tile * 7.2)]:
		draw_rect(Rect2(p.x, p.y - 2, 10, 3), accent_c, true)
		draw_rect(Rect2(p.x, p.y, 10, 18), wall_c.darkened(0.05), true)
		draw_rect(Rect2(p.x + 1, p.y + 2, 3, 12), wall_c.lightened(0.12), true)
	# Torches
	var flicker := 0.55 + 0.35 * absf(sin(torch_phase * 6.0))
	for tp in [Vector2(tile * 2.2, tile * 1.35), Vector2(tile * 13.5, tile * 1.35), Vector2(tile * 2.2, tile * 8.6), Vector2(tile * 13.5, tile * 8.6)]:
		draw_rect(Rect2(tp.x - 4, tp.y - 3, 14, 14), Color(1.0, 0.5, 0.1, 0.16), true)
		draw_rect(Rect2(tp.x, tp.y, 5, 7), Color(1.0, flicker, 0.18, 0.95), true)
		draw_rect(Rect2(tp.x - 2, tp.y + 7, 8, 4), Color(0.32, 0.28, 0.22), true)
	# Banners
	for bx in [tile * 5.0, tile * 10.0]:
		draw_rect(Rect2(bx, tile * 1.2, 2, 18), Color(0.4, 0.35, 0.25), true)
		draw_rect(Rect2(bx - 5, tile * 1.35, 12, 16), accent_c.darkened(0.1), true)
		draw_rect(Rect2(bx - 5, tile * 1.35 + 5, 12, 3), accent_c.lightened(0.2), true)
	# Theme props
	_draw_theme_props()
	# Door arrows
	for d in doors.keys():
		if locked_dirs.get(d, false):
			continue
		match str(d):
			"n":
				draw_rect(Rect2(rw * 0.5 - 4, tile + 2, 8, 5), accent_c.lightened(0.3), true)
			"s":
				draw_rect(Rect2(rw * 0.5 - 4, (room_h - 1) * tile - 7, 8, 5), accent_c.lightened(0.3), true)
			"w":
				draw_rect(Rect2(tile + 2, rh * 0.5 - 4, 5, 8), accent_c.lightened(0.3), true)
			"e":
				draw_rect(Rect2((room_w - 1) * tile - 7, rh * 0.5 - 4, 5, 8), accent_c.lightened(0.3), true)
	if kind == "boss":
		draw_rect(Rect2(tile * 4.5, tile * 1.55, tile * 7, 12), Color(0.42, 0.1, 0.12, 0.9), true)
		draw_rect(Rect2(rw * 0.5 - 4, tile * 1.7, 8, 8), Color(0.85, 0.8, 0.7), true)
	# Vignette corners
	var vg := Color(0, 0, 0, 0.25)
	draw_rect(Rect2(tile, tile, tile * 2, tile * 2), vg, true)
	draw_rect(Rect2((room_w - 3) * tile, tile, tile * 2, tile * 2), vg, true)
	draw_rect(Rect2(tile, (room_h - 3) * tile, tile * 2, tile * 2), vg, true)
	draw_rect(Rect2((room_w - 3) * tile, (room_h - 3) * tile, tile * 2, tile * 2), vg, true)


func _draw_wall_row(full: Rect2, dir: String) -> void:
	var has := doors.has(dir)
	var locked: bool = locked_dirs.get(dir, false)
	if not has or locked:
		_fill_wall(full)
		if locked and has:
			draw_rect(Rect2(full.position.x + full.size.x * 0.5 - tile, full.position.y, tile * 2, full.size.y), Color(0.55, 0.45, 0.15), true)
		return
	var gap_x := full.position.x + full.size.x * 0.5 - tile
	_fill_wall(Rect2(full.position.x, full.position.y, gap_x - full.position.x, full.size.y))
	_fill_wall(Rect2(gap_x + tile * 2, full.position.y, full.position.x + full.size.x - (gap_x + tile * 2), full.size.y))
	# Door frame
	draw_rect(Rect2(gap_x - 2, full.position.y, 2, full.size.y), accent_c, true)
	draw_rect(Rect2(gap_x + tile * 2, full.position.y, 2, full.size.y), accent_c, true)


func _draw_wall_col(full: Rect2, dir: String) -> void:
	var has := doors.has(dir)
	var locked: bool = locked_dirs.get(dir, false)
	if not has or locked:
		_fill_wall(full)
		if locked and has:
			draw_rect(Rect2(full.position.x, full.position.y + full.size.y * 0.5 - tile, full.size.x, tile * 2), Color(0.55, 0.45, 0.15), true)
		return
	var gap_y := full.position.y + full.size.y * 0.5 - tile
	_fill_wall(Rect2(full.position.x, full.position.y, full.size.x, gap_y - full.position.y))
	_fill_wall(Rect2(full.position.x, gap_y + tile * 2, full.size.x, full.position.y + full.size.y - (gap_y + tile * 2)))
	draw_rect(Rect2(full.position.x, gap_y - 2, full.size.x, 2), accent_c, true)
	draw_rect(Rect2(full.position.x, gap_y + tile * 2, full.size.x, 2), accent_c, true)


func _fill_wall(r: Rect2) -> void:
	if r.size.x <= 0 or r.size.y <= 0:
		return
	draw_rect(r, wall_c, true)
	var y := int(r.position.y)
	while y < int(r.position.y + r.size.y):
		var c := wall_c.lightened(0.08) if ((y / 8) % 2 == 0) else wall_c.darkened(0.08)
		draw_rect(Rect2(r.position.x, y, r.size.x, 1), c, true)
		y += 8
	draw_rect(Rect2(r.position.x + 1, r.position.y + 1, maxf(1, r.size.x - 2), 2), wall_c.lightened(0.18), true)


func _draw_theme_props() -> void:
	if "cave" in theme_name or "mine" in theme_name or "catacomb" in theme_name:
		for i in range(6):
			draw_rect(Rect2(tile * (3 + i * 1.7), tile * 8.2 - (i % 2) * 4, 6 + i % 3, 10 + i % 5), wall_c.lightened(0.05), true)
	elif "forest" in theme_name or "thorn" in theme_name:
		for i in range(5):
			draw_rect(Rect2(tile * (2.5 + i * 2.2), tile * (3.5 + (i % 3)), 14, 3), Color(0.25, 0.4, 0.18), true)
			draw_rect(Rect2(tile * (2.5 + i * 2.2) + 4, tile * (3.5 + (i % 3)) - 4, 5, 5), accent_c, true)
	elif "tower" in theme_name or "ruin" in theme_name or "ashen" in theme_name:
		for wx in [tile * 4.0, tile * 11.0]:
			draw_rect(Rect2(wx, tile * 1.15, 14, 18), floor_c.darkened(0.25), true)
			draw_rect(Rect2(wx + 2, tile * 1.15 + 3, 10, 12), Color(accent_c.r, accent_c.g, accent_c.b, 0.35), true)
	elif "crypt" in theme_name or "keep" in theme_name:
		for i in range(3):
			draw_rect(Rect2(tile * (3.5 + i * 3.5), tile * 7.6, 18, 8), wall_c.darkened(0.15), true)
			draw_rect(Rect2(tile * (3.5 + i * 3.5), tile * 7.6 - 2, 18, 3), accent_c.darkened(0.25), true)
	else:
		for i in range(4):
			draw_rect(Rect2(tile * (3.2 + i * 2.5), tile * 7.5, 12, 12), Color(0.42, 0.28, 0.14), true)
			draw_rect(Rect2(tile * (3.2 + i * 2.5), tile * 7.5 + 5, 12, 2), Color(0.55, 0.45, 0.25), true)
	# Rubble
	for i in range(8):
		draw_rect(Rect2(tile * (3.5 + (i % 5) * 1.6), tile * (7.8 + (i % 3) * 0.4), 4 + (i % 4), 2 + (i % 3)), wall_c.darkened(0.08), true)
