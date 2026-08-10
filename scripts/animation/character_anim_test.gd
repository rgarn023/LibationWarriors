extends Node2D
## Demo: Pirate attack frames via PlayerAnimController state machine.
## Space / attack action = start_attack once. Movement ignored while ATTACKING.


@onready var body: CharacterBody2D = $Player
@onready var label: Label = $UI/Label
@onready var hint: Label = $UI/Hint

var _anim: PlayerAnimController
var _pad: Vector2 = Vector2.ZERO


func _ready() -> void:
	_anim = PlayerAnimController.new()
	_anim.name = "Anim"
	_anim.debug_attacks = true
	body.add_child(_anim)
	var warrior := Warrior.new({"faction": "pirate", "variant": 0})
	var loaded := FactionAttackLoader.build_for_warrior(warrior)
	_anim.configure(body, loaded["frames"], 2.0, loaded.get("trail_frame_indices", []), Color.WHITE)
	_anim.attack_finished.connect(func():
		label.text = "Pirate [idle] frames=%s" % str(loaded.get("phases_used", []))
	)
	_anim.attack_started.connect(func():
		label.text = "Pirate [ATTACKING]"
	)
	label.text = "Pirate ok=%s source=%s" % [str(loaded.get("ok", false)), str(loaded.get("source_path", "MISSING"))]
	hint.text = "Space: attack   Arrows: move (locked during attack)\nDrop pirate_attack.png into assets/sprites/attacks/"
	print("[AnimTest] ", loaded)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("attack") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE):
		_anim.start_attack()
		get_viewport().set_input_as_handled()


func _physics_process(_delta: float) -> void:
	if _anim.is_attacking():
		_anim.lock_body_position_if_attacking()
		return
	_pad = Vector2.ZERO
	if Input.is_action_pressed("ui_left"):
		_pad.x -= 1
	if Input.is_action_pressed("ui_right"):
		_pad.x += 1
	if Input.is_action_pressed("ui_up"):
		_pad.y -= 1
	if Input.is_action_pressed("ui_down"):
		_pad.y += 1
	if _pad != Vector2.ZERO:
		_anim.set_facing(_pad)
		_anim.set_moving(true)
		body.velocity = _pad.normalized() * 120.0
	else:
		_anim.set_moving(false)
		body.velocity = Vector2.ZERO
	body.move_and_slide()
