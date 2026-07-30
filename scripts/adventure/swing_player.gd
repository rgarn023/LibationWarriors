extends RefCounted
class_name SwingPlayer
## Plays a SwingAnim strip on a Sprite2D, then restores the walk sheet.


var active: bool = false
var hit_ready: bool = false ## true once on hit frame
var _sprite: Sprite2D
var _restore_tex: Texture2D
var _restore_region: Rect2
var _restore_region_enabled: bool = true
var _restore_scale: float = 0.42
var _restore_modulate: Color = Color.WHITE
var _strip: Texture2D
var _frame: int = 0
var _frame_t: float = 0.0
var _durations: Array = []
var _hit_frame: int = 2
var _hit_fired: bool = false
var _facing: Vector2 = Vector2.DOWN


func start(sprite: Sprite2D, walk_tex: Texture2D, walk_region: Rect2, shape: String, facing: Vector2, color: Color, base_scale: float, base_modulate: Color, is_special: bool = false) -> bool:
	if sprite == null or walk_tex == null:
		return false
	var built := SwingAnim.build_strip(walk_tex, walk_region, shape, facing, color, is_special)
	if built.is_empty() or built.get("texture") == null:
		return false
	_sprite = sprite
	_restore_tex = walk_tex
	_restore_region = walk_region
	_restore_region_enabled = sprite.region_enabled
	_restore_scale = base_scale
	_restore_modulate = base_modulate
	_strip = built["texture"]
	_durations = built.get("durations", [0.06, 0.07, 0.05, 0.07, 0.08])
	_hit_frame = int(built.get("hit_frame", 2))
	_frame = 0
	_frame_t = 0.0
	_hit_fired = false
	hit_ready = false
	_facing = WeaponData.cardinal(facing)
	active = true
	_sprite.texture = _strip
	_sprite.region_enabled = true
	_sprite.region_rect = Rect2(0, 0, SwingAnim.FRAME_W, SwingAnim.FRAME_H)
	_sprite.offset = Vector2.ZERO
	_sprite.rotation = 0.0
	_sprite.scale = Vector2(base_scale, base_scale)
	_sprite.flip_h = false # strip already faces the swing direction
	_sprite.modulate = base_modulate
	return true


func update(delta: float) -> void:
	hit_ready = false
	if not active or _sprite == null:
		return
	_frame_t += delta
	var dur := float(_durations[_frame]) if _frame < _durations.size() else 0.07
	if _frame_t >= dur:
		_frame_t = 0.0
		_frame += 1
		if _frame >= SwingAnim.FRAME_COUNT:
			finish()
			return
		_sprite.region_rect = Rect2(_frame * SwingAnim.FRAME_W, 0, SwingAnim.FRAME_W, SwingAnim.FRAME_H)
	if not _hit_fired and _frame >= _hit_frame:
		_hit_fired = true
		hit_ready = true


func finish() -> void:
	if not active:
		return
	active = false
	hit_ready = false
	if _sprite == null:
		return
	_sprite.texture = _restore_tex
	_sprite.region_enabled = _restore_region_enabled
	_sprite.region_rect = _restore_region
	_sprite.offset = Vector2.ZERO
	_sprite.rotation = 0.0
	_sprite.scale = Vector2(_restore_scale, _restore_scale)
	_sprite.modulate = _restore_modulate
	_sprite.flip_h = _facing.x < -0.2
