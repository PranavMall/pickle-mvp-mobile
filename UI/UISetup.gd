# UISetup.gd - Fixed with proper button types
extends CanvasLayer

@onready var main = get_node("/root/Main")

func _ready() -> void:
	setup_top_panel()
	setup_instructions()
	setup_power_indicator()

func setup_complete_ui() -> void:
	# Get existing HUD from scene (it already exists)
	var hud = get_node_or_null("HUD")
	if not hud:
		print("ERROR: HUD node not found in UI!")
		return
	
	# Setup components that already exist in scene
	setup_top_panel()
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
