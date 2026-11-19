extends SceneTree

const Levels = preload("res://scripts/gameplay/level_data.gd")
const Solver = preload("res://scripts/generation/level_solver.gd")
const Progress = preload("res://scripts/core/level_manager.gd")

func _init() -> void:
	for level_id in range(1, Levels.level_count() + 1):
		var level := Levels.get_level(level_id)
		var solution := Solver.solve(level)
		assert(solution.size() == level.vehicles.size(), "Level %d must be solvable" % level_id)
	var manager := Progress.new()
	manager.persistence_enabled = false
	manager.highest_unlocked = 1
	manager.coins = 0
	manager.stars_by_level = {}
	manager.best_moves = {}
	assert(manager.is_unlocked(1) and not manager.is_unlocked(2), "Only the first tutorial starts unlocked")
	var stars := manager.complete_level(1, 1, [1, 2, 4])
	assert(stars == 3 and manager.is_unlocked(2), "Three-star completion unlocks the next level")
	assert(manager.coins == 45, "Star rewards grant coins once")
	print("Traffic Mash level and progression tests passed.")
	quit()
