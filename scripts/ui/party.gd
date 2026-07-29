extends Control

@onready var safe_root: Control = %SafeRoot
@onready var slots: VBoxContainer = %Slots
@onready var picker: VBoxContainer = %Picker
@onready var status_label: Label = %StatusLabel
@onready var btn_back: Button = %BtnBack
@onready var btn_clear: Button = %BtnClear

var _active_slot := -1
var _slot_buttons: Array[Button] = []


func _ready() -> void:
	SafeArea.register(safe_root)
	UITheme.style_button(btn_back)
	UITheme.style_button(btn_clear)
	btn_back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
	btn_clear.pressed.connect(_clear_party)
	_build_slots()
	_refresh()
	GameState.party_changed.connect(_refresh)
	GameState.collection_changed.connect(_refresh)


func _build_slots() -> void:
	for i in GameState.PARTY_SIZE:
		var b := Button.new()
		b.custom_minimum_size = Vector2(0, 64)
		UITheme.style_button(b, true)
		var idx := i
		b.pressed.connect(func(): _select_slot(idx))
		slots.add_child(b)
		_slot_buttons.append(b)


func _select_slot(index: int) -> void:
	_active_slot = index
	status_label.text = "Choose a warrior for party slot %d." % (index + 1)
	_refresh_picker()


func _refresh() -> void:
	for i in GameState.PARTY_SIZE:
		var code: String = GameState.party[i]
		if code == "":
			_slot_buttons[i].text = "Slot %d — Empty" % (i + 1)
		else:
			var w := GameState.get_warrior(code)
			_slot_buttons[i].text = "Slot %d — %s [%s]" % [i + 1, w.name, w.faction_display()]
	if GameState.party_is_ready():
		status_label.text = "Party ready for battle!"
	elif _active_slot < 0:
		status_label.text = "Tap a slot, then pick a warrior. Parties need 3 unique warriors."
	_refresh_picker()


func _refresh_picker() -> void:
	for c in picker.get_children():
		c.queue_free()
	if _active_slot < 0:
		return
	var warriors := GameState.get_all_warriors()
	if warriors.is_empty():
		var lab := Label.new()
		lab.text = "No warriors yet. Scan bottles first."
		lab.add_theme_color_override("font_color", UITheme.C_MUTED)
		picker.add_child(lab)
		return
	for w in warriors:
		var b := Button.new()
		b.text = "%s  ATK%d DEF%d" % [w.name, w.attack, w.defense]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		UITheme.style_button(b)
		var code := w.barcode
		b.pressed.connect(func():
			GameState.set_party_slot(_active_slot, code)
			status_label.text = "Assigned %s to slot %d." % [w.name, _active_slot + 1]
		)
		picker.add_child(b)
	var clear_slot := Button.new()
	clear_slot.text = "Clear this slot"
	UITheme.style_button(clear_slot)
	clear_slot.pressed.connect(func(): GameState.clear_party_slot(_active_slot))
	picker.add_child(clear_slot)


func _clear_party() -> void:
	for i in GameState.PARTY_SIZE:
		GameState.clear_party_slot(i)
	_active_slot = -1
	status_label.text = "Party cleared."
