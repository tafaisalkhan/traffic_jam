class_name LevelManager
extends RefCounted

const Saves = preload("res://scripts/systems/save_manager.gd")
const Campaign = preload("res://scripts/generation/campaign_catalog.gd")
var save_manager = Saves.new()
var highest_unlocked := 1
var coins := 0
var stars_by_level: Dictionary = {}
var best_moves: Dictionary = {}
var settings: Dictionary = {}
var powerups: Dictionary = {}
var selected_cosmetic := "classic"
var ads_removed := false
var privacy_acknowledged := false
var daily_completed_date := ""
var daily_streak := 0
var daily_reward_last_date := ""
var daily_reward_streak := 0
var free_chest_last_date := ""
var persistence_enabled := true

func _init() -> void:
	var data := save_manager.load_data()
	highest_unlocked = maxi(1, int(data.highest_unlocked))
	coins = int(data.coins)
	stars_by_level = data.stars_by_level
	best_moves = data.best_moves
	settings = data.settings
	powerups = data.powerups
	selected_cosmetic = data.selected_cosmetic
	ads_removed = bool(data.ads_removed)
	privacy_acknowledged = bool(data.privacy_acknowledged)
	daily_completed_date = str(data.get("daily_completed_date", ""))
	daily_streak = int(data.get("daily_streak", 0))
	daily_reward_last_date = str(data.get("daily_reward_last_date", ""))
	daily_reward_streak = int(data.get("daily_reward_streak", 0))
	free_chest_last_date = str(data.get("free_chest_last_date", ""))

func get_level(level_id: int) -> Dictionary:
	return Campaign.get_level(level_id)

func is_unlocked(level_id: int) -> bool:
	return level_id <= highest_unlocked

func complete_level(level_id: int, moves: int, thresholds: Array) -> int:
	var stars := 1
	if moves <= thresholds[1]: stars = 2
	if moves <= thresholds[0]: stars = 3
	var previous := int(stars_by_level.get(level_id, 0))
	stars_by_level[level_id] = max(previous, stars)
	coins += 20
	var key := str(level_id)
	var previous_best := int(best_moves.get(key, 0))
	if previous_best == 0 or moves < previous_best: best_moves[key] = moves
	highest_unlocked = max(highest_unlocked, level_id + 1)
	_persist()
	return stars

func stars_for(level_id: int) -> int:
	return int(stars_by_level.get(level_id, 0))

func update_settings(next_settings: Dictionary) -> void:
	for key in settings.keys():
		if next_settings.has(key): settings[key] = next_settings[key]
	_persist()

func select_cosmetic(cosmetic: String) -> void:
	if cosmetic in ["classic", "ocean", "sunset"]:
		selected_cosmetic = cosmetic
		_persist()

func confirm_ads_removed() -> void:
	ads_removed = true
	_persist()

func acknowledge_privacy() -> void:
	privacy_acknowledged = true
	_persist()

func add_reward_coins(amount: int) -> void:
	if amount <= 0:
		return
	coins += amount
	_persist()

func spend_coins(amount: int) -> bool:
	if amount <= 0 or coins < amount:
		return false
	coins -= amount
	_persist()
	return true

func cosmetic_tint() -> Color:
	match selected_cosmetic:
		"ocean": return Color("42bdea")
		"sunset": return Color("ff8b50")
		_: return Color.WHITE

func today_date_string() -> String:
	var d := Time.get_date_dict_from_system()
	return "%04d-%02d-%02d" % [int(d.get("year", 2026)), int(d.get("month", 1)), int(d.get("day", 1))]

func yesterday_date_string() -> String:
	var unix := int(Time.get_unix_time_from_system()) - 86400
	var d := Time.get_date_dict_from_unix_time(unix)
	return "%04d-%02d-%02d" % [int(d.get("year", 2026)), int(d.get("month", 1)), int(d.get("day", 1))]

func can_claim_daily_reward() -> bool:
	return daily_reward_last_date != today_date_string()

func effective_daily_reward_day() -> int:
	var today := today_date_string()
	if daily_reward_last_date == today:
		return maxi(1, daily_reward_streak)
	if daily_reward_last_date == yesterday_date_string():
		return maxi(1, daily_reward_streak + 1)
	return 1

func daily_reward_amount_for_day(day: int) -> int:
	return maxi(1, day) * 10

func claim_daily_reward() -> Dictionary:
	if not can_claim_daily_reward():
		return {"claimed": false, "day": effective_daily_reward_day(), "coins": 0}
	var next_day := effective_daily_reward_day()
	var reward := daily_reward_amount_for_day(next_day)
	daily_reward_streak = next_day
	daily_reward_last_date = today_date_string()
	coins += reward
	_persist()
	return {"claimed": true, "day": next_day, "coins": reward}

func is_free_chest_ready() -> bool:
	return free_chest_last_date != today_date_string()

func mark_free_chest_opened() -> void:
	free_chest_last_date = today_date_string()
	_persist()

func add_powerups(hints: int, helis: int) -> void:
	if hints > 0:
		powerups["hint"] = int(powerups.get("hint", 0)) + hints
	if helis > 0:
		powerups["remove_car"] = int(powerups.get("remove_car", 0)) + helis
	_persist()

func daily_seed() -> int:
	var d := Time.get_date_dict_from_system()
	return int(d.get("year", 2026)) * 10000 + int(d.get("month", 1)) * 100 + int(d.get("day", 1))

func is_daily_completed() -> bool:
	return daily_completed_date == today_date_string()

func complete_daily_challenge(moves: int, thresholds: Array) -> Dictionary:
	var stars := 1
	if moves <= thresholds[1]: stars = 2
	if moves <= thresholds[0]: stars = 3
	var today := today_date_string()
	var reward := 0
	if daily_completed_date != today:
		daily_completed_date = today
		daily_streak += 1
		reward = 50
		coins += reward
	else:
		reward = 20
		coins += reward
	_persist()
	return {"stars": stars, "reward": reward, "streak": daily_streak}

func _persist() -> void:
	if not persistence_enabled: return
	save_manager.save_data({
		"version": 1,
		"highest_unlocked": highest_unlocked,
		"coins": coins,
		"stars_by_level": stars_by_level,
		"best_moves": best_moves,
		"settings": settings,
		"powerups": powerups,
		"selected_cosmetic": selected_cosmetic,
		"ads_removed": ads_removed,
		"privacy_acknowledged": privacy_acknowledged,
		"daily_completed_date": daily_completed_date,
		"daily_streak": daily_streak,
		"daily_reward_last_date": daily_reward_last_date,
		"daily_reward_streak": daily_reward_streak,
		"free_chest_last_date": free_chest_last_date
	})
