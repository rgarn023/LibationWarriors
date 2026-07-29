extends Control
## 1v1 dungeon fight. Awards XP and rare potion drops.

enum Action { REGULAR, SPECIAL, DEFEND, POTION }

@onready var safe_root: Control = %SafeRoot
@onready var log_label: RichTextLabel = %BattleLog
@onready var player_host: Control = %PlayerHost
@onready var enemy_host: Control = %EnemyHost
@onready var player_info: Label = %PlayerInfo
@onready var enemy_info: Label = %EnemyInfo
@onready var turn_label: Label = %TurnLabel
@onready var btn_regular: Button = %BtnRegular
@onready var btn_special: Button = %BtnSpecial
@onready var btn_defend: Button = %BtnDefend
@onready var btn_potion: Button = %BtnPotion
@onready var btn_flee: Button = %BtnFlee

var hero: Warrior
var foe: Warrior
var hero_defending := false
var foe_defending := false
var battle_over := false
var is_boss := false
var room_id := 0
var dungeon: Dictionary = {}


func _ready() -> void:
	SafeArea.register(safe_root)
	UITheme.style_button(btn_regular, true)
	UITheme.style_button(btn_special)
	UITheme.style_button(btn_defend)
	UITheme.style_button(btn_potion)
	UITheme.style_button(btn_flee)
	btn_regular.pressed.connect(func(): _player_act(Action.REGULAR))
	btn_special.pressed.connect(func(): _player_act(Action.SPECIAL))
	btn_defend.pressed.connect(func(): _player_act(Action.DEFEND))
	btn_potion.pressed.connect(func(): _player_act(Action.POTION))
	btn_flee.pressed.connect(_on_flee)

	var pending: Dictionary = GameState.pending_adventure_battle
	dungeon = GameState.adventure_dungeon
	hero = GameState.get_adventure_warrior()
	if hero == null or pending.is_empty():
		get_tree().change_scene_to_file("res://scenes/adventure_lobby.tscn")
		return
	room_id = int(pending.get("room_id", 0))
	is_boss = bool(pending.get("is_boss", false))
	foe = Warrior.new(pending.get("enemy", {}))
	foe.reset_hp()
	_refresh_portraits()
	_refresh_info()
	_append("[b]%s[/b] engages [b]%s[/b]!" % [hero.name, foe.name])
	if is_boss:
		_append("Boss battle in the %s!" % str(dungeon.get("name", "dungeon")))
	turn_label.text = "Your turn"
	_update_buttons()


func _refresh_portraits() -> void:
	for c in player_host.get_children():
		c.queue_free()
	for c in enemy_host.get_children():
		c.queue_free()
	player_host.add_child(WarriorPortrait.make_portrait(hero, Vector2(130, 160)))
	var ep := WarriorPortrait.make_portrait(foe, Vector2(130, 160))
	enemy_host.add_child(ep)


func _refresh_info() -> void:
	player_info.text = "Lv.%d %s\nHP %d/%d" % [hero.level, hero.name, hero.current_hp, hero.max_hp]
	enemy_info.text = "Lv.%d %s\nHP %d/%d" % [foe.level, foe.name, foe.current_hp, foe.max_hp]
	_update_buttons()


func _update_buttons() -> void:
	var pots := int(dungeon.get("potions_small", 0)) + int(dungeon.get("potions_large", 0))
	btn_potion.disabled = battle_over or pots <= 0 or hero.current_hp >= hero.max_hp
	btn_regular.disabled = battle_over
	btn_special.disabled = battle_over
	btn_defend.disabled = battle_over
	btn_flee.disabled = battle_over


func _append(msg: String) -> void:
	log_label.append_text(msg + "\n")


func _player_act(action: Action) -> void:
	if battle_over:
		return
	hero_defending = false
	match action:
		Action.REGULAR:
			var dmg := hero.calc_damage(hero.regular_power, foe.defense, false)
			if foe_defending:
				dmg = maxi(1, int(dmg * 0.5))
			foe.current_hp = maxi(0, foe.current_hp - dmg)
			_append("%s used %s for %d!" % [hero.name, hero.regular_move, dmg])
		Action.SPECIAL:
			var dmg2 := hero.calc_damage(hero.special_power, foe.defense, true)
			if foe_defending:
				dmg2 = maxi(1, int(dmg2 * 0.5))
			foe.current_hp = maxi(0, foe.current_hp - dmg2)
			_append("%s unleashed %s for %d!" % [hero.name, hero.special_move, dmg2])
		Action.DEFEND:
			hero_defending = true
			_append("%s braces for impact." % hero.name)
		Action.POTION:
			if not _use_potion():
				return
	foe_defending = false
	_refresh_info()
	if not foe.is_alive():
		_win()
		return
	await get_tree().create_timer(0.35).timeout
	_enemy_turn()


func _use_potion() -> bool:
	var large := int(dungeon.get("potions_large", 0))
	var small := int(dungeon.get("potions_small", 0))
	if large > 0:
		dungeon["potions_large"] = large - 1
		var healed := hero.heal(int(hero.max_hp * 0.55))
		_append("Large Potion restored %d HP!" % healed)
	elif small > 0:
		dungeon["potions_small"] = small - 1
		var healed2 := hero.heal(int(hero.max_hp * 0.22))
		_append("Potion restored %d HP!" % healed2)
	else:
		_append("No potions left.")
		return false
	GameState.adventure_dungeon = dungeon
	GameState.save_adventure_warrior(hero)
	return true


func _enemy_turn() -> void:
	if battle_over:
		return
	turn_label.text = "Enemy turn"
	foe_defending = false
	var roll := randf()
	if roll < 0.18:
		foe_defending = true
		_append("%s takes a defensive stance." % foe.name)
	elif roll < 0.55 or is_boss and roll < 0.45:
		var dmg := foe.calc_damage(foe.regular_power, hero.defense, false)
		if hero_defending:
			dmg = maxi(1, int(dmg * 0.5))
		hero.current_hp = maxi(0, hero.current_hp - dmg)
		_append("%s hits with %s for %d!" % [foe.name, foe.regular_move, dmg])
	else:
		var dmg2 := foe.calc_damage(foe.special_power, hero.defense, true)
		if hero_defending:
			dmg2 = maxi(1, int(dmg2 * 0.5))
		hero.current_hp = maxi(0, hero.current_hp - dmg2)
		_append("%s uses %s for %d!" % [foe.name, foe.special_move, dmg2])
	GameState.save_adventure_warrior(hero)
	_refresh_info()
	if not hero.is_alive():
		_lose()
		return
	turn_label.text = "Your turn"
	_update_buttons()


func _win() -> void:
	battle_over = true
	turn_label.text = "Victory!"
	var base_xp := 28 + foe.level * 12
	if is_boss:
		base_xp = int(base_xp * 2.4) + 40
	var xp_info := hero.gain_xp(base_xp)
	GameState.save_adventure_warrior(hero)
	var drops := {"small": 0, "large": 0}
	var drop_roll := randf()
	if is_boss:
		if drop_roll < 0.55:
			drops["large"] = 1
		elif drop_roll < 0.9:
			drops["small"] = 1
	else:
		if drop_roll < 0.12:
			drops["large"] = 1
		elif drop_roll < 0.45:
			drops["small"] = 1
	var xp_msg := "Victory! +%d XP" % xp_info["gained"]
	if int(xp_info["levels"]) > 0:
		xp_msg += " — leveled to %d!" % xp_info["level"]
	if drops["large"] > 0:
		xp_msg += " Large Potion drop!"
	elif drops["small"] > 0:
		xp_msg += " Potion drop!"
	_append(xp_msg)
	GameState.pending_adventure_battle = {
		"result": "win",
		"room_id": room_id,
		"boss_cleared": is_boss,
		"drops": drops,
		"xp_message": xp_msg,
	}
	GameState.adventure_dungeon = dungeon
	await get_tree().create_timer(1.2).timeout
	get_tree().change_scene_to_file("res://scenes/dungeon_explore.tscn")


func _lose() -> void:
	battle_over = true
	turn_label.text = "Defeated"
	_append("%s falls..." % hero.name)
	hero.current_hp = 1
	GameState.save_adventure_warrior(hero)
	GameState.pending_adventure_battle = {
		"result": "lose",
		"room_id": room_id,
	}
	await get_tree().create_timer(1.2).timeout
	get_tree().change_scene_to_file("res://scenes/dungeon_explore.tscn")


func _on_flee() -> void:
	if battle_over:
		return
	if is_boss:
		_append("Cannot flee the boss!")
		return
	battle_over = true
	_append("Fled the fight.")
	GameState.save_adventure_warrior(hero)
	GameState.pending_adventure_battle = {
		"result": "flee",
		"room_id": room_id,
	}
	get_tree().change_scene_to_file("res://scenes/dungeon_explore.tscn")
