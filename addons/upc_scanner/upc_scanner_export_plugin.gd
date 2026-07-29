@tool
extends EditorExportPlugin

const AAR_RELEASE := "res://android/plugins/UpcScanner.release.aar"
const AAR_DEBUG := "res://android/plugins/UpcScanner.debug.aar"


func _get_name() -> String:
	return "UpcScannerExport"


func _supports_platform(platform: EditorExportPlatform) -> bool:
	return platform is EditorExportPlatformAndroid


func _get_android_libraries(platform: EditorExportPlatform, debug: bool) -> PackedStringArray:
	# Same AAR for debug/release; contents are identical.
	var path := AAR_RELEASE
	if debug and FileAccess.file_exists(AAR_DEBUG):
		path = AAR_DEBUG
	elif not FileAccess.file_exists(path):
		path = AAR_DEBUG
	return PackedStringArray([path])


func _get_android_dependencies(platform: EditorExportPlatform, debug: bool) -> PackedStringArray:
	return PackedStringArray([
		"com.google.android.gms:play-services-code-scanner:16.1.0",
		"com.google.android.gms:play-services-base:18.5.0",
	])


func _get_android_manifest_element_contents(platform: EditorExportPlatform, debug: bool) -> String:
	# Ensure camera feature is declared softly for Play devices without cameras.
	return """
	<uses-feature android:name="android.hardware.camera" android:required="false" />
"""
