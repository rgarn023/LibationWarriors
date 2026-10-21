extends RefCounted
class_name SpriteFramesBuilder
## Builds a SpriteFrames resource from CharacterAnimationData.
## Pixel-perfect: AtlasTexture regions, no filtering assumptions in the atlas itself.
## Callers must set AnimatedSprite2D.texture_filter = TEXTURE_FILTER_NEAREST.


const ANIM_IDLE := "idle"
const ANIM_ATTACK := "attack"


static func build(data: CharacterAnimationData) -> SpriteFrames:
	var frames := SpriteFrames.new()
	if data == null:
		push_error("SpriteFramesBuilder: CharacterAnimationData is null")
		return frames

	_ensure_animation(frames, ANIM_IDLE)
	_ensure_animation(frames, ANIM_ATTACK)

	var attack_tex := _load_texture(data.resolved_attack_path())
	var idle_path := data.resolved_idle_path()
	var idle_tex := attack_tex
	if idle_path != data.resolved_attack_path():
		idle_tex = _load_texture(idle_path)
		if idle_tex == null:
			idle_tex = attack_tex

	if attack_tex == null and idle_tex == null:
		push_error("SpriteFramesBuilder: no textures for '%s'" % data.character_name)
		return frames

	# --- Idle ---
	var idle_src: Texture2D = idle_tex if idle_tex else attack_tex
	var idle_size := data.idle_frame_size()
	var idle_grid := _resolve_grid(
		idle_src,
		idle_size,
		data.idle_columns,
		data.idle_rows,
		data.idle_total_frames
	)
	_fill_animation(
		frames,
		ANIM_IDLE,
		idle_src,
		idle_size,
		idle_grid,
		data.idle_fps,
		data.idle_loop
	)

	# --- Attack (one-shot) ---
	var atk_src: Texture2D = attack_tex if attack_tex else idle_tex
	var atk_size := data.attack_frame_size()
	var atk_grid := _resolve_grid(
		atk_src,
		atk_size,
		data.columns,
		data.rows,
		data.total_frames
	)
	_fill_animation(
		frames,
		ANIM_ATTACK,
		atk_src,
		atk_size,
		atk_grid,
		data.attack_fps,
		data.attack_loop
	)
	return frames


static func _ensure_animation(frames: SpriteFrames, anim: String) -> void:
	if frames.has_animation(anim):
		frames.clear(anim)
	else:
		frames.add_animation(anim)


static func _load_texture(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if not ResourceLoader.exists(path):
		push_warning("SpriteFramesBuilder: missing texture '%s'" % path)
		return null
	var res := load(path)
	if res is Texture2D:
		return res
	push_warning("SpriteFramesBuilder: not a Texture2D: '%s'" % path)
	return null


static func _resolve_grid(tex: Texture2D, frame_size: Vector2i, columns: int, rows: int, total_frames: int) -> Dictionary:
	## Returns {columns, rows, total_frames}
	var tw := tex.get_width() if tex else frame_size.x
	var th := tex.get_height() if tex else frame_size.y
	var cols := columns
	var rws := rows
	if cols <= 0:
		cols = maxi(1, int(tw / maxi(1, frame_size.x)))
	if rws <= 0:
		rws = maxi(1, int(th / maxi(1, frame_size.y)))
	var total := total_frames
	if total <= 0:
		total = cols * rws
	total = clampi(total, 1, cols * rws)
	return {"columns": cols, "rows": rws, "total_frames": total}


static func _fill_animation(
	frames: SpriteFrames,
	anim: String,
	tex: Texture2D,
	frame_size: Vector2i,
	grid: Dictionary,
	fps: float,
	loop: bool
) -> void:
	frames.set_animation_loop(anim, loop)
	frames.set_animation_speed(anim, maxf(0.01, fps))
	var cols: int = int(grid.columns)
	var total: int = int(grid.total_frames)
	for i in total:
		var col := i % cols
		var row := int(i / cols)
		var atlas := AtlasTexture.new()
		atlas.atlas = tex
		atlas.filter_clip = true
		atlas.region = Rect2(
			col * frame_size.x,
			row * frame_size.y,
			frame_size.x,
			frame_size.y
		)
		frames.add_frame(anim, atlas, 1.0, i)
