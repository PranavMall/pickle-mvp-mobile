# SwipeDetector.gd - Handles all swipe input for shots
# NOTE: Input is forwarded from Main.gd's _input() because set_script()
# on a dynamically-added node doesn't register _input() on Android.
# Main.gd calls start_swipe(), update_swipe(), complete_swipe() directly.
extends Node2D  # Node2D for drawing capabilities

# Swipe detection
var touch_start: Vector2 = Vector2.ZERO
var touch_current: Vector2 = Vector2.ZERO
var is_swiping: bool = false
var swipe_start_time: int = 0

# Constants from prototype
const MIN_SWIPE_DISTANCE: float = 30.0
const MAX_SWIPE_DISTANCE: float = 250.0
const SWIPE_TIMEOUT: float = 2.0  # Max time for a swipe

# References — resolved dynamically, NOT @onready (breaks with set_script)
var main: Node = null
var ball: Node = null
var ui: Node = null

# Signals
signal swipe_completed(angle: float, power: float, shot_type: String)
signal swipe_started()
signal swipe_cancelled()

func _ready() -> void:
	print("SwipeDetector _ready() called!")

	# Resolve references dynamically — works even when added via set_script()
	main = get_node_or_null("/root/Main")
	ball = get_node_or_null("/root/Main/Ball")
	ui = get_node_or_null("/root/Main/UI")

	# Disable own _input — Main.gd forwards touch events to our methods directly
	# This avoids double-processing and works around set_script() not registering _input on Android
	set_process_input(false)
	set_process_unhandled_input(false)

	print("SwipeDetector ready - main: ", main != null, " ball: ", ball != null, " ui: ", ui != null)
	print("SwipeDetector ready - Input forwarded from Main.gd")

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
		print("[SWIPE] can_swipe: Missing refs main=%s ball=%s — resolving..." % [str(main != null), str(ball != null)])
		# Try to resolve again
		main = get_node_or_null("/root/Main")
		ball = get_node_or_null("/root/Main/Ball")
		if not main or not ball:
			print("[SWIPE] can_swipe: STILL missing after resolve!")
			return false

	# 1. Is it a serve situation?
	if main.game_state.waiting_for_serve:
		if main.game_state.can_serve:
			print("[SWIPE] can_swipe: Player can serve")
			return true
		else:
			print("[SWIPE] can_swipe: Waiting for partner/opponent serve")
			return false

	# 2. During rally, ALWAYS allow swipe (hit detection will handle if it connects)
	if main.game_state.ball_in_play:
		return true

	print("[SWIPE] can_swipe: No ball in play, waiting=%s can_serve=%s" % [
		str(main.game_state.waiting_for_serve), str(main.game_state.can_serve)])
	return false

func determine_shot_type(power: float, angle: float) -> String:
	# Get player reference for actual position
	var player = main.get_node_or_null("Player")
	
	if player:
		# Use actual player position
		var court_pos = main.get_node("Court").screen_to_court(player.position) if main.has_node("Court") else Vector2.ZERO
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
	if not ui:
		return
	# Try both paths (PowerIndicator is child of UI, not UI/HUD)
	var power_indicator = ui.get_node_or_null("PowerIndicator")
	if not power_indicator:
		power_indicator = ui.get_node_or_null("HUD/PowerIndicator")
	if power_indicator:
		power_indicator.visible = true
		power_indicator.modulate.a = 0.0
		var tween = create_tween()
		tween.tween_property(power_indicator, "modulate:a", 1.0, 0.1)

func update_power_indicator() -> void:
	if not ui:
		return
	var power_bar = ui.get_node_or_null("PowerIndicator/PowerBar")
	if not power_bar:
		power_bar = ui.get_node_or_null("HUD/PowerIndicator/PowerBar")
	if not power_bar:
		return

	var distance = touch_start.distance_to(touch_current)
	var power = min(distance / MAX_SWIPE_DISTANCE, 1.0)
	power_bar.value = power * 100

	var bar_style = power_bar.get_theme_stylebox("fill") as StyleBoxFlat
	if bar_style:
		if power < 0.3:
			bar_style.bg_color = Color(0.3, 0.69, 0.31)
		elif power > 0.7:
			bar_style.bg_color = Color(0.96, 0.26, 0.21)
		else:
			bar_style.bg_color = Color(1.0, 0.92, 0.23)

	queue_redraw()

func hide_power_indicator() -> void:
	if not ui:
		return
	var power_indicator = ui.get_node_or_null("PowerIndicator")
	if not power_indicator:
		power_indicator = ui.get_node_or_null("HUD/PowerIndicator")
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
			draw_line(touch_start, touch_current, Color(1, 1, 1, 0.3), 3.0)
			
			# Draw power indicator circles
			var power = min(distance / MAX_SWIPE_DISTANCE, 1.0)
			var color = Color(1 - power, power, 0, 0.5)  # Green to red gradient
			draw_circle(touch_start, 10, color)
			draw_circle(touch_current, 8, color)
