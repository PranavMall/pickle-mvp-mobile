# UISetup.gd - Attach this to the UI CanvasLayer node
extends CanvasLayer

@onready var main = get_node("/root/Main")

func _ready() -> void:
	setup_complete_ui()

func setup_complete_ui() -> void:
	# Create HUD container
	var hud = Control.new()
	hud.name = "HUD"
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(hud)
	
	# Create Top Panel
	create_top_panel(hud)
	
	# Create Kitchen Button
	create_kitchen_button(hud)
	
	# Create Mastery Button
	create_mastery_button(hud)
	
	# Create Instructions Label
	create_instructions(hud)
	
	# Create Power Indicator
	create_power_indicator(hud)
	
	# Create Debug Info
	create_debug_info(hud)

func create_top_panel(parent: Control) -> void:
	# Container panel
	var top_panel = Panel.new()
	top_panel.name = "TopPanel"
	top_panel.position = Vector2(10, 10)
	top_panel.size = Vector2(410, 40)
	top_panel.modulate = Color(0, 0, 0, 0.6)
	
	# Add StyleBox for rounded corners
	var panel_style = StyleBoxFlat.new()
	panel_style.set_corner_radius_all(20)
	panel_style.bg_color = Color(0, 0, 0, 0.6)
	top_panel.add_theme_stylebox_override("panel", panel_style)
	parent.add_child(top_panel)
	
	# Score Label
	var score_label = Label.new()
	score_label.name = "ScoreLabel"
	score_label.text = "0-0-2"
	score_label.position = Vector2(15, 10)
	score_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0))  # Gold
	score_label.add_theme_font_size_override("font_size", 16)
	top_panel.add_child(score_label)
	
	# Server Indicator
	var server_label = Label.new()
	server_label.name = "ServerIndicator"
	server_label.text = "You Serve"
	server_label.position = Vector2(150, 10)
	score_label.add_theme_color_override("font_color", Color(0.3, 0.69, 0.31))  # Green
	score_label.add_theme_font_size_override("font_size", 12)
	top_panel.add_child(server_label)
	
	# Rally Counter
	var rally_label = Label.new()
	rally_label.name = "RallyCounter"
	rally_label.text = "R: 0"
	rally_label.position = Vector2(250, 10)
	rally_label.add_theme_color_override("font_color", Color(0.67, 0.67, 0.67))
	rally_label.add_theme_font_size_override("font_size", 11)
	top_panel.add_child(rally_label)
	
	# Kitchen Violations
	var violations_label = Label.new()
	violations_label.name = "ViolationsLabel"
	violations_label.text = "KV: 0"
	violations_label.position = Vector2(320, 10)
	violations_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0))  # Orange
	violations_label.add_theme_font_size_override("font_size", 10)
	top_panel.add_child(violations_label)

func create_kitchen_button(parent: Control) -> void:
	# Kitchen Button Container
	var kitchen_button = Button.new()
	kitchen_button.name = "KitchenButton"
	kitchen_button.position = Vector2(345, 750)
	kitchen_button.size = Vector2(70, 70)
	kitchen_button.text = "K"
	
	# Style for the button
	var button_style = StyleBoxFlat.new()
	button_style.set_corner_radius_all(12)
	button_style.bg_color = Color(0.4, 0.4, 0.4)  # #666666
	button_style.border_color = Color.BLACK
	button_style.set_border_width_all(3)
	kitchen_button.add_theme_stylebox_override("normal", button_style)
	kitchen_button.add_theme_stylebox_override("hover", button_style)
	kitchen_button.add_theme_stylebox_override("pressed", button_style)
	kitchen_button.add_theme_font_size_override("font_size", 24)
	kitchen_button.add_theme_color_override("font_color", Color.WHITE)
	parent.add_child(kitchen_button)
	
	# Kitchen Timer Label
	var kitchen_timer = Label.new()
	kitchen_timer.name = "KitchenTimer"
	kitchen_timer.text = ""
	kitchen_timer.position = Vector2(0, 50)
	kitchen_timer.size = Vector2(70, 20)
	kitchen_timer.add_theme_font_size_override("font_size", 10)
	kitchen_timer.add_theme_color_override("font_color", Color.WHITE)
	kitchen_timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kitchen_button.add_child(kitchen_timer)
	
	# Connect button press
	kitchen_button.pressed.connect(_on_kitchen_button_pressed)

func create_mastery_button(parent: Control) -> void:
	# Mastery Button Container
	var mastery_button = Button.new()
	mastery_button.name = "MasteryButton"
	mastery_button.position = Vector2(15, 750)
	mastery_button.size = Vector2(70, 70)
	mastery_button.text = "⚡"
	
	# Circular style
	var button_style = StyleBoxFlat.new()
	button_style.set_corner_radius_all(35)  # Half of 70 for circle
	button_style.bg_color = Color(0.2, 0.2, 0.2)  # #333333
	button_style.border_color = Color(1.0, 0.84, 0)  # Gold
	button_style.set_border_width_all(3)
	mastery_button.add_theme_stylebox_override("normal", button_style)
	mastery_button.add_theme_stylebox_override("hover", button_style)
	mastery_button.add_theme_stylebox_override("pressed", button_style)
	mastery_button.add_theme_font_size_override("font_size", 24)
	mastery_button.add_theme_color_override("font_color", Color.WHITE)
	parent.add_child(mastery_button)
	
	# Fill Bar (Progress Bar)
	var fill_bar = ProgressBar.new()
	fill_bar.name = "FillBar"
	fill_bar.position = Vector2(5, 45)
	fill_bar.size = Vector2(60, 8)
	fill_bar.value = 0
	fill_bar.show_percentage = false
	
	# Style the progress bar
	var fill_style = StyleBoxFlat.new()
	fill_style.bg_color = Color(0.3, 0.69, 0.31)  # Green when filling
	fill_bar.add_theme_stylebox_override("fill", fill_style)
	mastery_button.add_child(fill_bar)
	
	# Percent Label
	var percent_label = Label.new()
	percent_label.name = "PercentLabel"
	percent_label.text = "0%"
	percent_label.position = Vector2(0, 25)
	percent_label.size = Vector2(70, 20)
	percent_label.add_theme_font_size_override("font_size", 14)
	percent_label.add_theme_color_override("font_color", Color.WHITE)
	percent_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mastery_button.add_child(percent_label)
	
	# Connect button press
	mastery_button.pressed.connect(_on_mastery_button_pressed)

func create_instructions(parent: Control) -> void:
	var instructions = Label.new()
	instructions.name = "Instructions"
	instructions.text = "Waiting to start..."
	instructions.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	instructions.position = Vector2(-100, -80)  # Offset from bottom center
	instructions.size = Vector2(200, 50)
	instructions.add_theme_font_size_override("font_size", 13)
	instructions.add_theme_color_override("font_color", Color.WHITE)
	instructions.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instructions.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	# Background style
	var bg_style = StyleBoxFlat.new()
	bg_style.set_corner_radius_all(15)
	bg_style.bg_color = Color(0, 0, 0, 0.7)
	instructions.add_theme_stylebox_override("normal", bg_style)
	parent.add_child(instructions)

func create_power_indicator(parent: Control) -> void:
	# Power Indicator Container
	var power_container = Panel.new()
	power_container.name = "PowerIndicator"
	power_container.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	power_container.position = Vector2(-90, -130)  # Offset from bottom center
	power_container.size = Vector2(180, 20)
	power_container.visible = false  # Hidden by default
	
	# Style
	var container_style = StyleBoxFlat.new()
	container_style.set_corner_radius_all(12)
	container_style.bg_color = Color(0, 0, 0, 0.6)
	container_style.border_color = Color.WHITE
	container_style.set_border_width_all(2)
	power_container.add_theme_stylebox_override("panel", container_style)
	parent.add_child(power_container)
	
	# Power Bar
	var power_bar = ProgressBar.new()
	power_bar.name = "PowerBar"
	power_bar.position = Vector2(2, 2)
	power_bar.size = Vector2(176, 16)
	power_bar.value = 0
	power_bar.show_percentage = false
	
	# Gradient style for power bar
	var bar_style = StyleBoxFlat.new()
	bar_style.set_corner_radius_all(10)
	bar_style.bg_color = Color(0.3, 0.69, 0.31)  # Will be updated dynamically
	power_bar.add_theme_stylebox_override("fill", bar_style)
	power_container.add_child(power_bar)

func create_debug_info(parent: Control) -> void:
	var debug_label = Label.new()
	debug_label.name = "DebugInfo"
	debug_label.text = "S:0 H:0 B:0\nK:OUT E:✓ M:0 V:0\nD:0"
	debug_label.position = Vector2(350, 50)
	debug_label.size = Vector2(70, 60)
	debug_label.add_theme_font_size_override("font_size", 9)
	debug_label.add_theme_color_override("font_color", Color.WHITE)
	
	# Background for visibility
	var bg_style = StyleBoxFlat.new()
	bg_style.set_corner_radius_all(4)
	bg_style.bg_color = Color(0, 0, 0, 0.5)
	debug_label.add_theme_stylebox_override("normal", bg_style)
	parent.add_child(debug_label)

func _on_kitchen_button_pressed() -> void:
	print("Kitchen button pressed!")
	if main:
		var player = main.get_node_or_null("Player")
		if not player:
			return
		
		match main.game_state.kitchen_state:
			main.KitchenState.AVAILABLE:
				player.enter_kitchen()
				update_kitchen_button("ACTIVE")
			main.KitchenState.ACTIVE, main.KitchenState.MUST_EXIT, main.KitchenState.WARNING:
				player.exit_kitchen()
				update_kitchen_button("DISABLED")

func _on_mastery_button_pressed() -> void:
	print("Mastery button pressed!")
	# This will be connected to the mastery system
	if main:
		# Handle mastery activation
		pass

# Update functions to be called from Main
func update_score(player_score: int, opponent_score: int, server_number: int) -> void:
	var score_label = get_node_or_null("HUD/TopPanel/ScoreLabel")
	if score_label:
		score_label.text = "%d-%d-%d" % [player_score, opponent_score, server_number]

func update_kitchen_button(state: String, timer: float = 0.0) -> void:
	var button = get_node_or_null("HUD/KitchenButton")
	var timer_label = get_node_or_null("HUD/KitchenButton/KitchenTimer")
	
	if not button:
		return
	
	# Update button appearance based on state
	var button_style = button.get_theme_stylebox("normal") as StyleBoxFlat
	
	match state:
		"AVAILABLE":
			button_style.bg_color = Color(1.0, 0.84, 0)  # Gold
			button.text = "→K"
			if timer > 0:
				timer_label.text = "%.1f" % timer
		"ACTIVE":
			button_style.bg_color = Color(0.3, 0.69, 0.31)  # Green
			button.text = "IN"
			timer_label.text = ""
		"MUST_EXIT":
			button_style.bg_color = Color(1.0, 0.6, 0)  # Orange
			button.text = "↑!"
			if timer > 0:
				timer_label.text = "%.1f" % timer
		"WARNING":
			button_style.bg_color = Color(0.96, 0.26, 0.21)  # Red
			button.text = "!!"
			timer_label.text = ""
		"COOLDOWN":
			button_style.bg_color = Color(0.6, 0.6, 0.6)  # Gray
			button.text = "..."
			if timer > 0:
				timer_label.text = "%.1f" % timer
		_:  # DISABLED
			button_style.bg_color = Color(0.4, 0.4, 0.4)  # Dark gray
			button.text = "K"
			timer_label.text = ""

func update_mastery_fill(percent: float) -> void:
	var fill_bar = get_node_or_null("HUD/MasteryButton/FillBar")
	var percent_label = get_node_or_null("HUD/MasteryButton/PercentLabel")
	
	if fill_bar:
		fill_bar.value = percent
	
	if percent_label:
		if percent >= 100:
			percent_label.text = "READY!"
		else:
			percent_label.text = "%d%%" % int(percent)

func show_power_indicator() -> void:
	var indicator = get_node_or_null("HUD/PowerIndicator")
	if indicator:
		indicator.visible = true

func hide_power_indicator() -> void:
	var indicator = get_node_or_null("HUD/PowerIndicator")
	if indicator:
		indicator.visible = false

func update_power_bar(power: float) -> void:
	var power_bar = get_node_or_null("HUD/PowerIndicator/PowerBar")
	if power_bar:
		power_bar.value = power * 100
