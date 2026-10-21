extends Node
## Live game events: special dungeons + special barcodes for rare warriors.
## Public builds fetch remote JSON. Dev builds can author events and export JSON
## into events/live_events.json (commit + push to publish to all players).

signal events_updated
signal fetch_finished(ok: bool, message: String)

const BUNDLED_PATH := "res://events/live_events.json"
const CACHE_PATH := "user://events_cache.json"
const DRAFT_PATH := "user://events_draft.json"
## Players pull from the public repo raw file. Update branch/path if you move hosting.
const DEFAULT_REMOTE_URL := "https://raw.githubusercontent.com/rgarn023/LibationWarriors/cursor/libation-warriors-game-0762/events/live_events.json"

var remote_url: String = DEFAULT_REMOTE_URL
var catalog: Dictionary = {"version": 1, "updated_at": "", "events": []}
var last_fetch_message: String = ""
var _http: HTTPRequest
var _fetching := false


func _ready() -> void:
	_http = HTTPRequest.new()
	_http.timeout = 20.0
	add_child(_http)
	_http.request_completed.connect(_on_http_completed)
	_load_local_fallback()
	# Defer network fetch so boot stays snappy.
	call_deferred("refresh_events")


func _load_local_fallback() -> void:
	if FileAccess.file_exists(CACHE_PATH):
		if _load_from_path(CACHE_PATH):
			return
	_load_from_path(BUNDLED_PATH)


func _load_from_path(path: String) -> bool:
	if not FileAccess.file_exists(path) and not path.begins_with("res://"):
		return false
	if path.begins_with("res://") and not ResourceLoader.exists(path) and not FileAccess.file_exists(path):
		# res:// JSON may still open via FileAccess
		pass
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	catalog = parsed
	events_updated.emit()
	return true


func refresh_events() -> void:
	if _fetching:
		return
	_fetching = true
	last_fetch_message = "Fetching events..."
	var err := _http.request(remote_url)
	if err != OK:
		_fetching = false
		last_fetch_message = "Could not start event fetch."
		fetch_finished.emit(false, last_fetch_message)


func _on_http_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_fetching = false
	if response_code != 200:
		last_fetch_message = "Event server unreachable (%d). Using cached/bundled events." % response_code
		fetch_finished.emit(false, last_fetch_message)
		return
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if typeof(parsed) != TYPE_DICTIONARY:
		last_fetch_message = "Invalid events payload."
		fetch_finished.emit(false, last_fetch_message)
		return
	catalog = parsed
	_write_cache(catalog)
	last_fetch_message = "Events updated."
	events_updated.emit()
	fetch_finished.emit(true, last_fetch_message)


func _write_cache(data: Dictionary) -> void:
	var file := FileAccess.open(CACHE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))


func get_active_events() -> Array:
	var now := int(Time.get_unix_time_from_system())
	var out: Array = []
	for e in catalog.get("events", []):
		if typeof(e) != TYPE_DICTIONARY:
			continue
		if not bool(e.get("enabled", true)):
			continue
		var start_u := _parse_iso_unix(str(e.get("starts_at", "")))
		var end_u := _parse_iso_unix(str(e.get("ends_at", "")))
		if start_u > 0 and now < start_u:
			continue
		if end_u > 0 and now > end_u:
			continue
		out.append(e)
	return out


func _parse_iso_unix(iso: String) -> int:
	## Accepts YYYY-MM-DD or YYYY-MM-DDTHH:MM:SSZ (basic).
	var s := iso.strip_edges()
	if s.is_empty():
		return 0
	s = s.replace("Z", "")
	var date_part := s
	var time_part := "00:00:00"
	if "T" in s:
		var bits := s.split("T")
		date_part = bits[0]
		if bits.size() > 1 and bits[1].length() >= 8:
			time_part = bits[1].substr(0, 8)
	var d := date_part.split("-")
	if d.size() != 3:
		return 0
	var t := time_part.split(":")
	var dict := {
		"year": int(d[0]),
		"month": int(d[1]),
		"day": int(d[2]),
		"hour": int(t[0]) if t.size() > 0 else 0,
		"minute": int(t[1]) if t.size() > 1 else 0,
		"second": int(t[2]) if t.size() > 2 else 0,
	}
	return int(Time.get_unix_time_from_datetime_dict(dict))


func find_special_barcode(code: String) -> Dictionary:
	var key := code.strip_edges()
	for e in get_active_events():
		for b in e.get("special_barcodes", []):
			if typeof(b) != TYPE_DICTIONARY:
				continue
			if str(b.get("barcode", "")).strip_edges() == key:
				var copy: Dictionary = b.duplicate(true)
				copy["event_id"] = e.get("id", "")
				copy["event_title"] = e.get("title", "")
				return copy
	return {}


func get_active_special_dungeons() -> Array:
	var out: Array = []
	for e in get_active_events():
		var sd = e.get("special_dungeon", {})
		if typeof(sd) == TYPE_DICTIONARY and not sd.is_empty() and str(sd.get("name", "")) != "":
			var item: Dictionary = (sd as Dictionary).duplicate(true)
			item["event_id"] = e.get("id", "")
			item["event_title"] = e.get("title", "")
			out.append(item)
	return out


func active_banner_text() -> String:
	var active := get_active_events()
	if active.is_empty():
		return ""
	var titles: Array[String] = []
	for e in active:
		titles.append(str(e.get("title", "Event")))
	return "Live event: %s" % ", ".join(titles)


## --- Dev authoring ---

func load_draft() -> Dictionary:
	if FileAccess.file_exists(DRAFT_PATH):
		var file := FileAccess.open(DRAFT_PATH, FileAccess.READ)
		if file:
			var parsed = JSON.parse_string(file.get_as_text())
			if typeof(parsed) == TYPE_DICTIONARY:
				return parsed
	return catalog.duplicate(true)


func save_draft(data: Dictionary) -> void:
	data["updated_at"] = Time.get_datetime_string_from_system(true, true)
	var file := FileAccess.open(DRAFT_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))


func apply_draft_locally(data: Dictionary) -> void:
	## Dev-only: preview events on this device without publishing.
	catalog = data.duplicate(true)
	_write_cache(catalog)
	events_updated.emit()


func export_draft_json(data: Dictionary) -> String:
	data["updated_at"] = Time.get_datetime_string_from_system(true, true)
	var text := JSON.stringify(data, "\t")
	save_draft(data)
	# Also write a copy players' repo file should match.
	var export_copy := FileAccess.open("user://live_events_export.json", FileAccess.WRITE)
	if export_copy:
		export_copy.store_string(text)
	DisplayServer.clipboard_set(text)
	return text


func make_rare_warrior(spec: Dictionary) -> Warrior:
	var code := str(spec.get("barcode", "")).strip_edges()
	var cat := int(spec.get("category", FactionData.Category.OTHER_ALCOHOL))
	var colors: Dictionary = {}
	if spec.has("tint_primary"):
		colors = {
			"primary": _colorish(spec.get("tint_primary")),
			"secondary": _colorish(spec.get("tint_secondary", spec.get("tint_primary"))),
			"accent": _colorish(spec.get("tint_accent", spec.get("tint_primary"))),
			"label": str(spec.get("palette_name", "Event Relic")),
		}
	var w: Warrior = WarriorFactory.generate(code, cat, colors)
	if str(spec.get("name", "")) != "":
		w.name = str(spec.get("name"))
	w.bottle_palette_name = str(spec.get("palette_name", "Event Relic"))
	var rarity := str(spec.get("rarity", "rare")).to_lower()
	match rarity:
		"legendary":
			w.base_attack = int(w.base_attack * 1.35) + 6
			w.base_defense = int(w.base_defense * 1.3) + 4
			w.base_max_hp = int(w.base_max_hp * 1.4) + 20
			w.base_special_power = int(w.base_special_power * 1.35) + 6
		"rare":
			w.base_attack = int(w.base_attack * 1.15) + 3
			w.base_defense = int(w.base_defense * 1.12) + 2
			w.base_max_hp = int(w.base_max_hp * 1.18) + 10
			w.base_special_power = int(w.base_special_power * 1.15) + 3
		_:
			pass
	w._recompute_stats_from_level()
	w.current_hp = w.max_hp
	return w


func _colorish(value) -> Color:
	if value is Color:
		return value
	if value is Array and value.size() >= 3:
		var a := float(value[3]) if value.size() > 3 else 1.0
		return Color(float(value[0]), float(value[1]), float(value[2]), a)
	if value is String and str(value).begins_with("#"):
		return Color(str(value))
	return Color(0.85, 0.62, 0.22)
