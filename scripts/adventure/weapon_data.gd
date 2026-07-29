class_name WeaponData
extends RefCounted
## Faction weapon shapes and attack styles for Adventure combat.


static func profile(faction: String) -> Dictionary:
	match faction:
		"pirate":
			return _p("cutlass", "melee", 22.0, false, "", 0.0, Color(0.75, 0.78, 0.85))
		"militiaman":
			return _p("bayonet", "hybrid", 20.0, true, "bullet", 78.0, Color(0.55, 0.5, 0.4))
		"bandit":
			return _p("knife", "melee", 16.0, false, "", 0.0, Color(0.7, 0.7, 0.75))
		"druid":
			return _p("staff", "hybrid", 18.0, true, "thorn", 70.0, Color(0.35, 0.55, 0.28))
		"barbarian":
			return _p("axe", "melee", 26.0, false, "", 0.0, Color(0.65, 0.55, 0.45))
		"paladin":
			return _p("sword", "melee", 22.0, false, "", 0.0, Color(0.9, 0.85, 0.55))
		"alchemist":
			return _p("flask", "ranged", 14.0, true, "acid", 72.0, Color(0.45, 0.85, 0.4))
		"bard":
			return _p("lute", "ranged", 14.0, true, "note", 68.0, Color(0.85, 0.65, 0.9))
		"red_mage":
			return _p("rapier", "hybrid", 20.0, true, "bolt", 76.0, Color(0.9, 0.35, 0.35))
		"white_mage":
			return _p("staff", "ranged", 16.0, true, "holy", 74.0, Color(0.95, 0.95, 0.8))
		"black_mage":
			return _p("rod", "ranged", 16.0, true, "shadow", 80.0, Color(0.55, 0.35, 0.8))
		"brawler":
			return _p("fist", "melee", 14.0, false, "", 0.0, Color(0.85, 0.7, 0.55))
		"samurai":
			return _p("katana", "melee", 24.0, false, "", 0.0, Color(0.85, 0.88, 0.95))
		"viking":
			return _p("axe", "melee", 24.0, false, "", 0.0, Color(0.6, 0.62, 0.7))
		"rogue":
			return _p("dagger", "melee", 15.0, false, "", 0.0, Color(0.55, 0.55, 0.6))
		"nimrod":
			return _p("bottle", "hybrid", 15.0, true, "splash", 60.0, Color(0.4, 0.75, 0.9))
		_:
			return _p("sword", "melee", 18.0, false, "", 0.0, Color(0.8, 0.8, 0.85))


static func _p(shape: String, style: String, reach: float, ranged: bool, proj: String, pref_range: float, color: Color) -> Dictionary:
	return {
		"shape": shape,
		"style": style,
		"melee_reach": reach,
		"can_ranged": ranged,
		"projectile": proj,
		"preferred_range": pref_range,
		"color": color,
	}


static func cardinal(dir: Vector2) -> Vector2:
	if dir == Vector2.ZERO:
		return Vector2.DOWN
	if absf(dir.x) >= absf(dir.y):
		return Vector2.RIGHT if dir.x >= 0.0 else Vector2.LEFT
	return Vector2.DOWN if dir.y >= 0.0 else Vector2.UP


static func finish_color(base: Color, weapon_style: int) -> Color:
	match weapon_style % 4:
		1: # Bright Edge
			return base.lightened(0.25).lerp(Color(0.95, 0.95, 1.0), 0.35)
		2: # Darksteel
			return base.darkened(0.35).lerp(Color(0.25, 0.28, 0.35), 0.4)
		3: # Gilded
			return base.lerp(Color(0.95, 0.8, 0.35), 0.55)
		_:
			return base
