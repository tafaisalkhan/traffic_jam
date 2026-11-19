extends SceneTree

const RescueScene = preload("res://scenes/gameplay/ambulance_rescue_level.tscn")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var game = RescueScene.instantiate()
	root.add_child(game)
	game.level_manager.persistence_enabled = false
	game.level_manager.privacy_acknowledged = false
	assert(game.ui.current_screen == "splash" and game.level.is_empty(), "Startup opens splash without loading a level")
	await create_timer(2.5).timeout
	assert(game.ui.current_screen == "menu" and game.level.is_empty(), "Splash finishes on the main menu")
	game.ui.play_requested.emit()
	assert(game.level.is_empty() and game.ui.privacy_overlay != null, "First Play opens privacy policy before loading")
	game.ui.privacy_dismissed.emit()
	game.ui.close_privacy_popup()
	assert(game.level.is_empty() and not game.level_manager.privacy_acknowledged, "Not Now keeps the game at the menu")
	game.ui.play_requested.emit()
	game.ui.privacy_acknowledged.emit()
	assert(game.level_manager.privacy_acknowledged, "Continue saves privacy acknowledgement")
	await create_timer(5.0).timeout
	assert(game.ui.time_overlay != null, "Rescue stage shows its time limit before play")
	assert(not game.playing, "Countdown waits for Start Level")
	game._on_time_start()
	assert(game.playing, "Rescue countdown starts after confirmation")
	game._on_time_boost_requested()
	game.level_manager.coins = 25
	var before: float = game.time_remaining
	game._on_time_boost_requested()
	assert(game.time_remaining == before + 15.0 and game.level_manager.coins == 0, "Rescue timer accepts a coin boost")
	game.time_remaining = 0.01
	game._process(1.0)
	assert(game.time_expired and not game.playing and game.ui.time_overlay != null, "Rescue timeout opens recovery choices")
	print("Traffic Mash rescue timer flow test passed.")
	quit()
