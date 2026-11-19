extends SceneTree

const UI = preload("res://scripts/ui/ui_manager.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var ui := UI.new()
	root.add_child(ui)
	await process_frame
	ui.show_splash()
	assert(ui.current_screen == "splash", "Splash appears before the menu")
	ui.show_main_menu()
	assert(ui.current_screen == "menu", "Main menu is reachable")
	ui.show_level_select()
	ui.show_settings()
	assert(ui.reward_button != null, "Settings contain a rewarded ad for coins")
	assert(not ui.coin_purchase_available and ui.root.find_children("*", "Button", true, false).any(func(button: Button): return button.text == "COIN STORE UNAVAILABLE"), "Coin purchase cannot be used without billing")
	ui.show_privacy_popup()
	assert(ui.privacy_overlay != null and ui.privacy_overlay.visible, "Settings can reopen the privacy policy")
	ui.close_privacy_popup()
	ui.show_gameplay(1, 0, 3, 3, "UI test")
	ui.update_time(60.0)
	ui.show_time_briefing(1, 60)
	assert(ui.time_overlay != null and ui.time_overlay.visible, "Time limit briefing appears")
	ui.show_time_options(0, 25, true)
	assert(ui.time_reward_button != null and ui.time_reward_button.disabled, "Rewarded option waits for an ad")
	ui.configure_rewarded(true)
	assert(not ui.time_reward_button.disabled, "Rewarded option becomes available when loaded")
	ui.close_time_overlay()
	ui.update_gameplay(1, 1, 3, 2, "Updated")
	ui.show_pause()
	ui.show_complete(3, 3)
	assert(ui.root.get_child_count() > 0, "A UI screen should be present")
	print("City Rescue Puzzle UI flow test passed.")
	quit()
