# Main.gd - Day 5 Integration with KitchenSystem
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
const PARTNER_SPEED: float = 170.0
const BALL_RADIUS: float = 8.0
const GRAVITY: float = 160.0
const HIT_DISTANCE: float = 80.0
const HIT_COOLDOWN: float = 0.4
const MIN_PLAYER_DISTANCE: float = 80.0

# Kitchen State Machine (kept for compatibility, but use KitchenSystem)
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
	
	# Kitchen states - NOW MANAGED BY KitchenSystem
	"kitchen_state": KitchenState.DISABLED,
	"kitchen_state_timer": 0.0,
	"in_kitchen": false,
	
	# Kitchen tracking
	"kitchen_violations": {"player": 0, "opponent": 0},
	"kitchen_flash": null,
	
	# Pressure system - NOW MANAGED BY KitchenSystem
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

# Player nodes and their data
var player_node = null
var partner_node = null

# Player movement data
var player_data = {
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
	# NEW: Kitchen violation tracking
	"was_in_kitchen": false,
	"feet_established": true,
	"momentum_timer": 0.0,
	"volley_position": Vector2.ZERO,
	"establishment_timer": 0.0
}

var partner_data = {
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
	"establishment_timer": 0.0
}

# Opponent data
var opponent1_data = {
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
	"volley_position": Vector2.ZERO
}

var opponent2_data = {
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
	"volley_position": Vector2.ZERO
}

# NEW: Kitchen System reference
var kitchen_system: Node = null

func _ready() -> void:
	screen_width = get_viewport().size.x
	screen_height = get_viewport().size.y
	
	print("=== STARTING DAY 5 WITH KITCHEN SYSTEM ===")
	
	court_scale = min(screen_width / COURT_WIDTH, screen_height / (COURT_HEIGHT + COURT_OFFSET_Y * 2))
	
	# Initialize game
	init_game()
	
	# Create KitchenSystem FIRST
	create_kitchen_system()
	
	# Create swipe detector
	create_swipe_detector()
	
	# Create player and partner
	await get_tree().process_frame
	create_player_team()
	
	print("=== DAY 5 KITCHEN SYSTEM READY ===")

# NEW: Create and setup KitchenSystem
func create_kitchen_system() -> void:
	var kitchen_script = load("res://scripts/systems/KitchenSystem.gd")
	if not kitchen_script:
		print("ERROR: Cannot load KitchenSystem.gd")
		return
	
	kitchen_system = Node.new()
	kitchen_system.name = "KitchenSystem"
	kitchen_system.set_script(kitchen_script)
	add_child(kitchen_system)
	
	# Set references
	kitchen_system.main_node = self
	kitchen_system.player_data = player_data
	
	# Connect signals
	kitchen_system.kitchen_opportunity.connect(_on_kitchen_opportunity)
	kitchen_system.kitchen_entered.connect(_on_kitchen_entered)
	kitchen_system.kitchen_exited.connect(_on_kitchen_exited)
	kitchen_system.kitchen_violation.connect(_on_kitchen_violation)
	kitchen_system.pressure_changed.connect(_on_pressure_changed)
	kitchen_system.state_changed.connect(_on_kitchen_state_changed)
	
	print("KitchenSystem created and connected!")

# NEW: Signal handlers for KitchenSystem
func _on_kitchen_opportunity() -> void:
	show_message("Kitchen Available!", COURT_WIDTH/2, NET_Y + 50, Color(1.0, 0.84, 0))

func _on_kitchen_entered() -> void:
	show_message("Entered Kitchen!", COURT_WIDTH/2, NET_Y, Color(1.0, 0.84, 0))

func _on_kitchen_exited() -> void:
	show_message("Exited Kitchen", COURT_WIDTH/2, NET_Y, Color(0.3, 0.69, 0.31))

func _on_kitchen_violation(violation_type: String, message: String) -> void:
	show_message("FAULT! " + message, COURT_WIDTH/2, COURT_HEIGHT/2, Color(1.0, 0, 0))
	flash_kitchen_zone(true)

func _on_pressure_changed(new_value: float) -> void:
	game_state.kitchen_pressure = new_value
	update_ui()

func _on_kitchen_state_changed(new_state: int) -> void:
	game_state.kitchen_state = new_state
	update_ui()

# MODIFIED: Handle kitchen button now uses KitchenSystem
func handle_kitchen_button_press() -> void:
	if not kitchen_system:
		print("ERROR: KitchenSystem not initialized!")
		return
	
	match kitchen_system.current_state:
		0:  # DISABLED
			print("Kitchen not available")
		
		1:  # AVAILABLE
			if kitchen_system.enter_kitchen():
				# System handles player movement through player_data
				pass
		
		2, 3, 4:  # ACTIVE, MUST_EXIT, WARNING
			kitchen_system.exit_kitchen()

# NEW: Flash kitchen zone for violations
func flash_kitchen_zone(is_player_side: bool) -> void:
	game_state.kitchen_flash = {
		"active": true,
		"side": "player" if is_player_side else "opponent",
		"start_time": Time.get_ticks_msec(),
		"duration": 1000
	}
	queue_redraw()

func create_player_team() -> void:
	print("Creating player team with 2D movement...")
	
	player_node = create_character("Player", Color(0.2, 0.4, 0.8), "right", true)
	partner_node = create_character("Partner", Color(0.2, 0.6, 0.9), "left", false)
	
	update_character_screen_position(player_node, player_data)
	update_character_screen_position(partner_node, partner_data)
	
	print("Player team created with 2D positioning")

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
	
	# Add paddle
	var paddle = Sprite2D.new()
	paddle.name = "Paddle"
	var paddle_img = Image.create(12, 40, false, Image.FORMAT_RGBA8)
	
	for x in range(12):
		for y in range(40):
			if y < 15:
				if x >= 4 and x < 8:
					paddle_img.set_pixel(x, y, Color(0.4, 0.25, 0.1))
			else:
				if x >= 1 and x < 11:
					if x == 1 or x == 10 or y == 15 or y == 39:
						paddle_img.set_pixel(x, y, Color.BLACK)
					else:
						paddle_img.set_pixel(x, y, Color(0.6, 0.35, 0.15))
	
	paddle.texture = ImageTexture.create_from_image(paddle_img)
	paddle.position = Vector2(25, 0)
	paddle.z_index = 2
	character.add_child(paddle)
	
	# Add hit indicator
	var hit_indicator = Sprite2D.new()
	hit_indicator.name = "HitIndicator"
	var hit_img = Image.create(120, 120, false, Image.FORMAT_RGBA8)
	
	for angle_deg in range(0, 360, 10):
		var angle = deg_to_rad(angle_deg)
		for width in range(2):
			var x = int(60 + cos(angle) * (58 + width))
			var y = int(60 + sin(angle) * (58 + width))
			if x >= 0 and x < 120 and y >= 0 and y < 120:
				hit_img.set_pixel(x, y, Color(0, 1, 0, 0.3))
	
	hit_indicator.texture = ImageTexture.create_from_image(hit_img)
	hit_indicator.position = Vector2(-60, -60)
	hit_indicator.visible = false
	hit_indicator.z_index = 0
	character.add_child(hit_indicator)
	
	character.z_index = 50
	
	return character

func update_character_screen_position(character: CharacterBody2D, data: Dictionary) -> void:
	var screen_pos = court_to_screen(data.court_x, data.court_y)
	character.position = screen_pos

func update_player_movement_2d(delta: float) -> void:
	if not player_node or not partner_node:
		return
	
	var ball = get_node_or_null("Ball")
	if not ball:
		return
	
	if game_state.waiting_for_serve:
		return
	
	var ball_court_pos = ball.screen_to_court(ball.global_position) if ball.has_method("screen_to_court") else Vector2.ZERO
	var ball_on_our_side = ball_court_pos.y > NET_Y
	
	check_hit_opportunity(player_node, player_data, ball)
	check_hit_opportunity(partner_node, partner_data, ball)
	
	if game_state.ball_in_play:
		update_player_2d_logic(player_data, ball, ball_court_pos, delta, true)
		update_player_2d_logic(partner_data, ball, ball_court_pos, delta, false)
		
		update_character_screen_position(player_node, player_data)
		update_character_screen_position(partner_node, partner_data)
		
		check_partner_hit_2d(ball, delta)
		
		update_paddle_aim(player_node, ball)
		update_paddle_aim(partner_node, ball)
	else:
		update_paddle_aim(player_node, ball)
		update_paddle_aim(partner_node, ball)
	
	update_opponents_2d(delta)
	
	# NEW: Update establishment timers
	update_establishment_timers(delta)

# NEW: Track feet establishment after leaving kitchen
func update_establishment_timers(delta: float) -> void:
	for data in [player_data, partner_data]:
		if data.establishment_timer > 0:
			data.establishment_timer -= delta
			if data.establishment_timer <= 0:
				data.feet_established = true
				data.was_in_kitchen = false
				print("Feet established!")
		
		if data.momentum_timer > 0:
			data.momentum_timer -= delta

func update_player_2d_logic(data: Dictionary, ball: Node, ball_court_pos: Vector2, delta: float, is_player: bool) -> void:
	var ball_on_our_side = ball_court_pos.y > NET_Y
	var speed = (PLAYER_SPEED if is_player else PARTNER_SPEED) * delta
	
	# Apply mastery boost
	if game_state.kitchen_mastery and is_player:
		speed *= 1.3
	
	var should_cover = should_player_cover_ball(data, ball_court_pos)
	
	if ball_on_our_side and should_cover:
		var time_to_reach = calculate_time_to_reach(data, ball_court_pos, ball)
		var predicted_x = ball_court_pos.x + ball.velocity.x * time_to_reach * 0.0005
		var predicted_y = ball_court_pos.y + ball.velocity.y * time_to_reach * 0.0005
		
		predicted_x = clamp(predicted_x, 20, COURT_WIDTH - 20)
		predicted_y = clamp(predicted_y, NET_Y + 10, BASELINE_BOTTOM - 10)
		
		if ball.height > 40 and ball.vertical_velocity > 0:
			data.target_court_y = min(predicted_y + 30, BASELINE_BOTTOM - 20)
		elif ball.height > 20 and predicted_y < data.court_y:
			# MODIFIED: Check kitchen system state
			if is_player and kitchen_system and kitchen_system.current_state == 2:  # ACTIVE
				# Allow in kitchen
				data.target_court_y = clamp(predicted_y, NET_Y + 10, KITCHEN_LINE_BOTTOM - 5)
			else:
				# Stay out of kitchen
				data.target_court_y = max(predicted_y, KITCHEN_LINE_BOTTOM + 10)
		else:
			data.target_court_y = clamp(predicted_y, KITCHEN_LINE_BOTTOM + 10, BASELINE_BOTTOM - 20)
		
		data.target_court_x = predicted_x
		
	elif ball_on_our_side and not should_cover:
		var support_x = data.default_x
		var support_y = lerp(data.court_y, data.default_y, 0.5)
		data.target_court_x = support_x
		data.target_court_y = support_y
	else:
		data.target_court_x = data.default_x
		data.target_court_y = data.default_y
	
	# COLLISION AVOIDANCE
	if is_player:
		var partner_dist = sqrt(pow(data.court_x - partner_data.court_x, 2) + 
							   pow(data.court_y - partner_data.court_y, 2))
		if partner_dist < MIN_PLAYER_DISTANCE:
			var push_dir_x = data.court_x - partner_data.court_x
			var push_dir_y = data.court_y - partner_data.court_y
			var push_dist = sqrt(push_dir_x*push_dir_x + push_dir_y*push_dir_y)
			if push_dist > 0:
				data.court_x += (push_dir_x / push_dist) * (MIN_PLAYER_DISTANCE - partner_dist) * 0.5
				data.court_y += (push_dir_y / push_dist) * (MIN_PLAYER_DISTANCE - partner_dist) * 0.5
	else:
		var player_dist = sqrt(pow(data.court_x - player_data.court_x, 2) + 
							  pow(data.court_y - player_data.court_y, 2))
		if player_dist < MIN_PLAYER_DISTANCE:
			var push_dir_x = data.court_x - player_data.court_x
			var push_dir_y = data.court_y - player_data.court_y
			var push_dist = sqrt(push_dir_x*push_dir_x + push_dir_y*push_dir_y)
			if push_dist > 0:
				data.court_x += (push_dir_x / push_dist) * (MIN_PLAYER_DISTANCE - player_dist) * 0.5
				data.court_y += (push_dir_y / push_dist) * (MIN_PLAYER_DISTANCE - player_dist) * 0.5
	
	# SMOOTH MOVEMENT
	var dx = data.target_court_x - data.court_x
	var dy = data.target_court_y - data.court_y
	var dist = sqrt(dx*dx + dy*dy)
	
	if dist > speed:
		data.court_x += (dx / dist) * speed
		data.court_y += (dy / dist) * speed
	else:
		data.court_x = data.target_court_x
		data.court_y = data.target_court_y
	
	# ENFORCE KITCHEN BOUNDARY (unless system allows)
	if is_player:
		if not kitchen_system or kitchen_system.current_state != 2:  # Not ACTIVE
			data.court_y = max(data.court_y, KITCHEN_LINE_BOTTOM + 5)
	else:
		data.court_y = max(data.court_y, KITCHEN_LINE_BOTTOM + 5)
	
	# Track kitchen status
	var was_in_kitchen_before = data.in_kitchen
	data.in_kitchen = (data.court_y >= NET_Y and data.court_y <= KITCHEN_LINE_BOTTOM)
	
	# NEW: Track kitchen entry/exit for feet establishment
	if not was_in_kitchen_before and data.in_kitchen:
		data.was_in_kitchen = true
		data.feet_established = false
	elif was_in_kitchen_before and not data.in_kitchen:
		data.establishment_timer = 0.5  # 0.5 seconds to establish feet

func should_player_cover_ball(data: Dictionary, ball_court_pos: Vector2) -> bool:
	if data.court_side == "right":
		return ball_court_pos.x > COURT_WIDTH * 0.4
	else:
		return ball_court_pos.x < COURT_WIDTH * 0.6

func calculate_time_to_reach(data: Dictionary, ball_pos: Vector2, ball: Node) -> float:
	var dx = ball_pos.x - data.court_x
	var dy = ball_pos.y - data.court_y
	var dist = sqrt(dx*dx + dy*dy)
	var player_speed = PLAYER_SPEED
	return dist / player_speed

func check_hit_opportunity(character: CharacterBody2D, data: Dictionary, ball: Node) -> void:
	var ball_screen_pos = ball.global_position
	var player_screen_pos = character.global_position
	
	var screen_dist = ball_screen_pos.distance_to(player_screen_pos)
	var time_since_hit = Time.get_ticks_msec() - data.last_hit_time
	var ball_court_pos = ball.screen_to_court(ball.global_position) if ball.has_method("screen_to_court") else Vector2.ZERO
	
	data.can_hit = screen_dist < HIT_DISTANCE and \
				   ball.height < 40 and \
				   ball.height > 0 and \
				   ball_court_pos.y > NET_Y - 10 and \
				   ball.in_flight and \
				   time_since_hit > HIT_COOLDOWN * 1000 and \
				   ball.last_hit_team == "opponent"
	
	if data.can_hit:
		character.get_node("Sprite").modulate = Color(1.5, 1.5, 1.5)
		var hit_indicator = character.get_node_or_null("HitIndicator")
		if hit_indicator:
			hit_indicator.visible = true
	else:
		character.get_node("Sprite").modulate = Color.WHITE
		var hit_indicator = character.get_node_or_null("HitIndicator")
		if hit_indicator:
			hit_indicator.visible = false

func update_paddle_aim(character: CharacterBody2D, ball: Node) -> void:
	var paddle = character.get_node_or_null("Paddle")
	if paddle:
		var to_ball = (ball.global_position - character.global_position).normalized()
		paddle.rotation = to_ball.angle() - PI/2
		
		var dist = character.global_position.distance_to(ball.global_position)
		if dist < 100:
			paddle.position = Vector2(25, 0) + to_ball * 10
		else:
			paddle.position = Vector2(25, 0)
	
	var hit_indicator = character.get_node_or_null("HitIndicator")
	if hit_indicator:
		var data = player_data if character.name == "Player" else partner_data
		hit_indicator.visible = data.can_hit

func check_partner_hit_2d(ball: Node, delta: float) -> void:
	if not partner_data.can_hit:
		return
	
	if player_data.can_hit:
		return
	
	if game_state.consecutive_hits < 2 and ball.bounces == 0:
		return
	
	if ball.last_hit_team != "opponent":
		return
	
	var hit_chance = 0.75 * delta * 3
	if randf() < hit_chance:
		execute_partner_hit(ball)

func execute_partner_hit(ball: Node) -> void:
	print("Partner hitting ball!")
	
	# NEW: Check for kitchen violations before hitting
	if kitchen_system:
		# Check volley violation
		if kitchen_system.check_volley_violation(partner_data, ball.height):
			return  # Violation detected, don't hit
		
		# Check step-in violation
		if kitchen_system.check_step_in_violation(partner_data):
			return
	
	# Store volley position for momentum check
	if ball.height > 0:
		partner_data.volley_position = Vector2(partner_data.court_x, partner_data.court_y)
		partner_data.momentum_timer = 1.5
	
	var target_x = COURT_WIDTH * (0.25 + randf() * 0.5)
	var target_y = BASELINE_TOP + randf() * (NET_Y - BASELINE_TOP - 20)
	var target_screen = court_to_screen(target_x, target_y)
	
	var dx = target_screen.x - ball.position.x
	var dy = target_screen.y - ball.position.y
	var angle = atan2(dy, dx)
	
	var power = 0.4 + randf() * 0.4
	var shot_type = "normal"
	
	if partner_data.in_kitchen and randf() < 0.3:
		shot_type = "dink"
		power = 0.2
	
	ball.velocity = Vector2(cos(angle) * 200, sin(angle) * 200)
	ball.vertical_velocity = 100 + randf() * 40
	ball.height = max(ball.height, 10.0)
	ball.bounces = 0
	ball.bounces_on_current_side = 0
	ball.last_hit_team = "player"
	ball.last_hit_by = partner_node
	ball.in_flight = true
	
	partner_data.last_hit_time = Time.get_ticks_msec()
	partner_data.can_hit = false
	
	game_state.consecutive_hits += 1
	game_state.rally_count += 1
	
	# Update pressure for partner hit
	if kitchen_system:
		if shot_type == "dink":
			kitchen_system.update_pressure(15.0)  # DINK_PRESSURE
		else:
			kitchen_system.update_pressure(3.0)
	
	show_message("Partner!", partner_data.court_x, partner_data.court_y - 20, Color(0.2, 0.6, 0.9))
	update_ui()

func update_opponents_2d(delta: float) -> void:
	var ball = get_node_or_null("Ball")
	if not ball or not game_state.ball_in_play:
		return
	
	var ball_court_pos = ball.screen_to_court(ball.global_position) if ball.has_method("screen_to_court") else Vector2.ZERO
	var ball_on_their_side = ball_court_pos.y < NET_Y
	
	for opp_data in [opponent1_data, opponent2_data]:
		if ball_on_their_side:
			var should_cover = should_opponent_cover(opp_data, ball_court_pos)
			
			if should_cover:
				var time_to_reach = calculate_time_to_reach(opp_data, ball_court_pos, ball)
				var predicted_x = ball_court_pos.x + ball.velocity.x * time_to_reach * 0.0005
				var predicted_y = ball_court_pos.y + ball.velocity.y * time_to_reach * 0.0005
				
				predicted_x = clamp(predicted_x, 20, COURT_WIDTH - 20)
				predicted_y = clamp(predicted_y, BASELINE_TOP + 10, NET_Y - 10)
				
				if ball.height > 30 and predicted_y > opp_data.court_y:
					opp_data.target_court_y = min(predicted_y, KITCHEN_LINE_TOP - 10)
				else:
					opp_data.target_court_y = clamp(predicted_y, BASELINE_TOP + 20, KITCHEN_LINE_TOP - 10)
				
				opp_data.target_court_x = predicted_x
			else:
				opp_data.target_court_x = opp_data.default_x
				opp_data.target_court_y = opp_data.default_y
		else:
			opp_data.target_court_x = opp_data.default_x
			opp_data.target_court_y = opp_data.default_y
		
		var speed = 150.0 * delta
		var dx = opp_data.target_court_x - opp_data.court_x
		var dy = opp_data.target_court_y - opp_data.court_y
		var dist = sqrt(dx*dx + dy*dy)
		
		if dist > speed:
			opp_data.court_x += (dx / dist) * speed
			opp_data.court_y += (dy / dist) * speed
		else:
			opp_data.court_x = opp_data.target_court_x
			opp_data.court_y = opp_data.target_court_y
		
		opp_data.court_y = min(opp_data.court_y, KITCHEN_LINE_TOP - 5)
		
		check_opponent_hit_opportunity(opp_data, ball, ball_court_pos)
		
		if opp_data.can_hit and randf() < 0.02:
			opponent_hit_ball_2d(opp_data, ball)

func should_opponent_cover(opp_data: Dictionary, ball_pos: Vector2) -> bool:
	if opp_data.court_side == "right":
		return ball_pos.x > COURT_WIDTH * 0.4
	else:
		return ball_pos.x < COURT_WIDTH * 0.6

func check_opponent_hit_opportunity(opp_data: Dictionary, ball: Node, ball_court_pos: Vector2) -> void:
	var dx = ball_court_pos.x - opp_data.court_x
	var dy = ball_court_pos.y - opp_data.court_y
	var dist = sqrt(dx*dx + dy*dy)
	var time_since_hit = Time.get_ticks_msec() - opp_data.last_hit_time
	
	opp_data.can_hit = dist < HIT_DISTANCE/2 and \
					   ball.height < 40 and \
					   ball_court_pos.y < NET_Y and \
					   ball.in_flight and \
					   time_since_hit > HIT_COOLDOWN * 1000 and \
					   ball.bounces > 0

func opponent_hit_ball_2d(opp_data: Dictionary, ball: Node) -> void:
	print("Opponent hitting from 2D position!")
	
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
	
	show_message("Return!", opp_data.court_x, opp_data.court_y - 20, Color(0.8, 0.2, 0.2))

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
	
	if game_state.waiting_for_serve and game_state.can_serve:
		player_serve_with_swipe(angle, power)
		return
	
	if game_state.ball_in_play:
		var ball = get_node_or_null("Ball")
		if ball:
			print("Checking hit - Player can_hit: ", player_data.can_hit, " Partner can_hit: ", partner_data.can_hit)
			
			if player_data.can_hit:
				print("PLAYER HITTING BALL!")
				
				# NEW: Check for kitchen violations before hitting
				if kitchen_system:
					# Check volley violation
					if kitchen_system.check_volley_violation(player_data, ball.height):
						return  # Violation detected, don't hit
					
					# Check step-in violation
					if kitchen_system.check_step_in_violation(player_data):
						return
					
					# Check momentum violation
					if kitchen_system.check_momentum_violation(player_data):
						return
				
				# Store volley position for momentum check
				if ball.height > 0:
					player_data.volley_position = Vector2(player_data.court_x, player_data.court_y)
					player_data.momentum_timer = 1.5
				
				ball.receive_hit(angle, power, shot_type)
				player_data.last_hit_time = Time.get_ticks_msec()
				player_data.can_hit = false
				game_state.consecutive_hits += 1
				game_state.rally_count += 1
				
				# Update pressure based on shot type
				if kitchen_system:
					if shot_type == "dink":
						kitchen_system.update_pressure(15.0)  # DINK_PRESSURE
					elif shot_type == "power":
						kitchen_system.update_pressure(-5.0)  # POWER_SHOT_PRESSURE
					else:
						kitchen_system.update_pressure(3.0)
					
					# Check if player hit from kitchen - trigger MUST_EXIT
					if player_data.in_kitchen and ball.height > 0:
						kitchen_system.force_must_exit()
				
				update_ui()
				show_message("Hit!", player_data.court_x, player_data.court_y - 20, Color(0.2, 0.8, 0.2))
				return
			
			if partner_data.can_hit:
				print("PARTNER HITTING BALL!")
				ball.receive_hit(angle, power, shot_type)
				partner_data.last_hit_time = Time.get_ticks_msec()
				partner_data.can_hit = false
				game_state.consecutive_hits += 1
				game_state.rally_count += 1
				update_ui()
				show_message("Partner!", partner_data.court_x, partner_data.court_y - 20, Color(0.2, 0.6, 0.9))
				return

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
		var serve_pos = court_to_screen(player_data.court_x, player_data.court_y - 20)
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
		update_player_movement_2d(delta)
		
		# Update mastery timer
		if game_state.kitchen_mastery:
			game_state.kitchen_mastery_timer -= delta
			if game_state.kitchen_mastery_timer <= 0:
				end_mastery_mode()
	
	update_messages(delta)
	
	# Update kitchen flash
	if game_state.kitchen_flash and game_state.kitchen_flash.active:
		var elapsed = Time.get_ticks_msec() - game_state.kitchen_flash.start_time
		if elapsed > game_state.kitchen_flash.duration:
			game_state.kitchen_flash = null
	
	queue_redraw()

func _draw() -> void:
	draw_court()
	
	# Draw opponents
	var opp1_pos = court_to_screen(opponent1_data.court_x, opponent1_data.court_y)
	draw_circle(opp1_pos, 18, Color(0.8, 0.2, 0.2))
	draw_arc(opp1_pos, 18, 0, TAU, 32, Color.BLACK, 2.0)
	var font = ThemeDB.fallback_font
	draw_string(font, opp1_pos + Vector2(-5, 5), "O1", 
				HORIZONTAL_ALIGNMENT_CENTER, -1, 12, Color.WHITE)
	
	var opp2_pos = court_to_screen(opponent2_data.court_x, opponent2_data.court_y)
	draw_circle(opp2_pos, 18, Color(0.7, 0.2, 0.3))
	draw_arc(opp2_pos, 18, 0, TAU, 32, Color.BLACK, 2.0)
	draw_string(font, opp2_pos + Vector2(-5, 5), "O2", 
				HORIZONTAL_ALIGNMENT_CENTER, -1, 12, Color.WHITE)
	
	draw_messages()

func update_kitchen_pressure(amount: float) -> void:
	if kitchen_system:
		kitchen_system.update_pressure(amount)

func activate_mastery_mode() -> void:
	game_state.kitchen_mastery = true
	game_state.kitchen_mastery_timer = 8.0
	
	if kitchen_system:
		kitchen_system.pressure = 0
	
	show_message("KITCHEN MASTERY ACTIVE!", COURT_WIDTH/2, COURT_HEIGHT/2, Color(1.0, 0.84, 0))
	
	player_node.get_node("Sprite").modulate = Color(1.2, 1.0, 0.8)

func end_mastery_mode() -> void:
	game_state.kitchen_mastery = false
	player_node.get_node("Sprite").modulate = Color.WHITE
	show_message("Mastery ended", COURT_WIDTH/2.0, NET_Y, Color(1.0, 0.84, 0))

func init_game() -> void:
	game_state.game_active = true
	game_state.serving_team = "player"
	game_state.server_number = 2
	game_state.is_first_serve_of_game = true
	game_state.waiting_for_serve = true
	game_state.can_serve = true
	
	player_data.target_court_x = player_data.court_x
	player_data.target_court_y = player_data.court_y
	partner_data.target_court_x = partner_data.court_x
	partner_data.target_court_y = partner_data.court_y
	opponent1_data.target_court_x = opponent1_data.court_x
	opponent1_data.target_court_y = opponent1_data.court_y
	opponent2_data.target_court_x = opponent2_data.court_x
	opponent2_data.target_court_y = opponent2_data.court_y
	
	var instructions = get_node_or_null("UI/HUD/Instructions")
	if instructions:
		instructions.text = "Swipe up to serve!"
	
	update_ui()

func update_game(delta: float) -> void:
	# Kitchen system handles its own updates
	pass

func update_ui() -> void:
	var score_label = get_node_or_null("UI/HUD/TopPanel/ScoreLabel")
	if score_label:
		score_label.text = "%d-%d-%d" % [game_state.player_score, game_state.opponent_score, game_state.server_number]
	
	var ui = get_node_or_null("UI")
	if ui and ui.has_method("update_mastery_fill"):
		var percent = 0
		if kitchen_system:
			percent = kitchen_system.get_pressure_percent()
		ui.update_mastery_fill(percent)

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
	
	var top_left = Vector2(center_x - (COURT_WIDTH / 2.0) * PERSPECTIVE_SCALE * court_scale, court_top)
	var top_right = Vector2(center_x + (COURT_WIDTH / 2.0) * PERSPECTIVE_SCALE * court_scale, court_top)
	var bottom_left = Vector2(center_x - (COURT_WIDTH / 2.0) * court_scale, court_top + COURT_HEIGHT * 0.9 * court_scale)
	var bottom_right = Vector2(center_x + (COURT_WIDTH / 2.0) * court_scale, court_top + COURT_HEIGHT * 0.9 * court_scale)
	
	var court_points = PackedVector2Array([top_left, top_right, bottom_right, bottom_left])
	draw_colored_polygon(court_points, Color(0.18, 0.49, 0.20))
	
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
	
	# Draw top kitchen
	var top_kitchen_points = PackedVector2Array([
		Vector2(center_x - (COURT_WIDTH/2.0) * top_kitchen_scale * court_scale, kitchen_top_pos.y),
		Vector2(center_x + (COURT_WIDTH/2.0) * top_kitchen_scale * court_scale, kitchen_top_pos.y),
		Vector2(center_x + (COURT_WIDTH/2.0) * net_scale * court_scale, net_pos.y),
		Vector2(center_x - (COURT_WIDTH/2.0) * net_scale * court_scale, net_pos.y)
	])
	
	# Flash effect for violations
	var top_color = kitchen_color
	if game_state.kitchen_flash and game_state.kitchen_flash.side == "opponent":
		var flash_progress = float(Time.get_ticks_msec() - game_state.kitchen_flash.start_time) / game_state.kitchen_flash.duration
		var flash_alpha = 0.5 * (1.0 - flash_progress)
		top_color = Color(1.0, 0, 0, flash_alpha)
	
	draw_colored_polygon(top_kitchen_points, top_color)
	
	# Draw bottom kitchen
	var bottom_kitchen_points = PackedVector2Array([
		Vector2(center_x - (COURT_WIDTH/2.0) * net_scale * court_scale, net_pos.y),
		Vector2(center_x + (COURT_WIDTH/2.0) * net_scale * court_scale, net_pos.y),
		Vector2(center_x + (COURT_WIDTH/2.0) * bottom_kitchen_scale * court_scale, kitchen_bottom_pos.y),
		Vector2(center_x - (COURT_WIDTH/2.0) * bottom_kitchen_scale * court_scale, kitchen_bottom_pos.y)
	])
	
	var bottom_color = kitchen_color
	if game_state.kitchen_flash and game_state.kitchen_flash.side == "player":
		var flash_progress = float(Time.get_ticks_msec() - game_state.kitchen_flash.start_time) / game_state.kitchen_flash.duration
		var flash_alpha = 0.5 * (1.0 - flash_progress)
		bottom_color = Color(1.0, 0, 0, flash_alpha)
	
	draw_colored_polygon(bottom_kitchen_points, bottom_color)
	
	var font = ThemeDB.fallback_font
	draw_string(font, Vector2(center_x - 30, net_pos.y - 30), "KITCHEN", 
				HORIZONTAL_ALIGNMENT_CENTER, -1, 11, Color(1, 1, 1, 0.4))
	draw_string(font, Vector2(center_x - 30, net_pos.y + 35), "KITCHEN", 
				HORIZONTAL_ALIGNMENT_CENTER, -1, 11, Color(1, 1, 1, 0.4))

func draw_court_lines(center_x: float, court_top: float) -> void:
	var top_left = Vector2(center_x - (COURT_WIDTH / 2.0) * PERSPECTIVE_SCALE * court_scale, court_top)
	var top_right = Vector2(center_x + (COURT_WIDTH / 2.0) * PERSPECTIVE_SCALE * court_scale, court_top)
	var bottom_left = Vector2(center_x - (COURT_WIDTH / 2.0) * court_scale, court_top + COURT_HEIGHT * 0.9 * court_scale)
	var bottom_right = Vector2(center_x + (COURT_WIDTH / 2.0) * court_scale, court_top + COURT_HEIGHT * 0.9 * court_scale)
	
	draw_line(top_left, top_right, Color.WHITE, 3.0)
	draw_line(top_right, bottom_right, Color.WHITE, 3.0)
	draw_line(bottom_right, bottom_left, Color.WHITE, 3.0)
	draw_line(bottom_left, top_left, Color.WHITE, 3.0)
	
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
	if kitchen_system and kitchen_system.current_state == 2:  # ACTIVE
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
