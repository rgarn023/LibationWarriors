class_name Warrior
extends RefCounted
## A unique libation warrior bound to a single barcode.

var barcode: String = ""
var barcode_hash: String = ""
var name: String = ""
var faction: String = "rogue"
var category: int = FactionData.Category.OTHER_ALCOHOL
var bottle_palette_name: String = ""
var tint_primary: Color = Color.WHITE
var tint_secondary: Color = Color.GRAY
var tint_accent: Color = Color(0.85, 0.62, 0.22)
var attack: int = 10
var defense: int = 10
var max_hp: int = 100
var current_hp: int = 100
var max_energy: int = 50
var current_energy: int = 50
var regular_move: String = "Strike"
var special_move: String = "Special"
var special_power: int = 20
var regular_power: int = 12
var seed_value: int = 0
var level: int = 1
var xp: int = 0
## Visual variant knobs derived from barcode (and packaging colors).
var variant_pattern: int = 0 ## 0..5 pattern / marking style
var variant_crest: int = 0 ## 0..4 crest / emblem
var variant_weapon_style: int = 0 ## 0..3 weapon finish
var variant_hue_shift: float = 0.0 ## -0.08..0.08
var appearance_components: Dictionary = {}
var appearance_signature: String = ""
var equipment: Dictionary = {}
var regular_attack_override: Dictionary = {}
var special_attack_override: Dictionary = {}
var progression: Dictionary = {}
var base_attack: int = 10
var base_defense: int = 10
var base_max_hp: int = 100
var base_max_energy: int = 50
var base_regular_power: int = 12
var base_special_power: int = 20
const SPECIAL_ENERGY_COST := 22


func _init(data: Dictionary = {}) -> void:
	if data.is_empty():
		return
	from_dict(data)


func from_dict(data: Dictionary) -> void:
	barcode = str(data.get("barcode", ""))
	barcode_hash = str(data.get("barcode_hash", ""))
	name = str(data.get("name", "Unknown"))
	faction = str(data.get("faction", "rogue"))
	category = int(data.get("category", FactionData.Category.OTHER_ALCOHOL))
	bottle_palette_name = str(data.get("bottle_palette_name", ""))
	tint_primary = _color_from(data.get("tint_primary", [1, 1, 1, 1]))
	tint_secondary = _color_from(data.get("tint_secondary", [0.5, 0.5, 0.5, 1]))
	tint_accent = _color_from(data.get("tint_accent", [0.85, 0.62, 0.22, 1]))
	attack = int(data.get("attack", 10))
	defense = int(data.get("defense", 10))
	max_hp = int(data.get("max_hp", 100))
	current_hp = int(data.get("current_hp", max_hp))
	max_energy = int(data.get("max_energy", 50))
	current_energy = int(data.get("current_energy", max_energy))
	regular_move = str(data.get("regular_move", "Strike"))
	special_move = str(data.get("special_move", "Special"))
	special_power = int(data.get("special_power", 20))
	regular_power = int(data.get("regular_power", 12))
	seed_value = int(data.get("seed_value", 0))
	level = maxi(1, int(data.get("level", 1)))
	xp = maxi(0, int(data.get("xp", 0)))
	variant_pattern = int(data.get("variant_pattern", 0))
	variant_crest = int(data.get("variant_crest", 0))
	variant_weapon_style = int(data.get("variant_weapon_style", 0))
	variant_hue_shift = float(data.get("variant_hue_shift", 0.0))
	appearance_components = _dict_from(data.get("appearance_components", {}))
	appearance_signature = str(data.get("appearance_signature", ""))
	equipment = _dict_from(data.get("equipment", {}))
	regular_attack_override = _dict_from(data.get("regular_attack_override", {}))
	special_attack_override = _dict_from(data.get("special_attack_override", {}))
	progression = _dict_from(data.get("progression", {}))
	base_attack = int(data.get("base_attack", attack))
	base_defense = int(data.get("base_defense", defense))
	base_max_hp = int(data.get("base_max_hp", max_hp))
	base_max_energy = int(data.get("base_max_energy", max_energy))
	base_regular_power = int(data.get("base_regular_power", regular_power))
	base_special_power = int(data.get("base_special_power", special_power))
	# Migrate older saves that lacked base_* / level / energy.
	if not data.has("base_attack"):
		base_attack = attack
		base_defense = defense
		base_max_hp = max_hp
		base_regular_power = regular_power
		base_special_power = special_power
		_recompute_stats_from_level()
	if not data.has("max_energy"):
		base_max_energy = 45 + mini(30, (level - 1) * 4)
		max_energy = base_max_energy
		current_energy = max_energy


func to_dict() -> Dictionary:
	return {
		"barcode": barcode,
		"barcode_hash": barcode_hash,
		"name": name,
		"faction": faction,
		"category": category,
		"bottle_palette_name": bottle_palette_name,
		"tint_primary": [tint_primary.r, tint_primary.g, tint_primary.b, tint_primary.a],
		"tint_secondary": [tint_secondary.r, tint_secondary.g, tint_secondary.b, tint_secondary.a],
		"tint_accent": [tint_accent.r, tint_accent.g, tint_accent.b, tint_accent.a],
		"attack": attack,
		"defense": defense,
		"max_hp": max_hp,
		"current_hp": current_hp,
		"max_energy": max_energy,
		"current_energy": current_energy,
		"regular_move": regular_move,
		"special_move": special_move,
		"special_power": special_power,
		"regular_power": regular_power,
		"seed_value": seed_value,
		"level": level,
		"xp": xp,
		"variant_pattern": variant_pattern,
		"variant_crest": variant_crest,
		"variant_weapon_style": variant_weapon_style,
		"variant_hue_shift": variant_hue_shift,
		"appearance_components": appearance_components,
		"appearance_signature": appearance_signature,
		"equipment": equipment,
		"regular_attack_override": regular_attack_override,
		"special_attack_override": special_attack_override,
		"progression": progression,
		"base_attack": base_attack,
		"base_defense": base_defense,
		"base_max_hp": base_max_hp,
		"base_max_energy": base_max_energy,
		"base_regular_power": base_regular_power,
		"base_special_power": base_special_power,
	}


func to_blueprint_dict() -> Dictionary:
	return {
		"name": name,
		"faction": faction,
		"category": category,
		"bottle_palette_name": bottle_palette_name,
		"tint_primary": [tint_primary.r, tint_primary.g, tint_primary.b, tint_primary.a],
		"tint_secondary": [tint_secondary.r, tint_secondary.g, tint_secondary.b, tint_secondary.a],
		"tint_accent": [tint_accent.r, tint_accent.g, tint_accent.b, tint_accent.a],
		"regular_move": regular_move,
		"special_move": special_move,
		"seed_value": seed_value,
		"variant_pattern": variant_pattern,
		"variant_crest": variant_crest,
		"variant_weapon_style": variant_weapon_style,
		"variant_hue_shift": variant_hue_shift,
		"appearance_components": appearance_components,
		"appearance_signature": appearance_signature,
		"base_attack": base_attack,
		"base_defense": base_defense,
		"base_max_hp": base_max_hp,
		"base_max_energy": base_max_energy,
		"base_regular_power": base_regular_power,
		"base_special_power": base_special_power,
		"attack": base_attack,
		"defense": base_defense,
		"max_hp": base_max_hp,
		"max_energy": base_max_energy,
		"regular_power": base_regular_power,
		"special_power": base_special_power,
	}


func regular_attack_data() -> Dictionary:
	var out := {"name": regular_move, "power": regular_power, "effects": []}
	for key in regular_attack_override.keys():
		out[key] = regular_attack_override[key]
	return out


func special_attack_data() -> Dictionary:
	var out := {"name": special_move, "power": special_power, "effects": []}
	for key in special_attack_override.keys():
		out[key] = special_attack_override[key]
	return out


func _dict_from(value: Variant) -> Dictionary:
	return value.duplicate(true) if typeof(value) == TYPE_DICTIONARY else {}


func _color_from(value) -> Color:
	if value is Color:
		return value
	if value is Array and value.size() >= 3:
		var a := float(value[3]) if value.size() > 3 else 1.0
		return Color(float(value[0]), float(value[1]), float(value[2]), a)
	if value is String:
		return Color(value)
	return Color.WHITE


func reset_hp() -> void:
	current_hp = max_hp
	current_energy = max_energy


func heal(amount: int) -> int:
	var before := current_hp
	current_hp = mini(max_hp, current_hp + maxi(0, amount))
	return current_hp - before


func restore_energy(amount: int) -> int:
	var before := current_energy
	current_energy = mini(max_energy, current_energy + maxi(0, amount))
	return current_energy - before


func can_special() -> bool:
	return current_energy >= SPECIAL_ENERGY_COST and is_alive()


func spend_special_energy() -> bool:
	if not can_special():
		return false
	current_energy -= SPECIAL_ENERGY_COST
	return true


func is_alive() -> bool:
	return current_hp > 0


func energy_item_name() -> String:
	return FactionData.energy_item_for_faction(faction)


func duplicate_warrior() -> Warrior:
	return Warrior.new(to_dict())


func sprite_path() -> String:
	return "res://assets/sprites/%s.png" % faction


func sheet_path() -> String:
	return "res://assets/sprites/%s_sheet.png" % faction


func preview_path() -> String:
	return "res://assets/sprites/%s_preview.png" % faction


func faction_display() -> String:
	return FactionData.faction_label(faction)


func category_display() -> String:
	return FactionData.category_label(category)


func xp_to_next_level() -> int:
	return 40 + (level * 35) + ((level * level) * 5)


func gain_xp(amount: int) -> Dictionary:
	var gained := maxi(0, amount)
	xp += gained
	var levels := 0
	while xp >= xp_to_next_level():
		xp -= xp_to_next_level()
		level += 1
		levels += 1
		_recompute_stats_from_level()
		current_hp = max_hp
		current_energy = max_energy
	return {"gained": gained, "levels": levels, "level": level, "xp": xp}


func _recompute_stats_from_level() -> void:
	var bonus := level - 1
	attack = base_attack + bonus * 2
	defense = base_defense + bonus * 2
	max_hp = base_max_hp + bonus * 8
	max_energy = base_max_energy + bonus * 4
	regular_power = base_regular_power + bonus
	special_power = base_special_power + bonus * 2


func scaled_for_level(target_level: int) -> Warrior:
	## Clone with stats scaled as if this warrior were target_level (for enemies).
	var w := Warrior.new(to_dict())
	w.level = maxi(1, target_level)
	w.xp = 0
	w._recompute_stats_from_level()
	w.reset_hp()
	return w


func calc_damage(move_power: int, target_defense: int, is_special: bool = false) -> int:
	var variance: float = 0.85 + (float((seed_value + move_power) % 30) / 100.0)
	var raw: float = float(attack) * float(move_power) / maxf(1.0, float(target_defense) * 0.65)
	if is_special:
		raw *= 1.35
	return maxi(1, int(round(raw * variance)))


func variant_label() -> String:
	const PATTERNS := ["Plainweave", "Striped", "Marbled", "Runed", "Speckled", "Banded"]
	const CRESTS := ["No Crest", "Sunmark", "Moonmark", "Thornmark", "Wave mark"]
	const WEAPONS := ["Dull Steel", "Bright Edge", "Darksteel", "Gilded"]
	return "%s · %s · %s" % [
		PATTERNS[variant_pattern % PATTERNS.size()],
		CRESTS[variant_crest % CRESTS.size()],
		WEAPONS[variant_weapon_style % WEAPONS.size()],
	]


func weapon_profile() -> Dictionary:
	return WeaponData.profile(faction)


func prefers_ranged() -> bool:
	var p := weapon_profile()
	return str(p.get("style", "melee")) == "ranged"


func can_ranged() -> bool:
	return bool(weapon_profile().get("can_ranged", false))


func display_modulate() -> Color:
	## Soft packaging tint on the sprite itself (no blocky overlays).
	var c := outfit_primary()
	var blend := 0.28
	return Color(
		c.r * blend + (1.0 - blend),
		c.g * blend + (1.0 - blend),
		c.b * blend + (1.0 - blend),
		1.0
	)


func outfit_primary() -> Color:
	return _outfit_shift(tint_primary)


func outfit_secondary() -> Color:
	return _outfit_shift(tint_secondary)


func outfit_accent() -> Color:
	return _outfit_shift(tint_accent)


func _outfit_shift(base: Color) -> Color:
	var c := base
	if absf(variant_hue_shift) > 0.001:
		var h := c.h + variant_hue_shift
		if h < 0.0:
			h += 1.0
		if h > 1.0:
			h -= 1.0
		c = Color.from_hsv(h, clampf(c.s * 1.08, 0.15, 1.0), clampf(c.v, 0.25, 1.0), 1.0)
	return c
