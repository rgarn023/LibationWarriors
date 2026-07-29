class_name WarriorPortrait
extends RefCounted
## Layered warrior portraits — variants dress the warrior (gear), not the background.

const PATTERN_NAMES := ["Plainweave", "Striped", "Marbled", "Runed", "Speckled", "Banded"]
const CREST_GLYPHS := ["·", "+", ")", "‡", "~"]


static func make_portrait(warrior: Warrior, size: Vector2 = Vector2(120, 150)) -> Control:
	var root := Control.new()
	root.custom_minimum_size = size
	root.size = size

	# Neutral frame — same for every warrior so outfit is the variation signal.
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.12, 0.13, 0.16, 0.95)
	root.add_child(bg)

	var floor_strip := ColorRect.new()
	floor_strip.anchor_top = 0.78
	floor_strip.anchor_bottom = 1.0
	floor_strip.anchor_right = 1.0
	floor_strip.offset_left = 0
	floor_strip.offset_right = 0
	floor_strip.offset_top = 0
	floor_strip.offset_bottom = 0
	floor_strip.color = Color(0.08, 0.09, 0.11, 1)
	floor_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(floor_strip)

	var tr := TextureRect.new()
	tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tr.offset_left = 10
	tr.offset_top = 6
	tr.offset_right = -10
	tr.offset_bottom = -28
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if ResourceLoader.exists(warrior.preview_path()):
		tr.texture = load(warrior.preview_path())
	tr.modulate = warrior.display_modulate()
	root.add_child(tr)

	# Clothing layers (Control ColorRects over the sprite midsection)
	_add_clothing_layers(root, warrior)

	var footer := Label.new()
	footer.text = "Lv%d · %s" % [warrior.level, PATTERN_NAMES[warrior.variant_pattern % PATTERN_NAMES.size()]]
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.anchor_top = 0.86
	footer.anchor_bottom = 1.0
	footer.anchor_right = 1.0
	footer.add_theme_font_size_override("font_size", 11)
	footer.add_theme_color_override("font_color", Color(0.88, 0.86, 0.8))
	root.add_child(footer)

	return root


static func _add_clothing_layers(root: Control, warrior: Warrior) -> void:
	var primary := warrior.outfit_primary()
	var secondary := warrior.outfit_secondary()
	var accent := warrior.outfit_accent()

	# Cape / cloak panels
	var cape_l := ColorRect.new()
	cape_l.anchor_left = 0.08
	cape_l.anchor_right = 0.28
	cape_l.anchor_top = 0.28
	cape_l.anchor_bottom = 0.72
	cape_l.color = Color(secondary.r, secondary.g, secondary.b, 0.7)
	cape_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(cape_l)
	var cape_r := ColorRect.new()
	cape_r.anchor_left = 0.72
	cape_r.anchor_right = 0.92
	cape_r.anchor_top = 0.28
	cape_r.anchor_bottom = 0.72
	cape_r.color = Color(secondary.r, secondary.g, secondary.b, 0.7)
	cape_r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(cape_r)

	# Pattern-specific gear
	match warrior.variant_pattern % 6:
		1: # Striped pauldrons
			_band(root, 0.12, 0.4, 0.22, 0.32, primary)
			_band(root, 0.6, 0.88, 0.22, 0.32, primary)
			_band(root, 0.12, 0.4, 0.28, 0.31, accent)
			_band(root, 0.6, 0.88, 0.28, 0.31, accent)
		2: # Marbled wrap
			_band(root, 0.22, 0.78, 0.42, 0.55, Color(primary.r, primary.g, primary.b, 0.85))
			_band(root, 0.26, 0.74, 0.46, 0.5, secondary)
		3: # Runed plate
			_band(root, 0.3, 0.7, 0.3, 0.55, Color(primary.r, primary.g, primary.b, 0.8))
			_band(root, 0.42, 0.58, 0.4, 0.48, accent)
		4: # Speckled clasp
			_band(root, 0.44, 0.56, 0.26, 0.34, accent)
			for i in 4:
				var speck := ColorRect.new()
				speck.anchor_left = 0.3 + (i % 2) * 0.25
				speck.anchor_right = speck.anchor_left + 0.06
				speck.anchor_top = 0.48 + (i / 2) * 0.1
				speck.anchor_bottom = speck.anchor_top + 0.05
				speck.color = primary
				speck.mouse_filter = Control.MOUSE_FILTER_IGNORE
				root.add_child(speck)
		5: # Banded belts
			_band(root, 0.25, 0.75, 0.48, 0.54, secondary)
			_band(root, 0.25, 0.75, 0.54, 0.59, primary)
			_band(root, 0.25, 0.75, 0.59, 0.63, accent)
		_: # Plainweave sash
			_band(root, 0.22, 0.78, 0.48, 0.58, primary)
			_band(root, 0.22, 0.78, 0.51, 0.54, accent)

	# Belt buckle
	_band(root, 0.44, 0.56, 0.52, 0.6, accent)

	# Crest
	var crest := Label.new()
	crest.text = CREST_GLYPHS[warrior.variant_crest % CREST_GLYPHS.size()]
	crest.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crest.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	crest.anchor_left = 0.4
	crest.anchor_right = 0.6
	crest.anchor_top = 0.34
	crest.anchor_bottom = 0.46
	crest.add_theme_font_size_override("font_size", 16)
	crest.add_theme_color_override("font_color", accent)
	crest.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(crest)

	# Weapon finish stripe
	var weapon := ColorRect.new()
	weapon.anchor_left = 0.78
	weapon.anchor_right = 0.84
	weapon.anchor_top = 0.3
	weapon.anchor_bottom = 0.62
	match warrior.variant_weapon_style % 4:
		1:
			weapon.color = Color(0.9, 0.92, 1.0, 0.9)
		2:
			weapon.color = Color(0.25, 0.28, 0.35, 0.95)
		3:
			weapon.color = Color(0.95, 0.8, 0.35, 0.95)
		_:
			weapon.color = Color(0.7, 0.72, 0.75, 0.75)
	weapon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(weapon)


static func _band(root: Control, l: float, r: float, t: float, b: float, color: Color) -> void:
	var rect := ColorRect.new()
	rect.anchor_left = l
	rect.anchor_right = r
	rect.anchor_top = t
	rect.anchor_bottom = b
	rect.color = color
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(rect)


static func apply_to_texture_rect(tr: TextureRect, warrior: Warrior) -> void:
	if tr == null or warrior == null:
		return
	if ResourceLoader.exists(warrior.preview_path()):
		tr.texture = load(warrior.preview_path())
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.modulate = warrior.display_modulate()


static func attach_world_gear(parent: Node2D, warrior: Warrior, body_scale: float = 0.42) -> Node2D:
	var gear: Node2D = GEAR_SCRIPT.new()
	gear.name = "OutfitGear"
	parent.add_child(gear)
	gear.call("configure", warrior, body_scale, true)
	return gear
