extends SceneTree

const Catalog = preload("res://scripts/generation/campaign_catalog.gd")
const Validator = preload("res://scripts/generation/campaign_validator.gd")

func _init() -> void:
	assert(Catalog.total_levels() == 300, "Campaign must expose 300 levels")
	var errors := Validator.validate_all()
	assert(errors.is_empty(), "Campaign validation failed")
	assert(Catalog.get_level(11).seed == 104729 + 11 * 7919, "Generated campaign seeds must be reproducible")
	assert(Catalog.get_level(300).campaign_difficulty == "expert_combinations", "Final campaign phase must be expert")
	print("City Rescue Puzzle 300-level campaign validation passed.")
	quit()
