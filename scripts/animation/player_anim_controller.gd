extends AnimatedSprite2D
class_name PlayerAnimController
## Player sprite state machine for Adventure.
## ATTACKING plays the full attack animation once; movement/idle cannot interrupt it.


enum PlayerState {
	IDLE,
	MOVING,
	ATTACKING,
}

signal attack_started
signal attack_finished
signal state_changed(new_state: int)

@export var debug_attacks: bool = true

var state: int = PlayerState.IDLE
var facing: Vector2 = Vector2.LEFT

var _trail_frame_indices: Array = []
var _trail_spawned: bool = false
var _last_attack_frame: int = -1
var _attack_locked_pos: Vector2 = Vector2.ZERO
var _base_modulate: Color = Color.WHITE
var _display_scale: float = 1.0
var _body: CharacterBody2D


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	centered = true
	animation_finished.connect(_on_animation_finished)
	frame_changed.connect(_on_frame_changed)


func configure(body: CharacterBody2D, sprite_frames: SpriteFrames, display_scale: float, trail_frames: Array = [], modulate_col: Color = Color.WHITE) -> void:
	_body = body
	self.sprite_frames = sprite_frames
	_display_scale = display_scale
	scale = Vector2(display_scale, display_scale)
	_trail_frame_indices = trail_frames.duplicate()
	_base_modulate = modulate_col
	modulate = modulate_col
	centered = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	offset = Vector2.ZERO
	position = Vector2.ZERO
	_set_state(PlayerState.IDLE)
	_play_checked("idle")


func is_attacking() -> bool:
	return state == PlayerState.ATTACKING


func can_move() -> bool:
	return state != PlayerState.ATTACKING


func set_facing(dir: Vector2) -> void:
	if state == PlayerState.ATTACKING:
		return
	facing = WeaponData.cardinal(dir)
	flip_h = WeaponData.flip_h_for(facing)


func set_moving(moving: bool) -> void:
	if state == PlayerState.ATTACKING:
		if debug_attacks and moving:
			print("[PlayerAnim] BLOCKED move-state while ATTACKING")
		return
	if moving:
		_set_state(PlayerState.MOVING)
		# Walk sheets use idle animation frames as a simple walk cycle.
		if animation != "idle":
			_play_checked("idle")
	else:
		_set_state(PlayerState.IDLE)
		_play_checked("idle")


func start_attack() -> void:
	if state == PlayerState.ATTACKING:
		if debug_attacks:
			print("[PlayerAnim] IGNORE attack — already ATTACKING (no restart)")
		return
	if sprite_frames == null or not sprite_frames.has_animation("attack"):
		if debug_attacks:
			print("[PlayerAnim] NO attack animation available")
		return
	if debug_attacks:
		print("[PlayerAnim] ATTACKING begins")
	_set_state(PlayerState.ATTACKING)
	_trail_spawned = false
	_last_attack_frame = -1
	if _body:
		_body.velocity = Vector2.ZERO
		_attack_locked_pos = _body.position
	# Fixed local sprite position for the whole attack.
	position = Vector2.ZERO
	offset = Vector2.ZERO
	rotation = 0.0
	scale = Vector2(_display_scale, _display_scale)
	frame = 0
	play("attack")
	attack_started.emit()


func _on_animation_finished() -> void:
	if debug_attacks:
		print("[PlayerAnim] animation_finished anim=%s" % str(animation))
	if animation == "attack":
		_set_state(PlayerState.IDLE)
		_play_checked("idle")
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
		print("[PlayerAnim] attack frame -> %d" % frame)


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
		position = Vector2.ZERO
		offset = Vector2.ZERO
