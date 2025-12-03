# MainMenu.gd - Main Menu Interface
extends Control

# UI References
var play_button: Button
var tutorial_button: Button
var settings_button: Button
var stats_button: Button
var title_label: Label
var version_label: Label

# Animation
var tween: Tween

func _ready() -> void:
	setup_ui()
	animate_entrance()
	AudioManager.play_ui_sound("button_press")

func setup_ui() -> void:
	"""Create and configure all UI elements"""
	# Background
	var bg = ColorRect.new()
	bg.color = Color(0.1, 0.15, 0.2)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Create decorative court background
	var court_bg = create_court_background()
	add_child(court_bg)

	# Container for menu items
	var container = VBoxContainer.new()
	container.set_anchors_preset(Control.PRESET_CENTER)
	container.custom_minimum_size = Vector2(300, 500)
	container.add_theme_constant_override("separation", 20)
	add_child(container)

	# Position container
	container.position = Vector2(
		get_viewport().size.x / 2 - 150,
		get_viewport().size.y / 2 - 250
	)

	# Title
	title_label = Label.new()
	title_label.text = "PICKLEBALL\nDOUBLES"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 48)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0))
	container.add_child(title_label)

	# Subtitle
	var subtitle = Label.new()
	subtitle.text = "2v2 Mobile Experience"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 18)
	subtitle.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	container.add_child(subtitle)

	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 40)
	container.add_child(spacer)

	# Play Button
	play_button = create_menu_button("PLAY", Color(0.18, 0.49, 0.20))
	play_button.pressed.connect(_on_play_pressed)
	container.add_child(play_button)

	# Tutorial Button
	tutorial_button = create_menu_button("TUTORIAL", Color(0.2, 0.4, 0.8))
	tutorial_button.pressed.connect(_on_tutorial_pressed)
	container.add_child(tutorial_button)

	# Settings Button
	settings_button = create_menu_button("SETTINGS", Color(0.4, 0.4, 0.4))
	settings_button.pressed.connect(_on_settings_pressed)
	container.add_child(settings_button)

	# Stats Button
	stats_button = create_menu_button("STATS", Color(0.5, 0.3, 0.6))
	stats_button.pressed.connect(_on_stats_pressed)
	container.add_child(stats_button)

	# Version label at bottom
	version_label = Label.new()
	version_label.text = "v1.0.0 MVP"
	version_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	version_label.add_theme_font_size_override("font_size", 12)
	version_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	version_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	version_label.position.y = -30
	add_child(version_label)

	# Check if tutorial should be highlighted
	if not GameManager.has_completed_tutorial():
		highlight_tutorial_button()

func create_menu_button(text: String, color: Color) -> Button:
	"""Create a styled menu button"""
	var button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(280, 60)
	button.add_theme_font_size_override("font_size", 24)

	# Create style for normal state
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = color
	style_normal.corner_radius_top_left = 10
	style_normal.corner_radius_top_right = 10
	style_normal.corner_radius_bottom_left = 10
	style_normal.corner_radius_bottom_right = 10
	style_normal.border_width_left = 2
	style_normal.border_width_right = 2
	style_normal.border_width_top = 2
	style_normal.border_width_bottom = 2
	style_normal.border_color = color.lightened(0.3)
	button.add_theme_stylebox_override("normal", style_normal)

	# Hover style
	var style_hover = style_normal.duplicate()
	style_hover.bg_color = color.lightened(0.2)
	button.add_theme_stylebox_override("hover", style_hover)

	# Pressed style
	var style_pressed = style_normal.duplicate()
	style_pressed.bg_color = color.darkened(0.2)
	button.add_theme_stylebox_override("pressed", style_pressed)

	return button

func create_court_background() -> Control:
	"""Create a decorative court pattern"""
	var court = Control.new()
	court.set_anchors_preset(Control.PRESET_FULL_RECT)

	# Draw court lines using custom drawing
	var canvas = ColorRect.new()
	canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.color = Color(0, 0, 0, 0)  # Transparent
	court.add_child(canvas)

	# Add some court-like decorative elements
	var net_line = ColorRect.new()
	net_line.color = Color(1, 1, 1, 0.1)
	net_line.size = Vector2(get_viewport().size.x, 4)
	net_line.position = Vector2(0, get_viewport().size.y / 2)
	court.add_child(net_line)

	# Kitchen zone indicators
	var kitchen_top = ColorRect.new()
	kitchen_top.color = Color(1.0, 0.84, 0, 0.05)
	kitchen_top.size = Vector2(get_viewport().size.x, 100)
	kitchen_top.position = Vector2(0, get_viewport().size.y / 2 - 100)
	court.add_child(kitchen_top)

	var kitchen_bottom = ColorRect.new()
	kitchen_bottom.color = Color(1.0, 0.84, 0, 0.05)
	kitchen_bottom.size = Vector2(get_viewport().size.x, 100)
	kitchen_bottom.position = Vector2(0, get_viewport().size.y / 2)
	court.add_child(kitchen_bottom)

	return court

func highlight_tutorial_button() -> void:
	"""Highlight tutorial button for new players"""
	var pulse_tween = create_tween()
	pulse_tween.set_loops()
	pulse_tween.tween_property(tutorial_button, "modulate", Color(1.3, 1.3, 1.0), 0.5)
	pulse_tween.tween_property(tutorial_button, "modulate", Color.WHITE, 0.5)

func animate_entrance() -> void:
	"""Animate menu entrance"""
	# Fade in
	modulate.a = 0
	tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.5)

	# Title bounce
	if title_label:
		title_label.scale = Vector2(0.5, 0.5)
		tween.parallel().tween_property(title_label, "scale", Vector2.ONE, 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

func _on_play_pressed() -> void:
	"""Start a new game"""
	AudioManager.play_ui_sound("button_press")

	# Fade out and change scene
	var out_tween = create_tween()
	out_tween.tween_property(self, "modulate:a", 0.0, 0.3)
	out_tween.tween_callback(func():
		get_tree().change_scene_to_file("res://scenes/main/Main.tscn")
	)

func _on_tutorial_pressed() -> void:
	"""Start tutorial mode"""
	AudioManager.play_ui_sound("button_press")

	GameManager.start_tutorial_mode()

	var out_tween = create_tween()
	out_tween.tween_property(self, "modulate:a", 0.0, 0.3)
	out_tween.tween_callback(func():
		get_tree().change_scene_to_file("res://scenes/main/Main.tscn")
	)

func _on_settings_pressed() -> void:
	"""Open settings panel"""
	AudioManager.play_ui_sound("button_press")
	show_settings_panel()

func _on_stats_pressed() -> void:
	"""Show statistics"""
	AudioManager.play_ui_sound("button_press")
	show_stats_panel()

func show_settings_panel() -> void:
	"""Display settings panel"""
	var panel = create_popup_panel("SETTINGS")

	var container = panel.get_node("Container")

	# Sound volume
	var sound_label = Label.new()
	sound_label.text = "Sound Effects"
	sound_label.add_theme_font_size_override("font_size", 18)
	container.add_child(sound_label)

	var sound_slider = HSlider.new()
	sound_slider.min_value = 0
	sound_slider.max_value = 100
	sound_slider.value = GameManager.get_setting("sfx_volume", 100)
	sound_slider.custom_minimum_size = Vector2(250, 30)
	sound_slider.value_changed.connect(func(val): GameManager.set_setting("sfx_volume", val))
	container.add_child(sound_slider)

	# Music volume
	var music_label = Label.new()
	music_label.text = "Music"
	music_label.add_theme_font_size_override("font_size", 18)
	container.add_child(music_label)

	var music_slider = HSlider.new()
	music_slider.min_value = 0
	music_slider.max_value = 100
	music_slider.value = GameManager.get_setting("music_volume", 80)
	music_slider.custom_minimum_size = Vector2(250, 30)
	music_slider.value_changed.connect(func(val): GameManager.set_setting("music_volume", val))
	container.add_child(music_slider)

	# Difficulty
	var diff_label = Label.new()
	diff_label.text = "AI Difficulty"
	diff_label.add_theme_font_size_override("font_size", 18)
	container.add_child(diff_label)

	var diff_options = OptionButton.new()
	diff_options.add_item("Easy", 0)
	diff_options.add_item("Normal", 1)
	diff_options.add_item("Hard", 2)
	diff_options.selected = GameManager.get_setting("difficulty", 1)
	diff_options.item_selected.connect(func(idx): GameManager.set_setting("difficulty", idx))
	container.add_child(diff_options)

	# Close button
	var close_btn = create_menu_button("CLOSE", Color(0.5, 0.2, 0.2))
	close_btn.pressed.connect(func(): panel.queue_free())
	container.add_child(close_btn)

	add_child(panel)

func show_stats_panel() -> void:
	"""Display statistics panel"""
	var panel = create_popup_panel("STATISTICS")

	var container = panel.get_node("Container")

	var stats = GameManager.get_stats()

	# Games played
	add_stat_row(container, "Games Played", str(stats.get("games_played", 0)))
	add_stat_row(container, "Games Won", str(stats.get("games_won", 0)))
	add_stat_row(container, "Win Rate", "%.1f%%" % (stats.get("win_rate", 0.0) * 100))
	add_stat_row(container, "Total Points", str(stats.get("total_points", 0)))
	add_stat_row(container, "Longest Rally", str(stats.get("longest_rally", 0)))
	add_stat_row(container, "Kitchen Masters", str(stats.get("mastery_activations", 0)))

	# Close button
	var close_btn = create_menu_button("CLOSE", Color(0.5, 0.2, 0.2))
	close_btn.pressed.connect(func(): panel.queue_free())
	container.add_child(close_btn)

	add_child(panel)

func add_stat_row(container: Control, label_text: String, value_text: String) -> void:
	"""Add a statistics row"""
	var row = HBoxContainer.new()
	row.custom_minimum_size = Vector2(280, 30)

	var label = Label.new()
	label.text = label_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 16)
	row.add_child(label)

	var value = Label.new()
	value.text = value_text
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.add_theme_font_size_override("font_size", 16)
	value.add_theme_color_override("font_color", Color(1.0, 0.84, 0))
	row.add_child(value)

	container.add_child(row)

func create_popup_panel(title_text: String) -> Control:
	"""Create a popup panel"""
	var overlay = Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)

	# Dim background
	var dim = ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.7)
	overlay.add_child(dim)

	# Panel
	var panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(320, 400)
	panel.position = Vector2(-160, -200)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.2)
	style.corner_radius_top_left = 15
	style.corner_radius_top_right = 15
	style.corner_radius_bottom_left = 15
	style.corner_radius_bottom_right = 15
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(1.0, 0.84, 0, 0.5)
	panel.add_theme_stylebox_override("panel", style)
	overlay.add_child(panel)

	# Content container
	var container = VBoxContainer.new()
	container.name = "Container"
	container.add_theme_constant_override("separation", 15)
	panel.add_child(container)

	# Title
	var title = Label.new()
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(1.0, 0.84, 0))
	container.add_child(title)

	# Separator
	var sep = HSeparator.new()
	container.add_child(sep)

	return overlay

func _input(event: InputEvent) -> void:
	# Handle back button on Android
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()
