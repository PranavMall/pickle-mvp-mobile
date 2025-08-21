# Main.gd - Complete Day 4 Implementation with Partner
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
const PARTNER_SPEED: float = 170.0  # Slightly slower than player
const BALL_RADIUS: float = 8.0
const GRAVITY: float = 160.0
const HIT_DISTANCE: float = 60.0
const HIT_COOLDOWN: float = 0.8
const MIN_PLAYER_DISTANCE: float = 80.0  # Minimum distance between player and partner

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

# Player nodes
var player_node = null
var partner_node = null

# TEMPORARY OPPONENT FOR TESTING
var temp_opponent = null
var temp_opponent2 = null  # Second opponent for doubles

func _ready() -> void:
	# Get screen dimensions
	screen_width = get_viewport().size.x
	screen_height = get_viewport().size.y
	
	print("=== STARTING DAY 4 COMPLETE ===")
	
	# Calculate court scale to fit screen
	court_scale = min(screen_width / COURT_WIDTH, screen_height / (COURT_HEIGHT + COURT_OFFSET_Y * 2))
	
	# Initialize game
	init_game()
	
	# Create swipe detector
	create_swipe_detector()
	
	# Create player and partner
	await get_tree().process_frame
	create_player_team()
	
	# Create opponents for testing
	create_opponent_team()
	
	print("=== DAY 4 SETUP COMPLETE ===")

func create_player_team() -> void:
	print("Creating player team...")
	
	# CREATE PLAYER
	player_node = create_character("Player", Color(0.2, 0.4, 0.8), "right", true)
	
	# CREATE PARTNER
	partner_node = create_character("Partner", Color(0.2, 0.6, 0.9), "left", false)
	
	# Set initial positions
	reset_player_positions()
	
	print("Player team created")

func create_character(name: String, color: Color, court_side: String, is_player: bool) -> CharacterBody2D:
	var character = CharacterBody2D.new()
	character.name = name
	add_child(character)
	
	# Create visual sprite
	var sprite = Sprite2D.new()
	sprite.name = "Sprite"
	
	# Create circle texture
	var img = Image.create(36, 36, false, Image.FORMAT_RGBA8)
	
	for x in range(36):
		for y in range(36):
			var dx = x - 18.0
			var dy = y - 18.0
			var dist = sqrt(dx*dx + dy*dy)
			
			if dist <= 18:
				if dist <= 16:
					img.set_pixel(x, y, color)
				else:
					img.set_pixel(x, y, Color.BLACK)
			else:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
	
	sprite.texture = ImageTexture.create_from_image(img)
	sprite.z_index = 1
	character.add_child(sprite)
	
	# Add collision
	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 18
	collision.shape = shape
	character.add_child(collision)
	
	# Add court side label
	var label = Label.new()
	label.text = "Y" if is_player else "P"
	label.position = Vector2(-5, -5)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_font_size_override("font_size", 10)
	sprite.add_child(label)
	
	# Add small paddle visual
	var paddle = Sprite2D.new()
	paddle.name = "Paddle"
	var paddle_img = Image.create(6, 20, false, Image.FORMAT_RGBA8)
	paddle_img.fill(Color(0.5, 0.3, 0.1))  # Brown
	paddle.texture = ImageTexture.create_from_image(paddle_img)
	paddle.position = Vector2(15, 0)
	character.add_child(paddle)
	
	# Set metadata
	character.set_meta("court_side", court_side)
	character.set_meta("is_player", is_player)
	character.set_meta("in_kitchen", false)
	character.set_meta("can_hit", false)
	
	character.z_index = 50
	
	return character

func reset_player_positions() -> void:
	# Player on right side
	var player_court_x = COURT_WIDTH * 0.75
	var player_court_y = BASELINE_BOTTOM - SERVICE_LINE_DEPTH
	var player_pos = court_to_screen(player_court_x, player_court_y)
	player_node.position = player_pos
	
	# Partner on left side
	var partner_court_x = COURT_WIDTH * 0.25
	var partner_court_y = BASELINE_BOTTOM - SERVICE_LINE_DEPTH
	var partner_pos = court_to_screen(partner_court_x, partner_court_y)
	partner_node.position = partner_pos

func create_opponent_team() -> void:
	print("Creating opponent team...")
	
	# Simple opponent data structures
	temp_opponent = {
		"x": COURT_WIDTH * 0.75,
		"y": BASELINE_TOP + SERVICE_LINE_DEPTH,
		"can_hit": false,
		"last_hit_time": 0,
		"court_side": "right"
	}
	
	temp_opponent2 = {
		"x": COURT_WIDTH * 0.25,
		"y": BASELINE_TOP + SERVICE_LINE_DEPTH,
		"can_hit": false,
		"last_hit_time": 0,
		"court_side": "left"
	}
	
	print("Opponent team created")

func update_player_movement(delta: float) -> void:
	if not player_node or not partner_node:
		return
	
	var ball = get_node_or_null("Ball")
	if not ball:
		return
	
	# Don't move during serve
	if not game_state.ball_in_play or game_state.waiting_for_serve:
		return
	
	# Check ball in flight
	var ball_in_flight = ball.get("in_flight") if ball.has_method("get") else false
	if not ball_in_flight:
		return
	
	var ball_court_pos = ball.screen_to_court(ball.global_position)
	var ball_on_our_side = ball_court_pos.y > NET_Y
	
	if ball_on_our_side and game_state.consecutive_hits > 0:
		# Determine who should cover the ball
		var ball_on_right = ball.global_position.x > screen_width / 2
		
		# Calculate base speed with mastery boost
		var player_speed = PLAYER_SPEED * delta
		var partner_speed = PARTNER_SPEED * delta
		
		if game_state.kitchen_mastery:
			player_speed *= 1.3  # 30% boost during mastery
			partner_speed *= 1.2  # Partner gets smaller boost
		
		# PLAYER MOVEMENT (Right side primary)
		update_individual_player(player_node, ball, player_speed, ball_on_right or not partner_close_enough(ball))
		
		# PARTNER MOVEMENT (Left side primary)
		update_individual_player(partner_node, ball, partner_speed, not ball_on_right or not player_close_enough(ball))
		
		# PARTNER AI HIT LOGIC
		check_partner_hit(ball, delta)
		
		# COLLISION AVOIDANCE
		avoid_collision_between_players()

func update_individual_player(character: CharacterBody2D, ball: Node, speed: float, should_cover: bool) -> void:
	var is_player = character.get_meta("is_player", false)
	var in_kitchen = character.get_meta("in_kitchen", false)
	
	# Kitchen movement takes priority
	if is_player and game_state.kitchen_state == KitchenState.ACTIVE and in_kitchen:
		# Stay in kitchen position
		var kitchen_y = court_to_screen(COURT_WIDTH/2, NET_Y + 35).y
		character.position.y = lerp(character.position.y, kitchen_y, speed * 0.1)
	elif should_cover and not in_kitchen:
		# Move toward ball X position with prediction
		var time_to_reach = max(0, (ball.position.y - character.position.y) / max(ball.velocity.y, 1))
		var predicted_x = ball.position.x + ball.velocity.x * time_to_reach * 0.2
		var target_x = predicted_x
		
		if abs(character.position.x - target_x) > speed:
			if character.position.x < target_x:
				character.position.x += speed
			else:
				character.position.x -= speed
		else:
			character.position.x = target_x
	else:
		# Return to default position
		var court_side = character.get_meta("court_side", "right")
		var default_x = screen_width * (0.65 if court_side == "right" else 0.35)
		
		if abs(character.position.x - default_x) > speed:
			if character.position.x < default_x:
				character.position.x += speed
			else:
				character.position.x -= speed
	
	# Keep in bounds
	character.position.x = clamp(character.position.x, 40, screen_width - 40)
	
	# Check hit capability
	var dist_to_ball = character.position.distance_to(ball.position)
	if dist_to_ball < HIT_DISTANCE and ball.height < 40:
		character.get_node("Sprite").modulate = Color(1.2, 1.2, 1.2)
		character.set_meta("can_hit", true)
		
		# Aim paddle at ball
		var paddle = character.get_node_or_null("Paddle")
		if paddle:
			paddle.rotation = (ball.position - character.position).angle() - PI/2
	else:
		character.get_node("Sprite").modulate = Color.WHITE
		character.set_meta("can_hit", false)
		
		# Reset paddle
		var paddle = character.get_node_or_null("Paddle")
		if paddle:
			paddle.rotation = 0

func player_close_enough(ball: Node) -> bool:
	return player_node.position.distance_to(ball.position) < 150

func partner_close_enough(ball: Node) -> bool:
	return partner_node.position.distance_to(ball.position) < 150

func avoid_collision_between_players() -> void:
	var distance = player_node.position.distance_to(partner_node.position)
	
	if distance < MIN_PLAYER_DISTANCE:
		# Push players apart
		var direction = (player_node.position - partner_node.position).normalized()
		var push_distance = (MIN_PLAYER_DISTANCE - distance) / 2.0
		
		player_node.position += direction * push_distance
		partner_node.position -= direction * push_distance
		
		# Keep both in bounds
		player_node.position.x = clamp(player_node.position.x, 40, screen_width - 40)
		partner_node.position.x = clamp(partner_node.position.x, 40, screen_width - 40)

func check_partner_hit(ball: Node, delta: float) -> void:
	# Partner AI hit logic - only if partner can hit and player can't
	if not partner_node.get_meta("can_hit", false):
		return
	
	if player_node.get_meta("can_hit", false):
		return  # Let player have priority
	
	# Check if ball has bounced (required for serve/return)
	if game_state.consecutive_hits < 2 and ball.bounces == 0:
		return  # Must let serve/return bounce
	
	# Check if it's been hit by opponent
	if ball.last_hit_team != "opponent":
		return  # Don't hit our own shots
	
	# Partner decision making (skill-based)
	var partner_skill = 0.75  # Partner skill level
	var hit_chance = partner_skill * delta * 3  # Chance to hit per frame
	
	if randf() < hit_chance:
		# Partner hits the ball!
		print("Partner hitting ball!")
		
		# Calculate angle toward opponent court
		var target_x = COURT_WIDTH * (0.25 + randf() * 0.5)  # Random spot on opponent side
		var target_y = BASELINE_TOP + randf() * (NET_Y - BASELINE_TOP - 20)
		var target_screen = court_to_screen(target_x, target_y)
		
		var dx = target_screen.x - ball.position.x
		var dy = target_screen.y - ball.position.y
		var angle = atan2(dy, dx)
		
		# Add some randomness
		angle += (randf() - 0.5) * 0.3
		
		# Determine shot type
		var power = 0.4 + randf() * 0.4
		var shot_type = "normal"
		
		if randf() < 0.2:
			shot_type = "drop"
			power = 0.2 + randf() * 0.1
		elif randf() < 0.1:
			shot_type = "power"
			power = 0.7 + randf() * 0.3
		
		# Hit the ball
		ball.velocity = Vector2(cos(angle) * 200, sin(angle) * 200)
		ball.vertical_velocity = 100 + randf() * 40
		ball.height = max(ball.height, 10.0)
		ball.bounces = 0
		ball.bounces_on_current_side = 0
		ball.last_hit_team = "player"  # Partner is on player team
		ball.last_hit_by = partner_node
		ball.in_flight = true
		ball.ball_speed = 200
		
		game_state.consecutive_hits += 1
		game_state.rally_count += 1
		update_ui()
		
		# Visual feedback
		show_message("Partner!", partner_node.position.x, partner_node.position.y - 30, Color(0.2, 0.6, 0.9))
		
		# Reset partner can_hit
		partner_node.set_meta("can_hit", false)
		partner_node.get_node("Sprite").modulate = Color.WHITE

func handle_kitchen_button_press() -> void:
	if not player_node:
		return
	
	match game_state.kitchen_state:
		KitchenState.AVAILABLE:
			# Move player to kitchen
			game_state.kitchen_state = KitchenState.ACTIVE
			game_state.in_kitchen = true
			player_node.set_meta("in_kitchen", true)
			
			var kitchen_pos = court_to_screen(player_node.position.x, NET_Y + 35)
			player_node.position = kitchen_pos
			
			update_kitchen_pressure(5)
			show_message("Entered Kitchen!", COURT_WIDTH/2, NET_Y, Color(1.0, 0.84, 0))
			
		KitchenState.ACTIVE, KitchenState.MUST_EXIT:
			# Exit kitchen
			game_state.kitchen_state = KitchenState.DISABLED
			game_state.in_kitchen = false
			player_node.set_meta("in_kitchen", false)
			
			var exit_pos = court_to_screen(COURT_WIDTH * 0.75, BASELINE_BOTTOM - SERVICE_LINE_DEPTH)
			player_node.position = exit_pos
			
			show_message("Exited Kitchen", COURT_WIDTH/2, NET_Y, Color(0.3, 0.69, 0.31))

func update_kitchen_pressure(amount: float) -> void:
	game_state.kitchen_pressure = clamp(
		game_state.kitchen_pressure + amount,
		0,
		game_state.kitchen_pressure_max
	)
	
	# Update UI
	update_ui()
	
	# Check for mastery activation
	if game_state.kitchen_pressure >= game_state.kitchen_pressure_max and not game_state.kitchen_mastery:
		activate_mastery_mode()

func activate_mastery_mode() -> void:
	game_state.kitchen_mastery = true
	game_state.kitchen_mastery_timer = 8.0
	game_state.kitchen_pressure = 0
	
	show_message("KITCHEN MASTERY ACTIVE!", COURT_WIDTH/2, COURT_HEIGHT/2, Color(1.0, 0.84, 0))
	
	# Visual effect on player
	player_node.get_node("Sprite").modulate = Color(1.2, 1.0, 0.8)

func update_temp_opponent(delta: float) -> void:
	if not temp_opponent or not game_state.ball_in_play:
		return
	
	var ball = get_node_or_null("Ball")
	if not ball:
		return
	
	var ball_court_pos = ball.screen_to_court(ball.global_position)
	
	# Update both opponents
	for opp in [temp_opponent, temp_opponent2]:
		if ball_court_pos.y < NET_Y:
			# Determine which opponent should cover
			var ball_on_right = ball_court_pos.x > COURT_WIDTH / 2
			var should_cover = (opp.court_side == "right" and ball_on_right) or \
							  (opp.court_side == "left" and not ball_on_right)
			
			if should_cover:
				# Move toward ball
				var target_x = ball_court_pos.x
				var move_speed = 150.0 * delta
				
				if abs(opp.x - target_x) > move_speed:
					opp.x += sign(target_x - opp.x) * move_speed
				else:
					opp.x = target_x
			else:
				# Return to default position
				var default_x = COURT_WIDTH * (0.75 if opp.court_side == "right" else 0.25)
				var move_speed = 100.0 * delta
				
				if abs(opp.x - default_x) > move_speed:
					opp.x += sign(default_x - opp.x) * move_speed
			
			# Keep in bounds
			opp.x = clamp(opp.x, 20, COURT_WIDTH - 20)
			
			# Check if can hit
			var opp_screen_pos = court_to_screen(opp.x, opp.y)
			var dist_to_ball = opp_screen_pos.distance_to(ball.global_position)
			var time_since_hit = Time.get_ticks_msec() - opp.last_hit_time
			
			opp.can_hit = dist_to_ball < HIT_DISTANCE and \
						 ball.height < 40 and \
						 ball_court_pos.y < NET_Y and \
						 ball.in_flight and \
						 time_since_hit > HIT_COOLDOWN * 1000 and \
						 ball.bounces > 0
			
			# Hit the ball if possible (only one opponent hits)
			if opp.can_hit and (opp == temp_opponent or not temp_opponent.can_hit):
				opponent_hit_ball(opp, ball, ball_court_pos)

func opponent_hit_ball(opp: Dictionary, ball: Node, ball_court_pos: Vector2) -> void:
	print("Opponent hitting ball back!")
	
	# Target player or partner randomly
	var target_player = player_node if randf() > 0.5 else partner_node
	var target_court_pos = court_to_screen(COURT_WIDTH/2, BASELINE_BOTTOM - 100)
	
	# Calculate angle to target
	var dx = target_court_pos.x - ball.position.x
	var dy = target_court_pos.y - ball.position.y
	var angle = atan2(dy, dx)
	
	# Hit the ball
	ball.velocity = Vector2(cos(angle) * 200, sin(angle) * 200)
	ball.vertical_velocity = 100
	ball.height = max(ball.height, 10.0)
	ball.bounces = 0
	ball.bounces_on_current_side = 0
	ball.last_hit_team = "opponent"
	ball.in_flight = true
	ball.ball_speed = 200
	
	opp.last_hit_time = Time.get_ticks_msec()
	opp.can_hit = false
	
	show_message("Return!", opp.x, opp.y, Color(0.8, 0.2, 0.2))
	
	game_state.consecutive_hits += 1
	game_state.rally_count += 1

func create_swipe_detector() -> void:
	var swipe_detector = Node2D.new()
	swipe_detector.name = "SwipeDetector"
	swipe_detector.z_index = 150
	add_child(swipe_detector)
	
	var swipe_script = load("res://SwipeDetector.gd")
	if swipe_script:
		swipe_detector.set_script(swipe_script)
		
		if swipe_detector.has_method("_ready"):
			swipe_detector._ready()
		
		swipe_detector.swipe_completed.connect(_on_swipe_completed)
		swipe_detector.swipe_started.connect(_on_swipe_started)
		
		print("SwipeDetector created and connected")

func _on_swipe_started() -> void:
	print("Player starting swipe...")

func _on_swipe_completed(angle: float, power: float, shot_type: String) -> void:
	print("Swipe completed! Angle: ", angle, " Power: ", power, " Type: ", shot_type)
	
	# Handle serve
	if game_state.waiting_for_serve and game_state.can_serve:
		player_serve_with_swipe(angle, power)
		return
	
	# Handle regular hit - player takes priority, then partner
	if game_state.ball_in_play:
		var ball = get_node_or_null("Ball")
		if ball:
			if player_node.get_meta("can_hit", false):
				ball.receive_hit(angle, power, shot_type)
				game_state.rally_count += 1
				update_kitchen_pressure(3)
				update_ui()
				print("Player hit the ball!")
			elif partner_node.get_meta("can_hit", false):
				ball.receive_hit(angle, power, shot_type)
				game_state.rally_count += 1
				update_ui()
				print("Partner hit the ball!")
			else:
				print("Too far from ball to hit")

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
	game_state.expected_service_box = "left"
	
	var ball = get_node_or_null("Ball")
	if ball:
		var serve_pos = court_to_screen(COURT_WIDTH/2, COURT_HEIGHT - 50)
		ball.global_position = serve_pos
		ball.height = 40.0
		
		var serve_angle = angle if angle < -PI/4 else -PI/3
		var serve_power = max(power, 0.5)
		
		ball.receive_serve(serve_angle, serve_power)
		
		show_message("Serve!", COURT_WIDTH/2, COURT_HEIGHT - 30, Color.WHITE)
		
		var instructions = get_node_or_null("UI/HUD/Instructions")
		if instructions:
			instructions.text = "Rally in play!"
	
	game_state.game_active = true
	game_state.rally_count = 0

func _process(delta: float) -> void:
	if game_state.game_active:
		update_game(delta)
		update_temp_opponent(delta)
		update_player_movement(delta)
		
		# Update mastery timer
		if game_state.kitchen_mastery:
			game_state.kitchen_mastery_timer -= delta
			if game_state.kitchen_mastery_timer <= 0:
				end_mastery_mode()
	
	update_messages(delta)
	queue_redraw()

func _draw() -> void:
	draw_court()
	
	# Draw opponents
	if temp_opponent:
		var opp_pos = court_to_screen(temp_opponent.x, temp_opponent.y)
		draw_circle(opp_pos, 18, Color(0.8, 0.2, 0.2))
		draw_arc(opp_pos, 18, 0, TAU, 32, Color.BLACK, 2.0)
		var font = ThemeDB.fallback_font
		draw_string(font, opp_pos + Vector2(-5, 5), "O1", 
					HORIZONTAL_ALIGNMENT_CENTER, -1, 12, Color.WHITE)
	
	if temp_opponent2:
		var opp_pos = court_to_screen(temp_opponent2.x, temp_opponent2.y)
		draw_circle(opp_pos, 18, Color(0.7, 0.2, 0.3))
		draw_arc(opp_pos, 18, 0, TAU, 32, Color.BLACK, 2.0)
		var font = ThemeDB.fallback_font
		draw_string(font, opp_pos + Vector2(-5, 5), "O2", 
					HORIZONTAL_ALIGNMENT_CENTER, -1, 12, Color.WHITE)
	
	draw_messages()

func init_game() -> void:
	game_state.game_active = true
	game_state.serving_team = "player"
	game_state.server_number = 2
	game_state.is_first_serve_of_game = true
	game_state.waiting_for_serve = true
	game_state.can_serve = true
	
	var instructions = get_node_or_null("UI/HUD/Instructions")
	if instructions:
		instructions.text = "Swipe up to serve!"
	
	update_ui()

func update_game(delta: float) -> void:
	update_kitchen_state_machine(delta)

func update_kitchen_state_machine(delta: float) -> void:
	if game_state.kitchen_state_timer > 0:
		game_state.kitchen_state_timer -= delta
		
		# Update UI timer
		var ui = get_node_or_null("UI")
		if ui and ui.has_method("update_kitchen_button"):
			var state_name = ""
			match game_state.kitchen_state:
				KitchenState.AVAILABLE: state_name = "AVAILABLE"
				KitchenState.ACTIVE: state_name = "ACTIVE"
				KitchenState.MUST_EXIT: state_name = "MUST_EXIT"
				KitchenState.WARNING: state_name = "WARNING"
				KitchenState.COOLDOWN: state_name = "COOLDOWN"
				_: state_name = "DISABLED"
			ui.update_kitchen_button(state_name, game_state.kitchen_state_timer)
	
	match game_state.kitchen_state:
		KitchenState.AVAILABLE:
			if game_state.kitchen_state_timer <= 0:
				game_state.kitchen_state = KitchenState.DISABLED
				show_message("Opportunity missed!", COURT_WIDTH/2.0, NET_Y + 50, Color(1.0, 0.6, 0))

func end_mastery_mode() -> void:
	game_state.kitchen_mastery = false
	player_node.get_node("Sprite").modulate = Color.WHITE
	show_message("Mastery ended", COURT_WIDTH/2.0, NET_Y, Color(1.0, 0.84, 0))

func update_ui() -> void:
	var score_label = get_node_or_null("UI/HUD/TopPanel/ScoreLabel")
	if score_label:
		score_label.text = "%d-%d-%d" % [game_state.player_score, game_state.opponent_score, game_state.server_number]
	
	var ui = get_node_or_null("UI")
	if ui and ui.has_method("update_mastery_fill"):
		var percent = (game_state.kitchen_pressure / game_state.kitchen_pressure_max) * 100
		ui.update_mastery_fill(percent)

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
	draw_colored_polygon(court_points, Color(0.18, 0.49, 0.20))
	
	# Draw court texture lines
	for i in range(11):
		var y_factor = i / 10.0
		var left_x = lerp(top_left.x, bottom_left.x, y_factor)
		var right_x = lerp(top_right.x, bottom_right.x, y_factor)
		var screen_y = lerp(top_left.y, bottom_left.y, y_factor)
		
		draw_line(Vector2(left_x, screen_y), Vector2(right_x, screen_y), 
				  Color(0.14, 0.42, 0.21), 1.0)
	
	draw_kitchen_zones(center_x, court_top)
	draw_court_lines(center_x, court_top)
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
	
	# Bottom kitchen
	var bottom_kitchen_points = PackedVector2Array([
		Vector2(center_x - (COURT_WIDTH/2.0) * net_scale * court_scale, net_pos.y),
		Vector2(center_x + (COURT_WIDTH/2.0) * net_scale * court_scale, net_pos.y),
		Vector2(center_x + (COURT_WIDTH/2.0) * bottom_kitchen_scale * court_scale, kitchen_bottom_pos.y),
		Vector2(center_x - (COURT_WIDTH/2.0) * bottom_kitchen_scale * court_scale, kitchen_bottom_pos.y)
	])
	draw_colored_polygon(bottom_kitchen_points, kitchen_color)
	
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
	var direction = (to - from).normalized()
	var total_length = from.distance_to(to)
	var current_length = 0.0
	
	while current_length < total_length:
		var dash_start = from + direction * current_length
		var dash_end = from + direction * min(current_length + dash_length, total_length)
		draw_line(dash_start, dash_end, color, width)
		current_length += dash_length + gap_length

func get_kitchen_zone_color() -> Color:
	if game_state.in_kitchen:
		return Color(1.0, 0.78, 0, 0.15)
	else:
		return Color(1.0, 0.78, 0, 0.06)

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
	
	for i in range(messages_to_remove.size() - 1, -1, -1):
		messages.remove_at(messages_to_remove[i])

func draw_messages() -> void:
	var font = ThemeDB.fallback_font
	for msg in messages:
		var alpha = min(msg.life, 1.0)
		var color = Color(msg.color.r, msg.color.g, msg.color.b, alpha)
		draw_string(font, Vector2(msg.x - 40, msg.y), msg.text,
					HORIZONTAL_ALIGNMENT_CENTER, -1, 14, color)
