class_name LevelSolver
extends RefCounted

const Roads = preload("res://scripts/world/road_tile_factory.gd")
const Routes = preload("res://scripts/gameplay/path_validator.gd")

static func solve(level: Dictionary) -> Array[String]:
	var road_map: Dictionary = {}
	for road in level.roads:
		road_map[road.cell] = {"connections": Roads.get_connections(road.kind, road.rotation), "is_exit": road.kind == "exit"}
	var remaining: Dictionary = {}
	var occupied: Dictionary = {}
	for vehicle in level.vehicles:
		if not Routes.is_valid_route(vehicle.route, road_map): return []
		remaining[vehicle.id] = vehicle
		occupied[vehicle.route[0]] = vehicle.id
	return _search(remaining, occupied, [])

static func estimate_difficulty(level: Dictionary, solution: Array[String]) -> int:
	var route_cells: int = 0
	for vehicle in level.vehicles: route_cells += vehicle.route.size()
	var density: int = level.vehicles.size() * 2
	return clampi(solution.size() + density + route_cells / 8, 1, 10)

static func _search(remaining: Dictionary, occupied: Dictionary, order: Array[String]) -> Array[String]:
	if remaining.is_empty(): return order
	for id in remaining.keys():
		var vehicle: Dictionary = remaining[id]
		if not _route_clear(id, vehicle.route, occupied): continue
		var next_remaining := remaining.duplicate()
		next_remaining.erase(id)
		var next_occupied := occupied.duplicate()
		for cell in next_occupied.keys():
			if next_occupied[cell] == id: next_occupied.erase(cell)
		var next_order: Array[String] = order.duplicate()
		next_order.append(id)
		var result := _search(next_remaining, next_occupied, next_order)
		if not result.is_empty(): return result
	return []

static func _route_clear(id: String, route: Array, occupied: Dictionary) -> bool:
	for index in range(1, route.size()):
		var cell: Vector2i = route[index]
		if occupied.has(cell) and occupied[cell] != id: return false
	return true
