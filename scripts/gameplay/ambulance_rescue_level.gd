extends "res://scripts/gameplay/level_13_scene.gd"

const BASE_TIME_LIMIT := 65.0
const HERO_TYPES := ["ambulance", "fire_truck", "police_car"]
const SMALL_CIVILIAN_TYPES := ["suv", "compact_sedan", "hatchback", "sports_car", "minivan", "taxi"]
const BIG_CIVILIAN_TYPES := ["delivery_van", "delivery_truck", "school_bus", "crane_truck"]

enum RescuePhase { INTRO, PLAYING, RESCUING, COMPLETE, FAILED }

var current_stage := 1
var is_daily_mode := false
var rescue_phase := RescuePhase.INTRO
var hero_vehicles: Array[VehicleController] = []
var pending_heroes: Array[VehicleController] = []
var follow_target: Node3D
var heroes_total := 1
var heroes_rescued := 0
var siren_pairs: Array[Dictionary] = []
var siren_timer := 0.0
var rescue_camera_follow := false
var convoy_jams_total := 1
var convoy_jam_index := 1
var is_convoy_transition := false
var level_board_rotation := 0.0

var timer_layer: CanvasLayer
var timer_panel: PanelContainer
var timer_label: Label
var add_time_button: Button
var fail_overlay: Control
var powerup_tray: PanelContainer
var btn_siren: Button
var btn_crane: Button
var btn_freeze: Button
var btn_hint: Button
var freeze_timer := 0.0
var tow_mode := false
var active_hint_vehicle: VehicleController = null


func _ready() -> void:
	custom_timer = true
	_create_rescue_hud()
	super._ready()
	timer_layer.visible = false


func _play_default() -> void:
	is_daily_mode = false
	timer_layer.visible = true
	load_level(build_stage_level(current_stage))


func _play_convoy_test() -> void:
	is_daily_mode = false
	timer_layer.visible = true
	var data := _build_tier1_one_lane(1)
	data["convoy_jams"] = 3
	data["is_convoy_test"] = true
	data["time_limit"] = 90.0
	data["tutorial_tip"] = "JAM TEST 1/3 — Clear the small jam!"
	load_level(data)


func _play_daily_challenge() -> void:
	is_daily_mode = true
	timer_layer.visible = true
	var seed_val := level_manager.daily_seed()
	var daily_stage := 3 + (seed_val % 6)
	var data := build_stage_level(daily_stage, seed_val)
	data["tutorial_tip"] = "DAILY CHALLENGE! Clear the road for +50 coins!"
	load_level(data)


func _show_main_menu() -> void:
	is_daily_mode = false
	timer_layer.visible = false
	super._show_main_menu()


func _restart() -> void:
	if (lives_fail_open or time_expired) and not level_manager.spend_coins(RETRY_COST):
		if lives_fail_open:
			ui.show_lives_fail(level_manager.coins, CONTINUE_LIFE_COST, monetization_manager.rewarded_ready)
		elif time_expired:
			ui.show_time_options(level_manager.coins, TIME_BOOST_COST, true)
		return
	timer_layer.visible = true
	if fail_overlay != null:
		fail_overlay.visible = false
	if is_daily_mode:
		_play_daily_challenge()
	else:
		load_level(build_stage_level(current_stage))


func _next_level() -> void:
	is_daily_mode = false
	timer_layer.visible = true
	current_stage += 1
	if fail_overlay != null:
		fail_overlay.visible = false
	load_level(build_stage_level(current_stage))


func _load_selected_level(level_id: int) -> void:
	is_daily_mode = false
	timer_layer.visible = true
	current_stage = level_id
	if fail_overlay != null:
		fail_overlay.visible = false
	load_level(build_stage_level(current_stage))


func load_level(data: Dictionary, completed: Array[String] = []) -> void:
	var preserved_time := time_remaining
	var preserved_lives := lives
	var preserved_moves := moves
	if not is_convoy_transition:
		convoy_jams_total = maxi(1, int(data.get("convoy_jams", 1)))
		convoy_jam_index = 1
		level_board_rotation = PI if (current_stage % 2 == 0) else 0.0
	rescue_phase = RescuePhase.INTRO
	rescue_camera_follow = false
	follow_target = null
	pending_heroes.clear()
	siren_pairs.clear()
	heroes_rescued = 0
	freeze_timer = 0.0
	tow_mode = false
	if active_hint_vehicle != null and is_instance_valid(active_hint_vehicle):
		active_hint_vehicle.highlight_hint(false)
		active_hint_vehicle = null
	time_remaining = preserved_time if is_convoy_transition else float(data.get("time_limit", BASE_TIME_LIMIT))
	if fail_overlay != null:
		fail_overlay.visible = false
	super.load_level(data, completed)
	if level_root != null:
		level_root.rotation.y = level_board_rotation
	if is_convoy_transition:
		lives = preserved_lives
		moves = preserved_moves
		ui.update_lives(lives, MAX_LIVES)
	ui.set_time_controls_visible(false)
	_setup_hero_visuals()
	_update_timer_hud()
	_update_powerup_hud()
	if is_convoy_transition:
		is_convoy_transition = false
		_set_gameplay_camera()
		rescue_phase = RescuePhase.PLAYING
		playing = true
		add_time_button.disabled = false
		_update_hud("JAM %d/%d — Clear the road for the Ambulance!" % [convoy_jam_index, convoy_jams_total])
	else:
		_play_intro_sequence()


func _process(delta: float) -> void:
	_update_siren(delta)

	if rescue_camera_follow and is_instance_valid(follow_target) and camera != null:
		if camera.projection == Camera3D.PROJECTION_PERSPECTIVE:
			if _camera_intro_tween == null or not _camera_intro_tween.is_valid():
				var desired_pos := follow_target.global_position + Vector3(0.0, 5.5, 8.5)
				camera.position = camera.position.lerp(desired_pos, clampf(delta * 6.5, 0.0, 1.0))
				camera.look_at(follow_target.global_position + Vector3(0.0, 1.0, -4.0))
		else:
			var target_pos := Vector3(follow_target.global_position.x, camera.position.y, follow_target.global_position.z)
			camera.position = camera.position.lerp(target_pos, clampf(delta * 2.4, 0.0, 1.0))

	if rescue_phase == RescuePhase.PLAYING and playing:
		if freeze_timer > 0.0:
			freeze_timer = maxf(0.0, freeze_timer - delta)
		else:
			time_remaining = maxf(0.0, time_remaining - delta)
			if time_remaining <= 0.0:
				_on_time_expired()
		_update_timer_hud()


func _handle_gesture(start: Vector2, finish: Vector2) -> void:
	if tow_mode:
		var vehicle := _vehicle_at_screen(start)
		if vehicle != null:
			if not _is_hero(vehicle.vehicle_id):
				_execute_tow_truck(vehicle)
				return
			else:
				_update_hud("Cannot tow emergency unit! Tap a civilian car.")
				return
	if active_hint_vehicle != null and is_instance_valid(active_hint_vehicle):
		active_hint_vehicle.highlight_hint(false)
		active_hint_vehicle = null
	super._handle_gesture(start, finish)


func _try_move(vehicle: VehicleController) -> void:
	if rescue_phase != RescuePhase.PLAYING and rescue_phase != RescuePhase.RESCUING:
		return
	if _is_hero(vehicle.vehicle_id):
		var blocker := _find_first_blocker(vehicle.vehicle_id, vehicle.route)
		if blocker.is_empty():
			_dispatch_hero(vehicle)
		else:
			_animate_bump_and_return(vehicle, blocker)
			_update_hud("Clear the cars blocking the emergency vehicle!")
		return
	super._try_move(vehicle)
	var newly_cleared := _find_clear_idle_heroes()
	if not newly_cleared.is_empty() and (vehicle.state == VehicleController.State.MOVING or vehicle.state == VehicleController.State.TURNING):
		# Focus and zoom in on the last blocking car as it drives out first,
		# then hand camera focus over to the Ambulance/hero once it clears.
		for h in newly_cleared:
			if not pending_heroes.has(h):
				pending_heroes.append(h)
		follow_target = vehicle
		rescue_camera_follow = true
		if hero_vehicles.size() <= pending_heroes.size():
			rescue_phase = RescuePhase.RESCUING
			playing = false
		var zoom_tween := create_tween()
		zoom_tween.tween_property(camera, "size", 16.5, 0.9).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_update_hud("Last blocker moving — clearing path!")


func _on_vehicle_exited(vehicle: VehicleController) -> void:
	if _is_hero(vehicle.vehicle_id):
		_on_hero_reached_destination(vehicle)
		return
	if follow_target == vehicle:
		follow_target = null
	super._on_vehicle_exited(vehicle)
	if not pending_heroes.is_empty():
		var to_dispatch := pending_heroes.duplicate()
		pending_heroes.clear()
		for hero in to_dispatch:
			if is_instance_valid(hero) and hero.state == VehicleController.State.IDLE and _is_route_free_of_stationary(hero.vehicle_id, hero.route):
				_dispatch_hero(hero)
	else:
		_check_and_dispatch_clear_heroes()


func _find_clear_idle_heroes() -> Array[VehicleController]:
	var result: Array[VehicleController] = []
	for hero in hero_vehicles:
		if not is_instance_valid(hero) or hero.state != VehicleController.State.IDLE:
			continue
		if _is_route_free_of_stationary(hero.vehicle_id, hero.route):
			result.append(hero)
	return result


func _is_hero(id: String) -> bool:
	return id.begins_with("hero_")


func _check_and_dispatch_clear_heroes() -> void:
	if rescue_phase != RescuePhase.PLAYING and rescue_phase != RescuePhase.RESCUING:
		return
	for hero in hero_vehicles.duplicate():
		if not is_instance_valid(hero) or hero.state != VehicleController.State.IDLE:
			continue
		if _is_route_free_of_stationary(hero.vehicle_id, hero.route):
			_dispatch_hero(hero)


var _intro_path_container: Node3D

func _clear_intro_path_markers() -> void:
	if _intro_path_container != null and is_instance_valid(_intro_path_container):
		_intro_path_container.queue_free()
	_intro_path_container = null

func _spawn_intro_path_markers(route: Array[Vector2i]) -> Array[MeshInstance3D]:
	_clear_intro_path_markers()
	var markers: Array[MeshInstance3D] = []
	if level_root == null or route.is_empty():
		return markers
	var board_size: Vector2i = level.get("board_size", Vector2i(8, 12))
	_intro_path_container = Node3D.new()
	_intro_path_container.name = "IntroPathMarkers"
	level_root.add_child(_intro_path_container)

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.18, 0.95, 0.55, 0.92)
	mat.emission_enabled = true
	mat.emission = Color(0.18, 0.95, 0.55)
	mat.emission_energy_multiplier = 1.6
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	var sphere := SphereMesh.new()
	sphere.radius = 0.28
	sphere.height = 0.22
	sphere.radial_segments = 12
	sphere.rings = 6

	for idx in range(route.size()):
		var world_pt := LevelData.cell_to_world(route[idx], board_size)
		var dot := MeshInstance3D.new()
		dot.mesh = sphere
		dot.material_override = mat
		dot.position = Vector3(world_pt.x, 0.32, world_pt.z)
		dot.scale = Vector3.ZERO
		if idx == route.size() - 1:
			var end_mat := StandardMaterial3D.new()
			end_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			end_mat.albedo_color = Color(1.0, 0.84, 0.22, 0.96)
			end_mat.emission_enabled = true
			end_mat.emission = Color(1.0, 0.84, 0.22)
			end_mat.emission_energy_multiplier = 2.0
			end_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			dot.material_override = end_mat
			dot.position.y = 0.40
		_intro_path_container.add_child(dot)
		markers.append(dot)
	return markers

func _sample_polyline(points: Array[Vector3], t: float) -> Vector3:
	if points.is_empty():
		return Vector3.ZERO
	if points.size() == 1 or t <= 0.0:
		return points[0]
	if t >= 1.0:
		return points[-1]
	var scaled := t * float(points.size() - 1)
	var idx := mini(int(scaled), points.size() - 2)
	var frac := scaled - float(idx)
	return points[idx].lerp(points[idx + 1], frac)

func _play_intro_sequence() -> void:
	var token := round_token
	playing = false
	_clear_intro_path_markers()
	var primary_hero: VehicleController = null
	for hero in hero_vehicles:
		if is_instance_valid(hero) and hero.vehicle_type == "ambulance":
			primary_hero = hero
			break
	if primary_hero == null and not hero_vehicles.is_empty():
		primary_hero = hero_vehicles[0]
	if camera == null or not is_instance_valid(primary_hero):
		rescue_phase = RescuePhase.PLAYING
		playing = true
		return

	var target_pos := primary_hero.position
	var dir := Vector2i(primary_hero.route[1] - primary_hero.route[0]) if primary_hero.route.size() >= 2 else Vector2i(0, -1)
	var start_pos := target_pos - Vector3(float(dir.x), 0.0, float(dir.y)) * (CELL_SIZE * 2.1)
	primary_hero.position = start_pos

	var half := _compute_board_half_extents()
	var full_size := _compute_fit_camera_size()
	var fov := 46.0
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = fov
	var hero_look := Vector3(target_pos.x * level_root.scale.x, 1.25, target_pos.z * level_root.scale.z)
	var board_size: Vector2i = level.get("board_size", Vector2i(8, 12))
	var route_points: Array[Vector3] = [hero_look]
	for cell in primary_hero.route:
		var cell_local := LevelData.cell_to_world(cell, board_size)
		var cell_world := Vector3(cell_local.x * level_root.scale.x, 0.95, cell_local.z * level_root.scale.z)
		if route_points.is_empty() or route_points[-1].distance_to(cell_world) > 0.05:
			route_points.append(cell_world)
	var path_end_look: Vector3 = route_points[-1]

	var cam_walk_offset := Vector3(half.x * 0.24, maxf(5.8, half.y * 0.36), maxf(5.8, half.y * 0.42))
	var cam_focus := hero_look + cam_walk_offset
	var end_height := full_size / (2.0 * tan(deg_to_rad(fov * 0.5)))
	var cam_z_off := _gameplay_camera_z_offset()
	var cam_end := Vector3(0.0, end_height, cam_z_off + 0.01)
	var cam_end_look := Vector3(0.0, 0.0, cam_z_off)

	camera.position = cam_focus
	camera.look_at(hero_look)
	_update_hud("Stage %d: Clear the jam on the Ambulance's path!" % current_stage)

	# 1. Focus smoothly on the Ambulance entering the jam
	_camera_intro_tween = create_tween()
	_camera_intro_tween.tween_property(primary_hero, "position", target_pos, 1.05).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await _camera_intro_tween.finished
	if token != round_token:
		return

	# 2. Walk smoothly along the Ambulance's entire path all the way to its exit destination
	var markers := _spawn_intro_path_markers(primary_hero.route)
	var walk_duration := clampf(float(maxi(1, markers.size())) * 0.14, 1.25, 2.2)
	for m_idx in range(markers.size()):
		var dot := markers[m_idx]
		if is_instance_valid(dot):
			var target_scale := Vector3(1.6, 1.6, 1.6) if m_idx == markers.size() - 1 else Vector3.ONE
			var dt := dot.create_tween()
			dt.tween_interval(float(m_idx) / float(maxi(1, markers.size())) * walk_duration * 0.85)
			dt.tween_property(dot, "scale", target_scale * 1.2, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			dt.tween_property(dot, "scale", target_scale, 0.12)

	_camera_intro_tween = create_tween()
	_camera_intro_tween.tween_method(func(t: float) -> void:
		if is_instance_valid(camera):
			var look_pt := _sample_polyline(route_points, t)
			camera.position = look_pt + cam_walk_offset
			camera.look_at(look_pt)
	, 0.0, 1.0, walk_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await _camera_intro_tween.finished
	if token != round_token:
		return

	await get_tree().create_timer(0.25).timeout
	if token != round_token:
		return

	# 3. Smoothly pull out from the end destination to full overhead gameplay framing
	_camera_intro_tween = create_tween()
	_camera_intro_tween.set_parallel(true)
	_camera_intro_tween.tween_property(camera, "position", cam_end, 1.15).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_camera_intro_tween.tween_method(func(t: float) -> void:
		if is_instance_valid(camera):
			camera.look_at(path_end_look.lerp(cam_end_look, t))
	, 0.0, 1.0, 1.15).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await _camera_intro_tween.finished
	if token != round_token:
		return
	_camera_intro_tween = null
	_clear_intro_path_markers()

	_set_gameplay_camera()
	playing = false
	ui.show_time_briefing(current_stage, ceili(time_remaining))


func _on_time_start() -> void:
	audio_manager.play_event(Audio.Event.START)
	rescue_phase = RescuePhase.PLAYING
	playing = true
	add_time_button.disabled = false
	_update_hud(str(level.get("tutorial_tip", "Clear the road!")))


func _after_time_boost() -> void:
	rescue_phase = RescuePhase.PLAYING
	add_time_button.disabled = false
	_update_timer_hud()


func _on_time_boost_requested() -> void:
	add_time_button.disabled = true
	super._on_time_boost_requested()


func _on_time_options_closed() -> void:
	super._on_time_options_closed()
	if not time_expired:
		add_time_button.disabled = false


func _dispatch_hero(hero: VehicleController) -> void:
	if not is_instance_valid(hero) or hero.state != VehicleController.State.IDLE:
		return
	occupancy.release_vehicle(hero.vehicle_id, hero.route, hero.lane_offset)
	moves += 1
	follow_target = hero
	rescue_camera_follow = true
	rescue_phase = RescuePhase.RESCUING
	playing = false
	audio_manager.play_event(Audio.Event.VEHICLE_SELECT)
	audio_manager.play_event(Audio.Event.AMBULANCE_SIREN)
	if convoy_jam_index < convoy_jams_total:
		_spawn_ahead_convoy_road(hero)
	hero.drive_out()
	_update_hud("Emergency vehicle on the move!")
	_drop_to_hero_road_view(hero)


func _spawn_ahead_convoy_road(hero: VehicleController) -> void:
	if level_root == null or not is_instance_valid(hero):
		return
	var road_ext := Node3D.new()
	road_ext.name = "AheadConvoyRoad"
	level_root.add_child(road_ext)
	var base_z := hero.position.z - 6.0
	var road_mat := WorldMaterials.get_material("asphalt")
	var grass_mat := WorldMaterials.get_material("grass")
	var mark_mat := WorldMaterials.get_material("marking")
	_add_box_mesh(road_ext, Vector3(22.0, 0.12, 34.0), Vector3(hero.position.x, 0.04, base_z - 14.0), grass_mat)
	_add_box_mesh(road_ext, Vector3(5.2, 0.14, 34.0), Vector3(hero.position.x, 0.07, base_z - 14.0), road_mat)
	for i in range(10):
		_add_box_mesh(road_ext, Vector3(0.11, 0.02, 0.8), Vector3(hero.position.x, 0.18, base_z - float(i) * 2.4), mark_mat)
	# Preview next traffic jam cluster right where the Ambulance will pull up and stop
	var jam_types := ["suv", "taxi", "delivery_van", "school_bus", "compact_sedan"]
	var jam_colors := [Color("ef5350"), Color("ffc52c"), Color("39b8eb"), Color("f4b52c"), Color("62d976")]
	for j in range(5):
		var c := VehicleController.Vehicles.create_vehicle(jam_types[j], jam_colors[j])
		var lane_x := hero.position.x + (-1.05 if j % 2 == 0 else 1.05)
		c.position = Vector3(lane_x, 0.19, base_z - 15.5 - float(j) * 2.4)
		road_ext.add_child(c)


func _drop_to_hero_road_view(hero: VehicleController) -> void:
	if camera == null or not is_inside_tree() or not is_instance_valid(hero):
		return
	var token := round_token
	if _camera_intro_tween != null and _camera_intro_tween.is_valid():
		_camera_intro_tween.kill()
	var fov := 46.0
	var end_pos := hero.global_position + Vector3(0.0, 5.5, 8.5)
	var start_pos: Vector3
	var start_look: Vector3
	if camera.projection == Camera3D.PROJECTION_PERSPECTIVE:
		start_pos = camera.position
		start_look = -camera.global_transform.basis.z * 12.0 + camera.global_position
	else:
		var start_height := camera.size / (2.0 * tan(deg_to_rad(fov * 0.5)))
		start_pos = Vector3(camera.position.x, start_height, camera.position.z if absf(camera.position.z) > 0.01 else 0.01)
		start_look = Vector3(camera.position.x, 0.0, camera.position.z)
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		camera.fov = fov
		camera.position = start_pos
		camera.look_at(start_look)

	_camera_intro_tween = create_tween()
	_camera_intro_tween.set_parallel(true)
	_camera_intro_tween.tween_method(func(t: float) -> void:
		if is_instance_valid(camera) and is_instance_valid(hero):
			var follow_pos := hero.global_position + Vector3(0.0, 5.5, 8.5)
			camera.position = start_pos.lerp(follow_pos, t)
			camera.look_at(start_look.lerp(hero.global_position + Vector3(0.0, 1.0, -4.0), t))
	, 0.0, 1.0, 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await _camera_intro_tween.finished
	if token != round_token:
		return
	_camera_intro_tween = null


func _return_to_overhead_from_road_view() -> void:
	if camera == null or not is_inside_tree():
		_set_gameplay_camera()
		return
	var token := round_token
	if _camera_intro_tween != null and _camera_intro_tween.is_valid():
		_camera_intro_tween.kill()
	var target_size := _compute_fit_camera_size()
	var fov := 46.0
	var end_height := target_size / (2.0 * tan(deg_to_rad(fov * 0.5)))
	var end_pos := Vector3(0.0, end_height, 0.01)
	var start_look := -camera.global_transform.basis.z * 12.0 + camera.global_position
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = fov

	_camera_intro_tween = create_tween()
	_camera_intro_tween.set_parallel(true)
	_camera_intro_tween.tween_property(camera, "position", end_pos, 1.15).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_camera_intro_tween.tween_method(func(t: float) -> void:
		if is_instance_valid(camera):
			camera.look_at(start_look.lerp(Vector3.ZERO, t))
	, 0.0, 1.0, 1.15).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await _camera_intro_tween.finished
	if token != round_token:
		return
	_camera_intro_tween = null
	_set_gameplay_camera()


func _on_hero_reached_destination(vehicle: VehicleController) -> void:
	if convoy_jam_index < convoy_jams_total and hero_vehicles.size() == 1:
		convoy_jam_index += 1
		time_remaining += 15.0
		var token := round_token
		_update_hud("Another traffic jam ahead (%d/%d)!" % [convoy_jam_index, convoy_jams_total])
		if is_instance_valid(vehicle):
			vehicle.state = VehicleController.State.IDLE
			follow_target = vehicle
			rescue_camera_follow = true
			var forward := -vehicle.global_transform.basis.z.normalized()
			var stop_pos := vehicle.global_position + forward * 10.5
			var drive_tween := create_tween()
			drive_tween.tween_property(vehicle, "global_position", stop_pos, 1.15).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			await drive_tween.finished
			if token != round_token:
				return
			await get_tree().create_timer(0.45).timeout
			if token != round_token:
				return
		await _return_to_overhead_from_road_view()
		if token != round_token:
			return
		is_convoy_transition = true
		var is_test := bool(level.get("is_convoy_test", false))
		var next_data := build_convoy_jam(current_stage, convoy_jam_index, is_test)
		next_data["convoy_jams"] = convoy_jams_total
		next_data["is_convoy_test"] = is_test
		load_level(next_data)
		return
	if follow_target == vehicle:
		follow_target = null
	occupancy.release_vehicle(vehicle.vehicle_id, vehicle.route, vehicle.lane_offset)
	vehicles.erase(vehicle)
	hero_vehicles.erase(vehicle)
	completion_order.append(vehicle.vehicle_id)
	heroes_rescued += 1
	effects.spawn_exit_sparkles(vehicle.global_position, Color("22c55e"))
	_update_timer_hud()

	if hero_vehicles.is_empty():
		rescue_phase = RescuePhase.COMPLETE
		rescue_camera_follow = false
		playing = false
		var token := round_token
		audio_manager.play_event(Audio.Event.COMPLETE)
		audio_manager.play_event(Audio.Event.COIN)
		var stars := 3
		if is_daily_mode:
			var daily_res := level_manager.complete_daily_challenge(moves, level.star_thresholds)
			stars = int(daily_res.get("stars", 3))
			ui.configure_daily(true, level_manager.daily_streak)
		else:
			stars = level_manager.complete_level(level.id, moves, level.star_thresholds)
		ui.configure_progress(level_manager.highest_unlocked, level_manager.stars_by_level, level_manager.coins, maxi(Campaign.total_levels(), level_manager.highest_unlocked))
		await _play_top_to_road_outro()
		if token != round_token:
			return
		ui.show_complete(moves, level.move_target, stars)
		monetization_manager.show_menu_banners()
		monetization_manager.on_level_completed()
		await get_tree().create_timer(1.85).timeout
		if token != round_token or ui.current_screen != "complete":
			return
		monetization_manager.show_level_end_interstitial()
	else:
		audio_manager.play_event(Audio.Event.VEHICLE_EXIT)
		var next_moving: VehicleController = null
		for h in hero_vehicles:
			if is_instance_valid(h) and (h.state == VehicleController.State.MOVING or h.state == VehicleController.State.TURNING):
				next_moving = h
				break
		if next_moving != null:
			follow_target = next_moving
			rescue_camera_follow = true
			_update_hud("Rescued %d / %d — next emergency vehicle moving!" % [heroes_rescued, heroes_total])
		else:
			rescue_camera_follow = false
			var token := round_token
			await _return_to_overhead_from_road_view()
			if token != round_token or rescue_phase != RescuePhase.RESCUING:
				return
			rescue_phase = RescuePhase.PLAYING
			playing = true
			_update_hud("Rescued %d / %d — clear the rest!" % [heroes_rescued, heroes_total])


func _on_time_expired() -> void:
	rescue_phase = RescuePhase.FAILED
	add_time_button.disabled = true
	_update_hud("Time's up! Emergency vehicles couldn't get through.")
	super._on_time_expired()

func _on_lives_exhausted() -> void:
	rescue_phase = RescuePhase.FAILED
	add_time_button.disabled = true
	_update_hud("Out of lives! Continue with coins or watch an ad.")

func _after_lives_continue() -> void:
	rescue_phase = RescuePhase.PLAYING
	playing = true
	add_time_button.disabled = false
	_update_hud(str(level.get("tutorial_tip", "Clear the road!")))


func _setup_hero_visuals() -> void:
	hero_vehicles.clear()
	siren_pairs.clear()
	for v in vehicles:
		if _is_hero(v.vehicle_id):
			hero_vehicles.append(v)
			if v.vehicle_visual == null:
				continue
			var lightbar := Node3D.new()
			lightbar.name = "SirenLightbar"
			lightbar.position = Vector3(0.0, 2.08, -0.10)
			v.vehicle_visual.add_child(lightbar)

			var red_mat := _flat_material(Color("ef4444"), 0.2)
			red_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			var blue_mat := _flat_material(Color("3b82f6"), 0.2)
			blue_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

			var red_lamp := _add_box_mesh(lightbar, Vector3(0.28, 0.14, 0.22), Vector3(-0.18, 0, 0), red_mat)
			var blue_lamp := _add_box_mesh(lightbar, Vector3(0.28, 0.14, 0.22), Vector3(0.18, 0, 0), blue_mat)
			siren_pairs.append({"red": red_lamp, "blue": blue_lamp})
	heroes_total = hero_vehicles.size()


func _apply_vehicle_body_tint(vehicle: VehicleController) -> void:
	if _is_hero(vehicle.vehicle_id):
		return
	super._apply_vehicle_body_tint(vehicle)


func _animate_cars_drive_in() -> void:
	for idx in range(vehicles.size()):
		var vehicle := vehicles[idx]
		if not is_instance_valid(vehicle) or _is_hero(vehicle.vehicle_id) or vehicle.route.size() < 2:
			continue
		var target_pos := vehicle.position
		var dir := Vector2i(vehicle.route[1] - vehicle.route[0])
		var back_offset := Vector3(float(dir.x), 0.0, float(dir.y)) * (CELL_SIZE * 1.35)
		vehicle.position = target_pos - back_offset
		var delay := float(idx) * 0.015
		var tween := vehicle.create_tween()
		if delay > 0.0:
			tween.tween_interval(delay)
		tween.tween_property(vehicle, "position", target_pos, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _update_siren(delta: float) -> void:
	if siren_pairs.is_empty():
		return
	siren_timer += delta * 8.0
	var red_on := fmod(siren_timer, 2.0) < 1.0
	for i in range(siren_pairs.size() - 1, -1, -1):
		var pair: Dictionary = siren_pairs[i]
		if not is_instance_valid(pair.red) or not is_instance_valid(pair.blue):
			siren_pairs.remove_at(i)
			continue
		pair.red.visible = red_on
		pair.blue.visible = not red_on


func _build_hospital() -> void:
	if level_root == null or level.is_empty():
		return
	var cols: int = int(level.size.x)
	var rows: int = int(level.size.y)
	var hospital_col: int = int(level.get("hospital_col", cols / 2))
	var hospital := Node3D.new()
	hospital.name = "HospitalBuilding"
	var center_x := _cell_range_center_x(hospital_col, hospital_col, cols)
	var top_z := -float(rows) * 0.5 * CELL_SIZE - 1.4
	hospital.position = Vector3(center_x, 0.0, top_z)
	level_root.add_child(hospital)

	var wall_mat := _flat_material(Color("f8fafc"), 0.5)
	var roof_mat := _flat_material(Color("e2e8f0"), 0.5)
	var glass_mat := _flat_material(Color("38bdf8"), 0.2)
	var red_cross_mat := _flat_material(Color("dc2626"), 0.3)
	red_cross_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var pad_mat := _flat_material(Color("22c55e"), 0.4)
	pad_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	_add_box_mesh(hospital, Vector3(4.6, 2.2, 2.2), Vector3(0, 1.1, 0), wall_mat)
	_add_box_mesh(hospital, Vector3(4.8, 0.25, 2.4), Vector3(0, 2.3, 0), roof_mat)
	_add_box_mesh(hospital, Vector3(3.4, 0.7, 0.12), Vector3(0, 1.2, 1.12), glass_mat)
	_add_box_mesh(hospital, Vector3(1.1, 0.12, 0.36), Vector3(0, 2.48, 0.1), red_cross_mat)
	_add_box_mesh(hospital, Vector3(0.36, 0.12, 1.1), Vector3(0, 2.48, 0.1), red_cross_mat)
	_add_box_mesh(hospital, Vector3(2.2, 0.06, 1.1), Vector3(0, 0.15, 1.55), pad_mat)


func _create_rescue_hud() -> void:
	timer_layer = CanvasLayer.new()
	timer_layer.layer = 10
	add_child(timer_layer)

	timer_panel = PanelContainer.new()
	var shared_theme := UIManager.create_game_theme()
	timer_panel.theme = shared_theme
	timer_panel.anchor_left = 0.5
	timer_panel.anchor_right = 0.5
	timer_panel.offset_left = -165.0
	timer_panel.offset_right = 165.0
	timer_panel.offset_top = 110.0
	timer_panel.offset_bottom = 152.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color("0f172ad9")
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 14
	style.corner_radius_bottom_right = 14
	style.border_width_bottom = 2
	style.border_color = Color("ef4444")
	timer_panel.add_theme_stylebox_override("panel", style)
	timer_panel.visible = false
	timer_layer.add_child(timer_panel)
	add_time_button = Button.new()
	add_time_button.theme = shared_theme
	add_time_button.text = "+15s"
	add_time_button.position = Vector2(548, 86)
	add_time_button.size = Vector2(132, 48)
	add_time_button.disabled = true
	add_time_button.visible = false
	add_time_button.add_theme_font_size_override("font_size", 20)
	add_time_button.pressed.connect(_on_time_boost_requested)
	timer_layer.add_child(add_time_button)

	timer_label = Label.new()
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	timer_label.add_theme_font_size_override("font_size", 18)
	timer_label.add_theme_color_override("font_color", Color("ffffff"))
	timer_panel.add_child(timer_label)

	fail_overlay = Control.new()
	fail_overlay.theme = shared_theme
	fail_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	fail_overlay.visible = false
	timer_layer.add_child(fail_overlay)

	var dimmer := ColorRect.new()
	dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	dimmer.color = Color(0.05, 0.07, 0.12, 0.72)
	fail_overlay.add_child(dimmer)

	var card := PanelContainer.new()
	card.anchor_left = 0.5
	card.anchor_top = 0.5
	card.anchor_right = 0.5
	card.anchor_bottom = 0.5
	card.offset_left = -180.0
	card.offset_top = -110.0
	card.offset_right = 180.0
	card.offset_bottom = 110.0
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color("1e293b")
	card_style.corner_radius_top_left = 18
	card_style.corner_radius_top_right = 18
	card_style.corner_radius_bottom_left = 18
	card_style.corner_radius_bottom_right = 18
	card.add_theme_stylebox_override("panel", card_style)
	fail_overlay.add_child(card)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 18)
	card.add_child(vbox)

	var title := Label.new()
	title.text = "TIME'S UP!"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color("f87171"))
	vbox.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Clear the jam faster to rescue all units."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 16)
	vbox.add_child(subtitle)

	var retry_btn := Button.new()
	retry_btn.text = "Try Again"
	retry_btn.custom_minimum_size = Vector2(180, 46)
	retry_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	retry_btn.pressed.connect(_restart)
	vbox.add_child(retry_btn)

	# Power-up HUD Dock Tray
	powerup_tray = PanelContainer.new()
	powerup_tray.theme = shared_theme
	powerup_tray.anchor_left = 0.5
	powerup_tray.anchor_right = 0.5
	powerup_tray.anchor_top = 1.0
	powerup_tray.anchor_bottom = 1.0
	powerup_tray.offset_left = -330.0
	powerup_tray.offset_right = 330.0
	powerup_tray.offset_top = -140.0
	powerup_tray.offset_bottom = -30.0
	var tray_style := StyleBoxFlat.new()
	tray_style.bg_color = Color("0d172af0")
	tray_style.border_width_left = 2
	tray_style.border_width_top = 2
	tray_style.border_width_right = 2
	tray_style.border_width_bottom = 2
	tray_style.border_color = Color("38bdf8")
	tray_style.corner_radius_top_left = 22
	tray_style.corner_radius_top_right = 22
	tray_style.corner_radius_bottom_left = 22
	tray_style.corner_radius_bottom_right = 22
	powerup_tray.add_theme_stylebox_override("panel", tray_style)
	timer_layer.add_child(powerup_tray)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 14)
	powerup_tray.add_child(hbox)

	btn_siren = _create_powerup_btn("🚨", "SIREN", hbox, _on_powerup_siren_pressed)
	btn_crane = _create_powerup_btn("🏗️", "CRANE", hbox, _on_powerup_crane_pressed)
	btn_freeze = _create_powerup_btn("⏱️", "FREEZE", hbox, _on_powerup_freeze_pressed)
	btn_hint = _create_powerup_btn("💡", "HINT", hbox, _on_powerup_hint_pressed)
	_update_powerup_hud()


func _create_powerup_btn(icon: String, title: String, parent: Control, handler: Callable) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(146, 88)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("1e293be6")
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_left = 16
	style.corner_radius_bottom_right = 16
	style.border_width_bottom = 4
	style.border_color = Color("0284c7")
	btn.add_theme_stylebox_override("normal", style)
	var pressed_style := style.duplicate()
	pressed_style.bg_color = Color("0f172a")
	btn.add_theme_stylebox_override("pressed", pressed_style)
	btn.text = "%s\n%s" % [icon, title]
	btn.add_theme_font_size_override("font_size", 16)
	btn.pressed.connect(handler)
	parent.add_child(btn)
	return btn


func _update_powerup_hud() -> void:
	if btn_siren != null and is_instance_valid(btn_siren):
		btn_siren.text = "🚨\nSIREN (%d)" % level_manager.get_powerup("siren")
	if btn_crane != null and is_instance_valid(btn_crane):
		if tow_mode:
			btn_crane.text = "🏗️\nCANCEL"
		else:
			btn_crane.text = "🏗️\nCRANE (%d)" % level_manager.get_powerup("remove_car")
	if btn_freeze != null and is_instance_valid(btn_freeze):
		btn_freeze.text = "⏱️\nFREEZE (%d)" % level_manager.get_powerup("freeze")
	if btn_hint != null and is_instance_valid(btn_hint):
		btn_hint.text = "💡\nHINT (%d)" % level_manager.get_powerup("hint")


func _on_powerup_siren_pressed() -> void:
	if not playing or rescue_phase != RescuePhase.PLAYING: return
	var count := level_manager.get_powerup("siren")
	if count <= 0:
		ui.show_shop()
		return
	var lead_hero: VehicleController = null
	for h in hero_vehicles:
		if is_instance_valid(h) and h.state == VehicleController.State.IDLE:
			lead_hero = h
			break
	if lead_hero == null:
		_update_hud("No idle emergency vehicle on the road!")
		return
	level_manager.spend_powerup("siren")
	_update_powerup_hud()
	audio_manager.play_event(Audio.Event.AMBULANCE_SIREN)
	effects.spawn_confetti(lead_hero.global_position)
	var blocker := _find_first_blocker(lead_hero.vehicle_id, lead_hero.route)
	if not blocker.is_empty():
		var blocker_id := str(blocker.get("blocker_id", ""))
		for v in vehicles:
			if is_instance_valid(v) and v.vehicle_id == blocker_id:
				_update_hud("🚨 SIREN: Clearing blocker %s!" % v.vehicle_type)
				occupancy.release_vehicle(v.vehicle_id, v.route, v.lane_offset)
				vehicles.erase(v)
				v.tow_away()
				break
	_update_hud("🚨 EMERGENCY SIREN: Road cleared for %s!" % lead_hero.vehicle_type)
	await get_tree().create_timer(0.4).timeout
	if is_instance_valid(lead_hero) and lead_hero.state == VehicleController.State.IDLE:
		_dispatch_hero(lead_hero)


func _on_powerup_crane_pressed() -> void:
	if not playing or rescue_phase != RescuePhase.PLAYING: return
	var count := level_manager.get_powerup("remove_car")
	if count <= 0:
		ui.show_shop()
		return
	tow_mode = not tow_mode
	_update_powerup_hud()
	if tow_mode:
		_update_hud("🏗️ CRANE ACTIVE: Tap ANY civilian car to remove it!")
	else:
		_update_hud("Crane mode canceled.")


func _execute_tow_truck(vehicle: VehicleController) -> void:
	tow_mode = false
	level_manager.spend_powerup("remove_car")
	_update_powerup_hud()
	audio_manager.play_event(Audio.Event.VEHICLE_SELECT)
	effects.spawn_exit_sparkles(vehicle.global_position, Color("f59e0b"))
	occupancy.release_vehicle(vehicle.vehicle_id, vehicle.route, vehicle.lane_offset)
	vehicles.erase(vehicle)
	_update_hud("🏗️ TOW TRUCK: Removed %s from the jam!" % vehicle.vehicle_type)
	vehicle.tow_away()


func _on_powerup_freeze_pressed() -> void:
	if not playing or rescue_phase != RescuePhase.PLAYING: return
	var count := level_manager.get_powerup("freeze")
	if count <= 0:
		ui.show_shop()
		return
	level_manager.spend_powerup("freeze")
	_update_powerup_hud()
	freeze_timer = 5.0
	time_remaining += 20.0
	audio_manager.play_event(Audio.Event.COIN)
	_update_hud("⏱️ TIME FREEZE! +20s added & timer paused 5s!")
	_update_timer_hud()
	if timer_panel != null:
		var st: StyleBoxFlat = timer_panel.get_theme_stylebox("panel") as StyleBoxFlat
		if st != null:
			var orig_col := st.border_color
			st.border_color = Color("38bdf8")
			var tw := create_tween()
			tw.tween_interval(2.0)
			tw.tween_property(st, "border_color", orig_col, 1.0)


func _on_powerup_hint_pressed() -> void:
	if not playing or rescue_phase != RescuePhase.PLAYING: return
	var count := level_manager.get_powerup("hint")
	if count <= 0:
		ui.show_shop()
		return
	if active_hint_vehicle != null and is_instance_valid(active_hint_vehicle):
		active_hint_vehicle.highlight_hint(false)
		active_hint_vehicle = null
	var chosen: VehicleController = null
	for h in hero_vehicles:
		if is_instance_valid(h) and h.state == VehicleController.State.IDLE and _is_route_free_of_stationary(h.vehicle_id, h.route):
			chosen = h
			break
	if chosen == null:
		for v in vehicles:
			if is_instance_valid(v) and v.state == VehicleController.State.IDLE and _is_route_free_of_stationary(v.vehicle_id, v.route):
				chosen = v
				break
	if chosen != null:
		level_manager.spend_powerup("hint")
		_update_powerup_hud()
		active_hint_vehicle = chosen
		chosen.highlight_hint(true)
		audio_manager.play_event(Audio.Event.HINT)
		_update_hud("💡 HINT: Tap the highlighted vehicle to advance!")
	else:
		_update_hud("No direct path clear — use Tow Crane or Siren!")


func _update_timer_hud() -> void:
	if timer_label == null:
		return
	var secs := ceili(time_remaining)
	var freeze_str := " ❄️" if freeze_timer > 0.0 else ""
	if convoy_jams_total > 1:
		timer_label.text = "LVL %d | JAM %d/%d | %ds%s" % [current_stage, convoy_jam_index, convoy_jams_total, secs, freeze_str]
	else:
		timer_label.text = "LVL %d | RESCUED %d/%d | %ds%s" % [current_stage, heroes_rescued, heroes_total, secs, freeze_str]
	if freeze_timer > 0.0:
		timer_label.add_theme_color_override("font_color", Color("38bdf8"))
	elif time_remaining <= 10.0:
		timer_label.add_theme_color_override("font_color", Color("f87171"))
	elif time_remaining <= 20.0:
		timer_label.add_theme_color_override("font_color", Color("fbbf24"))
	else:
		timer_label.add_theme_color_override("font_color", UIManager.OFF_WHITE)


static func build_convoy_jam(stage: int, jam_idx: int, is_test := false) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = stage * 7919 + jam_idx * 997
	var data: Dictionary
	if is_test:
		var variant_stage := 1 if jam_idx == 1 else (2 if jam_idx == 2 else 3)
		data = _build_tier1_one_lane(variant_stage)
		if jam_idx == 2:
			_mirror_horizontally(data)
		elif jam_idx >= 3:
			_mirror_vertically(data)
		_assign_stage_vehicles(data, variant_stage, rng)
	else:
		var effective_stage := stage + (jam_idx - 1)
		data = build_stage_level(effective_stage, rng.seed)
		if jam_idx >= 3 and (jam_idx % 2 == 1):
			_mirror_vertically(data)
	data["id"] = stage
	data["convoy_jams"] = convoy_jam_count_for_stage(stage)
	return data


static func convoy_jam_count_for_stage(stage: int) -> int:
	if stage <= 1:
		return 1
	return clampi(stage, 2, 5)


static func hero_count_for_stage(stage: int) -> int:
	if stage <= 2:
		return 1
	if stage <= 4:
		return 2
	if stage <= 6:
		return 3
	return clampi(2 + stage / 3, 3, 5)


static func build_stage_level(stage: int, custom_seed := -1) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = custom_seed if custom_seed >= 0 else (stage * 7919 + 13)

	var data: Dictionary
	if stage <= 2:
		data = _build_tier1_one_lane(stage)
	elif stage <= 4:
		data = _build_tier2_two_lane(stage)
	elif stage <= 6:
		data = _build_tier3_multi_lane(stage)
	elif stage <= 8:
		data = _build_tier4_three_lane(stage)
	else:
		data = _build_max_mobile_level(stage)

	if stage % 2 == 0:
		_mirror_horizontally(data)

	_assign_stage_vehicles(data, stage, rng)
	data["convoy_jams"] = convoy_jam_count_for_stage(stage)
	return data


static func _build_tier1_one_lane(stage: int) -> Dictionary:
	var cols := 6
	var rows := 10
	var h_rows := [2, 5, 7]
	var v_cols := [1, 3]
	var is_three_lane := stage == 2
	var road_kind := "three_lane" if is_three_lane else "two_lane"
	var lane_count := 3 if is_three_lane else 2
	var roads := _grid_roads(cols, rows, h_rows, v_cols, road_kind)

	var vehicles: Array[Dictionary] = [
		_slot("hero_1", [Vector2i(3, 8), Vector2i(3, 7), Vector2i(3, 6), Vector2i(3, 5), Vector2i(3, 4), Vector2i(3, 3), Vector2i(3, 2), Vector2i(3, 1), Vector2i(3, 0)]),
		_slot("v01", [Vector2i(3, 5), Vector2i(2, 5), Vector2i(1, 5), Vector2i(0, 5)]),
		_slot("v02", [Vector2i(1, 5), Vector2i(0, 5)]),
		_slot("v03", [Vector2i(3, 2), Vector2i(4, 2), Vector2i(5, 2)]),
		_slot("v04", [Vector2i(1, 2), Vector2i(1, 1), Vector2i(1, 0)]),
		_slot("v05", [Vector2i(2, 7), Vector2i(1, 7), Vector2i(1, 8), Vector2i(1, 9)]),
		_slot("v06", [Vector2i(3, 7), Vector2i(4, 7), Vector2i(5, 7)]),
		_slot("v07", [Vector2i(1, 3), Vector2i(1, 2), Vector2i(0, 2)])
	]
	if stage >= 2:
		vehicles.append(_slot("v08", [Vector2i(4, 5), Vector2i(5, 5)]))
		vehicles.append(_slot("v09", [Vector2i(1, 6), Vector2i(1, 5), Vector2i(0, 5)]))
		vehicles.append(_slot("v10", [Vector2i(4, 2), Vector2i(5, 2)]))

	return {
		"id": stage,
		"name": "Stage %d (%s)" % [stage, "3-Lane" if is_three_lane else "2-Lane"],
		"tutorial_tip": "Clear the %d-lane road for the Ambulance!" % lane_count,
		"size": Vector2i(cols, rows),
		"lane_count": lane_count,
		"ground": "grass",
		"move_limit": 24,
		"move_target": 24,
		"star_thresholds": [20, 24, 28],
		"time_limit": 50.0,
		"hospital_col": 3,
		"v_dividers": [],
		"h_dividers": [],
		"x_islands": [Vector2i(0, 0), Vector2i(2, 2), Vector2i(4, 5)],
		"y_islands": [Vector2i(0, 1), Vector2i(3, 4), Vector2i(6, 6), Vector2i(8, 9)],
		"roads": roads,
		"vehicles": vehicles
	}


static func _build_tier2_two_lane(stage: int) -> Dictionary:
	var data := build_level_13()
	data["id"] = stage
	data["name"] = "Stage %d (2-Lane)" % stage
	data["tutorial_tip"] = "2-Lane Highway! Rescue the emergency vehicle!"
	data["time_limit"] = 75.0
	data["hospital_col"] = 3
	data["v_dividers"] = [3]
	data["h_dividers"] = [4, 10]
	data["x_islands"] = [Vector2i(0, 0), Vector2i(2, 2), Vector2i(5, 5), Vector2i(7, 7)]
	data["y_islands"] = [Vector2i(0, 1), Vector2i(3, 3), Vector2i(6, 7), Vector2i(9, 9), Vector2i(12, 13)]
	return data


static func _build_tier3_multi_lane(stage: int) -> Dictionary:
	var data := build_level_13()
	data["id"] = stage
	data["name"] = "Stage %d (Multi-Lane + Trucks)" % stage
	data["tutorial_tip"] = "Heavy trucks ahead! Clear 3 emergency units!"
	data["time_limit"] = 80.0
	data["hospital_col"] = 3
	data["v_dividers"] = [3]
	data["h_dividers"] = [4, 10]
	data["x_islands"] = [Vector2i(0, 0), Vector2i(2, 2), Vector2i(5, 5), Vector2i(7, 7)]
	data["y_islands"] = [Vector2i(0, 1), Vector2i(3, 3), Vector2i(6, 7), Vector2i(9, 9), Vector2i(12, 13)]
	return data


static func _build_tier4_three_lane(stage: int) -> Dictionary:
	var cols := 9
	var rows := 14
	var h_rows := [2, 4, 5, 8, 10, 11]
	var v_cols := [1, 3, 4, 5, 7]
	var roads := _grid_roads(cols, rows, h_rows, v_cols, "two_lane")

	# Base 8x14 solvable layout shifted across the 3-lane highway (x=3,4,5) plus extra middle-lane (x=4) cars
	var base := build_level_13()
	var vehicles: Array[Dictionary] = []
	for v in base.vehicles:
		var shifted_route: Array[Vector2i] = []
		for step in v.route:
			var sx: int = step.x + (1 if step.x >= 4 else 0)
			var next_pt := Vector2i(sx, step.y)
			if not shifted_route.is_empty() and abs(next_pt.x - shifted_route[shifted_route.size() - 1].x) == 2:
				shifted_route.append(Vector2i(4, step.y))
			shifted_route.append(next_pt)
		var nv: Dictionary = v.duplicate(true)
		nv["route"] = shifted_route
		vehicles.append(nv)

	# Extra traffic inside the 3rd highway lane (x=4) with multi-turns
	vehicles.append(_slot("v36", [Vector2i(4, 1), Vector2i(4, 0)]))
	vehicles.append(_slot("v37", [Vector2i(4, 3), Vector2i(4, 2), Vector2i(3, 2), Vector2i(2, 2), Vector2i(1, 2), Vector2i(0, 2)]))
	vehicles.append(_slot("v38", [Vector2i(4, 6), Vector2i(4, 5), Vector2i(5, 5), Vector2i(6, 5), Vector2i(7, 5), Vector2i(8, 5)]))
	vehicles.append(_slot("v39", [Vector2i(4, 9), Vector2i(4, 8), Vector2i(3, 8), Vector2i(2, 8), Vector2i(1, 8), Vector2i(0, 8)]))
	vehicles.append(_slot("v40", [Vector2i(4, 12), Vector2i(4, 11), Vector2i(5, 11), Vector2i(6, 11), Vector2i(7, 11), Vector2i(8, 11)]))

	return {
		"id": stage,
		"name": "Stage %d (3-Lane Highway)" % stage,
		"tutorial_tip": "3-Lane Mega Jam! Watch out for Water & Oil Trucks!",
		"size": Vector2i(cols, rows),
		"lane_count": 2,
		"ground": "grass",
		"move_limit": 48,
		"move_target": 48,
		"star_thresholds": [40, 44, 48],
		"time_limit": 95.0,
		"hospital_col": 3,
		"v_dividers": [3, 4],
		"h_dividers": [4, 10],
		"x_islands": [Vector2i(0, 0), Vector2i(2, 2), Vector2i(6, 6), Vector2i(8, 8)],
		"y_islands": [Vector2i(0, 1), Vector2i(3, 3), Vector2i(6, 7), Vector2i(9, 9), Vector2i(12, 13)],
		"roads": roads,
		"vehicles": vehicles
	}


static func _build_max_mobile_level(stage: int) -> Dictionary:
	var cols := 11
	var rows := 18
	var h_rows := [2, 4, 6, 9, 11, 13, 15]
	var v_cols := [1, 3, 4, 5, 7, 9]
	var roads := _grid_roads(cols, rows, h_rows, v_cols, "one_lane")
	for r in roads:
		if int(r.cell.x) in [3, 4, 5] and str(r.kind) == "one_lane":
			r["kind"] = "two_lane"
	var rng := RandomNumberGenerator.new()
	rng.seed = stage * 104729 + 37

	# Constructive reverse-order placement guarantees 100% solvability:
	# heroes are placed deepest first, then each added blocker has a clear exit
	# path past all previously placed vehicles.
	var placed_starts: Dictionary = {}
	var vehicles: Array[Dictionary] = []

	var hero_specs := [
		{"type": "ambulance", "route": _straight_route(Vector2i(4, 15), Vector2i(0, -1), rows, cols)},
		{"type": "fire_truck", "route": _straight_route(Vector2i(3, 14), Vector2i(0, -1), rows, cols)},
		{"type": "police_car", "route": _straight_route(Vector2i(5, 12), Vector2i(0, -1), rows, cols)},
		{"type": "ambulance", "route": _straight_route(Vector2i(7, 10), Vector2i(0, -1), rows, cols)},
		{"type": "fire_truck", "route": _straight_route(Vector2i(1, 8), Vector2i(0, -1), rows, cols)}
	]
	for i in range(hero_specs.size()):
		var spec: Dictionary = hero_specs[i]
		var r: Array[Vector2i] = spec.route
		placed_starts[r[0]] = true
		vehicles.append({
			"id": "hero_%d" % (i + 1),
			"type": spec.type,
			"route": r
		})

	var candidates := _collect_grid_routes(cols, rows, h_rows, v_cols)
	var target_total := 76
	var civ_idx := 1
	var progress := true
	while vehicles.size() < target_total and progress:
		progress = false
		for i in range(candidates.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var tmp: Array[Vector2i] = candidates[i]
			candidates[i] = candidates[j]
			candidates[j] = tmp
		for r in candidates:
			if vehicles.size() >= target_total:
				break
			if r.size() < 2 or placed_starts.has(r[0]):
				continue
			var blocked := false
			for step_idx in range(1, r.size()):
				if placed_starts.has(r[step_idx]):
					blocked = true
					break
			if blocked:
				continue
			placed_starts[r[0]] = true
			vehicles.append(_slot("v%02d" % civ_idx, r))
			civ_idx += 1
			progress = true

	return {
		"id": stage,
		"name": "Stage %d (Mobile Max %d Cars)" % [stage, vehicles.size()],
		"tutorial_tip": "Max Mobile Grid (%d cars)! Rescue all 5 emergency units!" % vehicles.size(),
		"size": Vector2i(cols, rows),
		"lane_count": 2,
		"compact_cars_only": true,
		"ground": "grass",
		"move_limit": vehicles.size() + 20,
		"move_target": vehicles.size(),
		"star_thresholds": [vehicles.size(), vehicles.size() + 6, vehicles.size() + 14],
		"time_limit": 160.0,
		"hospital_col": 4,
		"v_dividers": [3],
		"h_dividers": [4, 11],
		"x_islands": [Vector2i(0, 0), Vector2i(2, 2), Vector2i(6, 6), Vector2i(8, 8), Vector2i(10, 10)],
		"y_islands": [Vector2i(0, 1), Vector2i(3, 3), Vector2i(5, 5), Vector2i(7, 8), Vector2i(10, 10), Vector2i(12, 12), Vector2i(14, 14), Vector2i(16, 17)],
		"roads": roads,
		"vehicles": vehicles
	}


static func _straight_route(start: Vector2i, dir: Vector2i, rows: int, cols: int) -> Array[Vector2i]:
	var route: Array[Vector2i] = [start]
	var cur := start + dir
	while cur.x >= 0 and cur.x < cols and cur.y >= 0 and cur.y < rows:
		route.append(cur)
		cur += dir
	return route


static func _collect_grid_routes(cols: int, rows: int, h_rows: Array, v_cols: Array) -> Array[Array]:
	var routes: Array[Array] = []
	for y in range(1, rows - 1):
		for x in range(1, cols - 1):
			var is_h := y in h_rows
			var is_v := x in v_cols
			if not is_h and not is_v:
				continue
			var start := Vector2i(x, y)
			if is_h:
				routes.append(_straight_route(start, Vector2i(-1, 0), rows, cols))
				routes.append(_straight_route(start, Vector2i(1, 0), rows, cols))
			if is_v:
				routes.append(_straight_route(start, Vector2i(0, -1), rows, cols))
				routes.append(_straight_route(start, Vector2i(0, 1), rows, cols))
	return routes


static func _grid_roads(cols: int, rows: int, h_rows: Array, v_cols: Array, straight_kind: String) -> Array[Dictionary]:
	var roads: Array[Dictionary] = []
	for y in range(rows):
		for x in range(cols):
			var cell := Vector2i(x, y)
			var is_h := y in h_rows
			var is_v := x in v_cols
			if y == 0 or y == rows - 1:
				if is_v:
					roads.append(_tile(cell, "exit", 0))
				continue
			if x == 0 or x == cols - 1:
				if is_h:
					roads.append(_tile(cell, "exit", 1))
				continue
			if is_h and is_v:
				roads.append(_tile(cell, "cross", 0))
			elif is_h:
				roads.append(_tile(cell, straight_kind, 1))
			elif is_v:
				roads.append(_tile(cell, straight_kind, 0))
	return roads


static func _mirror_horizontally(data: Dictionary) -> void:
	var cols: int = int(data.size.x)
	data["hospital_col"] = (cols - 1) - int(data.get("hospital_col", 3))

	for r in data.roads:
		r["cell"] = Vector2i((cols - 1) - int(r.cell.x), int(r.cell.y))

	var new_v_dividers: Array = []
	for vx in data.get("v_dividers", []):
		new_v_dividers.append((cols - 2) - int(vx))
	data["v_dividers"] = new_v_dividers

	var new_x_islands: Array = []
	for xi in data.get("x_islands", []):
		var x0: int = (cols - 1) - int(xi.y)
		var x1: int = (cols - 1) - int(xi.x)
		new_x_islands.append(Vector2i(x0, x1))
	data["x_islands"] = new_x_islands

	for v in data.vehicles:
		var mirrored: Array[Vector2i] = []
		for step in v.route:
			mirrored.append(Vector2i((cols - 1) - step.x, step.y))
		v["route"] = mirrored
		if v.get("route_sign", "") == "u_turn_left":
			v["route_sign"] = "u_turn_right"
		elif v.get("route_sign", "") == "u_turn_right":
			v["route_sign"] = "u_turn_left"


static func _mirror_vertically(data: Dictionary) -> void:
	var rows: int = int(data.size.y)
	for r in data.roads:
		r["cell"] = Vector2i(int(r.cell.x), (rows - 1) - int(r.cell.y))

	var new_h_dividers: Array = []
	for hy in data.get("h_dividers", []):
		new_h_dividers.append((rows - 2) - int(hy))
	data["h_dividers"] = new_h_dividers

	var new_y_islands: Array = []
	for yi in data.get("y_islands", []):
		var y0: int = (rows - 1) - int(yi.y)
		var y1: int = (rows - 1) - int(yi.x)
		new_y_islands.append(Vector2i(y0, y1))
	data["y_islands"] = new_y_islands

	for v in data.vehicles:
		var mirrored: Array[Vector2i] = []
		for step in v.route:
			mirrored.append(Vector2i(step.x, (rows - 1) - step.y))
		v["route"] = mirrored


static func _assign_stage_vehicles(data: Dictionary, stage: int, rng: RandomNumberGenerator) -> void:
	var has_preset_heroes := false
	for v in data.vehicles:
		if str(v.id).begins_with("hero_"):
			has_preset_heroes = true
			break
	var hero_count := hero_count_for_stage(stage)
	var candidate_slots := ["v28", "v03", "v30", "v20", "v17"]
	var active_slots: Array = [] if has_preset_heroes else candidate_slots.slice(0, hero_count)

	var include_big_trucks := stage >= 5 and not bool(data.get("compact_cars_only", false))
	var pool: Array = SMALL_CIVILIAN_TYPES.duplicate()
	if include_big_trucks:
		pool.append_array(BIG_CIVILIAN_TYPES)

	var updated: Array[Dictionary] = []
	var hero_idx := 0
	for v in data.vehicles:
		var is_preset_hero := str(v.id).begins_with("hero_")
		var slot_idx := active_slots.find(v.id)
		if is_preset_hero or slot_idx >= 0:
			var h_type := str(v.get("type", "ambulance"))
			if is_preset_hero:
				h_type = HERO_TYPES[(stage - 1) % HERO_TYPES.size()] if stage >= 2 else "ambulance"
			else:
				var combo_offset := 1 if stage % 2 == 1 else 0
				h_type = HERO_TYPES[(slot_idx + combo_offset) % HERO_TYPES.size()] if slot_idx > 0 else "ambulance"
			var h_route: Array[Vector2i] = v.route
			if v.id == "v28":
				var hx := int(v.route[0].x)
				h_route = []
				for y in range(int(data.size.y) - 2, -1, -1):
					h_route.append(Vector2i(hx, y))
			updated.append({
				"id": "hero_%d_%s" % [hero_idx + 1, h_type],
				"type": h_type,
				"color": Color("ffffff"),
				"route": h_route,
				"lane_offset": 0.0,
				"u_turn_side": 0,
				"reference_sign": false,
				"route_sign": ""
			})
			hero_idx += 1
		else:
			var civ: Dictionary = v.duplicate(true)
			var chosen_type: String = pool[rng.randi_range(0, pool.size() - 1)]
			var chosen_color: Color = CAR_PALETTE[rng.randi_range(0, CAR_PALETTE.size() - 1)]
			# Special Water Truck (bright cyan) & Oil Truck (amber-gold) styling on delivery_truck
			if include_big_trucks and chosen_type == "delivery_truck":
				if rng.randi_range(0, 1) == 0:
					chosen_color = Color("38bdf8") # Water Truck
				else:
					chosen_color = Color("f59e0b") # Oil Truck
			civ["type"] = chosen_type
			civ["color"] = chosen_color
			updated.append(civ)

	data["vehicles"] = updated


static func _slot(id: String, route: Array) -> Dictionary:
	return _car(id, route)


static func build_ambulance_level() -> Dictionary:
	return build_stage_level(1)
