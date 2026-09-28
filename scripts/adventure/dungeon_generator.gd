class_name DungeonGenerator
extends RefCounted
## Seeded connected dungeon graph. Rendering remains in dungeon_explore.gd.

const THEMES := [
	{"name":"Dilapidated Tower","boss":"Tower Warden","enemy_label":"Tower Guard","floor":Color(0.28,0.26,0.3),"wall":Color(0.45,0.4,0.38),"accent":Color(0.7,0.55,0.35),"enemy_factions":["rogue","militiaman","bandit"]},
	{"name":"Murky Cave","boss":"Gloom Serpent","enemy_label":"Cave Crawler","floor":Color(0.18,0.2,0.22),"wall":Color(0.32,0.36,0.34),"accent":Color(0.35,0.55,0.5),"enemy_factions":["rogue","druid","barbarian"]},
	{"name":"Cursed Forest","boss":"Thornwood Horror","enemy_label":"Bramble Shade","floor":Color(0.16,0.22,0.14),"wall":Color(0.25,0.38,0.2),"accent":Color(0.45,0.7,0.3),"enemy_factions":["druid","bandit","bard"]},
	{"name":"Sunken Crypt","boss":"Bone Cantor","enemy_label":"Crypt Wight","floor":Color(0.2,0.18,0.24),"wall":Color(0.35,0.32,0.4),"accent":Color(0.55,0.45,0.7),"enemy_factions":["black_mage","rogue","paladin"]},
	{"name":"Ashen Ruins","boss":"Cinder Colossus","enemy_label":"Ash Stalker","floor":Color(0.26,0.2,0.16),"wall":Color(0.42,0.3,0.22),"accent":Color(0.85,0.4,0.2),"enemy_factions":["barbarian","brawler","red_mage"]},
	{"name":"Flooded Catacombs","boss":"Tidebound Knight","enemy_label":"Drowned Sentry","floor":Color(0.14,0.2,0.28),"wall":Color(0.25,0.35,0.45),"accent":Color(0.35,0.65,0.85),"enemy_factions":["paladin","viking","rogue"]},
	{"name":"Whispering Mines","boss":"Pickaxe Specter","enemy_label":"Mine Shade","floor":Color(0.22,0.2,0.18),"wall":Color(0.4,0.36,0.3),"accent":Color(0.85,0.75,0.35),"enemy_factions":["brawler","alchemist","bandit"]},
	{"name":"Thornkeep","boss":"Briar Monarch","enemy_label":"Thornkin","floor":Color(0.2,0.24,0.16),"wall":Color(0.35,0.42,0.25),"accent":Color(0.7,0.35,0.45),"enemy_factions":["druid","samurai","bard"]},
]

const DIR_DELTA := {"n":Vector2i(0,-1),"s":Vector2i(0,1),"w":Vector2i(-1,0),"e":Vector2i(1,0)}
const OPPOSITE := {"n":"s","s":"n","w":"e","e":"w"}


static func generate(
	hero_level: int,
	seed_value: int = 0,
	theme_override: Dictionary = {},
	difficulty: String = "normal"
) -> Dictionary:
	var resolved_difficulty := DungeonBalanceConfig.normalize_difficulty(difficulty)
	var actual_seed := seed_value
	if actual_seed == 0:
		actual_seed = int(Time.get_unix_time_from_system()) ^ int(Time.get_ticks_msec())
	var rng := RandomNumberGenerator.new()
	rng.seed = actual_seed

	var theme := THEMES[rng.randi() % THEMES.size()].duplicate(true) if theme_override.is_empty() else normalize_theme(theme_override)
	var requested_count := DungeonBalanceConfig.choose_room_count(rng, hero_level, resolved_difficulty)
	var occupied := {"0,0": 0}
	var rooms: Array = [_blank_room(0, 0, 0)]
	var dirs := ["n", "s", "e", "w"]

	while rooms.size() < requested_count:
		var parent_index := rng.randi_range(0, rooms.size() - 1)
		var ordered := dirs.duplicate()
		_shuffle_with_rng(ordered, rng)
		var placed := false
		for d in ordered:
			var parent: Dictionary = rooms[parent_index]
			var nx := int(parent["gx"]) + DIR_DELTA[d].x
			var ny := int(parent["gy"]) + DIR_DELTA[d].y
			var key := "%d,%d" % [nx, ny]
			if occupied.has(key):
				continue
			var nid := rooms.size()
			rooms.append(_blank_room(nid, nx, ny))
			occupied[key] = nid
			_link_dir(rooms, parent_index, nid, d)
			placed = true
			break
		if placed:
			continue
		for fallback_index in rooms.size():
			var ordered_fallback := dirs.duplicate()
			_shuffle_with_rng(ordered_fallback, rng)
			for d2 in ordered_fallback:
				var base: Dictionary = rooms[fallback_index]
				var fx := int(base["gx"]) + DIR_DELTA[d2].x
				var fy := int(base["gy"]) + DIR_DELTA[d2].y
				var fkey := "%d,%d" % [fx, fy]
				if occupied.has(fkey):
					continue
				var forced_id := rooms.size()
				rooms.append(_blank_room(forced_id, fx, fy))
				occupied[fkey] = forced_id
				_link_dir(rooms, fallback_index, forced_id, d2)
				placed = true
				break
			if placed:
				break
		if not placed:
			push_error("DungeonGenerator could not place requested connected room.")
			break

	rooms[0]["kind"] = "start"
	rooms[0]["visited"] = true
	var distances := _bfs_dist(rooms, 0)
	var boss_id := 0
	var max_depth := 0
	for i in rooms.size():
		rooms[i]["depth"] = int(distances[i])
		if int(distances[i]) > max_depth:
			max_depth = int(distances[i])
			boss_id = i
	if boss_id == 0 and rooms.size() > 1:
		boss_id = rooms.size() - 1
	rooms[boss_id]["kind"] = "boss"
	rooms[boss_id]["enemy_count"] = 1
	rooms[boss_id]["encounter_budget"] = DungeonBalanceConfig.encounter_budget(hero_level, resolved_difficulty, max_depth, max_depth) + 4
	rooms[boss_id]["enemy"] = _make_enemy(
		theme,
		DungeonBalanceConfig.enemy_level(hero_level, resolved_difficulty, max_depth, max_depth) + 1,
		true,
		rng
	)

	var key_candidates: Array[int] = []
	for i in rooms.size():
		if i != 0 and i != boss_id:
			key_candidates.append(i)
	var key_id := key_candidates[rng.randi() % key_candidates.size()]
	rooms[key_id]["kind"] = "key"

	for i in rooms.size():
		if str(rooms[i]["kind"]) != "empty":
			continue
		var depth := int(rooms[i]["depth"])
		var roll := rng.randf()
		if roll < 0.58:
			var budget := DungeonBalanceConfig.encounter_budget(hero_level, resolved_difficulty, depth, max_depth)
			var enemy_count := DungeonBalanceConfig.enemy_count_for_budget(budget, resolved_difficulty)
			var level := DungeonBalanceConfig.enemy_level(hero_level, resolved_difficulty, depth, max_depth, 0)
			rooms[i]["kind"] = "enemy"
			rooms[i]["encounter_budget"] = budget
			rooms[i]["enemy_count"] = enemy_count
			rooms[i]["enemy"] = _make_enemy(theme, level, false, rng)
		elif roll < 0.80:
			rooms[i]["kind"] = "treasure"
		else:
			rooms[i]["kind"] = "empty"

	return {
		"name": theme["name"],
		"boss_name": theme["boss"],
		"enemy_label": theme["enemy_label"],
		"theme": theme,
		"rooms": rooms,
		"start_id": 0,
		"exit_id": boss_id,
		"boss_id": boss_id,
		"key_id": key_id,
		"has_key": false,
		"boss_unlocked": false,
		"hero_level": hero_level,
		"difficulty": resolved_difficulty,
		"seed": actual_seed,
		"current_room": 0,
		"potions_small": 0,
		"potions_large": 0,
		"player_hp": -1,
		"is_event": not theme_override.is_empty(),
		"event_id": str(theme_override.get("event_id", "")),
	}


static func normalize_theme(raw: Dictionary) -> Dictionary:
	var base: Dictionary = THEMES[0].duplicate(true)
	for key in ["name", "boss", "enemy_label"]:
		if raw.has(key):
			base[key] = str(raw[key])
	if raw.has("enemy_factions"):
		base["enemy_factions"] = raw["enemy_factions"]
	base["floor"] = _as_color(raw.get("floor", base["floor"]))
	base["wall"] = _as_color(raw.get("wall", base["wall"]))
	base["accent"] = _as_color(raw.get("accent", base["accent"]))
	return base


static func _as_color(value: Variant) -> Color:
	if value is Color:
		return value
	if value is Array and value.size() >= 3:
		return Color(float(value[0]), float(value[1]), float(value[2]), float(value[3]) if value.size() > 3 else 1.0)
	if value is String:
		return Color(value)
	return Color(0.2, 0.2, 0.22)


static func _blank_room(id: int, gx: int, gy: int) -> Dictionary:
	return {
		"id": id, "gx": gx, "gy": gy, "doors": {}, "kind": "empty",
		"cleared": false, "looted": false, "enemy": {}, "enemy_count": 0,
		"encounter_budget": 0, "visited": false, "depth": -1,
	}


static func _link_dir(rooms: Array, a: int, b: int, dir_from_a: String) -> void:
	rooms[a]["doors"][dir_from_a] = b
	rooms[b]["doors"][OPPOSITE[dir_from_a]] = a


static func _bfs_dist(rooms: Array, start: int) -> Array:
	var dist: Array = []
	dist.resize(rooms.size())
	dist.fill(-1)
	dist[start] = 0
	var q: Array[int] = [start]
	while not q.is_empty():
		var cur := q.pop_front()
		for d in rooms[cur]["doors"].keys():
			var next_id := int(rooms[cur]["doors"][d])
			if int(dist[next_id]) >= 0:
				continue
			dist[next_id] = int(dist[cur]) + 1
			q.append(next_id)
	return dist


static func _shuffle_with_rng(values: Array, rng: RandomNumberGenerator) -> void:
	for i in range(values.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: Variant = values[i]
		values[i] = values[j]
		values[j] = tmp


static func _make_enemy(theme: Dictionary, level: int, is_boss: bool, rng: RandomNumberGenerator) -> Dictionary:
	var factions: Array = theme["enemy_factions"]
	var faction := str(factions[rng.randi() % factions.size()])
	var code := "DUN-%s-%d-%d" % [faction, level, rng.randi()]
	var w := WarriorFactory.generate(code, _category_for_faction(faction)).scaled_for_level(maxi(1, level))
	if is_boss:
		w.name = str(theme["boss"])
		w.max_hp = int(w.max_hp * 1.65)
		w.current_hp = w.max_hp
		w.attack = int(w.attack * 1.28)
		w.defense = int(w.defense * 1.18)
		w.special_power = int(w.special_power * 1.35)
	else:
		var titles := ["Scout", "Sentry", "Stalker", "Hexer", "Brute"]
		w.name = "%s %s" % [titles[rng.randi() % titles.size()], str(theme["enemy_label"])]
	return {"warrior": w.to_dict(), "is_boss": is_boss}


static func _category_for_faction(faction: String) -> int:
	for cat in FactionData.CATEGORY_TO_FACTION.keys():
		if FactionData.CATEGORY_TO_FACTION[cat] == faction:
			return int(cat)
	return FactionData.Category.OTHER_ALCOHOL
