class_name AppearanceData
extends RefCounted
## Deterministic component pools. IDs map to synchronized sprite layers as art is added.

const ARCHETYPES := {
	"pirate": "Sea Corsair", "militiaman": "Frontier Sentinel",
	"bandit": "Sunset Outlaw", "druid": "Highland Mystic",
	"barbarian": "Frost Reaver", "paladin": "Gilded Warden",
	"alchemist": "Botanical Artificer", "bard": "Velvet Virtuoso",
	"red_mage": "Crimson Arcanist", "white_mage": "Ivory Oracle",
	"black_mage": "Void Hexer", "brawler": "Iron Bruiser",
	"samurai": "Blossom Ronin", "viking": "Runestone Raider",
	"rogue": "Midnight Stalker", "nimrod": "Fizz Fool",
}

static func gender_for_seed(seed: int) -> String:
	# Intentionally independent of caller, current time, and local RNG.
	return "female" if (seed & 1) == 1 else "male"

static func archetype_for(faction: String) -> String:
	return str(ARCHETYPES.get(faction, "Wandering Warrior"))

const DEFAULT_POOLS := {
	"body": ["body_01", "body_02", "body_03"],
	"silhouette": ["athletic", "lean", "stocky", "regal"],
	"face": ["face_01", "face_02", "face_03", "face_04"],
	"skin": ["skin_01", "skin_02", "skin_03", "skin_04", "skin_05"],
	"headwear": ["hood", "circlet", "none", "helm"],
	"head": ["head_01", "head_02", "head_03", "head_04"],
	"hair": ["hair_01", "hair_02", "hair_03", "hair_04"],
	"outfit": ["outfit_01", "outfit_02", "outfit_03", "outfit_04"],
	"weapon": ["weapon_01", "weapon_02", "weapon_03"],
	"accessory": ["none", "accessory_01", "accessory_02", "accessory_03"],
}

const PIRATE_POOLS := {
	"body": ["body_01", "body_02", "body_03", "body_04"],
	"silhouette": ["athletic", "lean", "stocky", "regal"],
	"face": ["face_01", "face_02", "face_03", "face_04"],
	"skin": ["skin_01", "skin_02", "skin_03", "skin_04", "skin_05"],
	"head": ["head_01", "head_02", "head_03", "head_04", "head_05", "head_06", "head_07"],
	"hair": ["hair_01", "hair_02", "hair_03", "hair_04", "hair_05", "hair_06"],
	"facial_hair": ["none", "stubble_01", "beard_01", "beard_02", "mustache_01"],
	"headwear": ["tricorn_01", "tricorn_02", "bandana_01", "bandana_02", "captain_hat_01", "none"],
	"shirt": ["shirt_01", "shirt_02", "shirt_03", "shirt_04"],
	"coat": ["coat_01", "coat_02", "coat_03", "coat_04", "coat_05", "none"],
	"pants": ["pants_01", "pants_02", "pants_03"],
	"boots": ["boots_01", "boots_02", "boots_03"],
	"belt": ["belt_01", "belt_02", "sash_01", "sash_02"],
	"weapon": ["cutlass_01", "cutlass_02", "saber_01", "hanger_01"],
	"offhand": ["none", "buckler_01", "pistol_01", "hook_01"],
	"accessory": ["none", "earring_01", "scar_01", "necklace_01", "spyglass_01"],
	"palette": ["palette_01", "palette_02", "palette_03", "palette_04", "palette_05", "palette_06"],
}


static func pools_for(faction: String) -> Dictionary:
	return (PIRATE_POOLS if faction == "pirate" else DEFAULT_POOLS).duplicate(true)


static func assign_to(warrior: Warrior, rng: RandomNumberGenerator) -> void:
	var pools := pools_for(warrior.faction)
	var keys: Array = pools.keys()
	keys.sort()
	var components := {}
	var signature: Array[String] = []
	for key in keys:
		var choices: Variant = pools[key]
		if typeof(choices) != TYPE_ARRAY or choices.is_empty():
			continue
		var selected := str(choices[rng.randi() % choices.size()])
		components[str(key)] = selected
		signature.append("%s=%s" % [str(key), selected])
	components["gender"] = warrior.gender
	components["archetype"] = warrior.base_archetype
	signature.append("gender=%s" % warrior.gender)
	signature.append("archetype=%s" % warrior.base_archetype)
	warrior.appearance_components = components
	warrior.appearance_signature = "|".join(signature)
