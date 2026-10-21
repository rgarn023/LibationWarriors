extends Area2D
## Facing-directed dungeon projectile (Sprite2D visual, proximity hits).

signal hit_enemy(enemy: Node, damage: int, from_pos: Vector2)
signal hit_player(damage: int, from_pos: Vector2)

var velocity: Vector2 = Vector2.ZERO
var damage: int = 8
var team: String = "player" ## "player" or "enemy"
var life: float = 1.15
var _kind: String = "bolt"


func setup(origin: Vector2, dir: Vector2, speed: float, dmg: int, p_team: String, kind: String, color: Color) -> void:
	position = origin
	var face := WeaponData.cardinal(dir) if dir != Vector2.ZERO else Vector2.DOWN
	# Allow diagonals for projectiles from AI aiming
	var aim := dir.normalized() if dir != Vector2.ZERO else face
	velocity = aim * speed
	damage = dmg
	team = p_team
	_kind = kind
	collision_layer = 0
	collision_mask = 0
	monitoring = false
	z_index = 26
	var spr := Sprite2D.new()
	spr.centered = true
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.texture = _bake(kind, color)
	spr.rotation = aim.angle()
	add_child(spr)
	# Tiny collision for future; hits use distance checks from explore/enemy
	var cs := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 5.0
	cs.shape = circle
	add_child(cs)


func _physics_process(delta: float) -> void:
	position += velocity * delta
	life -= delta
	# Stay inside room soft bounds
	if position.x < 18.0 or position.x > 238.0 or position.y < 18.0 or position.y > 158.0:
		queue_free()
		return
	if life <= 0.0:
		queue_free()
		return
	if team == "player":
		for e in get_tree().get_nodes_in_group("dungeon_enemies"):
			if not is_instance_valid(e):
				continue
			if e.has_method("is_alive_enemy") and not e.is_alive_enemy():
				continue
			if position.distance_to(e.position) <= 11.0:
				hit_enemy.emit(e, damage, position)
				queue_free()
				return
	else:
		for p in get_tree().get_nodes_in_group("dungeon_player"):
			if not is_instance_valid(p):
				continue
			if position.distance_to(p.position) <= 12.0:
				hit_player.emit(damage, position)
				queue_free()
				return


func _bake(kind: String, color: Color) -> Texture2D:
	var img := Image.create(14, 14, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	match kind:
		"bullet":
			img.fill_rect(Rect2i(3, 6, 9, 3), color)
			img.fill_rect(Rect2i(10, 5, 3, 5), color.lightened(0.3))
		"thorn":
			img.fill_rect(Rect2i(6, 2, 2, 10), color)
			img.fill_rect(Rect2i(4, 4, 6, 2), color.darkened(0.15))
		"acid":
			img.fill_rect(Rect2i(4, 4, 6, 6), color)
			img.fill_rect(Rect2i(5, 2, 4, 3), color.lightened(0.2))
		"note":
			img.fill_rect(Rect2i(4, 3, 3, 8), color)
			img.fill_rect(Rect2i(7, 3, 4, 3), color)
		"bolt":
			img.fill_rect(Rect2i(2, 6, 10, 2), color)
			img.fill_rect(Rect2i(8, 4, 4, 6), color.lightened(0.25))
		"holy":
			img.fill_rect(Rect2i(6, 2, 2, 10), color)
			img.fill_rect(Rect2i(3, 6, 8, 2), color)
		"shadow":
			img.fill_rect(Rect2i(4, 4, 6, 6), color)
			img.fill_rect(Rect2i(5, 5, 4, 4), color.darkened(0.25))
		"splash":
			img.fill_rect(Rect2i(5, 3, 4, 8), color)
			img.fill_rect(Rect2i(4, 2, 6, 3), color.lightened(0.15))
		_:
			img.fill_rect(Rect2i(4, 4, 6, 6), color)
	return ImageTexture.create_from_image(img)
