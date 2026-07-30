class_name WarriorPortrait
extends RefCounted
## Clean warrior portraits — packaging tint on the sprite, no blocky overlays.

const PATTERN_NAMES := ["Plainweave", "Striped", "Marbled", "Runed", "Speckled", "Banded"]


static func make_portrait(warrior: Warrior, size: Vector2 = Vector2(120, 150)) -> Control:
	var root := Control.new()
	root.custom_minimum_size = size
	root.size = size
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	root.offset_right = size.x
	root.offset_bottom = size.y

	var w := size.x
	var h := size.y

	# Neutral shared frame
	_rect(root, Color(0.14, 0.15, 0.18, 1), 0, 0, w, h)
	_rect(root, Color(0.09, 0.1, 0.12, 1), 0, h * 0.78, w, h * 0.22)

	# Thin outfit accent under the feet — does not cover the character
	_rect(root, warrior.outfit_accent(), w * 0.18, h * 0.74, w * 0.64, 3.0)
	_rect(root, warrior.outfit_primary(), w * 0.28, h * 0.76, w * 0.44, 2.0)

	var tr := TextureRect.new()
	tr.position = Vector2(w * 0.1, h * 0.02)
	tr.size = Vector2(w * 0.8, h * 0.74)
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

	var footer := Label.new()
	var wp := warrior.weapon_profile()
	footer.text = "Lv%d · %s" % [warrior.level, str(wp.get("shape", "blade")).capitalize()]
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


static func apply_to_texture_rect(tr: TextureRect, warrior: Warrior) -> void:
	if tr == null or warrior == null:
		return
	if ResourceLoader.exists(warrior.preview_path()):
		tr.texture = load(warrior.preview_path())
	elif ResourceLoader.exists(warrior.sprite_path()):
		tr.texture = load(warrior.sprite_path())
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.modulate = warrior.display_modulate()
