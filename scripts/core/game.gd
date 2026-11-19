extends Node3D

const CELL_SIZE := LevelData.CELL_SIZE
const RoadTiles = preload("res://scripts/world/road_tile_factory.gd")
const EnvironmentItems = preload("res://scripts/world/environment_factory.gd")
const Materials = preload("res://scripts/world/world_materials.gd")
const Routes = preload("res://scripts/gameplay/path_validator.gd")
const UI = preload("res://scripts/ui/ui_manager.gd")
const Levels = preload("res://scripts/core/level_manager.gd")
const Effects = preload("res://scripts/world/effects_manager.gd")
const Campaign = preload("res://scripts/generation/campaign_catalog.gd")
const Quality = preload("res://scripts/systems/quality_manager.gd")
const Audio = preload("res://scripts/systems/audio_manager.gd")
const PerformanceTracker = preload("res://scripts/systems/performance_monitor.gd")
const Monetization = preload("res://scripts/systems/monetization_manager.gd")
const CAMERA_MIN_SIZE := 12.0
const CAMERA_MAX_SIZE := 180.0
const FIXED_LEVEL_CAMERA_FILL := 0.78
const TIME_BOOST_COST := 25
const TIME_BOOST_SECONDS := 15.0
const MAX_LIVES := 3
const CONTINUE_LIFE_COST := 25
const RETRY_COST := 25
var level: Dictionary
var road_map: Dictionary = {}
var occupancy := OccupancyManager.new()
var vehicles: Array[VehicleController] = []
var completion_order: Array[String] = []
var moves := 0
var round_token := 0
var _camera_intro_tween: Tween
var camera: Camera3D
var status_label: Label
var moves_label: Label
var touch_starts: Dictionary = {}
var touch_positions: Dictionary = {}
var pinch_start_distance := 0.0
var pinch_start_camera_size := 34.0
var level_start_camera_size := CAMERA_MAX_SIZE
var pan_last_pos := Vector2.ZERO
var pan_moved := false
var ui: CanvasLayer
var playing := false
var level_manager = Levels.new()
var effects: Node3D
var quality_manager = Quality.new()
var audio_manager: Node
var performance_monitor: Node
var monetization_manager: Node
var level_root: Node3D
var custom_timer := false
var time_remaining := 0.0
var time_limit := 0.0
var time_expired := false
var time_options_open := false
var pending_time_reward := false
var pending_menu_reward := false
var pending_lives_reward := false
var lives := MAX_LIVES
var lives_fail_open := false
var level_finished := false
var pending_play_after_privacy := false
var pending_daily_after_privacy := false
var home_popup_shown_this_launch := false
var has_entered_gameplay := false
var pending_free_chest_reward := false

func _sync_gameplay_music() -> void:
	if audio_manager != null and is_instance_valid(audio_manager):
		var paused := get_tree().paused if is_inside_tree() else false
		audio_manager.set_gameplay_active(playing and not paused and not level_finished and not lives_fail_open and not time_options_open)

func _process(delta: float) -> void:
	_sync_gameplay_music()
	if custom_timer or not playing or level.is_empty():
		return
	time_remaining = maxf(0.0, time_remaining - delta)
	ui.update_time(time_remaining)
	if time_remaining <= 0.0:
		_on_time_expired()

func _ready() -> void:
	EnvironmentItems.request_prewarm()
	VehicleController.Vehicles.request_prewarm()
	_create_world()
	_create_effects()
	_create_delivery_systems()
	_create_ui()
	ui.splash_finished.connect(_on_splash_finished)
	ui.show_splash()

func _on_splash_finished() -> void:
	monetization_manager.show_menu_banners()
	monetization_manager.check_in_app_update()
	_sync_daily_notifications()

func _create_world() -> void:
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = DesignTokens.SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#f4f6f8")
	env.ambient_light_energy = 0.60
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.environment = env
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -35, 0)
	sun.light_color = Color("#fff8ec")
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 55
	add_child(sun)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	# Start with a full play-field view; players can pinch or use the mouse wheel
	# to zoom the board in and out.
	# Reference-style overhead puzzle camera: roads, cars, and roof signs stay
	# readable without perspective distortion.
	camera.size = 42.0
	camera.position = Vector3(0, 72.0, 0.01)
	add_child(camera)
	camera.look_at(Vector3(0, 0, 0))

func _create_effects() -> void:
	effects = Effects.new()
	add_child(effects)

func _create_delivery_systems() -> void:
	quality_manager.apply(str(level_manager.settings.get("graphics_quality", "mobile")))
	audio_manager = Audio.new(); audio_manager.configure(level_manager.settings); add_child(audio_manager)
	performance_monitor = PerformanceTracker.new(); performance_monitor.configure(str(level_manager.settings.get("graphics_quality", "mobile"))); add_child(performance_monitor)
	monetization_manager = Monetization.new()
	monetization_manager.ads_removed = level_manager.ads_removed
	monetization_manager.ads_allowed = level_manager.privacy_acknowledged
	monetization_manager.purchase_state_changed.connect(_on_purchase_state_changed)
	monetization_manager.rewarded_ready_changed.connect(_on_rewarded_ready_changed)
	monetization_manager.reward_earned.connect(_on_reward_earned)
	monetization_manager.rewarded_ad_closed.connect(_on_rewarded_ad_closed)
	monetization_manager.coin_purchase_verified.connect(_on_coin_purchase_verified)
	monetization_manager.coin_purchase_state_changed.connect(_on_coin_purchase_state_changed)
	monetization_manager.no_fill_changed.connect(_on_no_fill_changed)
	monetization_manager.pack_purchase_verified.connect(_on_pack_purchase_verified)
	monetization_manager.coffee_purchased.connect(_on_coffee_purchased)
	add_child(monetization_manager)

func load_level(data: Dictionary, completed: Array[String] = []) -> void:
	has_entered_gameplay = true
	if is_inside_tree():
		get_tree().paused = false
	if _camera_intro_tween != null and _camera_intro_tween.is_valid():
		_camera_intro_tween.kill()
	_camera_intro_tween = null
	monetization_manager.show_gameplay_banner()
	round_token += 1
	level = data
	time_limit = float(data.get("time_limit", 45.0 + float(data.vehicles.size()) * 5.0))
	time_remaining = time_limit
	time_expired = false
	time_options_open = false
	pending_time_reward = false
	pending_menu_reward = false
	pending_lives_reward = false
	lives = MAX_LIVES
	lives_fail_open = false
	level_finished = false
	for child in get_children():
		if child.is_in_group("level_content"): child.queue_free()
	vehicles.clear()
	road_map.clear()
	occupancy = OccupancyManager.new()
	completion_order = completed.duplicate()
	moves = completion_order.size()
	level_root = Node3D.new()
	level_root.add_to_group("level_content")
	# Keep the reference-style board framing stable and close to the cars.
	level_root.scale = Vector3(1.15, 1.0, 1.15)
	add_child(level_root)
	if camera != null:
		_set_gameplay_camera()
	_build_board()
	for definition in level.vehicles:
		if completion_order.has(definition.id): continue
		_spawn_vehicle(definition)
	playing = true
	ui.show_gameplay(level.id, _display_moves(), level.move_target, vehicles.size(), "Tap a vehicle, or swipe in its arrow direction")
	ui.update_lives(lives, MAX_LIVES)
	ui.update_coins(level_manager.coins)
	_update_hud("Tap a vehicle, or swipe in its arrow direction")
	if not custom_timer:
		playing = false
		ui.update_time(time_remaining)
		_start_level_with_intro()

func _build_board() -> void:
	var size: Vector2i = level.size
	var skip_base_roads := level.has("x_islands")
	if not skip_base_roads:
		# One continuous pavement slab removes the visible square-grid seams.  Roads
		# are then laid above it as a joined street network, like the reference.
		var pavement := MeshInstance3D.new()
		pavement.add_to_group("level_content")
		var pavement_mesh := BoxMesh.new()
		pavement_mesh.size = Vector3(float(size.x) * CELL_SIZE, 0.13, float(size.y) * CELL_SIZE)
		pavement.mesh = pavement_mesh
		pavement.position = Vector3(0, 0, 0)
		pavement.material_override = Materials.get_material(str(level.get("ground", "grass")))
		level_root.add_child(pavement)
	var road_cells: Dictionary = {}
	for road_definition in level.roads:
		road_cells[road_definition.cell] = true
	for road_definition in level.roads:
		var cell: Vector2i = road_definition.cell
		if not skip_base_roads:
			var visual_connections: Array[String] = []
			var directions := {"north": Vector2i(0, -1), "east": Vector2i(1, 0), "south": Vector2i(0, 1), "west": Vector2i(-1, 0)}
			for direction in directions:
				if road_cells.has(cell + directions[direction]):
					visual_connections.append(direction)
			if road_definition.kind == "exit":
				for direction in RoadTiles.get_connections(road_definition.kind, road_definition.rotation):
					if not road_cells.has(cell + directions[direction]) and not visual_connections.has(direction):
						visual_connections.append(direction)
			var tile: Node3D = RoadTiles.create_from_neighbors(visual_connections, road_definition.kind)
			tile.add_to_group("level_content")
			tile.position = LevelData.cell_to_world(cell, size)
			level_root.add_child(tile, true)
		road_map[cell] = {"connections": RoadTiles.get_connections(road_definition.kind, road_definition.rotation), "is_exit": road_definition.kind == "exit", "kind": road_definition.kind}
	if not skip_base_roads:
		_build_highway_dividers(road_cells, size)
	_add_decorations()

func _build_highway_dividers(road_cells: Dictionary, size: Vector2i) -> void:
	var v_dividers: Array = level.get("v_dividers", [])
	var h_dividers: Array = level.get("h_dividers", [])
	if v_dividers.is_empty() and h_dividers.is_empty():
		return
	var dividers_root := Node3D.new()
	dividers_root.name = "HighwayDividers"
	dividers_root.add_to_group("level_content")
	level_root.add_child(dividers_root)
	var v_set := {}
	for vx in v_dividers:
		v_set[int(vx)] = true
	var h_set := {}
	for hy in h_dividers:
		h_set[int(hy)] = true
	for vx_raw in v_dividers:
		var vx := int(vx_raw)
		var seam_x := (float(vx) + 0.5 - float(size.x - 1) * 0.5) * RoadTiles.TILE_SIZE
		for y in range(size.y):
			if not (road_cells.has(Vector2i(vx, y)) and road_cells.has(Vector2i(vx + 1, y))):
				continue
			if h_set.has(y) or h_set.has(y - 1):
				continue
			var cell_z := (float(y) - float(size.y - 1) * 0.5) * RoadTiles.TILE_SIZE
			RoadTiles._add_lane_dashes(dividers_root, Vector3(0.055, 0.015, RoadTiles.TILE_SIZE), Vector3(seam_x, 0.18, cell_z))
	for hy_raw in h_dividers:
		var hy := int(hy_raw)
		var seam_z := (float(hy) + 0.5 - float(size.y - 1) * 0.5) * RoadTiles.TILE_SIZE
		for x in range(size.x):
			if not (road_cells.has(Vector2i(x, hy)) and road_cells.has(Vector2i(x, hy + 1))):
				continue
			if v_set.has(x) or v_set.has(x - 1):
				continue
			var cell_x := (float(x) - float(size.x - 1) * 0.5) * RoadTiles.TILE_SIZE
			RoadTiles._add_lane_dashes(dividers_root, Vector3(RoadTiles.TILE_SIZE, 0.015, 0.055), Vector3(cell_x, 0.18, seam_z))

func _add_decorations() -> void:
	var placed_cells := {}
	var decorations := [[Vector2i(0,0),"tree"],[Vector2i(4,0),"building"],[Vector2i(0,1),"bush"],[Vector2i(4,1),"street_light"],[Vector2i(0,3),"fountain"],[Vector2i(4,3),"bench"],[Vector2i(0,4),"flower_bed"],[Vector2i(4,4),"tree"],[Vector2i(0,5),"street_light"],[Vector2i(4,5),"bush"],[Vector2i(0,6),"tree"],[Vector2i(4,6),"tree"]]
	var level_seed := int(level.get("id", 1))
	for definition in decorations:
		var cell: Vector2i = definition[0]
		if road_map.has(cell) or placed_cells.has(cell):
			continue
		placed_cells[cell] = true
		var seed_val := level_seed * 31 + cell.x * 7 + cell.y * 13
		var item: Node3D = EnvironmentItems.create(definition[1], seed_val)
		item.add_to_group("level_content")
		item.position = LevelData.cell_to_world(cell, level.size)
		level_root.add_child(item)

	# Fill all remaining empty grass blocks inside the board + outer border ring
	var w: int = level.size.x
	var h: int = level.size.y
	for y in range(-1, h + 1):
		for x in range(-1, w + 1):
			var cell := Vector2i(x, y)
			if road_map.has(cell) or placed_cells.has(cell):
				continue
			var is_border := (x == -1 or x == w or y == -1 or y == h)
			if is_border:
				var adj := Vector2i(clampi(x, 0, w - 1), clampi(y, 0, h - 1))
				if road_map.has(adj) and bool(road_map[adj].get("is_exit", false)):
					continue
			placed_cells[cell] = true
			var seed_val := level_seed * 37 + (x + 3) * 11 + (y + 3) * 17
			var kind := "bush"
			if is_border:
				if posmod(x + y, 2) != 0:
					continue
				kind = "building" if posmod(x * 3 + y, 3) != 0 else "tree"
			else:
				var slot_hash := posmod(x + y * 2, 4)
				if slot_hash == 0:
					kind = "building"
				elif slot_hash == 1:
					kind = "tree"
				else:
					continue
			var item: Node3D = EnvironmentItems.create(kind, seed_val)
			item.add_to_group("level_content")
			item.position = LevelData.cell_to_world(cell, level.size)
			if kind == "building":
				if x <= 0:
					item.rotation.y = PI * 0.5
				elif x >= w - 1:
					item.rotation.y = -PI * 0.5
				elif y <= 0:
					item.rotation.y = 0.0
				elif y >= h - 1:
					item.rotation.y = PI
			level_root.add_child(item)

func _spawn_vehicle(definition: Dictionary) -> void:
	var vehicle := VehicleController.new()
	vehicle.add_to_group("level_content")
	level_root.add_child(vehicle)
	var rendered_definition := definition.duplicate()
	# One-lane levels keep cars centred.  Multi-lane levels assign each car to
	# a lane centre, never on a dashed divider, so parallel traffic is visible.
	var start_road: Dictionary = road_map.get(definition.route[0], {})
	var lane_count := 1 if str(start_road.get("kind", "")) == "one_lane" else int(level.get("lane_count", 2))
	rendered_definition.lane_offset = _vehicle_lane_offset(vehicles.size(), lane_count)
	rendered_definition.lane_count = lane_count
	if level_manager.selected_cosmetic != "classic": rendered_definition.color = definition.color.lerp(level_manager.cosmetic_tint(), 0.22)
	vehicle.setup(rendered_definition, level.size)
	vehicle.exited.connect(_on_vehicle_exited)
	vehicles.append(vehicle)
	occupancy.add_vehicle(definition.id, definition.route[0], vehicle.lane_offset)

func _vehicle_lane_offset(spawn_index: int, lane_count: int) -> float:
	if lane_count <= 1:
		return 0.0
	var lane_width := RoadTiles.ROAD_WIDTH / float(lane_count)
	if lane_count == 2:
		# Right-hand traffic: every vehicle on a 2-lane road uses its right lane,
		# keeping off the dashed center line and letting opposite traffic pass.
		return lane_width * 0.5 * 0.94
	var lane_index := posmod(spawn_index, lane_count)
	return (float(lane_index) - float(lane_count - 1) * 0.5) * lane_width * 0.94

func _is_zoomed_in() -> bool:
	return camera != null and camera.size < minf(CAMERA_MAX_SIZE, level_start_camera_size) - 0.5

func _pan_camera(screen_delta: Vector2) -> void:
	if not _is_zoomed_in():
		return
	var viewport_h := maxf(get_viewport().get_visible_rect().size.y, 1.0)
	var world_per_pixel := camera.size / viewport_h
	camera.position.x -= screen_delta.x * world_per_pixel
	camera.position.z -= screen_delta.y * world_per_pixel
	_clamp_camera_to_board()

func _clamp_camera_to_board() -> void:
	if camera == null or camera.projection != Camera3D.PROJECTION_ORTHOGONAL:
		return
	var half := _compute_board_half_extents()
	var viewport_size := get_viewport().get_visible_rect().size
	var aspect := viewport_size.x / maxf(viewport_size.y, 1.0)
	if aspect <= 0.0:
		aspect = 720.0 / 1280.0
	var half_view_h := camera.size * 0.5
	var half_view_w := half_view_h * aspect
	var max_pan_x := maxf(0.0, half.x - half_view_w)
	var max_pan_z := maxf(0.0, half.y - half_view_h)
	camera.position.x = clampf(camera.position.x, -max_pan_x, max_pan_x)
	camera.position.z = clampf(camera.position.z, -max_pan_z, max_pan_z)
	if absf(camera.position.z) < 0.01:
		camera.position.z = 0.01

func _unhandled_input(event: InputEvent) -> void:
	if not playing: return
	if event is InputEventScreenTouch:
		if event.pressed:
			touch_starts[event.index] = event.position
			touch_positions[event.index] = event.position
			if touch_positions.size() == 1:
				pan_last_pos = event.position
				pan_moved = false
			_begin_pinch_if_needed()
		elif touch_starts.has(event.index):
			var was_pinch := touch_positions.size() > 1
			if not was_pinch and not pan_moved:
				_handle_gesture(touch_starts[event.index], event.position)
			touch_starts.erase(event.index)
			touch_positions.erase(event.index)
			if touch_positions.size() < 2:
				pinch_start_distance = 0.0
			if touch_positions.is_empty():
				pan_moved = false
	elif event is InputEventScreenDrag:
		if touch_positions.has(event.index):
			touch_positions[event.index] = event.position
			if touch_positions.size() == 2:
				_update_pinch_zoom()
			elif touch_positions.size() == 1 and _is_zoomed_in():
				var delta: Vector2 = event.position - pan_last_pos
				pan_last_pos = event.position
				if pan_moved or event.position.distance_to(touch_starts.get(event.index, event.position)) > 10.0:
					pan_moved = true
					_pan_camera(delta)
	elif event is InputEventMagnifyGesture:
		if event.factor > 0.0:
			_set_camera_size(camera.size / event.factor)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
		_set_camera_size(camera.size * 0.9)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
		_set_camera_size(camera.size * 1.1)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			touch_starts[-1] = event.position
			pan_last_pos = event.position
			pan_moved = false
		elif touch_starts.has(-1):
			if not pan_moved:
				_handle_gesture(touch_starts[-1], event.position)
			touch_starts.erase(-1)
			pan_moved = false
	elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		if touch_starts.has(-1) and _is_zoomed_in():
			var delta: Vector2 = event.position - pan_last_pos
			pan_last_pos = event.position
			if pan_moved or event.position.distance_to(touch_starts[-1]) > 10.0:
				pan_moved = true
				_pan_camera(delta)

func _begin_pinch_if_needed() -> void:
	if touch_positions.size() != 2: return
	var points := touch_positions.values()
	var first_point: Vector2 = points[0]
	var second_point: Vector2 = points[1]
	pinch_start_distance = first_point.distance_to(second_point)
	pinch_start_camera_size = camera.size

func _update_pinch_zoom() -> void:
	if pinch_start_distance <= 0.0 or touch_positions.size() != 2: return
	var points := touch_positions.values()
	var first_point: Vector2 = points[0]
	var second_point: Vector2 = points[1]
	var current_distance := first_point.distance_to(second_point)
	if current_distance > 0.0: _set_camera_size(pinch_start_camera_size * pinch_start_distance / current_distance)

func _compute_board_half_extents() -> Vector2:
	var board_size: Vector2i = level.get("size", Vector2i(5, 7))
	var scale_x := level_root.scale.x if level_root != null else 1.15
	var scale_z := level_root.scale.z if level_root != null else 1.15
	return Vector2(float(board_size.x) * CELL_SIZE * scale_x * 0.5, float(board_size.y) * CELL_SIZE * scale_z * 0.5)

func _compute_fit_camera_size() -> float:
	var half := _compute_board_half_extents()
	var board_width := half.x * 2.0
	var board_height := half.y * 2.0
	var viewport_size := get_viewport().get_visible_rect().size
	var aspect := viewport_size.x / maxf(viewport_size.y, 1.0)
	if aspect <= 0.0:
		aspect = 720.0 / 1280.0
	return maxf(board_height * FIXED_LEVEL_CAMERA_FILL, (board_width / aspect) * 1.08)

func _set_gameplay_camera() -> void:
	if camera == null:
		return
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.position = Vector3(0.0, 72.0, 0.01)
	camera.look_at(Vector3.ZERO)
	level_start_camera_size = clampf(_compute_fit_camera_size(), CAMERA_MIN_SIZE, CAMERA_MAX_SIZE)
	_set_camera_size(level_start_camera_size)

func _play_road_to_top_intro() -> void:
	if camera == null or not is_inside_tree():
		_set_gameplay_camera()
		return
	var token := round_token
	var half := _compute_board_half_extents()
	var target_size := _compute_fit_camera_size()
	var fov := 46.0
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = fov
	var start_pos := Vector3(half.x * 0.42, maxf(4.6, half.y * 0.35), half.y + 7.5)
	var start_look := Vector3(0.0, 1.35, -half.y * 0.15)
	var end_height := target_size / (2.0 * tan(deg_to_rad(fov * 0.5)))
	var end_pos := Vector3(0.0, end_height, 0.01)
	var end_look := Vector3.ZERO
	camera.position = start_pos
	camera.look_at(start_look)

	if _camera_intro_tween != null and _camera_intro_tween.is_valid():
		_camera_intro_tween.kill()
	_camera_intro_tween = create_tween()
	_camera_intro_tween.set_parallel(true)
	_camera_intro_tween.tween_property(camera, "position", end_pos, 1.85).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_camera_intro_tween.tween_method(func(t: float) -> void:
		if is_instance_valid(camera):
			camera.look_at(start_look.lerp(end_look, t))
	, 0.0, 1.0, 1.85).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await _camera_intro_tween.finished
	if token != round_token:
		return
	_camera_intro_tween = null
	_set_gameplay_camera()

func _start_level_with_intro() -> void:
	var token := round_token
	await _play_road_to_top_intro()
	if token != round_token:
		return
	ui.show_time_briefing(int(level.id), ceili(time_limit))

func _play_top_to_road_outro() -> void:
	if camera == null or not is_inside_tree():
		return
	var token := round_token
	if _camera_intro_tween != null and _camera_intro_tween.is_valid():
		_camera_intro_tween.kill()
	var half := _compute_board_half_extents()
	var fov := 46.0
	var end_pos := Vector3(half.x * 0.42, maxf(4.6, half.y * 0.35), half.y + 7.5)
	var end_look := Vector3(0.0, 1.35, -half.y * 0.15)
	var start_pos: Vector3
	var start_look: Vector3
	var duration := 1.45
	if camera.projection == Camera3D.PROJECTION_PERSPECTIVE:
		start_pos = camera.position
		start_look = -camera.global_transform.basis.z * 12.0 + camera.global_position
		duration = 0.85
	else:
		var start_size := camera.size
		var start_height := start_size / (2.0 * tan(deg_to_rad(fov * 0.5)))
		start_pos = Vector3(camera.position.x, start_height, camera.position.z if absf(camera.position.z) > 0.01 else 0.01)
		start_look = Vector3(camera.position.x, 0.0, camera.position.z)
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		camera.fov = fov
		camera.position = start_pos
		camera.look_at(start_look)

	_camera_intro_tween = create_tween()
	_camera_intro_tween.set_parallel(true)
	_camera_intro_tween.tween_property(camera, "position", end_pos, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_camera_intro_tween.tween_method(func(t: float) -> void:
		if is_instance_valid(camera):
			camera.look_at(start_look.lerp(end_look, t))
	, 0.0, 1.0, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await _camera_intro_tween.finished
	if token != round_token:
		return
	_camera_intro_tween = null

func _set_camera_size(next_size: float) -> void:
	var max_zoom_out := minf(CAMERA_MAX_SIZE, level_start_camera_size)
	camera.size = clampf(next_size, CAMERA_MIN_SIZE, max_zoom_out)
	_clamp_camera_to_board()

func _handle_gesture(start: Vector2, finish: Vector2) -> void:
	var vehicle := _vehicle_at_screen(start)
	if vehicle == null: return
	# Dragging selects and sends the car along its assigned route. Camera zoom
	# remains disabled, so every drag is reserved for vehicle control.
	_try_move(vehicle)

func _vehicle_at_screen(screen_position: Vector2) -> VehicleController:
	var origin := camera.project_ray_origin(screen_position)
	var ray := camera.project_ray_normal(screen_position)
	if abs(ray.y) < 0.001: return null
	var hit := origin + ray * (-origin.y / ray.y)
	var chosen: VehicleController = null
	var closest := 0.90
	for vehicle in vehicles:
		if not is_instance_valid(vehicle) or vehicle.state != VehicleController.State.IDLE: continue
		var vehicle_position := vehicle.global_position
		var distance := Vector2(hit.x - vehicle_position.x, hit.z - vehicle_position.z).length()
		if distance < closest:
			closest = distance
			chosen = vehicle
	return chosen

func _swipe_matches_route(vehicle: VehicleController, start: Vector2, finish: Vector2) -> bool:
	if vehicle.route.size() < 2: return false
	var screen_from := camera.unproject_position(vehicle.global_position)
	# The roof arrow communicates the exit direction, including any turn.
	var final_direction: Vector2i = vehicle.route[vehicle.route.size() - 1] - vehicle.route[vehicle.route.size() - 2]
	var board_scale := level_root.scale.x if level_root != null else 1.0
	var hint_world := vehicle.global_position + Vector3(final_direction.x * CELL_SIZE * board_scale, 0.0, final_direction.y * CELL_SIZE * board_scale)
	var screen_to := camera.unproject_position(hint_world)
	var expected := (screen_to - screen_from).normalized()
	var actual := (finish - start).normalized()
	return expected.dot(actual) > 0.55

func _try_move(vehicle: VehicleController) -> void:
	var command_token := round_token
	vehicle.state = VehicleController.State.PATH_CHECKING
	if not Routes.is_valid_route(vehicle.route, road_map):
		vehicle.blocked_feedback()
		_update_hud("Route data is invalid")
		return
	if not occupancy.can_reserve(vehicle.vehicle_id, vehicle.route, vehicle.lane_offset):
		effects.spawn_blocked_pulse(vehicle.global_position)
		audio_manager.play_event(Audio.Event.BLOCKED)
		vehicle.blocked_feedback()
		_update_hud("Blocked — clear the traffic first")
		_on_car_collision()
		return
	occupancy.reserve_route(vehicle.vehicle_id, vehicle.route, vehicle.lane_offset)
	moves += 1
	audio_manager.play_event(Audio.Event.VEHICLE_SELECT)
	vehicle.state = VehicleController.State.IDLE
	vehicle.select_feedback()
	await get_tree().create_timer(0.27).timeout
	if command_token != round_token or not is_instance_valid(vehicle) or vehicle.state != VehicleController.State.IDLE: return
	vehicle.drive_out()
	_update_hud("Clear route — vehicle exiting")

func _on_vehicle_exited(vehicle: VehicleController) -> void:
	effects.spawn_exit_sparkles(vehicle.global_position, Color("ffc52c"))
	audio_manager.play_event(Audio.Event.VEHICLE_EXIT)
	occupancy.release_vehicle(vehicle.vehicle_id, vehicle.route, vehicle.lane_offset)
	vehicles.erase(vehicle)
	completion_order.append(vehicle.vehicle_id)
	if vehicles.is_empty():
		if time_expired:
			return
		_finish_level()
	else:
		_update_hud("Nice move — choose another vehicle")

func _finish_level() -> void:
	if level_finished:
		return
	level_finished = true
	playing = false
	var token := round_token
	audio_manager.play_event(Audio.Event.COMPLETE)
	audio_manager.play_event(Audio.Event.COIN)
	var stars := level_manager.complete_level(level.id, moves, level.star_thresholds)
	ui.configure_progress(level_manager.highest_unlocked, level_manager.stars_by_level, level_manager.coins, Campaign.total_levels())
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

func _restart() -> void:
	if (lives_fail_open or time_expired) and not level_manager.spend_coins(RETRY_COST):
		if lives_fail_open:
			ui.show_lives_fail(level_manager.coins, CONTINUE_LIFE_COST, monetization_manager.rewarded_ready)
		elif time_expired:
			ui.show_time_options(level_manager.coins, TIME_BOOST_COST, true)
		return
	load_level(level_manager.get_level(level.id if not level.is_empty() else 1))

func _undo() -> void:
	if _has_active_motion():
		_update_hud("Undo is available after movement finishes")
		return
	if completion_order.is_empty():
		_update_hud("Nothing to undo")
		return
	var remaining_time := time_remaining
	completion_order.pop_back()
	load_level(level, completion_order)
	time_remaining = remaining_time
	ui.update_time(time_remaining)
	if not custom_timer:
		ui.show_time_briefing(int(level.id), ceili(time_remaining))
	_update_hud("Last vehicle restored")

func _has_active_motion() -> bool:
	for vehicle in vehicles:
		if is_instance_valid(vehicle) and vehicle.state != VehicleController.State.IDLE: return true
	return false

func _create_ui() -> void:
	ui = UI.new()
	add_child(ui)
	ui.configure_progress(level_manager.highest_unlocked, level_manager.stars_by_level, level_manager.coins, Campaign.total_levels())
	ui.configure_profile(level_manager.settings, level_manager.selected_cosmetic)
	ui.configure_monetization(level_manager.ads_removed, monetization_manager.purchase_available())
	ui.configure_coin_store(monetization_manager.coin_purchase_available())
	ui.configure_no_fill(monetization_manager.no_fill_this_launch)
	ui.configure_rewarded(monetization_manager.rewarded_ready)
	ui.configure_daily(level_manager.is_daily_completed(), level_manager.daily_streak)
	ui.configure_daily_reward(level_manager.effective_daily_reward_day(), level_manager.can_claim_daily_reward(), level_manager.is_free_chest_ready(), int(level_manager.powerups.get("hint", 3)))
	ui.play_requested.connect(_request_play)
	ui.daily_challenge_requested.connect(_request_daily_challenge)
	ui.daily_reward_claim_requested.connect(_on_daily_reward_claimed)
	ui.shop_free_chest_requested.connect(_on_shop_free_chest_requested)
	ui.shop_pack_requested.connect(monetization_manager.request_pack_purchase)
	ui.coffee_purchase_requested.connect(monetization_manager.request_coffee_purchase)
	ui.rate_app_requested.connect(monetization_manager.request_rate_app)
	ui.share_game_requested.connect(monetization_manager.request_share_game)
	ui.convoy_test_requested.connect(_play_convoy_test)
	ui.privacy_acknowledged.connect(_on_privacy_acknowledged)
	ui.privacy_dismissed.connect(_on_privacy_dismissed)
	ui.level_requested.connect(_load_selected_level)
	ui.restart_requested.connect(_restart)
	ui.undo_requested.connect(_undo)
	ui.pause_requested.connect(_pause_game)
	ui.resume_requested.connect(_resume_game)
	ui.main_menu_requested.connect(_show_main_menu)
	ui.next_requested.connect(_next_level_with_ad)
	ui.settings_changed.connect(_update_settings)
	ui.cosmetic_selected.connect(_select_cosmetic)
	ui.remove_ads_requested.connect(monetization_manager.request_remove_ads)
	ui.restore_purchases_requested.connect(monetization_manager.restore_purchases)
	ui.coin_purchase_requested.connect(monetization_manager.request_coin_purchase)
	ui.rewarded_ad_requested.connect(_watch_menu_reward)
	ui.time_start_requested.connect(_on_time_start)
	ui.time_boost_requested.connect(_on_time_boost_requested)
	ui.time_ad_requested.connect(_watch_time_ad)
	ui.time_options_closed.connect(_on_time_options_closed)
	ui.lives_continue_requested.connect(_continue_with_coins)
	ui.lives_ad_requested.connect(_watch_lives_ad)

func _request_play() -> void:
	if level_manager.privacy_acknowledged:
		_play_default()
	else:
		pending_play_after_privacy = true
		ui.show_privacy_popup()

func _request_daily_challenge() -> void:
	if level_manager.privacy_acknowledged:
		_play_daily_challenge()
	else:
		pending_daily_after_privacy = true
		ui.show_privacy_popup()

func _on_privacy_acknowledged() -> void:
	level_manager.acknowledge_privacy()
	monetization_manager.enable_ads()
	if pending_play_after_privacy:
		pending_play_after_privacy = false
		_play_default()
	elif pending_daily_after_privacy:
		pending_daily_after_privacy = false
		_play_daily_challenge()

func _on_privacy_dismissed() -> void:
	pending_play_after_privacy = false
	pending_daily_after_privacy = false

func _pause_game() -> void:
	if not playing: return
	get_tree().paused = true
	audio_manager.stop_car_tap()
	_sync_gameplay_music()
	ui.show_pause()
	monetization_manager.show_menu_banners()

func _resume_game() -> void:
	get_tree().paused = false
	_sync_gameplay_music()
	monetization_manager.show_gameplay_banner()

func _show_main_menu() -> void:
	round_token += 1
	if _camera_intro_tween != null and _camera_intro_tween.is_valid():
		_camera_intro_tween.kill()
	_camera_intro_tween = null
	get_tree().paused = false
	playing = false
	time_options_open = false
	pending_time_reward = false
	pending_menu_reward = false
	audio_manager.stop_car_tap()
	_sync_gameplay_music()
	ui.configure_progress(level_manager.highest_unlocked, level_manager.stars_by_level, level_manager.coins, Campaign.total_levels())
	ui.configure_profile(level_manager.settings, level_manager.selected_cosmetic)
	ui.configure_monetization(level_manager.ads_removed, monetization_manager.purchase_available())
	ui.configure_no_fill(monetization_manager.no_fill_this_launch)
	ui.configure_rewarded(monetization_manager.rewarded_ready)
	ui.configure_daily(level_manager.is_daily_completed(), level_manager.daily_streak)
	ui.configure_daily_reward(level_manager.effective_daily_reward_day(), level_manager.can_claim_daily_reward(), level_manager.is_free_chest_ready(), int(level_manager.powerups.get("hint", 3)))
	ui.show_main_menu()
	monetization_manager.show_menu_banners()
	monetization_manager.check_in_app_update()
	if has_entered_gameplay and not home_popup_shown_this_launch:
		home_popup_shown_this_launch = true
		ui.show_home_support_popup()

func _load_selected_level(level_id: int) -> void:
	load_level(level_manager.get_level(level_id))

func _play_default() -> void:
	load_level(level_manager.get_level(1))

func _play_convoy_test() -> void:
	_play_default()

func _play_daily_challenge() -> void:
	var daily_id := 1 + (level_manager.daily_seed() % Campaign.total_levels())
	load_level(level_manager.get_level(daily_id))

func _next_level() -> void:
	var next_id: int = mini(level_manager.highest_unlocked, int(level.id) + 1)
	load_level(level_manager.get_level(next_id))

func _next_level_with_ad() -> void:
	monetization_manager.on_between_levels()
	_next_level()

func _on_no_fill_changed(no_fill: bool) -> void:
	if ui != null:
		ui.configure_no_fill(no_fill)

func _on_daily_reward_claimed() -> void:
	var res := level_manager.claim_daily_reward()
	if bool(res.get("claimed", false)):
		audio_manager.play_event(Audio.Event.COIN)
	if ui != null:
		ui.configure_progress(level_manager.highest_unlocked, level_manager.stars_by_level, level_manager.coins, Campaign.total_levels())
		ui.configure_daily_reward(level_manager.effective_daily_reward_day(), level_manager.can_claim_daily_reward(), level_manager.is_free_chest_ready(), int(level_manager.powerups.get("hint", 3)))
		if ui.current_screen == "menu":
			ui.show_main_menu()

func _on_shop_free_chest_requested() -> void:
	pending_free_chest_reward = true
	if not monetization_manager.show_rewarded():
		pending_free_chest_reward = false

func _on_pack_purchase_verified(coins_amount: int, hints_amount: int, helis_amount: int) -> void:
	level_manager.add_reward_coins(coins_amount)
	level_manager.add_powerups(hints_amount, helis_amount)
	if ui != null:
		ui.configure_progress(level_manager.highest_unlocked, level_manager.stars_by_level, level_manager.coins, Campaign.total_levels())
		ui.configure_daily_reward(level_manager.effective_daily_reward_day(), level_manager.can_claim_daily_reward(), level_manager.is_free_chest_ready(), int(level_manager.powerups.get("hint", 3)))
		if ui.current_screen == "shop":
			ui.show_shop()

func _on_coffee_purchased(message: String) -> void:
	if ui != null:
		ui.configure_monetization(false, monetization_manager.purchase_available(), message)
		if ui.current_screen == "settings":
			ui.show_settings()

func _on_purchase_state_changed(owned: bool, message: String) -> void:
	if owned:
		level_manager.confirm_ads_removed()
	if ui != null:
		ui.configure_monetization(level_manager.ads_removed, monetization_manager.purchase_available(), message)
		if ui.current_screen == "settings":
			ui.show_settings()

func _on_coin_purchase_verified(amount: int) -> void:
	level_manager.add_reward_coins(amount)
	if ui != null:
		ui.configure_progress(level_manager.highest_unlocked, level_manager.stars_by_level, level_manager.coins, Campaign.total_levels())
		if ui.current_screen == "settings":
			ui.show_settings()

func _on_coin_purchase_state_changed(message: String) -> void:
	if ui != null:
		ui.configure_coin_store(monetization_manager.coin_purchase_available(), message)
		if ui.current_screen == "settings":
			ui.show_settings()

func _on_rewarded_ready_changed(ready: bool) -> void:
	if ui != null:
		ui.configure_rewarded(ready)

func _on_reward_earned(coins: int) -> void:
	audio_manager.play_event(Audio.Event.COIN)
	level_manager.add_reward_coins(coins)
	if ui != null:
		ui.update_coins(level_manager.coins)
	if pending_lives_reward and lives_fail_open:
		pending_lives_reward = false
		_resume_after_lives_continue()
		return
	if pending_time_reward and time_options_open:
		pending_time_reward = false
		_resume_with_added_time()
		return
	if pending_free_chest_reward and ui != null:
		pending_free_chest_reward = false
		level_manager.mark_free_chest_opened()
		ui.configure_progress(level_manager.highest_unlocked, level_manager.stars_by_level, level_manager.coins, Campaign.total_levels())
		ui.configure_daily_reward(level_manager.effective_daily_reward_day(), level_manager.can_claim_daily_reward(), level_manager.is_free_chest_ready(), int(level_manager.powerups.get("hint", 3)))
		if ui.current_screen == "shop":
			ui.show_shop()
		return
	if pending_menu_reward and ui != null:
		pending_menu_reward = false
		ui.configure_progress(level_manager.highest_unlocked, level_manager.stars_by_level, level_manager.coins, Campaign.total_levels())
		ui.configure_rewarded(monetization_manager.rewarded_ready)
		if ui.current_screen == "settings":
			ui.show_settings()
		elif ui.current_screen == "menu":
			ui.show_main_menu()
		elif ui.current_screen == "complete":
			ui.update_coins(level_manager.coins)
		monetization_manager.show_menu_banners()

func _on_rewarded_ad_closed(earned: bool) -> void:
	if not earned:
		pending_time_reward = false
		pending_menu_reward = false
		pending_lives_reward = false

func _on_car_collision() -> void:
	if level_finished or lives_fail_open or lives <= 0:
		return
	lives = maxi(0, lives - 1)
	if ui != null:
		ui.update_lives(lives, MAX_LIVES)
	if lives <= 0:
		lives_fail_open = true
		playing = false
		audio_manager.stop_car_tap()
		audio_manager.play_event(Audio.Event.FAIL)
		_on_lives_exhausted()
		if ui != null:
			ui.show_lives_fail(level_manager.coins, CONTINUE_LIFE_COST, monetization_manager.rewarded_ready)

func _on_lives_exhausted() -> void:
	pass

func _continue_with_coins() -> void:
	if not lives_fail_open:
		return
	if level_manager.spend_coins(CONTINUE_LIFE_COST):
		_resume_after_lives_continue()
	elif ui != null:
		ui.show_lives_fail(level_manager.coins, CONTINUE_LIFE_COST, monetization_manager.rewarded_ready)

func _watch_lives_ad() -> void:
	if not lives_fail_open or not monetization_manager.rewarded_ready:
		return
	pending_lives_reward = monetization_manager.show_rewarded()

func _resume_after_lives_continue() -> void:
	lives = MAX_LIVES
	lives_fail_open = false
	pending_lives_reward = false
	if ui != null:
		ui.close_time_overlay()
		ui.update_lives(lives, MAX_LIVES)
		ui.update_coins(level_manager.coins)
		ui.configure_progress(level_manager.highest_unlocked, level_manager.stars_by_level, level_manager.coins, Campaign.total_levels())
	playing = true
	_after_lives_continue()

func _after_lives_continue() -> void:
	pass

func _watch_menu_reward() -> void:
	pending_menu_reward = monetization_manager.show_rewarded()

func _on_time_start() -> void:
	audio_manager.play_event(Audio.Event.START)
	playing = true

func _on_time_expired() -> void:
	time_expired = true
	time_options_open = true
	playing = false
	audio_manager.play_event(Audio.Event.FAIL)
	ui.show_time_options(level_manager.coins, TIME_BOOST_COST, true)

func _on_time_boost_requested() -> void:
	if not time_options_open:
		time_options_open = true
		playing = false
		ui.show_time_options(level_manager.coins, TIME_BOOST_COST, false)
		return
	if level_manager.spend_coins(TIME_BOOST_COST):
		_resume_with_added_time()
	else:
		ui.show_time_options(level_manager.coins, TIME_BOOST_COST, time_expired)

func _watch_time_ad() -> void:
	if not time_options_open or not monetization_manager.rewarded_ready:
		return
	pending_time_reward = monetization_manager.show_rewarded()

func _on_time_options_closed() -> void:
	if time_expired:
		return
	time_options_open = false
	playing = true

func _resume_with_added_time() -> void:
	time_remaining += TIME_BOOST_SECONDS
	time_expired = false
	time_options_open = false
	ui.close_time_overlay()
	ui.update_time(time_remaining)
	ui.configure_progress(level_manager.highest_unlocked, level_manager.stars_by_level, level_manager.coins, Campaign.total_levels())
	playing = true
	_after_time_boost()
	if vehicles.is_empty() and not custom_timer:
		_finish_level()

func _after_time_boost() -> void:
	pass

func _update_settings(next_settings: Dictionary) -> void:
	level_manager.update_settings(next_settings)
	quality_manager.apply(str(level_manager.settings.get("graphics_quality", "mobile")))
	audio_manager.configure(level_manager.settings)
	performance_monitor.configure(str(level_manager.settings.get("graphics_quality", "mobile")))
	_sync_daily_notifications()

func _sync_daily_notifications() -> void:
	var enabled := bool(level_manager.settings.get("daily_notifications", true))
	if OS.get_name() == "Android" and Engine.has_singleton("DailyNotifications"):
		Engine.get_singleton("DailyNotifications").call("set_enabled", enabled)

func _select_cosmetic(cosmetic: String) -> void:
	level_manager.select_cosmetic(cosmetic)
	ui.configure_profile(level_manager.settings, level_manager.selected_cosmetic)

func _create_interface() -> void:
	var layer := CanvasLayer.new(); add_child(layer)
	var top := Panel.new(); top.position = Vector2(42, 34); top.size = Vector2(636, 148)
	var top_style := _panel_style(DesignTokens.PANEL, 24); top.add_theme_stylebox_override("panel", top_style); layer.add_child(top)
	var title := Label.new(); title.text = "CITY RESCUE PUZZLE"; title.position = Vector2(68, 49); title.size = Vector2(330, 38); title.add_theme_font_size_override("font_size", 24); title.add_theme_color_override("font_color", Color.WHITE); layer.add_child(title)
	moves_label = Label.new(); moves_label.position = Vector2(68, 91); moves_label.size = Vector2(420, 34); moves_label.add_theme_font_size_override("font_size", 20); moves_label.add_theme_color_override("font_color", DesignTokens.GOLD); layer.add_child(moves_label)
	status_label = Label.new(); status_label.position = Vector2(68, 128); status_label.size = Vector2(510, 30); status_label.add_theme_font_size_override("font_size", 16); status_label.add_theme_color_override("font_color", Color("d9efff")); layer.add_child(status_label)
	var restart := _action_button("Restart", Vector2(505, 65)); restart.pressed.connect(_restart); layer.add_child(restart)
	var undo := _action_button("Undo", Vector2(505, 121)); undo.pressed.connect(_undo); layer.add_child(undo)
	var footer := Panel.new(); footer.position = Vector2(36, 1140); footer.size = Vector2(648, 92); footer.add_theme_stylebox_override("panel", _panel_style(Color("10223ad9"), 28)); layer.add_child(footer)
	var guide := Label.new(); guide.text = "TAP A CAR  •  OR SWIPE WITH ITS ARROW"; guide.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; guide.position = Vector2(55, 1171); guide.size = Vector2(610, 30); guide.add_theme_font_size_override("font_size", 17); guide.add_theme_color_override("font_color", Color.WHITE); layer.add_child(guide)

func _action_button(text: String, position: Vector2) -> Button:
	var button := Button.new(); button.text = text; button.position = position; button.size = Vector2(145, 45); button.add_theme_font_size_override("font_size", 16)
	var normal := StyleBoxFlat.new(); normal.bg_color = DesignTokens.PRIMARY; normal.corner_radius_top_left = 14; normal.corner_radius_top_right = 14; normal.corner_radius_bottom_left = 14; normal.corner_radius_bottom_right = 14
	button.add_theme_stylebox_override("normal", normal)
	return button

func _panel_style(color: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new(); style.bg_color = color; style.border_color = DesignTokens.PANEL_HIGHLIGHT; style.set_border_width_all(2); style.corner_radius_top_left = radius; style.corner_radius_top_right = radius; style.corner_radius_bottom_left = radius; style.corner_radius_bottom_right = radius; style.shadow_color = Color("07111dbb"); style.shadow_size = 10; style.shadow_offset = Vector2(0, 6); return style

func _update_hud(message: String) -> void:
	if ui == null or level.is_empty(): return
	ui.update_gameplay(level.id, _display_moves(), level.move_target, vehicles.size(), message)

func _display_moves() -> int:
	return maxi(0, int(level.get("move_limit", moves)) - moves)
