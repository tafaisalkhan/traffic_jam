class_name OccupancyManager
extends RefCounted

var occupied: Dictionary = {}
var reservations: Dictionary = {}

func add_vehicle(id: String, cell: Vector2i, lane_offset := 0.0) -> void:
	occupied[_lane_key(cell, lane_offset)] = id

func can_reserve(id: String, route: Array, lane_offset := 0.0) -> bool:
	for index in range(1, route.size()):
		var cell: Vector2i = route[index]
		var key := _lane_key(cell, lane_offset)
		if occupied.has(key) and occupied[key] != id:
			return false
		if reservations.has(key) and reservations[key] != id:
			return false
	return true

func reserve_route(id: String, route: Array, lane_offset := 0.0) -> void:
	for index in range(1, route.size()):
		reservations[_lane_key(route[index], lane_offset)] = id


func release_vehicle(id: String, route: Array, lane_offset := 0.0) -> void:
	for cell in occupied.keys():
		if occupied[cell] == id:
			occupied.erase(cell)
	for cell in reservations.keys():
		if reservations[cell] == id:
			reservations.erase(cell)

func _lane_key(cell: Vector2i, lane_offset: float) -> String:
	# A crossing is shared physical space.  Cars in different painted lanes may
	# travel alongside each other, but no two cars may reserve the same tile.
	return "%d:%d" % [cell.x, cell.y]
