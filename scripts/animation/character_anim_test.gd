extends Node2D
## Test harness for CharacterAnimationData → SpriteFrames → AnimatedSprite2D.
##
## Controls:
##   Space          = play attack (once, then idle)
##   Left / Right   = previous / next character
##   1–7            = jump to a specific class
##
## Open this scene (F6) after dropping attack PNGs into assets/sprites/attacks/.


@onready var character: AnimatedCharacter = $AnimatedSprite2D
@onready var label: Label = $UI/Label
@onready var hint: Label = $UI/Hint


func _ready() -> void:
	if character:
		character.character_changed.connect(_on_character_changed)
		character.attack_started.connect(func(): _flash("ATTACK"))
		character.attack_finished.connect(func(): _flash("idle"))
		_on_character_changed(character.get_character_name())
	if hint:
		hint.text = "Space: attack   ←/→: switch class   1-7: pick class"


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE):
		if character:
			character.play_attack()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_LEFT:
				_step_character(-1)
			KEY_RIGHT:
				_step_character(1)
			KEY_1:
				character.set_character("WhiteMage")
			KEY_2:
				character.set_character("BlackMage")
			KEY_3:
				character.set_character("Brawler")
			KEY_4:
				character.set_character("Samurai")
			KEY_5:
				character.set_character("Viking")
			KEY_6:
				character.set_character("Rogue")
			KEY_7:
				character.set_character("Nimrod")


func _step_character(dir: int) -> void:
	var names := CharacterAnimationLibrary.all_names()
	if names.is_empty() or character == null:
		return
	var idx := 0
	for i in names.size():
		if str(names[i]) == character.get_character_name():
			idx = i
			break
	idx = (idx + dir) % names.size()
	if idx < 0:
		idx += names.size()
	character.set_character(str(names[idx]))


func _on_character_changed(character_name: String) -> void:
	if label:
		label.text = character_name


func _flash(state: String) -> void:
	if label and character:
		label.text = "%s  [%s]" % [character.get_character_name(), state]
