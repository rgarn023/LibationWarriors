extends RefCounted
class_name CombatFx
## Pixel slash / special burst VFX for realtime dungeon combat (no white boxes).


static func spawn_slash(parent: Node2D, origin: Vector2, facing: Vector2, color: Color, is_special: bool = false) -> void:
	var root := Node2D.new()
	root.z_index = 30
	root.position = origin
	parent.add_child(root)
	var dir := facing.normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.DOWN
	var ang := dir.angle()
	var span := 1.35 if is_special else 0.95
	var radius := 26.0 if is_special else 18.0
	var blades := 7 if is_special else 5
	for i in blades:
		var t := float(i) / float(maxi(1, blades - 1))
		var a := ang - span * 0.5 + span * t
		var p1 := Vector2(cos(a), sin(a)) * (radius * 0.35)
		var p2 := Vector2(cos(a), sin(a)) * radius
		var seg := ColorRect.new()
		seg.color = color if not is_special else color.lightened(0.25)
		var mid := (p1 + p2) * 0.5
		var length := p1.distance_to(p2)
		seg.size = Vector2(length, 3.0 if is_special else 2.0)
		seg.position = mid - seg.size * 0.5
		seg.rotation = a
		seg.pivot_offset = seg.size * 0.5
		root.add_child(seg)
		# Tip spark
		var tip := ColorRect.new()
		tip.color = Color(1, 1, 0.85, 0.95)
		tip.size = Vector2(3, 3)
		tip.position = p2 - Vector2(1.5, 1.5)
		root.add_child(tip)
	if is_special:
		# Outer burst ring
		for j in 10:
			var a2 := TAU * float(j) / 10.0
			var spark := ColorRect.new()
			spark.color = color
			spark.size = Vector2(4, 4)
			spark.position = Vector2(cos(a2), sin(a2)) * 22.0 - Vector2(2, 2)
			root.add_child(spark)
		# Core flash
		var core := ColorRect.new()
		core.color = Color(color.r, color.g, color.b, 0.55)
		core.size = Vector2(16, 16)
		core.position = Vector2(-8, -8)
		root.add_child(core)
	# Animate fade + expand
	var tw := parent.get_tree().create_tween()
	tw.tween_property(root, "scale", Vector2(1.35, 1.35) if is_special else Vector2(1.15, 1.15), 0.14)
	tw.parallel().tween_property(root, "modulate:a", 0.0, 0.18)
	tw.tween_callback(func():
		if is_instance_valid(root):
			root.queue_free()
	)


static func spawn_enemy_swipe(parent: Node2D, origin: Vector2, facing: Vector2, color: Color) -> void:
	var root := Node2D.new()
	root.z_index = 28
	root.position = origin
	parent.add_child(root)
	var dir := facing.normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.LEFT
	var ang := dir.angle()
	for i in 4:
		var t := float(i) / 3.0
		var a := ang - 0.55 + 1.1 * t
		var p := Vector2(cos(a), sin(a)) * 14.0
		var seg := ColorRect.new()
		seg.color = Color(color.r, color.g * 0.5, color.b * 0.5, 0.9)
		seg.size = Vector2(12, 3)
		seg.position = p - seg.size * 0.5
		seg.rotation = a
		seg.pivot_offset = seg.size * 0.5
		root.add_child(seg)
	var tw := parent.get_tree().create_tween()
	tw.tween_property(root, "modulate:a", 0.0, 0.16)
	tw.tween_callback(func():
		if is_instance_valid(root):
			root.queue_free()
	)


static func spawn_hit_spark(parent: Node2D, pos: Vector2, color: Color) -> void:
	var root := Node2D.new()
	root.z_index = 32
	root.position = pos
	parent.add_child(root)
	for i in 5:
		var a := TAU * float(i) / 5.0 + randf() * 0.2
		var bit := ColorRect.new()
		bit.color = color
		bit.size = Vector2(3, 3)
		bit.position = Vector2(cos(a), sin(a)) * 4.0
		root.add_child(bit)
	var tw := parent.get_tree().create_tween()
	tw.tween_property(root, "scale", Vector2(1.8, 1.8), 0.12)
	tw.parallel().tween_property(root, "modulate:a", 0.0, 0.14)
	tw.tween_callback(func():
		if is_instance_valid(root):
			root.queue_free()
	)
