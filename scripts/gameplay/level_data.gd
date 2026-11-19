class_name LevelData
extends RefCounted

## A four-unit tile gives each of the three lanes enough clearance for buses
## and trucks, not only the small car models used in early levels.
const CELL_SIZE := 2.6

static func tutorial_one() -> Dictionary:
	return get_level(1)

static func level_count() -> int:
	return 10

static func reference_level_16() -> Dictionary:
	var roads: Array = []
	var crossings := [Vector2i(1, 2), Vector2i(5, 2), Vector2i(5, 5), Vector2i(3, 5), Vector2i(1, 8), Vector2i(3, 8), Vector2i(5, 8)]
	for x in [1, 5]:
		for y in range(0, 5):
			var cell := Vector2i(x, y)
			roads.append(_tile(cell, "cross" if cell in crossings else "exit" if y == 0 else "one_lane", 0))
	for y in range(5, 6):
		var cell := Vector2i(5, y)
		roads.append(_tile(cell, "cross" if cell in crossings else "one_lane"))
	for y in range(5, 8):
		var cell := Vector2i(3, y)
		roads.append(_tile(cell, "cross" if cell in crossings else "one_lane"))
	for x in [1, 5]:
		# Continue through the final board row so the lower roads reach a real
		# edge exit instead of stopping visibly inside the pavement.
		for y in range(8, 14):
			var cell := Vector2i(x, y)
			roads.append(_tile(cell, "cross" if cell in crossings else "exit" if y == 13 else "one_lane", 2 if y == 13 else 0))
	for y in range(8, 14):
		var cell := Vector2i(3, y)
		roads.append(_tile(cell, "cross" if cell in crossings else "exit" if y == 13 else "one_lane", 2 if y == 13 else 0))
	for y in [2, 5, 8]:
		for x in range(7):
			var cell := Vector2i(x, y)
			if cell in crossings: continue
			# Horizontal roads must rotate the normal north/south lane by 90°.
			roads.append(_tile(cell, "exit" if x == 0 or x == 6 else "two_lane", 3 if x == 0 else 1))
	var vehicles := [
		_vehicle("taxi_top_left", "taxi", "ffc52c", [Vector2i(1, 1), Vector2i(1, 2), Vector2i(2, 2), Vector2i(3, 2), Vector2i(4, 2), Vector2i(5, 2), Vector2i(6, 2), Vector2i(7, 2)]),
		_vehicle("car_top_middle", "sports_car", "f47b42", [Vector2i(3, 2), Vector2i(2, 2), Vector2i(1, 2), Vector2i(0, 2), Vector2i(-1, 2)]),
		_vehicle("taxi_top_right", "taxi", "ffc52c", [Vector2i(5, 3), Vector2i(5, 2), Vector2i(4, 2), Vector2i(3, 2), Vector2i(2, 2), Vector2i(1, 2), Vector2i(0, 2), Vector2i(-1, 2)]),
		# This right-side car clears to its nearby exit first, opening the row for
		# the car travelling across the main junction.
		_vehicle("taxi_right", "taxi", "ffca28", [Vector2i(6, 5), Vector2i(7, 5)]),
		_vehicle("car_mid_left", "compact_sedan", "ffca28", [Vector2i(2, 5), Vector2i(3, 5), Vector2i(4, 5), Vector2i(5, 5), Vector2i(6, 5), Vector2i(7, 5)]),
		_vehicle("car_mid_center", "suv", "ffc52c", [Vector2i(3, 6), Vector2i(3, 5), Vector2i(4, 5), Vector2i(5, 5), Vector2i(6, 5), Vector2i(7, 5)]),
		_vehicle("car_row_eight", "sports_car", "f47b42", [Vector2i(4, 8), Vector2i(3, 8), Vector2i(2, 8), Vector2i(1, 8), Vector2i(0, 8), Vector2i(-1, 8)]),
		_vehicle("taxi_lower_left", "taxi", "ffc52c", [Vector2i(1, 10), Vector2i(1, 9), Vector2i(1, 8), Vector2i(2, 8), Vector2i(3, 8), Vector2i(4, 8), Vector2i(5, 8), Vector2i(6, 8), Vector2i(7, 8)]),
		_vehicle("taxi_lower_right", "taxi", "ffc52c", [Vector2i(5, 10), Vector2i(5, 9), Vector2i(5, 8), Vector2i(4, 8), Vector2i(3, 8), Vector2i(2, 8), Vector2i(1, 8), Vector2i(0, 8), Vector2i(-1, 8)]),
		_vehicle("u_turn_left", "minivan", "ffca28", [Vector2i(1, 12), Vector2i(1, 11), Vector2i(1, 10), Vector2i(1, 9), Vector2i(1, 8), Vector2i(2, 8), Vector2i(3, 8), Vector2i(3, 9), Vector2i(3, 10), Vector2i(3, 11), Vector2i(3, 12), Vector2i(3, 13)], 0.0, -1, "u_turn_left"),
		_vehicle("lower_left_turn", "minivan", "ffca28", [Vector2i(5, 12), Vector2i(5, 11), Vector2i(5, 10), Vector2i(5, 9), Vector2i(5, 8), Vector2i(4, 8), Vector2i(3, 8), Vector2i(2, 8), Vector2i(1, 8), Vector2i(0, 8), Vector2i(-1, 8)])
	]
	for vehicle in vehicles:
		vehicle.color = Color("ffc52c")
		vehicle.reference_sign = true
	return {"id": 13, "name": "Level 13", "tutorial_tip": "Clear every vehicle from the road.", "size": Vector2i(7, 14), "lane_count": 2, "ground": "grass", "move_limit": 36, "move_target": 36, "star_thresholds": [36, 39, 42], "roads": roads, "vehicles": vehicles}

static func get_level(level_id: int) -> Dictionary:
	var vehicles_by_level := [
		[_vehicle("blue", "suv", "42a5f5", _east())],
		[_vehicle("blue", "suv", "42a5f5", _east()), _vehicle("yellow", "taxi", "ffca28", _north())],
		[_vehicle("blue", "suv", "42a5f5", _east()), _vehicle("yellow", "taxi", "ffca28", _north()), _vehicle("red", "compact_sedan", "ef5350", _right_turn())],
		[_vehicle("purple", "minivan", "a66ce5", _west()), _vehicle("cyan", "hatchback", "28b9dc", _u_turn())],
		[_vehicle("orange", "sports_car", "f47b42", _east()), _vehicle("green", "delivery_van", "52bf68", _left_north()), _vehicle("gold", "school_bus", "f3b928", _north())],
		[_vehicle("violet", "minivan", "9968df", _west()), _vehicle("yellow", "taxi", "ffc52c", _north()), _vehicle("red", "compact_sedan", "ef5350", _right_turn())],
		[_vehicle("blue", "suv", "41a8ef", _east()), _vehicle("pink", "hatchback", "ed6ab4", _left_turn()), _vehicle("cyan", "delivery_truck", "32bad8", _south())],
		[_vehicle("purple", "minivan", "9968df", _west()), _vehicle("fire", "fire_truck", "e94e56", _right_turn()), _vehicle("green", "delivery_van", "55c96b", _left_turn())],
		[_vehicle("blue", "suv", "41a8ef", _east()), _vehicle("yellow", "taxi", "ffc52c", _north()), _vehicle("orange", "sports_car", "f47b42", _left_north()), _vehicle("fire", "fire_truck", "e94e56", _right_turn())],
		[_vehicle("blue", "police_car", "315b9c", _east()), _vehicle("fire", "fire_truck", "e94e56", _right_turn()), _vehicle("green", "delivery_van", "55c96b", _left_north()), _vehicle("cyan", "ambulance", "f5f7fb", _south())]
	]
	var names := ["First Exit", "Clear the Lane", "First Crossing", "Two Way Trouble", "Longer Vehicles", "Crossing Patrol", "Watch the Arrow", "Busy Junction", "Four Car Flow", "Tutorial Finale"]
	var tips := ["Tap the blue SUV.", "Move the blue SUV before the taxi.", "Clear the crossing in order.", "A clear exit makes space.", "Long vehicles need clear routes.", "Read every roof arrow.", "Use the crossing one car at a time.", "Free the road from left to right.", "Plan before moving.", "Everything you learned comes together."]
	var index := clampi(level_id, 1, level_count()) - 1
	var vehicles := _big_u_turn_vehicles(index)
	return {
		"id": index + 1,
		"name": names[index],
		"tutorial_tip": tips[index],
		"size": Vector2i(7, 14),
		"move_target": vehicles.size(),
		"star_thresholds": [vehicles.size(), vehicles.size() + 2, vehicles.size() + 5],
		"roads": _big_u_turn_roads(),
		"vehicles": vehicles
	}

static func _big_u_turn_vehicles(variant: int) -> Array:
	var types := ["suv", "taxi", "compact_sedan", "minivan", "sports_car", "delivery_van", "school_bus", "hatchback", "delivery_truck", "crane_truck"]
	var colours := ["42a5f5", "ffca28", "ef5350", "9968df", "f47b42", "55c96b", "f3b928", "29bcd9", "f5f7fb", "e94e56"]
	var routes := _video_routes()
	var vehicles: Array = []
	for index in range(routes.size()):
		vehicles.append(_vehicle("route_%02d" % index, types[(index + variant) % types.size()], colours[index % colours.size()], routes[index], 0.0))
	return vehicles

static func _big_u_turn_roads() -> Array:
	var roads: Array = []
	var lanes := [1, 3, 5]
	var crossings := [2, 5, 8, 11]
	for x in lanes:
		for y in range(14):
			var kind := "cross" if y in crossings else "exit" if y == 0 or y == 13 else "one_lane"
			roads.append(_tile(Vector2i(x, y), kind, 2 if y == 13 else 0))
	for y in crossings:
		for x in range(7):
			if x in lanes: continue
		# These cells form an east/west road, so every middle segment also needs
		# the east/west rotation rather than the default vertical orientation.
			roads.append(_tile(Vector2i(x, y), "exit" if x == 0 or x == 6 else "one_lane", 3 if x == 0 else 1))
	return roads

static func _video_routes() -> Array:
	return [
		_to_top(1, 1), _to_top(3, 1), _to_top(5, 1),
		_turn_north(1, 4, 2, 1), _turn_north(3, 4, 2, -1), _turn_north(5, 4, 2, -1),
		_u_turn_north(1, 7, 5), _turn_north(3, 7, 5, 1), _turn_north(5, 7, 5, -1),
		_turn_north(1, 10, 8, 1), _u_turn_north(3, 10, 8), _turn_north(5, 10, 8, -1),
		_u_turn_north(1, 12, 11), _turn_north(3, 12, 11, 1), _turn_north(5, 12, 11, -1),
		_to_right(0, 2), _to_right(2, 5), _to_left(6, 8), _to_left(4, 11), _to_right(0, 11)
	]

static func _to_top(x: int, y: int) -> Array:
	var route: Array = []
	for next_y in range(y, -2, -1): route.append(Vector2i(x, next_y))
	return route

static func _turn_north(x: int, start_y: int, turn_y: int, direction: int) -> Array:
	var route: Array = []
	for y in range(start_y, turn_y - 1, -1): route.append(Vector2i(x, y))
	var end_x := 7 if direction > 0 else -1
	for next_x in range(x + direction, end_x + direction, direction): route.append(Vector2i(next_x, turn_y))
	return route

static func _u_turn_north(x: int, start_y: int, turn_y: int) -> Array:
	var route: Array = []
	for y in range(start_y, turn_y - 1, -1): route.append(Vector2i(x, y))
	for y in range(turn_y + 1, 15): route.append(Vector2i(x, y))
	return route

static func _to_right(start_x: int, y: int) -> Array:
	var route: Array = []
	for x in range(start_x, 8): route.append(Vector2i(x, y))
	return route

static func _to_left(start_x: int, y: int) -> Array:
	var route: Array = []
	for x in range(start_x, -2, -1): route.append(Vector2i(x, y))
	return route

static func _huge_routes() -> Array:
	var routes: Array = []
	for block in range(5):
		var base_y := block * 9
		routes.append_array([_lower_u_turn(1, base_y), _upper_u_turn(1, base_y), _lower_straight(3, base_y), _upper_straight(3, base_y), _lower_turn(5, 1, base_y), _lower_turn(7, -1, base_y), _upper_turn(9, -1, base_y), _upper_turn(5, 1, base_y), _lower_u_turn(9, base_y), _upper_u_turn(7, base_y)])
	return routes

static func _lower_u_turn(x: int, base_y := 0) -> Array:
	var route: Array = []
	for y in range(7, 1, -1): route.append(Vector2i(x, base_y + y))
	for y in range(3, 10): route.append(Vector2i(x, base_y + y))
	return route

static func _upper_u_turn(x: int, base_y := 0) -> Array:
	var route: Array = []
	for y in range(1, 7): route.append(Vector2i(x, base_y + y))
	for y in range(5, -2, -1): route.append(Vector2i(x, base_y + y))
	return route

# Two straight cars share this road in separate lanes and have a full visible
# run to their respective exits instead of starting immediately beside one.
static func _lower_straight(x: int, base_y := 0) -> Array: return [Vector2i(x, base_y + 5), Vector2i(x, base_y + 6), Vector2i(x, base_y + 7), Vector2i(x, base_y + 8), Vector2i(x, base_y + 9)]
static func _upper_straight(x: int, base_y := 0) -> Array: return [Vector2i(x, base_y + 3), Vector2i(x, base_y + 2), Vector2i(x, base_y + 1), Vector2i(x, base_y), Vector2i(x, base_y - 1)]

static func _lower_turn(x: int, horizontal_direction: int, base_y := 0) -> Array:
	var route: Array = [Vector2i(x, base_y + 7), Vector2i(x, base_y + 6)]
	var end_x := 11 if horizontal_direction > 0 else -1
	for next_x in range(x + horizontal_direction, end_x + horizontal_direction, horizontal_direction): route.append(Vector2i(next_x, base_y + 6))
	return route

static func _upper_turn(x: int, horizontal_direction: int, base_y := 0) -> Array:
	var route: Array = [Vector2i(x, base_y + 1), Vector2i(x, base_y + 2)]
	var end_x := 11 if horizontal_direction > 0 else -1
	for next_x in range(x + horizontal_direction, end_x + horizontal_direction, horizontal_direction): route.append(Vector2i(next_x, base_y + 2))
	return route

static func _vehicle(id: String, type: String, color: String, route: Array, lane_offset := 0.0, u_turn_side := 0, route_sign := "") -> Dictionary:
	return {"id": id, "type": type, "color": Color(color), "route": route, "lane_offset": lane_offset, "u_turn_side": u_turn_side, "route_sign": route_sign}

static func _east() -> Array: return [Vector2i(1, 2), Vector2i(2, 2), Vector2i(3, 2), Vector2i(4, 2), Vector2i(5, 2)]
static func _west() -> Array: return [Vector2i(3, 2), Vector2i(2, 2), Vector2i(1, 2), Vector2i(0, 2), Vector2i(-1, 2)]
static func _north() -> Array: return [Vector2i(3, 5), Vector2i(3, 4), Vector2i(3, 3), Vector2i(3, 2), Vector2i(3, 1), Vector2i(3, 0), Vector2i(3, -1)]
static func _south() -> Array: return [Vector2i(3, 0), Vector2i(3, 1), Vector2i(3, 2), Vector2i(3, 3), Vector2i(3, 4), Vector2i(3, 5), Vector2i(3, 6), Vector2i(3, 7)]
static func _left_north() -> Array: return [Vector2i(1, 5), Vector2i(1, 4), Vector2i(1, 3), Vector2i(1, 2), Vector2i(1, 1), Vector2i(1, 0), Vector2i(1, -1)]
static func _right_turn() -> Array: return [Vector2i(1, 4), Vector2i(1, 3), Vector2i(1, 2), Vector2i(2, 2), Vector2i(3, 2), Vector2i(4, 2), Vector2i(5, 2)]
static func _left_turn() -> Array: return [Vector2i(3, 5), Vector2i(3, 4), Vector2i(3, 3), Vector2i(3, 2), Vector2i(2, 2), Vector2i(1, 2), Vector2i(0, 2), Vector2i(-1, 2)]
static func _u_turn() -> Array: return [Vector2i(1, 4), Vector2i(1, 3), Vector2i(1, 2), Vector2i(1, 3), Vector2i(1, 4), Vector2i(1, 5), Vector2i(1, 6), Vector2i(1, 7)]

static func _tile(cell: Vector2i, kind: String, rotation := 0) -> Dictionary:
	return {"cell": cell, "kind": kind, "rotation": rotation}

static func cell_to_world(cell: Vector2i, board_size: Vector2i) -> Vector3:
	return Vector3((cell.x - (board_size.x - 1) * 0.5) * CELL_SIZE, 0.18, (cell.y - (board_size.y - 1) * 0.5) * CELL_SIZE)
