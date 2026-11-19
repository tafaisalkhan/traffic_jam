class_name LevelGenerator
extends RefCounted

const Solver = preload("res://scripts/generation/level_solver.gd")

const VEHICLE_TYPES := ["compact_sedan", "hatchback", "suv", "taxi", "sports_car", "minivan", "delivery_van", "school_bus", "delivery_truck", "ambulance", "police_car", "fire_truck", "crane_truck"]
const COLOURS := ["ef5350", "42a5f5", "ffca28", "62c76b", "a66ce5", "f47b42", "29bcd9"]

func generate(seed: int, requested_difficulty := 1) -> Dictionary:
	# The video-style board contains many simultaneous cars. Searching every
	# possible order is exponential and was freezing Play before a level opened.
	var candidate := _build_candidate(seed, requested_difficulty)
	var order: Array[String] = []
	for vehicle in candidate.vehicles: order.append(vehicle.id)
	candidate.solution_order = order
	candidate.difficulty_rating = clampi(requested_difficulty + 4, 1, 10)
	return candidate

func _build_candidate(seed: int, requested_difficulty: int) -> Dictionary:
	var rng := RandomNumberGenerator.new(); rng.seed = seed
	var routes := _video_routes()
	var vehicles: Array = []
	for index in range(routes.size()):
		vehicles.append(_vehicle("g_%02d" % index, VEHICLE_TYPES[rng.randi_range(0, VEHICLE_TYPES.size() - 1)], COLOURS[rng.randi_range(0, COLOURS.size() - 1)], routes[index], 0.0))
	return {
		"id": 1000 + seed,
		"seed": seed,
		"name": "Generated Route %d" % abs(seed),
		"theme": "garden_city",
		"size": Vector2i(7, 14),
		"move_target": vehicles.size(),
		"star_thresholds": [vehicles.size(), vehicles.size() + 1, vehicles.size() + 3],
		"roads": _road_network(),
		"vehicles": vehicles,
		"obstacles": [],
		"difficulty_requested": requested_difficulty
	}

func _road_network() -> Array:
	var roads: Array = []
	var lanes := [1, 3, 5]
	var crossings := [2, 5, 8, 11]
	for x in lanes:
		for y in range(14):
			var kind := "cross" if y in crossings else "exit" if y == 0 or y == 13 else "one_lane"
			roads.append({"cell": Vector2i(x, y), "kind": kind, "rotation": 2 if y == 13 else 0})
	for y in crossings:
		for x in range(7):
			if x in lanes: continue
			roads.append({"cell": Vector2i(x, y), "kind": "exit" if x == 0 or x == 6 else "one_lane", "rotation": 3 if x == 0 else 1})
	return roads

func _video_routes() -> Array:
	return [
		_to_top(1, 1), _to_top(3, 1), _to_top(5, 1),
		_turn_north(1, 4, 2, 1), _turn_north(3, 4, 2, -1), _turn_north(5, 4, 2, -1),
		_u_turn_north(1, 7, 5), _turn_north(3, 7, 5, 1), _turn_north(5, 7, 5, -1),
		_turn_north(1, 10, 8, 1), _u_turn_north(3, 10, 8), _turn_north(5, 10, 8, -1),
		_u_turn_north(1, 12, 11), _turn_north(3, 12, 11, 1), _turn_north(5, 12, 11, -1),
		_to_right(0, 2), _to_right(2, 5), _to_left(6, 8), _to_left(4, 11), _to_right(0, 11)
	]

func _to_top(x: int, y: int) -> Array:
	var route: Array = []
	for next_y in range(y, -2, -1): route.append(Vector2i(x, next_y))
	return route

func _turn_north(x: int, start_y: int, turn_y: int, direction: int) -> Array:
	var route: Array = []
	for y in range(start_y, turn_y - 1, -1): route.append(Vector2i(x, y))
	var end_x := 7 if direction > 0 else -1
	for next_x in range(x + direction, end_x + direction, direction): route.append(Vector2i(next_x, turn_y))
	return route

func _u_turn_north(x: int, start_y: int, turn_y: int) -> Array:
	var route: Array = []
	for y in range(start_y, turn_y - 1, -1): route.append(Vector2i(x, y))
	for y in range(turn_y + 1, 15): route.append(Vector2i(x, y))
	return route

func _to_right(start_x: int, y: int) -> Array:
	var route: Array = []
	for x in range(start_x, 8): route.append(Vector2i(x, y))
	return route

func _to_left(start_x: int, y: int) -> Array:
	var route: Array = []
	for x in range(start_x, -2, -1): route.append(Vector2i(x, y))
	return route

func _u_turn_route(x: int, from_bottom: bool) -> Array:
	var route: Array = []
	if from_bottom:
		for y in range(7, 1, -1): route.append(Vector2i(x, y))
		for y in range(3, 10): route.append(Vector2i(x, y))
	else:
		for y in range(1, 7): route.append(Vector2i(x, y))
		for y in range(5, -2, -1): route.append(Vector2i(x, y))
	return route

func _huge_routes() -> Array:
	var routes: Array = []
	for block in range(5):
		var base_y := block * 9
		routes.append_array([_lower_u_turn(1, base_y), _upper_u_turn(1, base_y), _lower_straight(3, base_y), _upper_straight(3, base_y), _lower_turn(5, 1, base_y), _lower_turn(7, -1, base_y), _upper_turn(9, -1, base_y), _upper_turn(5, 1, base_y), _lower_u_turn(9, base_y), _upper_u_turn(7, base_y)])
	return routes

func _lower_u_turn(x: int, base_y := 0) -> Array:
	var route: Array = []
	for y in range(7, 1, -1): route.append(Vector2i(x, base_y + y))
	for y in range(3, 10): route.append(Vector2i(x, base_y + y))
	return route

func _upper_u_turn(x: int, base_y := 0) -> Array:
	var route: Array = []
	for y in range(1, 7): route.append(Vector2i(x, base_y + y))
	for y in range(5, -2, -1): route.append(Vector2i(x, base_y + y))
	return route

func _lower_straight(x: int, base_y := 0) -> Array: return [Vector2i(x, base_y + 5), Vector2i(x, base_y + 6), Vector2i(x, base_y + 7), Vector2i(x, base_y + 8), Vector2i(x, base_y + 9)]
func _upper_straight(x: int, base_y := 0) -> Array: return [Vector2i(x, base_y + 3), Vector2i(x, base_y + 2), Vector2i(x, base_y + 1), Vector2i(x, base_y), Vector2i(x, base_y - 1)]

func _lower_turn(x: int, horizontal_direction: int, base_y := 0) -> Array:
	var route: Array = [Vector2i(x, base_y + 7), Vector2i(x, base_y + 6)]
	var end_x := 11 if horizontal_direction > 0 else -1
	for next_x in range(x + horizontal_direction, end_x + horizontal_direction, horizontal_direction): route.append(Vector2i(next_x, base_y + 6))
	return route

func _upper_turn(x: int, horizontal_direction: int, base_y := 0) -> Array:
	var route: Array = [Vector2i(x, base_y + 1), Vector2i(x, base_y + 2)]
	var end_x := 11 if horizontal_direction > 0 else -1
	for next_x in range(x + horizontal_direction, end_x + horizontal_direction, horizontal_direction): route.append(Vector2i(next_x, base_y + 2))
	return route

func _route(key: String, row: int) -> Array:
	match key:
		"east": return _horizontal(Vector2i(1, row), 1)
		"north": return _vertical(Vector2i(3, 5), -1)
		"south": return _vertical(Vector2i(3, 0), 1)
		"left_north": return _vertical(Vector2i(1, 5), -1)
		"right_turn":
			var route: Array = []
			for y in range(6, row - 1, -1): route.append(Vector2i(1, y))
			for x in range(2, 6): route.append(Vector2i(x, row))
			return route
		"left_turn":
			var route: Array = []
			for y in range(6, row - 1, -1): route.append(Vector2i(3, y))
			for x in range(2, -2, -1): route.append(Vector2i(x, row))
			return route
		"u_turn":
			var route: Array = []
			for y in range(5, row - 1, -1): route.append(Vector2i(1, y))
			for y in range(row + 1, 8): route.append(Vector2i(1, y))
			return route
	return []

func _horizontal(start: Vector2i, direction: int) -> Array:
	var route: Array = []
	var end_x := 5 if direction > 0 else -1
	for x in range(start.x, end_x + direction, direction): route.append(Vector2i(x, start.y))
	return route

func _vertical(start: Vector2i, direction: int) -> Array:
	var route: Array = []
	var end_y := 7 if direction > 0 else -1
	for y in range(start.y, end_y + direction, direction): route.append(Vector2i(start.x, y))
	return route

func _vehicle(id: String, type: String, colour: String, route: Array, lane_offset := 0.0) -> Dictionary:
	return {"id": id, "type": type, "color": Color(colour), "route": route, "lane_offset": lane_offset}
