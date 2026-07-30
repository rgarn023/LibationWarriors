extends Node2D
## Isolated Pirate attack-frame test.
## Uses ONLY res://assets/animations/01_Pirate_Attack.png
## No slash FX. No contact sheet. No combat systems.


@onready var idle_sprite: Sprite2D = $IdleSprite
@onready var attack_sprite: AnimatedSprite2D = $AttackSprite
@onready var frame_label: Label = $FrameLabel
@onready var instructions_label: Label = $InstructionsLabel

const ATTACK_PATH := "res://assets/animations/01_Pirate_Attack.png"
const IDLE_PATH := "res://assets/sprites/pirate.png"

const X_BOUNDS := [0, 341, 683, 1024]
const Y_BOUNDS := [0, 512, 1024, 1536]

# Duration multipliers used with an animation speed of 10 FPS.
# The strike frames are quicker than the wind-up and recovery.
const FRAME_DURATIONS := [
	1.0,
	1.0,
	0.9,
	0.8,
	0.6,
	0.5,
	0.7,
	0.9,
	1.1,
]

var attack_active := false
var attack_texture: Texture2D
var _frame_hashes: Array = []
var _pose_changed := false


func _ready() -> void:
	if not ResourceLoader.exists(ATTACK_PATH):
		instructions_label.text = "MISSING: %s — copy the Pirate attack sheet there" % ATTACK_PATH
		frame_label.text = "ERROR: attack sheet missing"
		push_error("AttackAnimationTest: missing %s" % ATTACK_PATH)
		print("ERROR: Pirate attack sheet not found at ", ATTACK_PATH)
		return

	attack_texture = load(ATTACK_PATH)
	print("Loaded attack texture size: ", attack_texture.get_width(), "x", attack_texture.get_height())

	_build_attack_animation()
	_verify_regions_differ()

	attack_sprite.visible = false
	attack_sprite.stop()
	attack_sprite.frame = 0
	attack_sprite.centered = true
	attack_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	idle_sprite.visible = true
	idle_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if ResourceLoader.exists(IDLE_PATH) and idle_sprite.texture == null:
		idle_sprite.texture = load(IDLE_PATH)

	# The two visual nodes must occupy the exact same origin.
	attack_sprite.position = idle_sprite.position

	# Match visible height of IdleSprite. Do NOT alter AtlasTexture regions.
	var idle_h := 80.0 * absf(idle_sprite.scale.y)
	if idle_sprite.texture != null:
		idle_h = float(idle_sprite.texture.get_height()) * absf(idle_sprite.scale.y)
	var attack_cell_h := 512.0
	var s := idle_h / attack_cell_h
	attack_sprite.scale = Vector2(s, s)
	print("AttackSprite.scale set to ", attack_sprite.scale)

	instructions_label.text = "Press Space to test the Pirate attack"
	frame_label.text = "Idle"

	attack_sprite.frame_changed.connect(_on_attack_frame_changed)
	attack_sprite.animation_finished.connect(_on_attack_animation_finished)

	print("Pirate attack frame count: ",
		attack_sprite.sprite_frames.get_frame_count("attack")
	)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE):
		start_attack()


func start_attack() -> void:
	if attack_texture == null:
		print("Attack ignored — attack texture missing.")
		return
	if attack_active:
		print("Attack ignored because an attack is already active.")
		return

	attack_active = true
	_pose_changed = false

	idle_sprite.visible = false
	attack_sprite.visible = true
	attack_sprite.frame = 0
	attack_sprite.play("attack")

	frame_label.text = "Attack frame: 0"
	print("Pirate attack started.")
	print("Displaying Pirate attack frame: 0")


func _build_attack_animation() -> void:
	var frames := SpriteFrames.new()

	frames.add_animation("attack")
	frames.set_animation_loop("attack", false)
	frames.set_animation_speed("attack", 10.0)

	var duration_index := 0

	for row in range(3):
		for column in range(3):
			var left: int = X_BOUNDS[column]
			var right: int = X_BOUNDS[column + 1]
			var top: int = Y_BOUNDS[row]
			var bottom: int = Y_BOUNDS[row + 1]

			var atlas_texture := AtlasTexture.new()
			atlas_texture.atlas = attack_texture
			atlas_texture.region = Rect2(
				left,
				top,
				right - left,
				bottom - top
			)

			frames.add_frame(
				"attack",
				atlas_texture,
				FRAME_DURATIONS[duration_index]
			)

			print("Region frame %d: Rect2(%d, %d, %d, %d)" % [
				duration_index, left, top, right - left, bottom - top
			])
			duration_index += 1

	attack_sprite.sprite_frames = frames


func _verify_regions_differ() -> void:
	## Hash each atlas cell. If all hashes match, regions are wrong or art is identical.
	_frame_hashes.clear()
	var img := attack_texture.get_image()
	if img == null:
		print("WARNING: could not read attack texture pixels for hash check")
		return
	if img.get_format() != Image.FORMAT_RGBA8:
		img = img.duplicate()
		img.convert(Image.FORMAT_RGBA8)
	var idx := 0
	for row in range(3):
		for column in range(3):
			var left: int = X_BOUNDS[column]
			var right: int = X_BOUNDS[column + 1]
			var top: int = Y_BOUNDS[row]
			var bottom: int = Y_BOUNDS[row + 1]
			var cell := img.get_region(Rect2i(left, top, right - left, bottom - top))
			var h := _simple_hash(cell)
			_frame_hashes.append(h)
			print("Frame %d pixel-hash: %s" % [idx, h])
			idx += 1
	var unique := {}
	for h2 in _frame_hashes:
		unique[h2] = true
	print("Unique frame hashes: ", unique.size(), " / ", _frame_hashes.size())
	if unique.size() <= 1:
		print("ERROR: AtlasTexture regions appear incorrect — all 9 cells look identical.")
	elif unique.size() < _frame_hashes.size():
		print("WARNING: some attack frames share identical pixel content.")
	else:
		print("OK: all 9 attack regions have distinct pixel content.")


func _simple_hash(cell: Image) -> String:
	var total := 0
	var step_x := maxi(1, int(cell.get_width() / 16))
	var step_y := maxi(1, int(cell.get_height() / 16))
	for y in range(0, cell.get_height(), step_y):
		for x in range(0, cell.get_width(), step_x):
			var c := cell.get_pixel(x, y)
			total = (total * 33 + int(c.r * 255) + int(c.g * 255) * 3 + int(c.b * 255) * 7 + int(c.a * 255) * 11) % 1000000007
	return "%08d" % total


func _on_attack_frame_changed() -> void:
	if not attack_active:
		return

	frame_label.text = "Attack frame: %d" % attack_sprite.frame
	print("Displaying Pirate attack frame: ", attack_sprite.frame)
	if attack_sprite.frame > 0:
		_pose_changed = true


func _on_attack_animation_finished() -> void:
	if attack_sprite.animation != "attack":
		return

	print("Pirate attack animation finished.")
	print("Pose visibly changed across frames: ", _pose_changed)
	if _frame_hashes.size() == 9:
		var unique := {}
		for h in _frame_hashes:
			unique[h] = true
		if unique.size() <= 1:
			print("RESULT: frame index advanced but artwork did not change — AtlasTexture regions incorrect or sheet is static.")
		else:
			print("RESULT: frame artwork differs across regions — character pose should visibly change.")

	attack_active = false
	attack_sprite.stop()
	attack_sprite.visible = false
	idle_sprite.visible = true
	frame_label.text = "Idle"
