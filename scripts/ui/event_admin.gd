extends Control
## Developer-only event authoring. Export JSON → replace events/live_events.json → push.

@onready var safe_root: Control = %SafeRoot
@onready var status_label: Label = %StatusLabel
@onready var event_id: LineEdit = %EventId
@onready var event_title: LineEdit = %EventTitle
@onready var event_desc: TextEdit = %EventDesc
@onready var starts_at: LineEdit = %StartsAt
@onready var ends_at: LineEdit = %EndsAt
@onready var dungeon_name: LineEdit = %DungeonName
@onready var dungeon_boss: LineEdit = %DungeonBoss
@onready var dungeon_enemy: LineEdit = %DungeonEnemy
@onready var barcode_code: LineEdit = %BarcodeCode
@onready var barcode_name: LineEdit = %BarcodeName
@onready var barcode_rarity: OptionButton = %BarcodeRarity
@onready var barcode_category: OptionButton = %BarcodeCategory
@onready var event_list: VBoxContainer = %EventList
@onready var btn_add_event: Button = %BtnAddEvent
@onready var btn_add_barcode: Button = %BtnAddBarcode
@onready var btn_export: Button = %BtnExport
@onready var btn_preview: Button = %BtnPreview
@onready var btn_refresh: Button = %BtnRefresh
@onready var btn_back: Button = %BtnBack
@onready var json_preview: TextEdit = %JsonPreview

var _draft: Dictionary = {"version": 1, "updated_at": "", "events": []}
var _categories: Array = []
var _editing_index: int = -1
var _pending_barcodes: Array = []


func _ready() -> void:
	if not DevBuild.allow_dev_tools():
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
		return
	SafeArea.register(safe_root)
	for b in [btn_add_event, btn_add_barcode, btn_export, btn_preview, btn_refresh, btn_back]:
		UITheme.style_button(b, b == btn_export)
	btn_add_event.pressed.connect(_on_add_event)
	btn_add_barcode.pressed.connect(_on_add_barcode)
	btn_export.pressed.connect(_on_export)
	btn_preview.pressed.connect(_on_preview)
	btn_refresh.pressed.connect(func(): EventService.refresh_events())
	btn_back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
	_populate_categories()
	barcode_rarity.clear()
	for r in ["rare", "legendary"]:
		barcode_rarity.add_item(r)
	_draft = EventService.load_draft()
	_reset_form_defaults()
	_refresh_list()
	_refresh_json()
	status_label.text = "DEV Event Admin · export JSON, commit events/live_events.json, push to publish."


func _populate_categories() -> void:
	barcode_category.clear()
	_categories.clear()
	var keys := FactionData.CATEGORY_LABELS.keys()
	keys.sort()
	for cat in keys:
		_categories.append(cat)
		barcode_category.add_item(FactionData.category_label(cat))
	if barcode_category.item_count > 0:
		barcode_category.select(mini(9, barcode_category.item_count - 1)) # white wine-ish default


func _reset_form_defaults() -> void:
	var today := Time.get_date_string_from_system(true)
	event_id.text = "event_%d" % int(Time.get_unix_time_from_system())
	event_title.text = "New Vigil"
	event_desc.text = "Limited-time dungeon and/or rare barcode."
	starts_at.text = today + "T00:00:00Z"
	ends_at.text = "2026-12-31T23:59:59Z"
	dungeon_name.text = "Moonwell Sanctum"
	dungeon_boss.text = "Lunar Cantor"
	dungeon_enemy.text = "Moonshade"
	barcode_code.text = "EVENT-RARE-001"
	barcode_name.text = "Relic Libation"
	_pending_barcodes.clear()


func _refresh_list() -> void:
	for c in event_list.get_children():
		c.queue_free()
	var events: Array = _draft.get("events", [])
	for i in events.size():
		var e: Dictionary = events[i]
		var row := HBoxContainer.new()
		var lab := Label.new()
		lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lab.text = "%s · %s" % [e.get("id", "?"), e.get("title", "?")]
		lab.add_theme_color_override("font_color", UITheme.C_TEXT)
		lab.autowrap_mode = TextServer.AUTOWRAP_WORD
		row.add_child(lab)
		var edit := Button.new()
		edit.text = "Load"
		UITheme.style_button(edit)
		edit.custom_minimum_size = Vector2(72, 44)
		var idx := i
		edit.pressed.connect(func(): _load_event(idx))
		row.add_child(edit)
		var del := Button.new()
		del.text = "Del"
		UITheme.style_button(del)
		del.custom_minimum_size = Vector2(64, 44)
		del.pressed.connect(func(): _delete_event(idx))
		row.add_child(del)
		event_list.add_child(row)


func _load_event(index: int) -> void:
	var events: Array = _draft.get("events", [])
	if index < 0 or index >= events.size():
		return
	_editing_index = index
	var e: Dictionary = events[index]
	event_id.text = str(e.get("id", ""))
	event_title.text = str(e.get("title", ""))
	event_desc.text = str(e.get("description", ""))
	starts_at.text = str(e.get("starts_at", ""))
	ends_at.text = str(e.get("ends_at", ""))
	var sd: Dictionary = e.get("special_dungeon", {})
	dungeon_name.text = str(sd.get("name", ""))
	dungeon_boss.text = str(sd.get("boss", ""))
	dungeon_enemy.text = str(sd.get("enemy_label", ""))
	_pending_barcodes = e.get("special_barcodes", []).duplicate(true)
	status_label.text = "Loaded event %s (%d barcodes)." % [event_id.text, _pending_barcodes.size()]
	_refresh_json()


func _delete_event(index: int) -> void:
	var events: Array = _draft.get("events", [])
	if index < 0 or index >= events.size():
		return
	events.remove_at(index)
	_draft["events"] = events
	_editing_index = -1
	EventService.save_draft(_draft)
	_refresh_list()
	_refresh_json()


func _on_add_barcode() -> void:
	var cat_idx := barcode_category.selected
	var cat := int(_categories[cat_idx]) if cat_idx >= 0 and cat_idx < _categories.size() else FactionData.Category.OTHER_ALCOHOL
	var rarity := barcode_rarity.get_item_text(barcode_rarity.selected)
	var code := barcode_code.text.strip_edges()
	if code.is_empty():
		status_label.text = "Barcode required."
		return
	if not code.begins_with("EVENT-") and not code.begins_with("LW-"):
		code = "EVENT-%s" % code
		barcode_code.text = code
	_pending_barcodes.append({
		"barcode": code,
		"name": barcode_name.text.strip_edges(),
		"category": cat,
		"rarity": rarity,
		"palette_name": "Event Relic",
		"tint_primary": [0.85, 0.7, 0.35, 1],
		"tint_secondary": [0.25, 0.2, 0.15, 1],
		"tint_accent": [0.95, 0.85, 0.45, 1],
	})
	status_label.text = "Queued barcode %s (%d total on this event)." % [code, _pending_barcodes.size()]


func _build_event_from_form() -> Dictionary:
	var sd := {}
	if dungeon_name.text.strip_edges() != "":
		sd = {
			"name": dungeon_name.text.strip_edges(),
			"boss": dungeon_boss.text.strip_edges(),
			"enemy_label": dungeon_enemy.text.strip_edges(),
			"floor": [0.12, 0.14, 0.22, 1],
			"wall": [0.22, 0.26, 0.4, 1],
			"accent": [0.7, 0.8, 0.95, 1],
			"enemy_factions": ["white_mage", "druid", "paladin"],
		}
	return {
		"id": event_id.text.strip_edges(),
		"title": event_title.text.strip_edges(),
		"description": event_desc.text.strip_edges(),
		"enabled": true,
		"starts_at": starts_at.text.strip_edges(),
		"ends_at": ends_at.text.strip_edges(),
		"special_dungeon": sd,
		"special_barcodes": _pending_barcodes.duplicate(true),
	}


func _on_add_event() -> void:
	var ev := _build_event_from_form()
	if ev["id"] == "" or ev["title"] == "":
		status_label.text = "Event id and title required."
		return
	var events: Array = _draft.get("events", [])
	if _editing_index >= 0 and _editing_index < events.size():
		events[_editing_index] = ev
	else:
		events.append(ev)
	_draft["events"] = events
	_editing_index = -1
	EventService.save_draft(_draft)
	_refresh_list()
	_refresh_json()
	status_label.text = "Saved event %s to draft." % ev["id"]
	_pending_barcodes.clear()


func _on_export() -> void:
	EventService.save_draft(_draft)
	var text := EventService.export_draft_json(_draft)
	_refresh_json()
	status_label.text = "Exported + copied to clipboard. Paste into events/live_events.json and push."
	json_preview.text = text


func _on_preview() -> void:
	EventService.apply_draft_locally(_draft)
	status_label.text = "Draft applied on this device only (dev preview)."


func _refresh_json() -> void:
	json_preview.text = JSON.stringify(_draft, "\t")
