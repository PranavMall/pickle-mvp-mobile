# UI/UISetup.gd - Day 6 Clean Version with Full System Integration
extends CanvasLayer

@onready var main = get_node_or_null("/root/Main")

func _ready() -> void:
	await get_tree().process_frame

	# Setup UI elements
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
	top_panel.position = Vector2(10, 40)  # Lower for notch
	top_panel.size = Vector2(get_viewport().size.x - 20, 45)

	# Style
	var panel_style = StyleBoxFlat.new()
	panel_style.set_corner_radius_all(12)
	panel_style.bg_color = Color(0, 0, 0, 0.7)
	panel_style.border_color = Color(1.0, 0.84, 0, 0.3)
	panel_style.border_width_bottom = 2
	top_panel.add_theme_stylebox_override("panel", panel_style)

	# Score Label - centered and prominent
	var score_label = get_node_or_null("HUD/TopPanel/ScoreLabel")
	if score_label:
		score_label.text = "0-0-2"
		score_label.position = Vector2(15, 8)
		score_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0))
		score_label.add_theme_font_size_override("font_size", 22)

	# Server Indicator
	var server_label = get_node_or_null("HUD/TopPanel/ServerIndicator")
	if server_label:
		server_label.text = "SERVE"
		server_label.position = Vector2(120, 12)
		server_label.add_theme_color_override("font_color", Color(0.3, 0.69, 0.31))
		server_label.add_theme_font_size_override("font_size", 14)

	# Rally Counter
	var rally_label = get_node_or_null("HUD/TopPanel/RallyCounter")
	if rally_label:
		rally_label.text = "Rally: 0"
		rally_label.position = Vector2(200, 12)
		rally_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		rally_label.add_theme_font_size_override("font_size", 12)

	# Violations Counter
	var violations_label = get_node_or_null("HUD/TopPanel/ViolationsLabel")
	if not violations_label:
		violations_label = Label.new()
		violations_label.name = "ViolationsLabel"
		top_panel.add_child(violations_label)

	violations_label.text = "KV:0"
	violations_label.position = Vector2(300, 12)
	violations_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0))
	violations_label.add_theme_font_size_override("font_size", 12)

func setup_instructions() -> void:
	var instructions = get_node_or_null("HUD/Instructions")
	if not instructions:
		return

	instructions.text = "Swipe up to serve!"
	instructions.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	instructions.position = Vector2(-120, -100)
	instructions.size = Vector2(240, 60)
	instructions.add_theme_font_size_override("font_size", 16)
	instructions.add_theme_color_override("font_color", Color.WHITE)
	instructions.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instructions.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	var bg_style = StyleBoxFlat.new()
	bg_style.set_corner_radius_all(15)
	bg_style.bg_color = Color(0, 0, 0, 0.8)
	bg_style.border_color = Color(1.0, 0.84, 0, 0.5)
	bg_style.border_width_bottom = 2
	instructions.add_theme_stylebox_override("normal", bg_style)

func setup_power_indicator() -> void:
	var power_container = get_node_or_null("PowerIndicator")
	if not power_container:
		return

	power_container.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	power_container.position = Vector2(-100, -170)
	power_container.size = Vector2(200, 24)
	power_container.visible = false

	var container_style = StyleBoxFlat.new()
	container_style.set_corner_radius_all(12)
	container_style.bg_color = Color(0, 0, 0, 0.7)
	container_style.border_color = Color.WHITE
	container_style.set_border_width_all(2)
	power_container.add_theme_stylebox_override("panel", container_style)

	var power_bar = get_node_or_null("PowerIndicator/PowerBar")
	if power_bar:
		power_bar.position = Vector2(4, 4)
		power_bar.size = Vector2(192, 16)
		power_bar.value = 0
		power_bar.show_percentage = false

		var bar_bg = StyleBoxFlat.new()
		bar_bg.set_corner_radius_all(8)
		bar_bg.bg_color = Color(0.2, 0.2, 0.2)
		power_bar.add_theme_stylebox_override("background", bar_bg)

		var bar_style = StyleBoxFlat.new()
		bar_style.set_corner_radius_all(8)
		bar_style.bg_color = Color(0.3, 0.69, 0.31)
		power_bar.add_theme_stylebox_override("fill", bar_style)

# =================== UPDATE FUNCTIONS ===================

func update_score(player_score: int, opponent_score: int, server_number: int) -> void:
	var score_label = get_node_or_null("HUD/TopPanel/ScoreLabel")
	if score_label:
		score_label.text = "%d-%d-%d" % [player_score, opponent_score, server_number]

func update_violations(player_violations: int) -> void:
	var violations_label = get_node_or_null("HUD/TopPanel/ViolationsLabel")
	if violations_label:
		violations_label.text = "KV:%d" % player_violations
		# Flash red when violation occurs
		if player_violations > 0:
			violations_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
			var tween = create_tween()
			tween.tween_property(violations_label, "modulate", Color(1, 0.5, 0.5), 0.1)
			tween.tween_property(violations_label, "modulate", Color.WHITE, 0.3)

func update_rally_count(count: int) -> void:
	var rally_label = get_node_or_null("HUD/TopPanel/RallyCounter")
	if rally_label:
		rally_label.text = "Rally: %d" % count
		# Color based on rally length
		if count >= 10:
			rally_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0))
		elif count >= 5:
			rally_label.add_theme_color_override("font_color", Color(0.3, 0.69, 0.31))
		else:
			rally_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))

func update_server_indicator(is_player_serving: bool, server_number: int) -> void:
	var server_label = get_node_or_null("HUD/TopPanel/ServerIndicator")
	if server_label:
		if is_player_serving:
			server_label.text = "YOU #%d" % server_number
			server_label.add_theme_color_override("font_color", Color(0.3, 0.69, 0.31))
		else:
			server_label.text = "OPP #%d" % server_number
			server_label.add_theme_color_override("font_color", Color(0.8, 0.2, 0.2))

func update_instructions_text(text: String) -> void:
	var instructions = get_node_or_null("HUD/Instructions")
	if instructions:
		instructions.text = text

func show_power_indicator() -> void:
	var power_container = get_node_or_null("PowerIndicator")
	if power_container:
		power_container.visible = true

func hide_power_indicator() -> void:
	var power_container = get_node_or_null("PowerIndicator")
	if power_container:
		power_container.visible = false

func update_power_bar(value: float, shot_type: String = "normal") -> void:
	var power_bar = get_node_or_null("PowerIndicator/PowerBar")
	if power_bar:
		power_bar.value = value * 100

		# Update bar color based on shot type
		var bar_style = power_bar.get_theme_stylebox("fill") as StyleBoxFlat
		if bar_style:
			match shot_type:
				"dink":
					bar_style.bg_color = Color(0, 0.74, 0.83)
				"drop":
					bar_style.bg_color = Color(1.0, 0.84, 0)
				"power":
					bar_style.bg_color = Color(0.96, 0.26, 0.21)
				_:
					bar_style.bg_color = Color(0.3, 0.69, 0.31)
