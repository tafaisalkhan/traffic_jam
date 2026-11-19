class_name MonetizationManager
extends Node

signal purchase_state_changed(owned: bool, message: String)
signal rewarded_ready_changed(ready: bool)
signal reward_earned(coins: int)
signal rewarded_ad_closed(earned: bool)
signal coin_purchase_verified(coins: int)
signal coin_purchase_state_changed(message: String)
signal no_fill_changed(no_fill: bool)
signal pack_purchase_verified(coins: int, hints: int, helis: int)
signal coffee_purchased(message: String)

const SECRETS_PATH := "res://admob_secrets.json"
const GOOGLE_TEST_PREFIX := "ca-app-pub-3940256099942544"
const PRODUCT_ID := "remove_ads"
const COFFEE_PRODUCT_ID := "cofee"
const COIN_PRODUCT_ID := "coins_500"
const COIN_PRODUCT_AMOUNT := 500
const ANDROID_PLUGIN := "TrafficMashMonetization"
const INTERSTITIAL_INTERVAL := 1
const REWARD_COINS := 50
const PLAY_STORE_URL := "https://play.google.com/store/apps/details?id=com.cityrescue.puzzle"

const SHOP_PACKS := {
	"coins_1000": {"coins": 1000, "hints": 0, "helis": 0},
	"coins_2000": {"coins": 2000, "hints": 0, "helis": 0},
	"coins_3000": {"coins": 3000, "hints": 0, "helis": 0}
}

var ads_removed := false
var ads_allowed := false
var no_fill_this_launch := false
var completed_since_ad := 0
var banner_unit_id := ""
var interstitial_unit_id := ""
var rewarded_unit_id := ""

var plugin: Object
var admob: Object
var banner_plugin: Object
var ad_size_plugin: Object
var interstitial_plugin: Object
var rewarded_plugin: Object
var bottom_banner_uid := -1
var top_banner_uid := -1
var interstitial_uid := -1
var rewarded_uid := -1
var bottom_banner_desired := false
var top_banner_desired := false
var gameplay_banner_active := false
var gameplay_banner_timer: Timer
var interstitial_ready := false
var rewarded_ready := false
var reward_pending := false
var reward_granted_this_ad := false
var pending_pack_id := ""

func _ready() -> void:
	_load_admob_secrets()
	if Engine.has_singleton(ANDROID_PLUGIN):
		plugin = Engine.get_singleton(ANDROID_PLUGIN)
		if plugin.has_signal("purchase_verified"):
			plugin.connect("purchase_verified", _on_purchase_verified)
		if plugin.has_signal("purchase_failed"):
			plugin.connect("purchase_failed", _on_purchase_failed)
		if plugin.has_signal("coin_purchase_verified"):
			plugin.connect("coin_purchase_verified", _on_coin_purchase_verified)
		if plugin.has_method("restore_purchases"):
			plugin.call("restore_purchases")
	if ads_allowed:
		_setup_admob()

func _load_admob_secrets() -> void:
	if not FileAccess.file_exists(SECRETS_PATH):
		return
	var file := FileAccess.open(SECRETS_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		banner_unit_id = str(parsed.get("ADMOB_BANNER_ID", "")).strip_edges()
		interstitial_unit_id = str(parsed.get("ADMOB_INTERSTITIAL_ID", "")).strip_edges()
		rewarded_unit_id = str(parsed.get("ADMOB_REWARDED_ID", "")).strip_edges()

func enable_ads() -> void:
	if ads_allowed:
		return
	ads_allowed = true
	_setup_admob()

func _mark_no_fill(reason: String) -> void:
	if not no_fill_this_launch:
		no_fill_this_launch = true
		push_warning("AdMob no-fill active: %s" % reason)
		hide_banner()
		no_fill_changed.emit(true)
	rewarded_ready = false
	rewarded_ready_changed.emit(false)

func _is_test_ad_id(ad_id: String) -> bool:
	return ad_id.begins_with(GOOGLE_TEST_PREFIX)

func _setup_admob() -> void:
	if OS.get_name() != "Android":
		return
	if banner_unit_id.is_empty() or interstitial_unit_id.is_empty() or rewarded_unit_id.is_empty():
		_mark_no_fill("missing production AdMob IDs in admob_secrets.json")
		return
	if _is_test_ad_id(banner_unit_id) or _is_test_ad_id(interstitial_unit_id) or _is_test_ad_id(rewarded_unit_id):
		_mark_no_fill("test AdMob IDs detected — blocking ads")
		return
	if not Engine.has_singleton("PoingGodotAdMob"):
		_mark_no_fill("PoingGodotAdMob singleton unavailable")
		return
	admob = Engine.get_singleton("PoingGodotAdMob")
	banner_plugin = Engine.get_singleton("PoingGodotAdMobAdView") if Engine.has_singleton("PoingGodotAdMobAdView") else null
	ad_size_plugin = Engine.get_singleton("PoingGodotAdMobAdSize") if Engine.has_singleton("PoingGodotAdMobAdSize") else null
	interstitial_plugin = Engine.get_singleton("PoingGodotAdMobInterstitialAd") if Engine.has_singleton("PoingGodotAdMobInterstitialAd") else null
	rewarded_plugin = Engine.get_singleton("PoingGodotAdMobRewardedAd") if Engine.has_singleton("PoingGodotAdMobRewardedAd") else null
	admob.call("initialize")
	if banner_plugin != null:
		banner_plugin.connect("on_ad_loaded", _on_banner_loaded)
		banner_plugin.connect("on_ad_failed_to_load", _on_banner_failed)
		if not no_fill_this_launch and not ads_removed:
			bottom_banner_uid = _load_banner_at(1)
			top_banner_uid = _load_banner_at(0)
	if interstitial_plugin != null:
		interstitial_plugin.connect("on_interstitial_ad_loaded", _on_interstitial_loaded)
		interstitial_plugin.connect("on_interstitial_ad_failed_to_load", _on_interstitial_failed)
		interstitial_plugin.connect("on_interstitial_ad_dismissed_full_screen_content", _on_interstitial_closed)
		interstitial_plugin.connect("on_interstitial_ad_failed_to_show_full_screen_content", _on_interstitial_show_failed)
		if not no_fill_this_launch and not ads_removed:
			_load_interstitial()
	if rewarded_plugin != null:
		rewarded_plugin.connect("on_rewarded_ad_loaded", _on_rewarded_loaded)
		rewarded_plugin.connect("on_rewarded_ad_failed_to_load", _on_rewarded_failed)
		rewarded_plugin.connect("on_rewarded_ad_user_earned_reward", _on_user_earned_reward)
		rewarded_plugin.connect("on_rewarded_ad_dismissed_full_screen_content", _on_rewarded_closed)
		rewarded_plugin.connect("on_rewarded_ad_failed_to_show_full_screen_content", _on_rewarded_show_failed)
		_load_rewarded()

func _ad_request() -> Dictionary:
	return {"mediation_extras": {}, "extras": {}, "google_request_agent": "TrafficMash-Godot"}

func _load_banner_at(ad_position: int) -> int:
	if banner_unit_id.is_empty():
		return -1
	var size := {"width": 320, "height": 50}
	if ad_size_plugin != null:
		size = ad_size_plugin.call("getCurrentOrientationAnchoredAdaptiveBannerAdSize", -1)
	var uid := int(banner_plugin.call("create", {"ad_unit_id": banner_unit_id, "ad_position": ad_position, "ad_size": size}))
	banner_plugin.call("load_ad", uid, _ad_request(), PackedStringArray())
	return uid

func show_menu_banners() -> void:
	gameplay_banner_active = false
	if gameplay_banner_timer != null:
		gameplay_banner_timer.stop()
	if no_fill_this_launch or ads_removed:
		hide_banner()
		return
	# Keep top bar (Settings & Coin count) unobstructed on menus; show bottom banner only
	top_banner_desired = false
	bottom_banner_desired = true
	_sync_banners()

func show_gameplay_banner() -> void:
	if no_fill_this_launch or ads_removed:
		hide_banner()
		return
	gameplay_banner_active = true
	top_banner_desired = true
	bottom_banner_desired = false
	_sync_banners()
	_ensure_gameplay_banner_timer()
	gameplay_banner_timer.start()

func show_banner() -> void:
	show_menu_banners()

func hide_banner() -> void:
	gameplay_banner_active = false
	if gameplay_banner_timer != null:
		gameplay_banner_timer.stop()
	top_banner_desired = false
	bottom_banner_desired = false
	_sync_banners()

func _ensure_gameplay_banner_timer() -> void:
	if gameplay_banner_timer != null:
		return
	gameplay_banner_timer = Timer.new()
	gameplay_banner_timer.wait_time = 5.0
	gameplay_banner_timer.one_shot = false
	gameplay_banner_timer.timeout.connect(_on_gameplay_banner_timer_timeout)
	add_child(gameplay_banner_timer)

func _on_gameplay_banner_timer_timeout() -> void:
	if not gameplay_banner_active or no_fill_this_launch:
		if gameplay_banner_timer != null:
			gameplay_banner_timer.stop()
		return
	top_banner_desired = not top_banner_desired
	bottom_banner_desired = false
	_sync_banners()

func _sync_banners() -> void:
	if banner_plugin == null:
		return
	if bottom_banner_uid >= 0:
		if bottom_banner_desired and not no_fill_this_launch and not ads_removed:
			banner_plugin.call("show", bottom_banner_uid)
		else:
			banner_plugin.call("hide", bottom_banner_uid)
	if top_banner_uid >= 0:
		if top_banner_desired and not no_fill_this_launch and not ads_removed:
			banner_plugin.call("show", top_banner_uid)
		else:
			banner_plugin.call("hide", top_banner_uid)

func _on_banner_loaded(uid: int) -> void:
	if uid == bottom_banner_uid or uid == top_banner_uid:
		_sync_banners()

func _on_banner_failed(uid: int, _error: Dictionary) -> void:
	if uid == bottom_banner_uid or uid == top_banner_uid:
		_mark_no_fill("banner failed to load")

func _load_interstitial() -> void:
	if interstitial_plugin == null or no_fill_this_launch or interstitial_unit_id.is_empty():
		return
	interstitial_ready = false
	interstitial_uid = int(interstitial_plugin.call("create"))
	interstitial_plugin.call("load", interstitial_unit_id, _ad_request(), PackedStringArray(), interstitial_uid)

func _on_interstitial_loaded(uid: int) -> void:
	if uid == interstitial_uid:
		interstitial_ready = true

func _on_interstitial_failed(uid: int, _error: Dictionary) -> void:
	if uid == interstitial_uid:
		interstitial_ready = false
		_mark_no_fill("interstitial failed to load")

func _on_interstitial_closed(uid: int) -> void:
	if uid == interstitial_uid:
		interstitial_plugin.call("destroy", uid)
		_load_interstitial()

func _on_interstitial_show_failed(uid: int, _error: Dictionary) -> void:
	_on_interstitial_closed(uid)

func _load_rewarded() -> void:
	if rewarded_plugin == null or rewarded_unit_id.is_empty():
		return
	rewarded_ready = false
	rewarded_ready_changed.emit(false)
	rewarded_uid = int(rewarded_plugin.call("create"))
	rewarded_plugin.call("load", rewarded_unit_id, _ad_request(), PackedStringArray(), rewarded_uid)

func _on_rewarded_loaded(uid: int) -> void:
	if uid == rewarded_uid:
		rewarded_ready = true
		rewarded_ready_changed.emit(true)

func _on_rewarded_failed(uid: int, _error: Dictionary) -> void:
	if uid == rewarded_uid:
		_mark_no_fill("rewarded ad failed to load")

func show_rewarded() -> bool:
	if no_fill_this_launch:
		reward_earned.emit(REWARD_COINS)
		rewarded_ad_closed.emit(true)
		return true
	if rewarded_plugin == null or not rewarded_ready:
		return false
	rewarded_ready = false
	rewarded_ready_changed.emit(false)
	reward_pending = true
	reward_granted_this_ad = false
	rewarded_plugin.call("show", rewarded_uid)
	return true

func _on_user_earned_reward(uid: int, _item: Dictionary) -> void:
	if uid == rewarded_uid and reward_pending:
		reward_pending = false
		reward_granted_this_ad = true
		reward_earned.emit(REWARD_COINS)

func _on_rewarded_closed(uid: int) -> void:
	if uid == rewarded_uid:
		reward_pending = false
		rewarded_ad_closed.emit(reward_granted_this_ad)
		reward_granted_this_ad = false
		if rewarded_plugin != null and not no_fill_this_launch:
			rewarded_plugin.call("destroy", uid)
			_load_rewarded()

func _on_rewarded_show_failed(uid: int, _error: Dictionary) -> void:
	_on_rewarded_closed(uid)

func purchase_available() -> bool:
	return plugin != null and (plugin.has_method("purchase_consumable") or plugin.has_method("purchase_coins"))

func coin_purchase_available() -> bool:
	return plugin != null and plugin.has_method("purchase_coins") and plugin.has_signal("coin_purchase_verified")

func request_coin_purchase() -> void:
	request_pack_purchase(COIN_PRODUCT_ID)

func request_coffee_purchase() -> void:
	if plugin != null and plugin.has_method("purchase_consumable"):
		plugin.call("purchase_consumable", COFFEE_PRODUCT_ID)
	elif plugin != null and plugin.has_method("purchase_coins"):
		plugin.call("purchase_coins", COFFEE_PRODUCT_ID)
	else:
		coffee_purchased.emit("Google Play Billing is unavailable in this build.")

func request_pack_purchase(product_id: String) -> void:
	pending_pack_id = product_id
	if not coin_purchase_available():
		coin_purchase_state_changed.emit("Store purchases are unavailable in this build.")
		return
	plugin.call("purchase_coins", product_id)

func _on_coin_purchase_verified(product_id: String) -> void:
	if product_id == COFFEE_PRODUCT_ID:
		coffee_purchased.emit("Thank you for buying the developer a coffee!")
		return
	if SHOP_PACKS.has(product_id):
		var pack: Dictionary = SHOP_PACKS[product_id]
		var c := int(pack.get("coins", 0))
		var h := int(pack.get("hints", 0))
		var helis := int(pack.get("helis", 0))
		if h > 0 or helis > 0:
			pack_purchase_verified.emit(c, h, helis)
		else:
			coin_purchase_verified.emit(c)
		coin_purchase_state_changed.emit("%d coins added!" % c)

func request_remove_ads() -> void:
	if ads_removed:
		purchase_state_changed.emit(true, "Ads are already removed.")
	elif plugin != null and plugin.has_method("purchase_remove_ads"):
		plugin.call("purchase_remove_ads", PRODUCT_ID)
	else:
		purchase_state_changed.emit(false, "Google Play Billing is unavailable in this build.")

func restore_purchases() -> void:
	if plugin != null and plugin.has_method("restore_purchases"):
		plugin.call("restore_purchases")
	else:
		purchase_state_changed.emit(ads_removed, "Store restore is unavailable in this build.")

func request_rate_app() -> void:
	if Engine.has_singleton("TrafficMashAppPlugin"):
		Engine.get_singleton("TrafficMashAppPlugin").call("request_in_app_review", PLAY_STORE_URL)
	elif plugin != null and plugin.has_method("request_in_app_review"):
		plugin.call("request_in_app_review")
	else:
		OS.shell_open(PLAY_STORE_URL)

func request_share_game() -> void:
	var share_text := "Try City Rescue Puzzle! Clear the traffic jam: %s" % PLAY_STORE_URL
	if Engine.has_singleton("TrafficMashAppPlugin"):
		Engine.get_singleton("TrafficMashAppPlugin").call("share_text", share_text)
	elif plugin != null and plugin.has_method("share_text"):
		plugin.call("share_text", share_text)
	else:
		DisplayServer.clipboard_set(share_text)

func check_in_app_update() -> void:
	if OS.get_name() != "Android":
		return
	if Engine.has_singleton("TrafficMashAppPlugin"):
		Engine.get_singleton("TrafficMashAppPlugin").call("check_in_app_update")
	elif plugin != null and plugin.has_method("check_in_app_update"):
		plugin.call("check_in_app_update")

func show_level_end_interstitial() -> bool:
	if no_fill_this_launch or ads_removed:
		return false
	if interstitial_plugin != null and interstitial_ready:
		interstitial_ready = false
		interstitial_plugin.call("show", interstitial_uid)
		completed_since_ad = 0
		return true
	return false

func on_level_completed() -> void:
	if no_fill_this_launch or ads_removed:
		return
	completed_since_ad += 1

func on_between_levels() -> void:
	if no_fill_this_launch or ads_removed:
		return
	if completed_since_ad < INTERSTITIAL_INTERVAL:
		return
	show_level_end_interstitial()

func _on_purchase_verified(product_id: String) -> void:
	if product_id == PRODUCT_ID:
		ads_removed = true
		completed_since_ad = 0
		hide_banner()
		purchase_state_changed.emit(true, "Ads removed. Thank you!")
		return
	if product_id == COFFEE_PRODUCT_ID:
		coffee_purchased.emit("Thank you for buying the developer a coffee!")

func _on_purchase_failed(message: String) -> void:
	purchase_state_changed.emit(ads_removed, message)
