extends Node
## Applies display safe-area insets so UI clears notches, punch-holes, and gesture bars.

signal safe_area_changed(margins: Rect2)

var margins := Rect2(24, 48, 24, 36) ## left, top, right, bottom in viewport pixels
var _last_key := ""


func _ready() -> void:
	get_tree().root.size_changed.connect(_recompute)
	_recompute()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_IN or what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		_recompute()


func _process(_delta: float) -> void:
	# Cheap poll — orientation / cutout can change at runtime on mobile.
	if Engine.get_process_frames() % 30 == 0:
		_recompute()


func _recompute() -> void:
	var vp := get_viewport()
	if vp == null:
		return
	var vsize: Vector2 = vp.get_visible_rect().size
	if vsize.x < 1.0 or vsize.y < 1.0:
		return

	var left := 20.0
	var top := 36.0
	var right := 20.0
	var bottom := 28.0

	if OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios"):
		left = 22.0
		top = 56.0
		right = 22.0
		bottom = 40.0
		# Extra headroom for punch-hole / front cameras on many Android devices.
		top = maxf(top, vsize.y * 0.045)
		bottom = maxf(bottom, vsize.y * 0.03)

	# Prefer OS safe area when available (screen coords → viewport).
	var safe: Rect2i = DisplayServer.get_display_safe_area()
	var win: Vector2i = DisplayServer.window_get_size()
	if win.x > 0 and win.y > 0 and safe.size.x > 0 and safe.size.y > 0:
		var sx := vsize.x / float(win.x)
		var sy := vsize.y / float(win.y)
		left = maxf(left, float(safe.position.x) * sx)
		top = maxf(top, float(safe.position.y) * sy)
		right = maxf(right, float(win.x - safe.end.x) * sx)
		bottom = maxf(bottom, float(win.y - safe.end.y) * sy)

	# Clamp so content still has room on tiny screens.
	left = minf(left, vsize.x * 0.12)
	right = minf(right, vsize.x * 0.12)
	top = minf(top, vsize.y * 0.14)
	bottom = minf(bottom, vsize.y * 0.12)

	var key := "%d:%d:%d:%d" % [int(left), int(top), int(right), int(bottom)]
	if key == _last_key:
		return
	_last_key = key
	margins = Rect2(left, top, right, bottom)
	safe_area_changed.emit(margins)
	_apply_to_marked_nodes()


func _apply_to_marked_nodes() -> void:
	var root := get_tree().root
	_apply_recursive(root)


func _apply_recursive(node: Node) -> void:
	if node is Control and node.is_in_group("safe_area_root"):
		apply_to_control(node as Control)
	for child in node.get_children():
		_apply_recursive(child)


func apply_to_control(ctrl: Control) -> void:
	ctrl.offset_left = margins.position.x
	ctrl.offset_top = margins.position.y
	ctrl.offset_right = -margins.size.x
	ctrl.offset_bottom = -margins.size.y


func register(ctrl: Control) -> void:
	if not ctrl.is_in_group("safe_area_root"):
		ctrl.add_to_group("safe_area_root")
	apply_to_control(ctrl)
