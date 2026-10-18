extends Node
## GDScript bridge to the Android UpcScanner Godot plugin (ML Kit Code Scanner).

signal barcode_scanned(code: String)
signal scan_cancelled
signal scan_failed(reason: String)

const PLUGIN_NAME := "UpcScanner"

var _plugin: Object = null
var available := false


func _ready() -> void:
	_bind_plugin()


func _bind_plugin() -> void:
	if Engine.has_singleton(PLUGIN_NAME):
		_plugin = Engine.get_singleton(PLUGIN_NAME)
		if not _plugin.is_connected("barcode_scanned", _on_scanned):
			_plugin.connect("barcode_scanned", _on_scanned)
		if not _plugin.is_connected("scan_cancelled", _on_cancelled):
			_plugin.connect("scan_cancelled", _on_cancelled)
		if not _plugin.is_connected("scan_failed", _on_failed):
			_plugin.connect("scan_failed", _on_failed)
		available = true
	else:
		available = false


func can_scan_camera() -> bool:
	return available and OS.has_feature("android")


func start_camera_scan() -> void:
	_bind_plugin()
	if _plugin == null:
		scan_failed.emit("Camera UPC scanning requires the Android build with UpcScanner.")
		return
	if OS.has_feature("android"):
		OS.request_permissions()
	_plugin.call("start_scan")


func _on_scanned(code: String) -> void:
	barcode_scanned.emit(str(code))


func _on_cancelled() -> void:
	scan_cancelled.emit()


func _on_failed(reason: String) -> void:
	scan_failed.emit(str(reason))
