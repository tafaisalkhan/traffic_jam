class_name WorldMaterials
extends RefCounted

static var _cache: Dictionary = {}

static func get_material(key: String) -> StandardMaterial3D:
	if _cache.has(key): return _cache[key]
	var material := StandardMaterial3D.new()
	match key:
		"asphalt":
			material.albedo_color = DesignTokens.ASPHALT
			material.roughness = 1.0
			material.metallic_specular = 0.0
		"curb":
			material.albedo_color = DesignTokens.CURB
			material.roughness = 0.72
		"pavement":
			material.albedo_color = Color("cbc5b9")
			material.roughness = 0.94
			material.metallic_specular = 0.0
		"marking":
			material.albedo_color = Color("f4f6f8")
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		"grass":
			material.albedo_color = DesignTokens.GRASS
			material.roughness = 0.92
			material.metallic_specular = 0.0
		"trunk": material.albedo_color = Color("875837"); material.roughness = 0.95
		"leaf": material.albedo_color = Color("2b9950"); material.roughness = 0.94
		"leaf_light": material.albedo_color = Color("55c45d"); material.roughness = 0.94
		"metal": material.albedo_color = Color("263342"); material.metallic = 0.35; material.roughness = 0.42
		"wood": material.albedo_color = Color("b97845"); material.roughness = 0.78
		"water": material.albedo_color = Color("39c6ee"); material.metallic = 0.18; material.roughness = 0.12
		"gold": material.albedo_color = DesignTokens.GOLD; material.metallic = 0.18; material.roughness = 0.25
		"blocked": material.albedo_color = DesignTokens.DANGER; material.roughness = 0.55
		_: material.albedo_color = Color.WHITE; material.roughness = 0.8
	_cache[key] = material
	return material
