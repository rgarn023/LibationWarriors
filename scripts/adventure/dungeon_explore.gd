extends Node2D
## Zelda ALttP-style dungeon: detailed rooms, live enemies, realtime combat.

const TILE := 16
const ROOM_W := 16
const ROOM_H := 11
const ENEMY_SCRIPT := preload("res://scripts/adventure/dungeon_enemy.gd")

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
var _torch_nodes: Array = []
var _torch_t: float = 0.0
var _cam: Camera2D
var _attack_anim_t: float = 0.0
var _attack_anim_special: bool = false
var _door_dirs: Array = [] ## open door dirs in current room


func _ready() -> void:
	_warrior = GameState.get_adventure_warrior()
	_dungeon = GameState.adventure_dungeon
	if _warrior == null or _dungeon.is_empty():
		get_tree().change_scene_to_file("res://scenes/adventure_lobby.tscn")
		return
	_theme = _dungeon.get("theme", {})
	_rooms = _dungeon.get("rooms", [])
	_current_id = int(_dungeon.get("current_room", _dungeon.get("start_id", 0)))
	GameState.pending_adventure_battle = {}
	attack_btn.pressed.connect(_on_attack)
	special_btn.pressed.connect(_on_special)
	leave_btn.pressed.connect(_on_leave)
	_wire_pad(pad_up, Vector2(0, -1))
	_wire_pad(pad_down, Vector2(0, 1))
	_wire_pad(pad_left, Vector2(-1, 0))
	_wire_pad(pad_right, Vector2(1, 0))
	UITheme.style_button(attack_btn, true)
	UITheme.style_button(special_btn)
	UITheme.style_button(leave_btn)
	var hud_safe: Control = $HUD.get_node_or_null("SafeRoot")
	if hud_safe:
		SafeArea.register(hud_safe)
	_setup_player()
	_setup_camera()
	_build_room(_current_id, Vector2(ROOM_W * TILE * 0.5, ROOM_H * TILE * 0.5))
	_show_message("Entered the %s..." % str(_dungeon.get("name", "Dungeon")))


func _wire_pad(btn: Button, dir: Vector2) -> void:
	btn.button_down.connect(func(): _pad_dir = dir)
	btn.button_up.connect(func():
		if _pad_dir == dir:
			_pad_dir = Vector2.ZERO
	)


func _setup_camera() -> void:
	_cam = Camera2D.new()
	_cam.enabled = true
	_cam.position = Vector2(ROOM_W * TILE * 0.5, ROOM_H * TILE * 0.42)
	_cam.zoom = Vector2(2.35, 2.35)
	add_child(_cam)


func _setup_player() -> void:
	# Layer 4 = player; layer 1 = walls. Enemies are layer 2 (no mutual body push).
	player.collision_layer = 4
	player.collision_mask = 1
	_player_sprite = player.get_node_or_null("Sprite") as Sprite2D
	if _player_sprite == null:
		_player_sprite = Sprite2D.new()
		_player_sprite.name = "Sprite"
		player.add_child(_player_sprite)
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
		if _message_timer <= 0.0:
			message_label.text = ""
	_torch_t += delta
	if _torch_t >= 0.18:
		_torch_t = 0.0
		for tnode in _torch_nodes:
			if is_instance_valid(tnode):
				tnode.color = Color(1.0, 0.55 + randf() * 0.35, 0.15, 0.85)


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
		_facing = dir.normalized()
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
	## Lunge + flash while swinging.
	var t := clampf(_attack_anim_t / 0.22, 0.0, 1.0)
	var lunge := (1.0 - absf(t - 0.5) * 2.0) * (6.0 if _attack_anim_special else 4.0)
	_player_sprite.offset = _facing * lunge
	_player_sprite.rotation = _facing.x * 0.25 * (1.0 if _attack_anim_special else 0.15)
	if _attack_anim_special:
		_player_sprite.modulate = _warrior.tint_accent.lerp(_warrior.display_modulate(), 1.0 - t)
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
	## Keep player inside floor, but allow door mouths so exits are reachable.
	var min_x := TILE + 6.0
	var max_x := (ROOM_W - 1) * TILE - 6.0
	var min_y := TILE + 6.0
	var max_y := (ROOM_H - 1) * TILE - 6.0
	for d in _door_dirs:
		match str(d):
			"n":
				min_y = TILE + 1.0
			"s":
				max_y = (ROOM_H - 1) * TILE - 1.0
			"w":
				min_x = TILE + 1.0
			"e":
				max_x = (ROOM_W - 1) * TILE - 1.0
	player.position.x = clampf(player.position.x, min_x, max_x)
	player.position.y = clampf(player.position.y, min_y, max_y)


func _build_room(room_id: int, spawn: Vector2) -> void:
	for c in world.get_children():
		c.queue_free()
	_enemies.clear()
	_pickups.clear()
	_torch_nodes.clear()
	_door_dirs.clear()
	_current_id = room_id
	_dungeon["current_room"] = room_id
	var room: Dictionary = _rooms[room_id]
	room["visited"] = true
	var floor_c: Color = _as_color(_theme.get("floor", Color(0.2, 0.2, 0.22)))
	var wall_c: Color = _as_color(_theme.get("wall", Color(0.35, 0.32, 0.3)))
	var accent_c: Color = _as_color(_theme.get("accent", Color(0.7, 0.55, 0.35)))

	_draw_detailed_floor(floor_c, accent_c)
	var doors: Dictionary = room.get("doors", {})
	for d in doors.keys():
		var tid := int(doors[d])
		var to_boss := tid == int(_dungeon.get("boss_id", -1))
		var needs_key := to_boss and not bool(_dungeon.get("has_key", false))
		if not needs_key:
			_door_dirs.append(str(d))
	_add_walls_and_doors(wall_c, floor_c, accent_c, doors)
	_draw_room_props(accent_c, wall_c, room)
	_draw_theme_scenery(accent_c, wall_c, floor_c)

	var kind: String = str(room.get("kind", "empty"))
	var cleared: bool = bool(room.get("cleared", false))
	var looted: bool = bool(room.get("looted", false))

	if (kind == "key" or kind == "treasure") and not looted:
		_spawn_chest(kind == "key", Vector2(ROOM_W * TILE * 0.5, ROOM_H * TILE * 0.38), accent_c)

	if (kind == "enemy" or kind == "boss") and not cleared:
		var wrap: Dictionary = room.get("enemy", {})
		var wdict: Dictionary = wrap.get("warrior", wrap)
		if not wdict.is_empty():
			if kind == "boss":
				_spawn_enemy(wdict, true, Vector2(ROOM_W * TILE * 0.5, ROOM_H * TILE * 0.5))
			else:
				_spawn_enemy(wdict, false, Vector2(ROOM_W * TILE * 0.55, ROOM_H * TILE * 0.5))
				if randf() < 0.4:
					_spawn_enemy(_clone_enemy_dict(wdict, 1), false, Vector2(ROOM_W * TILE * 0.38, ROOM_H * TILE * 0.62))

	player.position = spawn
	player.z_index = 20
	GameState.adventure_dungeon = _dungeon
	_door_cooldown = 0.35
	_update_hud()
	if _door_dirs.size() > 0 and (cleared or kind == "empty" or kind == "start" or kind == "treasure" or kind == "key"):
		_show_message("Exits open")


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


func _draw_detailed_floor(floor_c: Color, accent_c: Color) -> void:
	var base := ColorRect.new()
	base.color = floor_c.darkened(0.08)
	base.size = Vector2(ROOM_W * TILE, ROOM_H * TILE)
	world.add_child(base)
	# Stone tiles with mortar lines
	for y in range(1, ROOM_H - 1):
		for x in range(1, ROOM_W - 1):
			var px := x * TILE
			var py := y * TILE
			var tile := ColorRect.new()
			var n := (x * 17 + y * 31) % 6
			var shade := [-0.08, -0.03, 0.0, 0.04, 0.07, -0.05][n]
			tile.color = floor_c.lightened(shade) if shade >= 0.0 else floor_c.darkened(-shade)
			tile.position = Vector2(px + 1, py + 1)
			tile.size = Vector2(TILE - 2, TILE - 2)
			world.add_child(tile)
			# Mortar
			var mortar := ColorRect.new()
			mortar.color = floor_c.darkened(0.22)
			mortar.position = Vector2(px, py)
			mortar.size = Vector2(TILE, 1)
			world.add_child(mortar)
			# Speckle / grit
			if n == 2 or n == 5:
				var grit := ColorRect.new()
				grit.color = floor_c.lightened(0.12)
				grit.position = Vector2(px + 4 + (n % 3), py + 5)
				grit.size = Vector2(2, 2)
				world.add_child(grit)
			if (x + y * 3) % 11 == 0:
				var crack := ColorRect.new()
				crack.color = floor_c.darkened(0.28)
				crack.position = Vector2(px + 3, py + 8)
				crack.size = Vector2(9, 1)
				world.add_child(crack)
			if (x * y) % 13 == 0:
				var stain := ColorRect.new()
				stain.color = Color(accent_c.r * 0.25, accent_c.g * 0.2, accent_c.b * 0.15, 0.35)
				stain.position = Vector2(px + 2, py + 2)
				stain.size = Vector2(8, 6)
				world.add_child(stain)
	# Inset carpet / ritual circle
	var carpet := ColorRect.new()
	carpet.color = Color(accent_c.r * 0.28, accent_c.g * 0.28, accent_c.b * 0.3, 0.65)
	carpet.position = Vector2(TILE * 4.5, TILE * 3)
	carpet.size = Vector2(TILE * 7, TILE * 5)
	world.add_child(carpet)
	for edge in [
		Rect2(carpet.position, Vector2(carpet.size.x, 2)),
		Rect2(carpet.position + Vector2(0, carpet.size.y - 2), Vector2(carpet.size.x, 2)),
		Rect2(carpet.position, Vector2(2, carpet.size.y)),
		Rect2(carpet.position + Vector2(carpet.size.x - 2, 0), Vector2(2, carpet.size.y)),
	]:
		var e := ColorRect.new()
		e.color = accent_c
		e.position = edge.position
		e.size = edge.size
		world.add_child(e)
	# Center emblem
	var emblem := ColorRect.new()
	emblem.color = accent_c.lightened(0.15)
	emblem.position = Vector2(ROOM_W * TILE * 0.5 - 5, ROOM_H * TILE * 0.5 - 5)
	emblem.size = Vector2(10, 10)
	world.add_child(emblem)
	var emblem_in := ColorRect.new()
	emblem_in.color = floor_c
	emblem_in.position = emblem.position + Vector2(2, 2)
	emblem_in.size = Vector2(6, 6)
	world.add_child(emblem_in)


func _add_walls_and_doors(wall_c: Color, floor_c: Color, accent_c: Color, doors: Dictionary) -> void:
	_wall_segment(wall_c, Rect2(0, 0, ROOM_W * TILE, TILE), not doors.has("n"), Vector2(ROOM_W * TILE * 0.5 - TILE, 0), Vector2(TILE * 2, TILE))
	_wall_segment(wall_c, Rect2(0, (ROOM_H - 1) * TILE, ROOM_W * TILE, TILE), not doors.has("s"), Vector2(ROOM_W * TILE * 0.5 - TILE, (ROOM_H - 1) * TILE), Vector2(TILE * 2, TILE))
	_wall_segment(wall_c, Rect2(0, 0, TILE, ROOM_H * TILE), not doors.has("w"), Vector2(0, ROOM_H * TILE * 0.5 - TILE), Vector2(TILE, TILE * 2))
	_wall_segment(wall_c, Rect2((ROOM_W - 1) * TILE, 0, TILE, ROOM_H * TILE), not doors.has("e"), Vector2((ROOM_W - 1) * TILE, ROOM_H * TILE * 0.5 - TILE), Vector2(TILE, TILE * 2))
	# Brick detailing on walls
	for x in range(ROOM_W):
		_brick_detail(wall_c, x * TILE, 2)
		_brick_detail(wall_c, x * TILE, (ROOM_H - 1) * TILE + 2)
	for y in range(ROOM_H):
		_brick_detail(wall_c, 2, y * TILE)
		_brick_detail(wall_c, (ROOM_W - 1) * TILE + 2, y * TILE)

	for dir_name in doors.keys():
		var target_id: int = int(doors[dir_name])
		var to_boss := int(target_id) == int(_dungeon.get("boss_id", -1))
		var needs_key := to_boss and not bool(_dungeon.get("has_key", false))
		if needs_key:
			_add_locked_door_blocker(dir_name, accent_c)
		_add_door_trigger(dir_name, target_id, to_boss, needs_key, floor_c, accent_c)


func _brick_detail(wall_c: Color, x: float, y: float) -> void:
	var b := ColorRect.new()
	b.color = wall_c.lightened(0.12)
	b.position = Vector2(x, y)
	b.size = Vector2(6, 2)
	world.add_child(b)


func _wall_segment(wall_c: Color, full: Rect2, solid: bool, gap_pos: Vector2, gap_size: Vector2) -> void:
	if solid:
		_add_wall_rect(full, wall_c)
		return
	if full.size.y == TILE:
		var left_w := gap_pos.x - full.position.x
		var right_x := gap_pos.x + gap_size.x
		if left_w > 0:
			_add_wall_rect(Rect2(full.position.x, full.position.y, left_w, TILE), wall_c)
		var right_w := full.position.x + full.size.x - right_x
		if right_w > 0:
			_add_wall_rect(Rect2(right_x, full.position.y, right_w, TILE), wall_c)
	else:
		var top_h := gap_pos.y - full.position.y
		var bot_y := gap_pos.y + gap_size.y
		if top_h > 0:
			_add_wall_rect(Rect2(full.position.x, full.position.y, TILE, top_h), wall_c)
		var bot_h := full.position.y + full.size.y - bot_y
		if bot_h > 0:
			_add_wall_rect(Rect2(full.position.x, bot_y, TILE, bot_h), wall_c)


func _add_wall_rect(r: Rect2, wall_c: Color) -> void:
	var wall := ColorRect.new()
	wall.color = wall_c
	wall.position = r.position
	wall.size = r.size
	world.add_child(wall)
	# Brick rows
	var step := 8
	var y := int(r.position.y)
	while y < int(r.position.y + r.size.y):
		var row := ColorRect.new()
		row.color = wall_c.lightened(0.08 if (y / step) % 2 == 0 else -0.0)
		if (y / step) % 2 != 0:
			row.color = wall_c.darkened(0.08)
		row.position = Vector2(r.position.x, y)
		row.size = Vector2(r.size.x, 1)
		world.add_child(row)
		y += step
	var bevel := ColorRect.new()
	bevel.color = wall_c.lightened(0.18)
	bevel.position = r.position + Vector2(1, 1)
	bevel.size = Vector2(maxi(1, int(r.size.x) - 2), 2)
	world.add_child(bevel)
	var shade := ColorRect.new()
	shade.color = wall_c.darkened(0.2)
	shade.position = r.position + Vector2(0, maxf(0.0, r.size.y - 3))
	shade.size = Vector2(r.size.x, mini(3.0, r.size.y))
	world.add_child(shade)
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


func _add_locked_door_blocker(dir_name: String, accent_c: Color) -> void:
	var body := StaticBody2D.new()
	body.name = "BossLock"
	body.collision_layer = 1
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	var vis := ColorRect.new()
	vis.color = Color(0.55, 0.45, 0.15, 0.95)
	match dir_name:
		"n":
			body.position = Vector2(ROOM_W * TILE * 0.5, TILE * 0.5)
			rs.size = Vector2(TILE * 2, TILE)
			vis.position = Vector2(ROOM_W * TILE * 0.5 - TILE, 0)
			vis.size = Vector2(TILE * 2, TILE)
		"s":
			body.position = Vector2(ROOM_W * TILE * 0.5, (ROOM_H - 0.5) * TILE)
			rs.size = Vector2(TILE * 2, TILE)
			vis.position = Vector2(ROOM_W * TILE * 0.5 - TILE, (ROOM_H - 1) * TILE)
			vis.size = Vector2(TILE * 2, TILE)
		"w":
			body.position = Vector2(TILE * 0.5, ROOM_H * TILE * 0.5)
			rs.size = Vector2(TILE, TILE * 2)
			vis.position = Vector2(0, ROOM_H * TILE * 0.5 - TILE)
			vis.size = Vector2(TILE, TILE * 2)
		"e":
			body.position = Vector2((ROOM_W - 0.5) * TILE, ROOM_H * TILE * 0.5)
			rs.size = Vector2(TILE, TILE * 2)
			vis.position = Vector2((ROOM_W - 1) * TILE, ROOM_H * TILE * 0.5 - TILE)
			vis.size = Vector2(TILE, TILE * 2)
	cs.shape = rs
	body.add_child(cs)
	world.add_child(body)
	world.add_child(vis)
	var lock := ColorRect.new()
	lock.color = accent_c.lightened(0.2)
	lock.size = Vector2(8, 8)
	lock.position = body.position - Vector2(4, 4)
	world.add_child(lock)


func _add_door_trigger(dir_name: String, target_id: int, to_boss: bool, locked: bool, floor_c: Color, accent_c: Color) -> void:
	var gap := ColorRect.new()
	gap.color = floor_c.lightened(0.1)
	var frame_a := ColorRect.new()
	frame_a.color = accent_c.darkened(0.15)
	var frame_b := ColorRect.new()
	frame_b.color = accent_c
	var arrow := ColorRect.new()
	arrow.color = accent_c.lightened(0.35)
	match dir_name:
		"n":
			gap.position = Vector2(ROOM_W * TILE * 0.5 - TILE, 0)
			gap.size = Vector2(TILE * 2, TILE)
			frame_a.position = Vector2(ROOM_W * TILE * 0.5 - TILE - 2, 0)
			frame_a.size = Vector2(2, TILE)
			frame_b.position = Vector2(ROOM_W * TILE * 0.5 + TILE, 0)
			frame_b.size = Vector2(2, TILE)
			arrow.position = Vector2(ROOM_W * TILE * 0.5 - 3, TILE + 2)
			arrow.size = Vector2(6, 4)
		"s":
			gap.position = Vector2(ROOM_W * TILE * 0.5 - TILE, (ROOM_H - 1) * TILE)
			gap.size = Vector2(TILE * 2, TILE)
			frame_a.position = Vector2(ROOM_W * TILE * 0.5 - TILE - 2, (ROOM_H - 1) * TILE)
			frame_a.size = Vector2(2, TILE)
			frame_b.position = Vector2(ROOM_W * TILE * 0.5 + TILE, (ROOM_H - 1) * TILE)
			frame_b.size = Vector2(2, TILE)
			arrow.position = Vector2(ROOM_W * TILE * 0.5 - 3, (ROOM_H - 1) * TILE - 6)
			arrow.size = Vector2(6, 4)
		"w":
			gap.position = Vector2(0, ROOM_H * TILE * 0.5 - TILE)
			gap.size = Vector2(TILE, TILE * 2)
			frame_a.position = Vector2(0, ROOM_H * TILE * 0.5 - TILE - 2)
			frame_a.size = Vector2(TILE, 2)
			frame_b.position = Vector2(0, ROOM_H * TILE * 0.5 + TILE)
			frame_b.size = Vector2(TILE, 2)
			arrow.position = Vector2(TILE + 2, ROOM_H * TILE * 0.5 - 3)
			arrow.size = Vector2(4, 6)
		"e":
			gap.position = Vector2((ROOM_W - 1) * TILE, ROOM_H * TILE * 0.5 - TILE)
			gap.size = Vector2(TILE, TILE * 2)
			frame_a.position = Vector2((ROOM_W - 1) * TILE, ROOM_H * TILE * 0.5 - TILE - 2)
			frame_a.size = Vector2(TILE, 2)
			frame_b.position = Vector2((ROOM_W - 1) * TILE, ROOM_H * TILE * 0.5 + TILE)
			frame_b.size = Vector2(TILE, 2)
			arrow.position = Vector2((ROOM_W - 1) * TILE - 6, ROOM_H * TILE * 0.5 - 3)
			arrow.size = Vector2(4, 6)
	if not locked:
		world.add_child(gap)
		world.add_child(frame_a)
		world.add_child(frame_b)
		world.add_child(arrow)
	var door_area := Area2D.new()
	door_area.name = "Door_%s" % dir_name
	door_area.set_meta("dir", dir_name)
	door_area.set_meta("target", target_id)
	door_area.set_meta("to_boss", to_boss)
	door_area.set_meta("locked", locked)
	door_area.collision_layer = 0
	door_area.collision_mask = 4
	door_area.monitoring = true
	door_area.monitorable = true
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	# Large trigger zone well inside the room
	match dir_name:
		"n":
			door_area.position = Vector2(ROOM_W * TILE * 0.5, TILE + 10)
			rs.size = Vector2(TILE * 2.2, 18)
		"s":
			door_area.position = Vector2(ROOM_W * TILE * 0.5, (ROOM_H - 1) * TILE - 10)
			rs.size = Vector2(TILE * 2.2, 18)
		"w":
			door_area.position = Vector2(TILE + 10, ROOM_H * TILE * 0.5)
			rs.size = Vector2(18, TILE * 2.2)
		"e":
			door_area.position = Vector2((ROOM_W - 1) * TILE - 10, ROOM_H * TILE * 0.5)
			rs.size = Vector2(18, TILE * 2.2)
	cs.shape = rs
	door_area.add_child(cs)
	world.add_child(door_area)


func _draw_room_props(accent_c: Color, wall_c: Color, room: Dictionary) -> void:
	for p in [Vector2(TILE * 2.8, TILE * 2.5), Vector2(TILE * 12.5, TILE * 2.5), Vector2(TILE * 2.8, TILE * 7.2), Vector2(TILE * 12.5, TILE * 7.2)]:
		_draw_pillar(p, wall_c, accent_c)
	for tp in [
		Vector2(TILE * 2.2, TILE * 1.35), Vector2(TILE * 13.5, TILE * 1.35),
		Vector2(TILE * 2.2, TILE * 8.6), Vector2(TILE * 13.5, TILE * 8.6),
	]:
		var bracket := ColorRect.new()
		bracket.color = Color(0.32, 0.28, 0.22)
		bracket.size = Vector2(8, 4)
		bracket.position = tp + Vector2(-2, 7)
		world.add_child(bracket)
		var flame := ColorRect.new()
		flame.color = Color(1.0, 0.62, 0.18, 0.95)
		flame.size = Vector2(5, 7)
		flame.position = tp
		world.add_child(flame)
		_torch_nodes.append(flame)
		var glow := ColorRect.new()
		glow.color = Color(1.0, 0.55, 0.1, 0.18)
		glow.size = Vector2(14, 14)
		glow.position = tp + Vector2(-4, -3)
		world.add_child(glow)
	for i in range(8):
		var r := ColorRect.new()
		r.color = wall_c.darkened(0.05 + (i % 3) * 0.04)
		r.size = Vector2(4 + (i % 4), 2 + (i % 3))
		r.position = Vector2(TILE * (3.5 + (i % 5) * 1.6), TILE * (7.8 + (i % 3) * 0.4))
		world.add_child(r)
	for bx in [TILE * 5.0, TILE * 10.0]:
		var pole := ColorRect.new()
		pole.color = Color(0.4, 0.35, 0.25)
		pole.size = Vector2(2, 18)
		pole.position = Vector2(bx, TILE * 1.2)
		world.add_child(pole)
		var cloth := ColorRect.new()
		cloth.color = accent_c.darkened(0.1)
		cloth.size = Vector2(12, 16)
		cloth.position = Vector2(bx - 5, TILE * 1.35)
		world.add_child(cloth)
		var stripe := ColorRect.new()
		stripe.color = accent_c.lightened(0.2)
		stripe.size = Vector2(12, 3)
		stripe.position = cloth.position + Vector2(0, 5)
		world.add_child(stripe)
	var kind := str(room.get("kind", "empty"))
	if kind == "boss":
		var banner := ColorRect.new()
		banner.color = Color(0.42, 0.1, 0.12, 0.85)
		banner.position = Vector2(TILE * 4.5, TILE * 1.55)
		banner.size = Vector2(TILE * 7, 12)
		world.add_child(banner)
		var skull := ColorRect.new()
		skull.color = Color(0.85, 0.8, 0.7)
		skull.size = Vector2(8, 8)
		skull.position = Vector2(ROOM_W * TILE * 0.5 - 4, TILE * 1.7)
		world.add_child(skull)


func _draw_theme_scenery(accent_c: Color, wall_c: Color, floor_c: Color) -> void:
	var theme_name := str(_theme.get("name", "")).to_lower()
	if "cave" in theme_name or "mine" in theme_name or "catacomb" in theme_name:
		for i in range(6):
			var rock := ColorRect.new()
			rock.color = wall_c.lightened(0.05)
			rock.size = Vector2(6 + i % 3, 10 + i % 5)
			rock.position = Vector2(TILE * (3 + i * 1.7), TILE * 8.2 - (i % 2) * 4)
			world.add_child(rock)
			if i % 2 == 0:
				var body := StaticBody2D.new()
				body.position = rock.position + rock.size * 0.5
				body.collision_layer = 1
				var cs := CollisionShape2D.new()
				var rs := RectangleShape2D.new()
				rs.size = rock.size
				cs.shape = rs
				body.add_child(cs)
				world.add_child(body)
	elif "forest" in theme_name or "thorn" in theme_name:
		for i in range(5):
			var root := ColorRect.new()
			root.color = Color(0.25, 0.4, 0.18)
			root.size = Vector2(14, 3)
			root.position = Vector2(TILE * (2.5 + i * 2.2), TILE * (3.5 + (i % 3)))
			world.add_child(root)
			var leaf := ColorRect.new()
			leaf.color = accent_c
			leaf.size = Vector2(5, 5)
			leaf.position = root.position + Vector2(4, -4)
			world.add_child(leaf)
	elif "tower" in theme_name or "ruin" in theme_name or "ashen" in theme_name:
		for wx in [TILE * 4.0, TILE * 11.0]:
			var niche := ColorRect.new()
			niche.color = floor_c.darkened(0.25)
			niche.size = Vector2(14, 18)
			niche.position = Vector2(wx, TILE * 1.15)
			world.add_child(niche)
			var pane := ColorRect.new()
			pane.color = Color(accent_c.r, accent_c.g, accent_c.b, 0.35)
			pane.size = Vector2(10, 12)
			pane.position = niche.position + Vector2(2, 3)
			world.add_child(pane)
	elif "crypt" in theme_name or "keep" in theme_name:
		for i in range(3):
			var coffin := ColorRect.new()
			coffin.color = wall_c.darkened(0.15)
			coffin.size = Vector2(18, 8)
			coffin.position = Vector2(TILE * (3.5 + i * 3.5), TILE * 7.6)
			world.add_child(coffin)
			var lid := ColorRect.new()
			lid.color = accent_c.darkened(0.25)
			lid.size = Vector2(18, 3)
			lid.position = coffin.position + Vector2(0, -2)
			world.add_child(lid)
	else:
		for i in range(4):
			var crate := ColorRect.new()
			crate.color = Color(0.42, 0.28, 0.14)
			crate.size = Vector2(12, 12)
			crate.position = Vector2(TILE * (3.2 + i * 2.5), TILE * 7.5)
			world.add_child(crate)
			var band := ColorRect.new()
			band.color = Color(0.55, 0.45, 0.25)
			band.size = Vector2(12, 2)
			band.position = crate.position + Vector2(0, 5)
			world.add_child(band)
	for corner in [
		Vector2(TILE, TILE), Vector2((ROOM_W - 3) * TILE, TILE),
		Vector2(TILE, (ROOM_H - 3) * TILE), Vector2((ROOM_W - 3) * TILE, (ROOM_H - 3) * TILE),
	]:
		var v := ColorRect.new()
		v.color = Color(0, 0, 0, 0.22)
		v.position = corner
		v.size = Vector2(TILE * 2, TILE * 2)
		world.add_child(v)


func _draw_pillar(pos: Vector2, wall_c: Color, accent_c: Color) -> void:
	var base := ColorRect.new()
	base.color = wall_c.darkened(0.05)
	base.position = pos
	base.size = Vector2(10, 18)
	world.add_child(base)
	var cap := ColorRect.new()
	cap.color = accent_c
	cap.position = pos + Vector2(0, -2)
	cap.size = Vector2(10, 3)
	world.add_child(cap)
	var body := StaticBody2D.new()
	body.position = pos + Vector2(5, 9)
	body.collision_layer = 1
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = Vector2(10, 18)
	cs.shape = rs
	body.add_child(cs)
	world.add_child(body)


func _spawn_chest(has_key: bool, pos: Vector2, accent_c: Color) -> void:
	var area := Area2D.new()
	area.name = "Chest"
	area.position = pos
	area.set_meta("has_key", has_key)
	area.collision_layer = 0
	area.collision_mask = 4
	area.monitoring = true
	# Chest body
	var box := ColorRect.new()
	box.color = Color(0.45, 0.28, 0.12)
	box.size = Vector2(22, 16)
	box.position = Vector2(-11, -8)
	area.add_child(box)
	var lid := ColorRect.new()
	lid.color = Color(0.62, 0.4, 0.16)
	lid.size = Vector2(22, 6)
	lid.position = Vector2(-11, -12)
	area.add_child(lid)
	var band := ColorRect.new()
	band.color = accent_c.lightened(0.15)
	band.size = Vector2(22, 3)
	band.position = Vector2(-11, -2)
	area.add_child(band)
	var lock := ColorRect.new()
	lock.color = Color(0.9, 0.75, 0.25) if has_key else Color(0.55, 0.55, 0.5)
	lock.size = Vector2(4, 4)
	lock.position = Vector2(-2, -1)
	area.add_child(lock)
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
	_enemies.append(e)


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
		# Sandwich or faction energy from chests
		if randf() < 0.45:
			_spawn_pickup("energy", area.position)
			_show_message("%s found in the chest!" % _warrior.energy_item_name())
		else:
			_spawn_pickup("sandwich", area.position)
			_show_message("Sandwich found in the chest!")
	_dungeon["rooms"] = _rooms
	GameState.adventure_dungeon = _dungeon
	area.queue_free()
	# Rebuild doors if key acquired (unlock boss)
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
	# Drops auto-pickup items
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
	var vis := ColorRect.new()
	if kind == "sandwich":
		vis.color = Color(0.85, 0.7, 0.35)
		vis.size = Vector2(12, 8)
		vis.position = Vector2(-6, -4)
		var top := ColorRect.new()
		top.color = Color(0.55, 0.35, 0.15)
		top.size = Vector2(12, 3)
		top.position = Vector2(-6, -6)
		area.add_child(top)
	else:
		vis.color = _warrior.tint_primary
		vis.size = Vector2(8, 14)
		vis.position = Vector2(-4, -7)
		var neck := ColorRect.new()
		neck.color = _warrior.tint_secondary
		neck.size = Vector2(4, 4)
		neck.position = Vector2(-2, -11)
		area.add_child(neck)
	area.add_child(vis)
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
	if _hurt_invuln > 0.0:
		return
	for e in _enemies:
		if not is_instance_valid(e):
			continue
		if not e.call("is_alive_enemy"):
			continue
		if player.global_position.distance_to(e.global_position) < 16.0:
			var dmg: int = int(e.get("contact_damage"))
			_warrior.current_hp = maxi(0, _warrior.current_hp - dmg)
			_hurt_invuln = 0.85
			_show_message("Hit for %d!" % dmg)
			GameState.save_adventure_warrior(_warrior)
			if not _warrior.is_alive():
				_on_player_down()
			_update_hud()
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
	_attack_cd = 0.32
	_attack_anim_t = 0.22
	_attack_anim_special = false
	_do_melee(false)


func _on_special() -> void:
	if _transitioning or _special_cd > 0.0 or _warrior == null:
		return
	if not _warrior.spend_special_energy():
		_show_message("Not enough energy for %s!" % _warrior.special_move)
		_update_hud()
		return
	_special_cd = 0.6
	_attack_cd = 0.4
	_attack_anim_t = 0.28
	_attack_anim_special = true
	GameState.save_adventure_warrior(_warrior)
	_show_message(_warrior.special_move + "!")
	_do_melee(true)
	_update_hud()


func _do_melee(is_special: bool) -> void:
	var reach := 24.0 if is_special else 17.0
	var center := player.position + _facing * reach
	var col := _warrior.tint_accent if is_special else Color(0.85, 0.88, 0.95)
	CombatFx.spawn_slash(world, center, _facing, col, is_special)
	var power := _warrior.special_power if is_special else _warrior.regular_power
	for e in _enemies.duplicate():
		if not is_instance_valid(e):
			continue
		var hit_r := 28.0 if is_special else 18.0
		if e.position.distance_to(center) <= hit_r or e.position.distance_to(player.position) <= hit_r * 0.75:
			var def := 10
			if e.get("warrior") != null:
				def = int(e.warrior.defense)
			var dmg := _warrior.calc_damage(power, def, is_special)
			e.call("take_hit", dmg, player.position)
			CombatFx.spawn_hit_spark(world, e.position, col)


func _check_doors() -> void:
	if _transitioning:
		return
	# Purge dead refs
	var live := 0
	var kept: Array = []
	for e in _enemies:
		if is_instance_valid(e) and e.call("is_alive_enemy"):
			live += 1
			kept.append(e)
	_enemies = kept
	for child in world.get_children():
		if not (child is Area2D and str(child.name).begins_with("Door_")):
			continue
		var area := child as Area2D
		if not _near_door(area):
			continue
		if bool(area.get_meta("locked", false)):
			_show_message("Locked. Find the dungeon key.")
			_door_cooldown = 0.4
			return
		if live > 0:
			_show_message("Defeat the enemies first!")
			_door_cooldown = 0.35
			return
		_enter_room(int(area.get_meta("target")), str(area.get_meta("dir")))
		return


func _near_door(area: Area2D) -> bool:
	if _body_overlaps(area):
		return true
	# Reliable distance fallback — clamp used to block overlap
	return player.position.distance_to(area.position) <= 16.0


func _body_overlaps(area: Area2D) -> bool:
	for body in area.get_overlapping_bodies():
		if body == player:
			return true
	return false


func _enter_room(target_id: int, from_dir: String) -> void:
	_transitioning = true
	_door_cooldown = 0.55
	var spawn := Vector2(ROOM_W * TILE * 0.5, ROOM_H * TILE * 0.5)
	match from_dir:
		"n":
			spawn = Vector2(ROOM_W * TILE * 0.5, (ROOM_H - 2.5) * TILE)
		"s":
			spawn = Vector2(ROOM_W * TILE * 0.5, 2.5 * TILE)
		"w":
			spawn = Vector2((ROOM_W - 2.5) * TILE, ROOM_H * TILE * 0.5)
		"e":
			spawn = Vector2(2.5 * TILE, ROOM_H * TILE * 0.5)
	_build_room(target_id, spawn)
	_transitioning = false
	var room: Dictionary = _rooms[target_id]
	if str(room.get("kind")) == "boss":
		_show_message("%s awaits!" % str(_dungeon.get("boss_name", "Boss")))
	else:
		_show_message("Room %d" % (target_id + 1))


func _update_hud() -> void:
	room_label.text = "%s · R%d/%d" % [str(_dungeon.get("name", "Dungeon")), _current_id + 1, _rooms.size()]
	hp_label.text = "HP %d/%d" % [_warrior.current_hp, _warrior.max_hp]
	energy_label.text = "EN %d/%d" % [_warrior.current_energy, _warrior.max_energy]
	key_label.text = "Key: Yes" if bool(_dungeon.get("has_key", false)) else "Key: —"
	level_label.text = "Lv.%d %s" % [_warrior.level, _warrior.name]
	special_btn.disabled = not _warrior.can_special()
	special_btn.text = "Special (%d)" % Warrior.SPECIAL_ENERGY_COST
	attack_btn.text = "Attack"


func _show_message(msg: String) -> void:
	message_label.text = msg
	_message_timer = 2.4


func _on_leave() -> void:
	GameState.save_adventure_warrior(_warrior)
	GameState.end_adventure()
	get_tree().change_scene_to_file("res://scenes/adventure_lobby.tscn")
