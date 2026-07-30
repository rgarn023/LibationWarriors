class_name DungeonGenerator
extends RefCounted
## Builds a Zelda-like multi-room dungeon (10–15 rooms) with key + boss.

const THEMES := [
	{
		"name": "Dilapidated Tower",
		"boss": "Tower Warden",
		"enemy_label": "Tower Guard",
		"floor": Color(0.28, 0.26, 0.3),
		"wall": Color(0.45, 0.4, 0.38),
		"accent": Color(0.7, 0.55, 0.35),
		"enemy_factions": ["rogue", "militiaman", "bandit"],
	},
	{
		"name": "Murky Cave",
		"boss": "Gloom Serpent",
		"enemy_label": "Cave Crawler",
		"floor": Color(0.18, 0.2, 0.22),
		"wall": Color(0.32, 0.36, 0.34),
		"accent": Color(0.35, 0.55, 0.5),
		"enemy_factions": ["rogue", "druid", "barbarian"],
	},
	{
		"name": "Cursed Forest",
		"boss": "Thornwood Horror",
		"enemy_label": "Bramble Shade",
		"floor": Color(0.16, 0.22, 0.14),
		"wall": Color(0.25, 0.38, 0.2),
		"accent": Color(0.45, 0.7, 0.3),
		"enemy_factions": ["druid", "bandit", "bard"],
	},
	{
		"name": "Sunken Crypt",
		"boss": "Bone Cantor",
		"enemy_label": "Crypt Wight",
		"floor": Color(0.2, 0.18, 0.24),
		"wall": Color(0.35, 0.32, 0.4),
		"accent": Color(0.55, 0.45, 0.7),
		"enemy_factions": ["black_mage", "rogue", "paladin"],
	},
	{
		"name": "Ashen Ruins",
		"boss": "Cinder Colossus",
		"enemy_label": "Ash Stalker",
		"floor": Color(0.26, 0.2, 0.16),
		"wall": Color(0.42, 0.3, 0.22),
		"accent": Color(0.85, 0.4, 0.2),
		"enemy_factions": ["barbarian", "brawler", "red_mage"],
	},
	{
		"name": "Flooded Catacombs",
		"boss": "Tidebound Knight",
		"enemy_label": "Drowned Sentry",
		"floor": Color(0.14, 0.2, 0.28),
		"wall": Color(0.25, 0.35, 0.45),
		"accent": Color(0.35, 0.65, 0.85),
		"enemy_factions": ["paladin", "viking", "rogue"],
	},
	{
		"name": "Whispering Mines",
		"boss": "Pickaxe Specter",
		"enemy_label": "Mine Shade",
		"floor": Color(0.22, 0.2, 0.18),
		"wall": Color(0.4, 0.36, 0.3),
		"accent": Color(0.85, 0.75, 0.35),
		"enemy_factions": ["brawler", "alchemist", "bandit"],
	},
	{
		"name": "Thornkeep",
		"boss": "Briar Monarch",
		"enemy_label": "Thornkin",
		"floor": Color(0.2, 0.24, 0.16),
		"wall": Color(0.35, 0.42, 0.25),
		"accent": Color(0.7, 0.35, 0.45),
		"enemy_factions": ["druid", "samurai", "bard"],
	},
]

const DIR_DELTA := {
	"n": Vector2i(0, -1),
	"s": Vector2i(0, 1),
	"w": Vector2i(-1, 0),
	"e": Vector2i(1, 0),
}
const OPPOSITE := {"n": "s", "s": "n", "w": "e", "e": "w"}


static func generate(hero_level: int, seed_value: int = 0, theme_override: Dictionary = {}) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	if seed_value == 0:
		rng.randomize()
	else:
		rng.seed = seed_value

	var theme: Dictionary
	if theme_override.is_empty():
		theme = THEMES[rng.randi() % THEMES.size()].duplicate(true)
	else:
		theme = normalize_theme(theme_override)
	var room_count := rng.randi_range(10, 15)

	# Place rooms on a grid via growth from origin.
	var occupied: Dictionary = {} ## "x,y" -> room id
	var rooms: Array = []
	rooms.append(_blank_room(0, 0, 0))
	occupied["0,0"] = 0

	var dirs := ["n", "s", "e", "w"]
	while rooms.size() < room_count:
		var parent: Dictionary = rooms[rng.randi_range(0, rooms.size() - 1)]
		dirs.shuffle()
		var placed := false
		for d in dirs:
			var nx: int = int(parent["gx"]) + DIR_DELTA[d].x
			var ny: int = int(parent["gy"]) + DIR_DELTA[d].y
			var key := "%d,%d" % [nx, ny]
			if occupied.has(key):
				continue
			var nid := rooms.size()
			rooms.append(_blank_room(nid, nx, ny))
			occupied[key] = nid
			_link_dir(rooms, int(parent["id"]), nid, d)
			placed = true
			break
		if not placed:
			# Force attach somewhere empty adjacent to any room
			var forced := false
			for r in rooms:
				for d2 in dirs:
					var fx: int = int(r["gx"]) + DIR_DELTA[d2].x
					var fy: int = int(r["gy"]) + DIR_DELTA[d2].y
					var fkey := "%d,%d" % [fx, fy]
					if occupied.has(fkey):
						continue
					var nid2 := rooms.size()
					rooms.append(_blank_room(nid2, fx, fy))
					occupied[fkey] = nid2
					_link_dir(rooms, int(r["id"]), nid2, d2)
					forced = true
					break
				if forced:
					break
			if not forced:
				break

	room_count = rooms.size()
	rooms[0]["kind"] = "start"
	rooms[0]["visited"] = true

	# Boss = farthest from start (Manhattan + BFS)
	var dist := _bfs_dist(rooms, 0)
	var boss_id := 1
	var best := -1
	for i in room_count:
		if int(dist[i]) > best:
			best = int(dist[i])
			boss_id = i
	rooms[boss_id]["kind"] = "boss"
	rooms[boss_id]["enemy"] = _make_enemy(theme, hero_level + rng.randi_range(1, 2), true, rng)

	# Key room away from start/boss
	var key_candidates: Array = []
	for i in room_count:
		if i != 0 and i != boss_id:
			key_candidates.append(i)
	var key_id: int = key_candidates[rng.randi() % key_candidates.size()]
	rooms[key_id]["kind"] = "key"

	# Fill rest
	for i in room_count:
		if rooms[i]["kind"] != "empty":
			continue
		var roll := rng.randf()
		if roll < 0.55:
			rooms[i]["kind"] = "enemy"
			rooms[i]["enemy"] = _make_enemy(theme, hero_level + rng.randi_range(0, 1), false, rng)
		elif roll < 0.78:
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
		"boss_id": boss_id,
		"key_id": key_id,
		"has_key": false,
		"boss_unlocked": false,
		"hero_level": hero_level,
		"seed": int(rng.seed),
		"current_room": 0,
		"potions_small": 0,
		"potions_large": 0,
		"player_hp": -1, ## filled when adventure starts
		"is_event": not theme_override.is_empty(),
		"event_id": str(theme_override.get("event_id", "")),
	}


static func normalize_theme(raw: Dictionary) -> Dictionary:
	var base: Dictionary = THEMES[0].duplicate(true)
	if raw.has("name"):
		base["name"] = str(raw["name"])
	if raw.has("boss"):
		base["boss"] = str(raw["boss"])
	if raw.has("enemy_label"):
		base["enemy_label"] = str(raw["enemy_label"])
	if raw.has("enemy_factions"):
		base["enemy_factions"] = raw["enemy_factions"]
	base["floor"] = _as_color(raw.get("floor", base["floor"]))
	base["wall"] = _as_color(raw.get("wall", base["wall"]))
	base["accent"] = _as_color(raw.get("accent", base["accent"]))
	return base


static func _as_color(value) -> Color:
	if value is Color:
		return value
	if value is Array and value.size() >= 3:
		var a := float(value[3]) if value.size() > 3 else 1.0
		return Color(float(value[0]), float(value[1]), float(value[2]), a)
	if value is String:
		return Color(value)
	return Color(0.2, 0.2, 0.22)


static func _blank_room(id: int, gx: int, gy: int) -> Dictionary:
	return {
		"id": id,
		"gx": gx,
		"gy": gy,
		"doors": {}, ## dir -> room id
		"kind": "empty",
		"cleared": false,
		"looted": false,
		"enemy": {},
		"visited": false,
	}


static func _link_dir(rooms: Array, a: int, b: int, dir_from_a: String) -> void:
	rooms[a]["doors"][dir_from_a] = b
	rooms[b]["doors"][OPPOSITE[dir_from_a]] = a


static func _bfs_dist(rooms: Array, start: int) -> Array:
	var dist: Array = []
	dist.resize(rooms.size())
	for i in rooms.size():
		dist[i] = -1
	dist[start] = 0
	var q: Array = [start]
	while not q.is_empty():
		var cur: int = q.pop_front()
		var doors: Dictionary = rooms[cur]["doors"]
		for d in doors.keys():
			var ni: int = int(doors[d])
			if int(dist[ni]) < 0:
				dist[ni] = int(dist[cur]) + 1
				q.append(ni)
	return dist


static func _make_enemy(theme: Dictionary, level: int, is_boss: bool, rng: RandomNumberGenerator) -> Dictionary:
	var factions: Array = theme["enemy_factions"]
	var faction: String = factions[rng.randi() % factions.size()]
	var code := "DUN-%s-%d-%d" % [faction, level, rng.randi()]
	var cat := _category_for_faction(faction)
	var w: Warrior = WarriorFactory.generate(code, cat)
	w = w.scaled_for_level(maxi(1, level))
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
	return {
		"warrior": w.to_dict(),
		"is_boss": is_boss,
	}


static func _category_for_faction(faction: String) -> int:
	for cat in FactionData.CATEGORY_TO_FACTION.keys():
		if FactionData.CATEGORY_TO_FACTION[cat] == faction:
			return int(cat)
	return FactionData.Category.OTHER_ALCOHOL
