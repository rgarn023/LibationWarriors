extends Control
## Barcode entry + beverage category selection. No brand names are shown or stored.
## Camera permission is requested on Android; scanning uses manual entry for reliability,
## with optional Open Food Facts category hints that strip brand fields.

@onready var barcode_input: LineEdit = %BarcodeInput
@onready var category_option: OptionButton = %CategoryOption
@onready var status_label: Label = %StatusLabel
@onready var result_panel: PanelContainer = %ResultPanel
@onready var result_name: Label = %ResultName
@onready var result_faction: Label = %ResultFaction
@onready var result_stats: Label = %ResultStats
@onready var result_sprite: TextureRect = %ResultSprite
@onready var btn_scan: Button = %BtnScan
@onready var btn_lookup: Button = %BtnLookup
@onready var btn_back: Button = %BtnBack
@onready var demo_box: VBoxContainer = %DemoBox
@onready var http: HTTPRequest = %HTTPRequest

var _pending_barcode := ""
var _categories: Array = []


func _ready() -> void:
	UITheme.style_button(btn_scan, true)
	UITheme.style_button(btn_lookup)
	UITheme.style_button(btn_back)
	UITheme.style_panel(result_panel)
	result_panel.visible = false
	status_label.text = "Enter a barcode from any bottle. Brands are never stored."
	_populate_categories()
	_populate_demos()
	btn_scan.pressed.connect(_on_scan_pressed)
	btn_lookup.pressed.connect(_on_lookup_pressed)
	btn_back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
	http.request_completed.connect(_on_http_completed)
	if OS.has_feature("android"):
		# Camera permission for future live scanning plugins; entry works without it.
		OS.request_permissions()


func _populate_categories() -> void:
	category_option.clear()
	_categories.clear()
	var keys := FactionData.CATEGORY_LABELS.keys()
	keys.sort()
	for cat in keys:
		_categories.append(cat)
		var faction := FactionData.faction_for_category(cat)
		category_option.add_item("%s → %s" % [FactionData.category_label(cat), FactionData.faction_label(faction)])


func _populate_demos() -> void:
	var demos := [
		{"label": "Demo Rum", "code": "DEMO-RUM-88001", "cat": FactionData.Category.RUM},
		{"label": "Demo Bourbon", "code": "DEMO-BRBN-88002", "cat": FactionData.Category.BOURBON},
		{"label": "Demo Tequila", "code": "DEMO-TEQ-88003", "cat": FactionData.Category.TEQUILA},
		{"label": "Demo Scotch", "code": "DEMO-SCT-88004", "cat": FactionData.Category.SCOTCH},
		{"label": "Demo Vodka", "code": "DEMO-VDK-88005", "cat": FactionData.Category.VODKA},
		{"label": "Demo Beer", "code": "DEMO-BEER-88006", "cat": FactionData.Category.BEER},
		{"label": "Demo Sake", "code": "DEMO-SAKE-88007", "cat": FactionData.Category.SAKE},
		{"label": "Demo Mead", "code": "DEMO-MEAD-88008", "cat": FactionData.Category.MEAD},
		{"label": "Demo Red Wine", "code": "DEMO-RWINE-88009", "cat": FactionData.Category.RED_WINE},
		{"label": "Demo Soft Drink", "code": "DEMO-SODA-88010", "cat": FactionData.Category.NON_ALCOHOLIC},
	]
	for d in demos:
		var b := Button.new()
		b.text = d.label
		UITheme.style_button(b)
		b.custom_minimum_size = Vector2(0, 44)
		b.add_theme_font_size_override("font_size", 16)
		var code: String = d.code
		var cat: int = d.cat
		b.pressed.connect(func():
			barcode_input.text = code
			_select_category(cat)
			_summon(code, cat)
		)
		demo_box.add_child(b)


func _select_category(cat: int) -> void:
	for i in _categories.size():
		if _categories[i] == cat:
			category_option.select(i)
			return


func _selected_category() -> int:
	var idx := category_option.selected
	if idx < 0 or idx >= _categories.size():
		return FactionData.Category.OTHER_ALCOHOL
	return int(_categories[idx])


func _on_scan_pressed() -> void:
	var code := barcode_input.text.strip_edges()
	if code.is_empty():
		status_label.text = "Enter a barcode first."
		return
	_summon(code, _selected_category())


func _on_lookup_pressed() -> void:
	var code := barcode_input.text.strip_edges()
	if code.is_empty():
		status_label.text = "Enter a barcode to look up category hints."
		return
	_pending_barcode = code
	status_label.text = "Looking up beverage category (brands hidden)..."
	var url := "https://world.openfoodfacts.org/api/v2/product/%s.json?fields=categories_tags,categories,product_name,generic_name,labels_tags" % code.uri_encode()
	var err := http.request(url)
	if err != OK:
		status_label.text = "Lookup failed to start. Pick a category manually."


func _on_http_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code != 200:
		status_label.text = "No category hint found. Choose the beverage type manually."
		return
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if typeof(parsed) != TYPE_DICTIONARY:
		status_label.text = "Lookup parse error. Choose category manually."
		return
	var product: Dictionary = parsed.get("product", {})
	# Build keyword blob WITHOUT using product_name as display text.
	var blob := ""
	blob += str(product.get("categories", "")) + " "
	var tags: Array = product.get("categories_tags", [])
	for t in tags:
		blob += str(t) + " "
	blob += str(product.get("generic_name", "")) + " "
	var labels: Array = product.get("labels_tags", [])
	for t in labels:
		blob += str(t) + " "
	var cat := WarriorFactory.classify_from_keywords(blob)
	if cat < 0:
		status_label.text = "Could not classify beverage. Select type manually, then Summon."
		return
	_select_category(cat)
	status_label.text = "Category hint: %s → %s. Tap Summon Warrior." % [
		FactionData.category_label(cat),
		FactionData.faction_label(FactionData.faction_for_category(cat)),
	]


func _summon(code: String, category: int) -> void:
	if GameState.has_warrior(code):
		var existing := GameState.get_warrior(code)
		_show_result(existing, true)
		status_label.text = "This barcode already summoned %s. Each barcode is unique." % existing.name
		return
	var warrior := WarriorFactory.generate(code, category)
	var result := GameState.unlock_warrior(warrior)
	if result.ok:
		_show_result(warrior, false)
		status_label.text = "A new Libation Warrior joins your ranks!"
	else:
		status_label.text = "Could not unlock warrior."


func _show_result(warrior: Warrior, duplicate: bool) -> void:
	result_panel.visible = true
	result_name.text = warrior.name
	result_faction.text = "%s  ·  %s  ·  %s" % [
		warrior.faction_display(),
		warrior.category_display(),
		warrior.bottle_palette_name,
	]
	result_stats.text = "ATK %d  DEF %d  HP %d\n%s (%d) / %s (%d)%s" % [
		warrior.attack, warrior.defense, warrior.max_hp,
		warrior.regular_move, warrior.regular_power,
		warrior.special_move, warrior.special_power,
		"\n(Already collected)" if duplicate else "",
	]
	var tex := UITheme.load_texture(warrior.preview_path())
	result_sprite.texture = tex
	result_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	result_sprite.modulate = Color(
		warrior.tint_primary.r * 0.4 + 0.6,
		warrior.tint_primary.g * 0.4 + 0.6,
		warrior.tint_primary.b * 0.4 + 0.6,
		1.0
	)
