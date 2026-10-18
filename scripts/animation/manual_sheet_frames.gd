extends RefCounted
class_name ManualSheetFrames
## Builds SpriteFrames from per-character manual AtlasTexture regions.
## Does NOT assume a global grid. Does NOT trim each cell by opaque bounds
## (that would shift the pivot). Every kept cell is pasted onto one shared
## transparent canvas and bottom-centered so feet stay planted.


static func build_attack(
	source: Texture2D,
	regions: Array,
	durations: Array,
	canvas_size: Vector2i,
	anim_name: String = "attack",
	exclude_empty: bool = true,
	min_opaque_ratio: float = 0.01
) -> Dictionary:
	## regions: Array of Rect2i in source pixels (reading order).
	## durations: seconds per frame (animation speed must be 1.0).
	## Returns {frames: SpriteFrames, used_regions: Array, skipped: Array, canvas: Vector2i}
	var result := {
		"frames": SpriteFrames.new(),
		"used_regions": [],
		"skipped": [],
		"canvas": canvas_size,
		"frame_count": 0,
	}
	if source == null:
		push_error("ManualSheetFrames: source texture is null")
		return result

	var img := source.get_image()
	if img == null:
		push_error("ManualSheetFrames: could not read image pixels from texture")
		return result
	if img.get_format() != Image.FORMAT_RGBA8:
		img = img.duplicate()
		img.convert(Image.FORMAT_RGBA8)

	var frames: SpriteFrames = result["frames"]
	if frames.has_animation(anim_name):
		frames.clear(anim_name)
	else:
		frames.add_animation(anim_name)
	frames.set_animation_loop(anim_name, false)
	# duration values are absolute seconds when speed == 1.0
	frames.set_animation_speed(anim_name, 1.0)

	var cw := maxi(1, canvas_size.x)
	var ch := maxi(1, canvas_size.y)
	var kept := 0
	for i in regions.size():
		var rect: Rect2i = regions[i]
		rect = _clamp_rect(rect, img.get_width(), img.get_height())
		if rect.size.x <= 0 or rect.size.y <= 0:
			result["skipped"].append({"index": i, "reason": "empty_rect"})
			continue
		var cell := img.get_region(rect)
		if exclude_empty and not _has_enough_pixels(cell, min_opaque_ratio):
			result["skipped"].append({"index": i, "reason": "too_empty", "rect": rect})
			print("[ManualSheetFrames] skip region %d %s (not enough opaque pixels)" % [i, str(rect)])
			continue
		var canvas := Image.create(cw, ch, false, Image.FORMAT_RGBA8)
		canvas.fill(Color(0, 0, 0, 0))
		# Bottom-center the FULL cell (no content trim) onto the shared canvas.
		var dx := int((cw - cell.get_width()) / 2.0)
		var dy := ch - cell.get_height()
		canvas.blit_rect(cell, Rect2i(0, 0, cell.get_width(), cell.get_height()), Vector2i(dx, dy))
		var tex := ImageTexture.create_from_image(canvas)
		var dur := 0.08
		if i < durations.size():
			dur = float(durations[i])
		frames.add_frame(anim_name, tex, maxf(0.01, dur))
		result["used_regions"].append(rect)
		kept += 1
		print("[ManualSheetFrames] keep frame %d region=%s duration=%.3f" % [kept - 1, str(rect), dur])

	result["frame_count"] = kept
	return result


static func build_idle_from_walk_sheet(walk: Texture2D, frame_w: int = 64, frame_h: int = 80, fps: float = 6.0) -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.add_animation("idle")
	frames.set_animation_loop("idle", true)
	frames.set_animation_speed("idle", fps)
	if walk == null:
		return frames
	var cols := maxi(1, int(walk.get_width() / maxi(1, frame_w)))
	var rows := maxi(1, int(walk.get_height() / maxi(1, frame_h)))
	var total := mini(cols * rows, 4)
	for i in total:
		var col := i % cols
		var row := int(i / cols)
		var atlas := AtlasTexture.new()
		atlas.atlas = walk
		atlas.filter_clip = true
		atlas.region = Rect2(col * frame_w, row * frame_h, frame_w, frame_h)
		frames.add_frame("idle", atlas, 1.0)
	return frames


static func merge_idle_and_attack(idle: SpriteFrames, attack: SpriteFrames) -> SpriteFrames:
	var out := SpriteFrames.new()
	_copy_anim(idle, out, "idle")
	_copy_anim(attack, out, "attack")
	return out


static func _copy_anim(src: SpriteFrames, dst: SpriteFrames, anim: String) -> void:
	if src == null or not src.has_animation(anim):
		return
	if dst.has_animation(anim):
		dst.clear(anim)
	else:
		dst.add_animation(anim)
	dst.set_animation_loop(anim, src.get_animation_loop(anim))
	dst.set_animation_speed(anim, src.get_animation_speed(anim))
	for i in src.get_frame_count(anim):
		dst.add_frame(anim, src.get_frame_texture(anim, i), src.get_frame_duration(anim, i))


static func _clamp_rect(rect: Rect2i, tw: int, th: int) -> Rect2i:
	var x := clampi(rect.position.x, 0, tw)
	var y := clampi(rect.position.y, 0, th)
	var w := clampi(rect.size.x, 0, tw - x)
	var h := clampi(rect.size.y, 0, th - y)
	return Rect2i(x, y, w, h)


static func _has_enough_pixels(cell: Image, min_ratio: float) -> bool:
	var total := cell.get_width() * cell.get_height()
	if total <= 0:
		return false
	var opaque := 0
	for y in cell.get_height():
		for x in cell.get_width():
			if cell.get_pixel(x, y).a > 0.08:
				opaque += 1
	return float(opaque) / float(total) >= min_ratio
