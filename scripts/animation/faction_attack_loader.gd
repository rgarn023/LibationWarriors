extends RefCounted
class_name FactionAttackLoader
## Loads per-faction attack SpriteFrames from individual PNGs (never the contact sheet).


static func build_for_warrior(warrior: Warrior) -> Dictionary:
	## {frames, trail_frame_indices, ok, note}
	if warrior == null:
		return {"ok": false, "frames": SpriteFrames.new(), "trail_frame_indices": [], "note": "no warrior"}
	var faction := str(warrior.faction).to_lower()
	if faction == "pirate":
		var pirate := PirateAttackFrames.build()
		var idle := ManualSheetFrames.build_idle_from_walk_sheet(
			load(warrior.sheet_path()) if ResourceLoader.exists(warrior.sheet_path()) else null
		)
		var merged := ManualSheetFrames.merge_idle_and_attack(idle, pirate.get("frames", SpriteFrames.new()))
		return {
			"ok": bool(pirate.get("ok", false)),
			"frames": merged,
			"trail_frame_indices": pirate.get("trail_frame_indices", []),
			"note": "pirate manual 3x3",
			"phases_used": pirate.get("phases_used", []),
			"durations_used": pirate.get("durations_used", []),
			"source_path": pirate.get("source_path", ""),
		}

	# Other factions: individual attack file if present, else idle-only (no fake attack).
	var attack_path := "res://assets/sprites/attacks/%s_attack.png" % faction
	var idle_tex: Texture2D = null
	if ResourceLoader.exists(warrior.sheet_path()):
		idle_tex = load(warrior.sheet_path())
	var idle := ManualSheetFrames.build_idle_from_walk_sheet(idle_tex)
	if ResourceLoader.exists(attack_path):
		var tex: Texture2D = load(attack_path)
		# Auto grid from texture / 64×80 only as a starting point — caller should
		# replace with a manual catalog entry when the sheet differs.
		var fw := 64
		var fh := 80
		var cols := maxi(1, int(tex.get_width() / fw))
		var rows := maxi(1, int(tex.get_height() / fh))
		var regions: Array = []
		var durs: Array = []
		for r in rows:
			for c in cols:
				regions.append(Rect2i(c * fw, r * fh, fw, fh))
				durs.append(0.08)
		var canvas := Vector2i(fw, fh)
		var built := ManualSheetFrames.build_attack(tex, regions, durs, canvas, "attack", true, 0.01)
		var merged := ManualSheetFrames.merge_idle_and_attack(idle, built["frames"])
		return {
			"ok": int(built["frame_count"]) > 0,
			"frames": merged,
			"trail_frame_indices": [maxi(0, int(built["frame_count"]) / 2)],
			"note": "auto %s" % attack_path,
		}
	return {
		"ok": false,
		"frames": idle,
		"trail_frame_indices": [],
		"note": "no attack sheet for %s" % faction,
	}
