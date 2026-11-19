class_name RoadTileFactory
extends RefCounted

const Materials = preload("res://scripts/world/world_materials.gd")

## Must match LevelData.CELL_SIZE. Keeping this single grid measure eliminates
## grass seams between connected road modules on the playable board.
const TILE_SIZE := 2.6
const ONE_LANE_WIDTH := 1.08
const TWO_LANE_WIDTH := 2.48
const ROAD_WIDTH := TWO_LANE_WIDTH
const CURB_HEIGHT := 0.16

static func create(kind: String, quarter_turns := 0) -> Node3D:
	var root := Node3D.new()
	root.name = "Road_%s" % kind
	root.rotation.y = quarter_turns * PI * 0.5
	root.set_meta("road_kind", kind)
	var connections := get_connections(kind, quarter_turns)
	root.set_meta("connections", connections)
	# Build in the unrotated local tile axes; the root rotation above places it
	# in the requested board direction while metadata stays in world directions.
	_build_connected_road(root, get_connections(kind, 0), _lane_count_for(kind))
	return root

static func create_from_neighbors(connections: Array[String], label := "connected") -> Node3D:
	var root := Node3D.new()
	root.name = "Road_%s" % label
	root.set_meta("road_kind", label)
	root.set_meta("connections", connections)
	_build_connected_road(root, connections, _lane_count_for(label))
	return root

static func _lane_count_for(kind: String) -> int:
	if kind == "one_lane":
		return 1
	if kind == "three_lane":
		return 3
	return 2

static func _build_connected_road(root: Node3D, connections: Array[String], lane_count: int) -> void:
	# A road is a centre square plus arms that exactly reach the tile boundary.
	# This makes adjoining cells read as a single continuous street, rather than
	# individual blocks with wider square junctions.
	var road_width := ONE_LANE_WIDTH if lane_count == 1 else TILE_SIZE if lane_count == 3 else TWO_LANE_WIDTH
	_add_box(root, Vector3(road_width, 0.10, road_width), Vector3(0, 0.10, 0), "asphalt")
	var arm_length := (TILE_SIZE - road_width) * 0.5
	if arm_length > 0.001:
		for direction in connections:
			var arm_position := Vector3.ZERO
			var arm_size := Vector3.ZERO
			match direction:
				"north":
					arm_position = Vector3(0, 0.10, -(road_width + arm_length) * 0.5)
					arm_size = Vector3(road_width, 0.10, arm_length)
				"south":
					arm_position = Vector3(0, 0.10, (road_width + arm_length) * 0.5)
					arm_size = Vector3(road_width, 0.10, arm_length)
				"east":
					arm_position = Vector3((road_width + arm_length) * 0.5, 0.10, 0)
					arm_size = Vector3(arm_length, 0.10, road_width)
				"west":
					arm_position = Vector3(-(road_width + arm_length) * 0.5, 0.10, 0)
					arm_size = Vector3(arm_length, 0.10, road_width)
			_add_box(root, arm_size, arm_position, "asphalt")
	# Keep road markings clean and consistent:
	# - Only draw lane dividers on 2+ lane straight segments (no 1-lane center lines, no scattered junction stubs).
	var has_n := connections.has("north")
	var has_s := connections.has("south")
	var has_e := connections.has("east")
	var has_w := connections.has("west")
	var is_only_ns := has_n and has_s and not has_e and not has_w
	var is_only_ew := has_e and has_w and not has_n and not has_s
	if lane_count >= 2:
		if is_only_ns:
			_add_lane_lines(root, false, TILE_SIZE, 0.0, lane_count, road_width)
		elif is_only_ew:
			_add_lane_lines(root, true, TILE_SIZE, 0.0, lane_count, road_width)

static func _add_lane_lines(root: Node3D, is_horizontal: bool, length: float, axis_offset: float, lane_count: int, road_width: float) -> void:
	var lane_offsets: Array[float] = [0.0]
	if lane_count >= 3:
		var split := road_width / 6.0
		lane_offsets = [-split, split]
	for lane_offset in lane_offsets:
		var line_size := Vector3(length, 0.015, 0.055) if is_horizontal else Vector3(0.055, 0.015, length)
		var line_pos := Vector3(axis_offset, 0.165, lane_offset) if is_horizontal else Vector3(lane_offset, 0.165, axis_offset)
		_add_lane_dashes(root, line_size, line_pos)

static func _add_lane_dashes(root: Node3D, line_size: Vector3, line_position: Vector3) -> void:
	var is_horizontal := line_size.x > line_size.z
	var length := line_size.x if is_horizontal else line_size.z
	if length < 0.18:
		return
	# 0.35 + 0.30 = 0.65 divides TILE_SIZE (2.6) into 4 exact, evenly spaced dashes
	# so dashes never bunch up or double at tile boundaries.
	var period := 0.65
	var dash_length := 0.35
	var count := maxi(1, int(round(length / period)))
	var step := length / float(count)
	var actual_dash := minf(dash_length, step * 0.55)
	for i in range(count):
		var offset := -length * 0.5 + step * (float(i) + 0.5)
		var dash_size := Vector3(actual_dash, line_size.y, line_size.z) if is_horizontal else Vector3(line_size.x, line_size.y, actual_dash)
		var dash_position := line_position + (Vector3(offset, 0, 0) if is_horizontal else Vector3(0, 0, offset))
		_add_box(root, dash_size, dash_position, "marking")

static func get_connections(kind: String, quarter_turns: int) -> Array[String]:
	var base: Array[String] = []
	match kind:
		"corner": base = ["north", "east"]
		"t": base = ["north", "east", "west"]
		"cross": base = ["north", "east", "south", "west"]
		"dead_end": base = ["north"]
		# Entry/exit tiles are traversable stubs: one connector joins the board
		# and the other permits the vehicle to cross its boundary.
		"entry", "exit": base = ["north", "south"]
		_: base = ["north", "south"]
	var directions := ["north", "east", "south", "west"]
	var result: Array[String] = []
	for direction in base:
		var index := directions.find(direction)
		result.append(directions[(index + quarter_turns) % 4])
	return result

static func _straight(root: Node3D, kind: String) -> void:
	# Reference roads look like a single road but retain enough width for a
	# U-turn to return through the adjacent lane.
	var road_width := TILE_SIZE if kind == "three_lane" else 1.72 if kind == "two_lane" else 1.80 if kind == "one_lane" else ROAD_WIDTH
	var curb_x := road_width * 0.5 + 0.07
	_add_box(root, Vector3(road_width, 0.10, TILE_SIZE), Vector3(0, 0.10, 0), "asphalt")
	_add_box(root, Vector3(0.14, CURB_HEIGHT, TILE_SIZE), Vector3(-curb_x, 0.18, 0), "curb")
	_add_box(root, Vector3(0.14, CURB_HEIGHT, TILE_SIZE), Vector3(curb_x, 0.18, 0), "curb")
	if kind != "three_lane" and kind != "one_lane":
		_add_box(root, Vector3(0.055, 0.015, TILE_SIZE), Vector3(0, 0.165, 0), "marking")
	if kind == "three_lane":
		for x in [-0.33, 0.33]:
			_add_box(root, Vector3(0.04, 0.015, TILE_SIZE), Vector3(x, 0.165, 0), "marking")
	if kind == "one_way": _add_arrow(root, Vector3(0, 0.18, -0.14))
	if kind == "blocked": _add_barrier(root)
	if kind == "dead_end": _add_box(root, Vector3(ROAD_WIDTH, 0.40, 0.14), Vector3(0, 0.35, -0.78), "curb")
	if kind == "entry" or kind == "exit": _add_gate(root, kind == "exit")
	if kind == "bridge": _add_bridge_rails(root)
	if kind == "tunnel": _add_tunnel_portal(root)

static func _corner(root: Node3D) -> void:
	# Two merged strips form an L road; raised inner greenery makes the curve legible.
	_add_box(root, Vector3(ROAD_WIDTH, 0.10, ROAD_WIDTH), Vector3(-0.20, 0.10, 0.20), "asphalt")
	_add_box(root, Vector3(ROAD_WIDTH, 0.10, 0.80), Vector3(0, 0.10, -0.48), "asphalt")
	_add_box(root, Vector3(0.80, 0.10, ROAD_WIDTH), Vector3(0.48, 0.10, 0), "asphalt")
	_add_box(root, Vector3(0.14, CURB_HEIGHT, 0.92), Vector3(-0.77, 0.18, -0.34), "curb")
	_add_box(root, Vector3(0.92, CURB_HEIGHT, 0.14), Vector3(0.34, 0.18, 0.77), "curb")
	_add_box(root, Vector3(0.62, 0.12, 0.62), Vector3(-0.48, 0.18, 0.48), "grass")

static func _intersection(root: Node3D, arms: int) -> void:
	# Junctions use the exact same road width as a normal street.  Do not make
	# a full square asphalt tile or raised corner blocks: those looked like
	# separate pieces instead of connected roads.
	_add_box(root, Vector3(TILE_SIZE, 0.10, ROAD_WIDTH), Vector3(0, 0.10, 0), "asphalt")
	_add_box(root, Vector3(TILE_SIZE, 0.015, 0.055), Vector3(0, 0.165, 0), "marking")
	if arms == 3:
		# Base T points north; the tile root rotation turns it as required.
		_add_box(root, Vector3(ROAD_WIDTH, 0.10, TILE_SIZE * 0.5), Vector3(0, 0.10, -TILE_SIZE * 0.25), "asphalt")
		_add_box(root, Vector3(0.055, 0.015, TILE_SIZE * 0.5), Vector3(0, 0.165, -TILE_SIZE * 0.25), "marking")
	else:
		_add_box(root, Vector3(ROAD_WIDTH, 0.10, TILE_SIZE), Vector3(0, 0.10, 0), "asphalt")
		_add_box(root, Vector3(0.055, 0.015, TILE_SIZE), Vector3(0, 0.165, 0), "marking")

static func _add_arrow(root: Node3D, position: Vector3) -> void:
	var head := PrismMesh.new(); head.size = Vector3(0.28, 0.02, 0.35); head.left_to_right = 0.5
	_add_mesh(root, head, position, "marking", Vector3(PI * 0.5, 0, 0))
	_add_box(root, Vector3(0.13, 0.02, 0.35), position + Vector3(0, 0, 0.22), "marking")

static func _add_barrier(root: Node3D) -> void:
	_add_box(root, Vector3(1.10, 0.14, 0.16), Vector3(0, 0.38, 0), "blocked")
	for x in [-0.42, 0.42]: _add_box(root, Vector3(0.10, 0.40, 0.10), Vector3(x, 0.25, 0), "blocked")

static func _add_gate(root: Node3D, is_exit: bool) -> void:
	var colour := "gold" if is_exit else "metal"
	for x in [-0.60, 0.60]: _add_box(root, Vector3(0.09, 0.75, 0.09), Vector3(x, 0.48, -0.65), colour)
	_add_box(root, Vector3(1.26, 0.08, 0.10), Vector3(0, 0.81, -0.65), colour)

static func _add_bridge_rails(root: Node3D) -> void:
	for x in [-0.73, 0.73]: _add_box(root, Vector3(0.08, 0.43, TILE_SIZE), Vector3(x, 0.35, 0), "metal")

static func _add_tunnel_portal(root: Node3D) -> void:
	_add_box(root, Vector3(ROAD_WIDTH, 0.96, 0.17), Vector3(0, 0.54, -0.72), "metal")
	_add_box(root, Vector3(0.16, 0.78, 0.30), Vector3(-0.60, 0.43, -0.62), "metal")
	_add_box(root, Vector3(0.16, 0.78, 0.30), Vector3(0.60, 0.43, -0.62), "metal")

static func _add_box(root: Node3D, size: Vector3, position: Vector3, material_key: String) -> void:
	var mesh := BoxMesh.new(); mesh.size = size
	_add_mesh(root, mesh, position, material_key)

static func _add_mesh(root: Node3D, mesh: Mesh, position: Vector3, material_key: String, rotation := Vector3.ZERO) -> void:
	var instance := MeshInstance3D.new(); instance.mesh = mesh; instance.position = position; instance.rotation = rotation; instance.material_override = Materials.get_material(material_key); root.add_child(instance)
