extends Node
## Shared beverage categories, factions, move pools, and naming data.

enum Category {
	RUM,
	BOURBON,
	TEQUILA,
	SCOTCH,
	VODKA,
	BRANDY,
	GIN,
	LIQUEUR,
	RED_WINE,
	WHITE_WINE,
	OTHER_WINE,
	BEER,
	SAKE,
	MEAD,
	OTHER_ALCOHOL,
	NON_ALCOHOLIC,
}

const CATEGORY_LABELS := {
	Category.RUM: "Rum",
	Category.BOURBON: "Bourbon",
	Category.TEQUILA: "Tequila",
	Category.SCOTCH: "Scotch",
	Category.VODKA: "Vodka",
	Category.BRANDY: "Brandy / Cognac",
	Category.GIN: "Gin",
	Category.LIQUEUR: "Liqueur / Cocktail",
	Category.RED_WINE: "Red Wine",
	Category.WHITE_WINE: "White Wine",
	Category.OTHER_WINE: "Other Wine",
	Category.BEER: "Beer",
	Category.SAKE: "Sake",
	Category.MEAD: "Mead",
	Category.OTHER_ALCOHOL: "Other Spirit",
	Category.NON_ALCOHOLIC: "Non-Alcoholic",
}

const CATEGORY_TO_FACTION := {
	Category.RUM: "pirate",
	Category.BOURBON: "militiaman",
	Category.TEQUILA: "bandit",
	Category.SCOTCH: "druid",
	Category.VODKA: "barbarian",
	Category.BRANDY: "paladin",
	Category.GIN: "alchemist",
	Category.LIQUEUR: "bard",
	Category.RED_WINE: "red_mage",
	Category.WHITE_WINE: "white_mage",
	Category.OTHER_WINE: "black_mage",
	Category.BEER: "brawler",
	Category.SAKE: "samurai",
	Category.MEAD: "viking",
	Category.OTHER_ALCOHOL: "rogue",
	Category.NON_ALCOHOLIC: "nimrod",
}

const FACTION_LABELS := {
	"pirate": "Pirate",
	"militiaman": "Militiaman",
	"bandit": "Bandit",
	"druid": "Druid",
	"barbarian": "Barbarian",
	"paladin": "Paladin",
	"alchemist": "Alchemist",
	"bard": "Bard",
	"red_mage": "Red Mage",
	"white_mage": "White Mage",
	"black_mage": "Black Mage",
	"brawler": "Brawler",
	"samurai": "Samurai",
	"viking": "Viking",
	"rogue": "Rogue",
	"nimrod": "Nimrod",
}

## Bottle-inspired color palettes (no brands). Used to tint warriors.
const BOTTLE_PALETTES := [
	{"name": "Amber Glass", "primary": Color(0.72, 0.42, 0.12), "secondary": Color(0.35, 0.18, 0.05)},
	{"name": "Deep Emerald", "primary": Color(0.12, 0.42, 0.28), "secondary": Color(0.05, 0.2, 0.12)},
	{"name": "Cobalt", "primary": Color(0.15, 0.28, 0.65), "secondary": Color(0.08, 0.12, 0.35)},
	{"name": "Clear Crystal", "primary": Color(0.75, 0.82, 0.9), "secondary": Color(0.45, 0.5, 0.58)},
	{"name": "Ruby Pour", "primary": Color(0.55, 0.1, 0.18), "secondary": Color(0.28, 0.05, 0.1)},
	{"name": "Golden Mash", "primary": Color(0.85, 0.7, 0.25), "secondary": Color(0.45, 0.32, 0.08)},
	{"name": "Smoky Char", "primary": Color(0.35, 0.32, 0.3), "secondary": Color(0.15, 0.14, 0.13)},
	{"name": "Frost Label", "primary": Color(0.7, 0.85, 0.95), "secondary": Color(0.35, 0.5, 0.65)},
	{"name": "Copper Still", "primary": Color(0.72, 0.4, 0.22), "secondary": Color(0.4, 0.2, 0.1)},
	{"name": "Ink Black", "primary": Color(0.12, 0.1, 0.14), "secondary": Color(0.35, 0.3, 0.4)},
	{"name": "Rose Tint", "primary": Color(0.75, 0.45, 0.5), "secondary": Color(0.4, 0.2, 0.25)},
	{"name": "Honeycomb", "primary": Color(0.9, 0.72, 0.3), "secondary": Color(0.55, 0.4, 0.12)},
]

const NAME_PREFIXES := {
	"pirate": ["Captain", "Corsair", "Buccaneer", "Matey", "Privateer"],
	"militiaman": ["Sergeant", "Ranger", "Minuteman", "Scout", "Corporal"],
	"bandit": ["Outlaw", "Desperado", "Raider", "Mask", "Coyote"],
	"druid": ["Oak", "Thorn", "Moss", "Heather", "Glen"],
	"barbarian": ["Frost", "Iron", "Wolf", "Storm", "Bear"],
	"paladin": ["Sir", "Knight", "Vigil", "Aegis", "Blessed"],
	"alchemist": ["Alembic", "Vial", "Catalyst", "Tincture", "Retort"],
	"bard": ["Verse", "Chord", "Lyric", "Ballad", "Muse"],
	"red_mage": ["Crimson", "Scarlet", "Vermilion", "Garnet", "Ember"],
	"white_mage": ["Pearl", "Ivory", "Lumen", "Halo", "Grace"],
	"black_mage": ["Umbral", "Void", "Hex", "Shadow", "Rune"],
	"brawler": ["Hop", "Stein", "Mash", "Pint", "Keg"],
	"samurai": ["Blade", "Honor", "Ronin", "Sakura", "Steel"],
	"viking": ["Skald", "Fjord", "Raven", "Axe", "Shield"],
	"rogue": ["Shade", "Whisper", "Dagger", "Smoke", "Silent"],
	"nimrod": ["Soda", "Splash", "Fizz", "Bubbly", "Quencher"],
}

const NAME_SUFFIXES := [
	"of the Cask", "of the Still", "of the Cellar", "of the Barrel",
	"of the Pour", "of the Foam", "of the Vine", "of the Mash",
	"Ash", "Reed", "Stone", "Spark", "Drake", "Wren", "Pike", "Bolt",
]

const REGULAR_MOVES := {
	"pirate": ["Cutlass Slash", "Boarder's Jab", "Salted Strike"],
	"militiaman": ["Bayonet Thrust", "Drill Strike", "Powder Shot"],
	"bandit": ["Ambush Cut", "Dust Kick", "Knife Flick"],
	"druid": ["Root Whip", "Bramble Jab", "Pine Needle"],
	"barbarian": ["Cleaving Blow", "Wild Swing", "Howl Strike"],
	"paladin": ["Holy Smite", "Shield Bash", "Oath Strike"],
	"alchemist": ["Acid Splash", "Stirring Blow", "Catalyst Tap"],
	"bard": ["Sharp Note", "Riff Jab", "Verse Sting"],
	"red_mage": ["Dual Bolt", "Crimson Arc", "Balance Blade"],
	"white_mage": ["Staff Rap", "Lumen Tap", "Gentle Smite"],
	"black_mage": ["Shadow Prick", "Hex Needle", "Dark Flick"],
	"brawler": ["Haymaker", "Bar Slam", "Knuckle Roll"],
	"samurai": ["Iai Cut", "Rising Slash", "Quiet Draw"],
	"viking": ["Axe Chop", "Shield Bash", "War Cry Hit"],
	"rogue": ["Backstab", "Shadow Tick", "Poison Tip"],
	"nimrod": ["Canteen Bonk", "Leaf Toss", "Awkward Poke"],
}

const SPECIAL_MOVES := {
	"pirate": ["Broadside Barrage", "Black Spot", "Kraken Call"],
	"militiaman": ["Volley Fire", "Hold the Line", "Powder Keg"],
	"bandit": ["Dust Devil", "Highway Robbery", "Night Raid"],
	"druid": ["Grove Awakening", "Highland Storm", "Thorn Cage"],
	"barbarian": ["Berserker Rage", "Avalanche", "Blood Frenzy"],
	"paladin": ["Divine Judgment", "Aegis Wall", "Consecrate"],
	"alchemist": ["Unstable Brew", "Philosopher's Flash", "Transmute Burst"],
	"bard": ["Encore Blast", "Crowd Charm", "Power Chord"],
	"red_mage": ["Vermilion Dualcast", "Scarlet Tempest", "Equilibrium"],
	"white_mage": ["Holy", "Full Cure Pulse", "Sanctuary"],
	"black_mage": ["Meteor", "Bio Cascade", "Void Collapse"],
	"brawler": ["Last Call", "Barrel Roll", "Crowd Surf"],
	"samurai": ["Cherry Blossom Cut", "One-Mind Strike", "Moonlight Iai"],
	"viking": ["Ragnarok Swing", "Longship Charge", "Valhalla Call"],
	"rogue": ["Vanish Strike", "Thousand Cuts", "Smoke Bomb"],
	"nimrod": ["Sugar Rush", "Spill Hazard", "Heroic Sip"],
}


func category_label(cat: int) -> String:
	return CATEGORY_LABELS.get(cat, "Unknown")


func faction_for_category(cat: int) -> String:
	return CATEGORY_TO_FACTION.get(cat, "rogue")


func faction_label(faction_id: String) -> String:
	return FACTION_LABELS.get(faction_id, faction_id.capitalize())


func all_categories() -> Array:
	return CATEGORY_LABELS.keys()
