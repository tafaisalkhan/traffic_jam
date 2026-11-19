extends SceneTree

const Generator = preload("res://scripts/generation/level_generator.gd")
const Solver = preload("res://scripts/generation/level_solver.gd")

func _init() -> void:
	var generator := Generator.new()
	for seed in range(1, 31):
		for requested_difficulty in range(1, 4):
			var level := generator.generate(seed, requested_difficulty)
			assert(not level.is_empty(), "Generator must return a validated level")
			assert(level.seed == seed, "Generated level retains its reproducible seed")
			assert(level.solution_order.size() == level.vehicles.size(), "Every generated car must have an escape order")
			assert(level.difficulty_rating >= 1 and level.difficulty_rating <= 10, "Difficulty estimate stays bounded")
			assert(Solver.solve(level).size() == level.vehicles.size(), "Solver must confirm each generated level")
	print("Traffic Mash generator tests passed.")
	quit()
