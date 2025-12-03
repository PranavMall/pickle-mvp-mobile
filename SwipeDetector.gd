# SwipeDetector.gd - Handles all swipe input for shots
extends Node2D

# Swipe detection
var touch_start: Vector2 = Vector2.ZERO
var touch_current: Vector2 = Vector2.ZERO
var is_swiping: bool = false
var swipe_start_time: int = 0

# Constants from prototype
const MIN_SWIPE_DISTANCE: float = 30.0
const MAX_SWIPE_DISTANCE: float = 250.0
const SWIPE_TIMEOUT: float = 2.0  # Max time for a swipe

# Signals
signal swipe_completed(angle: float, power: float, shot_type: String)
signal swipe_started()
signal swipe_cancelled()

# Lazy-loaded references
var _main: Node = null
var _ball: Node = null
var _ui: Node = null

func get_main() -> Node:
	if not _main:
		_main = get_node_or_null("/root/Main")
	return _main

func get_ball() -> Node:
	if not _ball:
		_ball = get_node_or_null("/root/Main/Ball")
	return _ball

func get_ui() -> Node:
	if not _ui:
		_ui = get_node_or_null("/root/Main/UI")
	return _ui

func _ready() -> void:
	# Enable input processing immediately
	set_process_input(true)
	print("SwipeDetector ready and listening for input")

func _input(event: InputEvent) -> void:
	# Handle mouse input for desktop testing
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				start_swipe(event.position)
			else:
				complete_swipe()
	elif event is InputEventMouseMotion:
		if is_swiping:
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
		print("Cannot swipe - game not ready or not in swipeable state")
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

	print("Swipe completed - distance: ", distance)

	# Check minimum swipe distance
	if distance < MIN_SWIPE_DISTANCE:
		print("Swipe too short, cancelled")
		cancel_swipe()
		return

	# Calculate power (0.0 to 1.0)
	var power = min(distance / MAX_SWIPE_DISTANCE, 1.0)

	# Calculate angle
	var angle = swipe_vector.angle()

	# Determine shot type
	var shot_type = determine_shot_type(power, angle)

	print("Emitting swipe_completed - angle: ", angle, " power: ", power, " type: ", shot_type)

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

func can_swipe() -> bool:
	var main = get_main()
	var ball = get_ball()

	if not main:
		print("can_swipe: Main not found")
		return false
	if not ball:
		print("can_swipe: Ball not found")
		return false

	# 1. Is it a serve situation?
	if main.game_state.waiting_for_serve:
		var can = main.game_state.can_serve
		print("can_swipe: waiting_for_serve=true, can_serve=", can)
		return can

	# 2. During rally, ALWAYS allow swipe
	if main.game_state.ball_in_play:
		print("can_swipe: ball_in_play=true, allowing swipe")
		return true

	print("can_swipe: no valid state (waiting_for_serve=", main.game_state.waiting_for_serve, ", ball_in_play=", main.game_state.ball_in_play, ")")
	return false

func determine_shot_type(power: float, angle: float) -> String:
	var main = get_main()
	if not main:
		return "normal"

	# Get player reference for actual position
	var player = main.get_node_or_null("Player")

	if player:
		# Use actual player position
		var court = main.get_node_or_null("Court")
		var court_pos = Vector2.ZERO
		if court and court.has_method("screen_to_court"):
			court_pos = court.screen_to_court(player.position)
		var near_kitchen = abs(court_pos.y - main.KITCHEN_LINE_BOTTOM) < 30

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
	else:
		# Fallback if no player
		if power < 0.3:
			return "drop"
		elif power > 0.7:
			return "power"
		else:
			return "normal"

# UI Functions
func show_power_indicator() -> void:
	var ui = get_ui()
	if not ui:
		return
	var power_indicator = ui.get_node_or_null("HUD/PowerIndicator")
	if power_indicator:
		power_indicator.visible = true
		power_indicator.modulate.a = 0.0
		var tween = create_tween()
		tween.tween_property(power_indicator, "modulate:a", 1.0, 0.1)

func update_power_indicator() -> void:
	var ui = get_ui()
	if not ui:
		return
	var power_bar = ui.get_node_or_null("HUD/PowerIndicator/PowerBar")

	if not power_bar:
		return

	# Calculate current power
	var distance = touch_start.distance_to(touch_current)
	var power = min(distance / MAX_SWIPE_DISTANCE, 1.0)

	# Update bar
	power_bar.value = power * 100

	# Also show swipe line preview
	queue_redraw()

func hide_power_indicator() -> void:
	var ui = get_ui()
	if not ui:
		return
	var power_indicator = ui.get_node_or_null("HUD/PowerIndicator")
	if power_indicator:
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
			draw_line(touch_start, touch_current, Color(1, 1, 1, 0.5), 4.0)

			# Draw power indicator circles
			var power = min(distance / MAX_SWIPE_DISTANCE, 1.0)
			var color = Color(1 - power, power, 0, 0.7)  # Green to red gradient
			draw_circle(touch_start, 12, color)
			draw_circle(touch_current, 10, color)
