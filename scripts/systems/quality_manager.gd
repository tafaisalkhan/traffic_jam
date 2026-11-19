class_name QualityManager
extends RefCounted

const MOBILE := "mobile"
const BATTERY := "battery"

var current_quality := MOBILE

func apply(quality: String) -> void:
	current_quality = BATTERY if quality == BATTERY else MOBILE
	# The actual renderer stays Mobile; these profiles intentionally control the
	# frame budget first, where older Android devices benefit most.
	Engine.max_fps = 30 if current_quality == BATTERY else 60

func target_fps() -> int:
	return 30 if current_quality == BATTERY else 60
