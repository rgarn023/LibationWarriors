extends Control
## Turn-based 3v3 party battle. Each warrior: Regular Attack + Special Attack + Defend.

enum Action { REGULAR, SPECIAL, DEFEND }

@onready var log_label: RichTextLabel = %BattleLog
@onready var player_row: HBoxContainer = %PlayerRow
@onready var enemy_row: HBoxContainer = %EnemyRow
@onready var btn_regular: Button = %BtnRegular
@onready var btn_special: Button = %BtnSpecial
@onready var btn_defend: Button = %BtnDefend
@onready var btn_back: Button = %BtnBack
@onready var turn_label: Label = %TurnLabel
@onready var target_hint: Label = %TargetHint

var player_party: Array[Warrior] = []
var enemy_party: Array[Warrior] = []
var player_defending: Array[bool] = [false, false, false]
var enemy_defending: Array[bool] = [false, false, false]
var active_player_index := 0
var selected_target := 0
var battle_over := false
var player_panels: Array[PanelContainer] = []
var enemy_panels: Array[PanelContainer] = []


func _ready() -> void:
	UITheme.style_button(btn_regular, true)
	UITheme.style_button(btn_special)
	UITheme.style_button(btn_defend)
	UITheme.style_button(btn_back)
	btn_back.pressed.connect(func():
		NetworkManager.close()
		get_tree().change_scene_to_file("res://scenes/battle_lobby.tscn")
	)
	btn_regular.pressed.connect(func(): _player_act(Action.REGULAR))
	btn_special.pressed.connect(func(): _player_act(Action.SPECIAL))
	btn_defend.pressed.connect(func(): _player_act(Action.DEFEND))
	_setup_parties()
	_rebuild_ui()
	_append_log("[b]Battle begins![/b] Mode: %s" % GameState.last_battle_mode.capitalize())
	_start_player_turn()


func _setup_parties() -> void:
	player_party = GameState.get_party_warriors()
	enemy_party.clear()
	for d in GameState.pending_enemy_party:
		var w := Warrior.new(d)
		w.reset_hp()
		enemy_party.append(w)
	if enemy_party.is_empty():
		enemy_party = GameState.make_training_enemies()
	# Ensure size 3
	while player_party.size() < 3:
		player_party.append(WarriorFactory.generate("FILL-P-%d" % player_party.size(), FactionData.Category.NON_ALCOHOLIC))
	while enemy_party.size() < 3:
		enemy_party.append(WarriorFactory.generate("FILL-E-%d" % enemy_party.size(), FactionData.Category.BEER))


func _rebuild_ui() -> void:
	for c in player_row.get_children():
		c.queue_free()
	for c in enemy_row.get_children():
		c.queue_free()
	player_panels.clear()
	enemy_panels.clear()
	for i in player_party.size():
		var p := _make_fighter_panel(player_party[i], false, i)
		player_row.add_child(p)
		player_panels.append(p)
	for i in enemy_party.size():
		var p := _make_fighter_panel(enemy_party[i], true, i)
		enemy_row.add_child(p)
		enemy_panels.append(p)


func _make_fighter_panel(w: Warrior, is_enemy: bool, index: int) -> PanelContainer:
	var panel := PanelContainer.new()
	UITheme.style_panel(panel)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	panel.add_child(v)
	var tr := TextureRect.new()
	tr.texture = UITheme.load_texture(w.preview_path())
	tr.custom_minimum_size = Vector2(72, 72)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.modulate = Color(w.tint_primary.r * 0.4 + 0.6, w.tint_primary.g * 0.4 + 0.6, w.tint_primary.b * 0.4 + 0.6, 1)
	v.add_child(tr)
	var name_l := Label.new()
	name_l.text = w.name
	name_l.autowrap_mode = TextServer.AUTOWRAP_WORD
	name_l.add_theme_font_size_override("font_size", 14)
	name_l.add_theme_color_override("font_color", UITheme.C_TEXT)
	v.add_child(name_l)
	var hp := Label.new()
	hp.name = "HPLabel"
	hp.text = "HP %d/%d" % [w.current_hp, w.max_hp]
	hp.add_theme_font_size_override("font_size", 13)
	hp.add_theme_color_override("font_color", UITheme.C_ACCENT)
	v.add_child(hp)
	if is_enemy:
		var pick := Button.new()
		pick.text = "Target"
		pick.add_theme_font_size_override("font_size", 14)
		UITheme.style_button(pick)
		pick.custom_minimum_size = Vector2(0, 36)
		var idx := index
		pick.pressed.connect(func():
			selected_target = idx
			target_hint.text = "Targeting: %s" % enemy_party[idx].name
			_refresh_highlights()
		)
		v.add_child(pick)
	return panel


func _refresh_hp_labels() -> void:
	for i in player_party.size():
		var hp: Label = player_panels[i].find_child("HPLabel", true, false)
		if hp:
			hp.text = "HP %d/%d%s" % [player_party[i].current_hp, player_party[i].max_hp, " [DEF]" if player_defending[i] else ""]
			if not player_party[i].is_alive():
				player_panels[i].modulate = Color(0.4, 0.4, 0.4, 1)
	for i in enemy_party.size():
		var hp: Label = enemy_panels[i].find_child("HPLabel", true, false)
		if hp:
			hp.text = "HP %d/%d%s" % [enemy_party[i].current_hp, enemy_party[i].max_hp, " [DEF]" if enemy_defending[i] else ""]
			if not enemy_party[i].is_alive():
				enemy_panels[i].modulate = Color(0.4, 0.4, 0.4, 1)


func _refresh_highlights() -> void:
	for i in player_panels.size():
		player_panels[i].self_modulate = Color(1.2, 1.1, 0.8) if i == active_player_index and player_party[i].is_alive() else Color.WHITE
	for i in enemy_panels.size():
		enemy_panels[i].self_modulate = Color(1.2, 0.85, 0.85) if i == selected_target and enemy_party[i].is_alive() else Color.WHITE


func _append_log(msg: String) -> void:
	log_label.append_text(msg + "\n")


func _alive_indices(party: Array[Warrior]) -> Array[int]:
	var out: Array[int] = []
	for i in party.size():
		if party[i].is_alive():
			out.append(i)
	return out


func _start_player_turn() -> void:
	if battle_over:
		return
	player_defending = [false, false, false]
	var alive := _alive_indices(player_party)
	if alive.is_empty():
		_end_battle(false)
		return
	if _alive_indices(enemy_party).is_empty():
		_end_battle(true)
		return
	active_player_index = alive[0]
	var targets := _alive_indices(enemy_party)
	selected_target = targets[0]
	_set_actions_enabled(true)
	_update_action_labels()
	turn_label.text = "Your turn — %s" % player_party[active_player_index].name
	target_hint.text = "Targeting: %s" % enemy_party[selected_target].name
	_refresh_hp_labels()
	_refresh_highlights()


func _update_action_labels() -> void:
	var w := player_party[active_player_index]
	btn_regular.text = w.regular_move
	btn_special.text = w.special_move
	btn_defend.text = "Defend"


func _set_actions_enabled(enabled: bool) -> void:
	btn_regular.disabled = not enabled
	btn_special.disabled = not enabled
	btn_defend.disabled = not enabled


func _player_act(action: Action) -> void:
	if battle_over:
		return
	var attacker := player_party[active_player_index]
	if not attacker.is_alive():
		return
	_set_actions_enabled(false)
	match action:
		Action.DEFEND:
			player_defending[active_player_index] = true
			_append_log("%s braces for impact. (+DEF)" % attacker.name)
		Action.REGULAR, Action.SPECIAL:
			if not enemy_party[selected_target].is_alive():
				var targets := _alive_indices(enemy_party)
				if targets.is_empty():
					_end_battle(true)
					return
				selected_target = targets[0]
			var target := enemy_party[selected_target]
			var is_special := action == Action.SPECIAL
			var power := attacker.special_power if is_special else attacker.regular_power
			var move_name := attacker.special_move if is_special else attacker.regular_move
			var dmg := attacker.calc_damage(power, target.defense, is_special)
			if enemy_defending[selected_target]:
				dmg = maxi(1, int(dmg * 0.5))
			target.current_hp = maxi(0, target.current_hp - dmg)
			_append_log("%s uses [color=#d4a03a]%s[/color] on %s for [color=#c05050]%d[/color] damage!" % [
				attacker.name, move_name, target.name, dmg
			])
			if not target.is_alive():
				_append_log("%s is defeated!" % target.name)
	_refresh_hp_labels()
	# Next living ally acts, then enemies
	var alive := _alive_indices(player_party)
	var next_idx := -1
	for i in alive:
		if i > active_player_index:
			next_idx = i
			break
	if next_idx >= 0:
		active_player_index = next_idx
		_set_actions_enabled(true)
		_update_action_labels()
		turn_label.text = "Your turn — %s" % player_party[active_player_index].name
		_refresh_highlights()
	else:
		await get_tree().create_timer(0.35).timeout
		_enemy_turn()


func _enemy_turn() -> void:
	if battle_over:
		return
	enemy_defending = [false, false, false]
	turn_label.text = "Enemy turn..."
	var enemies := _alive_indices(enemy_party)
	if enemies.is_empty():
		_end_battle(true)
		return
	for ei in enemies:
		var attacker := enemy_party[ei]
		var players := _alive_indices(player_party)
		if players.is_empty():
			_end_battle(false)
			return
		# Simple AI: sometimes defend, else attack lowest HP
		var roll := randf()
		if roll < 0.18:
			enemy_defending[ei] = true
			_append_log("%s defends." % attacker.name)
			continue
		var target_i := players[0]
		var lowest := player_party[target_i].current_hp
		for pi in players:
			if player_party[pi].current_hp < lowest:
				lowest = player_party[pi].current_hp
				target_i = pi
		var target := player_party[target_i]
		var is_special := roll > 0.62
		var power := attacker.special_power if is_special else attacker.regular_power
		var move_name := attacker.special_move if is_special else attacker.regular_move
		var dmg := attacker.calc_damage(power, target.defense, is_special)
		if player_defending[target_i]:
			dmg = maxi(1, int(dmg * 0.5))
		target.current_hp = maxi(0, target.current_hp - dmg)
		_append_log("%s uses [color=#8a6aaa]%s[/color] on %s for [color=#c05050]%d[/color]!" % [
			attacker.name, move_name, target.name, dmg
		])
		if not target.is_alive():
			_append_log("%s falls!" % target.name)
		_refresh_hp_labels()
		await get_tree().create_timer(0.25).timeout
	if _alive_indices(player_party).is_empty():
		_end_battle(false)
	elif _alive_indices(enemy_party).is_empty():
		_end_battle(true)
	else:
		_start_player_turn()


func _end_battle(player_won: bool) -> void:
	battle_over = true
	_set_actions_enabled(false)
	if player_won:
		turn_label.text = "Victory!"
		_append_log("[b][color=#5aa86a]Your party prevails![/color][/b]")
	else:
		turn_label.text = "Defeat..."
		_append_log("[b][color=#c05050]Your party was defeated.[/color][/b]")
	NetworkManager.close()
