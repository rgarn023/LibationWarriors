extends Node
## Anti-cheat for warrior summons: camera-only path, product DB verify, rate limits.
## Printed random barcodes fail OFF lookup. Printed real UPCs are throttled.
## Perfect prevention of printed real UPCs needs server attestation; this raises the bar.

signal limits_changed

const DAILY_NEW_SUMMON_LIMIT := 8
const SUMMON_COOLDOWN_SEC := 40
const MIN_BARCODE_DIGITS := 8

var day_key: String = ""
var summons_today: int = 0
var last_summon_unix: int = 0
var summoned_today: Array = [] ## barcodes unlocked today


func _ready() -> void:
	_roll_day_if_needed()


func to_save_dict() -> Dictionary:
	return {
		"day_key": day_key,
		"summons_today": summons_today,
		"last_summon_unix": last_summon_unix,
		"summoned_today": summoned_today,
	}


func from_save_dict(data: Dictionary) -> void:
	day_key = str(data.get("day_key", ""))
	summons_today = int(data.get("summons_today", 0))
	last_summon_unix = int(data.get("last_summon_unix", 0))
	summoned_today = data.get("summoned_today", [])
	_roll_day_if_needed()


func _today_key() -> String:
	var t := Time.get_datetime_dict_from_system(true)
	return "%04d-%02d-%02d" % [int(t.year), int(t.month), int(t.day)]


func _roll_day_if_needed() -> void:
	var today := _today_key()
	if day_key != today:
		day_key = today
		summons_today = 0
		summoned_today = []
		limits_changed.emit()


func can_attempt_summon(barcode: String = "") -> Dictionary:
	_roll_day_if_needed()
	var code := barcode.strip_edges()
	if not code.is_empty() and GameState.has_warrior(code):
		return {"ok": true, "duplicate": true}
	# Dev/editor builds are unrestricted for testing.
	if DevBuild.allow_dev_tools():
		return {"ok": true, "remaining": 999, "dev": true}
	var now := int(Time.get_unix_time_from_system())
	var wait := SUMMON_COOLDOWN_SEC - (now - last_summon_unix)
	if last_summon_unix > 0 and wait > 0:
		return {"ok": false, "reason": "cooldown", "wait": wait, "message": "Wait %ds before another new summon." % wait}
	if summons_today >= DAILY_NEW_SUMMON_LIMIT:
		return {
			"ok": false,
			"reason": "daily_limit",
			"message": "Daily summon limit reached (%d). Try again tomorrow." % DAILY_NEW_SUMMON_LIMIT,
		}
	return {"ok": true, "remaining": DAILY_NEW_SUMMON_LIMIT - summons_today}


func record_successful_summon(barcode: String) -> void:
	_roll_day_if_needed()
	var code := barcode.strip_edges()
	summons_today += 1
	last_summon_unix = int(Time.get_unix_time_from_system())
	if not summoned_today.has(code):
		summoned_today.append(code)
	limits_changed.emit()
	SaveSystem.save_game()


func is_plausible_product_barcode(code: String) -> bool:
	## Reject obvious junk / short tokens. Real retail barcodes are numeric-ish and long.
	var c := code.strip_edges()
	if c.is_empty() or c.length() < MIN_BARCODE_DIGITS:
		return false
	# Event barcodes may be alphanumeric (EVENT-...).
	if c.begins_with("EVENT-") or c.begins_with("LW-"):
		return true
	# Demo codes only valid in dev tools.
	if c.begins_with("DEMO-"):
		return DevBuild.allow_dev_tools()
	# Prefer mostly digits (UPC/EAN).
	var digits := 0
	for i in c.length():
		var ch := c.unicode_at(i)
		if ch >= 48 and ch <= 57:
			digits += 1
	return float(digits) / float(c.length()) >= 0.85


func status_text() -> String:
	_roll_day_if_needed()
	var left := maxi(0, DAILY_NEW_SUMMON_LIMIT - summons_today)
	return "New summons left today: %d / %d" % [left, DAILY_NEW_SUMMON_LIMIT]
