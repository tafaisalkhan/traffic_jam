extends SceneTree

const Game = preload("res://scripts/core/game.gd")
const Levels = preload("res://scripts/gameplay/level_data.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var game := Game.new()
	root.add_child(game)
	await process_frame
	game.level_manager.persistence_enabled = false
	game.load_level(Levels.get_level(1))
	assert(game.time_limit > 0.0 and game.ui.time_overlay != null, "Every campaign level starts with a visible time limit")
	game._on_time_start()
	game._on_time_boost_requested()
	assert(game.time_options_open and not game.playing, "Opening extra-time choices pauses the countdown")
	game.level_manager.coins = 25
	var before := game.time_remaining
	game._on_time_boost_requested()
	assert(game.playing and not game.time_options_open, "Coin purchase resumes the level")
	assert(game.time_remaining == before + 15.0 and game.level_manager.coins == 0, "Coin purchase adds 15 seconds and deducts 25 coins")
	game.time_remaining = 0.0
	game._on_time_expired()
	assert(game.time_expired and not game.playing, "Time expiry opens recovery choices")
	game.pending_time_reward = true
	game._on_reward_earned(50)
	assert(game.playing and game.time_remaining == 15.0 and game.level_manager.coins == 50, "Verified ad reward adds coins and time")
	print("Traffic Mash timed level flow test passed.")
	quit()
