extends CharacterBody2D
## Real-time dungeon foe with chase AI and swipe attack animation.

signal died(enemy: CharacterBody2D, is_boss: bool, world_pos: Vector2)

var warrior: Warrior
var is_boss: bool = false
var speed: float = 38.0
var contact_damage: int = 8
var invuln: float = 0.0
var knockback: Vector2 = Vector2.ZERO
var _player: CharacterBody2D
var _anim_t: float = 0.0
var _frame: int = 0
var _sprite: Sprite2D
var _sheet: Texture2D
var _alive: bool = true
var _hurt_flash: float = 0.0
var _ai_dir: Vector2 = Vector2.ZERO
var _ai_timer: float = 0.0
var _attack_cd: float = 0.0
var _attack_anim: float = 0.0
var _world: Node2D


func setup(data: Dictionary, player: CharacterBody2D, boss: bool) -> void:
	_player = player
	is_boss = boss
	warrior = Warrior.new(data)
	warrior.reset_hp()
	contact_damage = maxi(4, int(warrior.regular_power * (1.35 if boss else 0.85)))
	speed = 28.0 if boss else 42.0
	collision_layer = 2
	collision_mask = 1
	_world = get_parent() as Node2D
	_sprite = Sprite2D.new()
	_sprite.centered = true
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_sprite)
	if ResourceLoader.exists(warrior.sheet_path()):
		_sheet = load(warrior.sheet_path())
		_sprite.texture = _sheet
		_sprite.region_enabled = true
		_sprite.region_rect = Rect2(0, 0, 64, 80)
	elif ResourceLoader.exists(warrior.sprite_path()):
		_sprite.texture = load(warrior.sprite_path())
	_sprite.modulate = warrior.display_modulate()
	var sc := 0.55 if boss else 0.42
	_sprite.scale = Vector2(sc, sc)
	if boss:
		_sprite.modulate = Color(1.0, 0.85, 0.85, 1.0)
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(14, 16) if not boss else Vector2(18, 20)
	cs.shape = rect
	add_child(cs)
	# Shadow via sprite (matches character render path on mobile)
	var sh_img := Image.create(16 if not boss else 22, 5 if not boss else 6, false, Image.FORMAT_RGBA8)
	sh_img.fill(Color(0, 0, 0, 0.35))
	var sh := Sprite2D.new()
	sh.z_index = -1
	sh.centered = true
	sh.position = Vector2(0, 12)
	sh.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sh.texture = ImageTexture.create_from_image(sh_img)
	add_child(sh)
	var gear := Node2D.new()
	gear.set_script(load("res://scripts/adventure/warrior_gear.gd"))
	add_child(gear)
	gear.call("configure", warrior, sc, true)


func _physics_process(delta: float) -> void:
	if not _alive:
		return
	if invuln > 0.0:
		invuln -= delta
	if _attack_cd > 0.0:
		_attack_cd -= delta
	if _hurt_flash > 0.0:
		_hurt_flash -= delta
		_sprite.modulate.a = 0.45 if int(_hurt_flash * 20.0) % 2 == 0 else 1.0
	else:
		_sprite.modulate.a = 1.0

	if _attack_anim > 0.0:
		_attack_anim -= delta
		var t := clampf(_attack_anim / 0.2, 0.0, 1.0)
		var face := Vector2.LEFT
		if _player != null and is_instance_valid(_player):
			face = (_player.global_position - global_position).normalized()
		_sprite.offset = face * (5.0 * (1.0 - absf(t - 0.5) * 2.0))
		_sprite.rotation = face.x * 0.2
		if _attack_anim <= 0.0:
			_sprite.offset = Vector2.ZERO
			_sprite.rotation = 0.0

	_anim_t += delta
	if _anim_t >= 0.14 and _attack_anim <= 0.0:
		_anim_t = 0.0
		_frame = (_frame + 1) % 4
		_update_frame()

	if knockback.length() > 4.0:
		velocity = knockback
		knockback = knockback.move_toward(Vector2.ZERO, 280.0 * delta)
	else:
		knockback = Vector2.ZERO
		_ai_timer -= delta
		if _ai_timer <= 0.0:
			_ai_timer = randf_range(0.35, 0.9)
			if _player != null and is_instance_valid(_player):
				var to_p: Vector2 = _player.global_position - global_position
				if to_p.length() < 110.0 or is_boss:
					_ai_dir = to_p.normalized()
				else:
					_ai_dir = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
			else:
				_ai_dir = Vector2.ZERO
		velocity = _ai_dir * (speed * (0.45 if _attack_anim > 0.0 else 1.0))
	move_and_slide()
	position.x = clampf(position.x, 28.0, 228.0)
	position.y = clampf(position.y, 28.0, 148.0)

	# Wind-up swipe when close to player
	if _player != null and is_instance_valid(_player) and _attack_cd <= 0.0:
		if global_position.distance_to(_player.global_position) < 20.0:
			_play_attack_swipe()


func _play_attack_swipe() -> void:
	_attack_cd = 0.85 if is_boss else 1.05
	_attack_anim = 0.2
	var face := Vector2.LEFT
	if _player != null and is_instance_valid(_player):
		face = (_player.global_position - global_position).normalized()
	var parent_node := _world if _world != null else get_parent()
	if parent_node is Node2D:
		CombatFx.spawn_enemy_swipe(parent_node as Node2D, position + face * 10.0, face, warrior.tint_accent)


func _update_frame() -> void:
	if _sheet == null or not _sprite.region_enabled:
		return
	_sprite.region_rect = Rect2(_frame * 64, 0, 64, 80)
	if _ai_dir.x < -0.2:
		_sprite.flip_h = true
	elif _ai_dir.x > 0.2:
		_sprite.flip_h = false


func take_hit(amount: int, from_pos: Vector2) -> void:
	if not _alive or invuln > 0.0:
		return
	warrior.current_hp = maxi(0, warrior.current_hp - amount)
	invuln = 0.28
	_hurt_flash = 0.35
	var dir := (global_position - from_pos).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	knockback = dir * (140.0 if is_boss else 180.0)
	if warrior.current_hp <= 0:
		_alive = false
		died.emit(self, is_boss, global_position)
		queue_free()


func is_alive_enemy() -> bool:
	return _alive
