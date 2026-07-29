extends Node2D
## Clothing overlays for in-world warrior sprites (cape, sash, belt, crest).
## Packaging / barcode colors dress the character — not a background tint.

var warrior: Warrior
var body_scale: float = 0.42
var show_cape: bool = true


func configure(w: Warrior, sc: float = 0.42, cape: bool = true) -> void:
	warrior = w
	body_scale = sc
	show_cape = cape
	z_index = 1
	queue_redraw()


func _draw() -> void:
	if warrior == null:
		return
	var primary := warrior.outfit_primary()
	var secondary := warrior.outfit_secondary()
	var accent := warrior.outfit_accent()
	var s := body_scale * 64.0
	# Cape / cloak behind torso read (drawn first, slightly offset)
	if show_cape:
		var cape_a := 0.55 + 0.1 * float(warrior.variant_pattern % 3)
		draw_rect(Rect2(-s * 0.28, -s * 0.05, s * 0.18, s * 0.55), Color(secondary.r, secondary.g, secondary.b, cape_a), true)
		draw_rect(Rect2(s * 0.10, -s * 0.05, s * 0.18, s * 0.55), Color(secondary.r, secondary.g, secondary.b, cape_a), true)
	# Shoulder pads / armor trim
	match warrior.variant_pattern % 6:
		1: # Striped pauldrons
			draw_rect(Rect2(-s * 0.32, -s * 0.22, s * 0.2, s * 0.12), primary, true)
			draw_rect(Rect2(s * 0.12, -s * 0.22, s * 0.2, s * 0.12), primary, true)
			draw_rect(Rect2(-s * 0.32, -s * 0.18, s * 0.2, s * 0.04), accent, true)
			draw_rect(Rect2(s * 0.12, -s * 0.18, s * 0.2, s * 0.04), accent, true)
		2: # Marbled sash wrap
			draw_rect(Rect2(-s * 0.22, s * 0.02, s * 0.44, s * 0.14), Color(primary.r, primary.g, primary.b, 0.85), true)
			draw_rect(Rect2(-s * 0.18, s * 0.06, s * 0.36, s * 0.04), secondary, true)
		3: # Runed chest plate
			draw_rect(Rect2(-s * 0.16, -s * 0.12, s * 0.32, s * 0.28), Color(primary.r, primary.g, primary.b, 0.75), true)
			draw_rect(Rect2(-s * 0.06, -s * 0.02, s * 0.12, s * 0.08), accent, true)
		4: # Speckled cloak clasp + spots
			draw_rect(Rect2(-s * 0.05, -s * 0.18, s * 0.1, s * 0.08), accent, true)
			for i in 5:
				var ox := -s * 0.2 + float(i % 3) * s * 0.12
				var oy := s * 0.05 + float(i % 2) * s * 0.1
				draw_rect(Rect2(ox, oy, 2.5, 2.5), primary, true)
		5: # Banded belt stack
			draw_rect(Rect2(-s * 0.2, s * 0.08, s * 0.4, s * 0.06), secondary, true)
			draw_rect(Rect2(-s * 0.2, s * 0.15, s * 0.4, s * 0.05), primary, true)
			draw_rect(Rect2(-s * 0.2, s * 0.21, s * 0.4, s * 0.04), accent, true)
		_: # Plainweave sash
			draw_rect(Rect2(-s * 0.2, s * 0.05, s * 0.4, s * 0.1), primary, true)
			draw_rect(Rect2(-s * 0.2, s * 0.08, s * 0.4, s * 0.03), accent, true)
	# Belt buckle
	draw_rect(Rect2(-s * 0.06, s * 0.12, s * 0.12, s * 0.08), accent, true)
	# Crest glyph mark on chest
	var crest := warrior.variant_crest % 5
	if crest > 0:
		var cx := 0.0
		var cy := -s * 0.02
		match crest:
			1: # sun
				draw_circle(Vector2(cx, cy), s * 0.06, accent)
			2: # moon
				draw_circle(Vector2(cx, cy), s * 0.06, secondary)
				draw_circle(Vector2(cx + s * 0.03, cy - s * 0.01), s * 0.045, Color(0.15, 0.15, 0.18, 0.9))
			3: # thorn
				draw_rect(Rect2(cx - 1.5, cy - s * 0.08, 3, s * 0.16), accent, true)
				draw_rect(Rect2(cx - s * 0.06, cy - 1.5, s * 0.12, 3), accent, true)
			_: # wave
				draw_rect(Rect2(cx - s * 0.08, cy, s * 0.16, 2.5), accent, true)
				draw_rect(Rect2(cx - s * 0.06, cy + 4, s * 0.12, 2.5), accent, true)
	# Weapon finish glint by style
	var wx := s * 0.28
	match warrior.variant_weapon_style % 4:
		1:
			draw_rect(Rect2(wx, -s * 0.15, 3, s * 0.35), Color(0.9, 0.92, 1.0, 0.85), true)
		2:
			draw_rect(Rect2(wx, -s * 0.15, 3, s * 0.35), Color(0.25, 0.28, 0.35, 0.9), true)
		3:
			draw_rect(Rect2(wx, -s * 0.15, 3, s * 0.35), Color(0.95, 0.8, 0.35, 0.9), true)
		_:
			draw_rect(Rect2(wx, -s * 0.12, 2.5, s * 0.28), Color(0.7, 0.72, 0.75, 0.7), true)
