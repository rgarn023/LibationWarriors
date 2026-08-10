extends Control

@onready var safe_root: Control = %SafeRoot
@onready var title: Label = %Title
@onready var subtitle: Label = %Subtitle
@onready var btn_scan: Button = %BtnScan
@onready var btn_collection: Button = %BtnCollection
@onready var btn_party: Button = %BtnParty
@onready var btn_battle: Button = %BtnBattle
@onready var btn_adventure: Button = %BtnAdventure
@onready var btn_events: Button = %BtnEvents
@onready var btn_refresh_events: Button = %BtnRefreshEvents
@onready var collection_count: Label = %CollectionCount
@onready var event_label: Label = %EventLabel
@onready var sprite_row: HBoxContainer = %SpriteRow


func _ready() -> void:
	SafeArea.register(safe_root)
	UITheme.style_button(btn_scan, true)
	UITheme.style_button(btn_collection)
	UITheme.style_button(btn_party)
	UITheme.style_button(btn_adventure, true)
	UITheme.style_button(btn_battle)
	UITheme.style_button(btn_events)
	UITheme.style_button(btn_refresh_events)
	btn_scan.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/scanner.tscn"))
	btn_collection.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/collection.tscn"))
	btn_party.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/party.tscn"))
	btn_adventure.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/adventure_lobby.tscn"))
	btn_battle.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/battle_lobby.tscn"))
	btn_events.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/event_admin.tscn"))
	btn_refresh_events.pressed.connect(func():
		EventService.refresh_events()
		event_label.text = "Refreshing events..."
	)
	btn_events.visible = DevBuild.allow_dev_tools()
	if DevBuild.is_dev_build():
		title.text = "LIBATION\nWARRIORS\nDEV"
	_refresh()
	_populate_showcase()
	_refresh_events_label()
	GameState.collection_changed.connect(_refresh)
	EventService.events_updated.connect(_refresh_events_label)
	EventService.fetch_finished.connect(func(ok: bool, message: String):
		event_label.text = message if not ok else (EventService.active_banner_text() if EventService.active_banner_text() != "" else "No live events.")
	)


func _refresh() -> void:
	collection_count.text = "Warriors collected: %d · %s" % [GameState.collection.size(), DevBuild.build_label()]


func _refresh_events_label() -> void:
	var banner := EventService.active_banner_text()
	event_label.text = banner if banner != "" else "No live events right now."


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
