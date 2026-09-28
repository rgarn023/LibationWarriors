extends Node
## JSON save/load for collection and party.

func save_game() -> void:
	var data := GameState.to_save_dict()
	var file := FileAccess.open(GameState.SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Could not save game: %s" % FileAccess.get_open_error())
		return
	file.store_string(JSON.stringify(data, "\t"))


func load_game() -> void:
	if not FileAccess.file_exists(GameState.SAVE_PATH):
		return
	var file := FileAccess.open(GameState.SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var text := file.get_as_text()
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	GameState.from_save_dict(parsed)


func reset_save() -> void:
	GameState.collection.clear()
	GameState.party = ["", "", ""]
	if FileAccess.file_exists(GameState.SAVE_PATH):
		DirAccess.remove_absolute(GameState.SAVE_PATH)
	GameState.collection_changed.emit()
	GameState.party_changed.emit()
