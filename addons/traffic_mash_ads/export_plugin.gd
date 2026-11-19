@tool
extends EditorExportPlugin

const LIB_PATH := "res://addons/traffic_mash_ads/android/libs"
const SECRETS_PATH := "res://admob_secrets.json"

func _get_name() -> String:
	return "TrafficMashAdMobAndroid"

func _supports_platform(platform: EditorExportPlatform) -> bool:
	return platform is EditorExportPlatformAndroid

func _get_android_libraries(_platform: EditorExportPlatform, debug: bool) -> PackedStringArray:
	var variant := "debug" if debug else "release"
	return PackedStringArray([
		"%s/poing-godot-admob-ads-%s.aar" % [LIB_PATH, variant],
		"%s/poing-godot-admob-core-%s.aar" % [LIB_PATH, variant]
	])

func _get_android_dependencies(_platform: EditorExportPlatform, _debug: bool) -> PackedStringArray:
	return PackedStringArray([
		"com.google.android.gms:play-services-ads:24.9.0",
		"com.google.android.play:app-update:2.1.0",
		"com.google.android.play:review:2.0.1",
		"com.android.billingclient:billing:8.0.0"
	])

func _read_admob_app_id() -> String:
	if not FileAccess.file_exists(SECRETS_PATH):
		push_error("Missing admob_secrets.json; ADMOB_APP_ID is required for Android export.")
		return ""
	var file := FileAccess.open(SECRETS_PATH, FileAccess.READ)
	if file == null:
		return ""
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		return str(parsed.get("ADMOB_APP_ID", "")).strip_edges()
	return ""

func _get_android_manifest_application_element_contents(_platform: EditorExportPlatform, _debug: bool) -> String:
	var app_id := _read_admob_app_id()
	if app_id.is_empty():
		return ""
	return '<meta-data android:name="com.google.android.gms.ads.APPLICATION_ID" android:value="%s" />' % app_id
