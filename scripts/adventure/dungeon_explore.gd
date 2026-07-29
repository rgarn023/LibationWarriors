extends Node2D
## Zelda ALttP-style single-room view with door transitions.

const TILE := 16
const ROOM_W := 16
const ROOM_H := 11

@onready var world: Node2D = $World
@onready var player: CharacterBody2D = $Player
@onready var room_label: Label = %RoomLabel
@onready var hp_label: Label = %HpLabel
@onready var key_label: Label = %KeyLabel
@onready var potion_label: Label = %PotionLabel
@onready var level_label: Label = %LevelLabel
@onready var message_label: Label = %MessageLabel
@onready var use_potion_btn: Button = %UsePotionBtn
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
var _pad_dir: Vector2 = Vector2.ZERO
var _interact_cooldown: float = 0.0


func _ready() -> void:
	_warrior = GameState.get_adventure_warrior()
	_dungeon = GameState.adventure_dungeon
	if _warrior == null or _dungeon.is_empty():
		get_tree().change_scene_to_file("res://scenes/adventure_lobby.tscn")
		return
	_theme = _dungeon.get("theme", {})
	_rooms = _dungeon.get("rooms", [])
	_current_id = int(_dungeon.get("current_room", _dungeon.get("start_id", 0)))
	use_potion_btn.pressed.connect(_on_use_potion)
	leave_btn.pressed.connect(_on_leave)
	_wire_pad(pad_up, Vector2(0, -1))
	_wire_pad(pad_down, Vector2(0, 1))
	_wire_pad(pad_left, Vector2(-1, 0))
	_wire_pad(pad_right, Vector2(1, 0))
	UITheme.style_button(use_potion_btn)
	UITheme.style_button(leave_btn)
	var hud_safe: Control = $HUD.get_node_or_null("SafeRoot")
	if hud_safe:
		SafeArea.register(hud_safe)
	_apply_camera()
	if not GameState.pending_adventure_battle.is_empty() and GameState.pending_adventure_battle.has("result"):
		await _handle_combat_return()
	else:
		_build_room(_current_id, Vector2(ROOM_W * TILE * 0.5, ROOM_H * TILE * 0.5))
		_show_message("Entered the %s..." % str(_dungeon.get("name", "Dungeon")))


func _wire_pad(btn: Button, dir: Vector2) -> void:
	btn.button_down.connect(func(): _pad_dir = dir)
	btn.button_up.connect(func():
		if _pad_dir == dir:
			_pad_dir = Vector2.ZERO
	)


func _apply_camera() -> void:
	var cam := Camera2D.new()
	cam.enabled = true
	cam.position = Vector2(ROOM_W * TILE * 0.5, ROOM_H * TILE * 0.5)
	cam.zoom = Vector2(2.2, 2.2)
	add_child(cam)


func _handle_combat_return() -> void:
	var pending: Dictionary = GameState.pending_adventure_battle
	if pending.is_empty() or not pending.has("result"):
		_build_room(_current_id, Vector2(ROOM_W * TILE * 0.5, ROOM_H * TILE * 0.5))
		return
	GameState.pending_adventure_battle = {}
	_warrior = GameState.get_adventure_warrior()
	_dungeon = GameState.adventure_dungeon
	_rooms = _dungeon.get("rooms", [])
	var result: String = str(pending.get("result", ""))
	var room_id: int = int(pending.get("room_id", _current_id))
	_current_id = room_id
	if result == "win":
		if room_id >= 0 and room_id < _rooms.size():
			_rooms[room_id]["cleared"] = true
			_rooms[room_id]["enemy"] = {}
		_dungeon["rooms"] = _rooms
		var drops: Dictionary = pending.get("drops", {})
		_dungeon["potions_small"] = int(_dungeon.get("potions_small", 0)) + int(drops.get("small", 0))
		_dungeon["potions_large"] = int(_dungeon.get("potions_large", 0)) + int(drops.get("large", 0))
		GameState.adventure_dungeon = _dungeon
		var xp_msg: String = str(pending.get("xp_message", "Victory!"))
		_build_room(_current_id, Vector2(ROOM_W * TILE * 0.5, ROOM_H * TILE * 0.55))
		_show_message(xp_msg)
		if pending.get("boss_cleared", false):
			await get_tree().create_timer(0.8).timeout
			_show_message("Boss defeated! The %s falls quiet." % str(_dungeon.get("name", "dungeon")))
	elif result == "lose":
		_build_room(_current_id, Vector2(ROOM_W * TILE * 0.5, ROOM_H * TILE * 0.5))
		_show_message("Defeated... retreat to recover.")
		GameState.save_adventure_warrior(_warrior)
		await get_tree().create_timer(1.4).timeout
		GameState.end_adventure()
		get_tree().change_scene_to_file("res://scenes/adventure_lobby.tscn")
		return
	else:
		_build_room(_current_id, Vector2(ROOM_W * TILE * 0.5, ROOM_H * TILE * 0.5))
	_update_hud()


func _process(delta: float) -> void:
	if _message_timer > 0.0:
		_message_timer -= delta
		if _message_timer <= 0.0:
			message_label.text = ""
	if _interact_cooldown > 0.0:
		_interact_cooldown -= delta


func _physics_process(_delta: float) -> void:
	if _transitioning or _warrior == null:
		return
	var dir := _pad_dir
	if Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A):
		dir.x -= 1
	if Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D):
		dir.x += 1
	if Input.is_action_pressed("ui_up") or Input.is_key_pressed(KEY_W):
		dir.y -= 1
	if Input.is_action_pressed("ui_down") or Input.is_key_pressed(KEY_S):
		dir.y += 1
	player.velocity = dir.normalized() * 95.0
	player.move_and_slide()
	_check_doors()
	if _interact_cooldown <= 0.0:
		_check_interactions()


func _build_room(room_id: int, spawn: Vector2) -> void:
	for c in world.get_children():
		c.queue_free()
	_current_id = room_id
	_dungeon["current_room"] = room_id
	var room: Dictionary = _rooms[room_id]
	room["visited"] = true
	var floor_c: Color = _theme.get("floor", Color(0.2, 0.2, 0.22))
	var wall_c: Color = _theme.get("wall", Color(0.35, 0.32, 0.3))
	var accent_c: Color = _theme.get("accent", Color(0.7, 0.55, 0.35))

	var floor_rect := ColorRect.new()
	floor_rect.color = floor_c
	floor_rect.size = Vector2(ROOM_W * TILE, ROOM_H * TILE)
	world.add_child(floor_rect)

	for y in range(1, ROOM_H - 1):
		for x in range(1, ROOM_W - 1):
			if (x + y) % 4 == 0:
				var dot := ColorRect.new()
				dot.color = floor_c.darkened(0.1)
				dot.size = Vector2(2, 2)
				dot.position = Vector2(x * TILE + 7, y * TILE + 7)
				world.add_child(dot)

	var doors: Dictionary = room.get("doors", {})
	_add_wall_with_gaps(wall_c, doors, floor_c, accent_c)

	# Decor
	for i in range(3):
		var deco := ColorRect.new()
		deco.color = accent_c
		deco.size = Vector2(4, 4)
		deco.position = Vector2(TILE * (3 + i * 4) + 6, TILE * 2 + 4)
		world.add_child(deco)

	var kind: String = str(room.get("kind", "empty"))
	var cleared: bool = bool(room.get("cleared", false))
	var looted: bool = bool(room.get("looted", false))

	if kind == "key" and not looted:
		_add_interactable("chest_key", Vector2(ROOM_W * TILE * 0.5, ROOM_H * TILE * 0.4), accent_c.lightened(0.25), Vector2(16, 14))
	elif kind == "treasure" and not looted:
		_add_interactable("chest", Vector2(ROOM_W * TILE * 0.5, ROOM_H * TILE * 0.4), accent_c.lightened(0.15), Vector2(16, 14))

	if kind == "enemy" and not cleared and not room.get("enemy", {}).is_empty():
		_add_interactable("enemies", Vector2(ROOM_W * TILE * 0.5, ROOM_H * TILE * 0.58), Color(0.72, 0.22, 0.22), Vector2(20, 20))
	if kind == "boss" and not cleared:
		_add_interactable("boss", Vector2(ROOM_W * TILE * 0.5, ROOM_H * TILE * 0.5), Color(0.85, 0.18, 0.28), Vector2(30, 30))

	_refresh_player_visual()
	player.position = spawn
	player.z_index = 10
	GameState.adventure_dungeon = _dungeon
	_update_hud()


func _add_wall_with_gaps(wall_c: Color, doors: Dictionary, floor_c: Color, accent_c: Color) -> void:
	# Top / bottom / left / right walls with door gaps
	_wall_segment(wall_c, Rect2(0, 0, ROOM_W * TILE, TILE), not doors.has("n"), Vector2(ROOM_W * TILE * 0.5 - TILE, 0), Vector2(TILE * 2, TILE), doors.has("n"))
	_wall_segment(wall_c, Rect2(0, (ROOM_H - 1) * TILE, ROOM_W * TILE, TILE), not doors.has("s"), Vector2(ROOM_W * TILE * 0.5 - TILE, (ROOM_H - 1) * TILE), Vector2(TILE * 2, TILE), doors.has("s"))
	_wall_segment(wall_c, Rect2(0, 0, TILE, ROOM_H * TILE), not doors.has("w"), Vector2(0, ROOM_H * TILE * 0.5 - TILE), Vector2(TILE, TILE * 2), doors.has("w"))
	_wall_segment(wall_c, Rect2((ROOM_W - 1) * TILE, 0, TILE, ROOM_H * TILE), not doors.has("e"), Vector2((ROOM_W - 1) * TILE, ROOM_H * TILE * 0.5 - TILE), Vector2(TILE, TILE * 2), doors.has("e"))

	for dir_name in doors.keys():
		var target_id: int = int(doors[dir_name])
		var to_boss := int(target_id) == int(_dungeon.get("boss_id", -1))
		var locked := to_boss and not bool(_dungeon.get("has_key", false)) and not bool(_dungeon.get("boss_unlocked", false))
		_add_door_trigger(dir_name, target_id, to_boss, locked, floor_c, accent_c)


func _wall_segment(wall_c: Color, full: Rect2, solid: bool, gap_pos: Vector2, gap_size: Vector2, _has_door: bool) -> void:
	if solid:
		_add_wall_rect(full, wall_c)
		return
	# Split wall around gap
	if full.size.y == TILE: # horizontal wall
		var left_w := gap_pos.x - full.position.x
		var right_x := gap_pos.x + gap_size.x
		if left_w > 0:
			_add_wall_rect(Rect2(full.position.x, full.position.y, left_w, TILE), wall_c)
		var right_w := full.position.x + full.size.x - right_x
		if right_w > 0:
			_add_wall_rect(Rect2(right_x, full.position.y, right_w, TILE), wall_c)
	else: # vertical wall
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
	var body := StaticBody2D.new()
	body.position = r.position + r.size * 0.5
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = r.size
	shape.shape = rect
	body.add_child(shape)
	world.add_child(body)


func _add_door_trigger(dir_name: String, target_id: int, to_boss: bool, locked: bool, floor_c: Color, accent_c: Color) -> void:
	var gap := ColorRect.new()
	gap.color = floor_c
	var marker := ColorRect.new()
	marker.size = Vector2(8, 8)
	var door_area := Area2D.new()
	door_area.name = "Door_%s" % dir_name
	door_area.set_meta("dir", dir_name)
	door_area.set_meta("target", target_id)
	door_area.set_meta("to_boss", to_boss)
	door_area.set_meta("locked", locked)
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	match dir_name:
		"n":
			gap.position = Vector2(ROOM_W * TILE * 0.5 - TILE, 0)
			gap.size = Vector2(TILE * 2, TILE)
			marker.position = Vector2(ROOM_W * TILE * 0.5 - 4, 4)
			door_area.position = Vector2(ROOM_W * TILE * 0.5, TILE * 0.55)
			rs.size = Vector2(TILE * 1.6, TILE * 0.9)
		"s":
			gap.position = Vector2(ROOM_W * TILE * 0.5 - TILE, (ROOM_H - 1) * TILE)
			gap.size = Vector2(TILE * 2, TILE)
			marker.position = Vector2(ROOM_W * TILE * 0.5 - 4, (ROOM_H - 1) * TILE + 8)
			door_area.position = Vector2(ROOM_W * TILE * 0.5, (ROOM_H - 0.55) * TILE)
			rs.size = Vector2(TILE * 1.6, TILE * 0.9)
		"w":
			gap.position = Vector2(0, ROOM_H * TILE * 0.5 - TILE)
			gap.size = Vector2(TILE, TILE * 2)
			marker.position = Vector2(4, ROOM_H * TILE * 0.5 - 4)
			door_area.position = Vector2(TILE * 0.55, ROOM_H * TILE * 0.5)
			rs.size = Vector2(TILE * 0.9, TILE * 1.6)
		"e":
			gap.position = Vector2((ROOM_W - 1) * TILE, ROOM_H * TILE * 0.5 - TILE)
			gap.size = Vector2(TILE, TILE * 2)
			marker.position = Vector2((ROOM_W - 1) * TILE + 8, ROOM_H * TILE * 0.5 - 4)
			door_area.position = Vector2((ROOM_W - 0.55) * TILE, ROOM_H * TILE * 0.5)
			rs.size = Vector2(TILE * 0.9, TILE * 1.6)
	world.add_child(gap)
	if locked:
		marker.color = Color(0.92, 0.78, 0.2)
	elif to_boss:
		marker.color = Color(0.9, 0.3, 0.3)
	else:
		marker.color = accent_c.lightened(0.25)
	world.add_child(marker)
	cs.shape = rs
	door_area.add_child(cs)
	# Monitoring bodies
	door_area.collision_layer = 0
	door_area.collision_mask = 1
	door_area.monitoring = true
	world.add_child(door_area)


func _add_interactable(kind: String, pos: Vector2, color: Color, size: Vector2) -> void:
	var area := Area2D.new()
	area.name = "Interact_%s" % kind
	area.position = pos
	area.set_meta("kind", kind)
	area.collision_layer = 0
	area.collision_mask = 1
	area.monitoring = true
	var vis := ColorRect.new()
	vis.color = color
	vis.size = size
	vis.position = -size * 0.5
	area.add_child(vis)
	var inner := ColorRect.new()
	inner.color = color.lightened(0.3)
	inner.size = size * 0.4
	inner.position = -inner.size * 0.5
	area.add_child(inner)
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = size * 1.15
	cs.shape = rs
	area.add_child(cs)
	world.add_child(area)


func _refresh_player_visual() -> void:
	var spr: Sprite2D = player.get_node_or_null("Sprite")
	if spr == null:
		spr = Sprite2D.new()
		spr.name = "Sprite"
		player.add_child(spr)
	if ResourceLoader.exists(_warrior.sprite_path()):
		spr.texture = load(_warrior.sprite_path())
	spr.modulate = _warrior.display_modulate()
	spr.scale = Vector2(0.42, 0.42)
	spr.centered = true
	# Ensure player collides
	player.collision_layer = 1
	player.collision_mask = 1


func _check_doors() -> void:
	if _transitioning:
		return
	for child in world.get_children():
		if not (child is Area2D and str(child.name).begins_with("Door_")):
			continue
		var area := child as Area2D
		if not _overlaps_player(area):
			continue
		if bool(area.get_meta("locked", false)):
			_show_message("Locked. Find the dungeon key.")
			_bounce_inward(str(area.get_meta("dir")))
			_interact_cooldown = 0.4
			return
		_enter_room(int(area.get_meta("target")), str(area.get_meta("dir")))
		return


func _bounce_inward(dir_name: String) -> void:
	match dir_name:
		"n":
			player.position.y = TILE * 2.2
		"s":
			player.position.y = (ROOM_H - 2.2) * TILE
		"w":
			player.position.x = TILE * 2.2
		"e":
			player.position.x = (ROOM_W - 2.2) * TILE


func _enter_room(target_id: int, from_dir: String) -> void:
	_transitioning = true
	_interact_cooldown = 0.35
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
		_show_message("Room %d" % (target_id + 1))


func _check_interactions() -> void:
	for child in world.get_children():
		if not (child is Area2D and str(child.name).begins_with("Interact_")):
			continue
		var area := child as Area2D
		if not _overlaps_player(area):
			continue
		var kind: String = str(area.get_meta("kind"))
		_interact_cooldown = 0.6
		match kind:
			"chest_key":
				_open_key_chest()
			"chest":
				_open_treasure()
			"enemies":
				_start_combat(false)
			"boss":
				_start_combat(true)
		return


func _overlaps_player(area: Area2D) -> bool:
	for body in area.get_overlapping_bodies():
		if body == player:
			return true
	# Fallback distance check (Areas sometimes lag a frame)
	return area.global_position.distance_to(player.global_position) < 18.0


func _open_key_chest() -> void:
	var room: Dictionary = _rooms[_current_id]
	if bool(room.get("looted", false)):
		return
	room["looted"] = true
	_dungeon["has_key"] = true
	_dungeon["boss_unlocked"] = true
	_rooms[_current_id] = room
	_dungeon["rooms"] = _rooms
	GameState.adventure_dungeon = _dungeon
	_show_message("You found the Dungeon Key!")
	_build_room(_current_id, player.position)


func _open_treasure() -> void:
	var room: Dictionary = _rooms[_current_id]
	if bool(room.get("looted", false)):
		return
	room["looted"] = true
	_rooms[_current_id] = room
	if randf() < 0.28:
		_dungeon["potions_large"] = int(_dungeon.get("potions_large", 0)) + 1
		_show_message("Chest: Large Potion!")
	else:
		_dungeon["potions_small"] = int(_dungeon.get("potions_small", 0)) + 1
		_show_message("Chest: Potion!")
	_dungeon["rooms"] = _rooms
	GameState.adventure_dungeon = _dungeon
	_build_room(_current_id, player.position)


func _start_combat(is_boss: bool) -> void:
	var room: Dictionary = _rooms[_current_id]
	var enemy_wrap: Dictionary = room.get("enemy", {})
	if enemy_wrap.is_empty():
		return
	GameState.save_adventure_warrior(_warrior)
	GameState.adventure_dungeon = _dungeon
	GameState.pending_adventure_battle = {
		"room_id": _current_id,
		"is_boss": is_boss,
		"enemy": enemy_wrap.get("warrior", enemy_wrap),
		"started": true,
	}
	get_tree().change_scene_to_file("res://scenes/dungeon_combat.tscn")


func _update_hud() -> void:
	_warrior = GameState.get_adventure_warrior()
	room_label.text = "%s · R%d/%d" % [str(_dungeon.get("name", "Dungeon")), _current_id + 1, _rooms.size()]
	hp_label.text = "HP %d/%d" % [_warrior.current_hp, _warrior.max_hp]
	key_label.text = "Key: Yes" if bool(_dungeon.get("has_key", false)) else "Key: —"
	potion_label.text = "Potions S:%d L:%d" % [int(_dungeon.get("potions_small", 0)), int(_dungeon.get("potions_large", 0))]
	level_label.text = "Lv.%d %s" % [_warrior.level, _warrior.name]
	var pots := int(_dungeon.get("potions_small", 0)) + int(_dungeon.get("potions_large", 0))
	use_potion_btn.disabled = pots <= 0 or _warrior.current_hp >= _warrior.max_hp


func _show_message(msg: String) -> void:
	message_label.text = msg
	_message_timer = 2.6


func _on_use_potion() -> void:
	_warrior = GameState.get_adventure_warrior()
	if _warrior.current_hp >= _warrior.max_hp:
		return
	var large := int(_dungeon.get("potions_large", 0))
	var small := int(_dungeon.get("potions_small", 0))
	if large > 0:
		_dungeon["potions_large"] = large - 1
		_warrior.heal(int(_warrior.max_hp * 0.55))
		_show_message("Large Potion! Big heal.")
	elif small > 0:
		_dungeon["potions_small"] = small - 1
		_warrior.heal(int(_warrior.max_hp * 0.22))
		_show_message("Potion restored some HP.")
	else:
		return
	GameState.adventure_dungeon = _dungeon
	GameState.save_adventure_warrior(_warrior)
	_update_hud()


func _on_leave() -> void:
	GameState.save_adventure_warrior(_warrior)
	GameState.end_adventure()
	get_tree().change_scene_to_file("res://scenes/adventure_lobby.tscn")
