extends SceneTree

const Levels = preload("res://scripts/gameplay/level_data.gd")
const Vehicle = preload("res://scripts/gameplay/vehicle_controller.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var level := Levels.get_level(1)
	var vehicle := Vehicle.new()
	root.add_child(vehicle)
	vehicle.setup(level.vehicles[0], level.size)
	vehicle.drive_out()
	await vehicle.exited
	assert(vehicle.state == Vehicle.State.EXITED, "Vehicle must reach its exit and emit completion")
	print("City Rescue Puzzle vehicle exit animation test passed.")
	quit()
