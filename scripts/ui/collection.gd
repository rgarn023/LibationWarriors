extends Control

@onready var list: VBoxContainer = %List
@onready var detail_panel: PanelContainer = %DetailPanel
@onready var detail_name: Label = %DetailName
@onready var detail_info: Label = %DetailInfo
@onready var detail_sprite: TextureRect = %DetailSprite
@onready var empty_label: Label = %EmptyLabel
@onready var btn_back: Button = %BtnBack

var _selected: Warrior = null


func _ready() -> void:
	UITheme.style_button(btn_back)
	UITheme.style_panel(detail_panel)
	btn_back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
	detail_panel.visible = false
	_refresh()
	GameState.collection_changed.connect(_refresh)


func _refresh() -> void:
	for c in list.get_children():
		c.queue_free()
	var warriors := GameState.get_all_warriors()
	empty_label.visible = warriors.is_empty()
	for w in warriors:
		var row := Button.new()
		row.text = "%s  [%s]" % [w.name, w.faction_display()]
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		UITheme.style_button(row)
		row.custom_minimum_size = Vector2(0, 52)
		var warrior_ref := w
		row.pressed.connect(func(): _show_detail(warrior_ref))
		list.add_child(row)


func _show_detail(w: Warrior) -> void:
	_selected = w
	detail_panel.visible = true
	detail_name.text = w.name
	detail_info.text = "%s · %s\nPalette: %s\nATK %d  DEF %d  HP %d\nRegular: %s (%d)\nSpecial: %s (%d)\nBarcode: %s" % [
		w.faction_display(), w.category_display(), w.bottle_palette_name,
		w.attack, w.defense, w.max_hp,
		w.regular_move, w.regular_power,
		w.special_move, w.special_power,
		w.barcode,
	]
	detail_sprite.texture = UITheme.load_texture(w.preview_path())
	detail_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	detail_sprite.modulate = Color(w.tint_primary.r * 0.4 + 0.6, w.tint_primary.g * 0.4 + 0.6, w.tint_primary.b * 0.4 + 0.6, 1)
