class_name CampaignCatalog
extends RefCounted

const AUTHORED_LEVELS := 10
const TOTAL_LEVELS := 300
const Generator = preload("res://scripts/generation/level_generator.gd")

static func total_levels() -> int:
	return TOTAL_LEVELS

static func get_level(level_id: int) -> Dictionary:
	var id := clampi(level_id, 1, TOTAL_LEVELS)
	if id == 16: return LevelData.reference_level_16()
	if id <= AUTHORED_LEVELS: return LevelData.get_level(id)
	var generator := Generator.new()
	var level := generator.generate(_seed_for(id), _generator_complexity(id))
	level.id = id
	level.name = "City Rescue Puzzle %03d" % id
	level.campaign_difficulty = _difficulty_phase(id)
	level.theme = _theme_for(id)
	return level

static func _seed_for(level_id: int) -> int:
	return 104729 + level_id * 7919

static func _generator_complexity(level_id: int) -> int:
	if level_id <= 60: return 2
	if level_id <= 150: return 3
	return 4

static func _difficulty_phase(level_id: int) -> String:
	if level_id <= 10: return "tutorial"
	if level_id <= 30: return "turns_and_blocking"
	if level_id <= 60: return "intersections"
	if level_id <= 100: return "larger_grids"
	if level_id <= 150: return "one_way_planning"
	if level_id <= 200: return "complex_intersections"
	if level_id <= 250: return "bridges_and_tunnels"
	return "expert_combinations"

static func _theme_for(level_id: int) -> String:
	var themes := ["garden_city", "sunset_district", "harbor_blue", "night_market"]
	return themes[(level_id / 25) % themes.size()]
