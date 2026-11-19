class_name PerformanceMonitor
extends Node

signal sampled(fps: float, target_fps: int)

var target_fps := 60
var elapsed := 0.0

func configure(quality: String) -> void:
	target_fps = 30 if quality == "battery" else 60

func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= 1.0:
		elapsed = 0.0
		sampled.emit(Engine.get_frames_per_second(), target_fps)
