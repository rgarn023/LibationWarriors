extends AnimatedSprite2D
class_name PlayerAnimController
## Player sprite state machine for Adventure.
## Pirate source art faces LEFT — facing uses flip_h only (never scale.x).


enum PlayerState {
	IDLE,
	MOVING,
	ATTACKING,
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
var facing_right: bool = true
var attack_facing_right: bool = true

var _trail_frame_indices: Array = []
var _trail_spawned: bool = false
var _last_attack_frame: int = -1
var _attack_locked_pos: Vector2 = Vector2.ZERO
var _base_modulate: Color = Color.WHITE
var _display_scale: float = 1.0
var _body: CharacterBody2D
var _idle_local_pos: Vector2 = Vector2.ZERO


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
	sprite_frames: SpriteFrames,
	display_scale: float,
	trail_frames: Array = [],
	modulate_col: Color = Color.WHITE
) -> void:
	_body = body
	self.sprite_frames = sprite_frames
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
	_play_checked("idle")
	_apply_idle_facing()


func is_attacking() -> bool:
	return state == PlayerState.ATTACKING


func can_move() -> bool:
	return state != PlayerState.ATTACKING


func set_facing(dir: Vector2) -> void:
	if state == PlayerState.ATTACKING:
		return
	facing = WeaponData.cardinal(dir)
	if facing.x > 0.0:
		facing_right = true
	elif facing.x < 0.0:
		facing_right = false
	_apply_idle_facing()


func set_moving(moving: bool) -> void:
	if state == PlayerState.ATTACKING:
		if debug_attacks and moving:
			print("[PlayerAnim] BLOCKED move-state while ATTACKING")
		return
	if moving:
		_set_state(PlayerState.MOVING)
		if animation != "idle":
			_play_checked("idle")
	else:
		_set_state(PlayerState.IDLE)
		_play_checked("idle")
	_apply_idle_facing()


func start_attack() -> void:
	if state == PlayerState.ATTACKING:
		if debug_attacks:
			print("[PlayerAnim] IGNORE attack — already ATTACKING (no restart)")
		return
	if sprite_frames == null or not sprite_frames.has_animation("attack"):
		if debug_attacks:
			print("[PlayerAnim] NO attack animation available")
		return
	if sprite_frames.get_frame_count("attack") <= 0:
		if debug_attacks:
			print("[PlayerAnim] EMPTY attack animation")
		return

	state = PlayerState.ATTACKING
	attack_facing_right = facing_right
	_trail_spawned = false
	_last_attack_frame = -1
	if _body:
		_body.velocity = Vector2.ZERO
		_attack_locked_pos = _body.position

	_apply_attack_facing()
	rotation = 0.0
	scale = Vector2(absf(_display_scale), absf(_display_scale))
	frame = 0
	play("attack")
	print(
		"Attack started | facing_right=",
		attack_facing_right,
		" | flip_h=",
		flip_h
	)
	attack_started.emit()


func _apply_idle_facing() -> void:
	flip_h = IDLE_SOURCE_FACES_RIGHT != facing_right
	scale = Vector2(absf(scale.x), absf(scale.y))
	position = _idle_local_pos
	offset = Vector2.ZERO


func _apply_attack_facing() -> void:
	## Lock flip_h for the whole attack; do not change again until finished.
	flip_h = ATTACK_SOURCE_FACES_RIGHT != attack_facing_right
	scale = Vector2(absf(_display_scale), absf(_display_scale))
	var mirrored_offset_x := attack_source_offset.x
	if flip_h:
		mirrored_offset_x = -attack_source_offset.x
	position = _idle_local_pos + Vector2(mirrored_offset_x, attack_source_offset.y)
	offset = Vector2.ZERO


func _on_animation_finished() -> void:
	if debug_attacks:
		print("[PlayerAnim] animation_finished anim=%s" % str(animation))
	if animation != "attack":
		return
	stop()
	_set_state(PlayerState.IDLE)
	_play_checked("idle")
	_apply_idle_facing()
	attack_finished.emit()


func _on_frame_changed() -> void:
	if state != PlayerState.ATTACKING:
		return
	if animation != "attack":
		return
	if frame == _last_attack_frame:
		return
	_last_attack_frame = frame
	if debug_attacks:
		print("[PlayerAnim] attack frame -> %d | flip_h=%s" % [frame, flip_h])


func _play_checked(anim: String) -> void:
	if state == PlayerState.ATTACKING and anim != "attack":
		if debug_attacks:
			print("[PlayerAnim] BLOCKED play('%s') while ATTACKING" % anim)
		return
	if anim == "attack" and state == PlayerState.ATTACKING and is_playing() and animation == "attack":
		if debug_attacks:
			print("[PlayerAnim] BLOCKED restart of attack")
		return
	play(anim)


func _set_state(s: int) -> void:
	if state == s:
		return
	state = s
	state_changed.emit(s)


func lock_body_position_if_attacking() -> void:
	## Call from _physics_process while ATTACKING to keep CharacterBody2D fixed.
	if state == PlayerState.ATTACKING and _body:
		_body.velocity = Vector2.ZERO
		_body.position = _attack_locked_pos
