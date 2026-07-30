extends RefCounted
class_name PirateAttackFrames
## Pirate cutlass attack — individual sheet, NOT the combined contact sheet.
## Source is a 3×3 visual layout (9 poses). Width may not divide evenly, so
## regions use the manual x/y boundaries from art direction.


const SOURCE_CANDIDATES := [
	"res://assets/sprites/attacks/pirate_attack.png",
	"res://assets/sprites/attacks/pirate_cutlass_attack_sprite_sheet.png",
	"res://assets/sprites/attacks/pirate_sword_attack.png",
]

## Approximate boundaries for the 1024×1536 Pirate attack sheet.
const X_BOUNDS := [0, 341, 683, 1024]
const Y_BOUNDS := [0, 512, 1024, 1536]

## Phase order (reading order: left→right, top→bottom).
const PHASE_NAMES := [
	"Ready",
	"Anticipation",
	"Sword raised",
	"Swing begins",
	"Main slash",
	"Impact",
	"Follow-through",
	"Recovery",
	"Return pose",
]

## Absolute seconds per phase (strike faster than anticipation / recovery).
const PHASE_DURATIONS := [
	0.08, # Ready
	0.10, # Anticipation
	0.10, # Sword raised
	0.06, # Swing begins
	0.05, # Main slash
	0.07, # Impact
	0.09, # Follow-through
	0.12, # Recovery
	0.08, # Return pose (only if 9th frame is kept)
]

## Frame indices (after filtering) that may show a tiny blade trail.
const TRAIL_PHASE_NAMES := ["Main slash", "Impact"]


static func source_path() -> String:
	for p in SOURCE_CANDIDATES:
		if ResourceLoader.exists(p):
			return p
	return ""


static func regions_3x3() -> Array:
	var out: Array = []
	for row in 3:
		for col in 3:
			var x0: int = int(X_BOUNDS[col])
			var x1: int = int(X_BOUNDS[col + 1])
			var y0: int = int(Y_BOUNDS[row])
			var y1: int = int(Y_BOUNDS[row + 1])
			out.append(Rect2i(x0, y0, x1 - x0, y1 - y0))
	return out


static func canvas_size_from_regions(regions: Array) -> Vector2i:
	var mw := 1
	var mh := 1
	for r in regions:
		var rect: Rect2i = r
		mw = maxi(mw, rect.size.x)
		mh = maxi(mh, rect.size.y)
	return Vector2i(mw, mh)


static func build() -> Dictionary:
	## Returns {ok, frames, phases_used, durations_used, source_path, skipped, canvas}
	var path := source_path()
	var empty := {
		"ok": false,
		"frames": SpriteFrames.new(),
		"phases_used": [],
		"durations_used": [],
		"source_path": path,
		"skipped": [],
		"canvas": Vector2i.ZERO,
		"trail_frame_indices": [],
	}
	if path.is_empty():
		push_warning("PirateAttackFrames: no pirate attack PNG found under assets/sprites/attacks/")
		return empty
	var tex: Texture2D = load(path)
	if tex == null:
		push_warning("PirateAttackFrames: failed to load %s" % path)
		return empty

	var regions := regions_3x3()
	# If the authored sheet is shorter/taller than 1536, scale Y bounds to texture height.
	regions = _fit_regions_to_texture(regions, tex.get_width(), tex.get_height())
	var canvas := canvas_size_from_regions(regions)
	var built := ManualSheetFrames.build_attack(
		tex,
		regions,
		PHASE_DURATIONS,
		canvas,
		"attack",
		true,
		0.008
	)
	# Downscale every baked frame to a shared game canvas (64×80) with nearest
	# neighbor so dungeon scaling matches walk sprites without per-frame trim.
	var game_frames := _downscale_attack_frames(built["frames"], Vector2i(64, 80))
	built["frames"] = game_frames
	built["canvas"] = Vector2i(64, 80)
	var used: Array = built["used_regions"]
	var phases_used: Array = []
	var durations_used: Array = []
	var trail_indices: Array = []
	for i in used.size():
		# Map kept frame back to original region index when possible.
		var phase_i := mini(i, PHASE_NAMES.size() - 1)
		# Prefer matching by region equality
		for ri in regions.size():
			if regions[ri] == used[i]:
				phase_i = ri
				break
		var pname: String = str(PHASE_NAMES[phase_i]) if phase_i < PHASE_NAMES.size() else "Frame%d" % i
		# Optional 9th return pose: only keep if present and needed (we already kept it if opaque).
		phases_used.append(pname)
		var dur := float(PHASE_DURATIONS[phase_i]) if phase_i < PHASE_DURATIONS.size() else 0.08
		durations_used.append(dur)
		if pname in TRAIL_PHASE_NAMES:
			trail_indices.append(i)

	print("[PirateAttackFrames] source=%s frames=%d canvas=%s" % [path, built["frame_count"], str(canvas)])
	for i in phases_used.size():
		print("[PirateAttackFrames]  %d: %s (%.3fs)" % [i, phases_used[i], durations_used[i]])

	return {
		"ok": int(built["frame_count"]) > 0,
		"frames": built["frames"],
		"phases_used": phases_used,
		"durations_used": durations_used,
		"source_path": path,
		"skipped": built["skipped"],
		"canvas": canvas,
		"trail_frame_indices": trail_indices,
	}


static func _fit_regions_to_texture(regions: Array, tw: int, th: int) -> Array:
	## Map authored 1024×1536 bounds into whatever size the PNG actually is.
	var sx := float(tw) / 1024.0
	var sy := float(th) / 1536.0
	if is_equal_approx(sx, 1.0) and is_equal_approx(sy, 1.0):
		return regions
	print("[PirateAttackFrames] scaling region bounds to texture %dx%d (sx=%.3f sy=%.3f)" % [tw, th, sx, sy])
	var out: Array = []
	for r in regions:
		var rect: Rect2i = r
		out.append(Rect2i(
			int(round(rect.position.x * sx)),
			int(round(rect.position.y * sy)),
			int(round(rect.size.x * sx)),
			int(round(rect.size.y * sy))
		))
	return out


static func _downscale_attack_frames(src: SpriteFrames, game_size: Vector2i) -> SpriteFrames:
	var out := SpriteFrames.new()
	out.add_animation("attack")
	out.set_animation_loop("attack", false)
	out.set_animation_speed("attack", 1.0)
	if src == null or not src.has_animation("attack"):
		return out
	for i in src.get_frame_count("attack"):
		var tex: Texture2D = src.get_frame_texture("attack", i)
		var dur := src.get_frame_duration("attack", i)
		var img := tex.get_image()
		if img == null:
			continue
		if img.get_format() != Image.FORMAT_RGBA8:
			img = img.duplicate()
			img.convert(Image.FORMAT_RGBA8)
		# Uniform nearest scale to fit game_size height, then bottom-center.
		var scale := float(game_size.y) / float(maxi(1, img.get_height()))
		var nw := maxi(1, int(round(img.get_width() * scale)))
		var nh := maxi(1, int(round(img.get_height() * scale)))
		img.resize(nw, nh, Image.INTERPOLATE_NEAREST)
		var canvas := Image.create(game_size.x, game_size.y, false, Image.FORMAT_RGBA8)
		canvas.fill(Color(0, 0, 0, 0))
		var dx := int((game_size.x - nw) / 2.0)
		var dy := game_size.y - nh
		canvas.blit_rect(img, Rect2i(0, 0, nw, nh), Vector2i(dx, dy))
		out.add_frame("attack", ImageTexture.create_from_image(canvas), dur)
	return out
