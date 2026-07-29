class_name Warrior
extends RefCounted
## A unique libation warrior bound to a single barcode.

var barcode: String = ""
var name: String = ""
var faction: String = "rogue"
var category: int = FactionData.Category.OTHER_ALCOHOL
var bottle_palette_name: String = ""
var tint_primary: Color = Color.WHITE
var tint_secondary: Color = Color.GRAY
var attack: int = 10
var defense: int = 10
var max_hp: int = 100
var current_hp: int = 100
var regular_move: String = "Strike"
var special_move: String = "Special"
var special_power: int = 20
var regular_power: int = 12
var seed_value: int = 0


func _init(data: Dictionary = {}) -> void:
	if data.is_empty():
		return
	from_dict(data)


func from_dict(data: Dictionary) -> void:
	barcode = str(data.get("barcode", ""))
	name = str(data.get("name", "Unknown"))
	faction = str(data.get("faction", "rogue"))
	category = int(data.get("category", FactionData.Category.OTHER_ALCOHOL))
	bottle_palette_name = str(data.get("bottle_palette_name", ""))
	tint_primary = _color_from(data.get("tint_primary", [1, 1, 1, 1]))
	tint_secondary = _color_from(data.get("tint_secondary", [0.5, 0.5, 0.5, 1]))
	attack = int(data.get("attack", 10))
	defense = int(data.get("defense", 10))
	max_hp = int(data.get("max_hp", 100))
	current_hp = int(data.get("current_hp", max_hp))
	regular_move = str(data.get("regular_move", "Strike"))
	special_move = str(data.get("special_move", "Special"))
	special_power = int(data.get("special_power", 20))
	regular_power = int(data.get("regular_power", 12))
	seed_value = int(data.get("seed_value", 0))


func to_dict() -> Dictionary:
	return {
		"barcode": barcode,
		"name": name,
		"faction": faction,
		"category": category,
		"bottle_palette_name": bottle_palette_name,
		"tint_primary": [tint_primary.r, tint_primary.g, tint_primary.b, tint_primary.a],
		"tint_secondary": [tint_secondary.r, tint_secondary.g, tint_secondary.b, tint_secondary.a],
		"attack": attack,
		"defense": defense,
		"max_hp": max_hp,
		"current_hp": current_hp,
		"regular_move": regular_move,
		"special_move": special_move,
		"special_power": special_power,
		"regular_power": regular_power,
		"seed_value": seed_value,
	}


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


func is_alive() -> bool:
	return current_hp > 0


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


func calc_damage(move_power: int, target_defense: int, is_special: bool = false) -> int:
	var variance: float = 0.85 + (float((seed_value + move_power) % 30) / 100.0)
	var raw: float = float(attack) * float(move_power) / maxf(1.0, float(target_defense) * 0.65)
	if is_special:
		raw *= 1.35
	return maxi(1, int(round(raw * variance)))
