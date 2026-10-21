extends RefCounted
class_name PirateAttackFrames
## Pirate cutlass attack — curated cells only (not all 9 in reading order).
## Source art faces LEFT. Path preferred: assets/animations/01_Pirate_Attack.png


const SOURCE_CANDIDATES := [
	"res://assets/animations/01_Pirate_Attack.png",
	"res://assets/sprites/attacks/pirate_attack.png",
	"res://assets/sprites/attacks/pirate_cutlass_attack_sprite_sheet.png",
	"res://assets/sprites/attacks/pirate_sword_attack.png",
]

const X_BOUNDS := [0, 341, 683, 1024]
const Y_BOUNDS := [0, 512, 1024, 1536]

## Usable cells only. Exclude 2, 3, 5, 6, 8.
const PIRATE_FRAME_ORDER := [
	0, # ready
	1, # anticipation
	4, # sword raised / swing begins
	7, # main slash and impact
	0, # recovery to ready
]

## Duration multipliers at animation speed 12.0
const PIRATE_FRAME_DURATIONS := [
	1.2, # ready
	1.0, # anticipation
	0.8, # sword raised
	0.55, # strike
	1.1, # recovery
]

const PHASE_NAMES := {
	0: "Ready",
	1: "Anticipation",
	4: "Sword raised",
	7: "Main slash",
}


static func source_path() -> String:
	for p in SOURCE_CANDIDATES:
		if ResourceLoader.exists(p):
			return p
	return ""


static func create_pirate_frame(atlas: Texture2D, source_index: int, tw: int, th: int) -> AtlasTexture:
	var row: int = int(source_index / 3)
	var column: int = int(source_index % 3)
	var sx := float(tw) / 1024.0
	var sy := float(th) / 1536.0
	var left: int = int(round(X_BOUNDS[column] * sx))
	var right: int = int(round(X_BOUNDS[column + 1] * sx))
	var top: int = int(round(Y_BOUNDS[row] * sy))
	var bottom: int = int(round(Y_BOUNDS[row + 1] * sy))
	var texture := AtlasTexture.new()
	texture.atlas = atlas
	texture.region = Rect2(left, top, right - left, bottom - top)
	return texture


static func build() -> Dictionary:
	## Returns {ok, frames, phases_used, durations_used, source_path, skipped, canvas, trail_frame_indices}
	var path := source_path()
	var empty := {
		"ok": false,
		"frames": SpriteFrames.new(),
		"phases_used": [],
		"durations_used": [],
		"source_path": path,
		"skipped": [2, 3, 5, 6, 8],
		"canvas": Vector2i.ZERO,
		"trail_frame_indices": [],
	}
	if path.is_empty():
		push_warning("PirateAttackFrames: missing 01_Pirate_Attack.png under assets/animations/")
		return empty
	var tex: Texture2D = load(path)
	if tex == null:
		push_warning("PirateAttackFrames: failed to load %s" % path)
		return empty

	var tw := tex.get_width()
	var th := tex.get_height()
	var frames := SpriteFrames.new()
	frames.add_animation("attack")
	frames.set_animation_speed("attack", 12.0)
	frames.set_animation_loop("attack", false)

	var phases_used: Array = []
	var durations_used: Array = []
	var trail_indices: Array = []
	for index in range(PIRATE_FRAME_ORDER.size()):
		var source_index: int = PIRATE_FRAME_ORDER[index]
		var atlas_tex := create_pirate_frame(tex, source_index, tw, th)
		# Bake to shared game canvas so dungeon scale matches walk sprites.
		var baked := _bake_to_game_canvas(atlas_tex, Vector2i(64, 80))
		frames.add_frame("attack", baked, PIRATE_FRAME_DURATIONS[index])
		var pname: String = str(PHASE_NAMES.get(source_index, "Frame%d" % source_index))
		if index == PIRATE_FRAME_ORDER.size() - 1:
			pname = "Recovery"
		phases_used.append("%s (src %d)" % [pname, source_index])
		durations_used.append(PIRATE_FRAME_DURATIONS[index])
		# Strike cell (source 7) is anim index 3.
		if source_index == 7:
			trail_indices.append(index)

	print("[PirateAttackFrames] source=%s curated_order=%s frames=%d" % [
		path, str(PIRATE_FRAME_ORDER), frames.get_frame_count("attack")
	])
	for i in phases_used.size():
		print("[PirateAttackFrames]  anim[%d]: %s dur=%.2f" % [i, phases_used[i], durations_used[i]])

	return {
		"ok": frames.get_frame_count("attack") > 0,
		"frames": frames,
		"phases_used": phases_used,
		"durations_used": durations_used,
		"source_path": path,
		"skipped": [2, 3, 5, 6, 8],
		"canvas": Vector2i(64, 80),
		"trail_frame_indices": trail_indices,
	}


static func _bake_to_game_canvas(tex: Texture2D, game_size: Vector2i) -> Texture2D:
	var img := tex.get_image()
	if img == null:
		return tex
	if img.get_format() != Image.FORMAT_RGBA8:
		img = img.duplicate()
		img.convert(Image.FORMAT_RGBA8)
	var scale_f := float(game_size.y) / float(maxi(1, img.get_height()))
	var nw := maxi(1, int(round(img.get_width() * scale_f)))
	var nh := maxi(1, int(round(img.get_height() * scale_f)))
	img.resize(nw, nh, Image.INTERPOLATE_NEAREST)
	var canvas := Image.create(game_size.x, game_size.y, false, Image.FORMAT_RGBA8)
	canvas.fill(Color(0, 0, 0, 0))
	var dx := int((game_size.x - nw) / 2.0)
	var dy := game_size.y - nh
	canvas.blit_rect(img, Rect2i(0, 0, nw, nh), Vector2i(dx, dy))
	return ImageTexture.create_from_image(canvas)
