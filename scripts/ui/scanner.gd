extends Control
## Camera-first scanner with canonical identity, idempotent acquisition, and callback debounce.

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
@onready var camera_hint: Label = %CameraHint

const CALLBACK_DEBOUNCE_MS := 1500

var _processing := false
var _last_scan_code := ""
var _last_scan_msec := 0


func _ready() -> void:
	SafeArea.register(safe_root)
	UITheme.style_button(btn_camera, true)
	UITheme.style_button(btn_back)
	UITheme.style_panel(result_panel)
	result_panel.visible = false
	identified_label.text = "Scan a real bottle UPC/EAN with the camera."
	btn_camera.pressed.connect(_on_camera_pressed)
	btn_back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
	UpcScanner.barcode_scanned.connect(_on_camera_barcode)
	UpcScanner.scan_cancelled.connect(func(): _finish_processing("Camera scan cancelled."))
	UpcScanner.scan_failed.connect(func(reason: String): _finish_processing("Scan failed: %s" % reason))
	ScanGuard.limits_changed.connect(_refresh_limits)
	_refresh_limits()
	_setup_dev_demos()
	_update_camera_ui()
	if OS.has_feature("android"):
		OS.request_permissions()


func _refresh_limits() -> void:
	limit_label.text = ScanGuard.status_text()


func _update_camera_ui() -> void:
	camera_hint.text = "Camera only — UPC/EAN. Unknown products are never assigned a random faction."
	if not UpcScanner.can_scan_camera() and not DevBuild.allow_dev_tools():
		status_label.text = "Camera scanning requires the Android build."
		btn_camera.disabled = true
	else:
		status_label.text = "Point the camera at a bottle barcode."
		btn_camera.disabled = false


func _setup_dev_demos() -> void:
	var show := DevBuild.allow_dev_tools()
	demo_header.visible = show
	demo_box.visible = show
	if not show:
		return
	demo_header.text = "DEV deterministic demos"
	for child in demo_box.get_children():
		child.queue_free()
	for d in [
		{"label": "Demo Rum", "code": "DEMO-RUM-88001", "cat": FactionData.Category.RUM},
		{"label": "Demo Beer", "code": "DEMO-BEER-88006", "cat": FactionData.Category.BEER},
	]:
		var b := Button.new()
		b.text = d.label
		b.custom_minimum_size = Vector2(0, 48)
		UITheme.style_button(b)
		var code: String = d.code
		var cat: int = d.cat
		b.pressed.connect(func(): _summon_verified(code, cat))
		demo_box.add_child(b)


func _on_camera_pressed() -> void:
	if _processing:
		return
	status_label.text = "Opening camera..."
	UpcScanner.start_camera_scan()


func _on_camera_barcode(raw_code: String) -> void:
	var code := BarcodeIdentity.canonicalize(raw_code)
	var now := Time.get_ticks_msec()
	if code.is_empty() or not BarcodeIdentity.is_supported_retail(code):
		_finish_processing("Unsupported or invalid retail barcode.")
		return
	if _processing:
		return
	if code == _last_scan_code and now - _last_scan_msec < CALLBACK_DEBOUNCE_MS:
		return
	_processing = true
	_last_scan_code = code
	_last_scan_msec = now
	btn_camera.disabled = true
	status_label.text = "Barcode captured. Resolving product type..."
	identified_label.text = "Identity %s" % BarcodeIdentity.short_id(code)

	if GameState.has_warrior(code):
		_show_result(GameState.get_warrior(code), true)
		_finish_processing("Warrior Already Discovered")
		return

	var gate := ScanGuard.can_attempt_summon(code)
	if not gate.get("ok", false):
		_finish_processing(str(gate.get("message", "Summon blocked.")))
		return

	var resolved := await ProductResolver.resolve(code)
	if not resolved.get("ok", false):
		_finish_processing(str(resolved.get("message", "Product could not be resolved.")))
		return
	var cat := int(resolved.get("category", -1))
	identified_label.text = "%s → %s" % [
		FactionData.category_label(cat),
		FactionData.faction_label(FactionData.faction_for_category(cat)),
	]
	_summon_verified(code, cat)


func _summon_verified(code: String, category: int) -> void:
	var canonical := BarcodeIdentity.canonicalize(code)
	if canonical.is_empty():
		_finish_processing("Invalid barcode identity.")
		return
	if GameState.has_warrior(canonical):
		_show_result(GameState.get_warrior(canonical), true)
		_finish_processing("Warrior Already Discovered")
		return
	var warrior := WarriorFactory.generate(canonical, category)
	var result := GameState.unlock_warrior(warrior, true)
	if result.get("ok", false):
		_show_result(warrior, false)
		_finish_processing("Discovered %s!" % warrior.name)
		return
	var existing: Variant = result.get("warrior", null)
	if existing is Warrior:
		_show_result(existing, true)
	_finish_processing("Warrior Already Discovered")


func _finish_processing(message: String) -> void:
	_processing = false
	btn_camera.disabled = not UpcScanner.can_scan_camera() and not DevBuild.allow_dev_tools()
	status_label.text = message
	_refresh_limits()


func _show_result(warrior: Warrior, duplicate: bool) -> void:
	result_panel.visible = true
	result_name.text = "Lv.%d  %s" % [warrior.level, warrior.name]
	result_faction.text = "%s · %s · ID %s" % [
		warrior.faction_display(),
		warrior.category_display(),
		warrior.barcode_hash.substr(0, 10).to_upper(),
	]
	result_stats.text = "ATK %d  DEF %d  HP %d\n%s\n%s (%d) / %s (%d)%s" % [
		warrior.attack, warrior.defense, warrior.max_hp,
		warrior.appearance_signature if not warrior.appearance_signature.is_empty() else warrior.variant_label(),
		warrior.regular_move, warrior.regular_power,
		warrior.special_move, warrior.special_power,
		"\n(Already discovered)" if duplicate else "",
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
