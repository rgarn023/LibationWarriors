extends Control
## Five-second Charoite Games startup gate.
## The original CG logo frames are never regenerated or altered here.

const SPLASH_SECONDS := 5.0
const SOURCE_FPS := 12.5
const FRAME_DIR := "res://assets/branding/cg_splash_frames"

@onready var logo: TextureRect = %Logo
@onready var status_label: Label = %StatusLabel

var _frames: Array[Texture2D] = []
var _elapsed := 0.0
var _frame_clock := 0.0
var _routed := false


func _ready() -> void:
	_load_frames()
	status_label.text = ""


func _process(delta: float) -> void:
	if _routed:
		return
	_elapsed += delta
	if not _frames.is_empty():
		_frame_clock += delta
		var frame_index := int(floor(_frame_clock * SOURCE_FPS)) % _frames.size()
		logo.texture = _frames[frame_index]
		logo.visible = true
	if _elapsed >= SPLASH_SECONDS:
		_routed = true
		await _route_after_splash()


func _load_frames() -> void:
	_frames.clear()
	var dir := DirAccess.open(FRAME_DIR)
	if dir == null:
		logo.visible = false
		return
	var names: Array[String] = []
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if not dir.current_is_dir() and name.to_lower().ends_with(".png"):
			names.append(name)
		name = dir.get_next()
	dir.list_dir_end()
	names.sort()
	for file_name in names:
		var tex := load(FRAME_DIR + "/" + file_name) as Texture2D
		if tex != null:
			_frames.append(tex)
	if _frames.is_empty():
		logo.visible = false


func _route_after_splash() -> void:
	if not SupabaseClient.is_configured():
		get_tree().change_scene_to_file("res://scenes/auth_gate.tscn")
		return
	status_label.text = "Restoring session..."
	var restored := await SupabaseClient.restore_session()
	if not restored:
		get_tree().change_scene_to_file("res://scenes/auth_gate.tscn")
		return
	status_label.text = "Loading cloud save..."
	var sync := await CloudSaveService.initial_sync()
	if not sync.get("ok", false):
		push_warning("Cloud sync failed during startup: %s" % str(sync.get("message", "")))
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
