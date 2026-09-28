extends CharacterBody2D
## Real-time dungeon foe: body attack pose + JRPG sword-arc swing / ranged shots.

signal died(enemy: CharacterBody2D, is_boss: bool, world_pos: Vector2)
signal damaged_player(amount: int, from_pos: Vector2)

const PROJECTILE_SCRIPT := preload("res://scripts/adventure/dungeon_projectile.gd")

enum CombatState {
	IDLE,
	WALK,
	ATTACK,
	SPECIAL_ATTACK,
	HIT,
	DEFEATED,
}

var combat_state := CombatState.IDLE
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
var _facing: Vector2 = Vector2.LEFT
var _ai_timer: float = 0.0
var _attack_cd: float = 0.0
var _attack_style: String = "slash"
var _base_scale: float = 0.42
var _pending_ranged: bool = false
var _strike_done: bool = false
var _attack_anim_t: float = 0.0
var _attack_anim_max: float = 0.28
var _world: Node2D
var _profile: Dictionary = {}
var _sword_arc: Node2D = null


func setup(data: Dictionary, player: CharacterBody2D, boss: bool) -> void:
	_player = player
	is_boss = boss
	warrior = Warrior.new(data)
	warrior.reset_hp()
	_profile = warrior.weapon_profile()
	contact_damage = maxi(4, int(warrior.regular_power * (1.35 if boss else 0.85)))
	speed = 26.0 if boss else (34.0 if warrior.prefers_ranged() else 44.0)
	collision_layer = 2
	collision_mask = 1
	_world = get_parent() as Node2D
	add_to_group("dungeon_enemies")
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
	_base_scale = 0.55 if boss else 0.42
	_sprite.scale = Vector2(_base_scale, _base_scale)
	if boss:
		_sprite.modulate = Color(_sprite.modulate.r, _sprite.modulate.g * 0.9, _sprite.modulate.b * 0.9)
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(14, 16) if not boss else Vector2(18, 20)
	cs.shape = rect
	add_child(cs)
	var sh_img := Image.create(16 if not boss else 22, 5 if not boss else 6, false, Image.FORMAT_RGBA8)
	sh_img.fill(Color(0, 0, 0, 0.35))
	var sh := Sprite2D.new()
	sh.z_index = -1
	sh.centered = true
	sh.position = Vector2(0, 12)
	sh.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sh.texture = ImageTexture.create_from_image(sh_img)
	add_child(sh)


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
		if combat_state == CombatState.HIT:
			combat_state = CombatState.IDLE

	if _attack_anim_t > 0.0:
		_attack_anim_t -= delta
		var remaining := clampf(_attack_anim_t / maxf(0.001, _attack_anim_max), 0.0, 1.0)
		var elapsed := 1.0 - remaining
		AttackPose.apply(_sprite, _facing, remaining, is_boss, _attack_style, _base_scale)
		if not _strike_done and elapsed >= 0.28:
			_strike_done = true
			_resolve_strike()
		if _attack_anim_t <= 0.0:
			AttackPose.reset(_sprite, _base_scale, warrior.display_modulate())
			_sword_arc = null
			combat_state = CombatState.IDLE
	else:
		_anim_t += delta
		if _anim_t >= 0.14:
			_anim_t = 0.0
			_frame = (_frame + 1) % 4
			_update_frame()

	var to_player := Vector2.ZERO
	var dist := 999.0
	if _player != null and is_instance_valid(_player):
		to_player = _player.global_position - global_position
		dist = to_player.length()
		if dist > 0.1 and _attack_anim_t <= 0.0:
			_facing = WeaponData.cardinal(to_player)

	if knockback.length() > 4.0:
		velocity = knockback
		knockback = knockback.move_toward(Vector2.ZERO, 280.0 * delta)
	else:
		knockback = Vector2.ZERO
		_ai_timer -= delta
		if _ai_timer <= 0.0:
			_ai_timer = randf_range(0.25, 0.7)
			_ai_dir = _choose_move_dir(to_player, dist)
		var mul := 0.28 if _attack_anim_t > 0.0 else 1.0
		velocity = _ai_dir * (speed * mul)
	move_and_slide()
	position.x = clampf(position.x, 28.0, 228.0)
	position.y = clampf(position.y, 28.0, 148.0)

	if _player != null and is_instance_valid(_player) and _attack_cd <= 0.0 and _attack_anim_t <= 0.0:
		_try_attack(dist)


func _choose_move_dir(to_player: Vector2, dist: float) -> Vector2:
	if to_player == Vector2.ZERO:
		return Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
	var ranged := warrior.prefers_ranged() or (bool(_profile.get("can_ranged", false)) and (is_boss or randf() < 0.55))
	var pref: float = float(_profile.get("preferred_range", 70.0))
	if ranged:
		if dist < pref * 0.55:
			return -to_player.normalized()
		if dist > pref * 1.25:
			return to_player.normalized()
		var side := Vector2(-to_player.y, to_player.x).normalized()
		if randf() < 0.5:
			side = -side
		return side
	if dist < 110.0 or is_boss:
		return to_player.normalized()
	return Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()


func _try_attack(dist: float) -> void:
	var can_r := bool(_profile.get("can_ranged", false))
	var melee_reach: float = float(_profile.get("melee_reach", 18.0)) + (4.0 if is_boss else 0.0)
	if can_r and dist > melee_reach + 6.0 and dist < 120.0:
		_begin_attack(true)
		return
	if dist <= melee_reach + 4.0:
		_begin_attack(false)


func _begin_attack(ranged: bool) -> void:
	combat_state = CombatState.SPECIAL_ATTACK if ranged else CombatState.ATTACK
	_attack_cd = 0.85 if is_boss else 1.05
	_strike_done = false
	_pending_ranged = ranged
	var shape := str(_profile.get("shape", "sword"))
	_attack_style = "cast" if ranged else AttackPose.swing_style_for(shape)
	if _player != null and is_instance_valid(_player):
		_facing = WeaponData.cardinal(_player.global_position - global_position)
	_attack_anim_max = 0.34 if is_boss else 0.28
	_attack_anim_t = _attack_anim_max
	var col: Color = WeaponData.finish_color(_profile.get("color", warrior.outfit_accent()), warrior.variant_weapon_style)
	if _sword_arc != null and is_instance_valid(_sword_arc):
		_sword_arc.queue_free()
	var arc := SwordArc.new()
	_sprite.add_child(arc)
	arc.position = Vector2.ZERO
	var s := _base_scale if _base_scale > 0.01 else 0.42
	arc.scale = Vector2(1.0 / s, 1.0 / s)
	var face_for_arc := _facing
	if absf(face_for_arc.x) >= absf(face_for_arc.y):
		face_for_arc = Vector2.LEFT
	arc.play(face_for_arc, shape, col, is_boss, _attack_style)
	_sword_arc = arc


func _resolve_strike() -> void:
	var col: Color = WeaponData.finish_color(_profile.get("color", warrior.outfit_accent()), warrior.variant_weapon_style)
	var origin := position + _facing * (12.0 if not _pending_ranged else 6.0)
	var parent_fx: Node2D = _world if _world else self
	if _pending_ranged:
		CombatFx.spawn_cast_burst(parent_fx, origin, _facing, col)
		var kind := str(_profile.get("projectile", "bolt"))
		var aim := _facing
		if _player != null and is_instance_valid(_player):
			aim = (_player.global_position - global_position).normalized()
			_facing = WeaponData.cardinal(aim)
		if _world:
			var proj: Area2D = PROJECTILE_SCRIPT.new()
			_world.add_child(proj)
			var dmg := maxi(3, int(contact_damage * (1.1 if is_boss else 0.85)))
			var spd := 110.0 if is_boss else 90.0
			proj.call("setup", position + _facing * 10.0, aim, spd, dmg, "enemy", kind, col)
			if not proj.hit_player.is_connected(_on_proj_hit_player):
				proj.hit_player.connect(_on_proj_hit_player)
	else:
		CombatFx.spawn_hit_spark(parent_fx, origin + _facing * 8.0, col)
		if _player != null and is_instance_valid(_player):
			var to_p: Vector2 = (_player.global_position - global_position)
			if to_p.length() <= float(_profile.get("melee_reach", 18.0)) + 6.0:
				if to_p != Vector2.ZERO and _facing.dot(to_p.normalized()) >= 0.15:
					damaged_player.emit(contact_damage, global_position)


func _on_proj_hit_player(amount: int, from_pos: Vector2) -> void:
	damaged_player.emit(amount, from_pos)


func _update_frame() -> void:
	if _sheet == null or not _sprite.region_enabled or _attack_anim_t > 0.0:
		return
	_sprite.region_rect = Rect2(_frame * 64, 0, 64, 80)
	_sprite.flip_h = WeaponData.flip_h_for(_facing)


func take_hit(amount: int, from_pos: Vector2) -> void:
	if not _alive or invuln > 0.0:
		return
	warrior.current_hp = maxi(0, warrior.current_hp - amount)
	invuln = 0.28
	_hurt_flash = 0.35
	combat_state = CombatState.HIT
	var dir := (global_position - from_pos).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	knockback = dir * (140.0 if is_boss else 180.0)
	if warrior.current_hp <= 0:
		_alive = false
		combat_state = CombatState.DEFEATED
		velocity = Vector2.ZERO
		died.emit(self, is_boss, global_position)
		# Hold the final authored frame briefly. A real defeated strip should
		# replace this timing once enemy defeat art exists.
		get_tree().create_timer(0.18).timeout.connect(queue_free)


func is_alive_enemy() -> bool:
	return _alive
