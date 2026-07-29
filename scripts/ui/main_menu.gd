extends Control

@onready var safe_root: Control = %SafeRoot
@onready var title: Label = %Title
@onready var subtitle: Label = %Subtitle
@onready var btn_scan: Button = %BtnScan
@onready var btn_collection: Button = %BtnCollection
@onready var btn_party: Button = %BtnParty
@onready var btn_battle: Button = %BtnBattle
@onready var btn_adventure: Button = %BtnAdventure
@onready var collection_count: Label = %CollectionCount
@onready var sprite_row: HBoxContainer = %SpriteRow


func _ready() -> void:
	SafeArea.register(safe_root)
	UITheme.style_button(btn_scan, true)
	UITheme.style_button(btn_collection)
	UITheme.style_button(btn_party)
	UITheme.style_button(btn_adventure, true)
	UITheme.style_button(btn_battle)
	btn_scan.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/scanner.tscn"))
	btn_collection.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/collection.tscn"))
	btn_party.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/party.tscn"))
	btn_adventure.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/adventure_lobby.tscn"))
	btn_battle.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/battle_lobby.tscn"))
	_refresh()
	_populate_showcase()
	GameState.collection_changed.connect(_refresh)


func _refresh() -> void:
	collection_count.text = "Warriors collected: %d" % GameState.collection.size()


func _populate_showcase() -> void:
	for child in sprite_row.get_children():
		child.queue_free()
	var showcase := ["pirate", "samurai", "bard", "viking", "red_mage"]
	for f in showcase:
		var tex := UITheme.load_texture("res://assets/sprites/%s_preview.png" % f)
		if tex == null:
			continue
		var tr := TextureRect.new()
		tr.texture = tex
		tr.custom_minimum_size = Vector2(80, 100)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite_row.add_child(tr)
