# Player.gd - Enhanced Movement System
extends CharacterBody2D

# Movement constants
@export var base_speed: float = 180.0
@export var hit_range: float = 60.0
@export var court_side: String = "right"  # "left" or "right"

# Kitchen tracking
var in_kitchen: bool = false
var was_in_kitchen: bool = false
var feet_established: bool = true
var momentum_timer: float = 0.0
var volley_position: Vector2
var kitchen_entry_time: int = 0
var establishment_timer: float = 0.0

# Hit detection
var can_hit: bool = false
var last_hit_time: int = 0

# Serving
var is_serving: bool = false
var is_server1: bool = true

# Movement
var target_position: Vector2

# Visual components
var sprite: Sprite2D = null
var paddle: Node2D = null
var hit_area: Area2D = null

# References
var main: Node = null
var ball: Node = null

signal entered_kitchen()
signal exited_kitchen()
signal ready_to_hit()

func _ready() -> void:
	await get_tree().process_frame
	
	main = get_node("/root/Main")
	ball = get_node("/root/Main/Ball")
	
	if not main or not ball:
		print("ERROR: Player cannot find Main or Ball!")
		return
	
	# Make sure player is visible
	visible = true
	z_index = 100  # Make sure it's above the court
	
	create_visuals()
	setup_collision()
	
	# Set initial position
	reset_to_default_position()
	
	# Debug output
	print("Player ready at position: ", position)
	print("Player global position: ", global_position)
	print("Player visible: ", visible)
	print("Player z_index: ", z_index)
	print("Player has sprite: ", sprite != null)
	if sprite:
		print("Sprite visible: ", sprite.visible)
		print("Sprite has texture: ", sprite.texture != null)

func create_visuals() -> void:
	# Create player sprite if not exists
	if not sprite:
		sprite = Sprite2D.new()
		sprite.name = "Sprite"
		add_child(sprite)
	
	# Make sure sprite is visible
	sprite.visible = true
	sprite.z_index = 1  # Above the player base
	
	# Create player texture (blue circle for player)
	var img = Image.create(36, 36, false, Image.FORMAT_RGBA8)
	var player_color = Color(0.2, 0.4, 0.8)  # Blue for player
	
	for x in range(36):
		for y in range(36):
			var dx = x - 18.0
			var dy = y - 18.0
			var dist = sqrt(dx*dx + dy*dy)
			
			if dist <= 18:
				if dist <= 16:
					# Inner circle
					img.set_pixel(x, y, player_color)
				else:
					# Border
					img.set_pixel(x, y, Color.BLACK)
			else:
				# Transparent background
				img.set_pixel(x, y, Color(0, 0, 0, 0))
	
	sprite.texture = ImageTexture.create_from_image(img)
	
	print("Player texture created, size: 36x36")
	print("Sprite texture assigned: ", sprite.texture != null)
	
	# Add court side indicator
	var label = Label.new()
	label.text = "R" if court_side == "right" else "L"
	label.position = Vector2(-5, -5)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_font_size_override("font_size", 10)
	sprite.add_child(label)
	
	# Create paddle
	if not paddle:
		paddle = Node2D.new()
		paddle.name = "Paddle"
		add_child(paddle)
		
		var paddle_sprite = Sprite2D.new()
		paddle_sprite.name = "Sprite"
		
		# Simple paddle texture
		var paddle_img = Image.create(8, 24, false, Image.FORMAT_RGBA8)
		paddle_img.fill(Color(0.5, 0.3, 0.1))  # Brown paddle
		paddle_sprite.texture = ImageTexture.create_from_image(paddle_img)
		paddle.add_child(paddle_sprite)
		
		# Position paddle to the side
		paddle.position = Vector2(20, 0)

func setup_collision() -> void:
	# Add collision shape for player
	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 18
	collision.shape = shape
	add_child(collision)
	
	# Create hit detection area
	if not hit_area:
		hit_area = Area2D.new()
		hit_area.name = "HitArea"
		add_child(hit_area)
		
		var hit_collision = CollisionShape2D.new()
		var hit_shape = CircleShape2D.new()
		hit_shape.radius = hit_range
		hit_collision.shape = hit_shape
		hit_area.add_child(hit_collision)
		
		# Connect hit area signals
		hit_area.body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	if not main or not ball:
		return
	
	update_movement(delta)
	update_paddle_aim(delta)
	check_hit_opportunity()
	update_kitchen_status(delta)

func update_movement(delta: float) -> void:
	var speed = base_speed
	
	# Apply mastery speed boost if active
	if main.game_state.kitchen_mastery:
		speed *= 1.3  # 30% boost during mastery
	
	# Get ball court position
	var ball_court_pos = ball.screen_to_court(ball.global_position)
	var ball_on_our_side = ball_court_pos.y > main.NET_Y
	
	# Predictive positioning when ball is on our side
	if ball_on_our_side and ball.in_flight:
		var time_to_reach = max(0, (position.y - ball.position.y) / max(ball.velocity.y, 1))
		var predicted_x = ball.position.x + ball.velocity.x * time_to_reach * 0.3
		
		if should_cover_ball(predicted_x):
			target_position = calculate_intercept_position(predicted_x, ball.position.y)
	elif not in_kitchen and not is_serving:
		# Default positioning
		var default_x = main.COURT_WIDTH * (0.7 if court_side == "right" else 0.3)
		var default_y = main.BASELINE_BOTTOM - 90
		var screen_pos = main.court_to_screen(default_x, default_y)
		target_position = screen_pos
	
	# Smooth movement to target
	var direction = (target_position - position).normalized()
	velocity = direction * speed
	move_and_slide()
	
	# Clamp to court bounds
	var court_pos = main.get_node("Court").screen_to_court(position) if main.has_node("Court") else Vector2.ZERO
	var bounds = main.get_visual_court_bounds(court_pos.y)
	
	# Convert bounds back to screen space for clamping
	var left_screen = main.court_to_screen(bounds.left + 10, court_pos.y).x
	var right_screen = main.court_to_screen(bounds.right - 10, court_pos.y).x
	
	position.x = clamp(position.x, left_screen, right_screen)
	
	if not in_kitchen:
		var bottom_limit = main.court_to_screen(main.COURT_WIDTH/2, main.BASELINE_BOTTOM - 10).y
		var kitchen_limit = main.court_to_screen(main.COURT_WIDTH/2, main.KITCHEN_LINE_BOTTOM + 5).y
		position.y = clamp(position.y, kitchen_limit, bottom_limit)

func should_cover_ball(predicted_x: float) -> bool:
	var in_my_zone = (court_side == "right" and predicted_x > get_viewport().size.x / 2) or \
					 (court_side == "left" and predicted_x <= get_viewport().size.x / 2)
	
	# For now, always cover if in our zone (no partner yet)
	return in_my_zone

func calculate_intercept_position(predicted_x: float, ball_y: float) -> Vector2:
	# Calculate where player should move to intercept
	var intercept_x = predicted_x
	var intercept_y = ball_y + 15  # Slightly behind ball
	
	# Clamp to court bounds
	intercept_y = max(intercept_y, position.y - 50)  # Don't move back too much
	
	return Vector2(intercept_x, intercept_y)

func update_paddle_aim(delta: float) -> void:
	if not paddle:
		return
	
	# Aim paddle toward ball
	var to_ball = (ball.global_position - global_position).normalized()
	var target_angle = to_ball.angle() + PI/2
	
	paddle.rotation = lerp_angle(paddle.rotation, target_angle, 10 * delta)
	
	# Extend paddle when ball is close
	var distance = global_position.distance_to(ball.global_position)
	if distance < 100:
		paddle.position = to_ball * min(30, distance * 0.3)
	else:
		paddle.position = paddle.position.lerp(Vector2(20, 0), 5 * delta)

func check_hit_opportunity() -> void:
	var dist_to_ball = position.distance_to(ball.position)
	var time_since_hit = Time.get_ticks_msec() - last_hit_time
	var ball_court_pos = ball.screen_to_court(ball.global_position)
	
	var was_can_hit = can_hit
	can_hit = dist_to_ball < hit_range and \
			  ball.height < 40 and \
			  ball_court_pos.y > main.NET_Y and \
			  ball.in_flight and \
			  time_since_hit > main.HIT_COOLDOWN * 1000
	
	# Emit signal when becoming ready to hit
	if can_hit and not was_can_hit:
		ready_to_hit.emit()
		
		# Visual feedback
		sprite.modulate = Color(1.2, 1.2, 1.2)  # Brighten when can hit
	elif not can_hit and was_can_hit:
		sprite.modulate = Color.WHITE  # Normal color

func update_kitchen_status(delta: float) -> void:
	var court_pos = main.get_node("Court").screen_to_court(position) if main.has_node("Court") else Vector2.ZERO
	
	var was_in_kitchen_before = in_kitchen
	in_kitchen = court_pos.y >= main.NET_Y and \
				court_pos.y <= main.KITCHEN_LINE_BOTTOM and \
				abs(court_pos.x - main.COURT_WIDTH/2) < main.COURT_WIDTH/2
	
	# Track kitchen entry/exit
	if not was_in_kitchen_before and in_kitchen:
		kitchen_entry_time = Time.get_ticks_msec()
		was_in_kitchen = true
		feet_established = false
		entered_kitchen.emit()
	elif was_in_kitchen_before and not in_kitchen:
		establishment_timer = 0.5
		exited_kitchen.emit()
	
	# Update establishment timer
	if establishment_timer > 0:
		establishment_timer -= delta
		if establishment_timer <= 0:
			feet_established = true
			was_in_kitchen = false
			main.show_message("Established!", court_pos.x, court_pos.y - 20, Color(0.3, 0.69, 0.31))
	
	# Update momentum timer
	if momentum_timer > 0:
		momentum_timer -= delta

func reset_to_default_position() -> void:
	# Set initial court position based on side
	var court_x = main.COURT_WIDTH * (0.75 if court_side == "right" else 0.25)
	var court_y = main.BASELINE_BOTTOM - main.SERVICE_LINE_DEPTH
	
	print("Court position target: ", court_x, ", ", court_y)
	print("Court dimensions - WIDTH: ", main.COURT_WIDTH, " HEIGHT: ", main.COURT_HEIGHT)
	print("Baseline bottom: ", main.BASELINE_BOTTOM)
	print("Service line depth: ", main.SERVICE_LINE_DEPTH)
	
	# Convert to screen position
	var screen_pos = main.court_to_screen(court_x, court_y)
	position = screen_pos
	target_position = screen_pos
	
	print("Player reset to position: ", position, " (court: ", court_x, ", ", court_y, ")")
	print("Viewport size: ", get_viewport().size)
	
	# Force visible and on top
	visible = true
	z_index = 100

func _on_body_entered(body: Node2D) -> void:
	if body == ball and can_hit:
		print("Ball entered hit area!")
		# This is where paddle hit detection would trigger
		# For now, the swipe system handles hitting

func enter_kitchen() -> void:
	# Called when kitchen button is pressed
	if main.game_state.kitchen_state == main.KitchenState.AVAILABLE:
		in_kitchen = true
		was_in_kitchen = true
		feet_established = false
		kitchen_entry_time = Time.get_ticks_msec()
		
		# Move to kitchen position
		var kitchen_y = main.NET_Y + 35
		target_position = main.court_to_screen(main.COURT_WIDTH/2, kitchen_y)
		
		main.game_state.kitchen_state = main.KitchenState.ACTIVE
		main.game_state.in_kitchen = true

func exit_kitchen() -> void:
	# Called to exit kitchen
	in_kitchen = false
	establishment_timer = 0.5
	
	# Move back to baseline position
	var court_x = main.COURT_WIDTH * (0.75 if court_side == "right" else 0.25)
	var court_y = (main.KITCHEN_LINE_BOTTOM + main.BASELINE_BOTTOM) / 2
	target_position = main.court_to_screen(court_x, court_y)
	
	main.game_state.kitchen_state = main.KitchenState.DISABLED
	main.game_state.in_kitchen = false
