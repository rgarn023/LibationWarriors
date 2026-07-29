class_name WarriorPortrait
extends RefCounted
## Builds layered warrior portraits so barcode variants + packaging colors read clearly.

const PATTERN_NAMES := ["Plainweave", "Striped", "Marbled", "Runed", "Speckled", "Banded"]
const CREST_GLYPHS := ["+", "*", "~", "#", "="]


static func make_portrait(warrior: Warrior, size: Vector2 = Vector2(120, 150)) -> Control:
	var root := Control.new()
	root.custom_minimum_size = size
	root.size = size

	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(warrior.tint_secondary.r * 0.35, warrior.tint_secondary.g * 0.35, warrior.tint_secondary.b * 0.35, 0.9)
	root.add_child(bg)

	# Pattern overlay
	var pattern := ColorRect.new()
	pattern.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pattern.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pattern.color = _pattern_color(warrior)
	root.add_child(pattern)

	var tr := TextureRect.new()
	tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tr.offset_left = 8
	tr.offset_top = 8
	tr.offset_right = -8
	tr.offset_bottom = -22
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if ResourceLoader.exists(warrior.preview_path()):
		tr.texture = load(warrior.preview_path())
	tr.modulate = warrior.display_modulate()
	root.add_child(tr)

	# Accent sash / weapon finish bar
	var sash := ColorRect.new()
	sash.anchor_left = 0.12
	sash.anchor_right = 0.88
	sash.anchor_top = 0.72
	sash.anchor_bottom = 0.78
	sash.offset_left = 0
	sash.offset_right = 0
	sash.offset_top = 0
	sash.offset_bottom = 0
	sash.color = warrior.tint_accent
	sash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(sash)

	# Crest badge
	var crest := Label.new()
	crest.text = CREST_GLYPHS[warrior.variant_crest % CREST_GLYPHS.size()]
	crest.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	crest.anchor_left = 0.7
	crest.anchor_right = 0.95
	crest.anchor_top = 0.05
	crest.anchor_bottom = 0.2
	crest.add_theme_font_size_override("font_size", 18)
	crest.add_theme_color_override("font_color", warrior.tint_accent)
	root.add_child(crest)

	var footer := Label.new()
	footer.text = "Lv%d · %s" % [warrior.level, PATTERN_NAMES[warrior.variant_pattern % PATTERN_NAMES.size()]]
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.anchor_top = 0.86
	footer.anchor_bottom = 1.0
	footer.anchor_right = 1.0
	footer.add_theme_font_size_override("font_size", 11)
	footer.add_theme_color_override("font_color", Color(0.92, 0.88, 0.8))
	root.add_child(footer)

	return root


static func _pattern_color(w: Warrior) -> Color:
	var a := w.tint_accent
	match w.variant_pattern % 6:
		0:
			return Color(a.r, a.g, a.b, 0.05)
		1:
			return Color(a.r, a.g, a.b, 0.18)
		2:
			return Color(w.tint_secondary.r, w.tint_secondary.g, w.tint_secondary.b, 0.22)
		3:
			return Color(a.r * 0.8, a.g * 0.9, a.b, 0.2)
		4:
			return Color(w.tint_primary.r, w.tint_primary.g, w.tint_primary.b, 0.12)
		_:
			return Color(a.r, a.g, a.b, 0.15)


static func apply_to_texture_rect(tr: TextureRect, warrior: Warrior) -> void:
	if tr == null or warrior == null:
		return
	if ResourceLoader.exists(warrior.preview_path()):
		tr.texture = load(warrior.preview_path())
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.modulate = warrior.display_modulate()
