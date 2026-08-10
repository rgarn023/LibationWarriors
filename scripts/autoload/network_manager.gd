extends Node
## Lightweight peer multiplayer for online battles using Godot high-level multiplayer.
## Host creates a lobby; client joins by IP. Party data is exchanged as dictionaries.

signal lobby_status(message: String)
signal match_ready(enemy_party: Array)
signal connection_failed(reason: String)

const DEFAULT_PORT := 7777
const MAX_CLIENTS := 1

var peer: ENetMultiplayerPeer
var is_host := false
var remote_party: Array = []
var local_ready := false
var remote_ready := false


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func host_game(port: int = DEFAULT_PORT) -> Error:
	close()
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_CLIENTS)
	if err != OK:
		connection_failed.emit("Could not host on port %d" % port)
		return err
	multiplayer.multiplayer_peer = peer
	is_host = true
	local_ready = false
	remote_ready = false
	remote_party.clear()
	lobby_status.emit("Hosting on port %d — waiting for challenger..." % port)
	return OK


func join_game(address: String, port: int = DEFAULT_PORT) -> Error:
	close()
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_client(address.strip_edges(), port)
	if err != OK:
		connection_failed.emit("Could not connect to %s:%d" % [address, port])
		return err
	multiplayer.multiplayer_peer = peer
	is_host = false
	local_ready = false
	remote_ready = false
	remote_party.clear()
	lobby_status.emit("Connecting to %s:%d..." % [address, port])
	return OK


func close() -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	peer = null
	is_host = false
	local_ready = false
	remote_ready = false
	remote_party.clear()


func submit_party_ready() -> void:
	if not GameState.party_is_ready():
		lobby_status.emit("Assemble a full party of 3 first.")
		return
	var payload: Array = []
	for w in GameState.get_party_warriors():
		payload.append(w.to_dict())
	local_ready = true
	if multiplayer.multiplayer_peer == null:
		lobby_status.emit("Not connected.")
		return
	_rpc_receive_party.rpc(payload)
	lobby_status.emit("Party sent. Waiting for opponent...")
	_try_start()


@rpc("any_peer", "reliable")
func _rpc_receive_party(party_data: Array) -> void:
	remote_party = party_data
	remote_ready = true
	lobby_status.emit("Opponent party received.")
	_try_start()


func _try_start() -> void:
	if local_ready and remote_ready and remote_party.size() == 3:
		var enemies: Array = []
		for d in remote_party:
			enemies.append(d)
		GameState.pending_enemy_party = enemies
		GameState.last_battle_mode = "online"
		match_ready.emit(enemies)


func _on_peer_connected(id: int) -> void:
	lobby_status.emit("Peer connected: %d" % id)


func _on_peer_disconnected(id: int) -> void:
	lobby_status.emit("Peer disconnected: %d" % id)
	remote_ready = false
	remote_party.clear()


func _on_connected_to_server() -> void:
	lobby_status.emit("Connected to host.")


func _on_connection_failed() -> void:
	connection_failed.emit("Connection failed.")
	close()


func _on_server_disconnected() -> void:
	lobby_status.emit("Host disconnected.")
	close()
