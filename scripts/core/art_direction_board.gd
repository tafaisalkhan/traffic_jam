extends Node3D

const CELL := RoadTileFactory.TILE_SIZE
const BOARD := Vector2i(5, 7)

func _ready() -> void:
	_create_world()
	_create_city_preview()
	_create_preview_hud()

func _create_world() -> void:
	var environment := WorldEnvironment.new()
	var env := Environment.new(); env.background_mode = Environment.BG_COLOR; env.background_color = DesignTokens.SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_color = Color("e7f5ff"); env.ambient_light_energy = 0.72
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC; environment.environment = env; add_child(environment)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-55, -28, 0); sun.light_energy = 1.15; sun.shadow_enabled = true; sun.directional_shadow_max_distance = 45; add_child(sun)
	var camera := Camera3D.new(); camera.projection = Camera3D.PROJECTION_ORTHOGONAL; camera.size = 13.2; camera.position = Vector3(0, 12.8, 7.7); camera.look_at(Vector3(0, 0, 0)); add_child(camera)

func _create_city_preview() -> void:
	for x in range(BOARD.x):
		for y in range(BOARD.y):
			_add_box(_cell(Vector2i(x, y)), Vector3(CELL - 0.04, 0.13, CELL - 0.04), DesignTokens.GRASS, 0.0)
	# The preview intentionally shows the complete modular kit rather than a
	# gameplay level. Every tile carries connection metadata for Phase 3.
	var roads := [
		[Vector2i(1, 0), "entry", 0], [Vector2i(1, 1), "straight", 0],
		[Vector2i(1, 2), "t", 0], [Vector2i(0, 2), "dead_end", 1],
		[Vector2i(2, 2), "cross", 0], [Vector2i(3, 2), "t", 2],
		[Vector2i(4, 2), "exit", 1], [Vector2i(2, 1), "one_way", 1],
		[Vector2i(2, 3), "two_lane", 1], [Vector2i(2, 4), "corner", 1],
		[Vector2i(3, 4), "bridge", 1], [Vector2i(4, 4), "tunnel", 1],
		[Vector2i(1, 4), "blocked", 0], [Vector2i(1, 5), "straight", 0],
		[Vector2i(1, 6), "exit", 0]
	]
	for definition in roads:
		var tile := RoadTileFactory.create(definition[1], definition[2])
		tile.position = _cell(definition[0]); add_child(tile)
	var decorations := [
		[Vector2i(0,0),"tree"], [Vector2i(4,0),"building"], [Vector2i(0,1),"bush"],
		[Vector2i(4,1),"street_light"], [Vector2i(0,3),"fountain"], [Vector2i(4,3),"bench"],
		[Vector2i(0,4),"flower_bed"], [Vector2i(0,5),"traffic_sign"], [Vector2i(3,5),"traffic_cone"],
		[Vector2i(4,5),"barrier"], [Vector2i(0,6),"tree"], [Vector2i(4,6),"tree"]
	]
	for definition in decorations:
		var decoration := EnvironmentFactory.create(definition[1])
		decoration.position = _cell(definition[0]); add_child(decoration)
	# Vehicle showroom: each production silhouette remains readable from the
	# intended portrait camera, including its high-contrast roof direction arrow.
	var showroom := [
		[Vector2i(1,0),"compact_sedan",Color("ef5350"),0.0], [Vector2i(1,1),"hatchback",Color("ab69e8"),0.0],
		[Vector2i(1,2),"suv",Color("62d976"),PI * 0.5], [Vector2i(0,2),"taxi",Color("ffc52c"),PI * 0.5],
		[Vector2i(2,1),"sports_car",Color("f47742"),PI * 0.5], [Vector2i(2,2),"minivan",Color("39b8eb"),0.0],
		[Vector2i(3,2),"delivery_van",Color("21b8a6"),PI * 0.5], [Vector2i(4,2),"school_bus",Color("f4b52c"),PI * 0.5],
		[Vector2i(2,3),"delivery_truck",Color("9667d9"),PI * 0.5], [Vector2i(2,4),"ambulance",Color("f2f4f7"),PI * 0.0],
		[Vector2i(3,4),"police_car",Color("315b9c"),PI * 0.5], [Vector2i(1,5),"fire_truck",Color("e94e56"),0.0]
	]
	for definition in showroom:
		var vehicle := VehicleFactory.create_vehicle(definition[1], definition[2])
		vehicle.position = _cell(definition[0]) + Vector3(0, 0.19, 0)
		vehicle.rotation.y = definition[3]
		add_child(vehicle)

func _add_road(cell: Vector2i, dimensions: Vector3) -> void:
	var pos := _cell(cell)
	_add_box(pos + Vector3(0, 0.10, 0), dimensions, DesignTokens.ASPHALT, 0.88)
	# Raised, pale curb edges give the board a premium toy-city silhouette.
	var horizontal := dimensions.x > dimensions.z
	var edge := 0.73 if horizontal else 0.73
	if horizontal:
		_add_box(pos + Vector3(0, 0.17, edge), Vector3(dimensions.x, 0.12, 0.13), DesignTokens.CURB, 0.75)
		_add_box(pos + Vector3(0, 0.17, -edge), Vector3(dimensions.x, 0.12, 0.13), DesignTokens.CURB, 0.75)
	else:
		_add_box(pos + Vector3(edge, 0.17, 0), Vector3(0.13, 0.12, dimensions.z), DesignTokens.CURB, 0.75)
		_add_box(pos + Vector3(-edge, 0.17, 0), Vector3(0.13, 0.12, dimensions.z), DesignTokens.CURB, 0.75)

func _add_tree(pos: Vector3) -> void:
	var trunk := CylinderMesh.new(); trunk.top_radius = 0.11; trunk.bottom_radius = 0.16; trunk.height = 0.78
	_add_mesh(trunk, pos + Vector3(0, 0.42, 0), Color("895c3a"), 0.9)
	var crown := SphereMesh.new(); crown.radius = 0.48; crown.height = 0.85
	_add_mesh(crown, pos + Vector3(0, 1.02, 0), Color("2d9b51"), 0.92)
	_add_mesh(crown, pos + Vector3(0.22, 1.0, 0.1), Color("4fbd59"), 0.92)

func _add_lamp(pos: Vector3) -> void:
	var pole := CylinderMesh.new(); pole.top_radius = 0.045; pole.bottom_radius = 0.07; pole.height = 1.05
	_add_mesh(pole, pos + Vector3(0, 0.56, 0), Color("263342"), 0.55)
	var glow := SphereMesh.new(); glow.radius = 0.14; glow.height = 0.25
	_add_mesh(glow, pos + Vector3(0, 1.15, 0), Color("ffd866"), 0.2)

func _add_fountain(pos: Vector3) -> void:
	var base := CylinderMesh.new(); base.top_radius = 0.52; base.bottom_radius = 0.62; base.height = 0.18
	_add_mesh(base, pos + Vector3(0, 0.14, 0), DesignTokens.CURB, 0.72)
	var water := CylinderMesh.new(); water.top_radius = 0.42; water.bottom_radius = 0.42; water.height = 0.07
	_add_mesh(water, pos + Vector3(0, 0.25, 0), Color("3dc4ed"), 0.15)

func _add_bench(pos: Vector3) -> void:
	_add_box(pos + Vector3(0, 0.32, 0), Vector3(0.85, 0.12, 0.28), Color("b97944"), 0.75)
	_add_box(pos + Vector3(0, 0.54, 0.16), Vector3(0.85, 0.30, 0.08), Color("b97944"), 0.75)

func _add_box(pos: Vector3, dimensions: Vector3, color: Color, roughness: float) -> void:
	var mesh := BoxMesh.new(); mesh.size = dimensions; _add_mesh(mesh, pos, color, roughness)

func _add_mesh(mesh: Mesh, pos: Vector3, color: Color, roughness: float) -> void:
	var instance := MeshInstance3D.new(); instance.mesh = mesh; instance.position = pos
	var material := StandardMaterial3D.new(); material.albedo_color = color; material.roughness = roughness; instance.material_override = material; add_child(instance)

func _cell(cell: Vector2i) -> Vector3:
	return Vector3((cell.x - (BOARD.x - 1) * 0.5) * CELL, 0, (cell.y - (BOARD.y - 1) * 0.5) * CELL)

func _create_preview_hud() -> void:
	var layer := CanvasLayer.new(); add_child(layer)
	var top := Panel.new(); top.position = Vector2(130, 30); top.size = Vector2(460, 138)
	var style := StyleBoxFlat.new(); style.bg_color = DesignTokens.PANEL; style.border_color = DesignTokens.PANEL_HIGHLIGHT; style.set_border_width_all(3); style.corner_radius_top_left = 24; style.corner_radius_top_right = 24; style.corner_radius_bottom_left = 24; style.corner_radius_bottom_right = 24; style.shadow_color = Color("07111dcc"); style.shadow_size = 10; style.shadow_offset = Vector2(0, 6)
	top.add_theme_stylebox_override("panel", style); layer.add_child(top)
	var label := Label.new(); label.text = "CITY RESCUE PUZZLE\nART DIRECTION BOARD"; label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER; label.position = Vector2(150, 46); label.size = Vector2(420, 82); label.add_theme_font_size_override("font_size", 26); label.add_theme_color_override("font_color", Color.WHITE); layer.add_child(label)
	var sub := Label.new(); sub.text = "MINIATURE CITY VISUAL SYSTEM"; sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; sub.position = Vector2(150, 128); sub.size = Vector2(420, 28); sub.add_theme_font_size_override("font_size", 15); sub.add_theme_color_override("font_color", DesignTokens.GOLD); layer.add_child(sub)
