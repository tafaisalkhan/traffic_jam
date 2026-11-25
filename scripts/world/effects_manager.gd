class_name EffectsManager
extends Node3D

const Tokens = preload("res://scripts/core/design_tokens.gd")

func spawn_exit_sparkles(world_position: Vector3, colour: Color) -> void:
	for index in range(7):
		var sparkle := MeshInstance3D.new()
		var mesh := SphereMesh.new(); mesh.radius = 0.08; mesh.height = 0.16
		sparkle.mesh = mesh
		var material := StandardMaterial3D.new()
		material.albedo_color = colour.lightened(0.25)
		material.emission_enabled = true
		material.emission = colour.lightened(0.18)
		material.roughness = 0.22
		sparkle.material_override = material
		var angle := TAU * float(index) / 7.0
		sparkle.position = world_position + Vector3(0, 0.68, 0)
		add_child(sparkle)
		var target := sparkle.position + Vector3(cos(angle) * 0.65, 0.35 + float(index % 2) * 0.13, sin(angle) * 0.65)
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(sparkle, "position", target, 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(sparkle, "scale", Vector3(0.15, 0.15, 0.15), 0.42)
		tween.chain().tween_callback(sparkle.queue_free)

func spawn_blocked_pulse(world_position: Vector3) -> void:
	var ring := MeshInstance3D.new()
	var mesh := TorusMesh.new(); mesh.inner_radius = 0.37; mesh.outer_radius = 0.44; mesh.rings = 12; mesh.ring_segments = 8
	ring.mesh = mesh; ring.position = world_position + Vector3(0, 0.19, 0)
	var material := StandardMaterial3D.new(); material.albedo_color = Tokens.DANGER; material.emission_enabled = true; material.emission = Tokens.DANGER; material.roughness = 0.25
	ring.material_override = material; add_child(ring)
	var tween := create_tween(); tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector3(1.7, 1.0, 1.7), 0.28)
	tween.tween_property(ring, "scale:y", 0.15, 0.28)
	tween.chain().tween_callback(ring.queue_free)

func spawn_confetti(world_position: Vector3) -> void:
	var colors: Array[Color] = [Color("ef4444"), Color("3b82f6"), Color("eab308"), Color("22c55e")]
	for index in range(8):
		spawn_exit_sparkles(world_position, colors[index % colors.size()])
