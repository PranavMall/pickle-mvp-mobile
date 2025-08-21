# Main.gd - Foundation
extends Node2D

# Constants from prototype - EXACT VALUES
const COURT_WIDTH: float = 280.0
const COURT_HEIGHT: float = 560.0
const COURT_OFFSET_Y: float = 60.0
const PERSPECTIVE_SCALE: float = 0.75
const PERSPECTIVE_ANGLE: float = 10.0

# Game dimensions
const KITCHEN_DEPTH: float = 70.0
const NET_Y: float = COURT_HEIGHT / 2.0
const KITCHEN_LINE_TOP: float = NET_Y - KITCHEN_DEPTH
const KITCHEN_LINE_BOTTOM: float = NET_Y + KITCHEN_DEPTH
const BASELINE_TOP: float = 30.0
const BASELINE_BOTTOM: float = COURT_HEIGHT - 30.0
const SERVICE_LINE_DEPTH: float = 90.0

# Player constants
const PLAYER_SPEED: float = 180.0
const BALL_RADIUS: float = 8.0
const GRAVITY: float = 160.0
const HIT_DISTANCE: float = 60.0
const HIT_COOLDOWN: float = 0.8

# Kitchen State Machine
enum KitchenState {
	DISABLED,
	AVAILABLE,
	ACTIVE,
	MUST_EXIT,
	WARNING,
	COOLDOWN
}

# Game State
var game_state: Dictionary = {
	"player_score": 0,
	"opponent_score": 0,
	"serving_team": "player",
	"server_number": 2,
	"rally_count": 0,
	"consecutive_hits": 0,
	"rally_length": 0,
	
	# Kitchen states
	"kitchen_state": KitchenState.DISABLED,
	"kitchen_state_timer": 0.0,
	"in_kitchen": false,
	
	# Kitchen tracking
	"kitchen_violations": {"player": 0, "opponent": 0},
	"kitchen_flash": null,
	
	# Pressure system
	"kitchen_pressure": 0.0,
	"kitchen_pressure_max": 100.0,
	"kitchen_mastery": false,
	"kitchen_mastery_timer": 0.0,
	
	# Dink tracking
	"is_dink_rally": false,
	"dink_count": 0,
	
	# Game flow
	"game_active": false,
	"ball_in_play": false,
	"first_bounce_complete": false,
	"second_bounce_complete": false,
	"waiting_for_serve": false,
	"can_serve": false,
	"is_first_serve_of_game": true,
	"current_server": null,
	"last_bounce_team": null,
	"bounces_on_current_side": 0,
	"is_serve_in_progress": false,
	"expected_service_box": null
}

# Messages array for floating text
var messages: Array = []

# Screen dimensions
var screen_width: float
var screen_height: float
var court_scale: float = 1.0

func _ready() -> void:
	# Get screen dimensions
	screen_width = get_viewport().size.x
	screen_height = get_viewport().size.y
	
	# Check if resolution is appropriate for mobile portrait game
	if screen_width > 500 or screen_height > 1000:
		print("WARNING: Game designed for mobile portrait (430x932)")
		print("Current resolution: ", screen_width, "x", screen_height)
		print("Game may not display correctly at this resolution")
		print("Recommended: Set window size to 430x932 or similar aspect ratio")
	
	# Calculate court scale to fit screen
	court_scale = min(screen_width / COURT_WIDTH, screen_height / (COURT_HEIGHT + COURT_OFFSET_Y * 2))
	
	# Initialize game
	init_game()
	
	# TEST: Verify perspective calculations
	test_perspective_points()
	
	# Ball is now part of the scene, no need to create it
	print("Main scene ready - Ball should be in scene tree")
	
	# Create swipe detector for Day 3
	create_swipe_detector()
	
	# Create player for Day 4
	create_player()
	
	# TEST: Add simple input test directly in Main
	set_process_input(true)

func _input(event: InputEvent) -> void:
	# TEST: See if Main is receiving input
	if event is InputEventMouseButton:
		print("MAIN received mouse button event: ", event.button_index, " pressed: ", event.pressed)

func create_swipe_detector() -> void:
	# Create SwipeDetector node (Node2D for drawing capabilities)
	var swipe_detector = Node2D.new()
	swipe_detector.name = "SwipeDetector"
	swipe_detector.z_index = 150  # Draw on top of everything
	add_child(swipe_detector)
	
	# Attach script
	var swipe_script = load("res://SwipeDetector.gd")
	if swipe_script:
		swipe_detector.set_script(swipe_script)
		
		# Force call _ready since it might not be called automatically
		if swipe_detector.has_method("_ready"):
			swipe_detector._ready()
		
		# Connect signals with error checking
		var result1 = swipe_detector.swipe_completed.connect(_on_swipe_completed)
		var result2 = swipe_detector.swipe_started.connect(_on_swipe_started)
		
		if result1 == OK and result2 == OK:
			print("SwipeDetector created and connected successfully")
		else:
			print("ERROR: Failed to connect SwipeDetector signals")
		
		# Verify it's processing input
		print("SwipeDetector is processing input: ", swipe_detector.is_processing_input())
		print("SwipeDetector is processing unhandled input: ", swipe_detector.is_processing_unhandled_input())
	else:
		print("ERROR: SwipeDetector.gd not found!")

func _on_swipe_started() -> void:
	print("Player starting swipe...")

func _on_swipe_completed(angle: float, power: float, shot_type: String) -> void:
	print("Swipe completed! Angle: ", angle, " Power: ", power, " Type: ", shot_type)
	
	# Handle serve
	if game_state.waiting_for_serve and game_state.can_serve:
		player_serve_with_swipe(angle, power)
		return
	
	# Handle regular hit
	if game_state.ball_in_play:
		var ball = get_node_or_null("Ball")
		if ball:
			# Check if ball is in valid hitting range
			var ball_court_pos = ball.screen_to_court(ball.global_position)
			if ball_court_pos.y > NET_Y and ball.height < 40:
				ball.receive_hit(angle, power, shot_type)
				
				# Update game state
				game_state.rally_count += 1
				update_ui()

func player_serve_with_swipe(angle: float, power: float) -> void:
	print("Player serving with swipe!")
	
	game_state.ball_in_play = true
	game_state.waiting_for_serve = false
	game_state.can_serve = false
	game_state.consecutive_hits = 0
	game_state.first_bounce_complete = false
	game_state.second_bounce_complete = false
	game_state.last_hit_team = "player"
	game_state.bounces_on_current_side = 0
	game_state.is_serve_in_progress = true
	
	# Determine target service box
	game_state.expected_service_box = "left"  # Will improve later
	
	# Get ball and serve
	var ball = get_node_or_null("Ball")
	if ball:
		# Position ball at serve position
		var serve_pos = court_to_screen(COURT_WIDTH/2, COURT_HEIGHT - 50)
		ball.global_position = serve_pos
		ball.height = 40.0
		
		# Force upward angle for serve to cross net
		# Serve must go up (negative angle) to cross net
		var serve_angle = angle
		if serve_angle > -PI/4:  # If angle is too horizontal or downward
			serve_angle = -PI/3  # Force upward angle
		
		# Boost power for serves to ensure it crosses net
		var serve_power = max(power, 0.5)  # Minimum 50% power for serves
		
		# Use special serve parameters
		ball.receive_serve(serve_angle, serve_power)
		
		show_message("Serve!", COURT_WIDTH/2, COURT_HEIGHT - 30, Color.WHITE)
		
		# Update instructions
		var instructions = get_node_or_null("UI/HUD/Instructions")
		if instructions:
			instructions.text = "Rally in play!"
	
	game_state.game_active = true
	game_state.rally_count = 0

func create_player() -> void:
	# Create player character
	var player = CharacterBody2D.new()
	player.name = "Player"
	player.z_index = 50  # Above court, below ball
	add_child(player)
	
	# Attach player script
	var player_script = load("res://Players/Player.gd")
	if player_script:
		player.set_script(player_script)
		
		# Connect player signals
		player.entered_kitchen.connect(_on_player_entered_kitchen)
		player.exited_kitchen.connect(_on_player_exited_kitchen)
		player.ready_to_hit.connect(_on_player_ready_to_hit)
		
		print("Player created and connected")
	else:
		print("ERROR: Player.gd not found!")

func _on_player_entered_kitchen() -> void:
	print("Player entered kitchen")
	update_kitchen_pressure(5)

func _on_player_exited_kitchen() -> void:
	print("Player exited kitchen")

func _on_player_ready_to_hit() -> void:
	# Visual feedback when player can hit
	var instructions = get_node_or_null("UI/HUD/Instructions")
	if instructions and game_state.ball_in_play:
		instructions.text = "Swipe to hit!"

func update_kitchen_pressure(amount: float) -> void:
	game_state.kitchen_pressure = clamp(
		game_state.kitchen_pressure + amount,
		0,
		game_state.kitchen_pressure_max
	)

func update_ui() -> void:
	# Update score display
	var score_label = get_node_or_null("UI/HUD/TopPanel/ScoreLabel")
	if score_label:
		score_label.text = "%d-%d-%d" % [game_state.player_score, game_state.opponent_score, game_state.server_number]
	
	# Update other UI elements through UISetup
	var ui = get_node_or_null("UI")
	if ui and ui.has_method("update_mastery_fill"):
		var percent = (game_state.kitchen_pressure / game_state.kitchen_pressure_max) * 100
		ui.update_mastery_fill(percent)
	if ui and ui.has_method("update_score"):
		ui.update_score(game_state.player_score, game_state.opponent_score, game_state.server_number)

func create_ball() -> void:
	# Method 1: Load and instantiate Ball scene (if you created Ball.tscn)
	var ball_scene = load("res://Ball/Ball.tscn")
	if ball_scene:
		var ball = ball_scene.instantiate()
		add_child(ball)
		print("Ball scene instantiated and added")
		return
	
	# Method 2: Create ball programmatically if scene doesn't exist
	print("Ball.tscn not found, creating programmatically...")
	
	var ball = CharacterBody2D.new()
	ball.name = "Ball"
	
	# Add collision shape
	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 8
	collision.shape = shape
	ball.add_child(collision)
	
	# Add sprite
	var sprite = Sprite2D.new()
	sprite.name = "Sprite"
	# Create a simple yellow circle texture
	var img = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	for x in 16:
		for y in 16:
			var dx = x - 8
			var dy = y - 8
			if dx*dx + dy*dy <= 64:
				img.set_pixel(x, y, Color.YELLOW)
	sprite.texture = ImageTexture.create_from_image(img)
	ball.add_child(sprite)
	
	# Add shadow
	var shadow = Sprite2D.new()
	shadow.name = "Shadow"
	shadow.modulate = Color(0, 0, 0, 0.5)
	ball.add_child(shadow)
	ball.move_child(shadow, 0)  # Put shadow behind
	
	# Add trail
	var trail = Line2D.new()
	trail.name = "Trail"
	trail.width = 3.0
	trail.default_color = Color(1.0, 0.84, 0, 0.3)
	ball.add_child(trail)
	ball.move_child(trail, 0)
	
	# Now add the complete ball to scene
	add_child(ball)
	
	# Attach the script
	var ball_script = load("res://Ball/Ball.gd")
	if ball_script:
		ball.set_script(ball_script)
		print("Ball script attached")
		
		# Set initial position manually since _ready might not trigger properly
		ball.position = court_to_screen(COURT_WIDTH / 2.0, COURT_HEIGHT - 100)
		print("Ball positioned at: ", ball.position)
	else:
		print("ERROR: Ball.gd script not found at res://Ball/Ball.gd")
	
	print("Ball created and added to scene")

func test_perspective_points() -> void:
	# Test court corners to verify perspective math
	var test_points = [
		Vector2(0, 0),  # Top-left
		Vector2(COURT_WIDTH, 0),  # Top-right
		Vector2(0, COURT_HEIGHT),  # Bottom-left
		Vector2(COURT_WIDTH, COURT_HEIGHT),  # Bottom-right
		Vector2(COURT_WIDTH/2, NET_Y),  # Center net
		Vector2(COURT_WIDTH/2, KITCHEN_LINE_TOP),  # Kitchen top
		Vector2(COURT_WIDTH/2, KITCHEN_LINE_BOTTOM),  # Kitchen bottom
		Vector2(COURT_WIDTH/2, COURT_HEIGHT - 100)  # Ball start position
	]
	
	print("=== Perspective Test Points ===")
	for point in test_points:
		var screen_pos = court_to_screen(point.x, point.y)
		print("Court ", point, " -> Screen ", screen_pos)
	print("===============================")

func _process(delta: float) -> void:
	if game_state.game_active:
		update_game(delta)
	
	# Update messages
	update_messages(delta)
	
	# Force redraw for court
	queue_redraw()

func _draw() -> void:
	# Draw court with perspective
	draw_court()
	
	# Draw messages
	draw_messages()

func init_game() -> void:
	game_state.game_active = true
	game_state.serving_team = "player"
	game_state.server_number = 2
	game_state.is_first_serve_of_game = true
	
	# Set up for player serve
	game_state.waiting_for_serve = true
	game_state.can_serve = true
	
	# Update instructions
	var instructions = get_node_or_null("UI/HUD/Instructions")
	if instructions:
		instructions.text = "Swipe up to serve!"
	
	# This will be called once players are set up
	# reset_positions()
	update_ui()

func update_game(delta: float) -> void:
	# Update kitchen state machine
	update_kitchen_state_machine(delta)
	
	# Update mastery timer
	if game_state.kitchen_mastery:
		game_state.kitchen_mastery_timer -= delta
		if game_state.kitchen_mastery_timer <= 0:
			end_mastery_mode()

# PERSPECTIVE CALCULATION - EXACT FROM PROTOTYPE
func get_visual_court_bounds(y: float) -> Dictionary:
	var perspective_factor = 1.0 - (1.0 - PERSPECTIVE_SCALE) * (1.0 - y / COURT_HEIGHT)
	var visual_width = COURT_WIDTH * perspective_factor
	var left_bound = (COURT_WIDTH - visual_width) / 2.0
	var right_bound = COURT_WIDTH - left_bound
	return {"left": left_bound, "right": right_bound, "width": visual_width}

func court_to_screen(x: float, y: float) -> Vector2:
	var center_x = screen_width / 2.0
	var court_top = COURT_OFFSET_Y * court_scale
	
	var perspective_factor = 1.0 - (1.0 - PERSPECTIVE_SCALE) * (1.0 - y / COURT_HEIGHT)
	var visual_bounds = get_visual_court_bounds(y)
	
	var normalized_x = x / COURT_WIDTH
	var visual_x = visual_bounds.left + normalized_x * visual_bounds.width
	
	var screen_x = center_x + (visual_x - COURT_WIDTH / 2.0) * perspective_factor * court_scale
	var screen_y = court_top + y * 0.9 * court_scale
	
	return Vector2(screen_x, screen_y)

func draw_court() -> void:
	var center_x = screen_width / 2.0
	var court_top = COURT_OFFSET_Y * court_scale
	
	# Court surface with perspective
	var top_left = Vector2(center_x - (COURT_WIDTH / 2.0) * PERSPECTIVE_SCALE * court_scale, court_top)
	var top_right = Vector2(center_x + (COURT_WIDTH / 2.0) * PERSPECTIVE_SCALE * court_scale, court_top)
	var bottom_left = Vector2(center_x - (COURT_WIDTH / 2.0) * court_scale, court_top + COURT_HEIGHT * 0.9 * court_scale)
	var bottom_right = Vector2(center_x + (COURT_WIDTH / 2.0) * court_scale, court_top + COURT_HEIGHT * 0.9 * court_scale)
	
	# Draw court surface
	var court_points = PackedVector2Array([top_left, top_right, bottom_right, bottom_left])
	draw_colored_polygon(court_points, Color(0.18, 0.49, 0.20))  # #2E7D32
	
	# Draw court texture lines
	for i in range(11):
		var y_factor = i / 10.0
		var left_x = lerp(top_left.x, bottom_left.x, y_factor)
		var right_x = lerp(top_right.x, bottom_right.x, y_factor)
		var screen_y = lerp(top_left.y, bottom_left.y, y_factor)
		
		draw_line(Vector2(left_x, screen_y), Vector2(right_x, screen_y), 
				  Color(0.14, 0.42, 0.21), 1.0)  # #236B35
	
	# Draw kitchen zones
	draw_kitchen_zones(center_x, court_top)
	
	# Draw court lines
	draw_court_lines(center_x, court_top)
	
	# Draw net
	draw_net(center_x, court_top)

func draw_kitchen_zones(center_x: float, court_top: float) -> void:
	var kitchen_color = get_kitchen_zone_color()
	
	var net_pos = court_to_screen(COURT_WIDTH/2.0, NET_Y)
	var kitchen_top_pos = court_to_screen(COURT_WIDTH/2.0, KITCHEN_LINE_TOP)
	var kitchen_bottom_pos = court_to_screen(COURT_WIDTH/2.0, KITCHEN_LINE_BOTTOM)
	
	var top_kitchen_scale = 1.0 - (1.0 - PERSPECTIVE_SCALE) * (1.0 - KITCHEN_LINE_TOP / COURT_HEIGHT)
	var net_scale = 1.0 - (1.0 - PERSPECTIVE_SCALE) * (1.0 - NET_Y / COURT_HEIGHT)
	var bottom_kitchen_scale = 1.0 - (1.0 - PERSPECTIVE_SCALE) * (1.0 - KITCHEN_LINE_BOTTOM / COURT_HEIGHT)
	
	# Top kitchen
	var top_kitchen_points = PackedVector2Array([
		Vector2(center_x - (COURT_WIDTH/2.0) * top_kitchen_scale * court_scale, kitchen_top_pos.y),
		Vector2(center_x + (COURT_WIDTH/2.0) * top_kitchen_scale * court_scale, kitchen_top_pos.y),
		Vector2(center_x + (COURT_WIDTH/2.0) * net_scale * court_scale, net_pos.y),
		Vector2(center_x - (COURT_WIDTH/2.0) * net_scale * court_scale, net_pos.y)
	])
	draw_colored_polygon(top_kitchen_points, kitchen_color)
	
	# Bottom kitchen (with potential flash)
	var bottom_color = kitchen_color
	if game_state.kitchen_flash and game_state.kitchen_flash.active and game_state.kitchen_flash.side == "bottom":
		bottom_color = Color(1.0, 0, 0, game_state.kitchen_flash.opacity)
	
	var bottom_kitchen_points = PackedVector2Array([
		Vector2(center_x - (COURT_WIDTH/2.0) * net_scale * court_scale, net_pos.y),
		Vector2(center_x + (COURT_WIDTH/2.0) * net_scale * court_scale, net_pos.y),
		Vector2(center_x + (COURT_WIDTH/2.0) * bottom_kitchen_scale * court_scale, kitchen_bottom_pos.y),
		Vector2(center_x - (COURT_WIDTH/2.0) * bottom_kitchen_scale * court_scale, kitchen_bottom_pos.y)
	])
	draw_colored_polygon(bottom_kitchen_points, bottom_color)
	
	# Kitchen labels
	var font = ThemeDB.fallback_font
	draw_string(font, Vector2(center_x - 30, net_pos.y - 30), "KITCHEN", 
				HORIZONTAL_ALIGNMENT_CENTER, -1, 11, Color(1, 1, 1, 0.4))
	draw_string(font, Vector2(center_x - 30, net_pos.y + 35), "KITCHEN", 
				HORIZONTAL_ALIGNMENT_CENTER, -1, 11, Color(1, 1, 1, 0.4))

func draw_court_lines(center_x: float, court_top: float) -> void:
	# Outer boundary
	var top_left = Vector2(center_x - (COURT_WIDTH / 2.0) * PERSPECTIVE_SCALE * court_scale, court_top)
	var top_right = Vector2(center_x + (COURT_WIDTH / 2.0) * PERSPECTIVE_SCALE * court_scale, court_top)
	var bottom_left = Vector2(center_x - (COURT_WIDTH / 2.0) * court_scale, court_top + COURT_HEIGHT * 0.9 * court_scale)
	var bottom_right = Vector2(center_x + (COURT_WIDTH / 2.0) * court_scale, court_top + COURT_HEIGHT * 0.9 * court_scale)
	
	draw_line(top_left, top_right, Color.WHITE, 3.0)
	draw_line(top_right, bottom_right, Color.WHITE, 3.0)
	draw_line(bottom_right, bottom_left, Color.WHITE, 3.0)
	draw_line(bottom_left, top_left, Color.WHITE, 3.0)
	
	# Baselines
	var baseline_top_pos = court_to_screen(COURT_WIDTH/2.0, BASELINE_TOP)
	var baseline_bottom_pos = court_to_screen(COURT_WIDTH/2.0, BASELINE_BOTTOM)
	var baseline_top_scale = 1.0 - (1.0 - PERSPECTIVE_SCALE) * (1.0 - BASELINE_TOP / COURT_HEIGHT)
	var baseline_bottom_scale = 1.0 - (1.0 - PERSPECTIVE_SCALE) * (1.0 - BASELINE_BOTTOM / COURT_HEIGHT)
	
	draw_line(
		Vector2(center_x - (COURT_WIDTH/2.0) * baseline_top_scale * court_scale, baseline_top_pos.y),
		Vector2(center_x + (COURT_WIDTH/2.0) * baseline_top_scale * court_scale, baseline_top_pos.y),
		Color.WHITE, 2.0
	)
	draw_line(
		Vector2(center_x - (COURT_WIDTH/2.0) * baseline_bottom_scale * court_scale, baseline_bottom_pos.y),
		Vector2(center_x + (COURT_WIDTH/2.0) * baseline_bottom_scale * court_scale, baseline_bottom_pos.y),
		Color.WHITE, 2.0
	)
	
	# Kitchen lines (dashed)
	var kitchen_top_pos = court_to_screen(COURT_WIDTH/2.0, KITCHEN_LINE_TOP)
	var kitchen_bottom_pos = court_to_screen(COURT_WIDTH/2.0, KITCHEN_LINE_BOTTOM)
	var kitchen_top_scale = 1.0 - (1.0 - PERSPECTIVE_SCALE) * (1.0 - KITCHEN_LINE_TOP / COURT_HEIGHT)
	var kitchen_bottom_scale = 1.0 - (1.0 - PERSPECTIVE_SCALE) * (1.0 - KITCHEN_LINE_BOTTOM / COURT_HEIGHT)
	
	draw_dashed_line_custom(
		Vector2(center_x - (COURT_WIDTH/2.0) * kitchen_top_scale * court_scale, kitchen_top_pos.y),
		Vector2(center_x + (COURT_WIDTH/2.0) * kitchen_top_scale * court_scale, kitchen_top_pos.y),
		Color(1.0, 0.84, 0), 2.0, 6.0, 3.0
	)
	draw_dashed_line_custom(
		Vector2(center_x - (COURT_WIDTH/2.0) * kitchen_bottom_scale * court_scale, kitchen_bottom_pos.y),
		Vector2(center_x + (COURT_WIDTH/2.0) * kitchen_bottom_scale * court_scale, kitchen_bottom_pos.y),
		Color(1.0, 0.84, 0), 2.0, 6.0, 3.0
	)
	
	# Service center lines
	draw_line(Vector2(center_x, baseline_top_pos.y), Vector2(center_x, kitchen_top_pos.y),
			  Color(1, 1, 1, 0.7), 2.0)
	draw_line(Vector2(center_x, kitchen_bottom_pos.y), Vector2(center_x, baseline_bottom_pos.y),
			  Color(1, 1, 1, 0.7), 2.0)

func draw_net(center_x: float, court_top: float) -> void:
	var net_pos = court_to_screen(COURT_WIDTH/2.0, NET_Y)
	var net_scale = 1.0 - (1.0 - PERSPECTIVE_SCALE) * (1.0 - NET_Y / COURT_HEIGHT)
	
	# Net shadow
	draw_line(
		Vector2(center_x - (COURT_WIDTH/2.0) * net_scale * court_scale, net_pos.y),
		Vector2(center_x + (COURT_WIDTH/2.0) * net_scale * court_scale, net_pos.y),
		Color.BLACK, 4.0
	)
	
	# Net
	draw_line(
		Vector2(center_x - (COURT_WIDTH/2.0) * net_scale * court_scale, net_pos.y),
		Vector2(center_x + (COURT_WIDTH/2.0) * net_scale * court_scale, net_pos.y),
		Color.WHITE, 2.0
	)

func draw_dashed_line_custom(from: Vector2, to: Vector2, color: Color, width: float, dash_length: float, gap_length: float) -> void:
	var direction = (to - from).normalized()
	var total_length = from.distance_to(to)
	var current_length = 0.0
	
	while current_length < total_length:
		var dash_start = from + direction * current_length
		var dash_end = from + direction * min(current_length + dash_length, total_length)
		draw_line(dash_start, dash_end, color, width)
		current_length += dash_length + gap_length

func get_kitchen_zone_color() -> Color:
	# Dynamic kitchen zone coloring based on state
	if game_state.in_kitchen:
		return Color(1.0, 0.78, 0, 0.15)  # Gold when active
	else:
		return Color(1.0, 0.78, 0, 0.06)  # Subtle gold

func update_kitchen_state_machine(delta: float) -> void:
	if game_state.kitchen_state_timer > 0:
		game_state.kitchen_state_timer -= delta
	
	match game_state.kitchen_state:
		KitchenState.AVAILABLE:
			if game_state.kitchen_state_timer <= 0:
				game_state.kitchen_state = KitchenState.DISABLED
				show_message("Opportunity missed!", COURT_WIDTH/2.0, NET_Y + 50, Color(1.0, 0.6, 0))
		
		KitchenState.ACTIVE:
			# Check if ball is high and coming to our side
			pass
		
		KitchenState.MUST_EXIT:
			if game_state.kitchen_state_timer <= 0:
				game_state.kitchen_state = KitchenState.WARNING
		
		KitchenState.WARNING:
			# Check for violation
			pass
		
		KitchenState.COOLDOWN:
			if game_state.kitchen_state_timer <= 0:
				game_state.kitchen_state = KitchenState.DISABLED

func end_mastery_mode() -> void:
	game_state.kitchen_mastery = false
	show_message("Mastery ended", COURT_WIDTH/2.0, NET_Y, Color(1.0, 0.84, 0))

func show_message(text: String, x: float, y: float, color: Color, duration: float = 1.0) -> void:
	var screen_pos = court_to_screen(x, y)
	messages.append({
		"text": text,
		"x": screen_pos.x,
		"y": screen_pos.y,
		"color": color,
		"life": duration,
		"vy": -2.0
	})

func update_messages(delta: float) -> void:
	var messages_to_remove = []
	for i in range(messages.size()):
		var msg = messages[i]
		msg.life -= delta
		msg.y += msg.vy
		if msg.life <= 0:
			messages_to_remove.append(i)
	
	# Remove expired messages
	for i in range(messages_to_remove.size() - 1, -1, -1):
		messages.remove_at(messages_to_remove[i])

func draw_messages() -> void:
	var font = ThemeDB.fallback_font
	for msg in messages:
		var alpha = min(msg.life, 1.0)
		var color = Color(msg.color.r, msg.color.g, msg.color.b, alpha)
		draw_string(font, Vector2(msg.x - 40, msg.y), msg.text,
					HORIZONTAL_ALIGNMENT_CENTER, -1, 14, color)
