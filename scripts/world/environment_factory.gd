class_name EnvironmentFactory
extends RefCounted

const Materials = preload("res://scripts/world/world_materials.gd")

const BUILDING_MODELS := [
	"res://models/house/building-type-a.glb",
	"res://models/house/building-type-b.glb",
	"res://models/house/building-type-c.glb",
	"res://models/house/building-type-e.glb",
	"res://models/house/building-type-g.glb",
	"res://models/house/building-type-j.glb",
]
const TREE_MODELS := [
	"res://models/house/tree-large.glb",
	"res://models/house/tree-small.glb",
]
const PLANTER_MODEL := "res://models/house/planter.glb"
const FENCE_MODEL := "res://models/house/fence-low.glb"
const PATH_MODEL := "res://models/house/path-long.glb"

static var _scene_cache: Dictionary = {}
static var _bounds_cache: Dictionary = {}
static var _prewarm_requested := false

static func request_prewarm() -> void:
	if _prewarm_requested:
		return
	_prewarm_requested = true
	var paths: Array[String] = []
	for p in BUILDING_MODELS:
		paths.append(p)
	for p in TREE_MODELS:
		paths.append(p)
	paths.append(PLANTER_MODEL)
	paths.append(FENCE_MODEL)
	paths.append(PATH_MODEL)
	for path in paths:
		if not _scene_cache.has(path) and ResourceLoader.exists(path):
			ResourceLoader.load_threaded_request(path)

static func create(kind: String, variant_seed: int = 0) -> Node3D:
	var root := Node3D.new(); root.name = kind.capitalize()
	match kind:
		"tree": _tree(root, variant_seed)
		"bush": _bush(root)
		"flower_bed": _flowers(root)
		"street_light": _street_light(root)
		"traffic_cone": _cone(root)
		"barrier": _barrier(root)
		"traffic_sign": _sign(root)
		"bench": _bench(root)
		"building": _building(root, variant_seed)
		"fence":
			if not _spawn_glb(root, FENCE_MODEL, 1.35):
				_barrier(root)
		"path":
			if not _spawn_glb(root, PATH_MODEL, 1.45):
				_bush(root)
		"fountain": _fountain(root)
		_: _bush(root)
	return root

static func _load_glb_scene(path: String) -> PackedScene:
	if _scene_cache.has(path):
		return _scene_cache[path] as PackedScene
	if not ResourceLoader.exists(path):
		return null
	var packed: PackedScene = null
	if ResourceLoader.load_threaded_get_status(path) != ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		packed = ResourceLoader.load_threaded_get(path) as PackedScene
	if packed == null:
		packed = load(path) as PackedScene
	if packed != null:
		_scene_cache[path] = packed
	return packed

static func _compute_local_bounds(node: Node3D, parent_xform: Transform3D = Transform3D.IDENTITY) -> AABB:
	var xform := parent_xform * node.transform
	var combined := AABB()
	var has_bounds := false
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh != null:
			var aabb := xform * mi.mesh.get_aabb()
			combined = aabb
			has_bounds = true
	for child in node.get_children():
		if child is Node3D:
			var child_aabb := _compute_local_bounds(child as Node3D, xform)
			if child_aabb.size.length_squared() > 0.0001:
				combined = combined.merge(child_aabb) if has_bounds else child_aabb
				has_bounds = true
	return combined

static func _spawn_glb(root: Node3D, path: String, target_footprint: float) -> bool:
	var packed := _load_glb_scene(path)
	if packed == null:
		return false
	var inst := packed.instantiate() as Node3D
	if inst == null:
		return false
	var bounds: AABB
	if _bounds_cache.has(path):
		bounds = _bounds_cache[path]
	else:
		bounds = _compute_local_bounds(inst)
		_bounds_cache[path] = bounds
	var max_horiz := maxf(bounds.size.x, bounds.size.z)
	if max_horiz > 0.001:
		var s := target_footprint / max_horiz
		inst.scale = Vector3.ONE * s
		var scaled_center := (bounds.position + bounds.size * 0.5) * s
		var scaled_min_y := bounds.position.y * s
		inst.position = Vector3(-scaled_center.x, -scaled_min_y, -scaled_center.z)
	root.add_child(inst)
	return true

static func _tree(root: Node3D, variant_seed: int = 0) -> void:
	var path: String = TREE_MODELS[posmod(variant_seed, TREE_MODELS.size())]
	if _spawn_glb(root, path, 1.15):
		return
	_add_cylinder(root, 0.13, 0.18, 0.85, Vector3(0, 0.45, 0), "trunk")
	for offset in [Vector3(0,1.15,0), Vector3(0.26,1.08,0.10), Vector3(-0.20,1.04,0.14)]: _add_sphere(root, 0.46, offset, "leaf" if offset.x == 0 else "leaf_light")

static func _bush(root: Node3D) -> void:
	for offset in [Vector3(-0.20,0.22,0), Vector3(0.18,0.25,0.10), Vector3(0,0.30,-0.18)]: _add_sphere(root, 0.28, offset, "leaf_light")

static func _flowers(root: Node3D) -> void:
	if _spawn_glb(root, PLANTER_MODEL, 1.10):
		return
	_add_box(root, Vector3(0.92, 0.14, 0.54), Vector3(0, 0.10, 0), "wood")
	for x in [-0.28, 0, 0.28]:
		_add_sphere(root, 0.10, Vector3(x, 0.26, 0), "gold")

static func _street_light(root: Node3D) -> void:
	_add_cylinder(root, 0.045, 0.07, 1.20, Vector3(0,0.62,0), "metal")
	_add_sphere(root, 0.15, Vector3(0,1.32,0), "gold")

static func _cone(root: Node3D) -> void:
	var cone := CylinderMesh.new(); cone.top_radius = 0.03; cone.bottom_radius = 0.16; cone.height = 0.34; _add_mesh(root, cone, Vector3(0,0.19,0), "blocked")

static func _barrier(root: Node3D) -> void:
	_add_box(root, Vector3(1.05,0.16,0.14), Vector3(0,0.37,0), "blocked")
	for x in [-0.38,0.38]: _add_box(root, Vector3(0.12,0.43,0.12), Vector3(x,0.23,0), "metal")

static func _sign(root: Node3D) -> void:
	_add_cylinder(root, 0.04,0.05,0.72,Vector3(0,0.36,0),"metal")
	_add_box(root, Vector3(0.35,0.35,0.06), Vector3(0,0.83,0), "gold")

static func _bench(root: Node3D) -> void:
	_add_box(root, Vector3(0.90,0.13,0.27), Vector3(0,0.34,0), "wood")
	_add_box(root, Vector3(0.90,0.30,0.08), Vector3(0,0.55,0.15), "wood")
	for x in [-0.32,0.32]: _add_box(root, Vector3(0.07,0.32,0.16), Vector3(x,0.18,0), "metal")

static func _building(root: Node3D, variant_seed: int = 0) -> void:
	var path: String = BUILDING_MODELS[posmod(variant_seed, BUILDING_MODELS.size())]
	if _spawn_glb(root, path, 1.75):
		return
	_add_box(root, Vector3(1.35,1.65,1.25), Vector3(0,0.84,0), "curb")
	_add_box(root, Vector3(1.42,0.18,1.32), Vector3(0,1.72,0), "blocked")
	for x in [-0.38,0.38]: _add_box(root, Vector3(0.22,0.32,0.04), Vector3(x,1.02,-0.65), "water")

static func _fountain(root: Node3D) -> void:
	_add_cylinder(root,0.60,0.68,0.18,Vector3(0,0.12,0),"curb")
	_add_cylinder(root,0.47,0.47,0.07,Vector3(0,0.23,0),"water")
	_add_cylinder(root,0.08,0.11,0.43,Vector3(0,0.38,0),"curb")

static func _add_box(root: Node3D, size: Vector3, position: Vector3, material_key: String) -> void:
	var mesh := BoxMesh.new(); mesh.size = size; _add_mesh(root, mesh, position, material_key)

static func _add_cylinder(root: Node3D, top: float, bottom: float, height: float, position: Vector3, material_key: String) -> void:
	var mesh := CylinderMesh.new(); mesh.top_radius = top; mesh.bottom_radius = bottom; mesh.height = height; _add_mesh(root, mesh, position, material_key)

static func _add_sphere(root: Node3D, radius: float, position: Vector3, material_key: String) -> void:
	var mesh := SphereMesh.new(); mesh.radius = radius; mesh.height = radius * 1.7; _add_mesh(root, mesh, position, material_key)

static func _add_mesh(root: Node3D, mesh: Mesh, position: Vector3, material_key: String) -> void:
	var instance := MeshInstance3D.new(); instance.mesh = mesh; instance.position = position; instance.material_override = Materials.get_material(material_key); root.add_child(instance)
