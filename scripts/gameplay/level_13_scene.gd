extends "res://scripts/core/game.gd"

const LEVEL_13_ID := 13
const LEVEL_13_MOVE_LIMIT := 36
const CAR_YELLOW := Color("f6b21a")
const CAR_TYPES := [
	"suv",
	"compact_sedan",
	"hatchback",
	"sports_car",
	"minivan",
	"taxi",
	"delivery_van",
	"police_car",
	"school_bus",
	"delivery_truck",
	"fire_truck",
	"crane_truck"
]
const CAR_PALETTE := [
	Color("ffffff"),
	Color("ffe066"),
	Color("ff7b7b"),
	Color("70c8ff"),
	Color("7cf29c"),
	Color("ffb067"),
	Color("d69eff"),
	Color("6ef3e8")
]


func _ready() -> void:
	super._ready()


func _play_default() -> void:
	load_level(build_level_13())


func _restart() -> void:
	load_level(build_level_13())


func _vehicle_at_screen(screen_position: Vector2) -> VehicleController:
	var origin := camera.project_ray_origin(screen_position)
	var ray := camera.project_ray_normal(screen_position)
	if abs(ray.y) < 0.001:
		return null
	var hit := origin + ray * (-origin.y / ray.y)
	var chosen: VehicleController = null
	var closest := 1.55
	for vehicle in vehicles:
		if not is_instance_valid(vehicle) or vehicle.state != VehicleController.State.IDLE:
			continue
		var vehicle_position := vehicle.global_position
		var distance := Vector2(hit.x - vehicle_position.x, hit.z - vehicle_position.z).length()
		if distance < closest:
			closest = distance
			chosen = vehicle
	return chosen


func _try_move(vehicle: VehicleController) -> void:
	if not Routes.is_valid_route(vehicle.route, road_map):
		vehicle.blocked_feedback()
		_update_hud("Route data is invalid")
		return
	var blocker := _find_first_blocker(vehicle.vehicle_id, vehicle.route)
	if not blocker.is_empty():
		_animate_bump_and_return(vehicle, blocker)
		_update_hud("Blocked — clear the car in its way first")
		return
	occupancy.release_vehicle(vehicle.vehicle_id, vehicle.route, vehicle.lane_offset)
	moves += 1
	audio_manager.play_event(Audio.Event.VEHICLE_SELECT)
	vehicle.drive_out()
	_update_hud("Clear route — vehicle exiting")


func _is_route_free_of_stationary(id: String, route: Array) -> bool:
	return _find_first_blocker(id, route).is_empty()


func _find_first_blocker(id: String, route: Array) -> Dictionary:
	var mover: VehicleController = null
	for v in vehicles:
		if is_instance_valid(v) and v.vehicle_id == id:
			mover = v
			break
	var mover_lane := mover.lane_offset if mover != null else 0.0
	for index in range(1, route.size()):
		var cell: Vector2i = route[index]
		var key := "%d:%d" % [cell.x, cell.y]
		if occupancy.occupied.has(key) and occupancy.occupied[key] != id:
			var blocker_id := str(occupancy.occupied[key])
			var road_kind := str(road_map.get(cell, {}).get("kind", "one_lane"))
			if road_kind != "one_lane" and mover != null:
				var other: VehicleController = null
				for v in vehicles:
					if is_instance_valid(v) and v.vehicle_id == blocker_id:
						other = v
						break
				if other != null and other.route.size() >= 2:
					var my_dir: Vector2i = route[index] - route[index - 1]
					var other_dir: Vector2i = other.route[1] - other.route[0]
					if my_dir.x * other_dir.y - my_dir.y * other_dir.x == 0:
						var my_lane_vec := Vector2(-float(my_dir.y), float(my_dir.x)) * mover_lane
						var other_lane_vec := Vector2(-float(other_dir.y), float(other_dir.x)) * other.lane_offset
						if (my_lane_vec - other_lane_vec).length() > 0.45:
							continue
			return {"cell_index": index, "blocker_id": blocker_id}
	return {}


func _animate_bump_and_return(vehicle: VehicleController, blocker: Dictionary) -> void:
	vehicle.state = VehicleController.State.BLOCKED
	var blocker_idx: int = int(blocker.cell_index)
	var blocker_id: String = str(blocker.blocker_id)
	var start_pos := vehicle.position
	var start_rot := vehicle.rotation.y

	var waypoints: Array[Dictionary] = []
	for i in range(1, blocker_idx):
		var dir := Vector2i(vehicle.route[i] - vehicle.route[i - 1])
		waypoints.append({"pos": vehicle._lane_position(vehicle.route[i], dir), "rot": vehicle._angle_for(dir)})

	var prev_cell: Vector2i = vehicle.route[blocker_idx - 1]
	var blocker_cell: Vector2i = vehicle.route[blocker_idx]
	var hit_dir := blocker_cell - prev_cell
	var prev_pos := vehicle._lane_position(prev_cell, hit_dir)
	var hit_pos := vehicle._lane_position(blocker_cell, hit_dir)
	waypoints.append({"pos": prev_pos.lerp(hit_pos, 0.45), "rot": vehicle._angle_for(hit_dir)})

	var tween := create_tween()
	for wp in waypoints:
		tween.tween_property(vehicle, "rotation:y", float(wp.rot), 0.06).set_trans(Tween.TRANS_SINE)
		tween.parallel().tween_property(vehicle, "position", wp.pos as Vector3, 0.13).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	tween.tween_callback(func():
		if is_instance_valid(vehicle):
			effects.spawn_blocked_pulse(vehicle.global_position)
		audio_manager.play_event(Audio.Event.BLOCKED)
		_nudge_blocker(blocker_id, hit_dir)
		_on_car_collision()
	)

	for i in range(waypoints.size() - 2, -1, -1):
		var wp: Dictionary = waypoints[i]
		tween.tween_property(vehicle, "position", wp.pos as Vector3, 0.11).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		tween.parallel().tween_property(vehicle, "rotation:y", float(wp.rot), 0.06).set_trans(Tween.TRANS_SINE)

	tween.tween_property(vehicle, "position", start_pos, 0.13).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(vehicle, "rotation:y", start_rot, 0.06).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(func():
		if is_instance_valid(vehicle) and vehicle.state == VehicleController.State.BLOCKED:
			vehicle.state = VehicleController.State.IDLE
	)


func _nudge_blocker(blocker_id: String, hit_dir: Vector2i) -> void:
	var blocker_vehicle: VehicleController = null
	for v in vehicles:
		if is_instance_valid(v) and v.vehicle_id == blocker_id:
			blocker_vehicle = v
			break
	if blocker_vehicle == null or blocker_vehicle.state != VehicleController.State.IDLE:
		return
	var orig_pos := blocker_vehicle.position
	var push := Vector3(float(hit_dir.x), 0.0, float(hit_dir.y)) * 0.18
	var t := create_tween()
	t.tween_property(blocker_vehicle, "position", orig_pos + push, 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(blocker_vehicle, "position", orig_pos, 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func load_level(data: Dictionary, completed: Array[String] = []) -> void:
	super.load_level(data, completed)
	_polish_board_visuals()
	_enhance_vehicles()
	_animate_cars_drive_in()
	_fit_board_to_camera()


func _animate_cars_drive_in() -> void:
	for idx in range(vehicles.size()):
		var vehicle := vehicles[idx]
		if not is_instance_valid(vehicle) or vehicle.vehicle_id == "ambulance" or vehicle.route.size() < 2:
			continue
		var target_pos := vehicle.position
		var dir := Vector2i(vehicle.route[1] - vehicle.route[0])
		var back_offset := Vector3(float(dir.x), 0.0, float(dir.y)) * (CELL_SIZE * 1.35)
		vehicle.position = target_pos - back_offset
		var delay := float(idx) * 0.005
		var tween := vehicle.create_tween()
		if delay > 0.0:
			tween.tween_interval(delay)
		tween.tween_property(vehicle, "position", target_pos, 0.20).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _polish_board_visuals() -> void:
	if level_root == null:
		return
	for child in level_root.get_children():
		if child is MeshInstance3D or child.name.begins_with("Road_") or child.has_meta("road_kind") or child.name == "HighwayDividers":
			child.visible = false

	var visuals := Node3D.new()
	visuals.name = "SeamlessBoardVisuals"
	level_root.add_child(visuals)

	var asphalt_mat := WorldMaterials.get_material("asphalt")
	var curb_mat := WorldMaterials.get_material("curb")
	var grass_mat := WorldMaterials.get_material("grass")
	var marking_mat := WorldMaterials.get_material("marking")

	var cols: int = int(level.size.x)
	var rows: int = int(level.size.y)
	var board_w := float(cols) * CELL_SIZE
	var board_h := float(rows) * CELL_SIZE

	# Continuous dark asphalt base covering the whole board
	_add_box_mesh(visuals, Vector3(board_w, 0.14, board_h), Vector3(0, 0.06, 0), asphalt_mat)

	var x_islands: Array = level.get("x_islands", [Vector2i(0, 0), Vector2i(2, 2), Vector2i(5, 5), Vector2i(7, 7)])
	var y_islands: Array = level.get("y_islands", [Vector2i(0, 1), Vector2i(3, 3), Vector2i(6, 7), Vector2i(9, 9), Vector2i(12, 13)])

	# Draw dashed lane dividers ONLY on straight segments flanked by grass islands (never inside intersections).
	var v_dividers: Array = level.get("v_dividers", [3])
	for vx in v_dividers:
		var center_x := _cell_range_center_x(int(vx), int(vx) + 1, cols)
		for yi in y_islands:
			var z_min := (float(yi.x) - 0.5 - float(rows - 1) * 0.5) * CELL_SIZE + 0.35
			var z_max := (float(yi.y) + 0.5 - float(rows - 1) * 0.5) * CELL_SIZE - 0.35
			_add_divider_dashes(visuals, false, center_x, z_min, z_max, marking_mat)

	var h_dividers: Array = level.get("h_dividers", [4, 10])
	for hy in h_dividers:
		var ave_z := _cell_range_center_z(int(hy), int(hy) + 1, rows)
		for xi in x_islands:
			var x_min := (float(xi.x) - 0.5 - float(cols - 1) * 0.5) * CELL_SIZE + 0.35
			var x_max := (float(xi.y) + 0.5 - float(cols - 1) * 0.5) * CELL_SIZE - 0.35
			_add_divider_dashes(visuals, true, ave_z, x_min, x_max, marking_mat)

	# Raised vibrant green grass islands with crisp white curbs
	var curb_pad := 0.16

	for xi in x_islands:
		for yi in y_islands:
			var w := float(xi.y - xi.x + 1) * CELL_SIZE
			var h := float(yi.y - yi.x + 1) * CELL_SIZE
			var cx := _cell_range_center_x(xi.x, xi.y, cols)
			var cz := _cell_range_center_z(yi.x, yi.y, rows)
			_add_box_mesh(visuals, Vector3(w + curb_pad * 2.0, 0.18, h + curb_pad * 2.0), Vector3(cx, 0.14, cz), curb_mat)
			_add_box_mesh(visuals, Vector3(w - 0.04, 0.21, h - 0.04), Vector3(cx, 0.15, cz), grass_mat)


func _cell_range_center_x(x_min: int, x_max: int, cols: int) -> float:
	var avg := float(x_min + x_max) * 0.5
	return (avg - float(cols - 1) * 0.5) * CELL_SIZE


func _cell_range_center_z(y_min: int, y_max: int, rows: int) -> float:
	var avg := float(y_min + y_max) * 0.5
	return (avg - float(rows - 1) * 0.5) * CELL_SIZE


func _add_divider_dashes(parent: Node3D, is_horizontal: bool, fixed_coord: float, span_min: float, span_max: float, mat: Material) -> void:
	var span := span_max - span_min
	if span < 0.45:
		return
	var period := 1.25
	var count := maxi(1, int(round(span / period)))
	var step := span / float(count)
	var dash_len := minf(0.68, step * 0.52)
	for i in range(count):
		var pos_along := span_min + step * (float(i) + 0.5)
		var size := Vector3(dash_len, 0.02, 0.11) if is_horizontal else Vector3(0.11, 0.02, dash_len)
		var pos := Vector3(pos_along, 0.18, fixed_coord) if is_horizontal else Vector3(fixed_coord, 0.18, pos_along)
		_add_box_mesh(parent, size, pos, mat)


func _flat_material(color: Color, roughness: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	return mat


func _add_box_mesh(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh_instance.mesh = box
	mesh_instance.position = pos
	mesh_instance.material_override = mat
	parent.add_child(mesh_instance)
	return mesh_instance


func _enhance_vehicles() -> void:
	var plate_mat := _flat_material(Color("ffffff"), 0.25)
	plate_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var arrow_mat := _flat_material(Color("121212"), 0.25)
	arrow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	for vehicle in vehicles:
		if not is_instance_valid(vehicle) or vehicle.vehicle_visual == null:
			continue
		var v_scale := 0.90 if absf(vehicle.lane_offset) > 0.05 else 1.12
		vehicle.vehicle_visual.scale = Vector3(v_scale, v_scale, v_scale)
		_apply_vehicle_body_tint(vehicle)
		for child in vehicle.vehicle_visual.find_children("*", "MeshInstance3D", true, false):
			var mesh_instance := child as MeshInstance3D
			if mesh_instance == null:
				continue
			var mat := mesh_instance.material_override as StandardMaterial3D
			if mat != null and mat.albedo_texture != null:
				mesh_instance.visible = false

		var sign_type := _resolve_sign_type(vehicle.route, _vehicle_route_sign(vehicle.vehicle_id))
		var sign_root := Node3D.new()
		sign_root.name = "RoofArrowSign"
		sign_root.position = Vector3(0, 1.85, 0)
		vehicle.vehicle_visual.add_child(sign_root)

		_add_box_mesh(sign_root, Vector3(0.92, 0.04, 0.92), Vector3.ZERO, plate_mat)
		_build_3d_arrow(sign_root, sign_type, arrow_mat)


var _tint_material_cache: Dictionary = {}


func _apply_vehicle_body_tint(vehicle: VehicleController) -> void:
	if vehicle.vehicle_id == "ambulance":
		return
	var tint := _vehicle_color(vehicle.vehicle_id)
	if tint == Color.WHITE:
		return
	var imported := vehicle.vehicle_visual.get_node_or_null("ImportedCar")
	if imported == null:
		return
	for node_name in ["body", "spoiler"]:
		for child in imported.find_children(node_name, "MeshInstance3D", true, false):
			var mi := child as MeshInstance3D
			if mi == null or mi.mesh == null or mi.mesh.get_surface_count() == 0:
				continue
			var base_mat := mi.get_active_material(0)
			if base_mat is StandardMaterial3D:
				var cache_key := "%d:%s" % [base_mat.get_rid().get_id(), tint.to_html()]
				var mat: StandardMaterial3D = _tint_material_cache.get(cache_key)
				if mat == null:
					mat = base_mat.duplicate() as StandardMaterial3D
					mat.albedo_color = tint
					_tint_material_cache[cache_key] = mat
				mi.set_surface_override_material(0, mat)


func _vehicle_color(id: String) -> Color:
	for v in level.vehicles:
		if v.id == id:
			return v.get("color", Color.WHITE)
	return Color.WHITE


func _vehicle_route_sign(id: String) -> String:
	for v in level.vehicles:
		if v.id == id:
			return str(v.get("route_sign", ""))
	return ""


func _resolve_sign_type(route: Array, route_sign: String) -> String:
	if route_sign == "u_turn_left" or route_sign == "u_turn_right":
		return route_sign
	if route.size() < 3:
		return "straight"
	var first_dir := Vector2i(route[1] - route[0])
	var last_dir := Vector2i(route[route.size() - 1] - route[route.size() - 2])
	if first_dir == -last_dir:
		return "u_turn_left"
	var cross := first_dir.x * last_dir.y - first_dir.y * last_dir.x
	if cross < 0:
		return "left"
	if cross > 0:
		return "right"
	return "straight"


func _build_3d_arrow(parent: Node3D, sign_type: String, mat: Material) -> void:
	var y := 0.03
	var w := 0.14
	match sign_type:
		"straight":
			_add_box_mesh(parent, Vector3(w, 0.02, 0.44), Vector3(0, y, 0.06), mat)
			_add_arrow_head(parent, Vector3(0, y, -0.22), 0.0, mat)
		"left":
			_add_box_mesh(parent, Vector3(w, 0.02, 0.34), Vector3(0.14, y, 0.09), mat)
			_add_box_mesh(parent, Vector3(0.32, 0.02, w), Vector3(0.05, y, -0.05), mat)
			_add_arrow_head(parent, Vector3(-0.18, y, -0.05), PI * 0.5, mat)
		"right":
			_add_box_mesh(parent, Vector3(w, 0.02, 0.34), Vector3(-0.14, y, 0.09), mat)
			_add_box_mesh(parent, Vector3(0.32, 0.02, w), Vector3(-0.05, y, -0.05), mat)
			_add_arrow_head(parent, Vector3(0.18, y, -0.05), -PI * 0.5, mat)
		"u_turn_left":
			_add_box_mesh(parent, Vector3(w, 0.02, 0.38), Vector3(0.16, y, 0.05), mat)
			_add_box_mesh(parent, Vector3(0.42, 0.02, w), Vector3(0.0, y, -0.14), mat)
			_add_box_mesh(parent, Vector3(w, 0.02, 0.24), Vector3(-0.16, y, -0.02), mat)
			_add_arrow_head(parent, Vector3(-0.16, y, 0.16), PI, mat)
		"u_turn_right":
			_add_box_mesh(parent, Vector3(w, 0.02, 0.38), Vector3(-0.16, y, 0.05), mat)
			_add_box_mesh(parent, Vector3(0.42, 0.02, w), Vector3(0.0, y, -0.14), mat)
			_add_box_mesh(parent, Vector3(w, 0.02, 0.24), Vector3(0.16, y, -0.02), mat)
			_add_arrow_head(parent, Vector3(0.16, y, 0.16), PI, mat)


func _add_arrow_head(parent: Node3D, pos: Vector3, rot_y: float, mat: Material) -> void:
	var head := Node3D.new()
	head.position = pos
	head.rotation.y = rot_y
	parent.add_child(head)
	_add_box_mesh(head, Vector3(0.32, 0.02, 0.10), Vector3(0, 0, 0.04), mat)
	_add_box_mesh(head, Vector3(0.20, 0.02, 0.09), Vector3(0, 0, -0.02), mat)
	_add_box_mesh(head, Vector3(0.09, 0.02, 0.08), Vector3(0, 0, -0.08), mat)


func _fit_board_to_camera() -> void:
	if camera == null or level_root == null or level.is_empty():
		return
	var board_size: Vector2i = level.size
	var board_width := float(board_size.x) * CELL_SIZE * level_root.scale.x
	var board_height := float(board_size.y) * CELL_SIZE * level_root.scale.z
	var viewport_size := get_viewport().get_visible_rect().size
	var aspect := viewport_size.x / maxf(viewport_size.y, 1.0)
	if aspect <= 0.0:
		aspect = 720.0 / 1280.0
	var required_size := maxf(board_height, board_width / aspect) * 1.06
	level_start_camera_size = clampf(required_size, CAMERA_MIN_SIZE, CAMERA_MAX_SIZE)
	_set_camera_size(level_start_camera_size)


static func build_level_13() -> Dictionary:
	var roads: Array[Dictionary] = []
	var horizontal_rows := [2, 4, 5, 8, 10, 11]
	var vertical_cols := [1, 3, 4, 6]

	for y in range(14):
		for x in range(8):
			var cell := Vector2i(x, y)
			var is_h := y in horizontal_rows
			var is_v := x in vertical_cols

			if y == 0 or y == 13:
				if is_v:
					roads.append(_tile(cell, "exit", 0))
				continue

			if x == 0 or x == 7:
				if is_h:
					roads.append(_tile(cell, "exit", 1))
				continue

			if is_h and is_v:
				roads.append(_tile(cell, "cross", 0))
			elif is_h:
				roads.append(_tile(cell, "two_lane", 1))
			elif is_v:
				roads.append(_tile(cell, "two_lane", 0))

	var vehicles: Array[Dictionary] = [
		# Row y = 1 (above H1)
		_car("v01", [Vector2i(1, 1), Vector2i(1, 2), Vector2i(0, 2)]),
		_car("v02", [Vector2i(3, 1), Vector2i(3, 2), Vector2i(3, 1), Vector2i(3, 0)], -1, "u_turn_left"),
		_car("v03", [
			Vector2i(4, 1), Vector2i(4, 2), Vector2i(4, 3), Vector2i(4, 4),
			Vector2i(4, 5), Vector2i(4, 6), Vector2i(4, 7), Vector2i(4, 8),
			Vector2i(4, 9), Vector2i(4, 10), Vector2i(4, 11), Vector2i(4, 12), Vector2i(4, 13)
		]),
		_car("v04", [Vector2i(6, 1), Vector2i(6, 0)]),

		# Row y = 2 (H1, 1-lane)
		_car("v05", [Vector2i(1, 2), Vector2i(0, 2)]),
		_car("v06", [Vector2i(2, 2), Vector2i(1, 2), Vector2i(1, 1), Vector2i(1, 0)]),
		_car("v36", [Vector2i(3, 2), Vector2i(2, 2), Vector2i(1, 2), Vector2i(0, 2)]),
		_car("v07", [Vector2i(4, 2), Vector2i(3, 2), Vector2i(2, 2), Vector2i(1, 2), Vector2i(0, 2)]),
		_car("v37", [Vector2i(5, 2), Vector2i(4, 2), Vector2i(3, 2), Vector2i(2, 2), Vector2i(1, 2), Vector2i(0, 2)]),
		_car("v08", [Vector2i(6, 2), Vector2i(5, 2), Vector2i(4, 2), Vector2i(3, 2), Vector2i(2, 2), Vector2i(1, 2), Vector2i(0, 2)]),

		# Row y = 3 (between H1 and H2)
		_car("v09", [Vector2i(1, 3), Vector2i(1, 2), Vector2i(0, 2)]),
		_car("v10", [Vector2i(3, 3), Vector2i(3, 2), Vector2i(2, 2), Vector2i(1, 2), Vector2i(0, 2)]),
		_car("v38", [Vector2i(4, 3), Vector2i(4, 2), Vector2i(3, 2), Vector2i(2, 2), Vector2i(1, 2), Vector2i(0, 2)]),
		_car("v11", [Vector2i(6, 3), Vector2i(6, 2), Vector2i(6, 3), Vector2i(6, 4), Vector2i(7, 4)], 1, "u_turn_right"),

		# Row y = 4 (H2 upper lane, 2-lane avenue)
		_car("v12", [Vector2i(2, 4), Vector2i(1, 4), Vector2i(1, 3), Vector2i(1, 2), Vector2i(1, 1), Vector2i(1, 0)]),
		_car("v13", [Vector2i(3, 4), Vector2i(2, 4), Vector2i(1, 4), Vector2i(0, 4)]),
		_car("v39", [Vector2i(4, 4), Vector2i(3, 4), Vector2i(2, 4), Vector2i(1, 4), Vector2i(0, 4)]),
		_car("v14", [Vector2i(5, 4), Vector2i(4, 4), Vector2i(5, 4), Vector2i(6, 4), Vector2i(7, 4)], 1, "u_turn_right"),
		_car("v40", [Vector2i(6, 4), Vector2i(7, 4)]),

		# Row y = 5 (H2 lower lane, 2-lane avenue)
		_car("v31", [Vector2i(1, 5), Vector2i(0, 5)]),
		_car("v41", [Vector2i(2, 5), Vector2i(1, 5), Vector2i(0, 5)]),
		_car("v42", [Vector2i(3, 5), Vector2i(2, 5), Vector2i(1, 5), Vector2i(0, 5)]),
		_car("v32", [Vector2i(4, 5), Vector2i(5, 5), Vector2i(6, 5), Vector2i(7, 5)]),
		_car("v43", [Vector2i(5, 5), Vector2i(6, 5), Vector2i(7, 5)]),
		_car("v33", [Vector2i(6, 5), Vector2i(7, 5)]),

		# Row y = 6 (upper half between H2 and H3)
		_car("v15", [Vector2i(1, 6), Vector2i(1, 5), Vector2i(0, 5)]),
		_car("v44", [Vector2i(3, 6), Vector2i(3, 5), Vector2i(2, 5), Vector2i(1, 5), Vector2i(0, 5)]),
		_car("v16", [Vector2i(4, 6), Vector2i(4, 5), Vector2i(5, 5), Vector2i(6, 5), Vector2i(7, 5)]),
		_car("v17", [Vector2i(6, 6), Vector2i(6, 5), Vector2i(6, 4), Vector2i(5, 4), Vector2i(4, 4), Vector2i(3, 4), Vector2i(2, 4), Vector2i(1, 4), Vector2i(0, 4)]),

		# Row y = 7 (lower half between H2 and H3)
		_car("v45", [Vector2i(1, 7), Vector2i(1, 6), Vector2i(1, 5), Vector2i(0, 5)]),
		_car("v18", [Vector2i(3, 7), Vector2i(3, 6), Vector2i(3, 5), Vector2i(3, 4), Vector2i(3, 3), Vector2i(3, 2), Vector2i(3, 1), Vector2i(3, 0)]),
		_car("v19", [Vector2i(4, 7), Vector2i(4, 6), Vector2i(4, 5), Vector2i(5, 5), Vector2i(6, 5), Vector2i(7, 5)]),
		_car("v46", [Vector2i(6, 7), Vector2i(6, 8), Vector2i(7, 8)]),

		# Row y = 8 (H3, 1-lane)
		_car("v47", [Vector2i(1, 8), Vector2i(0, 8)]),
		_car("v20", [Vector2i(2, 8), Vector2i(3, 8), Vector2i(3, 7), Vector2i(3, 6), Vector2i(3, 5), Vector2i(3, 4), Vector2i(3, 3), Vector2i(3, 2), Vector2i(3, 1), Vector2i(3, 0)]),
		_car("v48", [Vector2i(3, 8), Vector2i(3, 9), Vector2i(3, 10), Vector2i(3, 11), Vector2i(3, 12), Vector2i(3, 13)]),
		_car("v49", [Vector2i(4, 8), Vector2i(5, 8), Vector2i(6, 8), Vector2i(7, 8)]),
		_car("v21", [Vector2i(5, 8), Vector2i(6, 8), Vector2i(6, 7), Vector2i(6, 6), Vector2i(6, 5), Vector2i(6, 4), Vector2i(6, 3), Vector2i(6, 2), Vector2i(6, 1), Vector2i(6, 0)]),
		_car("v50", [Vector2i(6, 8), Vector2i(7, 8)]),

		# Row y = 9 (between H3 and H4)
		_car("v22", [Vector2i(1, 9), Vector2i(1, 10), Vector2i(0, 10)]),
		_car("v51", [Vector2i(3, 9), Vector2i(3, 10), Vector2i(3, 11), Vector2i(3, 12), Vector2i(3, 13)]),
		_car("v23", [Vector2i(4, 9), Vector2i(4, 8), Vector2i(3, 8), Vector2i(2, 8), Vector2i(1, 8), Vector2i(0, 8)]),
		_car("v24", [Vector2i(6, 9), Vector2i(6, 8), Vector2i(7, 8)]),

		# Row y = 10 (H4 upper lane, 2-lane avenue)
		_car("v52", [Vector2i(1, 10), Vector2i(0, 10)]),
		_car("v25", [Vector2i(2, 10), Vector2i(3, 10), Vector2i(3, 11), Vector2i(3, 12), Vector2i(3, 13)]),
		_car("v53", [Vector2i(3, 10), Vector2i(3, 11), Vector2i(3, 12), Vector2i(3, 13)]),
		_car("v26", [Vector2i(4, 10), Vector2i(3, 10), Vector2i(2, 10), Vector2i(1, 10), Vector2i(0, 10)]),
		_car("v54", [Vector2i(5, 10), Vector2i(6, 10), Vector2i(7, 10)]),
		_car("v55", [Vector2i(6, 10), Vector2i(7, 10)]),

		# Row y = 11 (H4 lower lane, 2-lane avenue)
		_car("v34", [Vector2i(1, 11), Vector2i(0, 11)]),
		_car("v56", [Vector2i(2, 11), Vector2i(1, 11), Vector2i(0, 11)]),
		_car("v57", [Vector2i(3, 11), Vector2i(2, 11), Vector2i(1, 11), Vector2i(0, 11)]),
		_car("v58", [Vector2i(4, 11), Vector2i(5, 11), Vector2i(6, 11), Vector2i(7, 11)]),
		_car("v35", [Vector2i(5, 11), Vector2i(6, 11), Vector2i(7, 11)]),
		_car("v59", [Vector2i(6, 11), Vector2i(7, 11)]),

		# Row y = 12 (below H4)
		_car("v27", [Vector2i(1, 12), Vector2i(1, 13)]),
		_car("v28", [Vector2i(3, 12), Vector2i(3, 11), Vector2i(3, 12), Vector2i(3, 13)], -1, "u_turn_left"),
		_car("v29", [Vector2i(4, 12), Vector2i(4, 11), Vector2i(5, 11), Vector2i(6, 11), Vector2i(7, 11)]),
		_car("v30", [Vector2i(6, 12), Vector2i(6, 11), Vector2i(6, 10), Vector2i(5, 10), Vector2i(4, 10), Vector2i(3, 10), Vector2i(2, 10), Vector2i(1, 10), Vector2i(0, 10)])
	]

	return {
		"id": LEVEL_13_ID,
		"name": "Level 13",
		"tutorial_tip": "Clear every vehicle from the road.",
		"size": Vector2i(8, 14),
		"lane_count": 2,
		"ground": "grass",
		"move_limit": LEVEL_13_MOVE_LIMIT,
		"move_target": LEVEL_13_MOVE_LIMIT,
		"star_thresholds": [36, 39, 42],
		"roads": roads,
		"vehicles": vehicles
	}


static func _tile(cell: Vector2i, kind: String, rotation: int) -> Dictionary:
	return {"cell": cell, "kind": kind, "rotation": rotation}


static func _car(id: String, route: Array, u_turn_side := 0, route_sign := "") -> Dictionary:
	var typed_route: Array[Vector2i] = []
	for step in route:
		typed_route.append(step as Vector2i)
	var idx := int(id.trim_prefix("v"))
	var v_type: String = CAR_TYPES[idx % CAR_TYPES.size()]
	var v_color: Color = CAR_PALETTE[idx % CAR_PALETTE.size()]
	return {
		"id": id,
		"type": v_type,
		"color": v_color,
		"route": typed_route,
		"lane_offset": 0.0,
		"u_turn_side": u_turn_side,
		"reference_sign": false,
		"route_sign": route_sign
	}
