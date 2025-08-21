# SwipeDetector.gd - Handles all swipe input for shots
extends Node2D  # Changed from Node to Node2D for drawing capabilities

# Swipe detection
var touch_start: Vector2 = Vector2.ZERO
var touch_current: Vector2 = Vector2.ZERO
var is_swiping: bool = false
var swipe_start_time: int = 0

# Constants from prototype
const MIN_SWIPE_DISTANCE: float = 30.0
const MAX_SWIPE_DISTANCE: float = 250.0
const SWIPE_TIMEOUT: float = 2.0  # Max time for a swipe

# References
@onready var main = get_node("/root/Main")
@onready var ball = get_node("/root/Main/Ball")
@onready var ui = get_node("/root/Main/UI")

# Signals
signal swipe_completed(angle: float, power: float, shot_type: String)
signal swipe_started()
signal swipe_cancelled()

func _ready() -> void:
	print("SwipeDetector _ready() called!")
	
	# Make sure we're processing input
	set_process_input(true)
	set_process_unhandled_input(true)
	
	print("SwipeDetector ready - Input processing enabled: ", is_processing_input())
	print("SwipeDetector ready - Unhandled input processing enabled: ", is_processing_unhandled_input())

func _input(event: InputEvent) -> void:
	# TEST: Print ANY input event to see if we're receiving them
	if event is InputEventMouse:
		print("MOUSE EVENT DETECTED: ", event.get_class())
	
	# Handle mouse input for desktop testing
	if event is InputEventMouseButton:
		print("Mouse button event - Button: ", event.button_index, " Pressed: ", event.pressed, " Position: ", event.position)
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				print("LEFT MOUSE PRESSED at: ", event.position)
				start_swipe(event.position)
			else:
				print("LEFT MOUSE RELEASED at: ", event.position)
				complete_swipe()
	elif event is InputEventMouseMotion:
		# Only print motion when swiping to avoid spam
		if is_swiping:
			print("Mouse motion while swiping: ", event.position)
			update_swipe(event.position)
	
	# Handle touch input for mobile
	elif event is InputEventScreenTouch:
		if event.pressed:
			start_swipe(event.position)
		else:
			complete_swipe()
	elif event is InputEventScreenDrag:
		update_swipe(event.position)

func start_swipe(pos: Vector2) -> void:
	# Don't start new swipe if already swiping
	if is_swiping:
		return
	
	# Check if we're in a valid state to swipe
	if not can_swipe():
		return
	
	touch_start = pos
	touch_current = pos
	is_swiping = true
	swipe_start_time = Time.get_ticks_msec()
	
	emit_signal("swipe_started")
	show_power_indicator()
	
	print("Swipe started at: ", pos)

func update_swipe(pos: Vector2) -> void:
	if not is_swiping:
		return
	
	touch_current = pos
	
	# Check for timeout
	if Time.get_ticks_msec() - swipe_start_time > SWIPE_TIMEOUT * 1000:
		cancel_swipe()
		return
	
	# Update power indicator
	update_power_indicator()

func complete_swipe() -> void:
	if not is_swiping:
		return
	
	is_swiping = false
	hide_power_indicator()
	
	# Calculate swipe properties
	var swipe_vector = touch_current - touch_start
	var distance = swipe_vector.length()
	
	print("Swipe distance: ", distance)
	
	# Check minimum swipe distance
	if distance < MIN_SWIPE_DISTANCE:
		cancel_swipe()
		return
	
	# Calculate power (0.0 to 1.0)
	var power = min(distance / MAX_SWIPE_DISTANCE, 1.0)
	
	# Calculate angle
	var angle = swipe_vector.angle()
	
	# Determine shot type
	var shot_type = determine_shot_type(power, angle)
	
	print("Swipe completed - Power: ", power, " Angle: ", angle, " Type: ", shot_type)
	
	# Emit signal for game to handle
	emit_signal("swipe_completed", angle, power, shot_type)
	
	# Reset
	touch_start = Vector2.ZERO
	touch_current = Vector2.ZERO

func cancel_swipe() -> void:
	is_swiping = false
	touch_start = Vector2.ZERO
	touch_current = Vector2.ZERO
	hide_power_indicator()
	emit_signal("swipe_cancelled")
	print("Swipe cancelled")

func can_swipe() -> bool:
	if not main or not ball:
		print("can_swipe: Missing references")
		return false
	
	# Get player reference
	var player = main.get_node_or_null("Player")
	
	# 1. Is it a serve situation?
	if main.game_state.waiting_for_serve:
		if main.game_state.can_serve:
			print("can_swipe: Player can serve")
			return true
		else:
			print("can_swipe: Waiting for partner/opponent serve")
			return false
	
	# 2. During rally, check if player can hit
	if main.game_state.ball_in_play and player:
		return player.can_hit
	
	print("can_swipe: No ball in play or no player")
	return false
	
func determine_shot_type(power: float, angle: float) -> String:
	# Check if player is near kitchen (will use actual player position later)
	# For now, approximate based on where swipe started
	var court_y_estimate = touch_start.y / get_viewport().size.y
	var near_kitchen = court_y_estimate > 0.5 and court_y_estimate < 0.65
	
	# Forward angle check (upward swipe)
	var forward_angle = angle < -PI/4 and angle > -3*PI/4
	
	# Determine shot type based on prototype logic
	if near_kitchen and power < 0.3 and forward_angle:
		return "dink"
	elif power < 0.3 and abs(angle) > PI/2:
		return "drop"
	elif power > 0.7:
		return "power"
	else:
		return "normal"

# UI Functions
func show_power_indicator() -> void:
	# Get power indicator from UI
	var power_indicator = ui.get_node_or_null("HUD/PowerIndicator")
	if power_indicator:
		power_indicator.visible = true
		power_indicator.modulate.a = 0.0
		# Fade in
		var tween = create_tween()
		tween.tween_property(power_indicator, "modulate:a", 1.0, 0.1)

func update_power_indicator() -> void:
	var power_indicator = ui.get_node_or_null("HUD/PowerIndicator")
	var power_bar = ui.get_node_or_null("HUD/PowerIndicator/PowerBar")
	
	if not power_bar:
		return
	
	# Calculate current power
	var distance = touch_start.distance_to(touch_current)
	var power = min(distance / MAX_SWIPE_DISTANCE, 1.0)
	
	# Update bar
	power_bar.value = power * 100
	
	# Update bar color based on power
	var bar_style = power_bar.get_theme_stylebox("fill") as StyleBoxFlat
	if bar_style:
		if power < 0.3:
			bar_style.bg_color = Color(0.3, 0.69, 0.31)  # Green for soft shots
		elif power > 0.7:
			bar_style.bg_color = Color(0.96, 0.26, 0.21)  # Red for power shots
		else:
			bar_style.bg_color = Color(1.0, 0.92, 0.23)  # Yellow for normal
	
	# Also show swipe line preview (optional)
	queue_redraw()

func hide_power_indicator() -> void:
	var power_indicator = ui.get_node_or_null("HUD/PowerIndicator")
	if power_indicator:
		# Fade out
		var tween = create_tween()
		tween.tween_property(power_indicator, "modulate:a", 0.0, 0.2)
		tween.tween_callback(func(): power_indicator.visible = false)

func _draw() -> void:
	# Draw swipe preview line when swiping
	if is_swiping:
		var swipe_vector = touch_current - touch_start
		var distance = swipe_vector.length()
		
		if distance > 10:  # Only draw if meaningful swipe
			# Draw line from start to current
			draw_line(touch_start, touch_current, Color(1, 1, 1, 0.3), 3.0)
			
			# Draw power indicator circles
			var power = min(distance / MAX_SWIPE_DISTANCE, 1.0)
			var color = Color(1 - power, power, 0, 0.5)  # Green to red gradient
			draw_circle(touch_start, 10, color)
			draw_circle(touch_current, 8, color)
