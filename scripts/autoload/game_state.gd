extends Node
## Persistent collection, party slots, and battle staging.

signal collection_changed
signal party_changed
signal warrior_unlocked(warrior: Warrior)

const PARTY_SIZE := 3
const SAVE_PATH := "user://libation_warriors_save.json"

var collection: Dictionary = {} ## barcode -> Warrior dict
var party: Array[String] = ["", "", ""] ## barcodes
var last_battle_mode: String = "local"
var pending_enemy_party: Array = []


func _ready() -> void:
	SaveSystem.load_game()


func has_warrior(barcode: String) -> bool:
	return collection.has(barcode.strip_edges())


func get_warrior(barcode: String) -> Warrior:
	var key := barcode.strip_edges()
	if not collection.has(key):
		return null
	return Warrior.new(collection[key])


func get_all_warriors() -> Array[Warrior]:
	var list: Array[Warrior] = []
	for key in collection.keys():
		list.append(Warrior.new(collection[key]))
	list.sort_custom(func(a: Warrior, b: Warrior) -> bool: return a.name < b.name)
	return list


func unlock_warrior(warrior: Warrior) -> Dictionary:
	var key := warrior.barcode.strip_edges()
	if key.is_empty():
		return {"ok": false, "reason": "empty_barcode"}
	if collection.has(key):
		return {"ok": false, "reason": "duplicate", "warrior": Warrior.new(collection[key])}
	collection[key] = warrior.to_dict()
	SaveSystem.save_game()
	collection_changed.emit()
	warrior_unlocked.emit(warrior)
	return {"ok": true, "warrior": warrior}


func set_party_slot(index: int, barcode: String) -> bool:
	if index < 0 or index >= PARTY_SIZE:
		return false
	var key := barcode.strip_edges()
	if key != "" and not collection.has(key):
		return false
	# Prevent duplicates in party
	if key != "":
		for i in party.size():
			if i != index and party[i] == key:
				party[i] = ""
	party[index] = key
	SaveSystem.save_game()
	party_changed.emit()
	return true


func clear_party_slot(index: int) -> void:
	set_party_slot(index, "")


func get_party_warriors() -> Array[Warrior]:
	var list: Array[Warrior] = []
	for code in party:
		if code != "" and collection.has(code):
			var w := Warrior.new(collection[code])
			w.reset_hp()
			list.append(w)
	return list


func party_is_ready() -> bool:
	return get_party_warriors().size() == PARTY_SIZE


func to_save_dict() -> Dictionary:
	return {
		"collection": collection,
		"party": party,
	}


func from_save_dict(data: Dictionary) -> void:
	collection = data.get("collection", {})
	var raw_party: Array = data.get("party", ["", "", ""])
	party = ["", "", ""]
	for i in mini(PARTY_SIZE, raw_party.size()):
		party[i] = str(raw_party[i])
	collection_changed.emit()
	party_changed.emit()


func make_training_enemies() -> Array[Warrior]:
	## Local practice opponents generated from fixed demo barcodes (no brands).
	var demos := [
		{"code": "LOCAL-RUM-001", "cat": FactionData.Category.RUM},
		{"code": "LOCAL-BEER-002", "cat": FactionData.Category.BEER},
		{"code": "LOCAL-WINE-003", "cat": FactionData.Category.RED_WINE},
	]
	var enemies: Array[Warrior] = []
	for d in demos:
		var w: Warrior = WarriorFactory.generate(d.code, d.cat)
		w.reset_hp()
		enemies.append(w)
	return enemies
