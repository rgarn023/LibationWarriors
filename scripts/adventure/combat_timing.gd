class_name CombatTiming
extends RefCounted
## Pure attack-frame timing helpers used by gameplay and deterministic tests.

static func is_active_frame(frame: int, active_frames: Array, fallback_frame: int = 2) -> bool:
	if frame < 0:
		return false
	if active_frames.is_empty():
		return frame >= fallback_frame
	return frame in active_frames


static func should_resolve_hit(
	frame: int,
	active_frames: Array,
	already_resolved: bool,
	fallback_frame: int = 2
) -> bool:
	if already_resolved:
		return false
	return is_active_frame(frame, active_frames, fallback_frame)
