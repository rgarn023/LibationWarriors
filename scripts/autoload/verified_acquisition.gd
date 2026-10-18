extends Node
## Wire this to a genuine Android device-integrity and live-camera adapter.
## No fake GPS, uploaded gallery images, or client-side verdicts are accepted.
## All methods require valid Supabase sign-in.

func _invoke(payload: Dictionary) -> Dictionary:
	if not SupabaseClient.is_signed_in():
		return {"ok": false, "message": "Sign in before registering or scanning."}
	if not SupabaseClient.is_configured():
		return {"ok": false, "message": "Supabase is not configured."}
	# Client auth JWT, never service_role.
	return await SupabaseClient.function_request("verified-acquisition", payload)


func register_fixed_location(latitude: float, longitude: float, accuracy_m: float, integrity_token: String) -> Dictionary:
	if integrity_token.is_empty():
		return {"ok": false, "message": "Native verified location evidence required."}
	return await _invoke({
		"operation": "register_location",
		"latitude": latitude, "longitude": longitude,
		"accuracy_m": accuracy_m, "location_integrity_token": integrity_token,
	})


func start_verification(barcode: String, latitude: float, longitude: float, accuracy_m: float, integrity_token: String) -> Dictionary:
	var normalized := BarcodeIdentity.canonicalize(barcode)
	if not BarcodeIdentity.is_supported_retail(normalized) or integrity_token.is_empty():
		return {"ok": false, "message": "Retail barcode and verified live location required."}
	return await _invoke({
		"operation": "begin_scan",
		"barcode": normalized,
		"latitude": latitude, "longitude": longitude,
		"accuracy_m": accuracy_m, "location_integrity_token": integrity_token,
	})


func submit_live_proof(challenge_id: String, photo_bytes: PackedByteArray, latitude: float, longitude: float, accuracy_m: float, integrity_token: String) -> Dictionary:
	if challenge_id.is_empty() or photo_bytes.size() < 1024 or integrity_token.is_empty():
		return {"ok": false, "message": "Live in-app camera photo, challenge and verified location required."}
	var result := await _invoke({
		"operation": "submit_proof",
		"challenge_id": challenge_id,
		"photo_base64": Marshalls.raw_to_base64(photo_bytes),
		"latitude": latitude, "longitude": longitude,
		"accuracy_m": accuracy_m, "location_integrity_token": integrity_token,
	})
	if not result.get("ok", false):
		return result
	# The server returns the first globally canonical blueprint. Never mint
	# using local product classification or the device RNG.
	var data: Variant = result.get("data", {})
	if typeof(data) != TYPE_DICTIONARY or not bool(data.get("ok", false)):
		return {"ok": false, "message": "Verified blueprint response missing."}
	var blueprint: Variant = data.get("warrior", {})
	if typeof(blueprint) != TYPE_DICTIONARY:
		return {"ok": false, "message": "Server did not return canonical warrior."}
	var warrior := Warrior.new(blueprint)
	warrior.barcode = str(data.get("barcode", ""))
	warrior.barcode_hash = BarcodeIdentity.sha256_hex(warrior.barcode)
	return GameState.unlock_warrior(warrior, true)
