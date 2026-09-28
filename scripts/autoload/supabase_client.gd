extends Node
## Minimal Supabase Auth + REST client for Godot.
## Only SUPABASE_PUBLISHABLE_KEY (or legacy anon key) belongs in a client build.
## Never place a service_role/secret key in this project.

signal auth_state_changed(signed_in: bool)
signal session_changed

const SESSION_PATH := "user://libation_warriors_supabase_session.json"
const PROJECT_CONFIG := "res://config/supabase.public.json"
const USER_CONFIG := "user://supabase.public.json"

var base_url: String = ""
var publishable_key: String = ""
var session: Dictionary = {}


func _ready() -> void:
	_load_config()
	_load_session_from_disk()


func _load_config() -> void:
	base_url = OS.get_environment("SUPABASE_URL").strip_edges().trim_suffix("/")
	publishable_key = OS.get_environment("SUPABASE_PUBLISHABLE_KEY").strip_edges()
	if base_url != "" and publishable_key != "":
		return
	for path in [USER_CONFIG, PROJECT_CONFIG]:
		if not FileAccess.file_exists(path):
			continue
		var f := FileAccess.open(path, FileAccess.READ)
		if f == null:
			continue
		var parsed = JSON.parse_string(f.get_as_text())
		if typeof(parsed) != TYPE_DICTIONARY:
			continue
		if base_url.is_empty():
			base_url = str(parsed.get("url", "")).strip_edges().trim_suffix("/")
		if publishable_key.is_empty():
			publishable_key = str(parsed.get("publishable_key", parsed.get("anon_key", ""))).strip_edges()
		if base_url != "" and publishable_key != "":
			return


func is_configured() -> bool:
	return base_url.begins_with("https://") and not publishable_key.is_empty()


func is_signed_in() -> bool:
	return not str(session.get("access_token", "")).is_empty() and not user_id().is_empty()


func user_id() -> String:
	var user: Variant = session.get("user", {})
	if typeof(user) == TYPE_DICTIONARY:
		return str(user.get("id", ""))
	return ""


func sign_up(email: String, password: String) -> Dictionary:
	var result := await _request(
		HTTPClient.METHOD_POST,
		"/auth/v1/signup",
		{"email": email.strip_edges(), "password": password},
		false
	)
	if result.get("ok", false):
		_adopt_auth_response(result.get("data", {}))
		result["needs_confirmation"] = not is_signed_in()
	return result


func sign_in(email: String, password: String) -> Dictionary:
	var result := await _request(
		HTTPClient.METHOD_POST,
		"/auth/v1/token?grant_type=password",
		{"email": email.strip_edges(), "password": password},
		false
	)
	if result.get("ok", false):
		_adopt_auth_response(result.get("data", {}))
	return result


func restore_session() -> bool:
	if not is_configured():
		return false
	_load_session_from_disk()
	var refresh := str(session.get("refresh_token", ""))
	if refresh.is_empty():
		_clear_session()
		return false
	var result := await _request(
		HTTPClient.METHOD_POST,
		"/auth/v1/token?grant_type=refresh_token",
		{"refresh_token": refresh},
		false
	)
	if not result.get("ok", false):
		_clear_session()
		return false
	_adopt_auth_response(result.get("data", {}))
	return is_signed_in()


func send_password_reset(email: String) -> Dictionary:
	return await _request(
		HTTPClient.METHOD_POST,
		"/auth/v1/recover",
		{"email": email.strip_edges()},
		false
	)


func sign_out() -> void:
	if is_configured() and is_signed_in():
		await _request(HTTPClient.METHOD_POST, "/auth/v1/logout", {}, true)
	_clear_session()


func rest_request(method: int, endpoint: String, body: Variant = null, prefer: String = "") -> Dictionary:
	return await _request(method, "/rest/v1/" + endpoint.trim_prefix("/"), body, true, prefer)


func _request(
	method: int,
	path: String,
	body: Variant = null,
	use_access_token: bool = false,
	prefer: String = ""
) -> Dictionary:
	if not is_configured():
		return {"ok": false, "status": 0, "message": "Supabase is not configured."}
	var http := HTTPRequest.new()
	add_child(http)
	var headers := PackedStringArray([
		"apikey: %s" % publishable_key,
		"Content-Type: application/json",
		"Accept: application/json",
	])
	if use_access_token:
		var token := str(session.get("access_token", ""))
		if token.is_empty():
			http.queue_free()
			return {"ok": false, "status": 401, "message": "No authenticated Supabase session."}
		headers.append("Authorization: Bearer %s" % token)
	if not prefer.is_empty():
		headers.append("Prefer: %s" % prefer)

	var payload := ""
	if body != null:
		payload = JSON.stringify(body)
	var err := http.request(base_url + path, headers, method, payload)
	if err != OK:
		http.queue_free()
		return {"ok": false, "status": 0, "message": "Network request could not start (%s)." % error_string(err)}

	var response: Array = await http.request_completed
	http.queue_free()
	var transport_result := int(response[0])
	var status := int(response[1])
	var bytes: PackedByteArray = response[3]
	var text := bytes.get_string_from_utf8()
	var data: Variant = {}
	if not text.is_empty():
		var parsed = JSON.parse_string(text)
		data = parsed if parsed != null else {"raw": text}
	var ok := transport_result == HTTPRequest.RESULT_SUCCESS and status >= 200 and status < 300
	var message := ""
	if not ok:
		if typeof(data) == TYPE_DICTIONARY:
			message = str(data.get("msg", data.get("message", data.get("error_description", data.get("error", "Request failed.")))))
		else:
			message = "Request failed."
	return {"ok": ok, "status": status, "data": data, "message": message}


func _adopt_auth_response(data: Variant) -> void:
	if typeof(data) != TYPE_DICTIONARY:
		return
	if not str(data.get("access_token", "")).is_empty():
		session = {
			"access_token": str(data.get("access_token", "")),
			"refresh_token": str(data.get("refresh_token", "")),
			"expires_in": int(data.get("expires_in", 0)),
			"token_type": str(data.get("token_type", "bearer")),
			"user": data.get("user", {}),
		}
		_save_session_to_disk()
		session_changed.emit()
		auth_state_changed.emit(true)


func _load_session_from_disk() -> void:
	session = {}
	if not FileAccess.file_exists(SESSION_PATH):
		return
	var f := FileAccess.open(SESSION_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) == TYPE_DICTIONARY:
		session = parsed


func _save_session_to_disk() -> void:
	var f := FileAccess.open(SESSION_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(session))


func _clear_session() -> void:
	session = {}
	if FileAccess.file_exists(SESSION_PATH):
		DirAccess.remove_absolute(SESSION_PATH)
	session_changed.emit()
	auth_state_changed.emit(false)
