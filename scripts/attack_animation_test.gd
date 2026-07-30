extends Node2D
## Isolated Pirate attack test — curated frames + flip_h facing.
## Source art faces LEFT. Facing right => attack_sprite.flip_h = true.
## No slash FX. No scale.x mirroring.


enum PlayerState {
	IDLE,
	MOVING,
	ATTACKING,
}

const IDLE_SOURCE_FACES_RIGHT := false
const ATTACK_SOURCE_FACES_RIGHT := false

const ATTACK_PATH := "res://assets/animations/01_Pirate_Attack.png"
const IDLE_PATH := "res://assets/sprites/pirate.png"

const X_BOUNDS := [0, 341, 683, 1024]
const Y_BOUNDS := [0, 512, 1024, 1536]

## Curated usable cells only (exclude 2, 3, 5, 6, 8).
const PIRATE_FRAME_ORDER := [
	0, # ready
	1, # anticipation
	4, # sword raised / swing begins
	7, # main slash and impact
	0, # recovery to ready
]

const PIRATE_FRAME_DURATIONS := [
	1.2, # ready
	1.0, # anticipation
	0.8, # sword raised
	0.55, # strike
	1.1, # recovery
]

@onready var idle_sprite: Sprite2D = $IdleSprite
@onready var attack_sprite: AnimatedSprite2D = $AttackSprite
@onready var attack_hitbox: Area2D = $AttackHitbox
@onready var frame_label: Label = $FrameLabel
@onready var instructions_label: Label = $InstructionsLabel

@export var attack_source_offset := Vector2(-12.0, 0.0)
@export var attack_hitbox_distance := 32.0

var state: int = PlayerState.IDLE
var facing_right: bool = true
var attack_facing_right: bool = true
var input_direction: Vector2 = Vector2.ZERO
var velocity: Vector2 = Vector2.ZERO

var _attack_texture: Texture2D
var _played_source_frames: Array = []


func _ready() -> void:
	# Force positive scales on all visual nodes — never scale.x = -1.
	scale = Vector2(absf(scale.x), absf(scale.y))
	idle_sprite.scale = Vector2(absf(idle_sprite.scale.x), absf(idle_sprite.scale.y))
	attack_sprite.scale = Vector2(absf(attack_sprite.scale.x), absf(attack_sprite.scale.y))

	idle_sprite.centered = true
	idle_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if ResourceLoader.exists(IDLE_PATH):
		idle_sprite.texture = load(IDLE_PATH)

	attack_sprite.centered = true
	attack_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	attack_sprite.visible = false
	attack_sprite.stop()

	if not ResourceLoader.exists(ATTACK_PATH):
		instructions_label.text = "MISSING: %s" % ATTACK_PATH
		frame_label.text = "ERROR: attack sheet missing"
		push_error("Missing Pirate attack sheet: %s" % ATTACK_PATH)
		print("ERROR: place 01_Pirate_Attack.png at assets/animations/")
		return

	_attack_texture = load(ATTACK_PATH)
	print("Loaded ", ATTACK_PATH, " size=", _attack_texture.get_width(), "x", _attack_texture.get_height())
	_build_attack_animation()

	# Match idle visible height; do not alter AtlasTexture regions.
	var idle_h := 80.0 * absf(idle_sprite.scale.y)
	if idle_sprite.texture != null:
		idle_h = float(idle_sprite.texture.get_height()) * absf(idle_sprite.scale.y)
	var s := idle_h / 512.0
	attack_sprite.scale = Vector2(absf(s), absf(s))
	print("AttackSprite.scale=", attack_sprite.scale, " (parent scales positive)")

	attack_sprite.position = idle_sprite.position
	attack_sprite.frame_changed.connect(_on_attack_frame_changed)
	attack_sprite.animation_finished.connect(_on_attack_animation_finished)

	_apply_idle_facing()
	_position_attack_hitbox()
	if attack_hitbox:
		attack_hitbox.monitoring = false
		attack_hitbox.monitorable = false

	instructions_label.text = "A/D or arrows: face   Space: attack (frames 0,1,4,7,0)"
	frame_label.text = "Idle | facing_right=%s flip_h=%s" % [facing_right, idle_sprite.flip_h]
	print("Pirate attack animation frame count: ",
		attack_sprite.sprite_frames.get_frame_count("attack"))
	print("Source frame order: ", PIRATE_FRAME_ORDER)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE):
		start_attack()
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	input_direction = Vector2.ZERO
	if Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A):
		input_direction.x -= 1.0
	if Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D):
		input_direction.x += 1.0

	# Only update facing while NOT attacking.
	if state != PlayerState.ATTACKING:
		if input_direction.x > 0.0:
			facing_right = true
		elif input_direction.x < 0.0:
			facing_right = false
		_apply_idle_facing()
		if state != PlayerState.ATTACKING:
			state = PlayerState.MOVING if input_direction.x != 0.0 else PlayerState.IDLE
		frame_label.text = "Idle | facing_right=%s flip_h=%s" % [facing_right, idle_sprite.flip_h]


func start_attack() -> void:
	if state == PlayerState.ATTACKING:
		print("Attack ignored — already ATTACKING")
		return
	if _attack_texture == null or attack_sprite.sprite_frames == null:
		print("Attack ignored — attack frames not built")
		return

	state = PlayerState.ATTACKING
	attack_facing_right = facing_right
	velocity = Vector2.ZERO
	_played_source_frames.clear()

	_apply_attack_facing()
	_position_attack_hitbox()

	idle_sprite.visible = false
	attack_sprite.visible = true
	attack_sprite.frame = 0
	attack_sprite.play("attack")

	print(
		"Attack started | facing_right=",
		attack_facing_right,
		" | flip_h=",
		attack_sprite.flip_h
	)
	print("Displaying source frame: ", PIRATE_FRAME_ORDER[0], " (anim frame 0)")
	frame_label.text = "Attack src=%d flip_h=%s" % [PIRATE_FRAME_ORDER[0], attack_sprite.flip_h]


func _apply_idle_facing() -> void:
	idle_sprite.flip_h = IDLE_SOURCE_FACES_RIGHT != facing_right
	# Keep scale positive — flip_h only.
	idle_sprite.scale = Vector2(absf(idle_sprite.scale.x), absf(idle_sprite.scale.y))


func _apply_attack_facing() -> void:
	attack_sprite.flip_h = ATTACK_SOURCE_FACES_RIGHT != attack_facing_right
	attack_sprite.scale = Vector2(absf(attack_sprite.scale.x), absf(attack_sprite.scale.y))

	var mirrored_offset_x := attack_source_offset.x
	if attack_sprite.flip_h:
		mirrored_offset_x = -attack_source_offset.x
	attack_sprite.position = idle_sprite.position + Vector2(
		mirrored_offset_x,
		attack_source_offset.y
	)


func _position_attack_hitbox() -> void:
	if attack_hitbox == null:
		return
	var direction := 1.0 if attack_facing_right else -1.0
	attack_hitbox.position.x = absf(attack_hitbox_distance) * direction
	attack_hitbox.position.y = 0.0


func create_pirate_frame(source_index: int) -> AtlasTexture:
	var row: int = int(source_index / 3)
	var column: int = source_index % 3
	var left: int = X_BOUNDS[column]
	var right: int = X_BOUNDS[column + 1]
	var top: int = Y_BOUNDS[row]
	var bottom: int = Y_BOUNDS[row + 1]
	var texture := AtlasTexture.new()
	texture.atlas = _attack_texture
	texture.region = Rect2(left, top, right - left, bottom - top)
	return texture


func _build_attack_animation() -> void:
	var frames := SpriteFrames.new()
	frames.add_animation("attack")
	frames.set_animation_loop("attack", false)
	frames.set_animation_speed("attack", 12.0)
	for index in range(PIRATE_FRAME_ORDER.size()):
		var source_index: int = PIRATE_FRAME_ORDER[index]
		frames.add_frame(
			"attack",
			create_pirate_frame(source_index),
			PIRATE_FRAME_DURATIONS[index]
		)
		print("Anim[%d] <- source cell %d region=%s dur=%.2f" % [
			index,
			source_index,
			str(create_pirate_frame(source_index).region),
			PIRATE_FRAME_DURATIONS[index],
		])
	attack_sprite.sprite_frames = frames


func _on_attack_frame_changed() -> void:
	if state != PlayerState.ATTACKING:
		return
	var anim_i := attack_sprite.frame
	var source_i: int = PIRATE_FRAME_ORDER[anim_i] if anim_i < PIRATE_FRAME_ORDER.size() else -1
	_played_source_frames.append(source_i)
	print("Displaying source frame: ", source_i, " (anim frame ", anim_i, ")")
	frame_label.text = "Attack src=%d anim=%d flip_h=%s" % [source_i, anim_i, attack_sprite.flip_h]


func _on_attack_animation_finished() -> void:
	if attack_sprite.animation != "attack":
		return
	print("Pirate attack animation finished. Source sequence: ", _played_source_frames)
	attack_sprite.stop()
	attack_sprite.visible = false
	idle_sprite.visible = true
	state = PlayerState.IDLE
	_apply_idle_facing()
	frame_label.text = "Idle | facing_right=%s flip_h=%s" % [facing_right, idle_sprite.flip_h]
