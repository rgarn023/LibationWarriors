class_name DungeonBalanceConfig
extends RefCounted
## Centralized dungeon length and encounter tuning.

const DIFFICULTIES := {
	"easy": {
		"label": "Easy",
		"room_bonus": 0,
		"budget_mult": 0.78,
		"level_offset": -1,
	},
	"normal": {
		"label": "Normal",
		"room_bonus": 3,
		"budget_mult": 1.0,
		"level_offset": 0,
	},
	"hard": {
		"label": "Hard",
		"room_bonus": 6,
		"budget_mult": 1.28,
		"level_offset": 1,
	},
}


static func normalize_difficulty(value: String) -> String:
	var key := value.to_lower()
	return key if DIFFICULTIES.has(key) else "normal"


static func label(value: String) -> String:
	var key := normalize_difficulty(value)
	return str(DIFFICULTIES[key]["label"])


static func room_range(hero_level: int, difficulty: String) -> Vector2i:
	var key := normalize_difficulty(difficulty)
	var bonus := int(DIFFICULTIES[key]["room_bonus"])
	var level := maxi(1, hero_level)
	var maximum := clampi(12 + int(level / 2) + bonus, 10, 25)
	var minimum := clampi(10 + int(level / 7) + int(bonus / 3), 10, minimum_int(20, maximum))
	return Vector2i(minimum, maximum)


static func choose_room_count(rng: RandomNumberGenerator, hero_level: int, difficulty: String) -> int:
	var bounds := room_range(hero_level, difficulty)
	return rng.randi_range(bounds.x, bounds.y)


static func encounter_budget(hero_level: int, difficulty: String, depth: int, max_depth: int) -> int:
	var key := normalize_difficulty(difficulty)
	var mult := float(DIFFICULTIES[key]["budget_mult"])
	var level_term := 2.0 + minf(8.0, float(maxi(1, hero_level)) * 0.32)
	var depth_ratio := float(depth) / maxf(1.0, float(max_depth))
	var depth_term := 1.0 + depth_ratio * 4.0
	return maxi(1, int(round((level_term + depth_term) * mult)))


static func enemy_count_for_budget(budget: int, difficulty: String) -> int:
	var key := normalize_difficulty(difficulty)
	var divisor := 4.0 if key == "easy" else (3.3 if key == "normal" else 2.8)
	return clampi(int(ceil(float(maxi(1, budget)) / divisor)), 1, 5)


static func enemy_level(hero_level: int, difficulty: String, depth: int, max_depth: int, index: int = 0) -> int:
	var key := normalize_difficulty(difficulty)
	var offset := int(DIFFICULTIES[key]["level_offset"])
	var depth_bonus := int(round((float(depth) / maxf(1.0, float(max_depth))) * 2.0))
	var group_softener := int(index / 2)
	return maxi(1, hero_level + offset + depth_bonus - group_softener)


static func minimum_int(a: int, b: int) -> int:
	return a if a < b else b
