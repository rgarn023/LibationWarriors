extends Node
## Distinguishes the developer APK (custom feature `lw_dev`) from the public build.
## Editor always gets developer tools for iteration.

func is_dev_build() -> bool:
	return OS.has_feature("lw_dev")


func allow_dev_tools() -> bool:
	## Dev APK or running inside the Godot editor.
	return is_dev_build() or OS.has_feature("editor")


func build_label() -> String:
	if is_dev_build():
		return "DEV"
	if OS.has_feature("editor"):
		return "EDITOR"
	return "PUBLIC"
