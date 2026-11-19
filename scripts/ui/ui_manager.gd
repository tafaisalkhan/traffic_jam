class_name UIManager
extends CanvasLayer

signal play_requested
signal level_requested(level_id: int)
signal restart_requested
signal undo_requested
signal pause_requested
signal resume_requested
signal main_menu_requested
signal next_requested
signal settings_changed(next_settings: Dictionary)
signal cosmetic_selected(cosmetic: String)
signal remove_ads_requested
signal restore_purchases_requested
signal rewarded_ad_requested
signal time_start_requested
signal time_boost_requested
signal time_ad_requested
signal time_options_closed
signal splash_finished
signal privacy_acknowledged
signal privacy_dismissed
signal coin_purchase_requested
signal lives_continue_requested
signal lives_ad_requested
signal daily_challenge_requested
signal daily_reward_claim_requested
signal shop_free_chest_requested
signal shop_pack_requested(product_id: String)
signal coffee_purchase_requested
signal rate_app_requested
signal share_game_requested
signal convoy_test_requested

const Tokens = preload("res://scripts/core/design_tokens.gd")
const GameIcon = preload("res://assets/ui/traffic_mash_icon_hd.png")
const SplashArt = preload("res://assets/ui/traffic_mash_splash_hd.png")
const BtnPlayTex = preload("res://assets/ui/btn_play_tex.png")
const BtnMenuTex = preload("res://assets/ui/btn_menu_tex.png")
const BtnGoldTex = preload("res://assets/ui/btn_gold_tex.png")
const PanelHudTex = preload("res://assets/ui/panel_hud_tex.png")
const IconLevel = preload("res://assets/ui/icon_level.png")
const IconTime = preload("res://assets/ui/icon_time.png")
const IconCoin = preload("res://assets/ui/coin.png")
const IconStar = preload("res://assets/ui/star.png")
const IconSettings = preload("res://assets/ui/icon_settings.png")
const OFF_WHITE := Color("f5f2eb")
const GameFont = preload("res://assets/fonts/LuckiestGuy-Regular.ttf")
const PrivacyPolicy = preload("res://scripts/core/privacy_policy.gd")
var root: Control
var hud: Control
var moves_label: Label
var status_label: Label
var time_icon: TextureRect
var coin_hud_label: Label
var lives_label: Label
var lives_ad_button: Button
var settings := {"music": true, "sound": true, "vibration": true, "daily_notifications": true}
var highest_unlocked := 1
var daily_completed_today := false
var daily_streak := 0
var daily_reward_day := 1
var daily_reward_can_claim := true
var free_chest_ready := true
var hints_count := 3
var no_fill_active := false
var support_overlay: Control
var daily_reward_overlay: Control
var stars_by_level: Dictionary = {}
var coins := 0
var selected_cosmetic := "classic"
var campaign_total := 10
var level_page := 0
var ads_removed := false
var purchase_available := false
var purchase_message := ""
var rewarded_ready := false
var reward_button: Button
var time_reward_button: Button
var time_overlay: Control
var privacy_overlay: Control
var coin_purchase_available := false
var coin_purchase_message := ""
var timer_label: Label
var time_button: Button
var screen_generation := 0
var current_screen := ""

static func create_game_theme() -> Theme:
	var ui_theme := Theme.new()
	ui_theme.default_font = GameFont
	ui_theme.set_font("font", "Label", GameFont)
	ui_theme.set_font("font", "Button", GameFont)
	ui_theme.set_color("font_color", "Label", OFF_WHITE)
	ui_theme.set_color("font_color", "Button", OFF_WHITE)
	ui_theme.set_color("font_hover_color", "Button", OFF_WHITE)
	ui_theme.set_color("font_pressed_color", "Button", OFF_WHITE)
	return ui_theme

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = create_game_theme()
	# The board must receive taps through transparent gameplay UI areas. Buttons
	# and panels keep their own default input handling.
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

func configure_progress(highest: int, stars: Dictionary, total_coins: int, total_levels := 10) -> void:
	highest_unlocked = highest
	stars_by_level = stars.duplicate()
	coins = total_coins
	campaign_total = total_levels

func configure_profile(next_settings: Dictionary, cosmetic: String) -> void:
	settings = next_settings.duplicate()
	selected_cosmetic = cosmetic

func configure_monetization(owned: bool, available: bool, message := "") -> void:
	ads_removed = owned
	purchase_available = available
	purchase_message = message

func configure_coin_store(available: bool, message := "") -> void:
	coin_purchase_available = available
	coin_purchase_message = message

func configure_daily(completed_today: bool, streak: int) -> void:
	daily_completed_today = completed_today
	daily_streak = streak

func configure_daily_reward(current_day: int, can_claim: bool, chest_ready := true, hints := 3) -> void:
	daily_reward_day = maxi(1, current_day)
	daily_reward_can_claim = can_claim
	free_chest_ready = chest_ready
	hints_count = hints

func configure_no_fill(no_fill: bool) -> void:
	no_fill_active = no_fill
	configure_rewarded(rewarded_ready)

func configure_rewarded(ready: bool) -> void:
	rewarded_ready = ready and not no_fill_active
	if reward_button != null and is_instance_valid(reward_button):
		reward_button.visible = rewarded_ready
		reward_button.disabled = not rewarded_ready
		reward_button.text = "WATCH AD  •  +50 COINS" if rewarded_ready else "REWARDED AD LOADING"
	if lives_ad_button != null and is_instance_valid(lives_ad_button):
		lives_ad_button.visible = rewarded_ready
		lives_ad_button.disabled = not rewarded_ready
		lives_ad_button.text = "WATCH AD (+50 COINS)" if rewarded_ready else "AD LOADING..."
	if time_reward_button != null and is_instance_valid(time_reward_button):
		time_reward_button.visible = rewarded_ready
		time_reward_button.disabled = not rewarded_ready
		time_reward_button.text = "WATCH AD: +50 COINS & +15s" if rewarded_ready else "REWARDED AD LOADING"

func _add_splash_background() -> void:
	_add_backdrop(Color("071728"))
	var artwork := TextureRect.new()
	artwork.texture = SplashArt
	artwork.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	artwork.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	artwork.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	artwork.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(artwork)

func show_splash() -> void:
	_clear()
	current_screen = "splash"
	_add_splash_background()
	var title := _label("CITY RESCUE PUZZLE", 42, OFF_WHITE); title.position = Vector2(45, 112); title.size = Vector2(630, 78); title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; root.add_child(title)
	var caption := _label("CLEAR THE ROAD. SAVE THE DAY.", 20, Tokens.GOLD); caption.add_theme_color_override("font_color", Tokens.GOLD); caption.position = Vector2(90, 193); caption.size = Vector2(540, 36); caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; root.add_child(caption)

	# 2D glossy game-styled loading bar
	var bar_frame := _tex_panel(Vector2(96, 1072), Vector2(528, 46), PanelHudTex)
	root.add_child(bar_frame)
	var bar_clip := Control.new()
	bar_clip.position = Vector2(10, 8); bar_clip.size = Vector2(508, 30); bar_clip.clip_contents = true
	bar_frame.add_child(bar_clip)
	var bar_fill := _tex_panel(Vector2(0, 0), Vector2(0, 30), BtnGoldTex)
	bar_clip.add_child(bar_fill)
	var bar_icon := _add_tex_icon(bar_frame, IconLevel, Vector2(0, -10), Vector2(44, 44))
	var loading := _label("PREPARING THE CITY  0%", 22, OFF_WHITE); loading.position = Vector2(96, 1130); loading.size = Vector2(528, 36); loading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; root.add_child(loading)

	var generation := screen_generation
	var tween := create_tween()
	tween.tween_method(func(val: float) -> void:
		if screen_generation != generation:
			return
		var ratio := clampf(val / 100.0, 0.0, 1.0)
		if is_instance_valid(bar_fill):
			bar_fill.size.x = 508.0 * ratio
		if is_instance_valid(bar_icon):
			bar_icon.offset_left = 8.0 + 476.0 * ratio - 12.0
			bar_icon.offset_right = bar_icon.offset_left + 44.0
		if is_instance_valid(loading):
			loading.text = "PREPARING THE CITY  %d%%" % int(round(val))
	, 0.0, 100.0, 1.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(func():
		if screen_generation == generation:
			show_main_menu()
			splash_finished.emit()
	)

func show_main_menu() -> void:
	_clear()
	current_screen = "menu"
	_add_splash_background()
	var scrim := ColorRect.new(); scrim.color = Color("07172826"); scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE; root.add_child(scrim)

	# Clean aligned top bar: visible Settings button on left, ONLY Coin count pill on right
	var settings_btn := _tex_button("", Vector2(24, 22), Vector2(76, 72), BtnMenuTex)
	settings_btn.pressed.connect(show_settings); root.add_child(settings_btn)
	_add_tex_icon(settings_btn, IconSettings, Vector2(16, 14), Vector2(44, 44))

	var coin_pill := _tex_panel(Vector2(476, 28), Vector2(220, 60), PanelHudTex); root.add_child(coin_pill)
	var menu_coin := _add_tex_icon(coin_pill, IconCoin, Vector2(14, 13), Vector2(34, 34))
	menu_coin.pivot_offset = Vector2(17, 17)
	_animate_pulse(menu_coin, 1.13, 0.7)
	var balance := _label("%d" % coins, 24, OFF_WHITE)
	balance.position = Vector2(52, 12); balance.size = Vector2(108, 36); balance.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; balance.vertical_alignment = VERTICAL_ALIGNMENT_CENTER; coin_pill.add_child(balance)
	var coin_plus := _tex_button("+", Vector2(166, 10), Vector2(40, 40), BtnPlayTex)
	coin_plus.add_theme_font_size_override("font_size", 22); coin_plus.pressed.connect(show_shop); coin_pill.add_child(coin_plus)

	# Title with bold shadow
	var title := _label("CITY RESCUE PUZZLE", 40, OFF_WHITE); title.position = Vector2(45, 118); title.size = Vector2(630, 68); title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_shadow_color", Color("040c16dd")); title.add_theme_constant_override("shadow_offset_x", 0); title.add_theme_constant_override("shadow_offset_y", 5); root.add_child(title)
	var subtitle := _label("CLEAR THE ROAD. SAVE THE DAY.", 18, Tokens.GOLD); subtitle.add_theme_color_override("font_color", Tokens.GOLD)
	subtitle.position = Vector2(90, 184); subtitle.size = Vector2(540, 32); subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_color_override("font_shadow_color", Color("040c16cc")); subtitle.add_theme_constant_override("shadow_offset_y", 3); root.add_child(subtitle)

	# Left glossy button: SHOP (matches game button style, with READY badge)
	var shop_btn := _tex_button("SHOP", Vector2(24, 246), Vector2(158, 76), BtnGoldTex)
	shop_btn.add_theme_font_size_override("font_size", 20)
	shop_btn.pressed.connect(show_shop); root.add_child(shop_btn)
	_add_tex_icon(shop_btn, IconCoin, Vector2(12, 20), Vector2(34, 34))
	_animate_pop_in(shop_btn, 0.05)

	# Right glossy buttons: aligned 196px wide column matching each other
	var daily_reward_btn := _tex_button("REWARD", Vector2(500, 246), Vector2(196, 76), BtnGoldTex if daily_reward_can_claim else BtnMenuTex)
	daily_reward_btn.add_theme_font_size_override("font_size", 19)
	daily_reward_btn.pressed.connect(show_daily_reward); root.add_child(daily_reward_btn)
	_add_tex_icon(daily_reward_btn, IconCoin, Vector2(14, 21), Vector2(32, 32))
	_animate_pop_in(daily_reward_btn, 0.10)
	if daily_reward_can_claim:
		var gift_tag := _tex_panel(Vector2(53, 62), Vector2(90, 32), BtnPlayTex)
		gift_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		daily_reward_btn.add_child(gift_tag)
		var gift_lbl := _label("CLAIM", 13, OFF_WHITE); gift_lbl.position = Vector2(0, 5); gift_lbl.size = Vector2(90, 22); gift_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; gift_tag.add_child(gift_lbl)
		gift_tag.pivot_offset = Vector2(45, 16)
		_animate_pulse(gift_tag, 1.08, 0.65)

	var daily_text := "DAILY ✓" if daily_completed_today else "DAILY +50"
	var daily_btn := _tex_button(daily_text, Vector2(500, 344), Vector2(196, 76), BtnMenuTex if daily_completed_today else BtnGoldTex)
	daily_btn.add_theme_font_size_override("font_size", 18)
	daily_btn.pressed.connect(daily_challenge_requested.emit); root.add_child(daily_btn)
	_add_tex_icon(daily_btn, IconStar, Vector2(14, 21), Vector2(32, 32))
	_animate_pop_in(daily_btn, 0.16)

	# Bottom glossy PLAY / LEVEL button
	var play := _tex_button("LEVEL %d" % highest_unlocked, Vector2(140, 940), Vector2(440, 108), BtnPlayTex)
	play.add_theme_font_size_override("font_size", 36)
	play.pivot_offset = Vector2(220, 54)
	play.pressed.connect(play_requested.emit); root.add_child(play)
	_animate_pulse(play, 1.04, 0.9)

func show_gameplay(level_id: int, moves: int, target: int, cars: int, message: String) -> void:
	_clear()
	current_screen = "gameplay"
	hud = Control.new(); hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); hud.mouse_filter = Control.MOUSE_FILTER_IGNORE; root.add_child(hud)
	var status_panel := _tex_panel(Vector2(204, 22), Vector2(312, 82), PanelHudTex); hud.add_child(status_panel)
	_add_tex_icon(status_panel, IconLevel, Vector2(20, 23), Vector2(36, 36))
	var level_label := _label("LEVEL %02d" % level_id, 24, OFF_WHITE); level_label.position = Vector2(62, 18); level_label.size = Vector2(230, 46); level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; level_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER; status_panel.add_child(level_label)
	moves_label = null
	var pause := _tex_icon_button(IconSettings, Vector2(22, 26), Vector2(58, 58)); pause.pressed.connect(func(): pause_requested.emit()); hud.add_child(pause)
	var lives_pill := _tex_panel(Vector2(90, 30), Vector2(104, 50), PanelHudTex); hud.add_child(lives_pill)
	lives_label = _label("♥ 3/3", 20, OFF_WHITE); lives_label.position = Vector2(0, 8); lives_label.size = Vector2(104, 34); lives_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; lives_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER; lives_pill.add_child(lives_label)
	var coin_hud := _tex_panel(Vector2(532, 26), Vector2(166, 52), PanelHudTex); hud.add_child(coin_hud)
	_add_tex_icon(coin_hud, IconCoin, Vector2(12, 10), Vector2(32, 32))
	coin_hud_label = _label("%d" % coins, 20, OFF_WHITE); coin_hud_label.position = Vector2(46, 10); coin_hud_label.size = Vector2(108, 32); coin_hud_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; coin_hud_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER; coin_hud.add_child(coin_hud_label)
	time_icon = TextureRect.new(); time_icon.texture = IconTime; time_icon.position = Vector2(534, 86); time_icon.size = Vector2(28, 28); time_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; time_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED; time_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE; hud.add_child(time_icon)
	timer_label = _label("TIME: --", 19, OFF_WHITE); timer_label.position = Vector2(564, 86); timer_label.size = Vector2(134, 30); timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; hud.add_child(timer_label)
	time_button = _tex_button("+15s", Vector2(552, 122), Vector2(128, 48), BtnGoldTex); time_button.pressed.connect(time_boost_requested.emit); hud.add_child(time_button)
	update_gameplay(level_id, moves, target, cars, message)

func update_coins(amount: int) -> void:
	coins = amount
	if coin_hud_label != null and is_instance_valid(coin_hud_label):
		coin_hud_label.text = "%d" % amount

func update_lives(current: int, total: int) -> void:
	if lives_label != null and is_instance_valid(lives_label):
		lives_label.text = "♥ %d/%d" % [current, total]
		lives_label.add_theme_color_override("font_color", Color("f87171") if current <= 1 else OFF_WHITE)

func update_gameplay(level_id: int, moves: int, target: int, cars: int, message: String) -> void:
	if moves_label != null and is_instance_valid(moves_label): moves_label.text = ""
	if status_label != null: status_label.text = message

func update_time(seconds: float) -> void:
	if timer_label != null:
		timer_label.text = "TIME: %ds" % ceili(seconds)
		timer_label.add_theme_color_override("font_color", Color("f87171") if seconds <= 10.0 else Color.WHITE)

func set_time_controls_visible(visible: bool) -> void:
	if time_icon != null: time_icon.visible = visible
	if timer_label != null: timer_label.visible = visible
	if time_button != null: time_button.visible = visible

func show_time_briefing(level_id: int, seconds: int) -> void:
	close_time_overlay()
	time_overlay = _overlay()
	var panel := _tex_panel(Vector2(88, 370), Vector2(544, 510), PanelHudTex); time_overlay.add_child(panel)
	var title := _label("LEVEL %d" % level_id, 38, OFF_WHITE); title.position = Vector2(110, 415); title.size = Vector2(500, 55); title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; time_overlay.add_child(title)
	var clock_row := HBoxContainer.new(); clock_row.position = Vector2(110, 494); clock_row.size = Vector2(500, 62); clock_row.alignment = BoxContainer.ALIGNMENT_CENTER; clock_row.add_theme_constant_override("separation", 14); time_overlay.add_child(clock_row)
	var clock_icon := TextureRect.new(); clock_icon.texture = IconTime; clock_icon.custom_minimum_size = Vector2(46, 46); clock_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; clock_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED; clock_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER; clock_row.add_child(clock_icon)
	var clock := _label("%d SECONDS" % seconds, 42, OFF_WHITE); clock.vertical_alignment = VERTICAL_ALIGNMENT_CENTER; clock_row.add_child(clock)
	var guide := _label("Complete this level before time runs out.", 20, OFF_WHITE); guide.position = Vector2(110, 595); guide.size = Vector2(500, 60); guide.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; guide.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; time_overlay.add_child(guide)
	var start := _tex_button("START LEVEL", Vector2(150, 710), Vector2(420, 76), BtnPlayTex)
	start.pressed.connect(func(): close_time_overlay(); time_start_requested.emit()); time_overlay.add_child(start)

func show_time_options(coins_available: int, cost: int, expired: bool) -> void:
	close_time_overlay()
	time_overlay = _overlay()
	var show_ad_btn := rewarded_ready
	var panel := _tex_panel(Vector2(78, 344 if show_ad_btn else 368), Vector2(564, 558 if show_ad_btn else 488), PanelHudTex); time_overlay.add_child(panel)
	var heading := _label("TIME'S UP!" if expired else "NEED MORE TIME?", 36, Color("f87171") if expired else OFF_WHITE); heading.position = Vector2(105, 386 if show_ad_btn else 412); heading.size = Vector2(510, 58); heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; time_overlay.add_child(heading)
	var balance := _label("YOUR COINS: %d" % coins_available, 24, Tokens.GOLD); balance.add_theme_color_override("font_color", Tokens.GOLD); balance.position = Vector2(105, 468 if show_ad_btn else 492); balance.size = Vector2(510, 40); balance.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; time_overlay.add_child(balance)
	var buy := _tex_button("+15s  •  %d COINS" % cost if coins_available >= cost else "NEED %d COINS FOR +15s" % cost, Vector2(135, 548 if show_ad_btn else 578), Vector2(450, 72), BtnPlayTex)
	buy.add_theme_font_size_override("font_size", 24)
	buy.disabled = coins_available < cost
	buy.pressed.connect(time_boost_requested.emit); time_overlay.add_child(buy)
	if show_ad_btn:
		time_reward_button = _tex_button("WATCH AD: +50 COINS & +15s" if rewarded_ready else "REWARDED AD LOADING", Vector2(135, 642), Vector2(450, 72), BtnGoldTex)
		time_reward_button.add_theme_font_size_override("font_size", 22)
		time_reward_button.disabled = not rewarded_ready
		time_reward_button.pressed.connect(time_ad_requested.emit); time_overlay.add_child(time_reward_button)
	else:
		time_reward_button = null
	var exit_button := _tex_button("TRY AGAIN" if expired else "KEEP PLAYING", Vector2(175, 758 if show_ad_btn else 704), Vector2(370, 68), BtnMenuTex)
	exit_button.add_theme_font_size_override("font_size", 24)
	if expired:
		exit_button.pressed.connect(func(): close_time_overlay(); restart_requested.emit())
	else:
		exit_button.pressed.connect(func(): close_time_overlay(); time_options_closed.emit())
	time_overlay.add_child(exit_button)

func close_time_overlay() -> void:
	if time_overlay != null and is_instance_valid(time_overlay):
		time_overlay.queue_free()
	time_overlay = null
	time_reward_button = null

func show_pause() -> void:
	var overlay := _overlay()
	var panel := _tex_panel(Vector2(98, 320), Vector2(524, 540), PanelHudTex); overlay.add_child(panel)
	var title := _label("PAUSED", 42, OFF_WHITE); title.position = Vector2(125, 360); title.size = Vector2(470, 60); title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; overlay.add_child(title)
	var resume := _tex_button("RESUME", Vector2(160, 450), Vector2(400, 72), BtnPlayTex); resume.add_theme_font_size_override("font_size", 26); resume.pressed.connect(func(): _remove_overlay(overlay); resume_requested.emit()); overlay.add_child(resume)
	var settings_p := _tex_button("SETTINGS", Vector2(160, 538), Vector2(400, 68), BtnMenuTex); settings_p.add_theme_font_size_override("font_size", 24); settings_p.pressed.connect(func(): _remove_overlay(overlay); show_settings()); overlay.add_child(settings_p)
	var restart := _tex_button("RESTART", Vector2(160, 622), Vector2(400, 68), BtnGoldTex); restart.add_theme_font_size_override("font_size", 24); restart.pressed.connect(func(): _remove_overlay(overlay); restart_requested.emit()); overlay.add_child(restart)
	var menu := _tex_button("MAIN MENU", Vector2(160, 706), Vector2(400, 68), BtnMenuTex); menu.add_theme_font_size_override("font_size", 24); menu.pressed.connect(func(): _remove_overlay(overlay); main_menu_requested.emit()); overlay.add_child(menu)

func show_lives_fail(coins_available: int, cost: int, ad_ready: bool) -> void:
	close_time_overlay()
	time_overlay = _overlay()
	var show_ad_btn := ad_ready and not no_fill_active
	var panel := _tex_panel(Vector2(78, 355 if show_ad_btn else 365), Vector2(564, 570 if show_ad_btn else 510), PanelHudTex); time_overlay.add_child(panel)
	var title := _label("CRASHED!", 40, OFF_WHITE); title.position = Vector2(100, 395 if show_ad_btn else 405); title.size = Vector2(520, 58); title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; time_overlay.add_child(title)
	var guide_msg := "All 3 lives lost! Continue with %d coins or watch an ad." % cost if show_ad_btn else "All 3 lives lost! Continue with %d coins or retry." % cost
	var guide := _label(guide_msg, 21, OFF_WHITE); guide.position = Vector2(110, 468 if show_ad_btn else 476); guide.size = Vector2(500, 66); guide.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; guide.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; time_overlay.add_child(guide)
	var coin_row := HBoxContainer.new(); coin_row.position = Vector2(110, 540 if show_ad_btn else 548); coin_row.size = Vector2(500, 40); coin_row.alignment = BoxContainer.ALIGNMENT_CENTER; coin_row.add_theme_constant_override("separation", 10); time_overlay.add_child(coin_row)
	var c_icon := TextureRect.new(); c_icon.texture = IconCoin; c_icon.custom_minimum_size = Vector2(32, 32); c_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; c_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED; c_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER; coin_row.add_child(c_icon)
	var c_lbl := _label("COINS: %d" % coins_available, 22, OFF_WHITE); c_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER; coin_row.add_child(c_lbl)
	var cont_btn := _tex_button("CONTINUE (%d COINS)" % cost, Vector2(138, 608 if show_ad_btn else 622), Vector2(444, 70), BtnPlayTex)
	cont_btn.disabled = coins_available < cost; cont_btn.pressed.connect(lives_continue_requested.emit); time_overlay.add_child(cont_btn)
	if show_ad_btn:
		lives_ad_button = _tex_button("WATCH AD (+50 COINS)" if ad_ready else "AD LOADING...", Vector2(138, 694), Vector2(444, 68), BtnGoldTex)
		lives_ad_button.disabled = not ad_ready; lives_ad_button.pressed.connect(lives_ad_requested.emit); time_overlay.add_child(lives_ad_button)
	else:
		lives_ad_button = null
	var retry_y := 782 if show_ad_btn else 730
	var retry_btn := _tex_button("RETRY", Vector2(138, retry_y), Vector2(212, 66), BtnGoldTex)
	retry_btn.pressed.connect(func(): close_time_overlay(); restart_requested.emit()); time_overlay.add_child(retry_btn)
	var menu_btn := _tex_button("MAIN MENU", Vector2(370, retry_y), Vector2(212, 66), BtnMenuTex)
	menu_btn.pressed.connect(func(): close_time_overlay(); main_menu_requested.emit()); time_overlay.add_child(menu_btn)

func show_complete(moves: int, target: int, earned_stars := -1) -> void:
	_clear()
	current_screen = "complete"
	var overlay := _overlay()
	var coin_hud := _tex_panel(Vector2(516, 92), Vector2(180, 54), PanelHudTex); overlay.add_child(coin_hud)
	var hud_coin_icon := _add_tex_icon(coin_hud, IconCoin, Vector2(14, 11), Vector2(32, 32))
	hud_coin_icon.pivot_offset = Vector2(16, 16)
	var start_coins := maxi(0, coins - 20)
	var hud_coin_lbl := _label("%d" % start_coins, 22, OFF_WHITE); hud_coin_lbl.position = Vector2(52, 11); hud_coin_lbl.size = Vector2(116, 32); hud_coin_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; hud_coin_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER; coin_hud.add_child(hud_coin_lbl)

	var panel := _tex_panel(Vector2(78, 340), Vector2(564, 600), PanelHudTex); overlay.add_child(panel)
	var title := _label("LEVEL COMPLETE!", 36, OFF_WHITE); title.position = Vector2(100, 376); title.size = Vector2(520, 56); title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; overlay.add_child(title)
	var stars := earned_stars if earned_stars > 0 else 3 if moves <= target else 2 if moves <= target + 2 else 1
	for s_idx in range(3):
		var star_tex := _add_tex_icon(overlay, IconStar, Vector2(244 + s_idx * 84, 444), Vector2(64, 64))
		star_tex.pivot_offset = Vector2(32, 32)
		if s_idx >= stars:
			star_tex.modulate = Color(1.0, 1.0, 1.0, 0.25)
		else:
			star_tex.scale = Vector2.ZERO
			var star_tween := star_tex.create_tween()
			if s_idx > 0:
				star_tween.tween_interval(float(s_idx) * 0.2)
			star_tween.tween_property(star_tex, "scale", Vector2(1.22, 1.22), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			star_tween.tween_property(star_tex, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	var reward_row := HBoxContainer.new(); reward_row.position = Vector2(100, 540); reward_row.size = Vector2(520, 40); reward_row.alignment = BoxContainer.ALIGNMENT_CENTER; reward_row.add_theme_constant_override("separation", 10); overlay.add_child(reward_row)
	var coin_tex := TextureRect.new(); coin_tex.texture = IconCoin; coin_tex.custom_minimum_size = Vector2(34, 34); coin_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; coin_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED; coin_tex.size_flags_vertical = Control.SIZE_SHRINK_CENTER; reward_row.add_child(coin_tex)
	var reward_lbl := _label("+20", 24, OFF_WHITE); reward_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER; reward_row.add_child(reward_lbl)

	# Fly 8 coins from the reward area into the top-right Coin HUD
	var fly_target := Vector2(534, 103)
	for c_idx in range(8):
		var fly_coin := _add_tex_icon(overlay, IconCoin, Vector2(344 + (c_idx % 3 - 1) * 18, 564), Vector2(30, 30))
		fly_coin.pivot_offset = Vector2(15, 15)
		fly_coin.modulate.a = 0.0
		var ft := fly_coin.create_tween()
		ft.tween_interval(0.45 + float(c_idx) * 0.07)
		ft.tween_property(fly_coin, "modulate:a", 1.0, 0.08)
		ft.tween_property(fly_coin, "position", fly_target, 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		ft.tween_callback(func():
			if is_instance_valid(fly_coin): fly_coin.queue_free()
			if is_instance_valid(hud_coin_lbl):
				var progress_val := start_coins + int(round(20.0 * float(c_idx + 1) / 8.0))
				hud_coin_lbl.text = "%d" % progress_val
			if is_instance_valid(hud_coin_icon):
				var pt := hud_coin_icon.create_tween()
				pt.tween_property(hud_coin_icon, "scale", Vector2(1.22, 1.22), 0.07)
				pt.tween_property(hud_coin_icon, "scale", Vector2.ONE, 0.09)
		)

	var next := _tex_button("NEXT LEVEL", Vector2(148, 646), Vector2(424, 76), BtnPlayTex); next.pressed.connect(next_requested.emit); overlay.add_child(next)
	var retry := _tex_button("RETRY", Vector2(148, 756), Vector2(204, 68), BtnGoldTex); retry.pressed.connect(restart_requested.emit); overlay.add_child(retry)
	var main_btn := _tex_button("MAIN MENU", Vector2(368, 756), Vector2(204, 68), BtnMenuTex); main_btn.pressed.connect(main_menu_requested.emit); overlay.add_child(main_btn)

func show_level_select() -> void:
	_clear()
	current_screen = "level_select"
	_add_backdrop(Color("0d2139e6"))
	var title := _label("SELECT LEVEL", 38, OFF_WHITE); title.position = Vector2(70, 100); title.size = Vector2(580, 55); title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; root.add_child(title)
	var first_level := level_page * 10 + 1
	for index in range(10):
		var level_id := first_level + index
		if level_id > campaign_total: continue
		var position := Vector2(88 + (index % 2) * 285, 220 + (index / 2) * 145)
		var unlocked := level_id <= highest_unlocked
		var earned := int(stars_by_level.get(level_id, 0))
		var caption := "LEVEL %02d" % level_id if unlocked else "LOCKED"
		var button := _tex_button(caption, position, Vector2(250, 112), BtnPlayTex if unlocked else BtnMenuTex)
		button.disabled = not unlocked
		if unlocked:
			button.pressed.connect(level_requested.emit.bind(level_id))
			for s_idx in range(3):
				var s_icon := _add_tex_icon(button, IconStar, Vector2(77 + s_idx * 34, 74), Vector2(28, 28))
				if s_idx >= earned:
					s_icon.modulate = Color(1.0, 1.0, 1.0, 0.25)
		root.add_child(button)
	var previous := _button("<", Vector2(70, 1020), Vector2(70, 62), Tokens.PANEL_HIGHLIGHT); previous.disabled = level_page == 0; previous.pressed.connect(_previous_level_page); root.add_child(previous)
	var back := _button("BACK", Vector2(150, 1020), Vector2(420, 62), Tokens.PANEL_HIGHLIGHT); back.pressed.connect(show_main_menu); root.add_child(back)
	var next := _button(">", Vector2(580, 1020), Vector2(70, 62), Tokens.PANEL_HIGHLIGHT); next.disabled = first_level + 10 > campaign_total; next.pressed.connect(_next_level_page); root.add_child(next)

func _previous_level_page() -> void:
	level_page = maxi(0, level_page - 1)
	show_level_select()

func _next_level_page() -> void:
	level_page = mini((campaign_total - 1) / 10, level_page + 1)
	show_level_select()

func show_settings() -> void:
	_clear()
	current_screen = "settings"
	_add_backdrop(Color("0b1942"))

	var back_top := _tex_button("BACK", Vector2(24, 30), Vector2(148, 68), BtnMenuTex)
	back_top.add_theme_font_size_override("font_size", 26); back_top.pressed.connect(show_main_menu); root.add_child(back_top)
	var title := _label("SETTINGS", 46, OFF_WHITE); title.position = Vector2(180, 32); title.size = Vector2(360, 62); title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; root.add_child(title)

	# Toggles card
	var toggles_card := _tex_panel(Vector2(36, 122), Vector2(648, 490), PanelHudTex); root.add_child(toggles_card)
	var rows := [
		["MUSIC", "music"],
		["SOUND EFFECTS", "sound"],
		["VIBRATION", "vibration"],
		["GRAPHICS", "graphics_quality"],
		["DAILY ALERTS", "daily_notifications"]
	]
	var y := 152
	for row in rows:
		var key: String = row[1]
		var lbl := _label(row[0], 28, OFF_WHITE); lbl.position = Vector2(68, y + 12); lbl.size = Vector2(370, 48); root.add_child(lbl)
		var value := str(settings.get(key, "mobile")).to_upper() if key == "graphics_quality" else ("ON" if bool(settings.get(key, true)) else "OFF")
		var toggle := _tex_button(value, Vector2(452, y), Vector2(204, 72), BtnPlayTex if value != "OFF" else BtnMenuTex)
		toggle.add_theme_font_size_override("font_size", 26)
		toggle.pressed.connect(_toggle_setting.bind(key))
		root.add_child(toggle)
		y += 90

	# Actions card
	var actions_card := _tex_panel(Vector2(36, 624), Vector2(648, 560), PanelHudTex); root.add_child(actions_card)
	var remove_btn := _tex_button("ADS REMOVED ✓" if ads_removed else "REMOVE ADS • $4.99", Vector2(62, 650), Vector2(596, 74), BtnMenuTex if ads_removed else BtnGoldTex)
	remove_btn.add_theme_font_size_override("font_size", 26)
	remove_btn.disabled = ads_removed
	remove_btn.pressed.connect(remove_ads_requested.emit); root.add_child(remove_btn)

	var rate_btn := _tex_button("RATE GAME", Vector2(62, 740), Vector2(284, 74), BtnPlayTex)
	rate_btn.add_theme_font_size_override("font_size", 25); rate_btn.pressed.connect(rate_app_requested.emit); root.add_child(rate_btn)
	var share_btn := _tex_button("SHARE GAME", Vector2(374, 740), Vector2(284, 74), BtnMenuTex)
	share_btn.add_theme_font_size_override("font_size", 25); share_btn.pressed.connect(share_game_requested.emit); root.add_child(share_btn)

	var coffee_btn := _tex_button("COFFEE • $1.99", Vector2(62, 830), Vector2(284, 74), BtnGoldTex)
	coffee_btn.add_theme_font_size_override("font_size", 24); coffee_btn.pressed.connect(coffee_purchase_requested.emit); root.add_child(coffee_btn)
	var restore := _tex_button("RESTORE", Vector2(374, 830), Vector2(284, 74), BtnMenuTex)
	restore.add_theme_font_size_override("font_size", 25); restore.pressed.connect(restore_purchases_requested.emit); root.add_child(restore)

	var privacy := _tex_button("PRIVACY", Vector2(62, 920), Vector2(284, 72), BtnMenuTex)
	privacy.add_theme_font_size_override("font_size", 24); privacy.pressed.connect(show_privacy_popup); root.add_child(privacy)
	var back := _tex_button("MAIN MENU", Vector2(374, 920), Vector2(284, 72), BtnPlayTex)
	back.add_theme_font_size_override("font_size", 24); back.pressed.connect(show_main_menu); root.add_child(back)

	var note_text := coin_purchase_message if not coin_purchase_message.is_empty() else purchase_message if not purchase_message.is_empty() else "Progress is saved on your device. Google Play handles purchases."
	var note := _label(note_text, 22, Tokens.GOLD); note.add_theme_color_override("font_color", Tokens.GOLD)
	note.position = Vector2(64, 1016); note.size = Vector2(592, 110); note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; root.add_child(note)

func show_privacy_popup() -> void:
	if privacy_overlay != null and is_instance_valid(privacy_overlay):
		return
	privacy_overlay = _overlay()
	var card := _tex_panel(Vector2(50, 140), Vector2(620, 996), PanelHudTex); privacy_overlay.add_child(card)
	var heading := _label("PRIVACY POLICY", 38, OFF_WHITE); heading.position = Vector2(85, 186); heading.size = Vector2(550, 54); heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; privacy_overlay.add_child(heading)
	var subtitle := _label("Please read before you play", 22, Tokens.GOLD); subtitle.add_theme_color_override("font_color", Tokens.GOLD); subtitle.position = Vector2(90, 246); subtitle.size = Vector2(540, 36); subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; privacy_overlay.add_child(subtitle)
	var scroll := ScrollContainer.new(); scroll.position = Vector2(90, 304); scroll.size = Vector2(540, 616); privacy_overlay.add_child(scroll)
	var policy := Label.new(); policy.text = PrivacyPolicy.TEXT; policy.custom_minimum_size.x = 520; policy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; policy.add_theme_font_size_override("font_size", 20); policy.add_theme_color_override("font_color", Color("e6f4ff")); scroll.add_child(policy)
	var continue_button := _tex_button("CONTINUE", Vector2(115, 954), Vector2(490, 72), BtnPlayTex)
	continue_button.add_theme_font_size_override("font_size", 26)
	continue_button.pressed.connect(func(): close_privacy_popup(); privacy_acknowledged.emit()); privacy_overlay.add_child(continue_button)
	var later_button := _tex_button("NOT NOW", Vector2(115, 1042), Vector2(490, 62), BtnMenuTex)
	later_button.add_theme_font_size_override("font_size", 22)
	later_button.pressed.connect(func(): close_privacy_popup(); privacy_dismissed.emit()); privacy_overlay.add_child(later_button)

func close_privacy_popup() -> void:
	if privacy_overlay != null and is_instance_valid(privacy_overlay):
		privacy_overlay.queue_free()
	privacy_overlay = null

func show_collection() -> void:
	_clear()
	current_screen = "collection"
	_add_backdrop(Color("0d2139e6"))
	var title := _label("VEHICLE COLLECTION", 34, Color.WHITE); title.position = Vector2(60, 115); title.size = Vector2(600, 50); title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; root.add_child(title)
	var subtitle := _label("SELECT A COLOUR TINT", 17, Tokens.GOLD); subtitle.position = Vector2(60, 175); subtitle.size = Vector2(600, 28); subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; root.add_child(subtitle)
	var options := [["classic", "CLASSIC", Tokens.PRIMARY], ["ocean", "OCEAN", Color("248dcc")], ["sunset", "SUNSET", Color("e47b46")]]
	for index in range(options.size()):
		var option = options[index]
		var suffix := "  SELECTED" if option[0] == selected_cosmetic else ""
		var button := _button(option[1] + suffix, Vector2(140, 285 + index * 105), Vector2(440, 70), option[2])
		button.pressed.connect(_choose_cosmetic.bind(option[0]))
		root.add_child(button)
	var back := _button("BACK", Vector2(150, 1020), Vector2(420, 62), Tokens.PANEL_HIGHLIGHT); back.pressed.connect(show_main_menu); root.add_child(back)

func _toggle_setting(key: String) -> void:
	if key == "graphics_quality": settings[key] = "battery" if settings.get(key, "mobile") == "mobile" else "mobile"
	else: settings[key] = not settings[key]
	settings_changed.emit(settings.duplicate())
	show_settings()

func _choose_cosmetic(cosmetic: String) -> void:
	selected_cosmetic = cosmetic
	cosmetic_selected.emit(cosmetic)
	show_collection()

func _clear() -> void:
	screen_generation += 1
	current_screen = ""
	for child in root.get_children(): child.queue_free()
	hud = null; moves_label = null; status_label = null; time_icon = null; coin_hud_label = null; lives_label = null
	reward_button = null; lives_ad_button = null
	time_overlay = null; time_reward_button = null; timer_label = null; time_button = null
	privacy_overlay = null; support_overlay = null; daily_reward_overlay = null

func _add_backdrop(color: Color) -> void:
	var rect := ColorRect.new(); rect.color = color; rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); root.add_child(rect)

func _add_icon(position: Vector2, size: Vector2) -> void:
	var icon := TextureRect.new()
	icon.texture = GameIcon
	icon.position = position
	icon.size = size
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(icon)

func _overlay() -> Control:
	var overlay := Control.new(); overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new(); shade.color = Color("08121c66"); shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); overlay.add_child(shade); root.add_child(overlay); return overlay

func _remove_overlay(overlay: Control) -> void:
	overlay.queue_free()

func _panel(position: Vector2, size: Vector2, color: Color, radius: int) -> Panel:
	var panel := Panel.new(); panel.position = position; panel.size = size
	var border := Tokens.PANEL_HIGHLIGHT; border.a = color.a
	var style := StyleBoxFlat.new(); style.bg_color = color; style.border_color = border; style.set_border_width_all(2); style.corner_radius_top_left = radius; style.corner_radius_top_right = radius; style.corner_radius_bottom_left = radius; style.corner_radius_bottom_right = radius; style.shadow_color = Color("050d18bb"); style.shadow_size = 12; style.shadow_offset = Vector2(0, 7)
	panel.add_theme_stylebox_override("panel", style); return panel

func _button(text: String, position: Vector2, size: Vector2, color: Color) -> Button:
	var button := Button.new(); button.text = text; button.position = position; button.size = size; button.add_theme_font_override("font", GameFont); button.add_theme_font_size_override("font_size", 22); button.add_theme_color_override("font_color", OFF_WHITE)
	var normal := StyleBoxFlat.new(); normal.bg_color = color; normal.corner_radius_top_left = 18; normal.corner_radius_top_right = 18; normal.corner_radius_bottom_left = 18; normal.corner_radius_bottom_right = 18; normal.shadow_color = Color("06111dbb"); normal.shadow_size = 7; normal.shadow_offset = Vector2(0,5)
	var pressed := normal.duplicate(); pressed.bg_color = color.darkened(0.17); pressed.shadow_size = 2; pressed.shadow_offset = Vector2(0,2)
	button.add_theme_stylebox_override("normal", normal); button.add_theme_stylebox_override("pressed", pressed); return button

func _label(text: String, font_size: int, _color: Color) -> Label:
	var label := Label.new(); label.text = text; label.add_theme_font_override("font", GameFont); label.add_theme_font_size_override("font_size", font_size); label.add_theme_color_override("font_color", OFF_WHITE)
	label.add_theme_color_override("font_outline_color", Color("061124")); label.add_theme_constant_override("outline_size", 4)
	return label

func _tex_panel(position: Vector2, size: Vector2, tex: Texture2D) -> Panel:
	var panel := Panel.new(); panel.position = position; panel.size = size
	var style := StyleBoxTexture.new(); style.texture = tex
	style.texture_margin_left = 24; style.texture_margin_right = 24; style.texture_margin_top = 20; style.texture_margin_bottom = 20
	panel.add_theme_stylebox_override("panel", style); return panel

func _tex_button(text: String, position: Vector2, size: Vector2, tex: Texture2D) -> Button:
	var button := Button.new(); button.text = text; button.position = position; button.size = size
	var font_col := Tokens.INK if tex == BtnGoldTex else OFF_WHITE
	button.add_theme_font_override("font", GameFont); button.add_theme_font_size_override("font_size", 24)
	button.add_theme_color_override("font_color", font_col)
	button.add_theme_color_override("font_hover_color", font_col)
	button.add_theme_color_override("font_pressed_color", font_col)
	button.add_theme_color_override("font_disabled_color", font_col * Color(1, 1, 1, 0.55))
	if tex == BtnGoldTex:
		button.add_theme_color_override("font_outline_color", Color("fff8dc")); button.add_theme_constant_override("outline_size", 2)
	else:
		button.add_theme_color_override("font_outline_color", Color("061124")); button.add_theme_constant_override("outline_size", 5)
	var normal := StyleBoxTexture.new(); normal.texture = tex
	normal.texture_margin_left = 26; normal.texture_margin_right = 26; normal.texture_margin_top = 20; normal.texture_margin_bottom = 20
	var pressed := normal.duplicate(); pressed.modulate_color = Color(0.84, 0.88, 0.94, 1.0)
	var hover := normal.duplicate(); hover.modulate_color = Color(1.06, 1.06, 1.06, 1.0)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	return button

func _tex_icon_button(tex: Texture2D, position: Vector2, size: Vector2) -> TextureButton:
	var btn := TextureButton.new(); btn.texture_normal = tex; btn.position = position; btn.size = size
	btn.ignore_texture_size = true; btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	return btn

func _add_tex_icon(parent: Control, tex: Texture2D, position: Vector2, size: Vector2) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = tex
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = size
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(icon)
	icon.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	icon.offset_left = position.x
	icon.offset_top = position.y
	icon.offset_right = position.x + size.x
	icon.offset_bottom = position.y + size.y
	return icon


func show_daily_reward() -> void:
	if daily_reward_overlay != null and is_instance_valid(daily_reward_overlay):
		daily_reward_overlay.queue_free()
	daily_reward_overlay = _overlay()
	var card := _tex_panel(Vector2(44, 150), Vector2(632, 920), PanelHudTex)
	daily_reward_overlay.add_child(card)

	var close_btn := _tex_button("X", Vector2(616, 134), Vector2(68, 68), BtnGoldTex)
	close_btn.add_theme_font_size_override("font_size", 28)
	close_btn.pressed.connect(close_daily_reward)
	daily_reward_overlay.add_child(close_btn)

	# Header pill matching game theme
	var header_pill := _tex_panel(Vector2(96, 36), Vector2(440, 88), BtnGoldTex)
	card.add_child(header_pill)
	var header_lbl := _label("DAILY REWARD", 36, Tokens.INK)
	header_lbl.add_theme_color_override("font_color", Tokens.INK)
	header_lbl.position = Vector2(0, 18); header_lbl.size = Vector2(440, 52); header_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header_pill.add_child(header_lbl)

	# 7-day window starting from current streak week (1..7, 8..14, etc.)
	var week_start := ((daily_reward_day - 1) / 7) * 7 + 1
	for i in range(6):
		var day_num := week_start + i
		var col := i % 3
		var row := i / 3
		var pos := Vector2(44 + col * 184, 168 + row * 188)
		_add_daily_reward_tile(card, pos, Vector2(168, 170), day_num)
	_add_daily_reward_tile(card, Vector2(44, 548), Vector2(536, 156), week_start + 6)

	var claim_text := "CLAIM +%d" % (daily_reward_day * 10) if daily_reward_can_claim else "CLAIMED TODAY ✓"
	var claim_btn := _tex_button(claim_text, Vector2(146, 756), Vector2(340, 92), BtnPlayTex if daily_reward_can_claim else BtnMenuTex)
	claim_btn.add_theme_font_size_override("font_size", 30)
	claim_btn.disabled = not daily_reward_can_claim
	claim_btn.pressed.connect(func():
		daily_reward_claim_requested.emit()
		close_daily_reward()
	)
	card.add_child(claim_btn)

func close_daily_reward() -> void:
	if daily_reward_overlay != null and is_instance_valid(daily_reward_overlay):
		daily_reward_overlay.queue_free()
	daily_reward_overlay = null

func _add_daily_reward_tile(parent: Control, pos: Vector2, size: Vector2, day_num: int) -> void:
	var claimed := (day_num < daily_reward_day) or (day_num == daily_reward_day and not daily_reward_can_claim)
	var is_today := (day_num == daily_reward_day and daily_reward_can_claim)
	var bg_col := Color("1c4d3a") if claimed else (Color("1e3a8a") if is_today else Color("142a46"))
	var border_col := Color("37d62a") if claimed else (Tokens.GOLD if is_today else Color("38bdf8"))
	var tile := _pill_box(pos, size, bg_col, border_col, 18)
	parent.add_child(tile)

	var day_lbl := _label("DAY %d" % day_num, 22, Tokens.GOLD if is_today else OFF_WHITE)
	day_lbl.add_theme_color_override("font_color", Tokens.GOLD if is_today else OFF_WHITE)
	day_lbl.position = Vector2(0, 10); day_lbl.size = Vector2(size.x, 32); day_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tile.add_child(day_lbl)

	if claimed:
		var check_lbl := _label("✓", 56, Color("4ade80"))
		check_lbl.add_theme_color_override("font_color", Color("4ade80"))
		check_lbl.position = Vector2(0, 56); check_lbl.size = Vector2(size.x, size.y - 64); check_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tile.add_child(check_lbl)
	else:
		_add_tex_icon(tile, IconCoin, Vector2(size.x * 0.5 - 28, 52), Vector2(56, 56))
		var amt_lbl := _label("+%d" % (day_num * 10), 26, Tokens.GOLD)
		amt_lbl.add_theme_color_override("font_color", Tokens.GOLD)
		amt_lbl.position = Vector2(0, size.y - 44); amt_lbl.size = Vector2(size.x, 34); amt_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tile.add_child(amt_lbl)

func show_home_support_popup(action_idx: int = -1) -> void:
	if support_overlay != null and is_instance_valid(support_overlay):
		support_overlay.queue_free()
	var pick := action_idx if action_idx in [0, 1, 2] else randi() % 3
	support_overlay = _overlay()

	# Matched to game theme (PanelHudTex + BtnGoldTex + BtnPlayTex + readable large fonts)
	var card := _tex_panel(Vector2(45, 330), Vector2(630, 610), PanelHudTex)
	support_overlay.add_child(card)

	var header_pill := _tex_panel(Vector2(115, 294), Vector2(490, 88), BtnGoldTex)
	support_overlay.add_child(header_pill)
	var titles := ["LOVE CITY RESCUE?", "SHARE THE LOVE", "A COFFEE FOR THE DEV?"]
	var header_lbl := _label(titles[pick], 32, Tokens.INK)
	header_lbl.add_theme_color_override("font_color", Tokens.INK)
	header_lbl.position = Vector2(0, 18); header_lbl.size = Vector2(490, 52); header_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header_pill.add_child(header_lbl)

	var close_btn := _tex_button("X", Vector2(616, 314), Vector2(64, 64), BtnMenuTex)
	close_btn.add_theme_font_size_override("font_size", 26)
	close_btn.pressed.connect(func():
		if support_overlay != null and is_instance_valid(support_overlay):
			support_overlay.queue_free()
		support_overlay = null
	)
	support_overlay.add_child(close_btn)

	if no_fill_active:
		var notice := _label("NO ADS TODAY", 26, Color("62d989"))
		notice.add_theme_color_override("font_color", Color("62d989"))
		notice.position = Vector2(150, 86); notice.size = Vector2(330, 40); notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.add_child(notice)

	if pick == 0:
		for i in range(5):
			_add_tex_icon(card, IconStar, Vector2(135 + i * 74, 156), Vector2(62, 62))
	else:
		_add_tex_icon(card, IconCoin, Vector2(255, 136), Vector2(120, 120))

	var texts := [
		"Enjoying the traffic puzzles?\nYour 5-star review helps us grow!",
		"Invite a friend to play\nCity Rescue Puzzle together!",
		"Support more levels & updates.\nCoffee is a one-time $1.99 consumable."
	]
	var desc_lbl := _label(texts[pick], 25, OFF_WHITE)
	desc_lbl.position = Vector2(45, 282); desc_lbl.size = Vector2(540, 110); desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.add_child(desc_lbl)

	var cta_texts := ["RATE GAME", "SHARE GAME", "COFFEE • $1.99"]
	var cta := _tex_button(cta_texts[pick], Vector2(95, 444), Vector2(440, 92), BtnPlayTex)
	cta.add_theme_font_size_override("font_size", 28)
	cta.pressed.connect(func():
		if pick == 0:
			rate_app_requested.emit()
		elif pick == 1:
			share_game_requested.emit()
		else:
			coffee_purchase_requested.emit()
		if support_overlay != null and is_instance_valid(support_overlay):
			support_overlay.queue_free()
		support_overlay = null
	)
	card.add_child(cta)

func show_shop() -> void:
	_clear()
	current_screen = "shop"
	_add_backdrop(Color("0f1d56"))

	# Top bar: Back on left, ONLY Coin count pill on right
	var back_btn := _tex_button("BACK", Vector2(24, 24), Vector2(126, 62), BtnMenuTex)
	back_btn.add_theme_font_size_override("font_size", 20)
	back_btn.pressed.connect(show_main_menu); root.add_child(back_btn)

	var coin_pill := _tex_panel(Vector2(476, 26), Vector2(220, 60), PanelHudTex)
	root.add_child(coin_pill)
	_add_tex_icon(coin_pill, IconCoin, Vector2(14, 13), Vector2(34, 34))
	var balance := _label("%d" % coins, 24, OFF_WHITE)
	balance.position = Vector2(54, 12); balance.size = Vector2(148, 36); balance.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; balance.vertical_alignment = VERTICAL_ALIGNMENT_CENTER; coin_pill.add_child(balance)

	# Gold SHOP ribbon + awning
	var shop_ribbon := _tex_panel(Vector2(180, 110), Vector2(360, 74), BtnGoldTex)
	root.add_child(shop_ribbon)
	var shop_lbl := _label("SHOP", 34, Tokens.INK); shop_lbl.add_theme_color_override("font_color", Tokens.INK)
	shop_lbl.position = Vector2(0, 14); shop_lbl.size = Vector2(360, 46); shop_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; shop_ribbon.add_child(shop_lbl)

	for stripe_i in range(9):
		var stripe := ColorRect.new()
		stripe.color = Color("5b3ff5") if stripe_i % 2 == 0 else Color("818cf8")
		stripe.position = Vector2(stripe_i * 80, 206); stripe.size = Vector2(80, 38)
		root.add_child(stripe)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(32, 260); scroll.size = Vector2(656, 980)
	root.add_child(scroll)
	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(636, 0)
	vbox.add_theme_constant_override("separation", 20)
	scroll.add_child(vbox)

	# Only 3 Coin Packs shown in Shop (1000 / $0.99, 2000 / $1.29, 3000 / $1.99)
	var packs := [
		["coins_1000", "1,000 COINS", "$0.99"],
		["coins_2000", "2,000 COINS", "$1.29"],
		["coins_3000", "3,000 COINS", "$1.99"]
	]
	for p in packs:
		var p_card := _tex_panel(Vector2.ZERO, Vector2(636, 152), PanelHudTex)
		p_card.custom_minimum_size = Vector2(636, 152)
		vbox.add_child(p_card)
		_add_tex_icon(p_card, IconCoin, Vector2(28, 38), Vector2(76, 76))
		var p_title := _label(p[1], 28, Tokens.GOLD); p_title.add_theme_color_override("font_color", Tokens.GOLD)
		p_title.position = Vector2(124, 52); p_title.size = Vector2(260, 48); p_card.add_child(p_title)
		var p_btn := _tex_button(p[2], Vector2(400, 38), Vector2(204, 76), BtnPlayTex)
		p_btn.add_theme_font_size_override("font_size", 26)
		p_btn.pressed.connect(shop_pack_requested.emit.bind(p[0])); p_card.add_child(p_btn)

func _animate_pulse(node: Control, max_scale := 1.06, duration := 0.8) -> void:
	var t := node.create_tween().set_loops()
	t.tween_property(node, "scale", Vector2(max_scale, max_scale), duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(node, "scale", Vector2.ONE, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _animate_pop_in(node: Control, delay := 0.0) -> void:
	node.pivot_offset = node.size * 0.5
	node.scale = Vector2(0.86, 0.86)
	node.modulate.a = 0.0
	var t := node.create_tween()
	if delay > 0.0:
		t.tween_interval(delay)
	t.set_parallel(true)
	t.tween_property(node, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(node, "modulate:a", 1.0, 0.22)

func _pill_box(pos: Vector2, size: Vector2, bg: Color, border: Color, radius := 24) -> Panel:
	var panel := Panel.new()
	panel.position = pos
	panel.size = size
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(4)
	style.set_corner_radius_all(radius)
	style.shadow_color = Color("040c1688")
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 5)
	panel.add_theme_stylebox_override("panel", style)
	return panel

func _flat_round_button(text: String, pos: Vector2, size: Vector2, bg: Color, border: Color, radius := 18) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.position = pos
	btn.size = size
	btn.add_theme_font_override("font", GameFont)
	btn.add_theme_font_size_override("font_size", 22)
	btn.add_theme_color_override("font_color", Color.WHITE)
	var normal := StyleBoxFlat.new()
	normal.bg_color = bg
	normal.border_color = border
	normal.border_width_bottom = 6
	normal.border_width_left = 3
	normal.border_width_right = 3
	normal.border_width_top = 3
	normal.set_corner_radius_all(radius)
	var pressed := normal.duplicate()
	pressed.bg_color = bg.darkened(0.15)
	pressed.border_width_bottom = 2
	var hover := normal.duplicate()
	hover.bg_color = bg.lightened(0.08)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	return btn
