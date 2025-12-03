# TutorialUI.gd - Tutorial overlay UI
extends CanvasLayer

var tutorial_manager: Node = null
var main_node: Node2D = null

# UI elements
var panel: PanelContainer
var title_label: Label
var instruction_label: Label
var continue_button: Button
var skip_button: Button
var progress_bar: ProgressBar

# Animation
var tween: Tween

func _ready() -> void:
	setup_ui()
	visible = false

func setup(main: Node2D, manager: Node) -> void:
	main_node = main
	tutorial_manager = manager

	if tutorial_manager:
		tutorial_manager.tutorial_started.connect(_on_tutorial_started)
		tutorial_manager.step_started.connect(_on_step_started)
		tutorial_manager.step_completed.connect(_on_step_completed)
		tutorial_manager.tutorial_completed.connect(_on_tutorial_completed)

func setup_ui() -> void:
	"""Create tutorial UI elements"""
	# Semi-transparent overlay at top
	panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	panel.custom_minimum_size = Vector2(0, 180)
	add_child(panel)

	# Style the panel
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.85)
	style.corner_radius_bottom_left = 20
	style.corner_radius_bottom_right = 20
	style.border_width_bottom = 3
	style.border_color = Color(1.0, 0.84, 0, 0.5)
	panel.add_theme_stylebox_override("panel", style)

	# Content container
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	# Margin
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 15)
	margin.add_theme_constant_override("margin_bottom", 15)
	vbox.add_child(margin)

	var inner_vbox = VBoxContainer.new()
	inner_vbox.add_theme_constant_override("separation", 8)
	margin.add_child(inner_vbox)

	# Title
	title_label = Label.new()
	title_label.text = "Tutorial"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 24)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0))
	inner_vbox.add_child(title_label)

	# Instructions
	instruction_label = Label.new()
	instruction_label.text = "Instructions will appear here"
	instruction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instruction_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	instruction_label.add_theme_font_size_override("font_size", 16)
	inner_vbox.add_child(instruction_label)

	# Progress bar
	progress_bar = ProgressBar.new()
	progress_bar.custom_minimum_size = Vector2(200, 10)
	progress_bar.show_percentage = false
	progress_bar.min_value = 0
	progress_bar.max_value = 100
	inner_vbox.add_child(progress_bar)

	# Button container
	var button_container = HBoxContainer.new()
	button_container.alignment = BoxContainer.ALIGNMENT_CENTER
	button_container.add_theme_constant_override("separation", 20)
	inner_vbox.add_child(button_container)

	# Continue button
	continue_button = Button.new()
	continue_button.text = "Continue"
	continue_button.custom_minimum_size = Vector2(120, 40)
	continue_button.visible = false
	continue_button.pressed.connect(_on_continue_pressed)
	button_container.add_child(continue_button)

	# Skip button
	skip_button = Button.new()
	skip_button.text = "Skip Tutorial"
	skip_button.custom_minimum_size = Vector2(120, 40)
	skip_button.pressed.connect(_on_skip_pressed)
	button_container.add_child(skip_button)

	# Style buttons
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.2, 0.4, 0.8)
	btn_style.corner_radius_top_left = 8
	btn_style.corner_radius_top_right = 8
	btn_style.corner_radius_bottom_left = 8
	btn_style.corner_radius_bottom_right = 8
	continue_button.add_theme_stylebox_override("normal", btn_style)

	var skip_style = btn_style.duplicate()
	skip_style.bg_color = Color(0.4, 0.4, 0.4)
	skip_button.add_theme_stylebox_override("normal", skip_style)

func _on_tutorial_started() -> void:
	visible = true
	animate_in()

func _on_step_started(step_index: int, title: String, instruction: String) -> void:
	title_label.text = title
	instruction_label.text = instruction

	# Update progress
	if tutorial_manager:
		var total_steps = tutorial_manager.steps.size()
		progress_bar.value = (float(step_index) / total_steps) * 100

	# Show continue button for tap_continue requirements
	var step = tutorial_manager.get_current_step()
	continue_button.visible = step.get("requirement", "") == "tap_continue"

	# Animate text change
	pulse_panel()

func _on_step_completed(step_index: int) -> void:
	continue_button.visible = false

func _on_tutorial_completed() -> void:
	animate_out()

func _on_continue_pressed() -> void:
	if tutorial_manager:
		tutorial_manager.check_action("tap")
		AudioManager.play_ui_sound("button_press")

func _on_skip_pressed() -> void:
	if tutorial_manager:
		tutorial_manager.skip_tutorial()
		AudioManager.play_ui_sound("button_press")
	animate_out()

func animate_in() -> void:
	panel.modulate.a = 0
	panel.position.y = -200
	tween = create_tween()
	tween.parallel().tween_property(panel, "modulate:a", 1.0, 0.3)
	tween.parallel().tween_property(panel, "position:y", 0, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

func animate_out() -> void:
	tween = create_tween()
	tween.parallel().tween_property(panel, "modulate:a", 0.0, 0.3)
	tween.parallel().tween_property(panel, "position:y", -200, 0.3).set_ease(Tween.EASE_IN)
	tween.tween_callback(func(): visible = false)

func pulse_panel() -> void:
	"""Quick pulse animation when content changes"""
	if tween and tween.is_running():
		return
	tween = create_tween()
	tween.tween_property(panel, "scale", Vector2(1.02, 1.02), 0.1)
	tween.tween_property(panel, "scale", Vector2.ONE, 0.1)
