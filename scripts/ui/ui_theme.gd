class_name UITheme
extends RefCounted
## Shared UI helpers and palette for Libation Warriors.

const C_BG := Color(0.07, 0.06, 0.1)
const C_PANEL := Color(0.12, 0.1, 0.16)
const C_ACCENT := Color(0.85, 0.62, 0.22)
const C_TEXT := Color(0.95, 0.92, 0.85)
const C_MUTED := Color(0.65, 0.6, 0.55)
const C_DANGER := Color(0.75, 0.25, 0.3)
const C_OK := Color(0.3, 0.65, 0.4)


static func style_button(btn: Button, accent: bool = false) -> void:
	btn.custom_minimum_size = Vector2(0, 56)
	btn.add_theme_font_size_override("font_size", 20)
	var normal := StyleBoxFlat.new()
	normal.bg_color = C_ACCENT if accent else C_PANEL
	normal.set_corner_radius_all(6)
	normal.content_margin_left = 16
	normal.content_margin_right = 16
	normal.content_margin_top = 10
	normal.content_margin_bottom = 10
	if not accent:
		normal.border_color = C_ACCENT
		normal.set_border_width_all(1)
	btn.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate()
	hover.bg_color = hover.bg_color.lightened(0.08)
	btn.add_theme_stylebox_override("hover", hover)
	var pressed := normal.duplicate()
	pressed.bg_color = pressed.bg_color.darkened(0.1)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_color_override("font_color", C_BG if accent else C_TEXT)


static func style_panel(panel: PanelContainer) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = C_PANEL
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	sb.border_color = Color(0.3, 0.25, 0.2)
	sb.set_border_width_all(1)
	panel.add_theme_stylebox_override("panel", sb)


static func load_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	return null


static func tinted_texture_rect(tex: Texture2D, tint: Color) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = tex
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.custom_minimum_size = Vector2(96, 96)
	tr.modulate = Color(tint.r * 0.55 + 0.45, tint.g * 0.55 + 0.45, tint.b * 0.55 + 0.45, 1.0)
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return tr
