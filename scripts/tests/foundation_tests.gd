extends Node
## Run this scene in Godot 4.7.x to validate deterministic foundation behavior.

var failures: Array[String] = []
var assertions := 0


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_barcode_identity()
	_test_warrior_identity()
	_test_dungeons()
	_test_direction_math()
	if failures.is_empty():
		print("[FoundationTests] PASS — %d assertions" % assertions)
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error("[FoundationTests] " + failure)
		print("[FoundationTests] FAIL — %d failures / %d assertions" % [failures.size(), assertions])
		get_tree().quit(1)


func _expect(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures.append(message)


func _test_barcode_identity() -> void:
	var upc := "012345678905"
	var ean_alias := "0012345678905"
	_expect(BarcodeIdentity.canonicalize(upc) == upc, "UPC-A normalization changed a canonical value")
	_expect(BarcodeIdentity.canonicalize(ean_alias) == upc, "EAN-13 leading-zero alias did not collapse to UPC-A")
	_expect(BarcodeIdentity.sha256_hex(upc).length() == 64, "SHA-256 identity is not 64 hex chars")
	_expect(BarcodeIdentity.sha256_hex(upc) == BarcodeIdentity.sha256_hex(" 012-345-678-905 "), "formatting changed barcode hash")
	_expect(BarcodeIdentity.seed_from_barcode(upc) == BarcodeIdentity.seed_from_barcode(ean_alias), "alias changed deterministic seed")
	_expect(BarcodeIdentity.canonicalize("not-a-retail-code") == "", "invalid retail text was accepted")


func _test_warrior_identity() -> void:
	var code := "012345678905"
	var a := WarriorFactory.generate(code, FactionData.Category.RUM)
	var b := WarriorFactory.generate(code, FactionData.Category.RUM)
	_expect(a.barcode_hash == b.barcode_hash, "same barcode changed hash")
	_expect(a.seed_value == b.seed_value, "same barcode changed seed")
	_expect(a.faction == "pirate" and b.faction == "pirate", "Rum did not map to Pirate")
	_expect(a.name == b.name, "same barcode changed base name")
	_expect(a.regular_move == b.regular_move, "same barcode changed regular attack")
	_expect(a.special_move == b.special_move, "same barcode changed special attack")
	_expect(a.appearance_signature == b.appearance_signature, "same barcode changed appearance signature")
	_expect(not a.appearance_signature.is_empty(), "appearance signature was empty")
	_expect(a.to_blueprint_dict() == b.to_blueprint_dict(), "same barcode/category changed base blueprint")


func _test_dungeons() -> void:
	for difficulty in ["easy", "normal", "hard"]:
		for level in [1, 10, 30]:
			for seed in range(1, 31):
				var actual_seed := seed * 7919 + level * 101
				var dungeon := DungeonGenerator.generate(level, actual_seed, {}, difficulty)
				var rooms: Array = dungeon.get("rooms", [])
				_expect(rooms.size() >= 10 and rooms.size() <= 25, "room count outside 10..25")
				var start_id := int(dungeon.get("start_id", -1))
				var exit_id := int(dungeon.get("exit_id", -1))
				_expect(start_id >= 0 and start_id < rooms.size(), "invalid entrance")
				_expect(exit_id >= 0 and exit_id < rooms.size(), "invalid exit")
				var reached := _reachable(rooms, start_id)
				_expect(reached.size() == rooms.size(), "dungeon contains disconnected rooms")
				_expect(reached.has(exit_id), "exit is unreachable")
				var coordinates := {}
				for room in rooms:
					var key := "%d,%d" % [int(room.get("gx", 0)), int(room.get("gy", 0))]
					coordinates[key] = true
				_expect(coordinates.size() == rooms.size(), "two rooms occupy the same grid coordinate")

				var repeat := DungeonGenerator.generate(level, actual_seed, {}, difficulty)
				_expect(_graph_signature(dungeon) == _graph_signature(repeat), "same dungeon seed changed graph")


func _reachable(rooms: Array, start_id: int) -> Dictionary:
	var seen := {}
	if start_id < 0 or start_id >= rooms.size():
		return seen
	var queue: Array[int] = [start_id]
	seen[start_id] = true
	while not queue.is_empty():
		var cur := queue.pop_front()
		var doors: Dictionary = rooms[cur].get("doors", {})
		for direction in doors.keys():
			var next_id := int(doors[direction])
			if seen.has(next_id):
				continue
			seen[next_id] = true
			queue.append(next_id)
	return seen


func _graph_signature(dungeon: Dictionary) -> String:
	var parts: Array[String] = []
	for room in dungeon.get("rooms", []):
		var doors: Dictionary = room.get("doors", {})
		var door_parts: Array[String] = []
		var keys: Array = doors.keys()
		keys.sort()
		for key in keys:
			door_parts.append("%s:%d" % [str(key), int(doors[key])])
		parts.append("%d@%d,%d[%s]" % [
			int(room.get("id", -1)),
			int(room.get("gx", 0)),
			int(room.get("gy", 0)),
			",".join(door_parts),
		])
	return "|".join(parts)


func _test_direction_math() -> void:
	_expect(WeaponData.cardinal(Vector2(9, 1)) == Vector2.RIGHT, "right-facing cardinal resolution failed")
	_expect(WeaponData.cardinal(Vector2(-9, 1)) == Vector2.LEFT, "left-facing cardinal resolution failed")
	_expect(WeaponData.cardinal(Vector2(1, -9)) == Vector2.UP, "up-facing cardinal resolution failed")
	_expect(WeaponData.cardinal(Vector2(1, 9)) == Vector2.DOWN, "down-facing cardinal resolution failed")
