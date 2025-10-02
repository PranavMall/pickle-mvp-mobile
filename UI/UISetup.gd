# UI/UISetup.gd - Day 5 Clean Version
extends CanvasLayer

@onready var main = get_node("/root/Main")

func _ready() -> void:
	# Wait for Main to be ready
	await get_tree().process_frame
	
	# ONLY setup non-button UI elements
	setup_top_panel()
	setup_instructions()
	setup_power_indicator()
	
	# DON'T touch Kitchen/Mastery buttons - they setup themselves!
	print("UISetup ready - buttons manage themselves")

func setup_top_panel() -> void:
	var top_panel = get_node_or_null("HUD/TopPanel")
	if not top_panel:
		return
	
	# Position and size
	top_panel.position = Vector2(10, 5)
	top_panel.size = Vector2(410, 40)
	
	# Style
	var panel_style = StyleBoxFlat.new()
	panel_style.set_corner_radius_all(20)
	panel_style.bg_color = Color(0, 0, 0, 0.6)
	top_panel.add_theme_stylebox_override("panel", panel_style)
	
	# Score Label
	var score_label = get_node_or_null("HUD/TopPanel/ScoreLabel")
	if score_label:
		score_label.text = "0-0-2"
		score_label.position = Vector2(15, 10)
		score_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0))
		score_label.add_theme_font_size_override("font_size", 16)
	
	# Server Indicator
	var server_label = get_node_or_null("HUD/TopPanel/ServerIndicator")
	if server_label:
		server_label.text = "You"
		server_label.position = Vector2(150, 10)
		server_label.add_theme_color_override("font_color", Color(0.3, 0.69, 0.31))
		server_label.add_theme_font_size_override("font_size", 12)
	
	# Rally Counter
	var rally_label = get_node_or_null("HUD/TopPanel/RallyCounter")
	if rally_label:
		rally_label.text = "R:0"
		rally_label.position = Vector2(250, 10)
		rally_label.add_theme_color_override("font_color", Color(0.67, 0.67, 0.67))
		rally_label.add_theme_font_size_override("font_size", 11)
	
	# Violations Counter
	var violations_label = get_node_or_null("HUD/TopPanel/ViolationsLabel")
	if not violations_label:
		violations_label = Label.new()
		violations_label.name = "ViolationsLabel"
		top_panel.add_child(violations_label)
	
	violations_label.text = "KV:0"
	violations_label.position = Vector2(320, 10)
	violations_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0))
	violations_label.add_theme_font_size_override("font_size", 11)

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

# Update score only - buttons update themselves
func update_score(player_score: int, opponent_score: int, server_number: int) -> void:
	var score_label = get_node_or_null("HUD/TopPanel/ScoreLabel")
	if score_label:
		score_label.text = "%d-%d-%d" % [player_score, opponent_score, server_number]

# Update violations counter
func update_violations(player_violations: int) -> void:
	var violations_label = get_node_or_null("HUD/TopPanel/ViolationsLabel")
	if violations_label:
		violations_label.text = "KV:%d" % player_violations
