extends RefCounted
class_name LibationPirateFrames
## Original Libation Warriors pirate ("Brine") — 64x64 sheet.
## Source art faces RIGHT. Use flip_h for left.


const SHEET_PATH := "res://assets/sprites/libation_warriors/pirate_brine_sheet.png"
const FRAME := 64

const ANIM := {
	"idle": {"row": 0, "frames": 4, "speed": 5.5, "loop": true},
	"walk": {"row": 1, "frames": 6, "speed": 10.0, "loop": true},
	"attack": {"row": 2, "frames": 8, "speed": 14.0, "loop": false},
	"hit": {"row": 3, "frames": 3, "speed": 12.0, "loop": false},
	"victory": {"row": 4, "frames": 4, "speed": 7.0, "loop": false},
}

const SOURCE_FACES_RIGHT := true


static func build_sprite_frames() -> SpriteFrames:
	var tex: Texture2D = load(SHEET_PATH)
	var frames := SpriteFrames.new()
	if tex == null:
		push_error("LibationPirateFrames: missing %s" % SHEET_PATH)
		return frames
	for anim_name in ANIM.keys():
		var info: Dictionary = ANIM[anim_name]
		if frames.has_animation(anim_name):
			frames.remove_animation(anim_name)
		frames.add_animation(anim_name)
		frames.set_animation_speed(anim_name, float(info["speed"]))
		frames.set_animation_loop(anim_name, bool(info["loop"]))
		var row: int = int(info["row"])
		for col in range(int(info["frames"])):
			var atlas := AtlasTexture.new()
			atlas.atlas = tex
			atlas.region = Rect2(col * FRAME, row * FRAME, FRAME, FRAME)
			frames.add_frame(anim_name, atlas, 1.0)
	return frames


static func apply_facing(sprite: AnimatedSprite2D, facing_right: bool) -> void:
	sprite.flip_h = SOURCE_FACES_RIGHT != facing_right
	sprite.scale = Vector2(absf(sprite.scale.x), absf(sprite.scale.y))
