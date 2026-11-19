extends Control

func _ready() -> void:
	_build_splash()
	var tween := create_tween()
	tween.tween_interval(1.35)
	tween.tween_callback(func(): get_tree().change_scene_to_file("res://scenes/gameplay/art_direction_board.tscn"))

func _build_splash() -> void:
	var background := ColorRect.new()
	background.color = DesignTokens.INK_DARK
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var glow := Panel.new()
	glow.position = Vector2(86, 365); glow.size = Vector2(548, 340)
	var glow_style := StyleBoxFlat.new(); glow_style.bg_color = Color("1d4770"); glow_style.corner_radius_top_left = 64; glow_style.corner_radius_top_right = 64; glow_style.corner_radius_bottom_left = 64; glow_style.corner_radius_bottom_right = 64
	glow.add_theme_stylebox_override("panel", glow_style); add_child(glow)
	var title := Label.new()
	title.text = "TRAFFIC\nMASH"; title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(80, 408); title.size = Vector2(560, 180)
	title.add_theme_color_override("font_color", Color.WHITE); title.add_theme_color_override("font_shadow_color", Color("07121e")); title.add_theme_constant_override("shadow_offset_x", 0); title.add_theme_constant_override("shadow_offset_y", 7); title.add_theme_font_size_override("font_size", 76)
	add_child(title)
	var caption := Label.new(); caption.text = "ORIGINAL CITY ESCAPE PUZZLE"; caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; caption.position = Vector2(70, 627); caption.size = Vector2(580, 40); caption.add_theme_color_override("font_color", DesignTokens.GOLD); caption.add_theme_font_size_override("font_size", 18); add_child(caption)
	var loading := ProgressBar.new(); loading.position = Vector2(160, 780); loading.size = Vector2(400, 18); loading.value = 100; loading.show_percentage = false; add_child(loading)
