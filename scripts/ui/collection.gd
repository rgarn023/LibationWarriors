extends Control

@onready var safe_root: Control = %SafeRoot
@onready var list: VBoxContainer = %List
@onready var detail_panel: PanelContainer = %DetailPanel
@onready var detail_name: Label = %DetailName
@onready var detail_info: Label = %DetailInfo
@onready var detail_sprite: TextureRect = %DetailSprite
@onready var empty_label: Label = %EmptyLabel
@onready var btn_back: Button = %BtnBack

var _selected: Warrior = null


func _ready() -> void:
	SafeArea.register(safe_root)
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
		row.text = "Lv.%d  %s  [%s]" % [w.level, w.name, w.faction_display()]
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		UITheme.style_button(row)
		row.custom_minimum_size = Vector2(0, 52)
		var warrior_ref := w
		row.pressed.connect(func(): _show_detail(warrior_ref))
		list.add_child(row)


func _show_detail(w: Warrior) -> void:
	_selected = w
	detail_panel.visible = true
	detail_name.text = "Lv.%d  %s" % [w.level, w.name]
	var regular := w.regular_attack_data()
	var special := w.special_attack_data()
	detail_info.text = "%s · %s\nXP %d / %d\nWarrior ID: %s\nAppearance: %s\nATK %d  DEF %d  HP %d\nRegular: %s (%d)\nSpecial: %s (%d)\nEquipment slots: %d" % [
		w.faction_display(), w.category_display(),
		w.xp, w.xp_to_next_level(),
		w.barcode_hash.substr(0, 10).to_upper(),
		w.appearance_signature if not w.appearance_signature.is_empty() else w.variant_label(),
		w.attack, w.defense, w.max_hp,
		str(regular.get("name", w.regular_move)), int(regular.get("power", w.regular_power)),
		str(special.get("name", w.special_move)), int(special.get("power", w.special_power)),
		w.equipment.size(),
	]
	WarriorPortrait.apply_to_texture_rect(detail_sprite, w)
	detail_sprite.custom_minimum_size = Vector2(120, 160)
	var parent := detail_sprite.get_parent()
	if parent != null:
		var old := parent.get_node_or_null("DetailPortrait")
		if old:
			old.queue_free()
		var portrait := WarriorPortrait.make_portrait(w, Vector2(120, 150))
		portrait.name = "DetailPortrait"
		parent.add_child(portrait)
		parent.move_child(portrait, detail_sprite.get_index())
		detail_sprite.visible = false
