class_name VehicleController
extends Node3D

const Vehicles = preload("res://scripts/gameplay/vehicle_factory.gd")

signal exited(vehicle: VehicleController)

enum State { IDLE, SELECTED, PATH_CHECKING, MOVING, TURNING, BLOCKED, EXITED }
var vehicle_id := ""
var vehicle_type := ""
var route: Array = []
var board_size := Vector2i.ZERO
var state := State.IDLE
var default_y := 0.18
var selection_ring: MeshInstance3D
var selection_material: StandardMaterial3D
var vehicle_visual: Node3D
var exhaust_smoke: GPUParticles3D
var wheels: Array[MeshInstance3D] = []
var lane_offset := 0.0
var smoke_tick := 0.0

func setup(definition: Dictionary, size: Vector2i) -> void:
	vehicle_id = definition.id
	vehicle_type = str(definition.get("type", ""))
	route = definition.route
	board_size = size
	lane_offset = float(definition.get("lane_offset", 0.0))
	position = _lane_position(route[0], route[1] - route[0])
	vehicle_visual = Vehicles.create_vehicle(definition.type, definition.color, route, int(definition.get("u_turn_side", 0)), bool(definition.get("reference_sign", false)), str(definition.get("route_sign", "")))
	# Three-lane traffic is slightly smaller so two cars in adjacent lanes keep
	# visible clearance while passing each other.
	# Preserve a visible safety gap on all three sides of a multi-lane vehicle.
	# Bigger vehicle types can receive their own level scale later, but never
	# overlap the lane dividers.
	var visual_scale := 0.66 if int(definition.get("lane_count", 1)) > 1 else 0.85
	vehicle_visual.scale = Vector3(visual_scale, visual_scale, visual_scale)
	add_child(vehicle_visual)
	exhaust_smoke = vehicle_visual.get_node_or_null("ExhaustSmoke") as GPUParticles3D
	for child in vehicle_visual.find_children("*", "MeshInstance3D", true, false):
		if child.has_meta("vehicle_wheel"): wheels.append(child as MeshInstance3D)
	_create_selection_ring()
	_face_cell(route[1])

func _create_selection_ring() -> void:
	selection_ring = MeshInstance3D.new()
	var mesh := TorusMesh.new(); mesh.inner_radius = 0.42; mesh.outer_radius = 0.49; mesh.rings = 16; mesh.ring_segments = 8
	selection_ring.mesh = mesh; selection_ring.position.y = 0.18
	selection_material = StandardMaterial3D.new(); selection_material.albedo_color = DesignTokens.PRIMARY; selection_material.emission_enabled = true; selection_material.emission = DesignTokens.PRIMARY; selection_material.roughness = 0.25
	selection_ring.material_override = selection_material; selection_ring.visible = false
	add_child(selection_ring)

func select_feedback() -> void:
	if state != State.IDLE: return
	state = State.SELECTED
	selection_material.albedo_color = DesignTokens.PRIMARY
	selection_material.emission = DesignTokens.PRIMARY
	selection_ring.visible = true; selection_ring.scale = Vector3.ONE
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position:y", default_y + 0.18, 0.10)
	tween.tween_property(selection_ring, "scale", Vector3(1.24, 1.0, 1.24), 0.10)
	tween.chain().tween_property(self, "position:y", default_y, 0.14)
	tween.parallel().tween_property(selection_ring, "scale", Vector3.ONE, 0.14)
	tween.tween_callback(func(): selection_ring.visible = false; if state == State.SELECTED: state = State.IDLE)

func blocked_feedback() -> void:
	state = State.BLOCKED
	selection_material.albedo_color = DesignTokens.DANGER
	selection_material.emission = DesignTokens.DANGER
	selection_ring.visible = true; selection_ring.scale = Vector3.ONE
	var start_x := position.x
	var tween := create_tween()
	tween.tween_property(self, "position:x", start_x + 0.15, 0.07)
	tween.tween_property(self, "position:x", start_x - 0.15, 0.07)
	tween.tween_property(self, "position:x", start_x, 0.07)
	tween.tween_callback(func(): selection_ring.visible = false; state = State.IDLE)

func drive_out() -> void:
	state = State.MOVING
	_set_motion_effects(true)
	var tween := create_tween()
	var segment_start := 0
	var segment_direction: Vector2i = route[1] - route[0]
	var segments: Array = []
	for index in range(2, route.size()):
		var next_direction: Vector2i = route[index] - route[index - 1]
		if next_direction != segment_direction:
			segments.append({"start": route[segment_start], "end": route[index - 1], "direction": segment_direction, "cells": index - segment_start - 1})
			segment_start = index - 1
			segment_direction = next_direction
	segments.append({"start": route[segment_start], "end": route[route.size() - 1], "direction": segment_direction, "cells": route.size() - 1 - segment_start})
	for index in range(segments.size()):
		var segment: Dictionary = segments[index]
		var target := _lane_position(segment.end, segment.direction)
		var duration := 0.22 * int(segment.cells)
		if index > 0:
			state = State.TURNING
			# First move across the intersection into the correct outgoing lane;
			# only then continue along that lane. This keeps U-turns off the
			# centre line and moves them into the adjacent return lane.
			var turn_target := _lane_position(segment.start, segment.direction)
			tween.tween_property(self, "rotation:y", _angle_for(segment.direction), 0.18).set_trans(Tween.TRANS_SINE)
			tween.parallel().tween_property(self, "position", turn_target, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			tween.tween_property(self, "position", target, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
			tween.tween_callback(func(): state = State.MOVING)
		else:
			tween.tween_property(self, "position", target, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	# Continue past the exit for a visible drive-off instead of disappearing as
	# soon as the car reaches the first cell outside the board.
	var final_direction: Vector2i = route[route.size() - 1] - route[route.size() - 2]
	var drive_off_cell: Vector2i = route[route.size() - 1] + final_direction * 2
	tween.tween_property(self, "position", _lane_position(drive_off_cell, final_direction), 0.46).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func(): _set_motion_effects(false); state = State.EXITED; exited.emit(self); queue_free())

func _process(delta: float) -> void:
	if state != State.MOVING and state != State.TURNING: return
	for wheel in wheels:
		if is_instance_valid(wheel): wheel.rotate_object_local(Vector3.RIGHT, delta * 22.0)
	smoke_tick -= delta
	if smoke_tick <= 0.0:
		smoke_tick = 0.12
		_spawn_smoke_puff()

func _set_motion_effects(active: bool) -> void:
	if exhaust_smoke != null:
		exhaust_smoke.emitting = active
		if active: exhaust_smoke.restart()
	if active:
		smoke_tick = 0.0
		for index in range(4): _spawn_smoke_puff(float(index) * 0.09)

func _spawn_smoke_puff(delay := 0.0) -> void:
	var parent := get_parent()
	if parent == null: return
	var puff := MeshInstance3D.new()
	var mesh := SphereMesh.new(); mesh.radius = 0.12; mesh.height = 0.20
	puff.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("d8e4e8b8")
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	puff.material_override = material
	parent.add_child(puff)
	var rear_offset := global_transform.basis * Vector3(0, 0.12, 0.62)
	puff.global_position = global_position + rear_offset
	puff.scale = Vector3.ONE * 0.45
	var drift := global_transform.basis * Vector3(0, 0.34, 0.50)
	var tween := create_tween()
	if delay > 0.0: tween.tween_interval(delay)
	tween.set_parallel(true)
	tween.tween_property(puff, "global_position", puff.global_position + drift, 0.48).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(puff, "scale", Vector3.ONE * 1.7, 0.48)
	tween.tween_property(material, "albedo_color:a", 0.0, 0.48)
	tween.chain().tween_callback(puff.queue_free)

func _face_cell(next_cell: Vector2i) -> void:
	rotation.y = _angle_for(next_cell - route[0])

func _lane_position(cell: Vector2i, direction: Vector2i) -> Vector3:
	var lane_right := Vector3(-float(direction.y), 0.0, float(direction.x))
	return LevelData.cell_to_world(cell, board_size) + lane_right * lane_offset

func _angle_for(direction: Vector2i) -> float:
	return atan2(-float(direction.x), -float(direction.y))
