# TutorialManager.gd - Interactive tutorial system
extends Node

signal tutorial_started()
signal step_completed(step_index: int)
signal step_started(step_index: int, title: String, instruction: String)
signal tutorial_completed()

# Tutorial state
var tutorial_active: bool = false
var current_step: int = 0
var step_requirements_met: Dictionary = {}
var waiting_for_action: bool = false

# References
var main_node: Node2D = null
var ui_panel: Control = null

# Tutorial steps
var steps: Array = [
	{
		"title": "Welcome to Pickleball!",
		"instruction": "Pickleball is America's fastest growing sport.\nLet's learn the basics!",
		"requirement": "tap_continue",
		"duration": 0.0,
		"highlight": ""
	},
	{
		"title": "The Serve",
		"instruction": "Swipe UP on the screen to serve.\nTry it now!",
		"requirement": "serve",
		"duration": 0.0,
		"highlight": "court_bottom",
		"show_ghost": true
	},
	{
		"title": "Power Control",
		"instruction": "Short swipe = soft shot\nLong swipe = power shot\n\nHit 3 balls with different powers!",
		"requirement": "vary_power",
		"requirement_count": 3,
		"duration": 0.0,
		"highlight": ""
	},
	{
		"title": "The Kitchen (No-Volley Zone)",
		"instruction": "The golden zone is the KITCHEN.\nYou CANNOT volley (hit in air) here!\n\nWatch for the golden Kitchen button!",
		"requirement": "observe",
		"duration": 5.0,
		"highlight": "kitchen_zone"
	},
	{
		"title": "Kitchen Entry",
		"instruction": "When the Kitchen button glows gold,\ntap it to enter the kitchen.\n\nWait for the glow, then tap!",
		"requirement": "enter_kitchen",
		"duration": 0.0,
		"highlight": "kitchen_button"
	},
	{
		"title": "Dinking",
		"instruction": "In the kitchen, use SHORT swipes\nto dink the ball softly over the net.\n\nDink 3 balls successfully!",
		"requirement": "dink",
		"requirement_count": 3,
		"duration": 0.0,
		"highlight": ""
	},
	{
		"title": "Kitchen Pressure",
		"instruction": "Dinks build your MASTERY meter!\nWatch it fill up on the left.\n\nKeep dinking to build pressure!",
		"requirement": "reach_pressure",
		"requirement_value": 50,
		"duration": 0.0,
		"highlight": "mastery_button"
	},
	{
		"title": "Mastery Mode!",
		"instruction": "When the meter hits 100%,\ntap it for MASTERY MODE!\n\n8 seconds of superpowers!",
		"requirement": "activate_mastery",
		"duration": 0.0,
		"highlight": "mastery_button"
	},
	{
		"title": "You're Ready!",
		"instruction": "Great job! You've learned:\n• Serving & Power control\n• Kitchen rules\n• Dinking & Mastery\n\nGo play!",
		"requirement": "tap_continue",
		"duration": 0.0,
		"highlight": ""
	}
]

# Tracking counters
var power_variations_hit: int = 0
var dinks_completed: int = 0
var last_power: float = -1.0

func _ready() -> void:
	pass

func setup(main: Node2D) -> void:
	"""Setup tutorial with main reference"""
	main_node = main

func start_tutorial() -> void:
	"""Start the tutorial from the beginning"""
	tutorial_active = true
	current_step = 0
	step_requirements_met = {}
	power_variations_hit = 0
	dinks_completed = 0
	last_power = -1.0

	emit_signal("tutorial_started")
	show_current_step()
	print("Tutorial started!")

func stop_tutorial() -> void:
	"""End the tutorial"""
	tutorial_active = false
	emit_signal("tutorial_completed")

	if main_node:
		main_node.show_message("Tutorial Complete!", main_node.COURT_WIDTH/2,
							   main_node.COURT_HEIGHT/2, Color(1.0, 0.84, 0))

	# Save completion
	GameManager.complete_tutorial()
	print("Tutorial completed!")

func show_current_step() -> void:
	"""Display the current tutorial step"""
	if current_step >= steps.size():
		stop_tutorial()
		return

	var step = steps[current_step]
	waiting_for_action = true

	emit_signal("step_started", current_step, step.title, step.instruction)

	# Show visual highlight if specified
	if step.has("highlight") and step.highlight != "":
		highlight_element(step.highlight)

	# Show ghost demonstration if specified
	if step.get("show_ghost", false):
		show_ghost_demo()

	# Auto-advance for timed steps
	if step.has("duration") and step.duration > 0:
		await get_tree().create_timer(step.duration).timeout
		if waiting_for_action:
			advance_step()

	print("Tutorial step %d: %s" % [current_step, step.title])

func check_action(action: String, details: Dictionary = {}) -> void:
	"""Check if an action satisfies the current step requirement"""
	if not tutorial_active or not waiting_for_action:
		return

	if current_step >= steps.size():
		return

	var step = steps[current_step]
	var requirement = step.get("requirement", "")

	var requirement_met = false

	match requirement:
		"tap_continue":
			if action == "tap" or action == "any":
				requirement_met = true

		"serve":
			if action == "serve_completed":
				requirement_met = true
				if main_node:
					main_node.show_message("Great serve!", main_node.COURT_WIDTH/2,
										   main_node.COURT_HEIGHT - 100, Color(0.3, 0.69, 0.31))

		"vary_power":
			if action == "shot_completed" and details.has("power"):
				var power = details.power
				# Check if power is significantly different from last
				if last_power < 0 or abs(power - last_power) > 0.3:
					power_variations_hit += 1
					last_power = power

					if power_variations_hit >= step.get("requirement_count", 3):
						requirement_met = true
					else:
						if main_node:
							main_node.show_message("Good! %d/%d" % [power_variations_hit, step.requirement_count],
												   main_node.COURT_WIDTH/2, main_node.NET_Y,
												   Color(0.3, 0.69, 0.31))

		"observe":
			# Auto-complete after duration
			pass

		"enter_kitchen":
			if action == "kitchen_entered":
				requirement_met = true

		"dink":
			if action == "dink_completed":
				dinks_completed += 1
				if dinks_completed >= step.get("requirement_count", 3):
					requirement_met = true
				else:
					if main_node:
						main_node.show_message("Nice dink! %d/%d" % [dinks_completed, step.requirement_count],
											   main_node.COURT_WIDTH/2, main_node.NET_Y,
											   Color(0, 0.74, 0.83))

		"reach_pressure":
			if action == "pressure_updated" and details.has("pressure"):
				if details.pressure >= step.get("requirement_value", 50):
					requirement_met = true

		"activate_mastery":
			if action == "mastery_activated":
				requirement_met = true

	if requirement_met:
		advance_step()

func advance_step() -> void:
	"""Move to the next tutorial step"""
	waiting_for_action = false
	emit_signal("step_completed", current_step)

	# Celebration feedback
	if main_node:
		main_node.show_message("✓", main_node.COURT_WIDTH/2 + 50,
							   main_node.COURT_HEIGHT/2, Color(0.3, 0.69, 0.31))
	AudioManager.play_ui_sound("success")

	current_step += 1

	# Brief delay before next step
	await get_tree().create_timer(1.0).timeout

	if current_step < steps.size():
		show_current_step()
	else:
		stop_tutorial()

func highlight_element(element_name: String) -> void:
	"""Highlight a UI element or court area"""
	match element_name:
		"kitchen_zone":
			# Pulse the kitchen zones
			if main_node:
				main_node.queue_redraw()

		"kitchen_button":
			var button = main_node.get_node_or_null("UI/HUD/KitchenButton") if main_node else null
			if button:
				create_highlight_pulse(button)

		"mastery_button":
			var button = main_node.get_node_or_null("UI/HUD/MasteryButton") if main_node else null
			if button:
				create_highlight_pulse(button)

		"court_bottom":
			# Highlight serving area
			pass

func create_highlight_pulse(node: Control) -> void:
	"""Create a pulsing highlight effect on a node"""
	if not node:
		return

	var tween = create_tween()
	tween.set_loops(3)
	tween.tween_property(node, "modulate", Color(1.5, 1.5, 0.5), 0.3)
	tween.tween_property(node, "modulate", Color.WHITE, 0.3)

func show_ghost_demo() -> void:
	"""Show a ghost hand demonstrating the swipe"""
	# In a full implementation, this would show an animated hand
	# doing the swipe gesture. For MVP, we'll skip this.
	pass

func is_tutorial_active() -> bool:
	"""Check if tutorial is currently running"""
	return tutorial_active

func get_current_step() -> Dictionary:
	"""Get the current tutorial step data"""
	if current_step < steps.size():
		return steps[current_step]
	return {}

func skip_tutorial() -> void:
	"""Skip the remaining tutorial"""
	tutorial_active = false
	emit_signal("tutorial_completed")
	GameManager.complete_tutorial()
	print("Tutorial skipped")
