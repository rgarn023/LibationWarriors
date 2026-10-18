class_name WarriorBaseArt
extends RefCounted
## Deterministic 64x80 original pixel-art base PORTRAITS for all 16 factions.
## Distinctive gendered silhouette, gear, face, hair, palette and weapon.
## Gameplay directional sheets are a separate authored-animation milestone.

const W := 64
const H := 80
const SKIN := [Color("#f6c5a2"), Color("#dca17e"), Color("#a96547"), Color("#76442f"), Color("#e6ae89")]
const COAT_COLORS := {
	"pirate": "#335c8a", "militiaman": "#596e55", "bandit": "#bd6734",
	"druid": "#326b4c", "barbarian": "#6388a9", "paladin": "#b8a16c",
	"alchemist": "#388977", "bard": "#824d85", "red_mage": "#b53b53",
	"white_mage": "#b6bdd1", "black_mage": "#57427f", "brawler": "#a46b3d",
	"samurai": "#9f3c4f", "viking": "#597d85", "rogue": "#474b69",
	"nimrod": "#79ab53",
}

static func texture_for(warrior: Warrior) -> Texture2D:
	var image := Image.create_empty(W, H, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var sig := warrior.appearance_signature
	var seed := warrior.seed_value
	var parts := warrior.appearance_components
	var gender := warrior.gender
	var outline := Color("#20202e")
	var skin := SKIN[posmod(_component_number(parts, "skin", 1) - 1, SKIN.size())]
	var coat := Color(str(COAT_COLORS.get(warrior.faction, "#6e6688")))
	var accent := warrior.outfit_accent()
	var pants := coat.darkened(0.48)
	var hair := [Color("#302839"), Color("#794a31"), Color("#c99a53"), Color("#ddd0b7"), Color("#593b65")][posmod(int(seed / 29), 5)]
	# Ground and cloak silhouette.
	_fill(image, 13, 73, 39, 3, Color(0.06, 0.05, 0.1, 0.35))
	var is_female := gender == "female"
	var shoulder := 12 if is_female else 10
	if str(parts.get("silhouette", "")) == "stocky":
		shoulder += 3
	elif str(parts.get("silhouette", "")) == "lean":
		shoulder -= 2
	# Torso and legs; each pixel is drawn once using stable UPC blueprint data.
	_fill(image, 26, 52, 6, 18, outline)
	_fill(image, 33, 52, 6, 18, outline)
	_fill(image, 27, 52, 4, 15, pants)
	_fill(image, 34, 52, 4, 15, pants)
	_fill(image, 24, 66, 9, 6, outline)
	_fill(image, 33, 66, 9, 6, outline)
	_fill(image, 25, 67, 7, 4, coat.darkened(0.5))
	_fill(image, 34, 67, 7, 4, coat.darkened(0.5))
	_fill(image, 32 - shoulder, 31, shoulder * 2 + 1, 24, outline)
	_fill(image, 33 - shoulder, 32, shoulder * 2 - 1, 21, coat)
	_fill(image, 31, 31, 3, 21, coat.lightened(0.18))
	_fill(image, 31 - shoulder, 34, 5, 19, coat.darkened(0.27))
	_fill(image, 27, 50, 12, 3, Color("#302936"))
	_fill(image, 30, 50, 5, 3, accent)
	# Cloth overlay / corset / tunic differentiates female and male character bases.
	if is_female:
		_fill(image, 25, 44, 14, 2, accent.darkened(0.12))
		_fill(image, 27, 37, 2, 9, accent)
		_fill(image, 37, 37, 2, 9, accent)
	else:
		_fill(image, 23, 39, 18, 2, accent.darkened(0.15))
		_fill(image, 31, 35, 2, 12, accent)
	# Sleeves and gloves.
	_fill(image, 15 if not is_female else 17, 34, 7, 21, outline)
	_fill(image, 42 if not is_female else 40, 34, 7, 21, outline)
	_fill(image, 16 if not is_female else 18, 35, 5, 16, coat.darkened(0.14))
	_fill(image, 43 if not is_female else 41, 35, 5, 16, coat.darkened(0.14))
	_fill(image, 16 if not is_female else 18, 52, 5, 6, skin)
	_fill(image, 43 if not is_female else 41, 52, 5, 6, skin)
	# Head, face and hair.
	_fill(image, 24, 13, 17, 22, outline)
	_fill(image, 25, 14, 15, 19, skin)
	_fill(image, 25, 13, 15, 7, hair)
	_fill(image, 22, 17, 5, 13 if is_female else 7, hair)
	_fill(image, 39, 17, 5, 14 if is_female else 6, hair)
	if str(parts.get("hair", "hair_01")) in ["hair_03", "hair_04", "hair_05", "hair_06"]:
		_fill(image, 21, 26, 5, 13, hair)
		_fill(image, 40, 26, 5, 13, hair)
	_fill(image, 28, 24, 3, 2, outline)
	_fill(image, 35, 24, 3, 2, outline)
	_fill(image, 31, 30, 4, 1, Color("#7c4a4a"))
	# The faction's recognizable signature headpiece and silhouette.
	var f := warrior.faction
	if f in ["pirate", "bandit"]:
		_fill(image, 16, 13, 34, 4, outline)
		_fill(image, 21, 5, 23, 10, coat.darkened(0.28))
		_fill(image, 22, 14, 21, 2, accent)
	elif f in ["samurai", "viking", "paladin", "militiaman", "barbarian"]:
		_fill(image, 22, 6, 22, 8, outline)
		_fill(image, 25, 7, 16, 5, accent.darkened(0.22))
		_fill(image, 31, 3, 3, 6, accent)
	elif f in ["red_mage", "white_mage", "black_mage", "druid", "rogue"]:
		_fill(image, 20, 11, 25, 6, coat.darkened(0.32))
		_fill(image, 23, 3, 19, 10, coat)
		_fill(image, 30, 4, 5, 4, accent)
	elif f in ["alchemist", "bard"]:
		_fill(image, 24, 10, 17, 5, outline)
		_fill(image, 27, 7, 11, 6, accent)
	elif f == "nimrod":
		_fill(image, 26, 5, 12, 8, accent)
		_fill(image, 28, 3, 8, 5, Color("#f4eb8e"))
	# Weapon / focus is faction-specific.
	match f:
		"pirate", "samurai", "rogue", "bandit", "paladin":
			_fill(image, 52, 13, 2, 42, outline)
			_fill(image, 52, 15, 1, 29, Color("#d7e0e8"))
			_fill(image, 48, 48, 10, 3, accent)
		"barbarian", "viking", "brawler", "militiaman":
			_fill(image, 53, 20, 3, 39, Color("#493427"))
			_fill(image, 49, 17, 12, 12, accent.darkened(0.24))
		"alchemist":
			_fill(image, 48, 43, 11, 14, Color("#a7ded6"))
			_fill(image, 50, 49, 7, 7, Color("#4fd1ae"))
		"nimrod":
			_fill(image, 49, 38, 10, 18, Color("#d1cf6a"))
		_:
			_fill(image, 53, 17, 3, 42, Color("#61506d"))
			_fill(image, 50, 10, 9, 10, accent)
	# Small deterministic crest and contrasting shoulder accent.
	var crest_x := 20 + posmod(int(seed / 137), 5)
	_fill(image, crest_x, 37, 3, 4, accent)
	return ImageTexture.create_from_image(image)

static func _component_number(parts: Dictionary, key: String, fallback: int) -> int:
	var value := str(parts.get(key, ""))
	if value.contains("_"):
		return int(value.get_slice("_", 1))
	return fallback

static func _fill(image: Image, x: int, y: int, w: int, h: int, color: Color) -> void:
	image.fill_rect(Rect2i(x, y, w, h), color)
