class_name CorruptedPathRules
extends RefCounted
## Pure rules for game/test use. Rewards, path closure and rankings need server validation.

const MAX_ACTIVE_PER_PLAYER := 5
const MAX_PATHS_PER_LOCATION := 5
const BONUS_TIERS_HOURS := [12, 24, 48, 56, 168]

static func may_create(player_active: int, location_active: int) -> bool:
	return player_active >= 0 and location_active >= 0 and player_active < MAX_ACTIVE_PER_PLAYER and location_active < MAX_PATHS_PER_LOCATION

static func contribution_score(items_collected: int, damage_dealt: int, damage_taken: int, items_used: int) -> int:
	# Balancing placeholder, NOT a trusted client-issued reward.
	return maxi(0, maxi(0, items_collected) * 100 + maxi(0, damage_dealt) - maxi(0, damage_taken) / 2 - maxi(0, items_used) * 25)

static func ranked_player_indices(player_scores: Array) -> Array[int]:
	var indices: Array[int] = []
	for i in player_scores.size():
		indices.append(i)
	indices.sort_custom(func(a: int, b: int) -> bool:
		var sa := int(player_scores[a])
		var sb := int(player_scores[b])
		return sa > sb if sa != sb else a < b
	)
	return indices

static func duration_bonus_tier(open_seconds: int) -> int:
	# Return highest qualifying threshold in hours. Bonus is non-stacking.
	var hours := maxi(0, open_seconds) / 3600
	var tier := 0
	for threshold in BONUS_TIERS_HOURS:
		if hours >= threshold:
			tier = threshold
	return tier

static func capped_daily_gold(proposed_gold: int, earned_today: int, earned_this_week: int, daily_cap: int, weekly_cap: int) -> int:
	return maxi(0, mini(maxi(0, proposed_gold), maxi(0, daily_cap - earned_today), maxi(0, weekly_cap - earned_this_week)))
