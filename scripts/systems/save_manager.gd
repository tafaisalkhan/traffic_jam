class_name SaveManager
extends RefCounted

const SAVE_PATH := "user://traffic_mash_save.json"
const VERSION := 1

func default_data() -> Dictionary:
	return {
		"version": VERSION,
		"highest_unlocked": 1,
		"coins": 0,
		"stars_by_level": {},
		"best_moves": {},
		"settings": {"music": true, "sound": true, "vibration": true, "graphics_quality": "mobile", "daily_notifications": true},
		"powerups": {"undo": 3, "hint": 3, "shuffle": 2, "remove_car": 2, "siren": 2, "freeze": 2},
		"selected_cosmetic": "classic",
		"ads_removed": false,
		"privacy_acknowledged": false,
		"daily_completed_date": "",
		"daily_streak": 0,
		"daily_reward_last_date": "",
		"daily_reward_streak": 0,
		"free_chest_last_date": ""
	}

func load_data() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH): return default_data()
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null: return default_data()
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary: return _recover_malformed()
	return sanitize(parsed)

func save_data(data: Dictionary) -> bool:
	var clean := sanitize(data)
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify(clean, "\t"))
	return true

func sanitize(raw: Dictionary) -> Dictionary:
	var clean := default_data()
	clean.highest_unlocked = maxi(1, int(raw.get("highest_unlocked", 1)))
	clean.coins = maxi(0, int(raw.get("coins", 0)))
	clean.stars_by_level = _valid_number_map(raw.get("stars_by_level", {}), 0, 3)
	clean.best_moves = _valid_number_map(raw.get("best_moves", {}), 0, 9999)
	if raw.get("settings") is Dictionary:
		for key in clean.settings.keys():
			if raw.settings.has(key): clean.settings[key] = raw.settings[key]
	if raw.get("powerups") is Dictionary:
		for key in clean.powerups.keys(): clean.powerups[key] = maxi(0, int(raw.powerups.get(key, clean.powerups[key])))
	var cosmetic := str(raw.get("selected_cosmetic", "classic"))
	clean.selected_cosmetic = cosmetic if cosmetic in ["classic", "ocean", "sunset"] else "classic"
	clean.ads_removed = raw.get("ads_removed", false) == true
	clean.privacy_acknowledged = raw.get("privacy_acknowledged", false) == true
	clean.daily_completed_date = str(raw.get("daily_completed_date", ""))
	clean.daily_streak = maxi(0, int(raw.get("daily_streak", 0)))
	clean.daily_reward_last_date = str(raw.get("daily_reward_last_date", ""))
	clean.daily_reward_streak = maxi(0, int(raw.get("daily_reward_streak", 0)))
	clean.free_chest_last_date = str(raw.get("free_chest_last_date", ""))
	return clean

func _valid_number_map(value, minimum: int, maximum: int) -> Dictionary:
	var result := {}
	if not value is Dictionary: return result
	for key in value.keys(): result[str(key)] = clampi(int(value[key]), minimum, maximum)
	return result

func _recover_malformed() -> Dictionary:
	# Deliberately do not overwrite the original malformed file. A subsequent
	# legitimate save safely replaces it after the player continues.
	return default_data()
