# Main.gd - Complete Pickleball Game Controller
# Integrates all game systems: Kitchen, Scoring, AI, Tutorial
extends Node2D

# =================== CONSTANTS ===================
# Court dimensions (from prototype)
const COURT_WIDTH: float = 280.0
const COURT_HEIGHT: float = 560.0
const COURT_OFFSET_Y: float = 25.0  # Reduced for fuller screen coverage
const PERSPECTIVE_SCALE: float = 0.75
const PERSPECTIVE_ANGLE: float = 10.0

# Zone dimensions
const KITCHEN_DEPTH: float = 70.0
const NET_Y: float = COURT_HEIGHT / 2.0
const KITCHEN_LINE_TOP: float = NET_Y - KITCHEN_DEPTH
const KITCHEN_LINE_BOTTOM: float = NET_Y + KITCHEN_DEPTH
const BASELINE_TOP: float = 30.0
const BASELINE_BOTTOM: float = COURT_HEIGHT - 30.0
const SERVICE_LINE_DEPTH: float = 90.0

# Player constants
const PLAYER_SPEED: float = 180.0
const PARTNER_SPEED: float = 170.0
const OPPONENT_SPEED: float = 160.0
const BALL_RADIUS: float = 8.0
const GRAVITY: float = 160.0
const HIT_DISTANCE: float = 80.0
const HIT_COOLDOWN: float = 0.4
const MIN_PLAYER_DISTANCE: float = 80.0

# Kitchen State Machine
enum KitchenState {
	DISABLED,
	AVAILABLE,
	ACTIVE,
	MUST_EXIT,
	WARNING,
	COOLDOWN
}

# =================== GAME STATE ===================
var game_state: Dictionary = {
	# Scoring
	"player_score": 0,
	"opponent_score": 0,
	"serving_team": "player",
	"server_number": 2,
	"rally_count": 0,
	"consecutive_hits": 0,
	"rally_length": 0,

	# Kitchen
	"kitchen_state": KitchenState.DISABLED,
	"kitchen_state_timer": 0.0,
	"in_kitchen": false,
	"kitchen_violations": {"player": 0, "opponent": 0},
	"kitchen_flash": null,

	# Mastery
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
	"expected_service_box": null,
	"last_hit_team": ""
}

# =================== REFERENCES ===================
var screen_width: float
var screen_height: float
var court_scale: float = 1.0

# Player nodes
var player_node: CharacterBody2D = null
var partner_node: CharacterBody2D = null

# Systems
var kitchen_system: Node = null
var scoring_system: Node = null
var service_rules: Node = null
var violation_detector: Node = null
var tutorial_manager: Node = null

# AI brains
var partner_ai: Node = null
var opponent1_ai: Node = null
var opponent2_ai: Node = null

# Messages
var messages: Array = []

# =================== PLAYER DATA ===================
var player_data: Dictionary = {
	"court_x": COURT_WIDTH * 0.75,
	"court_y": BASELINE_BOTTOM - SERVICE_LINE_DEPTH,
	"target_court_x": 0.0,
	"target_court_y": 0.0,
	"court_side": "right",
	"in_kitchen": false,
	"can_hit": false,
	"last_hit_time": 0,
	"default_x": COURT_WIDTH * 0.75,
	"default_y": BASELINE_BOTTOM - SERVICE_LINE_DEPTH,
	"was_in_kitchen": false,
	"feet_established": true,
	"momentum_timer": 0.0,
	"volley_position": Vector2.ZERO,
	"establishment_timer": 0.0,
	"is_serving": false,
	"is_opponent": false,
	"name": "Player"
}

var partner_data: Dictionary = {
	"court_x": COURT_WIDTH * 0.25,
	"court_y": BASELINE_BOTTOM - SERVICE_LINE_DEPTH,
	"target_court_x": 0.0,
	"target_court_y": 0.0,
	"court_side": "left",
	"in_kitchen": false,
	"can_hit": false,
	"last_hit_time": 0,
	"default_x": COURT_WIDTH * 0.25,
	"default_y": BASELINE_BOTTOM - SERVICE_LINE_DEPTH,
	"was_in_kitchen": false,
	"feet_established": true,
	"momentum_timer": 0.0,
	"volley_position": Vector2.ZERO,
	"establishment_timer": 0.0,
	"is_serving": false,
	"is_opponent": false,
	"name": "Partner"
}

var opponent1_data: Dictionary = {
	"court_x": COURT_WIDTH * 0.75,
	"court_y": BASELINE_TOP + SERVICE_LINE_DEPTH,
	"target_court_x": 0.0,
	"target_court_y": 0.0,
	"court_side": "right",
	"in_kitchen": false,
	"can_hit": false,
	"last_hit_time": 0,
	"default_x": COURT_WIDTH * 0.75,
	"default_y": BASELINE_TOP + SERVICE_LINE_DEPTH,
	"was_in_kitchen": false,
	"feet_established": true,
	"momentum_timer": 0.0,
	"volley_position": Vector2.ZERO,
	"establishment_timer": 0.0,
	"is_serving": false,
	"is_opponent": true,
	"name": "Opponent1"
}

var opponent2_data: Dictionary = {
	"court_x": COURT_WIDTH * 0.25,
	"court_y": BASELINE_TOP + SERVICE_LINE_DEPTH,
	"target_court_x": 0.0,
	"target_court_y": 0.0,
	"court_side": "left",
	"in_kitchen": false,
	"can_hit": false,
	"last_hit_time": 0,
	"default_x": COURT_WIDTH * 0.25,
	"default_y": BASELINE_TOP + SERVICE_LINE_DEPTH,
	"was_in_kitchen": false,
	"feet_established": true,
	"momentum_timer": 0.0,
	"volley_position": Vector2.ZERO,
	"establishment_timer": 0.0,
	"is_serving": false,
	"is_opponent": true,
	"name": "Opponent2"
}

# =================== INITIALIZATION ===================
func _ready() -> void:
	screen_width = get_viewport().size.x
	screen_height = get_viewport().size.y
	# Use a larger scale to fill more of the screen - prioritize height for portrait mode
	var width_scale = screen_width / COURT_WIDTH
	var height_scale = screen_height / (COURT_HEIGHT + COURT_OFFSET_Y * 0.5)  # Reduced offset for fuller screen
	court_scale = min(width_scale, height_scale) * 0.95  # Fill 95% of available space

	print("=== PICKLEBALL DOUBLES MVP ===")
	print("Screen: %dx%d, Court scale: %.2f" % [int(screen_width), int(screen_height), court_scale])

	# Initialize all systems - await to ensure completion
	await get_tree().process_frame
	await create_systems()
	await create_swipe_detector()
	create_player_team()

	# Start game
	init_game()
	print("=== GAME READY ===")

func create_systems() -> void:
	"""Create all game systems"""
	# Kitchen System
	var kitchen_script = load("res://scripts/systems/KitchenSystem.gd")
	if kitchen_script:
		kitchen_system = Node.new()
		kitchen_system.name = "KitchenSystem"
		kitchen_system.set_script(kitchen_script)
		add_child(kitchen_system)
		kitchen_system.main_node = self
		kitchen_system.player_data = player_data
		connect_kitchen_signals()

	# Scoring System
	var scoring_script = load("res://scripts/systems/ScoringSystem.gd")
	if scoring_script:
		scoring_system = Node.new()
		scoring_system.name = "ScoringSystem"
		scoring_system.set_script(scoring_script)
		add_child(scoring_system)
		scoring_system.main_node = self
		connect_scoring_signals()

	# Service Rules
	var service_script = load("res://scripts/systems/ServiceRules.gd")
	if service_script:
		service_rules = Node.new()
		service_rules.name = "ServiceRules"
		service_rules.set_script(service_script)
		add_child(service_rules)
		service_rules.setup_from_main(self)
		connect_service_signals()

	# Violation Detector
	var violation_script = load("res://scripts/systems/ViolationDetector.gd")
	if violation_script:
		violation_detector = Node.new()
		violation_detector.name = "ViolationDetector"
		violation_detector.set_script(violation_script)
		add_child(violation_detector)
		violation_detector.setup_from_main(self)
		connect_violation_signals()

	# Tutorial Manager
	var tutorial_script = load("res://scripts/systems/TutorialManager.gd")
	if tutorial_script:
		tutorial_manager = Node.new()
		tutorial_manager.name = "TutorialManager"
		tutorial_manager.set_script(tutorial_script)
		add_child(tutorial_manager)
		tutorial_manager.setup(self)

	# Connect UI buttons
	await get_tree().create_timer(0.1).timeout
	connect_ui_buttons()

	print("All systems created and connected")

func connect_kitchen_signals() -> void:
	"""Connect kitchen system signals"""
	if kitchen_system:
		kitchen_system.kitchen_opportunity.connect(_on_kitchen_opportunity)
		kitchen_system.kitchen_entered.connect(_on_kitchen_entered)
		kitchen_system.kitchen_exited.connect(_on_kitchen_exited)
		kitchen_system.kitchen_violation.connect(_on_kitchen_violation)
		kitchen_system.pressure_changed.connect(_on_pressure_changed)
		kitchen_system.state_changed.connect(_on_kitchen_state_changed)

func connect_scoring_signals() -> void:
	"""Connect scoring system signals"""
	if scoring_system:
		scoring_system.score_updated.connect(_on_score_updated)
		scoring_system.game_over.connect(_on_game_over)

func connect_service_signals() -> void:
	"""Connect service rules signals"""
	if service_rules:
		service_rules.serve_valid.connect(_on_serve_valid)
		service_rules.serve_fault.connect(_on_serve_fault)
		service_rules.double_bounce_complete.connect(_on_double_bounce_complete)
		service_rules.double_bounce_violation.connect(_on_double_bounce_violation)

func connect_violation_signals() -> void:
	"""Connect violation detector signals"""
	if violation_detector:
		violation_detector.violation_detected.connect(_on_violation_detected)

func connect_ui_buttons() -> void:
	"""Connect UI button scripts"""
	var kitchen_button = get_node_or_null("UI/HUD/KitchenButton")
	if kitchen_button and kitchen_button.has_method("set_kitchen_system"):
		kitchen_button.set_kitchen_system(kitchen_system)
		kitchen_button.main_node = self

	var mastery_button = get_node_or_null("UI/HUD/MasteryButton")
	if mastery_button and mastery_button.has_method("set_kitchen_system"):
		mastery_button.set_kitchen_system(kitchen_system)
		mastery_button.main_node = self

# =================== PLAYER CREATION ===================
func create_player_team() -> void:
	"""Create player and partner characters"""
	player_node = create_character("Player", Color(0.2, 0.4, 0.8), "right", true)
	partner_node = create_character("Partner", Color(0.2, 0.6, 0.9), "left", false)

	update_character_screen_position(player_node, player_data)
	update_character_screen_position(partner_node, partner_data)

	# Create AI for partner
	var ai_script = load("res://scripts/ai/AIBrain.gd")
	if ai_script:
		partner_ai = Node.new()
		partner_ai.set_script(ai_script)
		partner_ai.setup(self, partner_data)
		add_child(partner_ai)

		opponent1_ai = Node.new()
		opponent1_ai.set_script(ai_script)
		opponent1_ai.setup(self, opponent1_data)
		add_child(opponent1_ai)

		opponent2_ai = Node.new()
		opponent2_ai.set_script(ai_script)
		opponent2_ai.setup(self, opponent2_data)
		add_child(opponent2_ai)

	print("Player team created")

func create_character(char_name: String, color: Color, court_side: String, is_player: bool) -> CharacterBody2D:
	"""Create a character with visual components"""
	var character = CharacterBody2D.new()
	character.name = char_name
	add_child(character)

	# Sprite
	var sprite = Sprite2D.new()
	sprite.name = "Sprite"
	var img = Image.create(36, 36, false, Image.FORMAT_RGBA8)

	for x in range(36):
		for y in range(36):
			var dx = x - 18.0
			var dy = y - 18.0
			var dist = sqrt(dx*dx + dy*dy)
			if dist <= 18:
				img.set_pixel(x, y, color if dist <= 16 else Color.BLACK)
			else:
				img.set_pixel(x, y, Color(0, 0, 0, 0))

	sprite.texture = ImageTexture.create_from_image(img)
	sprite.z_index = 1
	character.add_child(sprite)

	# Collision
	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 18
	collision.shape = shape
	character.add_child(collision)

	# Label
	var label = Label.new()
	label.text = "Y" if is_player else "P"
	label.position = Vector2(-5, -5)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_font_size_override("font_size", 10)
	sprite.add_child(label)

	# Paddle
	var paddle = Sprite2D.new()
	paddle.name = "Paddle"
	var paddle_img = Image.create(12, 40, false, Image.FORMAT_RGBA8)
	for x in range(12):
		for y in range(40):
			if y < 15 and x >= 4 and x < 8:
				paddle_img.set_pixel(x, y, Color(0.4, 0.25, 0.1))
			elif y >= 15 and x >= 1 and x < 11:
				paddle_img.set_pixel(x, y, Color(0.6, 0.35, 0.15) if (x > 1 and x < 10 and y > 15 and y < 39) else Color.BLACK)
	paddle.texture = ImageTexture.create_from_image(paddle_img)
	paddle.position = Vector2(25, 0)
	paddle.z_index = 2
	character.add_child(paddle)

	character.z_index = 50
	return character

func update_character_screen_position(character: CharacterBody2D, data: Dictionary) -> void:
	"""Update character screen position from court position"""
	if character:
		var screen_pos = court_to_screen(data.court_x, data.court_y)
		character.position = screen_pos

# =================== SWIPE INPUT ===================
func create_swipe_detector() -> void:
	"""Create the swipe input detector"""
	print("Creating SwipeDetector...")

	var swipe_detector = Node2D.new()
	swipe_detector.name = "SwipeDetector"
	swipe_detector.z_index = 150
	add_child(swipe_detector)

	var swipe_script = load("res://SwipeDetector.gd")
	if swipe_script:
		print("SwipeDetector script loaded successfully")
		swipe_detector.set_script(swipe_script)

		# Wait a frame for _ready() to complete
		await get_tree().process_frame

		# Now connect signals
		if swipe_detector.has_signal("swipe_completed"):
			swipe_detector.swipe_completed.connect(_on_swipe_completed)
			swipe_detector.swipe_started.connect(_on_swipe_started)
			print("SwipeDetector signals connected!")
		else:
			push_error("SwipeDetector missing signals!")
	else:
		push_error("Failed to load SwipeDetector.gd!")

func _on_swipe_started() -> void:
	"""Handle swipe start"""
	pass

func _on_swipe_completed(angle: float, power: float, shot_type: String) -> void:
	"""Handle completed swipe for serving or hitting"""
	# Serve
	if game_state.waiting_for_serve and game_state.can_serve:
		player_serve_with_swipe(angle, power)
		if tutorial_manager and tutorial_manager.is_tutorial_active():
			tutorial_manager.check_action("serve_completed")
		return

	# Hit during rally
	if game_state.ball_in_play:
		var ball = get_node_or_null("Ball")
		if not ball:
			return

		# Check if player or partner can hit
		if player_data.can_hit:
			attempt_player_hit(ball, angle, power, shot_type)
		elif partner_data.can_hit and ball.last_hit_team == "opponent":
			# Let partner AI handle it if they're in position
			pass
		else:
			# Even if not perfectly in range, try to hit if reasonably close
			var ball_court_pos = ball.screen_to_court(ball.global_position) if ball.has_method("screen_to_court") else Vector2.ZERO
			var player_screen_pos = court_to_screen(player_data.court_x, player_data.court_y)
			var screen_dist = player_screen_pos.distance_to(ball.global_position)

			# Allow hit if within extended range and ball is on our side and from opponent
			var extended_hit_dist = HIT_DISTANCE * 2.0  # 160 pixels for swipe leniency
			if screen_dist < extended_hit_dist and \
			   ball_court_pos.y > NET_Y - 30 and \
			   ball.in_flight and \
			   ball.last_hit_team == "opponent":
				attempt_player_hit(ball, angle, power, shot_type)

# =================== SERVING ===================
func player_serve_with_swipe(angle: float, power: float) -> void:
	"""Execute player serve"""
	game_state.ball_in_play = true
	game_state.waiting_for_serve = false
	game_state.can_serve = false
	game_state.consecutive_hits = 0
	game_state.first_bounce_complete = false
	game_state.second_bounce_complete = false
	game_state.last_hit_team = "player"
	game_state.bounces_on_current_side = 0
	game_state.is_serve_in_progress = true
	game_state.rally_length = 0

	# Get target service box
	if scoring_system:
		game_state.expected_service_box = scoring_system.get_receiver_side()
	else:
		game_state.expected_service_box = "left"

	# Setup service rules
	if service_rules:
		service_rules.start_serve(false, game_state.expected_service_box)

	var ball = get_node_or_null("Ball")
	if ball:
		var serve_pos = court_to_screen(player_data.court_x, player_data.court_y - 20)
		ball.global_position = serve_pos
		ball.height = 40.0

		var serve_angle = clamp(angle, -3*PI/4, -PI/4) if angle < -PI/4 else -PI/2
		ball.receive_serve(serve_angle, max(power, 0.5))

		AudioManager.play_serve(ball.global_position)
		show_message("Serve!", COURT_WIDTH/2, COURT_HEIGHT - 50, Color.WHITE)

	update_instructions("Rally in play!")
	game_state.game_active = true
	update_ui()

# =================== HITTING ===================
func attempt_player_hit(ball: Node2D, angle: float, power: float, shot_type: String) -> void:
	"""Attempt to hit the ball as the player"""
	# Check for kitchen violations
	if violation_detector:
		var violation = violation_detector.check_comprehensive_kitchen_violation(
			player_data, ball.height, true
		)
		if violation.violation:
			handle_violation(player_data, violation)
			return

	# Check double-bounce rule
	if service_rules:
		if service_rules.check_double_bounce_violation("player", ball.bounces > 0):
			show_message("Must let ball bounce!", COURT_WIDTH/2, COURT_HEIGHT/2, Color(1.0, 0.26, 0.21))
			AudioManager.play_fault()
			return

	# Record volley position for momentum check
	if ball.height > 0:
		player_data.volley_position = Vector2(player_data.court_x, player_data.court_y)
		player_data.momentum_timer = 1.5

	# Execute hit
	ball.receive_hit(angle, power, shot_type)
	player_data.last_hit_time = Time.get_ticks_msec()
	player_data.can_hit = false

	game_state.consecutive_hits += 1
	game_state.rally_count += 1
	game_state.rally_length += 1

	if service_rules:
		service_rules.record_hit("player")

	# Update pressure based on shot type
	if kitchen_system:
		match shot_type:
			"dink":
				kitchen_system.update_pressure(15.0)
				game_state.dink_count += 1
				if tutorial_manager and tutorial_manager.is_tutorial_active():
					tutorial_manager.check_action("dink_completed")
			"power":
				kitchen_system.update_pressure(5.0)
			_:
				kitchen_system.update_pressure(3.0)

	# Check if must exit kitchen after hitting
	if player_data.in_kitchen and ball.height > 0:
		if kitchen_system:
			kitchen_system.force_must_exit()

	AudioManager.play_hit(power, ball.global_position)
	show_message(shot_type.capitalize() + "!", player_data.court_x, player_data.court_y - 30, get_shot_color(shot_type))

	if tutorial_manager and tutorial_manager.is_tutorial_active():
		tutorial_manager.check_action("shot_completed", {"power": power, "type": shot_type})

	update_ui()

func get_shot_color(shot_type: String) -> Color:
	"""Get display color for shot type"""
	match shot_type:
		"dink": return Color(0, 0.74, 0.83)
		"drop": return Color(1.0, 0.84, 0)
		"power": return Color(0.96, 0.26, 0.21)
		_: return Color(0.3, 0.69, 0.31)

# =================== GAME LOOP ===================
func _process(delta: float) -> void:
	if game_state.game_active:
		update_game(delta)
		update_player_movement(delta)
		update_ai_players(delta)

		if game_state.kitchen_mastery:
			game_state.kitchen_mastery_timer -= delta
			if game_state.kitchen_mastery_timer <= 0:
				end_mastery_mode()

	update_messages(delta)
	update_kitchen_flash()
	queue_redraw()

func update_game(delta: float) -> void:
	"""Main game update"""
	# Update establishment timers
	for data in [player_data, partner_data, opponent1_data, opponent2_data]:
		if data.establishment_timer > 0:
			data.establishment_timer -= delta
			if data.establishment_timer <= 0:
				data.feet_established = true
				data.was_in_kitchen = false

		if data.momentum_timer > 0:
			data.momentum_timer -= delta

func update_player_movement(delta: float) -> void:
	"""Update player auto-movement"""
	if not player_node or game_state.waiting_for_serve:
		return

	var ball = get_node_or_null("Ball")
	if not ball:
		return

	var ball_court_pos = ball.screen_to_court(ball.global_position) if ball.has_method("screen_to_court") else Vector2.ZERO
	var ball_on_our_side = ball_court_pos.y > NET_Y

	check_hit_opportunity(player_node, player_data, ball, ball_court_pos)
	check_hit_opportunity(partner_node, partner_data, ball, ball_court_pos)

	if game_state.ball_in_play:
		update_player_position(player_data, ball, ball_court_pos, delta, true)
		update_player_position(partner_data, ball, ball_court_pos, delta, false)

		update_character_screen_position(player_node, player_data)
		update_character_screen_position(partner_node, partner_data)

		update_paddle_aim(player_node, ball)
		update_paddle_aim(partner_node, ball)

func update_player_position(data: Dictionary, ball: Node2D, ball_court_pos: Vector2, delta: float, is_player: bool) -> void:
	"""Update a player's court position"""
	var ball_on_our_side = ball_court_pos.y > NET_Y
	var ball_coming_to_us = ball.velocity.y > 0  # Positive Y means moving toward player side
	var speed = (PLAYER_SPEED if is_player else PARTNER_SPEED) * delta

	if game_state.kitchen_mastery and is_player:
		speed *= 1.3

	# Move to intercept when ball is on our side OR coming to us
	var should_intercept = ball_on_our_side or (ball_coming_to_us and ball.last_hit_team == "opponent")

	if should_intercept and should_cover_ball(data, ball_court_pos):
		# Better prediction using ball trajectory
		var time_to_land = 0.0
		if ball.vertical_velocity != 0:
			time_to_land = (ball.height + ball.vertical_velocity / GRAVITY) / 50.0
		time_to_land = max(time_to_land, 0.3)

		var predicted_x = ball_court_pos.x + ball.velocity.x * time_to_land * 0.004
		var predicted_y = ball_court_pos.y + ball.velocity.y * time_to_land * 0.004

		predicted_x = clamp(predicted_x, 30, COURT_WIDTH - 30)
		predicted_y = clamp(predicted_y, NET_Y + 20, BASELINE_BOTTOM - 20)

		if is_player and kitchen_system and kitchen_system.current_state == 2:
			data.target_court_y = clamp(predicted_y, NET_Y + 10, KITCHEN_LINE_BOTTOM - 5)
		else:
			data.target_court_y = max(predicted_y, KITCHEN_LINE_BOTTOM + 10)

		data.target_court_x = predicted_x
	else:
		data.target_court_x = data.default_x
		data.target_court_y = data.default_y

	# Smooth movement
	var dx = data.target_court_x - data.court_x
	var dy = data.target_court_y - data.court_y
	var dist = sqrt(dx*dx + dy*dy)

	if dist > speed:
		data.court_x += (dx / dist) * speed
		data.court_y += (dy / dist) * speed
	else:
		data.court_x = data.target_court_x
		data.court_y = data.target_court_y

	# Enforce boundaries
	if not data.in_kitchen:
		data.court_y = max(data.court_y, KITCHEN_LINE_BOTTOM + 5)

	# Track kitchen status
	var was_in = data.in_kitchen
	data.in_kitchen = (data.court_y >= NET_Y and data.court_y <= KITCHEN_LINE_BOTTOM)

	if not was_in and data.in_kitchen:
		data.was_in_kitchen = true
		data.feet_established = false
	elif was_in and not data.in_kitchen:
		data.establishment_timer = 0.5

func should_cover_ball(data: Dictionary, ball_pos: Vector2) -> bool:
	"""Check if this player should cover the ball"""
	if data.court_side == "right":
		return ball_pos.x > COURT_WIDTH * 0.4
	else:
		return ball_pos.x < COURT_WIDTH * 0.6

func calculate_time_to_reach(data: Dictionary, ball_pos: Vector2, ball: Node2D) -> float:
	"""Estimate time for ball to reach player"""
	var dx = ball_pos.x - data.court_x
	var dy = ball_pos.y - data.court_y
	var dist = sqrt(dx*dx + dy*dy)
	return dist / PLAYER_SPEED

func check_hit_opportunity(character: CharacterBody2D, data: Dictionary, ball: Node2D, ball_court_pos: Vector2) -> void:
	"""Check if player can hit the ball"""
	var screen_dist = character.global_position.distance_to(ball.global_position)
	var time_since_hit = Time.get_ticks_msec() - data.last_hit_time

	# More lenient hit detection for better gameplay
	var hit_dist = HIT_DISTANCE * 1.3  # Slightly larger hit zone (104 pixels)

	data.can_hit = screen_dist < hit_dist and \
				   ball.height < 50 and \
				   ball.height >= 0 and \
				   ball_court_pos.y > NET_Y - 20 and \
				   ball.in_flight and \
				   time_since_hit > HIT_COOLDOWN * 1000 and \
				   ball.last_hit_team == "opponent"

	if character.has_node("Sprite"):
		character.get_node("Sprite").modulate = Color(1.5, 1.5, 1.5) if data.can_hit else Color.WHITE

func update_paddle_aim(character: CharacterBody2D, ball: Node2D) -> void:
	"""Update paddle rotation to aim at ball"""
	var paddle = character.get_node_or_null("Paddle")
	if paddle:
		var to_ball = (ball.global_position - character.global_position).normalized()
		paddle.rotation = to_ball.angle() - PI/2

func update_ai_players(delta: float) -> void:
	"""Update AI-controlled players"""
	var ball = get_node_or_null("Ball")
	if not ball or not game_state.ball_in_play:
		return

	# Update partner AI
	if partner_ai and partner_data.can_hit:
		var decision = partner_ai.update(delta, ball)
		if decision.should_hit and ball.last_hit_team == "opponent":
			execute_ai_hit(partner_data, ball, decision.shot_type)

	# Update opponents
	update_opponents(delta, ball)

func update_opponents(delta: float, ball: Node2D) -> void:
	"""Update opponent AI movement and hitting"""
	var ball_court_pos = ball.screen_to_court(ball.global_position) if ball.has_method("screen_to_court") else Vector2.ZERO
	var ball_on_their_side = ball_court_pos.y < NET_Y
	var ball_coming_to_them = ball.velocity.y < 0  # Negative Y means moving toward opponent side

	for opp_data in [opponent1_data, opponent2_data]:
		# Opponents should move to intercept when ball is coming to them OR on their side
		if ball_on_their_side or (ball_coming_to_them and ball.last_hit_team == "player"):
			# Calculate where ball will land based on trajectory
			var time_to_land = 0.0
			if ball.vertical_velocity != 0:
				# Estimate time for ball to reach ground (simplified)
				time_to_land = (ball.height + ball.vertical_velocity / GRAVITY) / 50.0
			time_to_land = max(time_to_land, 0.3)  # At least 0.3 seconds prediction

			# Predict ball landing position
			var predicted_x = ball_court_pos.x + ball.velocity.x * time_to_land * 0.005
			var predicted_y = ball_court_pos.y + ball.velocity.y * time_to_land * 0.005

			predicted_x = clamp(predicted_x, 30, COURT_WIDTH - 30)
			predicted_y = clamp(predicted_y, BASELINE_TOP + 30, KITCHEN_LINE_TOP + 30)

			if should_opponent_cover(opp_data, Vector2(predicted_x, predicted_y)):
				opp_data.target_court_x = predicted_x
				# Move forward to intercept, stay behind kitchen line
				opp_data.target_court_y = clamp(predicted_y + 10, BASELINE_TOP + 30, KITCHEN_LINE_TOP - 5)
			else:
				# Move to cover position
				opp_data.target_court_x = opp_data.default_x
				opp_data.target_court_y = min(predicted_y + 30, KITCHEN_LINE_TOP - 5)
		else:
			# Return to default position when ball is on player's side
			opp_data.target_court_x = opp_data.default_x
			opp_data.target_court_y = opp_data.default_y

		# Move opponent with increased speed
		var speed = OPPONENT_SPEED * 1.3 * delta  # 30% faster for better interception
		var dx = opp_data.target_court_x - opp_data.court_x
		var dy = opp_data.target_court_y - opp_data.court_y
		var dist = sqrt(dx*dx + dy*dy)

		if dist > speed:
			opp_data.court_x += (dx / dist) * speed
			opp_data.court_y += (dy / dist) * speed
		else:
			opp_data.court_x = opp_data.target_court_x
			opp_data.court_y = opp_data.target_court_y

		# Keep opponents behind kitchen line
		opp_data.court_y = min(opp_data.court_y, KITCHEN_LINE_TOP - 5)

		# Check hit opportunity
		check_opponent_hit(opp_data, ball, ball_court_pos, delta)

func should_opponent_cover(opp_data: Dictionary, ball_pos: Vector2) -> bool:
	"""Check if opponent should cover ball"""
	if opp_data.court_side == "right":
		return ball_pos.x > COURT_WIDTH * 0.4
	else:
		return ball_pos.x < COURT_WIDTH * 0.6

func check_opponent_hit(opp_data: Dictionary, ball: Node2D, ball_court_pos: Vector2, delta: float) -> void:
	"""Check and execute opponent hit"""
	# Use screen distance for consistency with player hit detection
	var opp_screen_pos = court_to_screen(opp_data.court_x, opp_data.court_y)
	var screen_dist = opp_screen_pos.distance_to(ball.global_position)
	var time_since_hit = Time.get_ticks_msec() - opp_data.last_hit_time

	# More lenient hit distance for opponents to ensure they can return
	var hit_dist = HIT_DISTANCE * 1.5  # 120 pixels for more reliable returns

	# Check if opponent can hit (ball is close enough, on their side, bounced, from player)
	opp_data.can_hit = screen_dist < hit_dist and \
					   ball.height < 60 and \
					   ball.height >= 0 and \
					   ball_court_pos.y < NET_Y + 20 and \
					   ball.in_flight and \
					   time_since_hit > HIT_COOLDOWN * 1000 and \
					   ball.bounces > 0 and \
					   ball.last_hit_team == "player"

	# High chance to hit when in range - opponents are skilled!
	if opp_data.can_hit:
		execute_opponent_hit(opp_data, ball)

func execute_ai_hit(data: Dictionary, ball: Node2D, shot_type: String) -> void:
	"""Execute AI partner hit"""
	var target_x = COURT_WIDTH * (0.25 + randf() * 0.5)
	var target_y = BASELINE_TOP + randf() * (NET_Y - BASELINE_TOP - 20)
	var target_screen = court_to_screen(target_x, target_y)

	var dx = target_screen.x - ball.position.x
	var dy = target_screen.y - ball.position.y
	var angle = atan2(dy, dx)

	ball.velocity = Vector2(cos(angle) * 200, sin(angle) * 200)
	ball.vertical_velocity = 100 + randf() * 40
	ball.height = max(ball.height, 10.0)
	ball.bounces = 0
	ball.bounces_on_current_side = 0
	ball.last_hit_team = "player"
	ball.in_flight = true

	data.last_hit_time = Time.get_ticks_msec()
	data.can_hit = false

	game_state.consecutive_hits += 1
	game_state.rally_count += 1

	AudioManager.play_hit(0.5, ball.global_position)
	show_message("Partner!", data.court_x, data.court_y - 20, Color(0.2, 0.6, 0.9))

func execute_opponent_hit(opp_data: Dictionary, ball: Node2D) -> void:
	"""Execute opponent hit"""
	var target_data = player_data if randf() > 0.5 else partner_data
	var target_screen = court_to_screen(target_data.court_x, target_data.court_y + 50)

	var dx = target_screen.x - ball.position.x
	var dy = target_screen.y - ball.position.y
	var angle = atan2(dy, dx)

	ball.velocity = Vector2(cos(angle) * 200, sin(angle) * 200)
	ball.vertical_velocity = 100
	ball.height = max(ball.height, 10.0)
	ball.bounces = 0
	ball.bounces_on_current_side = 0
	ball.last_hit_team = "opponent"
	ball.in_flight = true

	opp_data.last_hit_time = Time.get_ticks_msec()
	opp_data.can_hit = false

	game_state.consecutive_hits += 1
	game_state.rally_count += 1

	AudioManager.play_hit(0.5, ball.global_position)
	show_message("Return!", opp_data.court_x, opp_data.court_y - 20, Color(0.8, 0.2, 0.2))

# =================== VIOLATION HANDLING ===================
func handle_violation(data: Dictionary, violation: Dictionary) -> void:
	"""Handle a detected violation"""
	var team = "opponent" if data.is_opponent else "player"

	show_message("FAULT!", data.court_x, data.court_y - 40, Color(1.0, 0, 0))
	show_message(violation.message, COURT_WIDTH/2, COURT_HEIGHT/2, Color(1.0, 0.26, 0.21))

	flash_kitchen_zone(not data.is_opponent)
	game_state.kitchen_violations[team] += 1

	if kitchen_system and team == "player":
		kitchen_system.update_pressure(-20.0)

	AudioManager.play_fault()
	fault_occurred(team)

func fault_occurred(faulting_team: String) -> void:
	"""Handle fault and award point"""
	game_state.ball_in_play = false

	var winning_team = "opponent" if faulting_team == "player" else "player"
	point_scored(winning_team)

func point_scored(winning_team: String) -> void:
	"""Handle point being scored"""
	game_state.ball_in_play = false
	game_state.first_bounce_complete = false
	game_state.second_bounce_complete = false
	game_state.consecutive_hits = 0
	game_state.bounces_on_current_side = 0
	game_state.is_serve_in_progress = false
	game_state.is_dink_rally = false

	# Reset kitchen states
	if kitchen_system:
		kitchen_system.reset()

	# Award pressure for long rallies
	if game_state.rally_length > 10 and kitchen_system:
		kitchen_system.update_pressure(20.0)
		show_message("Long Rally Bonus!", COURT_WIDTH/2, COURT_HEIGHT/2, Color(0.3, 0.69, 0.31))

	# Update scoring
	if scoring_system:
		scoring_system.rally_won_by(winning_team)
	else:
		# Fallback scoring
		if winning_team == game_state.serving_team:
			if winning_team == "player":
				game_state.player_score += 1
			else:
				game_state.opponent_score += 1
			show_message("Point!", COURT_WIDTH/2, COURT_HEIGHT/2, Color(0.3, 0.69, 0.31))
		else:
			handle_side_out()
			show_message("Side Out!", COURT_WIDTH/2, COURT_HEIGHT/2, Color(1.0, 0.6, 0))

	game_state.rally_length = 0
	update_ui()

	# Reset for next point
	get_tree().create_timer(1.5).timeout.connect(reset_for_next_point)

func handle_side_out() -> void:
	"""Handle side out"""
	if game_state.is_first_serve_of_game:
		game_state.serving_team = "opponent" if game_state.serving_team == "player" else "player"
		game_state.server_number = 1
		game_state.is_first_serve_of_game = false
	elif game_state.server_number == 1:
		game_state.server_number = 2
	else:
		game_state.serving_team = "opponent" if game_state.serving_team == "player" else "player"
		game_state.server_number = 1

func reset_for_next_point() -> void:
	"""Reset positions for next point"""
	reset_positions()
	update_ui()

func reset_positions() -> void:
	"""Reset all player positions"""
	player_data.is_serving = false
	partner_data.is_serving = false
	opponent1_data.is_serving = false
	opponent2_data.is_serving = false

	if game_state.serving_team == "player":
		if game_state.server_number == 2:
			player_data.is_serving = true
		else:
			partner_data.is_serving = true

		player_data.court_x = COURT_WIDTH * 0.75
		player_data.court_y = BASELINE_BOTTOM - 20 if player_data.is_serving else BASELINE_BOTTOM - SERVICE_LINE_DEPTH
		partner_data.court_x = COURT_WIDTH * 0.25
		partner_data.court_y = BASELINE_BOTTOM - SERVICE_LINE_DEPTH
	else:
		opponent1_data.is_serving = game_state.server_number == 2
		opponent2_data.is_serving = game_state.server_number == 1

		player_data.court_x = COURT_WIDTH * 0.75
		player_data.court_y = BASELINE_BOTTOM - SERVICE_LINE_DEPTH
		partner_data.court_x = COURT_WIDTH * 0.25
		partner_data.court_y = BASELINE_BOTTOM - SERVICE_LINE_DEPTH

	opponent1_data.court_x = COURT_WIDTH * 0.75
	opponent1_data.court_y = BASELINE_TOP + SERVICE_LINE_DEPTH
	opponent2_data.court_x = COURT_WIDTH * 0.25
	opponent2_data.court_y = BASELINE_TOP + SERVICE_LINE_DEPTH

	# Update screen positions
	update_character_screen_position(player_node, player_data)
	update_character_screen_position(partner_node, partner_data)

	game_state.waiting_for_serve = true
	game_state.can_serve = game_state.serving_team == "player" and player_data.is_serving

	if game_state.can_serve:
		update_instructions("Your serve - Swipe up!")
	elif game_state.serving_team == "player":
		update_instructions("Partner serving...")
		get_tree().create_timer(2.0).timeout.connect(partner_serve)
	else:
		update_instructions("Opponent serving...")
		get_tree().create_timer(2.0).timeout.connect(opponent_serve)

func partner_serve() -> void:
	"""Execute partner serve"""
	if not partner_data.is_serving:
		return

	var ball = get_node_or_null("Ball")
	if ball:
		game_state.ball_in_play = true
		game_state.waiting_for_serve = false

		ball.global_position = court_to_screen(partner_data.court_x, partner_data.court_y - 15)
		ball.receive_serve(-PI/2, 0.6)
		ball.last_hit_team = "player"

		game_state.is_serve_in_progress = true
		game_state.expected_service_box = "left"

		AudioManager.play_serve(ball.global_position)
		show_message("Partner Serves!", partner_data.court_x, partner_data.court_y - 30, Color(0.2, 0.6, 0.9))
		update_instructions("Rally in play!")

func opponent_serve() -> void:
	"""Execute opponent serve"""
	var server = opponent1_data if opponent1_data.is_serving else opponent2_data

	var ball = get_node_or_null("Ball")
	if ball:
		game_state.ball_in_play = true
		game_state.waiting_for_serve = false

		ball.global_position = court_to_screen(server.court_x, server.court_y + 15)
		ball.receive_serve(PI/2, 0.6)
		ball.last_hit_team = "opponent"

		game_state.is_serve_in_progress = true

		AudioManager.play_serve(ball.global_position)
		show_message("Opponent Serves!", server.court_x, server.court_y + 30, Color(0.8, 0.2, 0.2))
		update_instructions("Rally in play!")

# =================== MASTERY MODE ===================
func activate_mastery_mode() -> void:
	"""Activate kitchen mastery mode"""
	game_state.kitchen_mastery = true
	game_state.kitchen_mastery_timer = 8.0

	if kitchen_system:
		kitchen_system.pressure = 0

	show_message("KITCHEN MASTERY ACTIVE!", COURT_WIDTH/2, COURT_HEIGHT/2, Color(1.0, 0.84, 0))
	AudioManager.play_mastery_activation()

	if player_node:
		player_node.get_node("Sprite").modulate = Color(1.2, 1.0, 0.8)

	if tutorial_manager and tutorial_manager.is_tutorial_active():
		tutorial_manager.check_action("mastery_activated")

func end_mastery_mode() -> void:
	"""End mastery mode"""
	game_state.kitchen_mastery = false

	if player_node:
		player_node.get_node("Sprite").modulate = Color.WHITE

	show_message("Mastery ended", COURT_WIDTH/2, NET_Y, Color(1.0, 0.84, 0))

# =================== SIGNAL HANDLERS ===================
func _on_kitchen_opportunity() -> void:
	show_message("Kitchen Available!", COURT_WIDTH/2, NET_Y + 50, Color(1.0, 0.84, 0))

func _on_kitchen_entered() -> void:
	show_message("Entered Kitchen!", COURT_WIDTH/2, NET_Y, Color(1.0, 0.84, 0))
	if tutorial_manager and tutorial_manager.is_tutorial_active():
		tutorial_manager.check_action("kitchen_entered")

func _on_kitchen_exited() -> void:
	show_message("Exited Kitchen", COURT_WIDTH/2, NET_Y, Color(0.3, 0.69, 0.31))

func _on_kitchen_violation(violation_type: String, message: String) -> void:
	show_message("FAULT! " + message, COURT_WIDTH/2, COURT_HEIGHT/2, Color(1.0, 0, 0))
	flash_kitchen_zone(true)

func _on_pressure_changed(new_value: float) -> void:
	game_state.kitchen_pressure = new_value
	if tutorial_manager and tutorial_manager.is_tutorial_active():
		tutorial_manager.check_action("pressure_updated", {"pressure": new_value})
	update_ui()

func _on_kitchen_state_changed(new_state: int) -> void:
	game_state.kitchen_state = new_state
	update_ui()

func _on_score_updated(p_score: int, o_score: int, server_num: int) -> void:
	game_state.player_score = p_score
	game_state.opponent_score = o_score
	game_state.server_number = server_num
	update_ui()

func _on_game_over(winner: String) -> void:
	game_state.game_active = false
	var message = "You Win!" if winner == "player" else "Opponent Wins!"
	show_message(message, COURT_WIDTH/2, COURT_HEIGHT/2, Color(1.0, 0.84, 0))
	update_instructions("Game Over! " + message)

func _on_serve_valid(bounce_pos: Vector2) -> void:
	show_message("Good Serve!", COURT_WIDTH/2, NET_Y, Color(0.3, 0.69, 0.31))

func _on_serve_fault(fault_type: String, message: String) -> void:
	show_message(message, COURT_WIDTH/2, COURT_HEIGHT/2, Color(1.0, 0.26, 0.21))
	fault_occurred(game_state.serving_team)

func _on_double_bounce_complete() -> void:
	game_state.second_bounce_complete = true

func _on_double_bounce_violation(team: String) -> void:
	show_message("Must let ball bounce!", COURT_WIDTH/2, COURT_HEIGHT/2, Color(1.0, 0.26, 0.21))
	fault_occurred(team)

func _on_violation_detected(violator: String, violation_type: String, message: String) -> void:
	show_message("FAULT! " + message, COURT_WIDTH/2, COURT_HEIGHT/2, Color(1.0, 0, 0))
	var team = "opponent" if "Opponent" in violator else "player"
	fault_occurred(team)

# =================== UI & RENDERING ===================
func init_game() -> void:
	"""Initialize a new game"""
	game_state.game_active = true
	game_state.serving_team = "player"
	game_state.server_number = 2
	game_state.is_first_serve_of_game = true
	game_state.waiting_for_serve = true
	game_state.can_serve = true

	if scoring_system:
		scoring_system.reset()

	reset_positions()
	update_ui()

func update_ui() -> void:
	"""Update all UI elements"""
	var score_label = get_node_or_null("UI/HUD/TopPanel/ScoreLabel")
	if score_label:
		score_label.text = "%d-%d-%d" % [game_state.player_score, game_state.opponent_score, game_state.server_number]

	var violations_label = get_node_or_null("UI/HUD/TopPanel/ViolationsLabel")
	if violations_label:
		violations_label.text = "KV:%d" % game_state.kitchen_violations.player

func update_instructions(text: String) -> void:
	"""Update instruction text"""
	var instructions = get_node_or_null("UI/HUD/Instructions")
	if instructions:
		instructions.text = text

func show_message(text: String, x: float, y: float, color: Color, duration: float = 1.0) -> void:
	"""Show a floating message"""
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
	"""Update message positions and lifetimes"""
	var to_remove = []
	for i in range(messages.size()):
		var msg = messages[i]
		msg.life -= delta
		msg.y += msg.vy
		if msg.life <= 0:
			to_remove.append(i)

	for i in range(to_remove.size() - 1, -1, -1):
		messages.remove_at(to_remove[i])

func flash_kitchen_zone(is_player_side: bool) -> void:
	"""Flash kitchen zone for violation feedback"""
	game_state.kitchen_flash = {
		"active": true,
		"side": "player" if is_player_side else "opponent",
		"start_time": Time.get_ticks_msec(),
		"duration": 1000
	}

func update_kitchen_flash() -> void:
	"""Update kitchen flash effect"""
	if game_state.kitchen_flash and game_state.kitchen_flash.active:
		var elapsed = Time.get_ticks_msec() - game_state.kitchen_flash.start_time
		if elapsed > game_state.kitchen_flash.duration:
			game_state.kitchen_flash = null

# =================== COORDINATE CONVERSION ===================
func get_visual_court_bounds(y: float) -> Dictionary:
	"""Get court bounds at given Y with perspective"""
	var perspective_factor = 1.0 - (1.0 - PERSPECTIVE_SCALE) * (1.0 - y / COURT_HEIGHT)
	var visual_width = COURT_WIDTH * perspective_factor
	var left_bound = (COURT_WIDTH - visual_width) / 2.0
	var right_bound = COURT_WIDTH - left_bound
	return {"left": left_bound, "right": right_bound, "width": visual_width}

func court_to_screen(x: float, y: float) -> Vector2:
	"""Convert court coordinates to screen coordinates"""
	var center_x = screen_width / 2.0
	var court_top = COURT_OFFSET_Y * court_scale

	var perspective_factor = 1.0 - (1.0 - PERSPECTIVE_SCALE) * (1.0 - y / COURT_HEIGHT)
	var visual_bounds = get_visual_court_bounds(y)

	var normalized_x = x / COURT_WIDTH
	var visual_x = visual_bounds.left + normalized_x * visual_bounds.width

	var screen_x = center_x + (visual_x - COURT_WIDTH / 2.0) * perspective_factor * court_scale
	var screen_y = court_top + y * 0.9 * court_scale

	return Vector2(screen_x, screen_y)

# =================== DRAWING ===================
func _draw() -> void:
	draw_court()
	draw_opponents()
	draw_messages()

func draw_court() -> void:
	"""Draw the court with perspective"""
	var center_x = screen_width / 2.0
	var court_top = COURT_OFFSET_Y * court_scale

	# Court surface
	var top_left = Vector2(center_x - (COURT_WIDTH / 2.0) * PERSPECTIVE_SCALE * court_scale, court_top)
	var top_right = Vector2(center_x + (COURT_WIDTH / 2.0) * PERSPECTIVE_SCALE * court_scale, court_top)
	var bottom_left = Vector2(center_x - (COURT_WIDTH / 2.0) * court_scale, court_top + COURT_HEIGHT * 0.9 * court_scale)
	var bottom_right = Vector2(center_x + (COURT_WIDTH / 2.0) * court_scale, court_top + COURT_HEIGHT * 0.9 * court_scale)

	draw_colored_polygon(PackedVector2Array([top_left, top_right, bottom_right, bottom_left]), Color(0.18, 0.49, 0.20))

	# Court texture lines
	for i in range(11):
		var y_factor = i / 10.0
		var left_x = lerp(top_left.x, bottom_left.x, y_factor)
		var right_x = lerp(top_right.x, bottom_right.x, y_factor)
		var screen_y = lerp(top_left.y, bottom_left.y, y_factor)
		draw_line(Vector2(left_x, screen_y), Vector2(right_x, screen_y), Color(0.14, 0.42, 0.21), 1.0)

	# Kitchen zones
	draw_kitchen_zones(center_x, court_top)

	# Court lines
	draw_court_lines(center_x, court_top)

	# Net
	draw_net(center_x, court_top)

func draw_kitchen_zones(center_x: float, court_top: float) -> void:
	"""Draw kitchen zones with appropriate colors"""
	var kitchen_color = Color(1.0, 0.78, 0, 0.06)
	if kitchen_system and kitchen_system.current_state == 2:
		kitchen_color = Color(1.0, 0.78, 0, 0.15)

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

	var top_color = kitchen_color
	if game_state.kitchen_flash and game_state.kitchen_flash.side == "opponent":
		var flash_progress = float(Time.get_ticks_msec() - game_state.kitchen_flash.start_time) / game_state.kitchen_flash.duration
		top_color = Color(1.0, 0, 0, 0.5 * (1.0 - flash_progress))

	draw_colored_polygon(top_kitchen_points, top_color)

	# Bottom kitchen
	var bottom_kitchen_points = PackedVector2Array([
		Vector2(center_x - (COURT_WIDTH/2.0) * net_scale * court_scale, net_pos.y),
		Vector2(center_x + (COURT_WIDTH/2.0) * net_scale * court_scale, net_pos.y),
		Vector2(center_x + (COURT_WIDTH/2.0) * bottom_kitchen_scale * court_scale, kitchen_bottom_pos.y),
		Vector2(center_x - (COURT_WIDTH/2.0) * bottom_kitchen_scale * court_scale, kitchen_bottom_pos.y)
	])

	var bottom_color = kitchen_color
	if game_state.kitchen_flash and game_state.kitchen_flash.side == "player":
		var flash_progress = float(Time.get_ticks_msec() - game_state.kitchen_flash.start_time) / game_state.kitchen_flash.duration
		bottom_color = Color(1.0, 0, 0, 0.5 * (1.0 - flash_progress))

	draw_colored_polygon(bottom_kitchen_points, bottom_color)

	# Kitchen labels
	var font = ThemeDB.fallback_font
	draw_string(font, Vector2(center_x - 30, net_pos.y - 30), "KITCHEN", HORIZONTAL_ALIGNMENT_CENTER, -1, 11, Color(1, 1, 1, 0.4))
	draw_string(font, Vector2(center_x - 30, net_pos.y + 35), "KITCHEN", HORIZONTAL_ALIGNMENT_CENTER, -1, 11, Color(1, 1, 1, 0.4))

func draw_court_lines(center_x: float, court_top: float) -> void:
	"""Draw court boundary lines"""
	var top_left = Vector2(center_x - (COURT_WIDTH / 2.0) * PERSPECTIVE_SCALE * court_scale, court_top)
	var top_right = Vector2(center_x + (COURT_WIDTH / 2.0) * PERSPECTIVE_SCALE * court_scale, court_top)
	var bottom_left = Vector2(center_x - (COURT_WIDTH / 2.0) * court_scale, court_top + COURT_HEIGHT * 0.9 * court_scale)
	var bottom_right = Vector2(center_x + (COURT_WIDTH / 2.0) * court_scale, court_top + COURT_HEIGHT * 0.9 * court_scale)

	# Boundary
	draw_line(top_left, top_right, Color.WHITE, 3.0)
	draw_line(top_right, bottom_right, Color.WHITE, 3.0)
	draw_line(bottom_right, bottom_left, Color.WHITE, 3.0)
	draw_line(bottom_left, top_left, Color.WHITE, 3.0)

	# Kitchen lines
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

	# Center lines
	var baseline_top_pos = court_to_screen(COURT_WIDTH/2.0, BASELINE_TOP)
	var baseline_bottom_pos = court_to_screen(COURT_WIDTH/2.0, BASELINE_BOTTOM)

	draw_line(Vector2(center_x, baseline_top_pos.y), Vector2(center_x, kitchen_top_pos.y), Color(1, 1, 1, 0.7), 2.0)
	draw_line(Vector2(center_x, kitchen_bottom_pos.y), Vector2(center_x, baseline_bottom_pos.y), Color(1, 1, 1, 0.7), 2.0)

func draw_net(center_x: float, court_top: float) -> void:
	"""Draw the net"""
	var net_pos = court_to_screen(COURT_WIDTH/2.0, NET_Y)
	var net_scale = 1.0 - (1.0 - PERSPECTIVE_SCALE) * (1.0 - NET_Y / COURT_HEIGHT)

	draw_line(
		Vector2(center_x - (COURT_WIDTH/2.0) * net_scale * court_scale, net_pos.y),
		Vector2(center_x + (COURT_WIDTH/2.0) * net_scale * court_scale, net_pos.y),
		Color.BLACK, 4.0
	)
	draw_line(
		Vector2(center_x - (COURT_WIDTH/2.0) * net_scale * court_scale, net_pos.y),
		Vector2(center_x + (COURT_WIDTH/2.0) * net_scale * court_scale, net_pos.y),
		Color.WHITE, 2.0
	)

func draw_dashed_line_custom(from: Vector2, to: Vector2, color: Color, width: float, dash_length: float, gap_length: float) -> void:
	"""Draw a dashed line"""
	var direction = (to - from).normalized()
	var total_length = from.distance_to(to)
	var current_length = 0.0

	while current_length < total_length:
		var dash_start = from + direction * current_length
		var dash_end = from + direction * min(current_length + dash_length, total_length)
		draw_line(dash_start, dash_end, color, width)
		current_length += dash_length + gap_length

func draw_opponents() -> void:
	"""Draw opponent characters"""
	var opp1_pos = court_to_screen(opponent1_data.court_x, opponent1_data.court_y)
	draw_circle(opp1_pos, 18, Color(0.8, 0.2, 0.2))
	draw_arc(opp1_pos, 18, 0, TAU, 32, Color.BLACK, 2.0)

	var opp2_pos = court_to_screen(opponent2_data.court_x, opponent2_data.court_y)
	draw_circle(opp2_pos, 18, Color(0.7, 0.2, 0.3))
	draw_arc(opp2_pos, 18, 0, TAU, 32, Color.BLACK, 2.0)

	var font = ThemeDB.fallback_font
	draw_string(font, opp1_pos + Vector2(-5, 5), "O1", HORIZONTAL_ALIGNMENT_CENTER, -1, 12, Color.WHITE)
	draw_string(font, opp2_pos + Vector2(-5, 5), "O2", HORIZONTAL_ALIGNMENT_CENTER, -1, 12, Color.WHITE)

func draw_messages() -> void:
	"""Draw floating messages"""
	var font = ThemeDB.fallback_font
	for msg in messages:
		var alpha = min(msg.life, 1.0)
		var color = Color(msg.color.r, msg.color.g, msg.color.b, alpha)
		draw_string(font, Vector2(msg.x - 40, msg.y), msg.text, HORIZONTAL_ALIGNMENT_CENTER, -1, 14, color)
