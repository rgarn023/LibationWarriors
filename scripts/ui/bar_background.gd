extends Control
## Original Libation Warriors tavern backdrop; responsive and asset-independent.

var _time := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _process(delta: float) -> void:
	_time += delta
	if Engine.get_process_frames() % 3 == 0:
		queue_redraw()

func _draw() -> void:
	var s := size
	if s.x <= 0.0 or s.y <= 0.0:
		return
	draw_rect(Rect2(Vector2.ZERO, s), Color(0.055, 0.035, 0.025))
	var plank_h := maxf(42.0, s.y / 18.0)
	var y := 0.0
	var row := 0
	while y < s.y * 0.68:
		var c := Color(0.15, 0.085, 0.045) if row % 2 == 0 else Color(0.12, 0.065, 0.038)
		draw_rect(Rect2(0, y, s.x, plank_h - 2.0), c)
		y += plank_h
		row += 1
	for shelf_y in [s.y * 0.27, s.y * 0.43]:
		draw_rect(Rect2(s.x * 0.08, shelf_y, s.x * 0.84, 9), Color(0.27, 0.14, 0.065))
		var x := s.x * 0.12
		var i := 0
		while x < s.x * 0.9:
			var bh := 28.0 + float((i * 13) % 22)
			var bottle := Color(0.12, 0.24, 0.17) if i % 3 == 0 else Color(0.28, 0.18, 0.08)
			draw_rect(Rect2(x, shelf_y - bh, 13, bh), bottle)
			draw_rect(Rect2(x + 4, shelf_y - bh - 10, 5, 11), bottle.lightened(0.05))
			x += 31.0
			i += 1
	var pulse := 0.94 + sin(_time * 2.2) * 0.04
	var lamp_center := Vector2(s.x * 0.5, s.y * 0.14)
	draw_circle(lamp_center, minf(s.x, s.y) * 0.11, Color(0.75, 0.4, 0.12, 0.08 * pulse))
	draw_circle(lamp_center, minf(s.x, s.y) * 0.052, Color(0.95, 0.63, 0.22, 0.12 * pulse))
	draw_rect(Rect2(s.x * 0.47, 0, s.x * 0.06, s.y * 0.09), Color(0.12, 0.07, 0.04))
	draw_rect(Rect2(0, s.y * 0.72, s.x, s.y * 0.28), Color(0.07, 0.035, 0.02))
	draw_rect(Rect2(0, s.y * 0.70, s.x, s.y * 0.055), Color(0.34, 0.17, 0.065))
	draw_rect(Rect2(0, s.y * 0.755, s.x, 8), Color(0.18, 0.085, 0.035))
