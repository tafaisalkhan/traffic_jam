class_name PathValidator
extends RefCounted

static func is_valid_route(route: Array, road_map: Dictionary) -> bool:
	if route.size() < 2: return false
	for index in range(route.size() - 1):
		var from: Vector2i = route[index]
		var to: Vector2i = route[index + 1]
		if not road_map.has(from): return false
		var delta := to - from
		if abs(delta.x) + abs(delta.y) != 1: return false
		var direction := _direction(delta)
		var from_tile: Dictionary = road_map[from]
		if not from_tile.connections.has(direction): return false
		if not road_map.has(to):
			if not from_tile.is_exit: return false
			continue
		var to_tile: Dictionary = road_map[to]
		if not to_tile.connections.has(_opposite(direction)): return false
	return true

static func _direction(delta: Vector2i) -> String:
	if delta == Vector2i(0, -1): return "north"
	if delta == Vector2i(1, 0): return "east"
	if delta == Vector2i(0, 1): return "south"
	return "west"

static func _opposite(direction: String) -> String:
	return {"north":"south", "east":"west", "south":"north", "west":"east"}[direction]
