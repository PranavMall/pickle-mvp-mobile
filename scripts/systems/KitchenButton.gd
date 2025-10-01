# KitchenButton.gd - Day 5 Kitchen Button UI
extends Button

# References
var kitchen_system: Node = null
var main_node: Node2D = null

# UI elements (created programmatically)
var button_text: Label
var timer_label: Label
var background_panel: Panel

# Colors for each state
var colors = {
	"disabled": Color(0.3, 0.3, 0.3, 0.8),
	"available": Color(1.0, 0.84, 0, 1.0),  # Gold
	"active": Color(0.3, 0.69, 0.31, 1.0),  # Green
	"must_exit": Color(1.0, 0.6, 0, 1.0),   # Orange
	"warning": Color(0.96, 0.26, 0.21, 1.0),  # Red
	"cooldown": Color(0.6, 0.6, 0.6, 0.6)   # Gray
}

func _ready() -> void:
	# Setup button
	custom_minimum_size = Vector2(80, 80)
	flat = true
	
	# Create text label
	button_text = Label.new()
	button_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	button_text.add_theme_font_size_override("font_size", 24)
	button_text.add_theme_color_override("font_color", Color.WHITE)
	button_text.text = "K"
	add_child(button_text)
	
	# Create timer label
	timer_label = Label.new()
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	timer_label.add_theme_font_size_override("font_size", 12)
	timer_label.add_theme_color_override("font_color", Color.WHITE)
	timer_label.visible = false
	add_child(timer_label)
	
	# Position labels
	button_text.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	timer_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	timer_label.position.y = -10
	
	# Connect button press
	pressed.connect(_on_button_pressed)
	
	# Initial state
	update_appearance(0)  # DISABLED

func set_kitchen_system(system: Node) -> void:
	kitchen_system = system
	if kitchen_system:
		kitchen_system.state_changed.connect(_on_state_changed)

func _process(_delta: float) -> void:
	if not kitchen_system:
		return
	
	# Update timer display
	if kitchen_system.state_timer > 0:
		timer_label.text = "%.1f" % kitchen_system.state_timer
		timer_label.visible = true
	else:
		timer_label.visible = false

func _on_state_changed(new_state: int) -> void:
	update_appearance(new_state)

func update_appearance(state: int) -> void:
	"""Update button appearance based on state"""
	match state:
		0:  # DISABLED
			modulate = colors["disabled"]
			button_text.text = "K"
			disabled = true
			
		1:  # AVAILABLE
			modulate = colors["available"]
			button_text.text = "↑K"
			disabled = false
			# Pulse animation
			create_pulse_animation()
			
		2:  # ACTIVE
			modulate = colors["active"]
			button_text.text = "IN"
			disabled = false
			
		3:  # MUST_EXIT
			modulate = colors["must_exit"]
			button_text.text = "↓!"
			disabled = false
			# Pulse animation
			create_pulse_animation()
			
		4:  # WARNING
			modulate = colors["warning"]
			button_text.text = "!!"
			disabled = false
			# Flash animation
			create_flash_animation()
			
		5:  # COOLDOWN
			modulate = colors["cooldown"]
			button_text.text = "⏳"
			disabled = true

func _on_button_pressed() -> void:
	if not kitchen_system:
		return
	
	match kitchen_system.current_state:
		1:  # AVAILABLE - Enter kitchen
			kitchen_system.enter_kitchen()
			
		2, 3, 4:  # ACTIVE, MUST_EXIT, WARNING - Exit kitchen
			kitchen_system.exit_kitchen()

func create_pulse_animation() -> void:
	"""Create pulsing animation"""
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(self, "scale", Vector2(1.1, 1.1), 0.5)
	tween.tween_property(self, "scale", Vector2.ONE, 0.5)

func create_flash_animation() -> void:
	"""Create flashing animation for warning state"""
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(button_text, "modulate:a", 0.3, 0.15)
	tween.tween_property(button_text, "modulate:a", 1.0, 0.15)
