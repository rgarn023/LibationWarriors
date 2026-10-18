extends SceneTree
## Verify curated Pirate frame regions exist and differ.


const ATTACK_PATH := "res://assets/animations/01_Pirate_Attack.png"
const X_BOUNDS := [0, 341, 683, 1024]
const Y_BOUNDS := [0, 512, 1024, 1536]
const ORDER := [0, 1, 4, 7, 0]


func _init() -> void:
	if not ResourceLoader.exists(ATTACK_PATH):
		print("FAIL: missing ", ATTACK_PATH)
		print("Place 01_Pirate_Attack.png at assets/animations/")
		print("Expected: facing RIGHT => flip_h=true | LEFT => flip_h=false")
		print("Expected source sequence: 0, 1, 4, 7, 0")
		quit(2)
		return
	var tex: Texture2D = load(ATTACK_PATH)
	var img: Image = tex.get_image()
	img.convert(Image.FORMAT_RGBA8)
	print("size=", tex.get_width(), "x", tex.get_height())
	print("curated order=", ORDER)
	var hashes: Array = []
	for source_index in ORDER:
		var row: int = int(source_index / 3)
		var col: int = int(source_index % 3)
		var l: int = int(X_BOUNDS[col])
		var r: int = int(X_BOUNDS[col + 1])
		var t: int = int(Y_BOUNDS[row])
		var b: int = int(Y_BOUNDS[row + 1])
		var cell: Image = img.get_region(Rect2i(l, t, r - l, b - t))
		var h: int = 0
		for y in range(0, cell.get_height(), 16):
			for x in range(0, cell.get_width(), 16):
				var c: Color = cell.get_pixel(x, y)
				h = (h * 33 + int(c.r * 255.0) + int(c.g * 255.0) * 5) % 1000000007
		hashes.append(h)
		print("source ", source_index, " Rect2(", l, ",", t, ",", r - l, ",", b - t, ") hash=", h)
	var unique: Dictionary = {}
	for h2 in hashes:
		unique[h2] = true
	print("unique_in_sequence=", unique.size(), " (recovery repeats ready so 4 unique expected)")
	print("Facing RIGHT => flip_h=true | Facing LEFT => flip_h=false")
	print("Parent scales must stay positive; only AttackSprite/IdleSprite use flip_h")
	quit(0 if unique.size() >= 3 else 1)
