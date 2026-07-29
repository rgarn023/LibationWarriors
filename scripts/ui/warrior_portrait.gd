class_name WarriorPortrait
extends RefCounted
## Layered warrior portraits — variants dress the warrior (gear), not the background.

const PATTERN_NAMES := ["Plainweave", "Striped", "Marbled", "Runed", "Speckled", "Banded"]
const CREST_GLYPHS := ["·", "+", ")", "#", "~"]
const GEAR_SCRIPT := preload("res://scripts/adventure/warrior_gear.gd")


static func make_portrait(warrior: Warrior, size: Vector2 = Vector2(120, 150)) -> Control:
	var root := Control.new()
	root.custom_minimum_size = size
	root.size = size
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Keep size stable when parented under a bare Control (adventure PreviewHost).
	root.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	root.offset_right = size.x
	root.offset_bottom = size.y

	var w := size.x
	var h := size.y

	# Neutral frame — same for every warrior so outfit is the variation signal.
	_rect(root, Color(0.14, 0.15, 0.18, 1), 0, 0, w, h)
	_rect(root, Color(0.09, 0.1, 0.12, 1), 0, h * 0.78, w, h * 0.22)

	var primary := warrior.outfit_primary()
	var secondary := warrior.outfit_secondary()
	var accent := warrior.outfit_accent()

	# Cape behind the sprite
	_rect(root, Color(secondary.r, secondary.g, secondary.b, 0.75), w * 0.06, h * 0.28, w * 0.2, h * 0.42)
	_rect(root, Color(secondary.r, secondary.g, secondary.b, 0.75), w * 0.74, h * 0.28, w * 0.2, h * 0.42)

	# Character art (explicit rect — anchors on zero-size parents hide TextureRect)
	var tr := TextureRect.new()
	tr.position = Vector2(w * 0.12, h * 0.04)
	tr.size = Vector2(w * 0.76, h * 0.72)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var path := warrior.preview_path()
	if ResourceLoader.exists(path):
		tr.texture = load(path)
	elif ResourceLoader.exists(warrior.sprite_path()):
		tr.texture = load(warrior.sprite_path())
	tr.modulate = warrior.display_modulate()
	root.add_child(tr)

	# Clothing overlays on top of the sprite (sash / armor / crest)
	_add_clothing_pixels(root, warrior, primary, secondary, accent, w, h)

	var footer := Label.new()
	footer.text = "Lv%d · %s" % [warrior.level, PATTERN_NAMES[warrior.variant_pattern % PATTERN_NAMES.size()]]
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.position = Vector2(0, h * 0.86)
	footer.size = Vector2(w, h * 0.14)
	footer.add_theme_font_size_override("font_size", 11)
	footer.add_theme_color_override("font_color", Color(0.9, 0.88, 0.82))
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(footer)

	return root


static func _rect(root: Control, color: Color, x: float, y: float, rw: float, rh: float) -> void:
	var r := ColorRect.new()
	r.color = color
	r.position = Vector2(x, y)
	r.size = Vector2(rw, rh)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(r)


static func _add_clothing_pixels(root: Control, warrior: Warrior, primary: Color, secondary: Color, accent: Color, w: float, h: float) -> void:
	match warrior.variant_pattern % 6:
		1: # Striped pauldrons
			_rect(root, primary, w * 0.14, h * 0.22, w * 0.22, h * 0.1)
			_rect(root, primary, w * 0.64, h * 0.22, w * 0.22, h * 0.1)
			_rect(root, accent, w * 0.14, h * 0.28, w * 0.22, h * 0.03)
			_rect(root, accent, w * 0.64, h * 0.28, w * 0.22, h * 0.03)
		2: # Marbled wrap
			_rect(root, Color(primary.r, primary.g, primary.b, 0.85), w * 0.22, h * 0.42, w * 0.56, h * 0.12)
			_rect(root, secondary, w * 0.26, h * 0.46, w * 0.48, h * 0.04)
		3: # Runed plate
			_rect(root, Color(primary.r, primary.g, primary.b, 0.8), w * 0.3, h * 0.3, w * 0.4, h * 0.24)
			_rect(root, accent, w * 0.42, h * 0.38, w * 0.16, h * 0.08)
		4: # Speckled clasp
			_rect(root, accent, w * 0.44, h * 0.26, w * 0.12, h * 0.08)
			for i in 4:
				_rect(root, primary, w * (0.32 + (i % 2) * 0.28), h * (0.48 + int(i / 2) * 0.08), w * 0.05, h * 0.04)
		5: # Banded belts
			_rect(root, secondary, w * 0.25, h * 0.48, w * 0.5, h * 0.05)
			_rect(root, primary, w * 0.25, h * 0.54, w * 0.5, h * 0.05)
			_rect(root, accent, w * 0.25, h * 0.59, w * 0.5, h * 0.04)
		_: # Plainweave sash
			_rect(root, primary, w * 0.22, h * 0.48, w * 0.56, h * 0.1)
			_rect(root, accent, w * 0.22, h * 0.51, w * 0.56, h * 0.03)

	# Belt buckle
	_rect(root, accent, w * 0.44, h * 0.52, w * 0.12, h * 0.08)

	# Crest glyph
	var crest := Label.new()
	crest.text = CREST_GLYPHS[warrior.variant_crest % CREST_GLYPHS.size()]
	crest.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crest.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	crest.position = Vector2(w * 0.38, h * 0.34)
	crest.size = Vector2(w * 0.24, h * 0.1)
	crest.add_theme_font_size_override("font_size", 16)
	crest.add_theme_color_override("font_color", accent)
	crest.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(crest)

	# Weapon finish stripe
	var wcol := Color(0.7, 0.72, 0.75, 0.85)
	match warrior.variant_weapon_style % 4:
		1:
			wcol = Color(0.9, 0.92, 1.0, 0.95)
		2:
			wcol = Color(0.25, 0.28, 0.35, 0.95)
		3:
			wcol = Color(0.95, 0.8, 0.35, 0.95)
	_rect(root, wcol, w * 0.78, h * 0.3, w * 0.05, h * 0.32)


static func apply_to_texture_rect(tr: TextureRect, warrior: Warrior) -> void:
	if tr == null or warrior == null:
		return
	if ResourceLoader.exists(warrior.preview_path()):
		tr.texture = load(warrior.preview_path())
	elif ResourceLoader.exists(warrior.sprite_path()):
		tr.texture = load(warrior.sprite_path())
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.modulate = warrior.display_modulate()


static func attach_world_gear(parent: Node2D, warrior: Warrior, body_scale: float = 0.42) -> Node2D:
	var gear: Node2D = GEAR_SCRIPT.new()
	gear.name = "OutfitGear"
	parent.add_child(gear)
	gear.call("configure", warrior, body_scale, true)
	return gear
