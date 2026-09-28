extends Control

@onready var safe_root: Control = %SafeRoot
@onready var email_edit: LineEdit = %Email
@onready var password_edit: LineEdit = %Password
@onready var status_label: Label = %Status
@onready var sign_in_btn: Button = %SignIn
@onready var create_btn: Button = %Create
@onready var reset_btn: Button = %Reset
@onready var offline_btn: Button = %OfflineDev

var _busy := false


func _ready() -> void:
	SafeArea.register(safe_root)
	UITheme.style_button(sign_in_btn, true)
	UITheme.style_button(create_btn)
	UITheme.style_button(reset_btn)
	UITheme.style_button(offline_btn)
	sign_in_btn.pressed.connect(_on_sign_in)
	create_btn.pressed.connect(_on_create)
	reset_btn.pressed.connect(_on_reset)
	offline_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
	offline_btn.visible = DevBuild.allow_dev_tools()
	if not SupabaseClient.is_configured():
		status_label.text = "Supabase public client configuration is missing."
	else:
		status_label.text = "Sign in to restore your warriors on this device."


func _set_busy(value: bool) -> void:
	_busy = value
	sign_in_btn.disabled = value
	create_btn.disabled = value
	reset_btn.disabled = value


func _validate() -> bool:
	if email_edit.text.strip_edges().is_empty():
		status_label.text = "Enter your email address."
		return false
	if password_edit.text.length() < 6:
		status_label.text = "Password must be at least 6 characters."
		return false
	return true


func _on_sign_in() -> void:
	if _busy or not _validate():
		return
	_set_busy(true)
	status_label.text = "Signing in..."
	var result := await SupabaseClient.sign_in(email_edit.text, password_edit.text)
	if not result.get("ok", false):
		status_label.text = str(result.get("message", "Sign in failed."))
		_set_busy(false)
		return
	await _finish_auth()


func _on_create() -> void:
	if _busy or not _validate():
		return
	_set_busy(true)
	status_label.text = "Creating account..."
	var result := await SupabaseClient.sign_up(email_edit.text, password_edit.text)
	if not result.get("ok", false):
		status_label.text = str(result.get("message", "Account creation failed."))
		_set_busy(false)
		return
	if result.get("needs_confirmation", false):
		status_label.text = "Account created. Check your email to confirm it, then sign in."
		_set_busy(false)
		return
	await _finish_auth()


func _on_reset() -> void:
	if _busy or email_edit.text.strip_edges().is_empty():
		status_label.text = "Enter your email address first."
		return
	_set_busy(true)
	var result := await SupabaseClient.send_password_reset(email_edit.text)
	status_label.text = "Password reset email requested." if result.get("ok", false) else str(result.get("message", "Reset request failed."))
	_set_busy(false)


func _finish_auth() -> void:
	status_label.text = "Loading cloud save..."
	var result := await CloudSaveService.initial_sync()
	if not result.get("ok", false):
		status_label.text = "Signed in. Cloud sync warning: %s" % str(result.get("message", "unknown error"))
		await get_tree().create_timer(0.8).timeout
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
