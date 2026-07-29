extends Node2D
## Zelda ALttP-style dungeon: canvas-drawn rooms, live enemies, realtime combat.
## Room art uses Node2D._draw (not ColorRect-under-Node2D) so Android mobile renders.

const TILE := 16
const ROOM_W := 16
const ROOM_H := 11
const DOOR_GAP := 3 ## tiles wide — wide enough for the player body
const OPPOSITE := {"n": "s", "s": "n", "w": "e", "e": "w"}
const ENEMY_SCRIPT := preload("res://scripts/adventure/dungeon_enemy.gd")
const ROOM_DRAW_SCRIPT := preload("res://scripts/adventure/dungeon_room_draw.gd")
const WEAPON_SCRIPT := preload("res://scripts/adventure/dungeon_weapon.gd")
const PROJECTILE_SCRIPT := preload("res://scripts/adventure/dungeon_projectile.gd")
const COMBAT_FX := preload("res://scripts/adventure/combat_fx.gd")

@onready var world: Node2D = $World
@onready var player: CharacterBody2D = $Player
@onready var room_label: Label = %RoomLabel
@onready var hp_label: Label = %HpLabel
@onready var energy_label: Label = %EnergyLabel
@onready var key_label: Label = %KeyLabel
@onready var level_label: Label = %LevelLabel
@onready var message_label: Label = %MessageLabel
@onready var attack_btn: Button = %AttackBtn
@onready var special_btn: Button = %SpecialBtn
@onready var leave_btn: Button = %LeaveBtn
@onready var pad_up: Button = %PadUp
@onready var pad_down: Button = %PadDown
@onready var pad_left: Button = %PadLeft
@onready var pad_right: Button = %PadRight

var _dungeon: Dictionary = {}
var _theme: Dictionary = {}
var _rooms: Array = []
var _current_id: int = 0
var _warrior: Warrior
var _message_timer: float = 0.0
var _transitioning: bool = false
var _door_cooldown: float = 0.0
var _pad_dir: Vector2 = Vector2.ZERO
var _facing: Vector2 = Vector2.DOWN
var _anim_t: float = 0.0
var _anim_frame: int = 0
var _player_sprite: Sprite2D
var _player_sheet: Texture2D
var _attack_cd: float = 0.0
var _special_cd: float = 0.0
var _hurt_invuln: float = 0.0
var _enemies: Array = []
var _pickups: Array = []
var _torch_t: float = 0.0
var _cam: Camera2D
var _attack_anim_t: float = 0.0
var _attack_anim_special: bool = false
var _door_dirs: Array = []
var _exits: Array = [] ## {dir, target, locked, mouth: Rect2}
var _retreat_dir: String = "" ## door that leads back the way you came
var _room_art: Node2D
var _controls_wired: bool = false
var _weapon_profile: Dictionary = {}


func _ready() -> void:
	# Wire controls first so Leave/Attack always work even if room build fails.
	_wire_controls()
	_warrior = GameState.get_adventure_warrior()
	_dungeon = GameState.adventure_dungeon
	if _warrior == null or _dungeon.is_empty():
		get_tree().change_scene_to_file("res://scenes/adventure_lobby.tscn")
		return
	_theme = _dungeon.get("theme", {})
	_rooms = _dungeon.get("rooms", [])
	_current_id = int(_dungeon.get("current_room", _dungeon.get("start_id", 0)))
	GameState.pending_adventure_battle = {}
	var hud_safe: Control = $HUD.get_node_or_null("SafeRoot")
	if hud_safe:
		SafeArea.register(hud_safe)
	_setup_player()
	_setup_camera()
	_build_room(_current_id, Vector2(ROOM_W * TILE * 0.5, ROOM_H * TILE * 0.5))
	_show_message("Entered the %s..." % str(_dungeon.get("name", "Dungeon")))


func _wire_controls() -> void:
	if _controls_wired:
		return
	_controls_wired = true
	if attack_btn:
		attack_btn.pressed.connect(_on_attack)
		UITheme.style_button(attack_btn, true)
	if special_btn:
		special_btn.pressed.connect(_on_special)
		UITheme.style_button(special_btn)
	if leave_btn:
		leave_btn.pressed.connect(_on_leave)
		UITheme.style_button(leave_btn)
	_wire_pad(pad_up, Vector2(0, -1))
	_wire_pad(pad_down, Vector2(0, 1))
	_wire_pad(pad_left, Vector2(-1, 0))
	_wire_pad(pad_right, Vector2(1, 0))


func _wire_pad(btn: Button, dir: Vector2) -> void:
	if btn == null:
		return
	btn.button_down.connect(func(): _pad_dir = dir)
	btn.button_up.connect(func():
		if _pad_dir == dir:
			_pad_dir = Vector2.ZERO
	)


func _setup_camera() -> void:
	_cam = Camera2D.new()
	_cam.enabled = true
	_cam.position = Vector2(ROOM_W * TILE * 0.5, ROOM_H * TILE * 0.45)
	# Zoom so the full room fits a 720x1280 portrait viewport with HUD margins.
	_cam.zoom = Vector2(2.45, 2.45)
	add_child(_cam)
	_cam.make_current()
	# Ensure world is above the clear color and camera can see room origin.
	world.z_index = 0
	player.z_as_relative = true


func _setup_player() -> void:
	player.collision_layer = 4
	player.collision_mask = 1
	player.add_to_group("dungeon_player")
	_weapon_profile = _warrior.weapon_profile()
	_player_sprite = player.get_node_or_null("Sprite") as Sprite2D
	if _player_sprite == null:
		_player_sprite = Sprite2D.new()
		_player_sprite.name = "Sprite"
		player.add_child(_player_sprite)
	# Remove leftover outfit overlays from older builds
	for child in player.get_children():
		if str(child.name) == "OutfitGear":
			child.queue_free()
	_player_sprite.centered = true
	_player_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_player_sprite.scale = Vector2(0.42, 0.42)
	if ResourceLoader.exists(_warrior.sheet_path()):
		_player_sheet = load(_warrior.sheet_path())
		_player_sprite.texture = _player_sheet
		_player_sprite.region_enabled = true
		_player_sprite.region_rect = Rect2(0, 0, 64, 80)
	elif ResourceLoader.exists(_warrior.sprite_path()):
		_player_sprite.texture = load(_warrior.sprite_path())
	_player_sprite.modulate = _warrior.display_modulate()
	var col: CollisionShape2D = player.get_node_or_null("Collision")
	if col and col.shape is RectangleShape2D:
		(col.shape as RectangleShape2D).size = Vector2(10, 12)


func _process(delta: float) -> void:
	if _message_timer > 0.0:
		_message_timer -= delta
		if _message_timer <= 0.0 and message_label:
			message_label.text = ""
	_torch_t += delta
	if _room_art != null and is_instance_valid(_room_art) and _torch_t >= 0.22:
		_torch_t = 0.0
		_room_art.call("set_torch_phase", Time.get_ticks_msec() * 0.001)


func _physics_process(delta: float) -> void:
	if _transitioning or _warrior == null:
		return
	if _door_cooldown > 0.0:
		_door_cooldown -= delta
	if _attack_cd > 0.0:
		_attack_cd -= delta
	if _special_cd > 0.0:
		_special_cd -= delta
	if _hurt_invuln > 0.0:
		_hurt_invuln -= delta
		_player_sprite.modulate.a = 0.5 if int(_hurt_invuln * 18.0) % 2 == 0 else 1.0
	else:
		_player_sprite.modulate.a = 1.0

	var dir := _pad_dir
	if Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A):
		dir.x -= 1
	if Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D):
		dir.x += 1
	if Input.is_action_pressed("ui_up") or Input.is_key_pressed(KEY_W):
		dir.y -= 1
	if Input.is_action_pressed("ui_down") or Input.is_key_pressed(KEY_S):
		dir.y += 1
	if Input.is_key_pressed(KEY_Z) or Input.is_key_pressed(KEY_J):
		_on_attack()
	if Input.is_key_pressed(KEY_X) or Input.is_key_pressed(KEY_K):
		_on_special()

	if dir != Vector2.ZERO and _attack_anim_t <= 0.0:
		_facing = WeaponData.cardinal(dir)
		_anim_t += delta
		if _anim_t >= 0.12:
			_anim_t = 0.0
			_anim_frame = (_anim_frame + 1) % 4
			_set_player_frame(_anim_frame)
	elif _attack_anim_t <= 0.0:
		_set_player_frame(0)

	if _attack_anim_t > 0.0:
		_attack_anim_t -= delta
		_animate_attack_pose()

	player.velocity = dir.normalized() * (70.0 if _attack_anim_t > 0.0 else 98.0)
	player.move_and_slide()
	_clamp_player_in_room()
	_check_enemy_contact()
	_check_pickups()
	if _door_cooldown <= 0.0:
		_check_doors()
	_update_hud()


func _animate_attack_pose() -> void:
	var t := clampf(_attack_anim_t / 0.22, 0.0, 1.0)
	var lunge := (1.0 - absf(t - 0.5) * 2.0) * (5.0 if _attack_anim_special else 3.5)
	_player_sprite.offset = _facing * lunge
	if _attack_anim_special:
		_player_sprite.modulate = _warrior.outfit_accent().lerp(_warrior.display_modulate(), 1.0 - t)
	if _attack_anim_t <= 0.0:
		_player_sprite.offset = Vector2.ZERO
		_player_sprite.rotation = 0.0
		_player_sprite.modulate = _warrior.display_modulate()
		_player_sprite.modulate.a = 1.0


func _set_player_frame(frame: int) -> void:
	if _player_sheet == null or not _player_sprite.region_enabled:
		return
	_player_sprite.region_rect = Rect2(frame * 64, 0, 64, 80)
	_player_sprite.flip_h = _facing.x < -0.2


func _clamp_player_in_room() -> void:
	## Keep player inside floor, but open door mouths fully so exits are reachable.
	var min_x := TILE + 6.0
	var max_x := (ROOM_W - 1) * TILE - 6.0
	var min_y := TILE + 6.0
	var max_y := (ROOM_H - 1) * TILE - 6.0
	var gap := float(DOOR_GAP * TILE)
	var cx := ROOM_W * TILE * 0.5
	var cy := ROOM_H * TILE * 0.5
	for d in _door_dirs:
		match str(d):
			"n":
				min_y = 2.0
				# Only relax X near the door mouth
				if absf(player.position.x - cx) <= gap * 0.5 + 4.0:
					min_y = 2.0
			"s":
				max_y = float(ROOM_H * TILE) - 2.0
			"w":
				min_x = 2.0
			"e":
				max_x = float(ROOM_W * TILE) - 2.0
	player.position.x = clampf(player.position.x, min_x, max_x)
	player.position.y = clampf(player.position.y, min_y, max_y)


func _build_room(room_id: int, spawn: Vector2) -> void:
	for c in world.get_children():
		c.queue_free()
	_enemies.clear()
	_pickups.clear()
	_door_dirs.clear()
	_exits.clear()
	_room_art = null
	_current_id = room_id
	_dungeon["current_room"] = room_id
	var room: Dictionary = _rooms[room_id]
	room["visited"] = true
	var floor_c: Color = _as_color(_theme.get("floor", Color(0.2, 0.2, 0.22)))
	var wall_c: Color = _as_color(_theme.get("wall", Color(0.35, 0.32, 0.3)))
	var accent_c: Color = _as_color(_theme.get("accent", Color(0.7, 0.55, 0.35)))
	var doors := _normalize_doors(room.get("doors", {}))
	room["doors"] = doors
	var locked: Dictionary = {}
	for d in doors.keys():
		var tid := int(doors[d])
		var to_boss := tid == int(_dungeon.get("boss_id", -1))
		var needs_key := to_boss and not bool(_dungeon.get("has_key", false))
		if needs_key:
			locked[d] = true
		else:
			_door_dirs.append(d)
		_exits.append({
			"dir": d,
			"target": tid,
			"locked": needs_key,
			"mouth": _door_mouth_rect(d),
		})

	var kind: String = str(room.get("kind", "empty"))
	_room_art = ROOM_DRAW_SCRIPT.new()
	_room_art.name = "RoomArt"
	_room_art.z_index = -10
	world.add_child(_room_art)
	_room_art.call(
		"configure",
		floor_c,
		wall_c,
		accent_c,
		str(_theme.get("name", "")),
		doors,
		locked,
		kind
	)

	_add_wall_colliders(doors, locked)
	_add_pillar_colliders()

	var cleared: bool = bool(room.get("cleared", false))
	var looted: bool = bool(room.get("looted", false))

	if (kind == "key" or kind == "treasure") and not looted:
		_spawn_chest(kind == "key", Vector2(ROOM_W * TILE * 0.5, ROOM_H * TILE * 0.38), accent_c)

	if (kind == "enemy" or kind == "boss") and not cleared:
		var wrap: Dictionary = room.get("enemy", {})
		var wdict: Dictionary = wrap.get("warrior", wrap)
		if wdict.is_empty():
			room["cleared"] = true
			cleared = true
		elif kind == "boss":
			_spawn_enemy(wdict, true, Vector2(ROOM_W * TILE * 0.5, ROOM_H * TILE * 0.5))
		else:
			_spawn_enemy(wdict, false, Vector2(ROOM_W * TILE * 0.55, ROOM_H * TILE * 0.5))
			if randf() < 0.4:
				_spawn_enemy(_clone_enemy_dict(wdict, 1), false, Vector2(ROOM_W * TILE * 0.38, ROOM_H * TILE * 0.62))

	player.position = spawn
	player.z_index = 20
	_rooms[room_id] = room
	_dungeon["rooms"] = _rooms
	GameState.adventure_dungeon = _dungeon
	_door_cooldown = 0.25
	_update_hud()
	if _door_dirs.size() > 0:
		if cleared or _room_allows_free_exit(kind):
			_show_message("Walk into a doorway to leave")
		elif _retreat_dir != "":
			_show_message("Fight — or retreat the way you came")


func _normalize_doors(raw) -> Dictionary:
	var out := {}
	if raw is Dictionary:
		for k in raw.keys():
			out[str(k)] = int(raw[k])
	return out


func _door_mouth_rect(dir: String) -> Rect2:
	## Generous zone just inside / on the doorway — position check, not Area2D.
	var gap := float(DOOR_GAP * TILE)
	var cx := ROOM_W * TILE * 0.5
	var cy := ROOM_H * TILE * 0.5
	match dir:
		"n":
			return Rect2(cx - gap * 0.5, 0.0, gap, float(TILE) + 22.0)
		"s":
			return Rect2(cx - gap * 0.5, float((ROOM_H - 1) * TILE) - 22.0, gap, float(TILE) + 22.0)
		"w":
			return Rect2(0.0, cy - gap * 0.5, float(TILE) + 22.0, gap)
		"e":
			return Rect2(float((ROOM_W - 1) * TILE) - 22.0, cy - gap * 0.5, float(TILE) + 22.0, gap)
	return Rect2()


func _room_allows_free_exit(kind: String) -> bool:
	return kind in ["empty", "start", "treasure", "key"]


func _as_color(value) -> Color:
	if value is Color:
		return value
	if value is Array and value.size() >= 3:
		var a := float(value[3]) if value.size() > 3 else 1.0
		return Color(float(value[0]), float(value[1]), float(value[2]), a)
	return Color(0.2, 0.2, 0.22)


func _clone_enemy_dict(src: Dictionary, seed_add: int) -> Dictionary:
	var d := src.duplicate(true)
	d["barcode"] = str(d.get("barcode", "E")) + "-X%d" % seed_add
	d["seed_value"] = int(d.get("seed_value", 1)) + seed_add * 17
	d["name"] = str(d.get("name", "Foe"))
	return d


func _add_wall_rect_collider(r: Rect2) -> void:
	if r.size.x <= 0.5 or r.size.y <= 0.5:
		return
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = r.position + r.size * 0.5
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = r.size
	shape.shape = rect
	body.add_child(shape)
	world.add_child(body)


func _wall_segment_colliders(full: Rect2, solid: bool, gap_pos: Vector2, gap_size: Vector2) -> void:
	if solid:
		_add_wall_rect_collider(full)
		return
	if full.size.y == TILE:
		var left_w := gap_pos.x - full.position.x
		var right_x := gap_pos.x + gap_size.x
		if left_w > 0:
			_add_wall_rect_collider(Rect2(full.position.x, full.position.y, left_w, TILE))
		var right_w := full.position.x + full.size.x - right_x
		if right_w > 0:
			_add_wall_rect_collider(Rect2(right_x, full.position.y, right_w, TILE))
	else:
		var top_h := gap_pos.y - full.position.y
		var bot_y := gap_pos.y + gap_size.y
		if top_h > 0:
			_add_wall_rect_collider(Rect2(full.position.x, full.position.y, TILE, top_h))
		var bot_h := full.position.y + full.size.y - bot_y
		if bot_h > 0:
			_add_wall_rect_collider(Rect2(full.position.x, bot_y, TILE, bot_h))


func _add_wall_colliders(doors: Dictionary, locked: Dictionary) -> void:
	var gap := float(DOOR_GAP * TILE)
	var half := gap * 0.5
	_wall_segment_colliders(
		Rect2(0, 0, ROOM_W * TILE, TILE),
		not doors.has("n") or bool(locked.get("n", false)),
		Vector2(ROOM_W * TILE * 0.5 - half, 0),
		Vector2(gap, TILE)
	)
	_wall_segment_colliders(
		Rect2(0, (ROOM_H - 1) * TILE, ROOM_W * TILE, TILE),
		not doors.has("s") or bool(locked.get("s", false)),
		Vector2(ROOM_W * TILE * 0.5 - half, (ROOM_H - 1) * TILE),
		Vector2(gap, TILE)
	)
	_wall_segment_colliders(
		Rect2(0, 0, TILE, ROOM_H * TILE),
		not doors.has("w") or bool(locked.get("w", false)),
		Vector2(0, ROOM_H * TILE * 0.5 - half),
		Vector2(TILE, gap)
	)
	_wall_segment_colliders(
		Rect2((ROOM_W - 1) * TILE, 0, TILE, ROOM_H * TILE),
		not doors.has("e") or bool(locked.get("e", false)),
		Vector2((ROOM_W - 1) * TILE, ROOM_H * TILE * 0.5 - half),
		Vector2(TILE, gap)
	)


func _add_pillar_colliders() -> void:
	## Keep pillars away from door lanes
	for p in [Vector2(TILE * 3.2, TILE * 3.0), Vector2(TILE * 12.0, TILE * 3.0), Vector2(TILE * 3.2, TILE * 7.0), Vector2(TILE * 12.0, TILE * 7.0)]:
		_add_wall_rect_collider(Rect2(p.x, p.y, 10, 16))


func _box(color: Color, size: Vector2, pos: Vector2, parent: Node = null) -> Node2D:
	## Sprite2D-backed pixel box (same path as character sprites on Android).
	var img := Image.create(maxi(1, int(size.x)), maxi(1, int(size.y)), false, Image.FORMAT_RGBA8)
	img.fill(color)
	var spr := Sprite2D.new()
	spr.centered = false
	spr.position = pos
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.texture = ImageTexture.create_from_image(img)
	(parent if parent else world).add_child(spr)
	return spr


func _spawn_chest(has_key: bool, pos: Vector2, accent_c: Color) -> void:
	var area := Area2D.new()
	area.name = "Chest"
	area.position = pos
	area.set_meta("has_key", has_key)
	area.collision_layer = 0
	area.collision_mask = 4
	area.monitoring = true
	_box(Color(0.45, 0.28, 0.12), Vector2(22, 16), Vector2(-11, -8), area)
	_box(Color(0.62, 0.4, 0.16), Vector2(22, 6), Vector2(-11, -12), area)
	_box(accent_c.lightened(0.15), Vector2(22, 3), Vector2(-11, -2), area)
	_box(Color(0.9, 0.75, 0.25) if has_key else Color(0.55, 0.55, 0.5), Vector2(4, 4), Vector2(-2, -1), area)
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = Vector2(24, 20)
	cs.shape = rs
	area.add_child(cs)
	area.body_entered.connect(func(body):
		if body == player:
			_open_chest(area)
	)
	world.add_child(area)


func _spawn_enemy(wdict: Dictionary, boss: bool, pos: Vector2) -> void:
	var e := CharacterBody2D.new()
	e.set_script(ENEMY_SCRIPT)
	e.position = pos
	e.z_index = 15
	world.add_child(e)
	e.call("setup", wdict, player, boss)
	e.connect("died", _on_enemy_died)
	if e.has_signal("damaged_player"):
		e.connect("damaged_player", _on_enemy_damaged_player)
	_enemies.append(e)


func _on_enemy_damaged_player(amount: int, from_pos: Vector2) -> void:
	if _hurt_invuln > 0.0 or _warrior == null:
		return
	_warrior.current_hp = maxi(0, _warrior.current_hp - amount)
	_hurt_invuln = 0.75
	_show_message("Hit for %d!" % amount)
	GameState.save_adventure_warrior(_warrior)
	if not _warrior.is_alive():
		_on_player_down()
	_update_hud()
	# Small knock visual
	var away := (player.position - from_pos).normalized()
	if away != Vector2.ZERO:
		player.position += away * 4.0


func _open_chest(area: Area2D) -> void:
	var room: Dictionary = _rooms[_current_id]
	if bool(room.get("looted", false)):
		return
	room["looted"] = true
	_rooms[_current_id] = room
	if bool(area.get_meta("has_key", false)):
		_dungeon["has_key"] = true
		_dungeon["boss_unlocked"] = true
		_show_message("Dungeon Key obtained!")
	else:
		if randf() < 0.45:
			_spawn_pickup("energy", area.position)
			_show_message("%s found in the chest!" % _warrior.energy_item_name())
		else:
			_spawn_pickup("sandwich", area.position)
			_show_message("Sandwich found in the chest!")
	_dungeon["rooms"] = _rooms
	GameState.adventure_dungeon = _dungeon
	area.queue_free()
	if bool(_dungeon.get("has_key", false)):
		var spawn := player.position
		_build_room(_current_id, spawn)


func _on_enemy_died(enemy: CharacterBody2D, is_boss: bool, world_pos: Vector2) -> void:
	_enemies.erase(enemy)
	var base_xp := 22 + _warrior.level * 10
	if is_boss:
		base_xp = int(base_xp * 2.5) + 35
	var info := _warrior.gain_xp(base_xp)
	var msg := "+%d XP" % info["gained"]
	if int(info["levels"]) > 0:
		msg += " · Level %d!" % info["level"]
	var roll := randf()
	if is_boss or roll < 0.55:
		if randf() < 0.4:
			_spawn_pickup("energy", world_pos)
		else:
			_spawn_pickup("sandwich", world_pos)
	_show_message(msg)
	if _enemies.is_empty():
		_rooms[_current_id]["cleared"] = true
		_rooms[_current_id]["enemy"] = {}
		_dungeon["rooms"] = _rooms
		if is_boss:
			_show_message("Boss defeated! The %s falls quiet." % str(_dungeon.get("name", "dungeon")))
	GameState.save_adventure_warrior(_warrior)
	_update_hud()


func _spawn_pickup(kind: String, pos: Vector2) -> void:
	var area := Area2D.new()
	area.position = pos
	area.set_meta("pickup", kind)
	area.collision_layer = 0
	area.collision_mask = 4
	area.monitoring = true
	if kind == "sandwich":
		_box(Color(0.85, 0.7, 0.35), Vector2(12, 8), Vector2(-6, -4), area)
		_box(Color(0.55, 0.35, 0.15), Vector2(12, 3), Vector2(-6, -6), area)
	else:
		_box(_warrior.outfit_primary(), Vector2(8, 14), Vector2(-4, -7), area)
		_box(_warrior.outfit_secondary(), Vector2(4, 4), Vector2(-2, -11), area)
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = Vector2(14, 14)
	cs.shape = rs
	area.add_child(cs)
	world.add_child(area)
	_pickups.append(area)


func _check_pickups() -> void:
	for p in _pickups.duplicate():
		if not is_instance_valid(p):
			_pickups.erase(p)
			continue
		if player.global_position.distance_to(p.global_position) > 14.0:
			continue
		var kind: String = str(p.get_meta("pickup", ""))
		if kind == "sandwich":
			var healed := _warrior.heal(int(_warrior.max_hp * 0.28))
			_show_message("Ate a Sandwich (+%d HP)" % healed)
		elif kind == "energy":
			var gained := _warrior.restore_energy(int(_warrior.max_energy * 0.4))
			_show_message("%s (+%d EN)" % [_warrior.energy_item_name(), gained])
		GameState.save_adventure_warrior(_warrior)
		_pickups.erase(p)
		p.queue_free()
		_update_hud()


func _check_enemy_contact() -> void:
	## Light bump damage only — main hurts come from facing weapon swings / projectiles.
	if _hurt_invuln > 0.0:
		return
	for e in _enemies:
		if not is_instance_valid(e):
			continue
		if not e.call("is_alive_enemy"):
			continue
		if player.global_position.distance_to(e.global_position) < 11.0:
			var dmg: int = maxi(2, int(e.get("contact_damage") * 0.35))
			_on_enemy_damaged_player(dmg, e.global_position)
			return


func _on_player_down() -> void:
	_warrior.current_hp = 1
	GameState.save_adventure_warrior(_warrior)
	_show_message("Defeated... retreating.")
	await get_tree().create_timer(1.2).timeout
	GameState.end_adventure()
	get_tree().change_scene_to_file("res://scenes/adventure_lobby.tscn")


func _on_attack() -> void:
	if _transitioning or _attack_cd > 0.0 or _warrior == null:
		return
	_facing = WeaponData.cardinal(_facing)
	_attack_cd = 0.34
	_attack_anim_t = 0.22
	_attack_anim_special = false
	_perform_attack(false)


func _on_special() -> void:
	if _transitioning or _special_cd > 0.0 or _warrior == null:
		return
	if not _warrior.spend_special_energy():
		_show_message("Not enough energy for %s!" % _warrior.special_move)
		_update_hud()
		return
	_facing = WeaponData.cardinal(_facing)
	_special_cd = 0.65
	_attack_cd = 0.42
	_attack_anim_t = 0.28
	_attack_anim_special = true
	GameState.save_adventure_warrior(_warrior)
	_show_message(_warrior.special_move + "!")
	_perform_attack(true)
	_update_hud()


func _perform_attack(is_special: bool) -> void:
	var profile := _weapon_profile if not _weapon_profile.is_empty() else _warrior.weapon_profile()
	var shape := str(profile.get("shape", "sword"))
	var col: Color = WeaponData.finish_color(profile.get("color", _warrior.outfit_accent()), _warrior.variant_weapon_style)
	var use_ranged := false
	if bool(profile.get("can_ranged", false)):
		if str(profile.get("style", "")) == "ranged":
			use_ranged = true
		elif is_special:
			use_ranged = true
		elif str(profile.get("style", "")) == "hybrid" and _warrior.prefers_ranged():
			use_ranged = true
	# Spawn facing weapon pose
	var wpn: Sprite2D = WEAPON_SCRIPT.new()
	world.add_child(wpn)
	wpn.call("play", player.position, _facing, shape, col, is_special)
	if use_ranged:
		_fire_player_projectile(is_special, profile, col)
	else:
		_do_facing_melee(is_special, profile, col)


func _fire_player_projectile(is_special: bool, profile: Dictionary, col: Color) -> void:
	var kind := str(profile.get("projectile", "bolt"))
	var power := _warrior.special_power if is_special else _warrior.regular_power
	var spd := 140.0 if is_special else 115.0
	var proj: Area2D = PROJECTILE_SCRIPT.new()
	world.add_child(proj)
	var dmg := _warrior.calc_damage(power, 10, is_special)
	# Damage recalculated on hit with real defense
	proj.call("setup", player.position + _facing * 12.0, _facing, spd, dmg, "player", kind, col)
	proj.hit_enemy.connect(func(enemy: Node, _amt: int, from_pos: Vector2):
		if not is_instance_valid(enemy):
			return
		var def := 10
		if enemy.get("warrior") != null:
			def = int(enemy.warrior.defense)
		var real := _warrior.calc_damage(power, def, is_special)
		enemy.call("take_hit", real, from_pos)
		COMBAT_FX.spawn_hit_spark(world, enemy.position, col)
	)


func _do_facing_melee(is_special: bool, profile: Dictionary, col: Color) -> void:
	var reach: float = float(profile.get("melee_reach", 18.0)) * (1.25 if is_special else 1.0)
	var center := player.position + _facing * reach
	COMBAT_FX.spawn_slash(world, center, _facing, col, is_special)
	var power := _warrior.special_power if is_special else _warrior.regular_power
	var hit_r := reach * 0.85 + (6.0 if is_special else 2.0)
	for e in _enemies.duplicate():
		if not is_instance_valid(e):
			continue
		var to_e: Vector2 = e.position - player.position
		if to_e.length() > hit_r + 8.0:
			continue
		# Must be roughly in the facing cone (forgiving)
		if to_e != Vector2.ZERO and _facing.dot(to_e.normalized()) < 0.1:
			continue
		if e.position.distance_to(center) > hit_r and to_e.length() > reach * 0.7:
			continue
		var def := 10
		if e.get("warrior") != null:
			def = int(e.warrior.defense)
		var dmg := _warrior.calc_damage(power, def, is_special)
		e.call("take_hit", dmg, player.position)
		COMBAT_FX.spawn_hit_spark(world, e.position, col)


func _living_enemy_count() -> int:
	var live := 0
	var kept: Array = []
	for e in _enemies:
		if is_instance_valid(e) and e.call("is_alive_enemy"):
			live += 1
			kept.append(e)
	_enemies = kept
	return live


func _check_doors() -> void:
	if _transitioning:
		return
	var room: Dictionary = _rooms[_current_id]
	var kind := str(room.get("kind", "empty"))
	var cleared := bool(room.get("cleared", false))
	var live := _living_enemy_count()
	if live == 0 and (kind == "enemy" or kind == "boss") and not cleared:
		room["cleared"] = true
		room["enemy"] = {}
		_rooms[_current_id] = room
		_dungeon["rooms"] = _rooms
		cleared = true
	for exit in _exits:
		var mouth: Rect2 = exit["mouth"]
		if not mouth.has_point(player.position):
			# Also accept if close to mouth center (lenient)
			if player.position.distance_to(mouth.get_center()) > 18.0:
				continue
		var dir := str(exit["dir"])
		if bool(exit.get("locked", false)):
			_show_message("Locked. Find the dungeon key.")
			_door_cooldown = 0.45
			return
		var free := cleared or _room_allows_free_exit(kind) or live == 0
		var retreat := dir == _retreat_dir and _retreat_dir != ""
		if not free and not retreat:
			_show_message("Defeat enemies — or retreat the way you came")
			_door_cooldown = 0.4
			return
		_enter_room(int(exit["target"]), dir)
		return


func _enter_room(target_id: int, from_dir: String) -> void:
	_transitioning = true
	_door_cooldown = 0.4
	# Entering through `from_dir` of the old room → appear at opposite wall; retreat is that opposite.
	_retreat_dir = str(OPPOSITE.get(from_dir, ""))
	var spawn := Vector2(ROOM_W * TILE * 0.5, ROOM_H * TILE * 0.5)
	match from_dir:
		"n":
			spawn = Vector2(ROOM_W * TILE * 0.5, (ROOM_H - 2.2) * TILE)
		"s":
			spawn = Vector2(ROOM_W * TILE * 0.5, 2.2 * TILE)
		"w":
			spawn = Vector2((ROOM_W - 2.2) * TILE, ROOM_H * TILE * 0.5)
		"e":
			spawn = Vector2(2.2 * TILE, ROOM_H * TILE * 0.5)
	_build_room(target_id, spawn)
	_transitioning = false
	var room: Dictionary = _rooms[target_id]
	if str(room.get("kind")) == "boss":
		_show_message("%s awaits!" % str(_dungeon.get("boss_name", "Boss")))
	else:
		_show_message("Room %d — exits at glowing doorways" % (target_id + 1))


func _update_hud() -> void:
	if _warrior == null or room_label == null:
		return
	room_label.text = "%s · R%d/%d" % [str(_dungeon.get("name", "Dungeon")), _current_id + 1, _rooms.size()]
	hp_label.text = "HP %d/%d" % [_warrior.current_hp, _warrior.max_hp]
	energy_label.text = "EN %d/%d" % [_warrior.current_energy, _warrior.max_energy]
	key_label.text = "Key: Yes" if bool(_dungeon.get("has_key", false)) else "Key: —"
	level_label.text = "Lv.%d %s" % [_warrior.level, _warrior.name]
	special_btn.disabled = not _warrior.can_special()
	special_btn.text = "Special (%d)" % Warrior.SPECIAL_ENERGY_COST
	var shape := str(_weapon_profile.get("shape", "Attack"))
	attack_btn.text = shape.capitalize() if not _warrior.prefers_ranged() else "Shoot"


func _show_message(msg: String) -> void:
	if message_label == null:
		return
	message_label.text = msg
	_message_timer = 2.4


func _on_leave() -> void:
	if _warrior:
		GameState.save_adventure_warrior(_warrior)
	GameState.end_adventure()
	get_tree().change_scene_to_file("res://scenes/adventure_lobby.tscn")
