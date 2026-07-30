extends SceneTree
func _init() -> void:
	var r := PirateAttackFrames.build()
	print("pirate_ok=", r.get("ok"), " frames=", r.get("phases_used"), " source=", r.get("source_path"))
	var w := Warrior.new({"faction": "pirate"})
	var L := FactionAttackLoader.build_for_warrior(w)
	var fr: SpriteFrames = L["frames"]
	var atk := fr.get_frame_count("attack") if fr.has_animation("attack") else 0
	print("loader_ok=", L.get("ok"), " idle=", fr.get_frame_count("idle"), " atk=", atk, " note=", L.get("note"))
	quit(0)
