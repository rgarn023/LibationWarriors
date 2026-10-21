extends RefCounted
class_name AttackPose
## Drives a dynamic wind-up → strike → recover attack on a character Sprite2D.
## Weapons are already painted into the faction sheets, so we animate the body
## and add a slash/cast smear instead of a second floating weapon sprite.


static func apply(sprite: Sprite2D, facing: Vector2, remaining01: float, is_special: bool, style: String, base_scale: float) -> void:
	## remaining01: 1 at start of attack, 0 when finished.
	if sprite == null:
		return
	var face := WeaponData.cardinal(facing)
	var u := 1.0 - clampf(remaining01, 0.0, 1.0) # elapsed 0..1
	var wind := 0.22
	var strike := 0.55
	sprite.flip_h = WeaponData.flip_h_for(face)
	var bs := base_scale if base_scale > 0.01 else 0.42
	match style:
		"thrust", "jab":
			_pose_thrust(sprite, face, u, wind, strike, is_special, bs)
		"cast":
			_pose_cast(sprite, face, u, wind, strike, is_special, bs)
		"chop", "slam":
			_pose_chop(sprite, face, u, wind, strike, is_special, bs)
		_:
			_pose_slash(sprite, face, u, wind, strike, is_special, bs)


static func reset(sprite: Sprite2D, base_scale: float, base_modulate: Color = Color.WHITE) -> void:
	if sprite == null:
		return
	sprite.offset = Vector2.ZERO
	sprite.rotation = 0.0
	sprite.scale = Vector2(base_scale, base_scale)
	sprite.modulate = base_modulate


static func swing_style_for(shape: String) -> String:
	match shape:
		"dagger", "knife", "bayonet", "rapier", "fist":
			return "thrust"
		"axe":
			return "chop"
		"staff", "rod", "lute", "flask", "bottle":
			return "cast"
		_:
			return "slash"


static func _pose_slash(sprite: Sprite2D, face: Vector2, u: float, wind: float, strike: float, special: bool, bs: float) -> void:
	## CT-style: coil back → hard forward lunge → settle.
	if u < wind:
		var p := u / wind
		sprite.offset = -face * (7.0 + 4.0 * p) + _perp(face) * (4.0 * p) + Vector2(0, -3.0 * p)
		sprite.rotation = _lean(face, -0.65 - 0.2 * float(special)) * p
		sprite.scale = Vector2(bs * (1.0 + 0.08 * p), bs * (1.0 - 0.14 * p))
	elif u < strike:
		var p := (u - wind) / (strike - wind)
		var ease := p * p * (3.0 - 2.0 * p)
		sprite.offset = face * lerpf(-4.0, 14.0 if special else 11.0, ease) + _perp(face) * lerpf(4.0, -5.0, ease) + Vector2(0, lerpf(-2.0, 2.0, ease))
		sprite.rotation = _lean(face, lerpf(-0.65, 0.7 if special else 0.5, ease))
		sprite.scale = Vector2(bs * lerpf(1.06, 1.2, ease), bs * lerpf(0.88, 0.78, ease))
	else:
		var p := (u - strike) / maxf(0.001, 1.0 - strike)
		sprite.offset = face * lerpf(11.0, 0.0, p) + _perp(face) * lerpf(-3.0, 0.0, p)
		sprite.rotation = _lean(face, lerpf(0.45, 0.0, p))
		sprite.scale = Vector2(bs * lerpf(1.16, 1.0, p), bs * lerpf(0.82, 1.0, p))


static func _pose_thrust(sprite: Sprite2D, face: Vector2, u: float, wind: float, strike: float, special: bool, bs: float) -> void:
	if u < wind:
		var p := u / wind
		sprite.offset = -face * (5.0 * p)
		sprite.rotation = _lean(face, -0.1) * p
		sprite.scale = Vector2(bs * (1.0 - 0.05 * p), bs * (1.0 + 0.05 * p))
	elif u < strike:
		var p := (u - wind) / (strike - wind)
		var ease := 1.0 - (1.0 - p) * (1.0 - p)
		sprite.offset = face * lerpf(-3.0, 11.0 if special else 8.5, ease)
		sprite.rotation = _lean(face, 0.08)
		sprite.scale = Vector2(bs * lerpf(0.95, 1.18, ease), bs * lerpf(1.05, 0.9, ease))
	else:
		var p := (u - strike) / maxf(0.001, 1.0 - strike)
		sprite.offset = face * lerpf(8.0, 0.0, p)
		sprite.rotation = 0.0
		sprite.scale = Vector2(bs * lerpf(1.1, 1.0, p), bs * lerpf(0.92, 1.0, p))


static func _pose_chop(sprite: Sprite2D, face: Vector2, u: float, wind: float, strike: float, special: bool, bs: float) -> void:
	if u < wind:
		var p := u / wind
		sprite.offset = -face * (2.0 * p) + Vector2(0, -5.0 * p)
		sprite.rotation = _lean(face, -0.5) * p
		sprite.scale = Vector2(bs * (1.0 - 0.04 * p), bs * (1.0 + 0.1 * p))
	elif u < strike:
		var p := (u - wind) / (strike - wind)
		var ease := p * p
		sprite.offset = face * lerpf(0.0, 6.0, ease) + Vector2(0, lerpf(-5.0, 6.0, ease))
		sprite.rotation = _lean(face, lerpf(-0.5, 0.65 if special else 0.5, ease))
		sprite.scale = Vector2(bs * lerpf(1.0, 1.15, ease), bs * lerpf(1.08, 0.82, ease))
	else:
		var p := (u - strike) / maxf(0.001, 1.0 - strike)
		sprite.offset = face * lerpf(5.0, 0.0, p) + Vector2(0, lerpf(4.0, 0.0, p))
		sprite.rotation = _lean(face, lerpf(0.45, 0.0, p))
		sprite.scale = Vector2(bs, bs)


static func _pose_cast(sprite: Sprite2D, face: Vector2, u: float, wind: float, strike: float, special: bool, bs: float) -> void:
	if u < wind:
		var p := u / wind
		sprite.offset = Vector2(0, -6.0 * p) - face * (1.5 * p)
		sprite.rotation = _lean(face, -0.25) * p
		sprite.scale = Vector2(bs * (1.0 - 0.03 * p), bs * (1.0 + 0.12 * p))
	elif u < strike:
		var p := (u - wind) / (strike - wind)
		sprite.offset = face * lerpf(0.0, 5.0 if special else 3.5, p) + Vector2(0, lerpf(-6.0, -1.0, p))
		sprite.rotation = _lean(face, lerpf(-0.2, 0.25, p))
		sprite.scale = Vector2(bs * lerpf(1.0, 1.08, p), bs * lerpf(1.1, 0.95, p))
	else:
		var p := (u - strike) / maxf(0.001, 1.0 - strike)
		sprite.offset = face * lerpf(3.0, 0.0, p)
		sprite.rotation = _lean(face, lerpf(0.2, 0.0, p))
		sprite.scale = Vector2(bs, bs)


static func _perp(face: Vector2) -> Vector2:
	return Vector2(-face.y, face.x)


static func _lean(face: Vector2, amount: float) -> float:
	if face.x < 0.0:
		return -amount
	if face == Vector2.UP:
		return amount * 0.35
	if face == Vector2.DOWN:
		return amount * 0.5
	return amount
