extends SceneTree
## Headless verification for AttackAnimationTest atlas regions.
## Run: godot --headless --path . --script res://tools/verify_attack_animation_test.gd


const ATTACK_PATH := "res://assets/animations/01_Pirate_Attack.png"
const X_BOUNDS := [0, 341, 683, 1024]
const Y_BOUNDS := [0, 512, 1024, 1536]


func _init() -> void:
	if not ResourceLoader.exists(ATTACK_PATH):
		print("FAIL: missing ", ATTACK_PATH)
		print("Copy 01_Pirate_Attack.png (1024x1536) into assets/animations/")
		quit(2)
		return
	var tex: Texture2D = load(ATTACK_PATH)
	print("OK: loaded ", ATTACK_PATH, " size=", tex.get_width(), "x", tex.get_height())
	if tex.get_width() != 1024 or tex.get_height() != 1536:
		print("WARN: expected 1024x1536, got ", tex.get_width(), "x", tex.get_height())
	var img := tex.get_image()
	img.convert(Image.FORMAT_RGBA8)
	var hashes := {}
	var i := 0
	for row in range(3):
		for col in range(3):
			var l: int = X_BOUNDS[col]
			var r: int = X_BOUNDS[col + 1]
			var t: int = Y_BOUNDS[row]
			var b: int = Y_BOUNDS[row + 1]
			var cell := img.get_region(Rect2i(l, t, r - l, b - t))
			var h := 0
			for y in range(0, cell.get_height(), 8):
				for x in range(0, cell.get_width(), 8):
					var c := cell.get_pixel(x, y)
					h = (h * 33 + int(c.r * 255) + int(c.g * 255) * 5 + int(c.b * 255) * 7) % 1000000007
			print("frame ", i, " Rect2(", l, ",", t, ",", r - l, ",", b - t, ") hash=", h)
			hashes[h] = true
			i += 1
	print("unique_hashes=", hashes.size())
	if hashes.size() <= 1:
		print("FAIL: regions identical — AtlasTexture setup wrong or sheet static")
		quit(1)
	else:
		print("PASS: regions have distinct content (pose should change in AttackAnimationTest)")
		quit(0)
