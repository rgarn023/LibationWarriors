extends AnimatedSprite2D
class_name PlayerAnimController
## Adventure animation state machine.
## Direction-specific animation names are preferred when present:
## idle_down/walk_down/attack_down/special_attack_down/hit_down/defeated_down, etc.
## Legacy Pirate assets fall back to the existing side-facing idle/attack frames.

enum PlayerState {
	IDLE,
	WALK,
	ATTACK,
	SPECIAL_ATTACK,
	HIT,
	DEFEATED,
}

signal attack_started
signal attack_finished
signal state_changed(new_state: int)

const IDLE_SOURCE_FACES_RIGHT := false
const ATTACK_SOURCE_FACES_RIGHT := false

@export var debug_attacks: bool = true
@export var attack_source_offset := Vector2(-12.0, 0.0)

var state: int = PlayerState.IDLE
var facing: Vector2 = Vector2.LEFT
var facing_right := false
var attack_facing_right := false

var _trail_frame_indices: Array = []
var _last_attack_frame := -1
var _attack_locked_pos := Vector2.ZERO
var _base_modulate := Color.WHITE
var _display_scale := 1.0
var _body: CharacterBody2D
var _idle_local_pos := Vector2.ZERO
var _active_attack_animation := ""
var _hit_generation := 0


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	centered = true
	scale = Vector2(absf(scale.x), absf(scale.y))
	if not animation_finished.is_connected(_on_animation_finished):
		animation_finished.connect(_on_animation_finished)
	if not frame_changed.is_connected(_on_frame_changed):
		frame_changed.connect(_on_frame_changed)


func configure(
	body: CharacterBody2D,
	frames: SpriteFrames,
	display_scale: float,
	trail_frames: Array = [],
	modulate_col: Color = Color.WHITE
) -> void:
	_body = body
	sprite_frames = frames
	_display_scale = absf(display_scale)
	scale = Vector2(_display_scale, _display_scale)
	_trail_frame_indices = trail_frames.duplicate()
	_base_modulate = modulate_col
	modulate = modulate_col
	centered = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	offset = Vector2.ZERO
	position = Vector2.ZERO
	_idle_local_pos = Vector2.ZERO
	_set_state(PlayerState.IDLE)
	_play_locomotion("idle")
	_apply_idle_facing()


func is_attacking() -> bool:
	return state == PlayerState.ATTACK or state == PlayerState.SPECIAL_ATTACK


func is_defeated() -> bool:
	return state == PlayerState.DEFEATED


func can_move() -> bool:
	return state == PlayerState.IDLE or state == PlayerState.WALK


func set_facing(dir: Vector2) -> void:
	if is_attacking() or state == PlayerState.HIT or state == PlayerState.DEFEATED:
		return
	facing = WeaponData.cardinal(dir)
	if facing.x > 0.0:
		facing_right = true
	elif facing.x < 0.0:
		facing_right = false
	_apply_idle_facing()


func set_moving(moving: bool) -> void:
	if not can_move():
		return
	if moving:
		_set_state(PlayerState.WALK)
		_play_locomotion("walk")
	else:
		_set_state(PlayerState.IDLE)
		_play_locomotion("idle")
	_apply_idle_facing()


func has_attack_animation(is_special: bool = false) -> bool:
	return not _resolve_attack_animation(is_special).is_empty()


func start_attack(is_special: bool = false) -> bool:
	if is_attacking() or state == PlayerState.HIT or state == PlayerState.DEFEATED:
		if debug_attacks:
			print("[PlayerAnim] IGNORE attack — state=%s" % state_name())
		return false
	var anim := _resolve_attack_animation(is_special)
	if anim.is_empty():
		if debug_attacks:
			print("[PlayerAnim] no attack animation for %s / %s" % [state_name(), _direction_suffix()])
		return false

	_set_state(PlayerState.SPECIAL_ATTACK if is_special else PlayerState.ATTACK)
	attack_facing_right = facing_right
	_last_attack_frame = -1
	_active_attack_animation = anim
	if _body:
		_body.velocity = Vector2.ZERO
		_attack_locked_pos = _body.position

	_apply_attack_facing(anim)
	rotation = 0.0
	scale = Vector2(absf(_display_scale), absf(_display_scale))
	frame = 0
	play(anim)
	if debug_attacks:
		print("[PlayerAnim] attack=%s dir=%s flip_h=%s" % [anim, _direction_suffix(), str(flip_h)])
	attack_started.emit()
	return true


func play_hit() -> void:
	if state == PlayerState.DEFEATED:
		return
	_interrupt_attack_if_needed()
	_hit_generation += 1
	var generation := _hit_generation
	_set_state(PlayerState.HIT)
	var anim := _resolve_directional("hit")
	if not anim.is_empty():
		_apply_directional_flip(anim, false)
		frame = 0
		play(anim)
		return
	# Legacy art has no hit strip yet. Preserve a real HIT state/timing contract
	# without fabricating frames; the dungeon hurt flash supplies feedback.
	stop()
	get_tree().create_timer(0.12).timeout.connect(func():
		if generation == _hit_generation and state == PlayerState.HIT:
			_finish_to_idle()
	)


func play_defeated() -> void:
	if state == PlayerState.DEFEATED:
		return
	_interrupt_attack_if_needed()
	_hit_generation += 1
	_set_state(PlayerState.DEFEATED)
	if _body:
		_body.velocity = Vector2.ZERO
	var anim := _resolve_directional("defeated")
	if not anim.is_empty():
		_apply_directional_flip(anim, false)
		frame = 0
		play(anim)
	else:
		# No fake defeat animation. Hold the current authored frame until the
		# scene transitions; production art should provide defeated_<direction>.
		stop()


func state_name() -> String:
	match state:
		PlayerState.IDLE: return "IDLE"
		PlayerState.WALK: return "WALK"
		PlayerState.ATTACK: return "ATTACK"
		PlayerState.SPECIAL_ATTACK: return "SPECIAL_ATTACK"
		PlayerState.HIT: return "HIT"
		PlayerState.DEFEATED: return "DEFEATED"
	return "UNKNOWN"


func _direction_suffix() -> String:
	var dir := WeaponData.cardinal(facing)
	if dir == Vector2.UP:
		return "up"
	if dir == Vector2.DOWN:
		return "down"
	if dir == Vector2.RIGHT:
		return "right"
	return "left"


func _resolve_directional(base: String) -> String:
	if sprite_frames == null:
		return ""
	var exact := "%s_%s" % [base, _direction_suffix()]
	if sprite_frames.has_animation(exact) and sprite_frames.get_frame_count(exact) > 0:
		return exact
	if sprite_frames.has_animation(base) and sprite_frames.get_frame_count(base) > 0:
		return base
	return ""


func _resolve_attack_animation(is_special: bool) -> String:
	if sprite_frames == null:
		return ""
	if is_special:
		var special := _resolve_directional("special_attack")
		if not special.is_empty():
			return special
	# A special may intentionally reuse a regular authored body attack until a
	# dedicated special strip exists; gameplay effects remain separate.
	return _resolve_directional("attack")


func _play_locomotion(base: String) -> void:
	if sprite_frames == null:
		return
	var anim := _resolve_directional(base)
	if anim.is_empty() and base == "walk":
		anim = _resolve_directional("idle")
	if anim.is_empty():
		return
	if animation != anim or not is_playing():
		play(anim)


func _apply_idle_facing() -> void:
	var dir_anim := str(animation)
	_apply_directional_flip(dir_anim, true)
	scale = Vector2(absf(scale.x), absf(scale.y))
	position = _idle_local_pos
	offset = Vector2.ZERO


func _apply_attack_facing(anim: String) -> void:
	_apply_directional_flip(anim, false)
	scale = Vector2(absf(_display_scale), absf(_display_scale))
	var mirrored_offset_x := attack_source_offset.x
	if flip_h:
		mirrored_offset_x = -attack_source_offset.x
	position = _idle_local_pos + Vector2(mirrored_offset_x, attack_source_offset.y)
	offset = Vector2.ZERO


func _apply_directional_flip(anim: String, idle: bool) -> void:
	# Authored direction-specific strips are already facing the requested way.
	if anim.ends_with("_up") or anim.ends_with("_down") or anim.ends_with("_left") or anim.ends_with("_right"):
		flip_h = false
		return
	# Legacy side-facing sheets use horizontal mirroring only.
	var source_right := IDLE_SOURCE_FACES_RIGHT if idle else ATTACK_SOURCE_FACES_RIGHT
	flip_h = source_right != facing_right


func _on_animation_finished() -> void:
	if debug_attacks:
		print("[PlayerAnim] animation_finished anim=%s state=%s" % [str(animation), state_name()])
	if is_attacking():
		_finish_to_idle()
		attack_finished.emit()
	elif state == PlayerState.HIT:
		_finish_to_idle()
	elif state == PlayerState.DEFEATED:
		stop()


func _on_frame_changed() -> void:
	if not is_attacking():
		return
	if animation != _active_attack_animation:
		return
	if frame == _last_attack_frame:
		return
	_last_attack_frame = frame
	if debug_attacks:
		print("[PlayerAnim] attack frame -> %d | anim=%s" % [frame, animation])


func _interrupt_attack_if_needed() -> void:
	if not is_attacking():
		return
	stop()
	_active_attack_animation = ""
	attack_finished.emit()


func _finish_to_idle() -> void:
	stop()
	_active_attack_animation = ""
	_set_state(PlayerState.IDLE)
	_play_locomotion("idle")
	_apply_idle_facing()


func _set_state(next_state: int) -> void:
	if state == next_state:
		return
	state = next_state
	state_changed.emit(next_state)


func lock_body_position_if_attacking() -> void:
	if is_attacking() and _body:
		_body.velocity = Vector2.ZERO
		_body.position = _attack_locked_pos
