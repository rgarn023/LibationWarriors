extends Control
## Camera-only bottle scanner. Manual barcode entry removed.
## Requires live product lookup (or an active event barcode) + ScanGuard limits.

@onready var safe_root: Control = %SafeRoot
@onready var status_label: Label = %StatusLabel
@onready var identified_label: Label = %IdentifiedLabel
@onready var result_panel: PanelContainer = %ResultPanel
@onready var result_name: Label = %ResultName
@onready var result_faction: Label = %ResultFaction
@onready var result_stats: Label = %ResultStats
@onready var result_sprite: TextureRect = %ResultSprite
@onready var btn_camera: Button = %BtnCamera
@onready var btn_back: Button = %BtnBack
@onready var demo_box: VBoxContainer = %DemoBox
@onready var demo_header: Label = %DemoHeader
@onready var limit_label: Label = %LimitLabel
@onready var http: HTTPRequest = %HTTPRequest
@onready var camera_hint: Label = %CameraHint

var _lookup_pending := false
var _lookup_code := ""
var _packaging_colors: Dictionary = {}
var _http_mode := "" ## product | image
var _pending_category: int = -1
var _image_http: HTTPRequest
var _camera_origin := false


func _ready() -> void:
	SafeArea.register(safe_root)
	UITheme.style_button(btn_camera, true)
	UITheme.style_button(btn_back)
	UITheme.style_panel(result_panel)
	result_panel.visible = false
	identified_label.text = "Scan a real bottle UPC with the camera."
	btn_camera.pressed.connect(_on_camera_pressed)
	btn_back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
	http.request_completed.connect(_on_http_completed)
	_image_http = HTTPRequest.new()
	_image_http.name = "ImageHTTP"
	add_child(_image_http)
	_image_http.request_completed.connect(_on_image_http_completed)
	UpcScanner.barcode_scanned.connect(_on_camera_barcode)
	UpcScanner.scan_cancelled.connect(func(): status_label.text = "Camera scan cancelled.")
	UpcScanner.scan_failed.connect(func(reason: String): status_label.text = "Scan failed: %s" % reason)
	ScanGuard.limits_changed.connect(_refresh_limits)
	_refresh_limits()
	_setup_dev_demos()
	_update_camera_ui()
	if OS.has_feature("android"):
		OS.request_permissions()


func _refresh_limits() -> void:
	limit_label.text = ScanGuard.status_text()


func _update_camera_ui() -> void:
	camera_hint.text = "Camera only — no typing barcodes. Product must verify online (brands never shown). Event codes work during live events."
	if not UpcScanner.can_scan_camera() and not DevBuild.allow_dev_tools():
		status_label.text = "Camera scanning requires the Android build."
		btn_camera.disabled = true
	else:
		status_label.text = "Point the camera at a bottle barcode on the packaging."
		btn_camera.disabled = false


func _setup_dev_demos() -> void:
	var show_demos := DevBuild.allow_dev_tools()
	demo_header.visible = show_demos
	demo_box.visible = show_demos
	if not show_demos:
		return
	demo_header.text = "DEV demos (not in public build)"
	for c in demo_box.get_children():
		c.queue_free()
	var demos := [
		{"label": "Demo Rum", "code": "DEMO-RUM-88001", "cat": FactionData.Category.RUM},
		{"label": "Demo Beer", "code": "DEMO-BEER-88006", "cat": FactionData.Category.BEER},
		{"label": "Demo Soft Drink", "code": "DEMO-SODA-88010", "cat": FactionData.Category.NON_ALCOHOLIC},
		{"label": "Event Moonwell (if live)", "code": "EVENT-MOONWELL-001", "cat": -1},
	]
	for d in demos:
		var b := Button.new()
		b.text = d.label
		UITheme.style_button(b)
		b.custom_minimum_size = Vector2(0, 48)
		b.add_theme_font_size_override("font_size", 16)
		var code: String = d.code
		var cat: int = d.cat
		b.pressed.connect(func(): _dev_demo_summon(code, cat))
		demo_box.add_child(b)


func _dev_demo_summon(code: String, cat: int) -> void:
	if not DevBuild.allow_dev_tools():
		return
	_camera_origin = true
	var spec := EventService.find_special_barcode(code)
	if not spec.is_empty():
		_summon_event(spec)
		return
	if cat < 0:
		status_label.text = "Event barcode not active right now."
		return
	_packaging_colors = {}
	_summon_verified(code, cat, false)


func _on_camera_pressed() -> void:
	status_label.text = "Opening camera UPC scanner..."
	UpcScanner.start_camera_scan()


func _on_camera_barcode(code: String) -> void:
	var clean := code.strip_edges()
	_camera_origin = true
	_packaging_colors = {}
	identified_label.text = "Checking scan..."
	status_label.text = "UPC captured. Verifying..."
	if not ScanGuard.is_plausible_product_barcode(clean):
		status_label.text = "That code doesn't look like a retail bottle barcode."
		return
	var gate := ScanGuard.can_attempt_summon(clean)
	if not gate.get("ok", false):
		status_label.text = str(gate.get("message", "Summon blocked."))
		if gate.get("duplicate", false):
			pass
		else:
			return
	if GameState.has_warrior(clean):
		var existing := GameState.get_warrior(clean)
		_show_result(existing, true)
		status_label.text = "Already collected: %s" % existing.name
		return
	# Event special barcode path (no OFF required).
	var spec := EventService.find_special_barcode(clean)
	if not spec.is_empty():
		_summon_event(spec)
		return
	_pending_lookup(clean)


func _pending_lookup(code: String) -> void:
	if _lookup_pending:
		http.cancel_request()
	_lookup_pending = true
	_lookup_code = code
	_http_mode = "product"
	_packaging_colors = {}
	status_label.text = "Verifying bottle against product database..."
	var fields := "categories_tags,categories,generic_name,labels_tags,product_name,product_name_en,alcohol_100g,nutriments,ingredients_analysis_tags,image_front_url,image_url,image_front_small_url"
	var url := "https://world.openfoodfacts.org/api/v2/product/%s.json?fields=%s" % [code.uri_encode(), fields.uri_encode()]
	var err := http.request(url)
	if err != OK:
		_lookup_pending = false
		_http_mode = ""
		status_label.text = "Verification failed to start. Check connection and retry."


func _on_http_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if _http_mode != "product":
		return
	_lookup_pending = false
	_http_mode = ""
	var code := _lookup_code

	if response_code != 200:
		status_label.text = "Could not verify this barcode online. Only real listed bottles can summon."
		return
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if typeof(parsed) != TYPE_DICTIONARY:
		status_label.text = "Verification parse error."
		return
	if int(parsed.get("status", 0)) != 1:
		status_label.text = "Unknown barcode — not a listed product. Printed/fake codes are rejected."
		return
	var product: Dictionary = parsed.get("product", {})
	var info: Dictionary = WarriorFactory.classify_product_dict(product)
	var cat: int = int(info.get("category", -1))
	if cat < 0:
		status_label.text = "Listed product, but not identified as a beverage. Try another bottle."
		identified_label.text = "Item type: not a supported beverage"
		return
	_pending_category = cat
	identified_label.text = "Verified: %s → %s" % [
		FactionData.category_label(cat),
		FactionData.faction_label(FactionData.faction_for_category(cat)),
	]
	var image_url := _pick_image_url(product)
	if image_url.is_empty():
		_summon_verified(code, cat, true)
		return
	status_label.text = "Sampling packaging colors..."
	_http_mode = "image"
	_lookup_pending = true
	var err := _image_http.request(image_url)
	if err != OK:
		_lookup_pending = false
		_http_mode = ""
		_summon_verified(code, cat, true)


func _pick_image_url(product: Dictionary) -> String:
	for key in ["image_front_small_url", "image_front_url", "image_url"]:
		var u := str(product.get(key, "")).strip_edges()
		if u.begins_with("http"):
			return u
	return ""


func _on_image_http_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_lookup_pending = false
	_http_mode = ""
	var code := _lookup_code
	var cat := _pending_category
	if response_code == 200 and body.size() > 32:
		var img := Image.new()
		var err := img.load_jpg_from_buffer(body)
		if err != OK:
			err = img.load_png_from_buffer(body)
		if err != OK:
			err = img.load_webp_from_buffer(body)
		if err == OK:
			_packaging_colors = WarriorFactory.colors_from_image(img)
	if cat >= 0 and not code.is_empty():
		_summon_verified(code, cat, true)


func _summon_event(spec: Dictionary) -> void:
	var code := str(spec.get("barcode", "")).strip_edges()
	var gate := ScanGuard.can_attempt_summon(code)
	if not gate.get("ok", false) and not gate.get("duplicate", false):
		status_label.text = str(gate.get("message", "Summon blocked."))
		return
	if GameState.has_warrior(code):
		_show_result(GameState.get_warrior(code), true)
		status_label.text = "Event warrior already collected."
		return
	if not _camera_origin and not DevBuild.allow_dev_tools():
		status_label.text = "Camera scan required."
		return
	var warrior := EventService.make_rare_warrior(spec)
	var result := GameState.unlock_warrior(warrior, true)
	if result.ok:
		_show_result(warrior, false)
		status_label.text = "Event unlock: %s (%s)!" % [warrior.name, str(spec.get("event_title", "Event"))]
		identified_label.text = "Event rarity: %s" % str(spec.get("rarity", "rare"))
	else:
		status_label.text = "Could not unlock event warrior."
	_refresh_limits()


func _summon_verified(code: String, category: int, require_camera: bool) -> void:
	if require_camera and not _camera_origin and not DevBuild.allow_dev_tools():
		status_label.text = "Camera scan required."
		return
	var gate := ScanGuard.can_attempt_summon(code)
	if not gate.get("ok", false) and not gate.get("duplicate", false):
		status_label.text = str(gate.get("message", "Summon blocked."))
		return
	if GameState.has_warrior(code):
		_show_result(GameState.get_warrior(code), true)
		status_label.text = "Already collected."
		return
	var warrior := WarriorFactory.generate(code, category, _packaging_colors)
	var result := GameState.unlock_warrior(warrior, true)
	if result.ok:
		_show_result(warrior, false)
		status_label.text = "Verified bottle → summoned %s!" % warrior.name
	else:
		status_label.text = "Could not unlock warrior."
	_refresh_limits()


func _show_result(warrior: Warrior, duplicate: bool) -> void:
	result_panel.visible = true
	result_name.text = "Lv.%d  %s" % [warrior.level, warrior.name]
	result_faction.text = "%s  ·  %s  ·  %s" % [
		warrior.faction_display(),
		warrior.category_display(),
		warrior.bottle_palette_name,
	]
	result_stats.text = "ATK %d  DEF %d  HP %d\n%s\n%s (%d) / %s (%d)%s" % [
		warrior.attack, warrior.defense, warrior.max_hp,
		warrior.variant_label(),
		warrior.regular_move, warrior.regular_power,
		warrior.special_move, warrior.special_power,
		"\n(Already collected)" if duplicate else "",
	]
	WarriorPortrait.apply_to_texture_rect(result_sprite, warrior)
	result_sprite.custom_minimum_size = Vector2(180, 220)
	result_sprite.visible = true
	var parent := result_sprite.get_parent()
	if parent != null:
		var old := parent.get_node_or_null("ResultPortrait")
		if old:
			old.queue_free()
		var portrait := WarriorPortrait.make_portrait(warrior, Vector2(160, 200))
		portrait.name = "ResultPortrait"
		parent.add_child(portrait)
		parent.move_child(portrait, result_sprite.get_index())
		result_sprite.visible = false
