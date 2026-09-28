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


func _collection_key(barcode: String) -> String:
	var canonical := BarcodeIdentity.canonicalize(barcode)
	return canonical if not canonical.is_empty() else barcode.strip_edges().to_upper()


func has_warrior(barcode: String) -> bool:
	return collection.has(_collection_key(barcode))


func get_warrior(barcode: String) -> Warrior:
	var key := _collection_key(barcode)
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
	var key := _collection_key(warrior.barcode)
	if key.is_empty():
		return {"ok": false, "reason": "empty_barcode"}
	warrior.barcode = key
	if warrior.barcode_hash.is_empty():
		warrior.barcode_hash = BarcodeIdentity.sha256_hex(key)
	if collection.has(key):
		return {"ok": false, "reason": "duplicate", "warrior": Warrior.new(collection[key])}
	collection[key] = warrior.to_dict()
	if from_scan:
		ScanGuard.record_successful_summon(key)
	else:
		SaveSystem.save_game()
	collection_changed.emit()
	warrior_unlocked.emit(warrior)
	CloudSaveService.queue_warrior_sync(warrior)
	return {"ok": true, "warrior": warrior}


func update_warrior(warrior: Warrior) -> void:
	var key := _collection_key(warrior.barcode)
	if key.is_empty() or not collection.has(key):
		return
	warrior.barcode = key
	if warrior.barcode_hash.is_empty():
		warrior.barcode_hash = BarcodeIdentity.sha256_hex(key)
	collection[key] = warrior.to_dict()
	SaveSystem.save_game()
	collection_changed.emit()
	CloudSaveService.queue_warrior_sync(warrior)


func set_party_slot(index: int, barcode: String) -> bool:
	if index < 0 or index >= PARTY_SIZE:
		return false
	var key := _collection_key(barcode) if not barcode.strip_edges().is_empty() else ""
	if key != "" and not collection.has(key):
		return false
	if key != "":
		for i in party.size():
			if i != index and party[i] == key:
				party[i] = ""
	party[index] = key
	SaveSystem.save_game()
	party_changed.emit()
	CloudSaveService.queue_profile_sync()
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
	var raw_collection: Dictionary = data.get("collection", {})
	collection = {}
	for old_key in raw_collection.keys():
		var raw_data: Variant = raw_collection[old_key]
		if typeof(raw_data) != TYPE_DICTIONARY:
			continue
		var warrior := Warrior.new(raw_data)
		var source_code := warrior.barcode if not warrior.barcode.is_empty() else str(old_key)
		var key := _collection_key(source_code)
		warrior.barcode = key
		if warrior.barcode_hash.is_empty():
			warrior.barcode_hash = BarcodeIdentity.sha256_hex(key)
		collection[key] = warrior.to_dict()
	var raw_party: Array = data.get("party", ["", "", ""])
	party = ["", "", ""]
	for i in mini(PARTY_SIZE, raw_party.size()):
		var saved_code := str(raw_party[i])
		party[i] = _collection_key(saved_code) if not saved_code.is_empty() else ""
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


func merge_cloud_warrior(warrior: Warrior) -> void:
	if warrior == null:
		return
	var key := _collection_key(warrior.barcode)
	if key.is_empty():
		return
	warrior.barcode = key
	if warrior.barcode_hash.is_empty():
		warrior.barcode_hash = BarcodeIdentity.sha256_hex(key)
	var existing := get_warrior(key)
	if existing != null:
		var existing_is_newer := existing.level > warrior.level or (existing.level == warrior.level and existing.xp > warrior.xp)
		if existing_is_newer:
			# Canonical cloud base identity still wins, but never discard newer local progression.
			warrior.level = existing.level
			warrior.xp = existing.xp
			warrior.equipment = existing.equipment.duplicate(true)
			warrior.regular_attack_override = existing.regular_attack_override.duplicate(true)
			warrior.special_attack_override = existing.special_attack_override.duplicate(true)
			warrior.progression = existing.progression.duplicate(true)
			warrior._recompute_stats_from_level()
			warrior.reset_hp()
	collection[key] = warrior.to_dict()
	collection_changed.emit()


func party_barcode_hashes() -> Array:
	var out: Array = []
	for code in party:
		if code.is_empty():
			out.append("")
		else:
			var w := get_warrior(code)
			out.append(w.barcode_hash if w != null else BarcodeIdentity.sha256_hex(code))
	return out


func apply_cloud_party_hashes(hashes: Variant) -> void:
	if typeof(hashes) != TYPE_ARRAY:
		return
	var by_hash := {}
	for w in get_all_warriors():
		by_hash[w.barcode_hash] = w.barcode
	var next_party: Array[String] = ["", "", ""]
	for i in mini(PARTY_SIZE, hashes.size()):
		next_party[i] = str(by_hash.get(str(hashes[i]), ""))
	party = next_party
	party_changed.emit()
