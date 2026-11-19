extends SceneTree

const Saves = preload("res://scripts/systems/save_manager.gd")
const Progress = preload("res://scripts/core/level_manager.gd")

func _init() -> void:
	var saves := Saves.new()
	var clean := saves.sanitize({"highest_unlocked": -4, "coins": -2, "stars_by_level": {"1": 99, "bad": -1}, "settings": {"music": false}, "powerups": {"hint": -3}, "selected_cosmetic": "unknown"})
	assert(clean.highest_unlocked == 1 and clean.coins == 0, "Negative save values must be repaired")
	assert(clean.stars_by_level["1"] == 3 and clean.stars_by_level["bad"] == 0, "Star values must be clamped")
	assert(clean.settings.music == false and clean.settings.sound == true, "Missing settings use defaults")
	assert(clean.powerups.hint == 0 and clean.selected_cosmetic == "classic", "Inventory and cosmetics are validated")
	assert(clean.ads_removed == false and saves.sanitize({"ads_removed": true}).ads_removed, "Ad removal entitlement is sanitized")
	assert(clean.privacy_acknowledged == false and saves.sanitize({"privacy_acknowledged": true}).privacy_acknowledged, "Privacy acknowledgement is sanitized")
	var manager := Progress.new()
	manager.persistence_enabled = false
	manager.update_settings({"music": false, "sound": true, "vibration": false})
	manager.select_cosmetic("ocean")
	assert(manager.settings.music == false and manager.selected_cosmetic == "ocean", "Profile updates apply in memory")
	manager.coins = 20
	assert(not manager.spend_coins(25) and manager.coins == 20, "Extra time cannot spend unavailable coins")
	manager.add_reward_coins(50)
	assert(manager.spend_coins(25) and manager.coins == 45, "Rewarded coins can buy extra time")
	print("City Rescue Puzzle save validation tests passed.")
	quit()
