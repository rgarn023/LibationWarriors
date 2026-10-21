extends RefCounted
class_name CharacterAnimationLibrary
## Single file that stores every class CharacterAnimationData config.
## Switch characters with get("Samurai") / get_data("samurai") / all_names().
##
## Attack sheets live under res://assets/sprites/attacks/ using the filenames
## you provided. Idle / walk uses the existing res://assets/sprites/*_sheet.png
## so the test scene works even before attack PNGs are copied in.
##
## When you drop a new attack sheet:
## 1. Put it in assets/sprites/attacks/
## 2. Re-import with Nearest / Lossless / no mipmaps (see docs)
## 3. Tweak frame_width / columns / rows / total_frames if that sheet differs


static func all_names() -> PackedStringArray:
	return PackedStringArray([
		"WhiteMage",
		"BlackMage",
		"Brawler",
		"Samurai",
		"Viking",
		"Rogue",
		"Nimrod",
	])


static func get_data(character_name: String) -> CharacterAnimationData:
	var key := _normalize(character_name)
	match key:
		"whitemage", "white_mage":
			return _white_mage()
		"blackmage", "black_mage":
			return _black_mage()
		"brawler":
			return _brawler()
		"samurai":
			return _samurai()
		"viking":
			return _viking()
		"rogue":
			return _rogue()
		"nimrod":
			return _nimrod()
		_:
			push_warning("CharacterAnimationLibrary: unknown character '%s'" % character_name)
			return _samurai()


static func _normalize(name: String) -> String:
	return name.strip_edges().to_lower().replace(" ", "").replace("-", "")


static func _make(
	display_name: String,
	attack_file: String,
	idle_file: String,
	frame_w: int,
	frame_h: int,
	columns: int,
	rows: int,
	total_frames: int,
	attack_fps: float,
	offset: Vector2 = Vector2.ZERO
) -> CharacterAnimationData:
	var d := CharacterAnimationData.new()
	d.character_name = display_name
	d.texture_path = "res://assets/sprites/attacks/%s" % attack_file
	d.idle_texture_path = "res://assets/sprites/%s" % idle_file
	d.frame_width = frame_w
	d.frame_height = frame_h
	d.columns = columns
	d.rows = rows
	d.total_frames = total_frames
	d.attack_fps = attack_fps
	d.attack_loop = false
	d.idle_fps = 6.0
	d.idle_frame_width = 64
	d.idle_frame_height = 80
	d.idle_columns = 4
	d.idle_rows = 1
	d.idle_total_frames = 4
	d.idle_loop = true
	d.sprite_offset = offset
	d.centered = true
	d.display_scale = 2.0
	return d


## --- Per-class configs -------------------------------------------------------
## columns/rows/total_frames = 0 → auto-detect from PNG size / frame size.
## Adjust these when you measure each attached sheet.


static func _white_mage() -> CharacterAnimationData:
	return _make(
		"WhiteMage",
		"white_mage_holy_casting_sprite_sheet.png",
		"white_mage_sheet.png",
		64, 80,
		0, 0, 0,
		10.0,
		Vector2.ZERO
	)


static func _black_mage() -> CharacterAnimationData:
	return _make(
		"BlackMage",
		"shadowspell_black_mage_sprite_sheet.png",
		"black_mage_sheet.png",
		64, 80,
		0, 0, 0,
		10.0,
		Vector2.ZERO
	)


static func _brawler() -> CharacterAnimationData:
	return _make(
		"Brawler",
		"punch_combo_pixel_sprite_sheet.png",
		"brawler_sheet.png",
		64, 80,
		0, 0, 0,
		12.0,
		Vector2.ZERO
	)


static func _samurai() -> CharacterAnimationData:
	return _make(
		"Samurai",
		"samurai_katana_attack_sprite_sheet.png",
		"samurai_sheet.png",
		64, 80,
		0, 0, 0,
		12.0,
		Vector2.ZERO
	)


static func _viking() -> CharacterAnimationData:
	return _make(
		"Viking",
		"viking_heavy_axe_attack_sprite_sheet.png",
		"viking_sheet.png",
		64, 80,
		0, 0, 0,
		11.0,
		Vector2.ZERO
	)


static func _rogue() -> CharacterAnimationData:
	return _make(
		"Rogue",
		"rogue_dagger_attack_sprite_sheet.png",
		"rogue_sheet.png",
		64, 80,
		0, 0, 0,
		14.0,
		Vector2.ZERO
	)


static func _nimrod() -> CharacterAnimationData:
	return _make(
		"Nimrod",
		"nimrod_s_woodland_club_attack_animation.png",
		"nimrod_sheet.png",
		64, 80,
		0, 0, 0,
		11.0,
		Vector2.ZERO
	)
