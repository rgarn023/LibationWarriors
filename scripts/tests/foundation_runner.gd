extends SceneTree
## CLI-safe test harness. Exits nonzero if the test scene fails to parse/load.
const TEST_SCENE := "res://scenes/tests/foundation_tests.tscn"

func _initialize() -> void:
	call_deferred("_launch")

func _launch() -> void:
	var scene: PackedScene = load(TEST_SCENE)
	if scene == null:
		push_error("Cannot load foundation tests.")
		quit(1)
		return
	var instance := scene.instantiate()
	if instance == null:
		push_error("Cannot instantiate foundation tests.")
		quit(1)
		return
	root.add_child(instance)
