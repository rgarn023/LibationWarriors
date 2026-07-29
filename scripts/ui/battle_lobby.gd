extends Control

@onready var safe_root: Control = %SafeRoot
@onready var status_label: Label = %StatusLabel
@onready var address_input: LineEdit = %AddressInput
@onready var port_input: LineEdit = %PortInput
@onready var btn_local: Button = %BtnLocal
@onready var btn_host: Button = %BtnHost
@onready var btn_join: Button = %BtnJoin
@onready var btn_ready: Button = %BtnReady
@onready var btn_back: Button = %BtnBack
@onready var party_summary: Label = %PartySummary


func _ready() -> void:
	SafeArea.register(safe_root)
	UITheme.style_button(btn_local, true)
	UITheme.style_button(btn_host)
	UITheme.style_button(btn_join)
	UITheme.style_button(btn_ready)
	UITheme.style_button(btn_back)
	port_input.text = str(NetworkManager.DEFAULT_PORT)
	address_input.placeholder_text = "Opponent IP (e.g. 192.168.1.10)"
	btn_back.pressed.connect(func():
		NetworkManager.close()
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
	)
	btn_local.pressed.connect(_start_local)
	btn_host.pressed.connect(_host)
	btn_join.pressed.connect(_join)
	btn_ready.pressed.connect(func(): NetworkManager.submit_party_ready())
	NetworkManager.lobby_status.connect(func(msg): status_label.text = msg)
	NetworkManager.connection_failed.connect(func(msg): status_label.text = msg)
	NetworkManager.match_ready.connect(_on_match_ready)
	_refresh_party()
	GameState.party_changed.connect(_refresh_party)


func _refresh_party() -> void:
	var warriors := GameState.get_party_warriors()
	if warriors.is_empty():
		party_summary.text = "Party: empty — build a party of 3 first."
	else:
		var names: PackedStringArray = []
		for w in warriors:
			names.append(w.name)
		party_summary.text = "Party (%d/3): %s" % [warriors.size(), ", ".join(names)]
	if not GameState.party_is_ready():
		status_label.text = "You need a full party of 3 warriors to battle."
	else:
		status_label.text = "Ready. Choose Local Battle or Online Search."


func _start_local() -> void:
	if not GameState.party_is_ready():
		status_label.text = "Assemble a party of 3 first."
		return
	GameState.last_battle_mode = "local"
	GameState.pending_enemy_party.clear()
	for w in GameState.make_training_enemies():
		GameState.pending_enemy_party.append(w.to_dict())
	get_tree().change_scene_to_file("res://scenes/battle.tscn")


func _host() -> void:
	if not GameState.party_is_ready():
		status_label.text = "Assemble a party of 3 first."
		return
	var port := int(port_input.text) if port_input.text.is_valid_int() else NetworkManager.DEFAULT_PORT
	NetworkManager.host_game(port)


func _join() -> void:
	if not GameState.party_is_ready():
		status_label.text = "Assemble a party of 3 first."
		return
	var addr := address_input.text.strip_edges()
	if addr.is_empty():
		status_label.text = "Enter the host IP address."
		return
	var port := int(port_input.text) if port_input.text.is_valid_int() else NetworkManager.DEFAULT_PORT
	NetworkManager.join_game(addr, port)


func _on_match_ready(_enemies: Array) -> void:
	get_tree().change_scene_to_file("res://scenes/battle.tscn")
