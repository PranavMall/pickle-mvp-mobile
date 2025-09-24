# UISetup.gd - Fixed with proper button types
extends CanvasLayer

@onready var main = get_node("/root/Main")

func _ready() -> void:
	setup_complete_ui()

func setup_complete_ui() -> void:
	# Get existing HUD from scene (it already exists)
	var hud = get_node_or_null("HUD")
	if not hud:
		print("ERROR: HUD node not found in UI!")
		return
	
	# Setup components that already exist in scene
	setup_top_panel()
	setup_kitchen_button()
	setup_mastery_button()
	setup_instructions()
	setup_power_indicator()

func setup_top_panel() -> void:
	var top_panel = get_node_or_null("HUD/TopPanel")
	if not top_panel:
		return
	
	# Style the existing panel
	var panel_style = StyleBoxFlat.new()
	panel_style.set_corner_radius_all(20)
	panel_style.bg_color = Color(0, 0, 0, 0.6)
	top_panel.add_theme_stylebox_override("panel", panel_style)
	
	# Setup existing labels
	var score_label = get_node_or_null("HUD/TopPanel/ScoreLabel")
	if score_label:
		score_label.text = "0-0-2"
		score_label.position = Vector2(15, 10)
		score_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0))
		score_label.add_theme_font_size_override("font_size", 16)
	
	var server_label = get_node_or_null("HUD/TopPanel/ServerIndicator")
	if server_label:
		server_label.text = "You Serve"
		server_label.position = Vector2(150, 10)
		server_label.add_theme_color_override("font_color", Color(0.3, 0.69, 0.31))
		server_label.add_theme_font_size_override("font_size", 12)
	
	var rally_label = get_node_or_null("HUD/TopPanel/RallyCounter")
	if rally_label:
		rally_label.text = "R: 0"
		rally_label.position = Vector2(250, 10)
		rally_label.add_theme_color_override("font_color", Color(0.67, 0.67, 0.67))
		rally_label.add_theme_font_size_override("font_size", 11)

func setup_kitchen_button() -> void:
	var kitchen_button = get_node_or_null("HUD/KitchenButton")
	if not kitchen_button:
		return
	
	# The scene has TextureButton, but we can use it as a button
	kitchen_button.position = Vector2(345, 750)
	kitchen_button.size = Vector2(70, 70)
	
	# Create a label child for the text since TextureButton doesn't have text property
	var existing_label = kitchen_button.get_node_or_null("KitchenText")
	if not existing_label:
		var kitchen_text = Label.new()
		kitchen_text.name = "KitchenText"
		kitchen_text.text = "K"
		kitchen_text.size = Vector2(70, 50)
		kitchen_text.position = Vector2(0, 10)
		kitchen_text.add_theme_font_size_override("font_size", 24)
		kitchen_text.add_theme_color_override("font_color", Color.WHITE)
		kitchen_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		kitchen_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		kitchen_button.add_child(kitchen_text)
	
	# Style the button
	var button_style = StyleBoxFlat.new()
	button_style.set_corner_radius_all(12)
	button_style.bg_color = Color(0.4, 0.4, 0.4)
	button_style.border_color = Color.BLACK
	button_style.set_border_width_all(3)
	kitchen_button.add_theme_stylebox_override("normal", button_style)
	kitchen_button.add_theme_stylebox_override("hover", button_style)
	kitchen_button.add_theme_stylebox_override("pressed", button_style)
	
	# Kitchen Timer Label
	var kitchen_timer = get_node_or_null("HUD/KitchenButton/KitchenTimer")
	if kitchen_timer:
		kitchen_timer.text = ""
		kitchen_timer.position = Vector2(0, 50)
		kitchen_timer.size = Vector2(70, 20)
		kitchen_timer.add_theme_font_size_override("font_size", 10)
		kitchen_timer.add_theme_color_override("font_color", Color.WHITE)
		kitchen_timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	# Connect button press
	if not kitchen_button.pressed.is_connected(_on_kitchen_button_pressed):
		kitchen_button.pressed.connect(_on_kitchen_button_pressed)

func setup_mastery_button() -> void:
	var mastery_button = get_node_or_null("HUD/MasteryButton")
	if not mastery_button:
		return
	
	mastery_button.position = Vector2(15, 750)
	mastery_button.size = Vector2(70, 70)
	
	# Create a label for the icon
	var existing_label = mastery_button.get_node_or_null("MasteryIcon")
	if not existing_label:
		var mastery_icon = Label.new()
		mastery_icon.name = "MasteryIcon"
		mastery_icon.text = "⚡"
		mastery_icon.size = Vector2(70, 35)
		mastery_icon.position = Vector2(0, 5)
		mastery_icon.add_theme_font_size_override("font_size", 24)
		mastery_icon.add_theme_color_override("font_color", Color.WHITE)
		mastery_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mastery_icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		mastery_button.add_child(mastery_icon)
	
	# Circular style
	var button_style = StyleBoxFlat.new()
	button_style.set_corner_radius_all(35)
	button_style.bg_color = Color(0.2, 0.2, 0.2)
	button_style.border_color = Color(1.0, 0.84, 0)
	button_style.set_border_width_all(3)
	mastery_button.add_theme_stylebox_override("normal", button_style)
	mastery_button.add_theme_stylebox_override("hover", button_style)
	mastery_button.add_theme_stylebox_override("pressed", button_style)
	
	# Fill Bar
	var fill_bar = get_node_or_null("HUD/MasteryButton/FillBar")
	if fill_bar:
		fill_bar.position = Vector2(5, 45)
		fill_bar.size = Vector2(60, 8)
		fill_bar.value = 0
		fill_bar.show_percentage = false
		
		var fill_style = StyleBoxFlat.new()
		fill_style.bg_color = Color(0.3, 0.69, 0.31)
		fill_bar.add_theme_stylebox_override("fill", fill_style)
	
	# Percent Label
	var percent_label = get_node_or_null("HUD/MasteryButton/PercentLabel")
	if percent_label:
		percent_label.text = "0%"
		percent_label.position = Vector2(0, 30)
		percent_label.size = Vector2(70, 20)
		percent_label.add_theme_font_size_override("font_size", 14)
		percent_label.add_theme_color_override("font_color", Color.WHITE)
		percent_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	# Connect button press
	if not mastery_button.pressed.is_connected(_on_mastery_button_pressed):
		mastery_button.pressed.connect(_on_mastery_button_pressed)

func setup_instructions() -> void:
	var instructions = get_node_or_null("HUD/Instructions")
	if not instructions:
		return
	
	instructions.text = "Swipe up to serve!"
	instructions.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	instructions.position = Vector2(-100, -80)
	instructions.size = Vector2(200, 50)
	instructions.add_theme_font_size_override("font_size", 13)
	instructions.add_theme_color_override("font_color", Color.WHITE)
	instructions.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instructions.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	var bg_style = StyleBoxFlat.new()
	bg_style.set_corner_radius_all(15)
	bg_style.bg_color = Color(0, 0, 0, 0.7)
	instructions.add_theme_stylebox_override("normal", bg_style)

func setup_power_indicator() -> void:
	var power_container = get_node_or_null("PowerIndicator")
	if not power_container:
		return
	
	power_container.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	power_container.position = Vector2(-90, -130)
	power_container.size = Vector2(180, 20)
	power_container.visible = false
	
	var container_style = StyleBoxFlat.new()
	container_style.set_corner_radius_all(12)
	container_style.bg_color = Color(0, 0, 0, 0.6)
	container_style.border_color = Color.WHITE
	container_style.set_border_width_all(2)
	power_container.add_theme_stylebox_override("panel", container_style)
	
	var power_bar = get_node_or_null("PowerIndicator/PowerBar")
	if power_bar:
		power_bar.position = Vector2(2, 2)
		power_bar.size = Vector2(176, 16)
		power_bar.value = 0
		power_bar.show_percentage = false
		
		var bar_style = StyleBoxFlat.new()
		bar_style.set_corner_radius_all(10)
		bar_style.bg_color = Color(0.3, 0.69, 0.31)
		power_bar.add_theme_stylebox_override("fill", bar_style)

func _on_kitchen_button_pressed() -> void:
	print("Kitchen button pressed!")
	if main and main.has_method("handle_kitchen_button_press"):
		main.handle_kitchen_button_press()

func _on_mastery_button_pressed() -> void:
	print("Mastery button pressed!")
	if main and main.has_method("activate_mastery_mode"):
		if main.game_state.kitchen_pressure >= main.game_state.kitchen_pressure_max:
			main.activate_mastery_mode()

# Update functions
func update_score(player_score: int, opponent_score: int, server_number: int) -> void:
	var score_label = get_node_or_null("HUD/TopPanel/ScoreLabel")
	if score_label:
		score_label.text = "%d-%d-%d" % [player_score, opponent_score, server_number]

func update_kitchen_button(state: String, timer: float = 0.0) -> void:
	var button = get_node_or_null("HUD/KitchenButton")
	var text_label = get_node_or_null("HUD/KitchenButton/KitchenText")
	var timer_label = get_node_or_null("HUD/KitchenButton/KitchenTimer")
	
	if not button:
		return
	
	var button_style = StyleBoxFlat.new()
	button_style.set_corner_radius_all(12)
	button_style.border_color = Color.BLACK
	button_style.set_border_width_all(3)
	
	match state:
		"AVAILABLE":
			button_style.bg_color = Color(1.0, 0.84, 0)  # Gold
			if text_label:
				text_label.text = "→K"
			if timer_label and timer > 0:
				timer_label.text = "%.1f" % timer
		"ACTIVE":
			button_style.bg_color = Color(0.3, 0.69, 0.31)  # Green
			if text_label:
				text_label.text = "IN"
			if timer_label:
				timer_label.text = ""
		"MUST_EXIT":
			button_style.bg_color = Color(1.0, 0.6, 0)  # Orange
			if text_label:
				text_label.text = "↑!"
			if timer_label and timer > 0:
				timer_label.text = "%.1f" % timer
		"WARNING":
			button_style.bg_color = Color(0.96, 0.26, 0.21)  # Red
			if text_label:
				text_label.text = "!!"
			if timer_label:
				timer_label.text = ""
		"COOLDOWN":
			button_style.bg_color = Color(0.6, 0.6, 0.6)  # Gray
			if text_label:
				text_label.text = "..."
			if timer_label and timer > 0:
				timer_label.text = "%.1f" % timer
		_:  # DISABLED
			button_style.bg_color = Color(0.4, 0.4, 0.4)  # Dark gray
			if text_label:
				text_label.text = "K"
			if timer_label:
				timer_label.text = ""
	
	button.add_theme_stylebox_override("normal", button_style)
	button.add_theme_stylebox_override("hover", button_style)
	button.add_theme_stylebox_override("pressed", button_style)

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
