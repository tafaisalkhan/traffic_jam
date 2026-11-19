class_name CampaignValidator
extends RefCounted

const Catalog = preload("res://scripts/generation/campaign_catalog.gd")
const Solver = preload("res://scripts/generation/level_solver.gd")

static func validate_all() -> Array[String]:
	var errors: Array[String] = []
	for level_id in range(1, Catalog.total_levels() + 1):
		var level := Catalog.get_level(level_id)
		var solution := Solver.solve(level)
		if solution.size() != level.vehicles.size(): errors.append("Level %d is unsolvable" % level_id)
		if int(level.id) != level_id: errors.append("Level %d has an incorrect id" % level_id)
		if not level.has("campaign_difficulty") and level_id > Catalog.AUTHORED_LEVELS: errors.append("Level %d lacks phase metadata" % level_id)
	return errors
