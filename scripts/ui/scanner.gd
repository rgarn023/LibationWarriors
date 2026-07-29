extends Control
## Bottle UPC scanner: camera scan on Android + manual entry. Brands never stored.

@onready var safe_root: Control = %SafeRoot
@onready var barcode_input: LineEdit = %BarcodeInput
@onready var category_option: OptionButton = %CategoryOption
@onready var status_label: Label = %StatusLabel
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


func _ready() -> void:
	SafeArea.register(safe_root)
	UITheme.style_button(btn_camera, true)
	UITheme.style_button(btn_scan, true)
	UITheme.style_button(btn_lookup)
	UITheme.style_button(btn_back)
	UITheme.style_panel(result_panel)
	result_panel.visible = false
	_populate_categories()
	_populate_demos()
	btn_camera.pressed.connect(_on_camera_pressed)
	btn_scan.pressed.connect(_on_scan_pressed)
	btn_lookup.pressed.connect(_on_lookup_pressed)
	btn_back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
	http.request_completed.connect(_on_http_completed)
	UpcScanner.barcode_scanned.connect(_on_camera_barcode)
	UpcScanner.scan_cancelled.connect(func(): status_label.text = "Camera scan cancelled.")
	UpcScanner.scan_failed.connect(func(reason: String): status_label.text = "Scan failed: %s" % reason)
	_update_camera_ui()
	if OS.has_feature("android"):
		OS.request_permissions()


func _update_camera_ui() -> void:
	if UpcScanner.can_scan_camera():
		btn_camera.disabled = false
		camera_hint.text = "Point your camera at the bottle UPC. Brands are never saved."
		status_label.text = "Tap Scan with Camera, or type a barcode."
	else:
		btn_camera.disabled = false  # still attempt; shows clear error if missing
		camera_hint.text = "On Android APK builds, Scan with Camera opens the UPC scanner. Desktop uses manual entry / demos."
		status_label.text = "Enter a barcode or use a demo bottle. Brands are never stored."


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
		b.custom_minimum_size = Vector2(0, 48)
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


func _on_camera_pressed() -> void:
	status_label.text = "Opening camera UPC scanner..."
	UpcScanner.start_camera_scan()


func _on_camera_barcode(code: String) -> void:
	var clean := code.strip_edges()
	barcode_input.text = clean
	status_label.text = "UPC captured. Confirm beverage type, then Summon Warrior."
	# Best-effort category hint without showing brands.
	_pending_lookup(clean)


func _on_scan_pressed() -> void:
	var code := barcode_input.text.strip_edges()
	if code.is_empty():
		status_label.text = "Scan or enter a barcode first."
		return
	_summon(code, _selected_category())


func _on_lookup_pressed() -> void:
	var code := barcode_input.text.strip_edges()
	if code.is_empty():
		status_label.text = "Enter or scan a barcode first."
		return
	_pending_lookup(code)


func _pending_lookup(code: String) -> void:
	status_label.text = "Looking up beverage category (brands hidden)..."
	var url := "https://world.openfoodfacts.org/api/v2/product/%s.json?fields=categories_tags,categories,generic_name,labels_tags" % code.uri_encode()
	var err := http.request(url)
	if err != OK:
		status_label.text = "Lookup failed to start. Pick a category manually, then Summon."


func _on_http_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code != 200:
		status_label.text = "No category hint found. Choose the beverage type, then Summon."
		return
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if typeof(parsed) != TYPE_DICTIONARY:
		status_label.text = "Lookup parse error. Choose category manually."
		return
	var product: Dictionary = parsed.get("product", {})
	var blob := ""
	blob += str(product.get("categories", "")) + " "
	for t in product.get("categories_tags", []):
		blob += str(t) + " "
	blob += str(product.get("generic_name", "")) + " "
	for t in product.get("labels_tags", []):
		blob += str(t) + " "
	var cat := WarriorFactory.classify_from_keywords(blob)
	if cat < 0:
		status_label.text = "Could not classify beverage. Select type, then Summon."
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
	result_sprite.custom_minimum_size = Vector2(144, 192)
	result_sprite.modulate = Color(
		warrior.tint_primary.r * 0.35 + 0.65,
		warrior.tint_primary.g * 0.35 + 0.65,
		warrior.tint_primary.b * 0.35 + 0.65,
		1.0
	)
