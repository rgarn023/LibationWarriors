extends AnimatedSprite2D
class_name AnimatedCharacter
## Reusable pixel-art character player.
## - Builds SpriteFrames from CharacterAnimationData
## - Space / play_attack() plays attack once
## - animation_finished → returns to idle
##
## Attach to an AnimatedSprite2D (this script IS the AnimatedSprite2D).


signal attack_started
signal attack_finished
signal character_changed(character_name: String)

@export var starting_character: String = "Samurai"
## If true and the attack PNG is missing, idle sheet is used as a stand-in so wiring still works.
@export var fallback_attack_to_idle_sheet: bool = true

var _data: CharacterAnimationData
var _attacking: bool = false


func _ready() -> void:
	# Pixel-perfect: never bilinear-filter character art.
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Stable feet when frames share the same canvas size.
	centered = true
	animation_finished.connect(_on_animation_finished)
	set_character(starting_character)


func set_character(character_name: String) -> void:
	_data = CharacterAnimationLibrary.get_data(character_name)
	_apply_data(_data)
	character_changed.emit(_data.character_name)


func get_character_name() -> String:
	return _data.character_name if _data else ""


func cycle_next_character() -> void:
	var names := CharacterAnimationLibrary.all_names()
	if names.is_empty():
		return
	var idx := 0
	for i in names.size():
		if str(names[i]) == get_character_name():
			idx = i
			break
	idx = (idx + 1) % names.size()
	set_character(str(names[idx]))


func _apply_data(data: CharacterAnimationData) -> void:
	if data == null:
		return
	_attacking = false

	# Clone so we can safely rewrite texture_path for fallback without mutating the library.
	var cfg := data.duplicate(true) as CharacterAnimationData
	if fallback_attack_to_idle_sheet and not ResourceLoader.exists(cfg.texture_path):
		push_warning(
			"Attack sheet missing for %s (%s) — using idle sheet until you drop the PNG in assets/sprites/attacks/"
			% [cfg.character_name, cfg.texture_path]
		)
		cfg.texture_path = cfg.idle_texture_path
		# Walk sheets are 4×1 @ 64×80 — keep attack as a one-shot pass over those frames.
		cfg.frame_width = cfg.idle_frame_width if cfg.idle_frame_width > 0 else 64
		cfg.frame_height = cfg.idle_frame_height if cfg.idle_frame_height > 0 else 80
		cfg.columns = cfg.idle_columns if cfg.idle_columns > 0 else 4
		cfg.rows = cfg.idle_rows if cfg.idle_rows > 0 else 1
		cfg.total_frames = cfg.idle_total_frames if cfg.idle_total_frames > 0 else 4
		cfg.attack_loop = false

	sprite_frames = SpriteFramesBuilder.build(cfg)
	centered = cfg.centered
	offset = cfg.sprite_offset
	# Integer-ish scale keeps pixels crisp (prefer 1, 2, 3…).
	var s := cfg.display_scale
	scale = Vector2(s, s)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_play_idle()


func is_attacking() -> bool:
	return _attacking


func play_attack() -> void:
	if _attacking:
		return
	if sprite_frames == null or not sprite_frames.has_animation(SpriteFramesBuilder.ANIM_ATTACK):
		return
	_attacking = true
	# One-shot: library / builder already set loop=false on "attack".
	play(SpriteFramesBuilder.ANIM_ATTACK)
	attack_started.emit()


func _play_idle() -> void:
	_attacking = false
	if sprite_frames and sprite_frames.has_animation(SpriteFramesBuilder.ANIM_IDLE):
		play(SpriteFramesBuilder.ANIM_IDLE)


func _on_animation_finished() -> void:
	# AnimatedSprite2D emits when a non-looping animation reaches the end.
	if animation == SpriteFramesBuilder.ANIM_ATTACK:
		_attacking = false
		attack_finished.emit()
		_play_idle()
