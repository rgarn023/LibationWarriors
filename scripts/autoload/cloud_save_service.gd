extends Node
## Relational cloud persistence. Local JSON remains the offline cache.
## Blueprints are global/immutable by barcode hash; user_warriors stores progression.

signal sync_finished(ok: bool, message: String)

var _syncing := false


func initial_sync() -> Dictionary:
	if _syncing:
		return {"ok": false, "message": "Cloud sync already running."}
	if not SupabaseClient.is_signed_in():
		return {"ok": false, "message": "Not signed in."}
	_syncing = true
	var pull_result := await _pull_cloud_state()
	if not pull_result.get("ok", false):
		_syncing = false
		sync_finished.emit(false, str(pull_result.get("message", "Cloud load failed.")))
		return pull_result

	for warrior in GameState.get_all_warriors():
		var pushed := await sync_warrior(warrior)
		if not pushed.get("ok", false):
			_syncing = false
			sync_finished.emit(false, str(pushed.get("message", "Warrior sync failed.")))
			return pushed

	var profile_result := await sync_profile()
	_syncing = false
	var ok := bool(profile_result.get("ok", false))
	sync_finished.emit(ok, str(profile_result.get("message", "Cloud save synced.")))
	return {"ok": ok, "message": "Cloud save synced." if ok else str(profile_result.get("message", "Profile sync failed."))}


func queue_warrior_sync(warrior: Warrior) -> void:
	if not SupabaseClient.is_signed_in() or _syncing:
		return
	call_deferred("_deferred_warrior_sync", warrior.to_dict())


func _deferred_warrior_sync(data: Dictionary) -> void:
	await sync_warrior(Warrior.new(data))


func queue_profile_sync() -> void:
	if not SupabaseClient.is_signed_in() or _syncing:
		return
	call_deferred("_deferred_profile_sync")


func _deferred_profile_sync() -> void:
	await sync_profile()


func sync_warrior(warrior: Warrior) -> Dictionary:
	if warrior == null or not SupabaseClient.is_signed_in():
		return {"ok": false, "message": "No signed-in warrior sync context."}
	var canonical := BarcodeIdentity.canonicalize(warrior.barcode)
	if canonical.is_empty():
		return {"ok": false, "message": "Warrior barcode is not canonical."}
	var hash := warrior.barcode_hash
	if hash.is_empty():
		hash = BarcodeIdentity.sha256_hex(canonical)
		warrior.barcode_hash = hash

	var base_payload := warrior.to_blueprint_dict()
	var blueprint_insert := {
		"barcode_hash": hash,
		"normalized_barcode": canonical,
		"faction": warrior.faction,
		"category": warrior.category,
		"seed_value": warrior.seed_value,
		"base_data": base_payload,
	}
	var insert_result := await SupabaseClient.rest_request(
		HTTPClient.METHOD_POST,
		"warrior_blueprints?on_conflict=barcode_hash&select=id,barcode_hash",
		[blueprint_insert],
		"resolution=ignore-duplicates,return=representation"
	)
	if not insert_result.get("ok", false):
		return insert_result

	var lookup := await SupabaseClient.rest_request(
		HTTPClient.METHOD_GET,
		"warrior_blueprints?select=id,barcode_hash,base_data&barcode_hash=eq.%s&limit=1" % hash
	)
	if not lookup.get("ok", false):
		return lookup
	var rows: Variant = lookup.get("data", [])
	if typeof(rows) != TYPE_ARRAY or rows.is_empty():
		return {"ok": false, "message": "Blueprint could not be resolved after acquisition."}
	var resolved_blueprint: Dictionary = rows[0]
	var blueprint_id := str(resolved_blueprint.get("id", ""))
	if blueprint_id.is_empty():
		return {"ok": false, "message": "Blueprint ID missing."}

	# If another user claimed this barcode first, their immutable global blueprint wins.
	var canonical_base: Variant = resolved_blueprint.get("base_data", {})
	if typeof(canonical_base) == TYPE_DICTIONARY and not canonical_base.is_empty():
		var canonical_warrior := Warrior.new(canonical_base)
		canonical_warrior.barcode = canonical
		canonical_warrior.barcode_hash = hash
		canonical_warrior.level = warrior.level
		canonical_warrior.xp = warrior.xp
		canonical_warrior.equipment = warrior.equipment.duplicate(true)
		canonical_warrior.regular_attack_override = warrior.regular_attack_override.duplicate(true)
		canonical_warrior.special_attack_override = warrior.special_attack_override.duplicate(true)
		canonical_warrior.progression = warrior.progression.duplicate(true)
		canonical_warrior._recompute_stats_from_level()
		canonical_warrior.reset_hp()
		GameState.merge_cloud_warrior(canonical_warrior)

	var owned := {
		"user_id": SupabaseClient.user_id(),
		"blueprint_id": blueprint_id,
		"barcode_value": canonical,
		"level": warrior.level,
		"xp": warrior.xp,
		"equipment": warrior.equipment,
		"regular_attack_override": warrior.regular_attack_override,
		"special_attack_override": warrior.special_attack_override,
		"progression": warrior.progression,
		"updated_at": Time.get_datetime_string_from_system(true),
	}
	return await SupabaseClient.rest_request(
		HTTPClient.METHOD_POST,
		"user_warriors?on_conflict=user_id,blueprint_id",
		[owned],
		"resolution=merge-duplicates,return=minimal"
	)


func sync_profile() -> Dictionary:
	if not SupabaseClient.is_signed_in():
		return {"ok": false, "message": "Not signed in."}
	var profile := {
		"user_id": SupabaseClient.user_id(),
		"player_level": 1,
		"player_xp": 0,
		"party_barcode_hashes": GameState.party_barcode_hashes(),
		"settings": {},
		"updated_at": Time.get_datetime_string_from_system(true),
	}
	return await SupabaseClient.rest_request(
		HTTPClient.METHOD_POST,
		"profiles?on_conflict=user_id",
		[profile],
		"resolution=merge-duplicates,return=minimal"
	)


func _pull_cloud_state() -> Dictionary:
	var uid := SupabaseClient.user_id()
	var owned := await SupabaseClient.rest_request(
		HTTPClient.METHOD_GET,
		"user_warriors?select=barcode_value,level,xp,equipment,regular_attack_override,special_attack_override,progression,warrior_blueprints(id,barcode_hash,base_data)&user_id=eq.%s" % uid
	)
	if not owned.get("ok", false):
		return owned
	var rows: Variant = owned.get("data", [])
	if typeof(rows) == TYPE_ARRAY:
		for row in rows:
			if typeof(row) != TYPE_DICTIONARY:
				continue
			var bp: Variant = row.get("warrior_blueprints", {})
			if typeof(bp) != TYPE_DICTIONARY:
				continue
			var base: Variant = bp.get("base_data", {})
			if typeof(base) != TYPE_DICTIONARY:
				continue
			var w := Warrior.new(base)
			w.barcode = str(row.get("barcode_value", ""))
			w.barcode_hash = str(bp.get("barcode_hash", ""))
			w.level = maxi(1, int(row.get("level", 1)))
			w.xp = maxi(0, int(row.get("xp", 0)))
			w.equipment = _dict_or_empty(row.get("equipment", {}))
			w.regular_attack_override = _dict_or_empty(row.get("regular_attack_override", {}))
			w.special_attack_override = _dict_or_empty(row.get("special_attack_override", {}))
			w.progression = _dict_or_empty(row.get("progression", {}))
			w._recompute_stats_from_level()
			w.reset_hp()
			GameState.merge_cloud_warrior(w)

	var profile := await SupabaseClient.rest_request(
		HTTPClient.METHOD_GET,
		"profiles?select=party_barcode_hashes&user_id=eq.%s&limit=1" % uid
	)
	if profile.get("ok", false):
		var prows: Variant = profile.get("data", [])
		if typeof(prows) == TYPE_ARRAY and not prows.is_empty():
			GameState.apply_cloud_party_hashes(prows[0].get("party_barcode_hashes", []))
	SaveSystem.save_game()
	return {"ok": true, "message": "Cloud state loaded."}


func _dict_or_empty(value: Variant) -> Dictionary:
	return value if typeof(value) == TYPE_DICTIONARY else {}
