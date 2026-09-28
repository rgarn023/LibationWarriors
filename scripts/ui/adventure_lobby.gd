extends Control
## Explore setup: choose an owned warrior, difficulty, then generate a seeded dungeon.

@onready var safe_root: Control = %SafeRoot
@onready var warrior_list: VBoxContainer = %WarriorList
@onready var preview_host: Control = %PreviewHost
@onready var preview_name: Label = %PreviewName
@onready var preview_level: Label = %PreviewLevel
@onready var preview_faction: Label = %PreviewFaction
@onready var dungeon_name_label: Label = %DungeonName
@onready var dungeon_mode: OptionButton = %DungeonMode
@onready var difficulty: OptionButton = %Difficulty
@onready var event_banner: Label = %EventBanner
@onready var start_btn: Button = %StartBtn
@onready var back_btn: Button = %BackBtn
@onready var empty_label: Label = %EmptyLabel

var _selected: Warrior = null
var _preview_seed: int = 0
var _mode_themes: Array = []
var _difficulty_ids := ["easy", "normal", "hard"]


func _ready() -> void:
	SafeArea.register(safe_root)
	UITheme.style_button(start_btn, true)
	UITheme.style_button(back_btn)
	start_btn.pressed.connect(_on_start)
	back_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
	dungeon_mode.item_selected.connect(func(_i): _update_dungeon_preview())
	difficulty.item_selected.connect(func(_i): _update_dungeon_preview())
	for id in _difficulty_ids:
		difficulty.add_item(DungeonBalanceConfig.label(id))
	difficulty.select(1)
	_preview_seed = int(Time.get_ticks_msec())
	_rebuild_modes()
	_refresh()
	EventService.events_updated.connect(_rebuild_modes)


func _rebuild_modes() -> void:
	dungeon_mode.clear()
	_mode_themes.clear()
	dungeon_mode.add_item("Standard random dungeon")
	_mode_themes.append({})
	var banner := EventService.active_banner_text()
	event_banner.text = banner if banner != "" else "No live event dungeon right now."
	for sd in EventService.get_active_special_dungeons():
		dungeon_mode.add_item("EVENT: %s" % str(sd.get("name", "Special")))
		_mode_themes.append(sd)
	_update_dungeon_preview()


func _refresh() -> void:
	for c in warrior_list.get_children():
		c.queue_free()
	var warriors := GameState.get_all_warriors()
	empty_label.visible = warriors.is_empty()
	start_btn.disabled = warriors.is_empty()
	for w in warriors:
		var btn := Button.new()
		btn.text = "Lv.%d  %s  [%s]" % [w.level, w.name, w.faction_display()]
		btn.custom_minimum_size = Vector2(0, 52)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		UITheme.style_button(btn)
		var ref := w
		btn.pressed.connect(func(): _select(ref))
		warrior_list.add_child(btn)
	if not warriors.is_empty():
		_select(warriors[0])
	else:
		dungeon_name_label.text = "Discover a warrior first."
		preview_name.text = "—"
		preview_level.text = ""
		preview_faction.text = ""


func _select(w: Warrior) -> void:
	_selected = w
	preview_name.text = w.name
	preview_level.text = "Level %d · XP %d / %d" % [w.level, w.xp, w.xp_to_next_level()]
	preview_faction.text = "%s · %s" % [w.faction_display(), w.category_display()]
	for c in preview_host.get_children():
		c.queue_free()
	var portrait := WarriorPortrait.make_portrait(w, Vector2(140, 175))
	portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	preview_host.add_child(portrait)
	_update_dungeon_preview()


func _selected_theme() -> Dictionary:
	var idx := dungeon_mode.selected
	return _mode_themes[idx] if idx >= 0 and idx < _mode_themes.size() else {}


func _selected_difficulty() -> String:
	return _difficulty_ids[clampi(difficulty.selected, 0, _difficulty_ids.size() - 1)]


func _update_dungeon_preview() -> void:
	if _selected == null:
		return
	var theme := _selected_theme()
	var diff := _selected_difficulty()
	var dungeon := DungeonGenerator.generate(_selected.level, _preview_seed + _selected.seed_value, theme, diff)
	var tag := "EVENT" if not theme.is_empty() else "Seeded"
	dungeon_name_label.text = "%s · %s · %s · %d rooms" % [
		tag, dungeon["name"], DungeonBalanceConfig.label(diff), dungeon["rooms"].size()
	]


func _on_start() -> void:
	if _selected == null:
		return
	var dungeon := DungeonGenerator.generate(_selected.level, 0, _selected_theme(), _selected_difficulty())
	GameState.begin_adventure(_selected.barcode, dungeon)
	get_tree().change_scene_to_file("res://scenes/dungeon_explore.tscn")
