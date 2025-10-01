# KitchenSystem.gd - Day 5 Kitchen State Machine
extends Node

# Signals for kitchen events
signal kitchen_opportunity()
signal kitchen_entered()
signal kitchen_exited()
signal kitchen_violation(violation_type: String, message: String)
signal pressure_changed(new_value: float)
signal state_changed(new_state: int)

# Kitchen states from prototype v2.1
enum KitchenState {
	DISABLED,
	AVAILABLE,
	ACTIVE,
	MUST_EXIT,
	WARNING,
	COOLDOWN
}

# Current state
var current_state: KitchenState = KitchenState.DISABLED
var state_timer: float = 0.0

# Pressure system
var pressure: float = 0.0
var pressure_max: float = 100.0

# Pressure values from prototype
const DINK_PRESSURE: float = 15.0
const POWER_SHOT_PRESSURE: float = -5.0
const LONG_RALLY_PRESSURE: float = 20.0
const WIN_POINT_PRESSURE: float = 15.0
const VIOLATION_PENALTY: float = -20.0
const OPPONENT_VIOLATION_BONUS: float = 10.0

# State timers from prototype
const AVAILABLE_DURATION: float = 2.5
const MUST_EXIT_DURATION: float = 1.5
const WARNING_DURATION: float = 1.0
const COOLDOWN_DURATION: float = 3.0

# References (set from Main)
var main_node: Node2D = null
var player_data: Dictionary = {}  # Changed from CharacterBody2D to Dictionary

func _ready() -> void:
	set_process(true)

func _process(delta: float) -> void:
	# Update state timer
	if state_timer > 0:
		state_timer -= delta
		
	# State machine logic
	match current_state:
		KitchenState.AVAILABLE:
			if state_timer <= 0:
				# Opportunity missed
				set_state(KitchenState.DISABLED)
				if main_node:
					main_node.show_message("Opportunity missed!", 
						main_node.COURT_WIDTH/2, main_node.NET_Y + 50, Color(1.0, 0.6, 0))
		
		KitchenState.ACTIVE:
			# Check if must exit (ball bounced or is about to)
			check_must_exit_condition()
		
		KitchenState.MUST_EXIT:
			if state_timer <= 0:
				set_state(KitchenState.WARNING)
		
		KitchenState.WARNING:
			# Check for violation every frame
			check_violation_condition()
			if state_timer <= 0:
				# Time's up - force violation
				trigger_violation("TIME_VIOLATION", "Must exit kitchen!")
		
		KitchenState.COOLDOWN:
			if state_timer <= 0:
				set_state(KitchenState.DISABLED)

func trigger_opportunity() -> void:
	"""Called when ball bounces in player's kitchen zone"""
	if current_state == KitchenState.DISABLED:
		set_state(KitchenState.AVAILABLE)
		state_timer = AVAILABLE_DURATION
		emit_signal("kitchen_opportunity")
		
		if main_node:
			main_node.show_message("Kitchen Available!", 
				main_node.COURT_WIDTH/2, main_node.NET_Y + 50, Color(1.0, 0.84, 0))

func enter_kitchen() -> bool:
	"""Player taps button to enter kitchen"""
	if current_state != KitchenState.AVAILABLE:
		return false
	
	set_state(KitchenState.ACTIVE)
	state_timer = 0.0
	
	# Move player into kitchen (using dictionary)
	if player_data and main_node:
		player_data.in_kitchen = true
		player_data.target_court_y = main_node.NET_Y + 35  # Position just behind kitchen line
	
	# Pressure bonus for entering
	update_pressure(5.0)
	
	emit_signal("kitchen_entered")
	return true

func exit_kitchen() -> void:
	"""Player taps button to exit kitchen"""
	if current_state not in [KitchenState.ACTIVE, KitchenState.MUST_EXIT, KitchenState.WARNING]:
		return
	
	set_state(KitchenState.DISABLED)
	state_timer = 0.0
	
	# Move player out of kitchen (using dictionary)
	if player_data and main_node:
		player_data.in_kitchen = false
		player_data.feet_established = false
		player_data.establishment_timer = 0.5  # 0.5s to establish feet
		
		# Move to safe position
		var safe_y = (main_node.KITCHEN_LINE_BOTTOM + main_node.BASELINE_BOTTOM) / 2.0
		player_data.target_court_y = safe_y
	
	emit_signal("kitchen_exited")

func check_must_exit_condition() -> void:
	"""Check if player must exit kitchen (ball hit or bounced)"""
	if current_state != KitchenState.ACTIVE:
		return
	
	# This will be called from Main when:
	# 1. Player hits the ball from kitchen
	# 2. Ball bounces (must exit after dink)
	pass

func force_must_exit() -> void:
	"""Called from Main when player must exit"""
	if current_state == KitchenState.ACTIVE:
		set_state(KitchenState.MUST_EXIT)
		state_timer = MUST_EXIT_DURATION
		
		if main_node:
			main_node.show_message("Exit Kitchen!", 
				main_node.COURT_WIDTH/2, main_node.NET_Y + 50, Color(1.0, 0.6, 0))

func check_violation_condition() -> void:
	"""Check if player is violating kitchen rules"""
	if not player_data or not main_node:
		return
	
	# Still in kitchen during warning state = violation
	if current_state == KitchenState.WARNING and player_data.in_kitchen:
		trigger_violation("EXIT_VIOLATION", "Failed to exit kitchen!")

func trigger_violation(violation_type: String, message: String) -> void:
	"""Handle a kitchen violation"""
	# Set cooldown state
	set_state(KitchenState.COOLDOWN)
	state_timer = COOLDOWN_DURATION
	
	# Pressure penalty
	update_pressure(VIOLATION_PENALTY)
	
	# Force player out (using dictionary)
	if player_data and main_node:
		player_data.in_kitchen = false
		player_data.feet_established = true
		var safe_y = (main_node.KITCHEN_LINE_BOTTOM + main_node.BASELINE_BOTTOM) / 2.0
		player_data.target_court_y = safe_y
	
	# Update tracking
	if main_node:
		main_node.game_state.kitchen_violations["player"] += 1
		main_node.flash_kitchen_zone(true)  # Flash player's kitchen
		main_node.show_message("FAULT! " + message, 
			main_node.COURT_WIDTH/2, main_node.COURT_HEIGHT/2, Color(1.0, 0, 0))
	
	emit_signal("kitchen_violation", violation_type, message)

func check_volley_violation(hitter: Dictionary, ball_height: float) -> bool:
	"""Check if hitting ball in kitchen while it's in air (volley)"""
	if not hitter.in_kitchen:
		return false
	
	# Ball must have bounced (height should be low after bounce)
	# If ball height > 20, it's likely a volley
	if ball_height > 20.0:
		trigger_violation("VOLLEY_IN_KITCHEN", "Cannot volley in kitchen!")
		return true
	
	return false

func check_step_in_violation(hitter: Dictionary) -> bool:
	"""Check if player entered kitchen before establishing feet"""
	if hitter.in_kitchen and not hitter.feet_established and hitter.was_in_kitchen:
		trigger_violation("STEP_IN", "Must establish feet before re-entering!")
		return true
	
	return false

func check_momentum_violation(hitter: Dictionary) -> bool:
	"""Check if momentum from volley carried into kitchen"""
	if hitter.momentum_timer > 0 and hitter.in_kitchen:
		var time_since_volley = 1.5 - hitter.momentum_timer
		if time_since_volley < 1.0 and hitter.volley_position != Vector2.ZERO:
			trigger_violation("MOMENTUM_CARRY", "Momentum carried into kitchen!")
			return true
	
	return false

func set_state(new_state: KitchenState) -> void:
	"""Change kitchen state"""
	if current_state == new_state:
		return
	
	var old_state = current_state
	current_state = new_state
	
	print("Kitchen State: ", KitchenState.keys()[old_state], " -> ", KitchenState.keys()[new_state])
	
	emit_signal("state_changed", new_state)

func update_pressure(amount: float) -> void:
	"""Update kitchen pressure meter"""
	var old_pressure = pressure
	pressure = clamp(pressure + amount, 0.0, pressure_max)
	
	print("Pressure: ", old_pressure, " -> ", pressure, " (", amount, ")")
	
	emit_signal("pressure_changed", pressure)
	
	# Check if mastery is ready
	if pressure >= pressure_max and main_node:
		main_node.show_message("MASTERY READY! Tap ⭐", 
			main_node.COURT_WIDTH/2, main_node.NET_Y, Color(1.0, 0.84, 0))

func get_state_string() -> String:
	"""Get current state as string"""
	return KitchenState.keys()[current_state]

func get_pressure_percent() -> float:
	"""Get pressure as percentage"""
	return (pressure / pressure_max) * 100.0

func reset() -> void:
	"""Reset kitchen system"""
	current_state = KitchenState.DISABLED
	state_timer = 0.0
	pressure = 0.0
