extends SceneTree
## Headless smoke test: build SpriteFrames for every library character.


func _init() -> void:
	var ok := true
	for name in CharacterAnimationLibrary.all_names():
		var data := CharacterAnimationLibrary.get_data(str(name))
		# Mirror AnimatedCharacter fallback so CI works without attack PNGs.
		if not ResourceLoader.exists(data.texture_path):
			data.texture_path = data.idle_texture_path
			data.frame_width = 64
			data.frame_height = 80
			data.columns = 4
			data.rows = 1
			data.total_frames = 4
			data.attack_loop = false
		var frames := SpriteFramesBuilder.build(data)
		var idle_n := frames.get_frame_count("idle")
		var atk_n := frames.get_frame_count("attack")
		var looping := frames.get_animation_loop("attack")
		print("%s idle=%d attack=%d attack_loop=%s" % [data.character_name, idle_n, atk_n, looping])
		if idle_n < 1 or atk_n < 1 or looping:
			ok = false
	quit(0 if ok else 1)
