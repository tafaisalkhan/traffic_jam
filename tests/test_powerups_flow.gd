extends SceneTree

const RescueScene = preload("res://scenes/gameplay/ambulance_rescue_level.tscn")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var game = RescueScene.instantiate()
	root.add_child(game)
	game.level_manager.persistence_enabled = false
	game.level_manager.privacy_acknowledged = true

	# Start default stage level
	game.load_level(game.build_stage_level(1))
	game.rescue_phase = game.RescuePhase.PLAYING
	game.playing = true

	# 1. Test Freeze Powerup
	var initial_time: float = game.time_remaining
	game.level_manager.powerups["freeze"] = 2
	game._on_powerup_freeze_pressed()
	assert(game.level_manager.get_powerup("freeze") == 1, "Freeze power-up count must decrement by 1")
	assert(game.time_remaining >= initial_time + 19.9, "Freeze must add +20s to time remaining")
	assert(game.freeze_timer > 4.5, "Freeze timer must pause countdown for 5 seconds")

	# Test Freeze timer prevents time decrement
	game._process(1.0)
	assert(game.time_remaining >= initial_time + 19.9, "Time remaining must not decrease while freeze timer is active")

	# 2. Test Hint Powerup
	game.level_manager.powerups["hint"] = 3
	game._on_powerup_hint_pressed()
	assert(game.level_manager.get_powerup("hint") == 2, "Hint power-up count must decrement by 1")
	assert(game.active_hint_vehicle != null, "Hint must select a vehicle to highlight")
	assert(game.active_hint_vehicle.hint_beacon != null, "Hint beacon must be attached to the chosen car")

	# 3. Test Crane (Tow Mode)
	game.level_manager.powerups["remove_car"] = 2
	game._on_powerup_crane_pressed()
	assert(game.tow_mode == true, "Crane button must activate tow mode")
	# Find a civilian vehicle to tow
	var civilian_target: VehicleController = null
	for v in game.vehicles:
		if not game._is_hero(v.vehicle_id):
			civilian_target = v
			break
	assert(civilian_target != null, "Civilian vehicle should exist on board")
	var initial_vehicle_count: int = game.vehicles.size()
	game._execute_tow_truck(civilian_target)
	assert(game.level_manager.get_powerup("remove_car") == 1, "Tow truck must consume 1 remove_car powerup")
	assert(game.tow_mode == false, "Tow mode must deactivate after towing")
	assert(game.vehicles.size() == initial_vehicle_count - 1, "Towed vehicle must be erased from active vehicles list")

	# 4. Test Siren Powerup
	game.level_manager.powerups["siren"] = 2
	game._on_powerup_siren_pressed()
	assert(game.level_manager.get_powerup("siren") == 1, "Siren power-up count must decrement by 1")

	print("City Rescue Puzzle 4 power-ups validation passed successfully!")
	game.queue_free()
	quit(0)
