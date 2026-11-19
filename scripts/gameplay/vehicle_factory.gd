class_name VehicleFactory
extends RefCounted

# Presentation is independent of gameplay, so imported GLBs can replace these
# original runtime meshes without changing routing, input, or save code.
const TYPES := ["compact_sedan", "hatchback", "suv", "taxi", "sports_car", "minivan", "delivery_van", "school_bus", "delivery_truck", "ambulance", "police_car", "fire_truck", "crane_truck"]
const DIRECTION_ARROW_TEXTURE = preload("res://assets/textures/ui/direction_arrow.png")
const LEFT_TURN_ARROW_TEXTURE = preload("res://assets/textures/ui/direction_left_turn.png")
const RIGHT_TURN_ARROW_TEXTURE = preload("res://assets/textures/ui/direction_right_turn.png")
const UTURN_ARROW_TEXTURE = preload("res://assets/textures/ui/direction_uturn.png")

# The current vehicle art lives in models/cars.  Gameplay still uses the
# lightweight specs below for lane spacing and sign placement.
const CAR_MODELS := {
	"compact_sedan": "res://models/cars/sedan.glb",
	"hatchback": "res://models/cars/hatchback-sports.glb",
	"suv": "res://models/cars/suv.glb",
	"taxi": "res://models/cars/taxi.glb",
	"sports_car": "res://models/cars/sedan-sports.glb",
	"minivan": "res://models/cars/van.glb",
	"delivery_van": "res://models/cars/delivery.glb",
	"school_bus": "res://models/cars/truck.glb",
	"delivery_truck": "res://models/cars/truck-flat.glb",
	"ambulance": "res://models/cars/ambulance.glb",
	"police_car": "res://models/cars/police.glb",
	"fire_truck": "res://models/cars/firetruck.glb",
	"crane_truck": "res://models/cars/tractor-shovel.glb"
}

static func create_vehicle(vehicle_type: String, body_color: Color, route: Array = [], u_turn_side := 0, reference_sign := false, route_sign := "") -> Node3D:
	var type := _normalize_type(vehicle_type)
	var spec := _spec(type)
	var root := Node3D.new()
	root.name = type.capitalize().replace("_", "")
	root.set_meta("vehicle_type", type)
	root.set_meta("bounds", Vector3(spec.width, spec.height, spec.length))
	# Use the user's imported car models.  The procedural build remains only as
	# a safe fallback while Godot is importing a newly copied GLB.
	if not _add_imported_car(root, type):
		_add_body(root, spec, body_color)
		_add_cabin(root, spec)
		_add_wheels(root, spec)
		_add_lights(root, spec)
		_add_mirrors(root, spec)
		_add_type_details(root, type, spec, body_color)
	_add_direction_arrow(root, spec, route, u_turn_side, reference_sign, route_sign)
	_add_exhaust_smoke(root, spec)
	return root

static var _scene_cache: Dictionary = {}
static var _prewarm_requested := false

static func request_prewarm() -> void:
	if _prewarm_requested:
		return
	_prewarm_requested = true
	for path in CAR_MODELS.values():
		if not _scene_cache.has(path) and ResourceLoader.exists(path):
			ResourceLoader.load_threaded_request(path)

static func _load_car_scene(path: String) -> PackedScene:
	if _scene_cache.has(path):
		return _scene_cache[path] as PackedScene
	if path.is_empty():
		return null
	var scene: PackedScene = null
	if ResourceLoader.load_threaded_get_status(path) != ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		scene = ResourceLoader.load_threaded_get(path) as PackedScene
	if scene == null:
		scene = load(path) as PackedScene
	if scene != null:
		_scene_cache[path] = scene
	return scene

static func _add_imported_car(root: Node3D, type: String) -> bool:
	var path := str(CAR_MODELS.get(type, ""))
	var scene := _load_car_scene(path)
	if scene == null:
		return false
	var model := scene.instantiate() as Node3D
	if model == null:
		return false
	model.name = "ImportedCar"
	# Imported Kenney GLB models have their front at +Z, while vehicle routes,
	# _angle_for(), exhaust smoke, and roof arrows all use -Z as forward.
	model.rotation.y = PI
	model.scale = Vector3(0.82, 0.82, 0.82)
	root.add_child(model)
	return true

static func get_bounds(vehicle_type: String) -> Vector3:
	var spec := _spec(_normalize_type(vehicle_type))
	return Vector3(spec.width, spec.height, spec.length)

static func _normalize_type(vehicle_type: String) -> String:
	var aliases := {"sedan":"compact_sedan", "van":"delivery_van", "truck":"delivery_truck", "police":"police_car", "bus":"school_bus"}
	return aliases.get(vehicle_type, vehicle_type) if not TYPES.has(vehicle_type) else vehicle_type

static func _spec(type: String) -> Dictionary:
	var specs := {
		"compact_sedan": {"width":1.10,"length":1.66,"height":0.42,"cabin_w":0.84,"cabin_l":0.82,"cabin_h":0.34,"cabin_z":-0.06,"wheel":0.15},
		"hatchback": {"width":1.08,"length":1.46,"height":0.43,"cabin_w":0.82,"cabin_l":0.76,"cabin_h":0.37,"cabin_z":0.03,"wheel":0.15},
		"suv": {"width":1.20,"length":1.76,"height":0.51,"cabin_w":0.94,"cabin_l":0.91,"cabin_h":0.42,"cabin_z":-0.03,"wheel":0.17},
		"taxi": {"width":1.15,"length":1.70,"height":0.46,"cabin_w":0.88,"cabin_l":0.84,"cabin_h":0.35,"cabin_z":-0.04,"wheel":0.16},
		"sports_car": {"width":1.14,"length":1.72,"height":0.32,"cabin_w":0.79,"cabin_l":0.71,"cabin_h":0.25,"cabin_z":-0.06,"wheel":0.16},
		"minivan": {"width":1.18,"length":1.86,"height":0.55,"cabin_w":0.92,"cabin_l":1.12,"cabin_h":0.48,"cabin_z":0.02,"wheel":0.16},
		"delivery_van": {"width":1.20,"length":1.94,"height":0.62,"cabin_w":0.92,"cabin_l":0.69,"cabin_h":0.43,"cabin_z":-0.37,"wheel":0.17},
		"school_bus": {"width":1.20,"length":2.38,"height":0.62,"cabin_w":0.97,"cabin_l":1.70,"cabin_h":0.52,"cabin_z":0.06,"wheel":0.17},
		"delivery_truck": {"width":1.24,"length":2.24,"height":0.62,"cabin_w":0.95,"cabin_l":0.63,"cabin_h":0.45,"cabin_z":-0.55,"wheel":0.18},
		"ambulance": {"width":1.22,"length":2.05,"height":0.65,"cabin_w":0.96,"cabin_l":1.23,"cabin_h":0.54,"cabin_z":0.05,"wheel":0.17},
		"police_car": {"width":1.13,"length":1.76,"height":0.45,"cabin_w":0.86,"cabin_l":0.86,"cabin_h":0.34,"cabin_z":-0.05,"wheel":0.16},
		"fire_truck": {"width":1.28,"length":2.32,"height":0.65,"cabin_w":1.00,"cabin_l":1.58,"cabin_h":0.56,"cabin_z":0.10,"wheel":0.18},
		"crane_truck": {"width":1.30,"length":2.55,"height":0.70,"cabin_w":0.95,"cabin_l":0.70,"cabin_h":0.48,"cabin_z":-0.62,"wheel":0.19}
	}
	return specs.get(type, specs["compact_sedan"])

static func _add_body(root: Node3D, spec: Dictionary, colour: Color) -> void:
	_add_box(root, Vector3(spec.width, spec.height, spec.length), Vector3(0, spec.height * 0.5 + 0.18, 0), _material(colour, 0.25))
	_add_box(root, Vector3(spec.width * 0.93, 0.12, spec.length * 0.92), Vector3(0, 0.23, 0), _material(colour.darkened(0.16), 0.38))

static func _add_cabin(root: Node3D, spec: Dictionary) -> void:
	var glass := _material(Color("bdefff"), 0.20)
	glass.metallic = 0.08
	_add_box(root, Vector3(spec.cabin_w, spec.cabin_h, spec.cabin_l), Vector3(0, spec.height + spec.cabin_h * 0.5 + 0.16, spec.cabin_z), glass)
	_add_box(root, Vector3(spec.cabin_w * 0.80, 0.035, spec.cabin_l * 0.72), Vector3(0, spec.height + spec.cabin_h + 0.19, spec.cabin_z), _material(Color("31516d"), 0.35))

static func _add_wheels(root: Node3D, spec: Dictionary) -> void:
	var tire_material := _material(Color("202b36"), 0.82)
	var hub_material := _material(Color("c8d1db"), 0.34)
	for x in [-spec.width * 0.52, spec.width * 0.52]:
		for z in [-spec.length * 0.30, spec.length * 0.30]:
			var wheel := CylinderMesh.new(); wheel.top_radius = spec.wheel; wheel.bottom_radius = spec.wheel; wheel.height = 0.105
			var wheel_instance := _add_mesh(root, wheel, Vector3(x, 0.27, z), tire_material, Vector3(0, 0, PI * 0.5))
			wheel_instance.set_meta("vehicle_wheel", true)
			var hub := CylinderMesh.new(); hub.top_radius = spec.wheel * 0.47; hub.bottom_radius = spec.wheel * 0.47; hub.height = 0.112
			_add_mesh(root, hub, Vector3(x * 1.01, 0.27, z), hub_material, Vector3(0, 0, PI * 0.5))

static func _add_lights(root: Node3D, spec: Dictionary) -> void:
	var front_z: float = -float(spec.length) * 0.47
	var rear_z: float = float(spec.length) * 0.47
	for x in [-spec.width * 0.28, spec.width * 0.28]:
		_add_box(root, Vector3(0.18, 0.10, 0.035), Vector3(x, spec.height * 0.48 + 0.22, front_z), _material(Color("fff2a6"), 0.18))
		_add_box(root, Vector3(0.18, 0.09, 0.035), Vector3(x, spec.height * 0.48 + 0.22, rear_z), _material(Color("ed535c"), 0.24))

static func _add_mirrors(root: Node3D, spec: Dictionary) -> void:
	for x in [-1.0, 1.0]:
		_add_box(root, Vector3(0.12, 0.07, 0.16), Vector3(x * (spec.width * 0.54), spec.height + 0.35, spec.cabin_z - spec.cabin_l * 0.28), _material(Color("31495d"), 0.42))

static func _add_type_details(root: Node3D, type: String, spec: Dictionary, colour: Color) -> void:
	match type:
		"taxi":
			_add_box(root, Vector3(0.34,0.10,0.23), Vector3(0,spec.height + spec.cabin_h + 0.26,spec.cabin_z), _material(DesignTokens.GOLD,0.3))
			for z in [-0.38,0.38]: _add_box(root, Vector3(spec.width * 0.97,0.06,0.22), Vector3(0,spec.height * 0.62 + 0.22,z), _material(Color("29323b"),0.52))
		"sports_car":
			_add_box(root, Vector3(spec.width * 0.90,0.07,0.17), Vector3(0,0.58,spec.length * 0.43), _material(colour.darkened(0.24),0.28))
		"minivan", "delivery_van":
			_add_box(root, Vector3(0.04,0.30,spec.length * 0.36), Vector3(-spec.width * 0.51,spec.height + 0.04,0.25), _material(Color("d9f2fb"),0.3))
		"school_bus":
			for z in [-0.55,-0.15,0.25,0.60]: _add_box(root, Vector3(0.04,0.25,0.26), Vector3(-spec.width * 0.51,spec.height + 0.12,z), _material(Color("32485b"),0.38))
		"delivery_truck":
			_add_box(root, Vector3(spec.width * 0.95,spec.height * 0.92,0.95), Vector3(0,spec.height + 0.12,0.42), _material(colour.lightened(0.08),0.36))
		"ambulance":
			_add_box(root, Vector3(0.08,0.12,0.43), Vector3(0,spec.height + spec.cabin_h + 0.25,0.15), _material(DesignTokens.DANGER,0.25))
			_add_cross(root, Vector3(0,spec.height + 0.20,0.52))
		"police_car":
			_add_box(root, Vector3(0.42,0.09,0.12), Vector3(0,spec.height + spec.cabin_h + 0.23,spec.cabin_z), _material(Color("f05b62"),0.16))
			_add_box(root, Vector3(0.21,0.10,0.13), Vector3(-0.11,spec.height + spec.cabin_h + 0.24,spec.cabin_z), _material(Color("37a7f1"),0.16))
		"fire_truck":
			_add_box(root, Vector3(0.15,0.13,1.34), Vector3(0,spec.height + spec.cabin_h + 0.23,0.12), _material(Color("e8e3d6"),0.45))
			for z in [-0.42,0.20,0.72]: _add_box(root, Vector3(0.50,0.07,0.07), Vector3(0,spec.height + spec.cabin_h + 0.32,z), _material(Color("f7c5a3"),0.34))
		"crane_truck":
			_add_box(root, Vector3(0.18,0.14,1.45), Vector3(0,spec.height + 0.76,0.25), _material(Color("ffc52c"),0.28))
			_add_box(root, Vector3(0.10,0.82,0.10), Vector3(0,spec.height + 0.53,0.72), _material(Color("f0b629"),0.30))
			_add_box(root, Vector3(0.08,0.32,0.08), Vector3(0,spec.height + 0.27,-0.43), _material(Color("384a5b"),0.50))

static func _add_cross(root: Node3D, position: Vector3) -> void:
	var red := _material(DesignTokens.DANGER,0.25)
	_add_box(root, Vector3(0.30,0.03,0.10),position,red)
	_add_box(root, Vector3(0.10,0.03,0.30),position,red)

static func _add_direction_arrow(root: Node3D, spec: Dictionary, route: Array, u_turn_side: int, reference_sign: bool, route_sign: String) -> void:
	if reference_sign:
		_add_reference_sign(root, spec, route, u_turn_side, route_sign)
		return
	# Each route gets its own blue marker: straight, left, right, or full U-turn.
	var indicator := Node3D.new()
	root.add_child(indicator)
	var marker := MeshInstance3D.new()
	var quad := QuadMesh.new(); quad.size = Vector2(0.78, 0.78)
	marker.mesh = quad
	marker.position = Vector3(0, float(spec.height) + float(spec.cabin_h) + 0.52, 0)
	marker.rotation.x = -PI * 0.5
	if _route_turn_type(route) == "u_turn" and u_turn_side > 0: marker.scale.x = -1.0
	var material := StandardMaterial3D.new()
	match _route_turn_type(route):
		"left": material.albedo_texture = LEFT_TURN_ARROW_TEXTURE
		"right": material.albedo_texture = RIGHT_TURN_ARROW_TEXTURE
		"u_turn": material.albedo_texture = UTURN_ARROW_TEXTURE
		_: material.albedo_texture = DIRECTION_ARROW_TEXTURE
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	marker.material_override = material
	indicator.add_child(marker)

static func _add_reference_sign(root: Node3D, spec: Dictionary, route: Array, u_turn_side: int, route_sign: String) -> void:
	var sign_root := Node3D.new()
	# Imported car bodies are taller than the old procedural body, so lift the
	# sign above the roof and make it readable from the fixed overhead camera.
	sign_root.position = Vector3(0, 1.62, 0)
	root.add_child(sign_root)
	var plate := MeshInstance3D.new()
	var quad := QuadMesh.new(); quad.size = Vector2(0.96, 0.96)
	plate.mesh = quad
	plate.rotation.x = -PI * 0.5
	var plate_material := StandardMaterial3D.new()
	plate_material.albedo_color = Color("fffdf3")
	plate_material.roughness = 0.38
	plate_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	plate.material_override = plate_material
	sign_root.add_child(plate)
	var arrow := Label3D.new()
	arrow.text = _reference_arrow(route, u_turn_side, route_sign)
	arrow.font_size = 96
	arrow.pixel_size = 0.009
	arrow.modulate = Color("121212")
	arrow.outline_size = 1
	arrow.outline_modulate = Color("121212")
	arrow.position.y = 0.012
	arrow.rotation.x = -PI * 0.5
	sign_root.add_child(arrow)

static func _reference_arrow(route: Array, u_turn_side: int, route_sign: String) -> String:
	if route_sign == "u_turn_left": return "↶"
	if route_sign == "u_turn_right": return "↷"
	match _route_turn_type(route):
		"left": return "↰"
		"right": return "↱"
		"u_turn": return "↶" if u_turn_side <= 0 else "↷"
		_: return "↑"

static func _add_exhaust_smoke(root: Node3D, spec: Dictionary) -> void:
	var smoke := GPUParticles3D.new()
	smoke.name = "ExhaustSmoke"
	smoke.position = Vector3(0, 0.34, float(spec.length) * 0.49)
	smoke.amount = 18
	smoke.lifetime = 0.75
	smoke.explosiveness = 0.0
	smoke.emitting = false
	smoke.local_coords = false
	smoke.visibility_aabb = AABB(Vector3(-1.5, -0.5, -1.5), Vector3(3.0, 3.0, 3.0))
	var puff := SphereMesh.new(); puff.radius = 0.075; puff.height = 0.15
	smoke.draw_pass_1 = puff
	var material := ParticleProcessMaterial.new()
	material.direction = Vector3(0, 0.75, 0.28)
	material.spread = 26.0
	material.initial_velocity_min = 0.32
	material.initial_velocity_max = 0.58
	material.gravity = Vector3(0, 0.42, 0)
	material.damping_min = 0.15
	material.damping_max = 0.30
	material.scale_min = 0.45
	material.scale_max = 1.25
	material.color = Color("d7e1e4b8")
	smoke.process_material = material
	root.add_child(smoke)

static func _route_turn_type(route: Array) -> String:
	if route.size() < 3: return "straight"
	var initial_direction: Vector2i = route[1] - route[0]
	for index in range(2, route.size()):
		var next_direction: Vector2i = route[index] - route[index - 1]
		if next_direction == initial_direction: continue
		var angle := wrapf(atan2(-float(next_direction.x), -float(next_direction.y)) - atan2(-float(initial_direction.x), -float(initial_direction.y)), -PI, PI)
		if absf(angle) > PI * 0.75: return "u_turn"
		return "right" if angle < 0.0 else "left"
	return "straight"

static func _add_box(root: Node3D, size: Vector3, position: Vector3, material: Material) -> void:
	var mesh := BoxMesh.new(); mesh.size = size; _add_mesh(root, mesh, position, material)

static func _add_mesh(root: Node3D, mesh: Mesh, position: Vector3, material: Material, rotation := Vector3.ZERO) -> MeshInstance3D:
	var instance := MeshInstance3D.new(); instance.mesh = mesh; instance.position = position; instance.rotation = rotation; instance.material_override = material; root.add_child(instance); return instance

static func _material(colour: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new(); material.albedo_color = colour; material.roughness = roughness; return material
