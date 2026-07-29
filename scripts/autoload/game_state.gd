extends Node
## Persistent collection, party slots, battle + adventure staging.

signal collection_changed
signal party_changed
signal warrior_unlocked(warrior: Warrior)

const PARTY_SIZE := 3
const SAVE_PATH := "user://libation_warriors_save.json"

var collection: Dictionary = {} ## barcode -> Warrior dict
var party: Array[String] = ["", "", ""] ## barcodes
var last_battle_mode: String = "local"
var pending_enemy_party: Array = []

## Adventure run state
var adventure_warrior_barcode: String = ""
var adventure_dungeon: Dictionary = {}
var adventure_return_scene: String = "res://scenes/adventure_lobby.tscn"
var pending_adventure_battle: Dictionary = {} ## enemy + context for dungeon combat


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


func unlock_warrior(warrior: Warrior, from_scan: bool = false) -> Dictionary:
	var key := warrior.barcode.strip_edges()
	if key.is_empty():
		return {"ok": false, "reason": "empty_barcode"}
	if collection.has(key):
		return {"ok": false, "reason": "duplicate", "warrior": Warrior.new(collection[key])}
	collection[key] = warrior.to_dict()
	if from_scan:
		ScanGuard.record_successful_summon(key)
	else:
		SaveSystem.save_game()
	collection_changed.emit()
	warrior_unlocked.emit(warrior)
	return {"ok": true, "warrior": warrior}


func update_warrior(warrior: Warrior) -> void:
	var key := warrior.barcode.strip_edges()
	if key.is_empty() or not collection.has(key):
		return
	collection[key] = warrior.to_dict()
	SaveSystem.save_game()
	collection_changed.emit()


func set_party_slot(index: int, barcode: String) -> bool:
	if index < 0 or index >= PARTY_SIZE:
		return false
	var key := barcode.strip_edges()
	if key != "" and not collection.has(key):
		return false
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
		"scan_guard": ScanGuard.to_save_dict(),
	}


func from_save_dict(data: Dictionary) -> void:
	collection = data.get("collection", {})
	var raw_party: Array = data.get("party", ["", "", ""])
	party = ["", "", ""]
	for i in mini(PARTY_SIZE, raw_party.size()):
		party[i] = str(raw_party[i])
	if data.has("scan_guard"):
		ScanGuard.from_save_dict(data.get("scan_guard", {}))
	collection_changed.emit()
	party_changed.emit()


func make_training_enemies() -> Array[Warrior]:
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


func begin_adventure(barcode: String, dungeon: Dictionary) -> void:
	adventure_warrior_barcode = barcode.strip_edges()
	adventure_dungeon = dungeon
	pending_adventure_battle.clear()
	var w := get_warrior(adventure_warrior_barcode)
	if w != null:
		w.reset_hp()
		adventure_dungeon["player_hp"] = w.max_hp
		adventure_dungeon["player_energy"] = w.max_energy
		update_warrior(w)


func get_adventure_warrior() -> Warrior:
	if adventure_warrior_barcode.is_empty():
		return null
	var w := get_warrior(adventure_warrior_barcode)
	if w == null:
		return null
	var hp := int(adventure_dungeon.get("player_hp", w.max_hp))
	if hp < 0:
		hp = w.max_hp
	w.current_hp = clampi(hp, 0, w.max_hp)
	var en := int(adventure_dungeon.get("player_energy", w.max_energy))
	if en < 0:
		en = w.max_energy
	w.current_energy = clampi(en, 0, w.max_energy)
	return w


func save_adventure_warrior(w: Warrior) -> void:
	if w == null:
		return
	adventure_dungeon["player_hp"] = w.current_hp
	adventure_dungeon["player_energy"] = w.current_energy
	update_warrior(w)


func end_adventure() -> void:
	adventure_warrior_barcode = ""
	adventure_dungeon = {}
	pending_adventure_battle.clear()
