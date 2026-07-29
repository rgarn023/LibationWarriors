extends Node
## Deterministically generates unique warriors from barcodes. Never stores brand names.

func barcode_seed(barcode: String) -> int:
	var clean := barcode.strip_edges()
	var h := 2166136261
	for i in clean.length():
		h = int((h ^ clean.unicode_at(i)) * 16777619) & 0x7FFFFFFF
	return h


func generate(barcode: String, category: int) -> Warrior:
	var seed := barcode_seed(barcode)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed

	var faction := FactionData.faction_for_category(category)
	var warrior := Warrior.new()
	warrior.barcode = barcode.strip_edges()
	warrior.faction = faction
	warrior.category = category
	warrior.seed_value = seed

	var prefixes: Array = FactionData.NAME_PREFIXES.get(faction, ["Warrior"])
	var prefix: String = prefixes[rng.randi() % prefixes.size()]
	var suffix: String = FactionData.NAME_SUFFIXES[rng.randi() % FactionData.NAME_SUFFIXES.size()]
	# Encode a short unique token from barcode so same liquor/different codes differ.
	var token := _token_from_seed(seed)
	warrior.name = "%s %s" % [prefix, token]
	if rng.randf() < 0.45:
		warrior.name = "%s %s" % [warrior.name, suffix]

	var palette: Dictionary = FactionData.BOTTLE_PALETTES[rng.randi() % FactionData.BOTTLE_PALETTES.size()]
	warrior.bottle_palette_name = palette["name"]
	warrior.tint_primary = palette["primary"]
	warrior.tint_secondary = palette["secondary"]

	# Stats unique per barcode; faction nudges the spread.
	var atk_bias := _faction_atk_bias(faction)
	var def_bias := _faction_def_bias(faction)
	warrior.attack = clampi(12 + rng.randi_range(0, 28) + atk_bias, 8, 48)
	warrior.defense = clampi(12 + rng.randi_range(0, 28) + def_bias, 8, 48)
	warrior.max_hp = clampi(80 + rng.randi_range(0, 60) + (def_bias * 2), 70, 180)
	warrior.current_hp = warrior.max_hp

	var regs: Array = FactionData.REGULAR_MOVES.get(faction, ["Strike"])
	var specs: Array = FactionData.SPECIAL_MOVES.get(faction, ["Special"])
	warrior.regular_move = regs[rng.randi() % regs.size()]
	warrior.special_move = specs[rng.randi() % specs.size()]
	warrior.regular_power = clampi(10 + rng.randi_range(0, 14) + atk_bias / 2, 8, 30)
	warrior.special_power = clampi(18 + rng.randi_range(0, 22) + atk_bias, 14, 45)

	return warrior


func _token_from_seed(seed: int) -> String:
	const SYLLABLES: Array[String] = ["ra", "ko", "ven", "thar", "lin", "mor", "ash", "que", "dra", "syl", "fen", "jor", "nix", "bel", "tor"]
	var a: String = SYLLABLES[seed % SYLLABLES.size()]
	var b: String = SYLLABLES[(seed / 17) % SYLLABLES.size()]
	var c: String = SYLLABLES[(seed / 93) % SYLLABLES.size()]
	return (a + b + c).capitalize()


func _faction_atk_bias(faction: String) -> int:
	match faction:
		"barbarian", "brawler", "viking", "samurai":
			return 6
		"rogue", "bandit", "pirate":
			return 4
		"white_mage", "nimrod":
			return -2
		_:
			return 0


func _faction_def_bias(faction: String) -> int:
	match faction:
		"paladin", "militiaman", "viking":
			return 6
		"druid", "white_mage":
			return 3
		"bard", "rogue", "nimrod":
			return -2
		_:
			return 0


## Best-effort classification hints from Open Food Facts-style keywords.
## Never returns or displays brand names.
func classify_from_keywords(text: String) -> int:
	var t := text.to_lower()
	if t.is_empty():
		return -1
	# Non-alcoholic first
	if "non-alcoholic" in t or "nonalcoholic" in t or "alcohol free" in t or "soda" in t or "soft drink" in t or "juice" in t or "water" in t and "tonic" not in t:
		if "beer" in t or "wine" in t or "spirit" in t:
			pass
		else:
			return FactionData.Category.NON_ALCOHOLIC
	if "rum" in t:
		return FactionData.Category.RUM
	if "bourbon" in t or "whiskey" in t and "scotch" not in t and "irish" not in t:
		return FactionData.Category.BOURBON
	if "tequila" in t or "mezcal" in t:
		return FactionData.Category.TEQUILA
	if "scotch" in t or "single malt" in t:
		return FactionData.Category.SCOTCH
	if "vodka" in t:
		return FactionData.Category.VODKA
	if "brandy" in t or "cognac" in t or "armagnac" in t:
		return FactionData.Category.BRANDY
	if "gin" in t and "ginger" not in t:
		return FactionData.Category.GIN
	if "liqueur" in t or "cordial" in t or "cocktail" in t or "ready to drink" in t or "rtd" in t:
		return FactionData.Category.LIQUEUR
	if "red wine" in t or ("wine" in t and ("cabernet" in t or "merlot" in t or "pinot noir" in t or "syrah" in t or "malbec" in t or "zinfandel" in t)):
		return FactionData.Category.RED_WINE
	if "white wine" in t or ("wine" in t and ("chardonnay" in t or "sauvignon" in t or "riesling" in t or "pinot grigio" in t or "pinot gris" in t)):
		return FactionData.Category.WHITE_WINE
	if "wine" in t or "champagne" in t or "prosecco" in t or "sparkling" in t:
		return FactionData.Category.OTHER_WINE
	if "beer" in t or "ale" in t or "lager" in t or "ipa" in t or "stout" in t or "porter" in t:
		return FactionData.Category.BEER
	if "sake" in t or "nihonshu" in t:
		return FactionData.Category.SAKE
	if "mead" in t:
		return FactionData.Category.MEAD
	if "whisky" in t or "whiskey" in t or "spirit" in t or "alcohol" in t:
		return FactionData.Category.OTHER_ALCOHOL
	return -1
