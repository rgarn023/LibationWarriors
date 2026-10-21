extends Resource
class_name CharacterAnimationData
## Per-character sprite-sheet config for pixel-art attack / idle animations.
## Sheets are NOT assumed identical — set frame size, grid, and fps per class.
##
## Setup:
## 1. Drop the PNG under res://assets/sprites/attacks/ (or any path you prefer).
## 2. In the Import dock: Compress = Lossless, Mipmaps = Off.
## 3. Project already uses Nearest filtering (see project.godot).
## 4. Fill in this resource (or add an entry in CharacterAnimationLibrary).


@export var character_name: String = ""

## Attack (or primary) sprite sheet path, e.g. res://assets/sprites/attacks/samurai_katana_attack_sprite_sheet.png
@export_file("*.png") var texture_path: String = ""

## Optional separate idle / walk sheet. Empty = use frame 0 of texture_path as idle.
@export_file("*.png") var idle_texture_path: String = ""

@export var frame_width: int = 64
@export var frame_height: int = 80

## Grid on the attack sheet. Set to 0 to auto-detect from texture size / frame size.
@export var columns: int = 0
@export var rows: int = 0

## Attack frames to play. 0 = use columns * rows (or auto-detected).
@export var total_frames: int = 0

@export var attack_fps: float = 12.0
## Must be false for one-shot attacks that return to idle.
@export var attack_loop: bool = false

@export var idle_fps: float = 6.0
## Idle uses these if idle_texture_path is set; 0 = reuse frame_width / frame_height.
@export var idle_frame_width: int = 0
@export var idle_frame_height: int = 0
@export var idle_columns: int = 0
@export var idle_rows: int = 0
@export var idle_total_frames: int = 0
@export var idle_loop: bool = true

## Visual pivot: keep feet / torso stable across idle ↔ attack frame size changes.
@export var sprite_offset: Vector2 = Vector2.ZERO
@export var centered: bool = true

## Integer scale only (1, 2, 3…) avoids blurry pixels when upscaling.
@export var display_scale: float = 2.0


func attack_frame_size() -> Vector2i:
	return Vector2i(maxi(1, frame_width), maxi(1, frame_height))


func idle_frame_size() -> Vector2i:
	var w := idle_frame_width if idle_frame_width > 0 else frame_width
	var h := idle_frame_height if idle_frame_height > 0 else frame_height
	return Vector2i(maxi(1, w), maxi(1, h))


func resolved_attack_path() -> String:
	return texture_path


func resolved_idle_path() -> String:
	if not idle_texture_path.is_empty():
		return idle_texture_path
	return texture_path
