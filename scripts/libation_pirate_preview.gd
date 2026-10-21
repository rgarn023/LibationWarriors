extends Node2D
## Preview Brine pirate animations. Arrow keys change anim, A/D flip facing.

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var label: Label = $Label

var _anims := ["idle", "walk", "attack", "hit", "victory"]
var _idx := 0
var facing_right := true


func _ready() -> void:
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.sprite_frames = LibationPirateFrames.build_sprite_frames()
	_play_current()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_right") or (event is InputEventKey and event.pressed and event.keycode == KEY_D):
		facing_right = true
		LibationPirateFrames.apply_facing(sprite, facing_right)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_left") or (event is InputEventKey and event.pressed and event.keycode == KEY_A):
		facing_right = false
		LibationPirateFrames.apply_facing(sprite, facing_right)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_up"):
		_idx = (_idx + 1) % _anims.size()
		_play_current()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_down"):
		_idx = (_idx - 1) % _anims.size()
		_play_current()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		_play_current()
		get_viewport().set_input_as_handled()


func _play_current() -> void:
	var name := _anims[_idx]
	LibationPirateFrames.apply_facing(sprite, facing_right)
	sprite.play(name)
	label.text = "%s | facing_right=%s flip_h=%s\nUp/Down: anim  A/D: face  Space: replay" % [
		name, facing_right, sprite.flip_h
	]
