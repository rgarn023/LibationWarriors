extends Control
## Bottle UPC scanner with automatic product-type identification (no brand display).

@onready var safe_root: Control = %SafeRoot
@onready var barcode_input: LineEdit = %BarcodeInput
@onready var category_option: OptionButton = %CategoryOption
@onready var status_label: Label = %StatusLabel
@onready var identified_label: Label = %IdentifiedLabel
@onready var result_panel: PanelContainer = %ResultPanel
@onready var result_name: Label = %ResultName
@onready var result_faction: Label = %ResultFaction
@onready var result_stats: Label = %ResultStats
@onready var result_sprite: TextureRect = %ResultSprite
@onready var btn_camera: Button = %BtnCamera
@onready var btn_scan: Button = %BtnScan
@onready var btn_lookup: Button = %BtnLookup
@onready var btn_back: Button = %BtnBack
@onready var demo_box: VBoxContainer = %DemoBox
@onready var http: HTTPRequest = %HTTPRequest
@onready var camera_hint: Label = %CameraHint

var _categories: Array = []
var _identified_category: int = -1
var _lookup_pending := false
var _auto_summon_after_lookup := false
var _lookup_code := ""


func _ready() -> void:
	SafeArea.register(safe_root)
	UITheme.style_button(btn_camera, true)
	UITheme.style_button(btn_scan, true)
	UITheme.style_button(btn_lookup)
	UITheme.style_button(btn_back)
	UITheme.style_panel(result_panel)
	result_panel.visible = false
	identified_label.text = "Item type: not identified yet"
	_populate_categories()
	_populate_demos()
	btn_camera.pressed.connect(_on_camera_pressed)
	btn_scan.pressed.connect(_on_scan_pressed)
	btn_lookup.pressed.connect(_on_lookup_pressed)
	btn_back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
	category_option.item_selected.connect(_on_category_chosen)
	http.request_completed.connect(_on_http_completed)
	UpcScanner.barcode_scanned.connect(_on_camera_barcode)
	UpcScanner.scan_cancelled.connect(func(): status_label.text = "Camera scan cancelled.")
	UpcScanner.scan_failed.connect(func(reason: String): status_label.text = "Scan failed: %s" % reason)
	_update_camera_ui()
	if OS.has_feature("android"):
		OS.request_permissions()


func _update_camera_ui() -> void:
	camera_hint.text = "Scan a UPC — the app identifies the beverage type (never brands)."
	status_label.text = "Tap Scan with Camera, or type a barcode then Identify."


func _populate_categories() -> void:
	category_option.clear()
	_categories.clear()
	category_option.add_item("— Select / confirm beverage type —")
	_categories.append(-1)
	var keys := FactionData.CATEGORY_LABELS.keys()
	keys.sort()
	for cat in keys:
		_categories.append(cat)
		var faction := FactionData.faction_for_category(cat)
		category_option.add_item("%s → %s" % [FactionData.category_label(cat), FactionData.faction_label(faction)])
	category_option.select(0)


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
		b.custom_minimum_size = Vector2(0, 48)
		b.add_theme_font_size_override("font_size", 16)
		var code: String = d.code
		var cat: int = d.cat
		b.pressed.connect(func():
			barcode_input.text = code
			_apply_identification(cat, true)
			_summon(code, cat)
		)
		demo_box.add_child(b)


func _on_category_chosen(index: int) -> void:
	if index <= 0 or index >= _categories.size():
		_identified_category = -1
		identified_label.text = "Item type: not identified yet"
		return
	_identified_category = int(_categories[index])
	identified_label.text = "Item type: %s → %s" % [
		FactionData.category_label(_identified_category),
		FactionData.faction_label(FactionData.faction_for_category(_identified_category)),
	]


func _select_category(cat: int) -> void:
	for i in _categories.size():
		if int(_categories[i]) == cat:
			category_option.select(i)
			_identified_category = cat
			return


func _apply_identification(cat: int, confident: bool) -> void:
	_select_category(cat)
	var faction := FactionData.faction_for_category(cat)
	identified_label.text = "Identified: %s → %s warrior" % [
		FactionData.category_label(cat),
		FactionData.faction_label(faction),
	]
	if confident:
		status_label.text = "Identified as %s. Summoning..." % FactionData.category_label(cat)
	else:
		status_label.text = "Type set to %s. Tap Summon Warrior." % FactionData.category_label(cat)


func _selected_category() -> int:
	if _identified_category >= 0:
		return _identified_category
	var idx := category_option.selected
	if idx <= 0 or idx >= _categories.size():
		return -1
	return int(_categories[idx])


func _on_camera_pressed() -> void:
	status_label.text = "Opening camera UPC scanner..."
	UpcScanner.start_camera_scan()


func _on_camera_barcode(code: String) -> void:
	var clean := code.strip_edges()
	barcode_input.text = clean
	_identified_category = -1
	category_option.select(0)
	identified_label.text = "Identifying scanned item..."
	status_label.text = "UPC captured. Identifying beverage type..."
	_auto_summon_after_lookup = true
	_pending_lookup(clean)


func _on_scan_pressed() -> void:
	var code := barcode_input.text.strip_edges()
	if code.is_empty():
		status_label.text = "Scan or enter a barcode first."
		return
	var cat := _selected_category()
	if cat < 0:
		# Identify first, then summon.
		_auto_summon_after_lookup = true
		_pending_lookup(code)
		return
	_summon(code, cat)


func _on_lookup_pressed() -> void:
	var code := barcode_input.text.strip_edges()
	if code.is_empty():
		status_label.text = "Enter or scan a barcode first."
		return
	_auto_summon_after_lookup = false
	_pending_lookup(code)


func _pending_lookup(code: String) -> void:
	if _lookup_pending:
		http.cancel_request()
	_lookup_pending = true
	_lookup_code = code
	status_label.text = "Looking up item type (brands never shown)..."
	var fields := "categories_tags,categories,generic_name,labels_tags,product_name,product_name_en,alcohol_100g,nutriments,ingredients_analysis_tags"
	var url := "https://world.openfoodfacts.org/api/v2/product/%s.json?fields=%s" % [code.uri_encode(), fields.uri_encode()]
	var err := http.request(url)
	if err != OK:
		_lookup_pending = false
		_auto_summon_after_lookup = false
		status_label.text = "Lookup failed to start. Select the beverage type manually, then Summon."


func _on_http_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_lookup_pending = false
	var code := _lookup_code
	var want_summon := _auto_summon_after_lookup
	_auto_summon_after_lookup = false

	if response_code != 200:
		status_label.text = "Product not found online. Select the beverage type, then Summon."
		return
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if typeof(parsed) != TYPE_DICTIONARY:
		status_label.text = "Lookup parse error. Select type manually."
		return
	if int(parsed.get("status", 0)) != 1:
		status_label.text = "Unknown barcode. Select the beverage type, then Summon."
		return
	var product: Dictionary = parsed.get("product", {})
	var info: Dictionary = WarriorFactory.classify_product_dict(product)
	var cat: int = int(info.get("category", -1))
	if cat < 0:
		status_label.text = "Could not classify this item. Select type manually, then Summon."
		identified_label.text = "Item type: unknown — please select"
		return
	_apply_identification(cat, true)
	if want_summon and not code.is_empty():
		_summon(code, cat)


func _summon(code: String, category: int) -> void:
	if category < 0:
		status_label.text = "Identify or select a beverage type first."
		return
	if GameState.has_warrior(code):
		var existing := GameState.get_warrior(code)
		_show_result(existing, true)
		status_label.text = "This barcode already summoned %s. Each barcode is unique." % existing.name
		return
	var warrior := WarriorFactory.generate(code, category)
	var result := GameState.unlock_warrior(warrior)
	if result.ok:
		_show_result(warrior, false)
		status_label.text = "Identified %s → summoned %s!" % [
			FactionData.category_label(category),
			warrior.name,
		]
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
	result_sprite.custom_minimum_size = Vector2(180, 220)
	# Keep sprite colors authentic — light bottle tint only
	result_sprite.modulate = Color(
		warrior.tint_primary.r * 0.2 + 0.8,
		warrior.tint_primary.g * 0.2 + 0.8,
		warrior.tint_primary.b * 0.2 + 0.8,
		1.0
	)
