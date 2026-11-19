extends SceneTree

const Quality = preload("res://scripts/systems/quality_manager.gd")
const Audio = preload("res://scripts/systems/audio_manager.gd")
const Monetization = preload("res://scripts/systems/monetization_manager.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var quality := Quality.new()
	quality.apply("battery")
	assert(quality.target_fps() == 30, "Battery profile targets 30 FPS")
	quality.apply("mobile")
	assert(quality.target_fps() == 60, "Mobile profile targets 60 FPS")
	var audio := Audio.new()
	root.add_child(audio)
	await process_frame
	assert(audio.music_player.playing, "Music starts when enabled")
	audio.configure({"music": false, "sound": false})
	assert(not audio.music_player.playing, "Music stops immediately when disabled")
	audio.play_event(Audio.Event.MUSIC)
	audio.play_event(Audio.Event.BLOCKED)
	assert(not audio.music_enabled and not audio.sound_enabled, "Silent audio hooks respect settings")
	var monetization := Monetization.new()
	root.add_child(monetization)
	monetization.on_level_completed()
	monetization.on_level_completed()
	monetization.on_level_completed()
	assert(monetization.completed_since_ad == 3, "Interstitial waits for three completions")
	monetization._on_purchase_verified("other_product")
	assert(not monetization.ads_removed, "Unrelated purchases do not remove ads")
	monetization._on_purchase_verified(Monetization.PRODUCT_ID)
	assert(monetization.ads_removed, "Verified remove-ads purchase disables ads")
	var rewards := {"earned": 0}
	monetization.reward_earned.connect(func(coins: int): rewards.earned += coins)
	monetization.reward_pending = true
	monetization._on_user_earned_reward(monetization.rewarded_uid, {"amount": 1, "type": "coins"})
	monetization._on_user_earned_reward(monetization.rewarded_uid, {"amount": 1, "type": "coins"})
	assert(rewards.earned == 50, "Reward callback grants coins once")
	monetization._on_rewarded_closed(monetization.rewarded_uid)
	assert(not monetization.reward_pending, "Closing an ad clears its pending reward")
	print("Traffic Mash delivery system tests passed.")
	quit()
