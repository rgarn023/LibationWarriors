extends Control

@onready var safe_root: Control = %SafeRoot
@onready var btn_scan: Button = %BtnScan
@onready var btn_collection: Button = %BtnCollection
@onready var btn_explore: Button = %BtnExplore
@onready var btn_battle: Button = %BtnBattle
@onready var btn_logout: Button = %BtnLogout
@onready var collection_count: Label = %CollectionCount
@onready var account_status: Label = %AccountStatus

func _ready() -> void:
	SafeArea.register(safe_root)
	UITheme.style_button(btn_scan, true)
	UITheme.style_button(btn_collection)
	UITheme.style_button(btn_explore, true)
	UITheme.style_button(btn_battle)
	UITheme.style_button(btn_logout)
	btn_scan.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/scanner.tscn"))
	btn_collection.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/collection.tscn"))
	btn_explore.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/adventure_lobby.tscn"))
	btn_battle.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/battle_lobby.tscn"))
	btn_logout.pressed.connect(_on_logout)
	btn_logout.visible = SupabaseClient.is_signed_in()
	GameState.collection_changed.connect(_refresh)
	_refresh()

func _refresh() -> void:
	collection_count.text = "%d warriors discovered" % GameState.collection.size()
	account_status.text = "Cloud save connected" if SupabaseClient.is_signed_in() else "Offline development session"

func _on_logout() -> void:
	btn_logout.disabled = true
	account_status.text = "Signing out..."
	await SupabaseClient.sign_out()
	get_tree().change_scene_to_file("res://scenes/auth_gate.tscn")
