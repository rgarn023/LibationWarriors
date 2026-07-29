extends Node
## Deterministically generates unique warriors from barcodes. Never stores brand names.

func barcode_seed(barcode: String) -> int:
	var clean := barcode.strip_edges()
	var h := 2166136261
	for i in clean.length():
		h = int((h ^ clean.unicode_at(i)) * 16777619) & 0x7FFFFFFF
	return h


func generate(barcode: String, category: int, packaging_colors: Dictionary = {}) -> Warrior:
	var seed := barcode_seed(barcode)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed

	var faction := FactionData.faction_for_category(category)
	var warrior := Warrior.new()
	warrior.barcode = barcode.strip_edges()
	warrior.faction = faction
	warrior.category = category
	warrior.seed_value = seed
	warrior.level = 1
	warrior.xp = 0

	var prefixes: Array = FactionData.NAME_PREFIXES.get(faction, ["Warrior"])
	var prefix: String = prefixes[rng.randi() % prefixes.size()]
	var suffix: String = FactionData.NAME_SUFFIXES[rng.randi() % FactionData.NAME_SUFFIXES.size()]
	var token := _token_from_seed(seed)
	warrior.name = "%s %s" % [prefix, token]
	if rng.randf() < 0.45:
		warrior.name = "%s %s" % [warrior.name, suffix]

	_apply_packaging_or_fallback_colors(warrior, rng, packaging_colors)

	# Strong per-barcode visual variants
	warrior.variant_pattern = rng.randi_range(0, 5)
	warrior.variant_crest = rng.randi_range(0, 4)
	warrior.variant_weapon_style = rng.randi_range(0, 3)
	warrior.variant_hue_shift = rng.randf_range(-0.07, 0.07)

	var atk_bias := _faction_atk_bias(faction)
	var def_bias := _faction_def_bias(faction)
	warrior.base_attack = clampi(12 + rng.randi_range(0, 28) + atk_bias, 8, 48)
	warrior.base_defense = clampi(12 + rng.randi_range(0, 28) + def_bias, 8, 48)
	warrior.base_max_hp = clampi(80 + rng.randi_range(0, 60) + (def_bias * 2), 70, 180)
	warrior.base_regular_power = clampi(10 + rng.randi_range(0, 14) + atk_bias / 2, 8, 30)
	warrior.base_special_power = clampi(18 + rng.randi_range(0, 22) + atk_bias, 14, 45)
	warrior._recompute_stats_from_level()
	warrior.current_hp = warrior.max_hp

	var regs: Array = FactionData.REGULAR_MOVES.get(faction, ["Strike"])
	var specs: Array = FactionData.SPECIAL_MOVES.get(faction, ["Special"])
	warrior.regular_move = regs[rng.randi() % regs.size()]
	warrior.special_move = specs[rng.randi() % specs.size()]

	return warrior


func _apply_packaging_or_fallback_colors(warrior: Warrior, rng: RandomNumberGenerator, packaging_colors: Dictionary) -> void:
	var has_pkg := packaging_colors.has("primary") and packaging_colors.has("secondary")
	if has_pkg:
		warrior.tint_primary = packaging_colors["primary"]
		warrior.tint_secondary = packaging_colors["secondary"]
		warrior.tint_accent = packaging_colors.get("accent", packaging_colors["primary"].lightened(0.2))
		warrior.bottle_palette_name = str(packaging_colors.get("label", "Packaging Blend"))
	else:
		var palette: Dictionary = FactionData.BOTTLE_PALETTES[rng.randi() % FactionData.BOTTLE_PALETTES.size()]
		warrior.bottle_palette_name = palette["name"]
		warrior.tint_primary = palette["primary"]
		warrior.tint_secondary = palette["secondary"]
		warrior.tint_accent = Color(
			clampf(palette["primary"].r * 0.6 + palette["secondary"].r * 0.4 + 0.15, 0, 1),
			clampf(palette["primary"].g * 0.6 + palette["secondary"].g * 0.4 + 0.1, 0, 1),
			clampf(palette["primary"].b * 0.5 + 0.2, 0, 1)
		)


## Sample dominant colors from a product photo Image (no brand text used).
func colors_from_image(image: Image) -> Dictionary:
	if image == null or image.get_width() < 4 or image.get_height() < 4:
		return {}
	var img := image
	if img.get_format() != Image.FORMAT_RGBA8 and img.get_format() != Image.FORMAT_RGB8:
		img = img.duplicate()
		img.convert(Image.FORMAT_RGBA8)
	# Downsample for speed
	var tw := mini(48, img.get_width())
	var th := mini(48, img.get_height())
	img = img.duplicate()
	img.resize(tw, th, Image.INTERPOLATE_NEAREST)

	var buckets: Dictionary = {}
	var total := 0
	for y in th:
		for x in tw:
			var c := img.get_pixel(x, y)
			# Skip near-white / near-black / gray (labels & shadows)
			if c.v < 0.12 or c.v > 0.94:
				continue
			if c.s < 0.12:
				continue
			var key := "%d_%d_%d" % [int(c.r * 8.0), int(c.g * 8.0), int(c.b * 8.0)]
			if not buckets.has(key):
				buckets[key] = {"count": 0, "r": 0.0, "g": 0.0, "b": 0.0}
			buckets[key]["count"] += 1
			buckets[key]["r"] += c.r
			buckets[key]["g"] += c.g
			buckets[key]["b"] += c.b
			total += 1
	if total < 8:
		return {}

	var ranked: Array = []
	for k in buckets.keys():
		ranked.append(buckets[k])
	ranked.sort_custom(func(a, b): return int(a["count"]) > int(b["count"]))

	var primary := _bucket_to_color(ranked[0])
	var secondary := primary.darkened(0.35)
	var accent := primary.lightened(0.2)
	if ranked.size() > 1:
		secondary = _bucket_to_color(ranked[1])
	if ranked.size() > 2:
		accent = _bucket_to_color(ranked[2])
	return {
		"primary": primary,
		"secondary": secondary,
		"accent": accent,
		"label": "Packaging Blend",
	}


func _bucket_to_color(b: Dictionary) -> Color:
	var n: float = maxf(1.0, float(b["count"]))
	return Color(float(b["r"]) / n, float(b["g"]) / n, float(b["b"]) / n, 1.0)


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


func _has_word(hay: String, needle: String) -> bool:
	## Match whole token/tag fragments so "rum" does not hit unrelated text wrongly,
	## while still matching OFF tags like "en:rums" / "dark-rum".
	if needle.is_empty() or hay.is_empty():
		return false
	if hay == needle:
		return true
	# Tag / hyphen / underscore / punctuation boundaries.
	var markers := [" ", "-", "_", ":", "/", ",", ";", "(", ")", "[", "]", "."]
	if (" " + hay + " ").find(" " + needle + " ") >= 0:
		return true
	for m in markers:
		if hay.find(m + needle + m) >= 0:
			return true
		if hay.begins_with(needle + m) or hay.ends_with(m + needle):
			return true
		if hay.find(m + needle + "s" + m) >= 0 or hay.find(m + needle + "s") >= 0:
			return true
		if hay.ends_with(m + needle + "s") or hay == needle + "s":
			return true
	# Compact tag forms: en:soft-drinks, en:non-alcoholic-beverages
	if hay.find(needle) >= 0:
		# Reject accidental substring inside longer alpha words (e.g. "forum").
		var idx := 0
		while true:
			var at := hay.find(needle, idx)
			if at < 0:
				break
			var before_ok := at == 0 or not _is_alpha(hay.unicode_at(at - 1))
			var after_i := at + needle.length()
			var after_ok := after_i >= hay.length() or not _is_alpha(hay.unicode_at(after_i))
			# Allow plural trailing s
			if after_i < hay.length() and hay.unicode_at(after_i) == "s".unicode_at(0):
				var after2 := after_i + 1
				after_ok = after2 >= hay.length() or not _is_alpha(hay.unicode_at(after2))
			if before_ok and after_ok:
				return true
			idx = at + 1
	return false


func _is_alpha(code: int) -> bool:
	return (code >= 65 and code <= 90) or (code >= 97 and code <= 122)


func _has_any(hay: String, needles: Array) -> bool:
	for n in needles:
		if _has_word(hay, str(n)):
			return true
	return false


## Classify beverage TYPE from product metadata. Never for display of brand names.
## Returns FactionData.Category or -1 if unknown.
func classify_from_keywords(text: String, alcohol_percent: float = -1.0) -> int:
	var t := text.to_lower().replace("_", "-")
	if t.is_empty() and alcohol_percent < 0.0:
		return -1

	# Explicit zero / near-zero alcohol → non-alcoholic.
	if alcohol_percent >= 0.0 and alcohol_percent < 0.5:
		return FactionData.Category.NON_ALCOHOLIC

	var non_alc := [
		"non-alcoholic", "nonalcoholic", "alcohol-free", "alcohol free",
		"soft-drink", "soft-drinks", "soda", "sodas", "cola", "colas",
		"lemonade", "lemonades", "energy-drink", "energy-drinks",
		"sport-drink", "sports-drink", "sports-drinks",
		"carbonated-drink", "carbonated-drinks", "fizzy",
		"juice", "juices", "nectar", "smoothie",
		"water", "waters", "sparkling-water", "still-water", "mineral-water",
		"tea", "teas", "coffee", "coffees", "milk", "dairy-drink",
		"beverage-preparation", "drinkable-yogurt",
		"tonic-water", # non-alc mixer unless marked alcoholic elsewhere
	]
	var alcoholic_conflict := ["beer", "wine", "spirit", "spirits", "rum", "vodka", "whisky", "whiskey", "liqueur", "cider"]

	if _has_any(t, non_alc):
		# Soft drinks / sodas / waters win unless clearly alcoholic beverage too.
		if not _has_any(t, alcoholic_conflict) or _has_any(t, ["non-alcoholic", "nonalcoholic", "alcohol-free", "alcohol free"]):
			# Exception: tonic water with gin context stays gin; plain tonic → non-alc.
			if _has_word(t, "gin") and _has_word(t, "tonic") and not _has_any(t, ["soft-drink", "soft-drinks", "soda", "sodas"]):
				pass
			else:
				return FactionData.Category.NON_ALCOHOLIC

	# Strong spirits — order matters (specific before generic).
	if _has_any(t, ["rum", "rums", "dark-rum", "white-rum", "spiced-rum"]):
		return FactionData.Category.RUM
	if _has_any(t, ["bourbon", "bourbons"]):
		return FactionData.Category.BOURBON
	if _has_any(t, ["tequila", "tequilas", "mezcal", "mezcals"]):
		return FactionData.Category.TEQUILA
	if _has_any(t, ["scotch", "single-malt", "single malt"]):
		return FactionData.Category.SCOTCH
	if _has_any(t, ["vodka", "vodkas"]):
		return FactionData.Category.VODKA
	if _has_any(t, ["brandy", "brandies", "cognac", "cognacs", "armagnac"]):
		return FactionData.Category.BRANDY
	# Gin: avoid ginger / virginia edge-cases via word match.
	if _has_word(t, "gin") or _has_word(t, "gins") or _has_word(t, "genever"):
		if not _has_any(t, ["ginger", "virginia"]):
			return FactionData.Category.GIN
	if _has_any(t, ["liqueur", "liqueurs", "cordial", "cordials", "cocktail", "cocktails", "ready-to-drink", "rtd", "alcopop", "alcopops"]):
		return FactionData.Category.LIQUEUR

	# Wines
	if _has_any(t, ["red-wine", "red wine"]) or (_has_word(t, "wine") and _has_any(t, ["cabernet", "merlot", "pinot-noir", "pinot noir", "syrah", "shiraz", "malbec", "zinfandel", "tempranillo", "sangiovese"])):
		return FactionData.Category.RED_WINE
	if _has_any(t, ["white-wine", "white wine"]) or (_has_word(t, "wine") and _has_any(t, ["chardonnay", "sauvignon", "riesling", "pinot-grigio", "pinot grigio", "pinot-gris", "pinot gris", "moscato"])):
		return FactionData.Category.WHITE_WINE
	if _has_any(t, ["wine", "wines", "champagne", "prosecco", "cava", "sparkling-wine", "sparkling wine", "rose-wine", "rosé", "rose"]):
		# Avoid classifying plain "sparkling" soft drinks as wine (already handled above).
		if not _has_any(t, ["soft-drink", "soft-drinks", "soda", "sodas", "cola"]):
			return FactionData.Category.OTHER_WINE

	if _has_any(t, ["beer", "beers", "ale", "ales", "lager", "lagers", "ipa", "stout", "porter", "porters", "pilsner", "cider", "ciders"]):
		return FactionData.Category.BEER
	if _has_any(t, ["sake", "sakes", "nihonshu"]):
		return FactionData.Category.SAKE
	if _has_any(t, ["mead", "meads"]):
		return FactionData.Category.MEAD

	# Generic alcohol leftovers
	if alcohol_percent >= 0.5:
		return FactionData.Category.OTHER_ALCOHOL
	if _has_any(t, ["whisky", "whiskey", "spirit", "spirits", "liquor", "distilled", "alcoholic-beverage", "alcoholic-beverages", "alcohol"]):
		# "alcohol" tag alone with soft-drink already returned; remaining → other alcohol
		if not _has_any(t, non_alc):
			return FactionData.Category.OTHER_ALCOHOL

	return -1


## Build a classification blob from an Open Food Facts (or similar) product dict.
## Includes product_name only for matching — callers must never show brand text.
func classify_product_dict(product: Dictionary) -> Dictionary:
	var blob := ""
	blob += str(product.get("categories", "")) + " "
	blob += str(product.get("generic_name", "")) + " "
	blob += str(product.get("product_name", "")) + " " # classify only
	blob += str(product.get("product_name_en", "")) + " "
	for t in product.get("categories_tags", []):
		blob += str(t) + " "
	for t in product.get("labels_tags", []):
		blob += str(t) + " "
	for t in product.get("ingredients_analysis_tags", []):
		blob += str(t) + " "
	# Alcohol % from nutriments if present
	var alcohol := -1.0
	if product.has("alcohol_100g"):
		alcohol = float(product.get("alcohol_100g"))
	var nutriments: Variant = product.get("nutriments", {})
	if typeof(nutriments) == TYPE_DICTIONARY:
		if nutriments.has("alcohol") or nutriments.has("alcohol_100g"):
			alcohol = float(nutriments.get("alcohol", nutriments.get("alcohol_100g", alcohol)))
	var cat := classify_from_keywords(blob, alcohol)
	var type_label := ""
	if cat >= 0:
		type_label = FactionData.category_label(cat)
	return {
		"category": cat,
		"type_label": type_label,
		"alcohol_percent": alcohol,
		"confident": cat >= 0,
	}
