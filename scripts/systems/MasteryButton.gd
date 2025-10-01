# MasteryButton.gd - Day 5 Mastery Button with Fill Indicator
extends Button

# References
var kitchen_system: Node = null
var main_node: Node2D = null

# UI elements
var fill_rect: ColorRect
var icon_label: Label
var percent_label: Label

# State
var is_ready: bool = false
var is_active: bool = false

func _ready() -> void:
	# Setup button
	custom_minimum_size = Vector2(70, 70)
	flat = true
	
	# Create background fill (from bottom up)
	fill_rect = ColorRect.new()
	fill_rect.color = Color(1.0, 0.84, 0, 0.3)  # Gold with transparency
	fill_rect.z_index = -1
	add_child(fill_rect)
	
	# Create icon
	icon_label = Label.new()
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon_label.add_theme_font_size_override("font_size", 32)
	icon_label.text = "⚡"
	add_child(icon_label)
	
	# Create percentage text
	percent_label = Label.new()
	percent_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	percent_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	percent_label.add_theme_font_size_override("font_size", 12)
	percent_label.add_theme_color_override("font_color", Color.WHITE)
	percent_label.text = "0%"
	add_child(percent_label)
	
	# Position elements
	icon_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	percent_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	percent_label.position.y = -5
	
	# Initial fill
	update_fill(0.0)
	
	# Connect press
	pressed.connect(_on_pressed)
	disabled = true

func set_kitchen_system(system: Node) -> void:
	kitchen_system = system
	if kitchen_system:
		kitchen_system.pressure_changed.connect(_on_pressure_changed)

func _on_pressure_changed(new_pressure: float) -> void:
	var fill_percent = (new_pressure / kitchen_system.pressure_max) * 100.0
	update_fill(fill_percent)

func update_fill(fill_percent: float) -> void:
	"""Update fill indicator and button state"""
	# Update fill height (from bottom)
	var button_height = size.y
	var fill_height = (fill_percent / 100.0) * button_height
	
	fill_rect.position = Vector2(0, button_height - fill_height)
	fill_rect.size = Vector2(size.x, fill_height)
	
	# Update percentage text
	percent_label.text = "%d%%" % int(fill_percent)
	
	# Update button state
	if fill_percent >= 100.0:
		# Ready to activate
		is_ready = true
		disabled = false
		modulate = Color(1.0, 0.84, 0, 1.0)  # Gold
		icon_label.text = "⭐"
		percent_label.text = "READY!"
		
		# Golden glow effect
		create_glow_animation()
		
	elif fill_percent >= 75.0:
		icon_label.text = "🔥"
		modulate = Color(1.0, 1.0, 1.0, 1.0)
		disabled = true
		
	elif fill_percent >= 50.0:
		icon_label.text = "⚡"
		modulate = Color(1.0, 1.0, 1.0, 1.0)
		disabled = true
		
	elif fill_percent >= 25.0:
		icon_label.text = "💫"
		modulate = Color(1.0, 1.0, 1.0, 0.8)
		disabled = true
		
	else:
		icon_label.text = "⚡"
		modulate = Color(1.0, 1.0, 1.0, 0.6)
		disabled = true
		is_ready = false

func _on_pressed() -> void:
	if not is_ready or not main_node:
		return
	
	# Activate mastery mode
	activate_mastery()

func activate_mastery() -> void:
	"""Activate kitchen mastery mode"""
	if not kitchen_system or not main_node:
		return
	
	# Set mastery state in main
	main_node.game_state.kitchen_mastery = true
	main_node.game_state.kitchen_mastery_timer = 8.0
	
	# Reset pressure
	kitchen_system.pressure = 0.0
	kitchen_system.emit_signal("pressure_changed", 0.0)
	
	# Apply mastery benefits to player
	if main_node.has_node("Player"):
		var player = main_node.get_node("Player")
		player.mastery_speed_boost = 1.3
		player.mastery_no_faults = true
	
	# Visual feedback
	main_node.show_message("KITCHEN MASTERY ACTIVE!", 
		main_node.COURT_WIDTH/2, main_node.COURT_HEIGHT/2, Color(1.0, 0.84, 0))
	
	# Update button to show active state
	is_active = true
	is_ready = false
	icon_label.text = "👑"
	modulate = Color(1.0, 0.84, 0, 1.0)
	disabled = true
	
	print("Mastery Mode Activated!")

func _process(_delta: float) -> void:
	# Update during mastery mode
	if is_active and main_node:
		var timer = main_node.game_state.kitchen_mastery_timer
		if timer > 0:
			percent_label.text = "%.1fs" % timer
		else:
			# Mastery ended
			is_active = false
			icon_label.text = "⚡"
			percent_label.text = "0%"
			modulate = Color(1.0, 1.0, 1.0, 0.6)

func create_glow_animation() -> void:
	"""Create golden glow when ready"""
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(self, "modulate", Color(1.0, 1.0, 0.5, 1.0), 0.5)
	tween.tween_property(self, "modulate", Color(1.0, 0.84, 0, 1.0), 0.5)
