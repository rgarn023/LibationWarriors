class_name RuptureLobbyRules
extends RefCounted
## Shared, deterministic lobby rules. Server must own timers/roster in online mode.

const MAX_PLAYERS := 4
const MATCHMAKING_SECONDS := 120
const READY_COUNTDOWN_SECONDS := 10

static func may_join(player_count: int) -> bool:
	return player_count >= 0 and player_count < MAX_PLAYERS

static func all_ready(players: Array) -> bool:
	if players.is_empty() or players.size() > MAX_PLAYERS:
		return false
	for player in players:
		if typeof(player) != TYPE_DICTIONARY or not bool(player.get("ready", false)):
			return false
	return true

static func entry_countdown_seconds(players: Array) -> int:
	return READY_COUNTDOWN_SECONDS if all_ready(players) else MATCHMAKING_SECONDS

static func encounter_multiplier(player_count: int) -> float:
	# Initial balance curve. Boss mechanics and spawn budgets can scale separately.
	return 1.0 + float(clampi(player_count, 1, MAX_PLAYERS) - 1) * 0.35
