# Ball.gd - Complete ball physics from prototype
extends CharacterBody2D

# Physics constants from prototype
const GRAVITY: float = 160.0
const BOUNCE_DAMPING: float = 0.65
const FRICTION: float = 0.85
const MAX_TRAIL_POINTS: int = 25

# Ball properties
var height: float = 0.0
var vertical_velocity: float = 0.0
var ball_speed: float = 0.0
var last_hit_by: Node2D = null
var last_hit_team: String = ""
var bounces: int = 0
var bounces_on_current_side: int = 0
var in_flight: bool = false

# Trail system
var trail_points: Array = []

# Bounce tracking
var bounce_positions: Array = []

# Visual components - using @onready since they exist in scene
@onready var sprite: Sprite2D = $Sprite
@onready var shadow: Sprite2D = $Shadow
@onready var trail_line: Line2D = $Trail

# Reference to main - DON'T use @onready, get it manually
var main: Node = null

signal bounced(pos, side)
signal entered_kitchen()
signal crossed_net()

func _ready() -> void:
	print("Ball._ready() called - Ball exists in scene!")
	
	# Wait for Main to be ready first
	await get_tree().process_frame
	
	# NOW get reference to main (after it's ready)
	if not main:
		main = get_node("/root/Main")
		if not main:
			print("ERROR: Cannot find Main node!")
			return
	
	# Create textures for sprite and shadow
	create_ball_textures()
	
	# Set initial position for testing - CENTER of court bottom
	var start_court_pos = Vector2(main.COURT_WIDTH / 2.0, main.COURT_HEIGHT - 100)
	var screen_pos = main.court_to_screen(start_court_pos.x, start_court_pos.y)
	
	# FORCE the position
	global_position = screen_pos
	position = screen_pos
	height = 40.0
	
	print("Court position: ", start_court_pos)
	print("Screen position calculated: ", screen_pos)
	print("Ball actual position: ", position)
	print("Ball global position: ", global_position)
	
	# Normal size
	scale = Vector2(1, 1)
	
	# Make sure ball is visible
	visible = true
	z_index = 100
	
	# Configure trail
	if trail_line:
		trail_line.width = 3.0
		trail_line.default_color = Color(1.0, 0.84, 0, 0.3)
		trail_line.z_index = -1  # Put trail BEHIND ball
		trail_line.clear_points()
		trail_line.top_level = true  # Make trail independent of ball transform
		trail_points.clear()  # Clear any existing trail points
	
	print("Ball ready - waiting for player swipe!")

func create_ball_textures() -> void:
	# Create ball texture (yellow gradient circle)
	if sprite and not sprite.texture:
		var ball_image = Image.create(32, 32, false, Image.FORMAT_RGBA8)
		
		for x in range(32):
			for y in range(32):
				var dx = x - 16.0
				var dy = y - 16.0
				var dist = sqrt(dx*dx + dy*dy)
				
				if dist <= 16:
					# Create gradient from bright yellow center to orange edge
					var t = dist / 16.0
					var r = 1.0
					var g = 1.0 - (t * 0.3)  # Yellow to orange
					var b = 0.2 + (t * 0.3)
					var a = 1.0
					ball_image.set_pixel(x, y, Color(r, g, b, a))
		
		sprite.texture = ImageTexture.create_from_image(ball_image)
		print("Ball texture created")
	
	# Create shadow texture (dark ellipse)
	if shadow and not shadow.texture:
		var shadow_image = Image.create(32, 16, false, Image.FORMAT_RGBA8)
		
		for x in range(32):
			for y in range(16):
				var dx = (x - 16.0) / 16.0
				var dy = (y - 8.0) / 8.0
				var dist = sqrt(dx*dx + dy*dy)
				
				if dist <= 1.0:
					var alpha = (1.0 - dist) * 0.5
					shadow_image.set_pixel(x, y, Color(0, 0, 0, alpha))
		
		shadow.texture = ImageTexture.create_from_image(shadow_image)
		shadow.show_behind_parent = true
		print("Shadow texture created")

func _physics_process(delta: float) -> void:
	if not main or not main.game_state.ball_in_play:
		return
	
	# Store previous position for net crossing detection
	var prev_court_y = screen_to_court(global_position).y
	
	# Apply gravity to vertical velocity
	vertical_velocity -= GRAVITY * delta
	height += vertical_velocity * delta
	
	# Move horizontally (this updates position based on velocity)
	move_and_slide()
	
	# Check for bounce
	if height <= 0 and vertical_velocity < 0:
		execute_bounce()
	
	# Update visual components
	update_visuals()
	update_trail()
	
	# Check net crossing
	var current_court_y = screen_to_court(global_position).y
	if (prev_court_y < main.NET_Y and current_court_y >= main.NET_Y) or \
	   (prev_court_y > main.NET_Y and current_court_y <= main.NET_Y):
		crossed_net.emit()
		main.game_state.bounces_on_current_side = 0
	
	# Check out of bounds
	check_boundaries()
	
	# Update ball speed for other systems
	ball_speed = velocity.length()

func execute_bounce() -> void:
	height = 0
	vertical_velocity = -vertical_velocity * BOUNCE_DAMPING
	velocity *= FRICTION
	bounces += 1
	bounces_on_current_side += 1
	
	# Determine which side ball bounced on
	var court_pos = screen_to_court(position)
	var bounce_side = "player" if court_pos.y > main.NET_Y else "opponent"
	
	print("Ball bounced at court position: ", court_pos)
	print("Bounce side: ", bounce_side)
	
	# Store bounce position
	bounce_positions.append({
		"pos": position,
		"court_pos": court_pos,
		"time": Time.get_ticks_msec(),
		"side": bounce_side
	})
	
	# Keep only recent bounces (last 3 seconds)
	var current_time = Time.get_ticks_msec()
	bounce_positions = bounce_positions.filter(func(b): return current_time - b.time < 3000)
	
	# Emit bounce signal
	bounced.emit(position, bounce_side)
	
	# Add visual bounce marker to court
	if main.has_node("Court"):
		main.get_node("Court").add_bounce_marker(position)
	
	# Check for kitchen opportunity (ball bounced in player's half near kitchen)
	if bounce_side == "player" and bounces_on_current_side == 1:
		if court_pos.y >= main.NET_Y and court_pos.y <= main.KITCHEN_LINE_BOTTOM:
			if main.game_state.kitchen_state == main.KitchenState.DISABLED:
				main.game_state.kitchen_state = main.KitchenState.AVAILABLE
				main.game_state.kitchen_state_timer = 2.5
				main.show_message("Kitchen Available!", main.COURT_WIDTH/2, main.NET_Y + 50, Color(1.0, 0.84, 0))
				print("Kitchen opportunity triggered!")
	
	# Check for double bounce fault
	if bounces_on_current_side >= 2:
		var fault_team = bounce_side
		main.show_message("Double Bounce!", court_pos.x, court_pos.y, Color(1.0, 0.26, 0.21))
		stop_ball()  # Reset after double bounce

func update_visuals() -> void:
	# Update ball sprite position based on height
	sprite.position.y = -height * 0.18  # Visual height offset
	
	# Scale ball based on height (appears smaller when higher)
	var height_scale = 1.0 + height * 0.002
	sprite.scale = Vector2.ONE * height_scale
	
	# Update shadow
	shadow.position = Vector2.ZERO  # Shadow stays on ground
	var shadow_scale = 1.0 + height * 0.08
	var shadow_opacity = max(0.15, 0.5 - height * 0.003)
	shadow.scale = Vector2(shadow_scale, shadow_scale * 0.4)
	shadow.modulate.a = shadow_opacity

func update_trail() -> void:
	# Store ball's current position in world space
	var current_pos = global_position - Vector2(0, height * 0.15)
	
	# Add to trail points
	trail_points.append(current_pos)
	
	# Limit trail length
	if trail_points.size() > MAX_TRAIL_POINTS:
		trail_points.pop_front()
	
	# Clear and redraw trail
	trail_line.clear_points()
	
	# Set trail to NOT be relative to ball
	if trail_line.get_parent() == self:
		trail_line.top_level = true  # This makes it ignore parent transform
	
	# Add all trail points
	for i in range(trail_points.size()):
		var point_pos = trail_points[i]
		trail_line.add_point(point_pos)
	
	# Fade effect
	trail_line.default_color = Color(1.0, 0.84, 0, 0.3)
	trail_line.width = 3.0

func check_boundaries() -> void:
	var court_pos = screen_to_court(global_position)
	var bounds = main.get_visual_court_bounds(court_pos.y)
	
	# Debug output every frame while ball is moving
	if ball_speed > 10:
		print("Ball position - Screen: ", global_position, " Court: ", court_pos)
		print("Court bounds at Y=", court_pos.y, " -> Left: ", bounds.left, " Right: ", bounds.right)
	
	# Check if out of bounds
	var out_of_bounds = false
	var fault_message = ""
	
	# Check side boundaries
	if court_pos.x < bounds.left - 10:
		out_of_bounds = true
		fault_message = "Out - Wide Left!"
		print("OUT OF BOUNDS: Ball X (", court_pos.x, ") < Left bound (", bounds.left - 10, ")")
	elif court_pos.x > bounds.right + 10:
		out_of_bounds = true
		fault_message = "Out - Wide Right!"
		print("OUT OF BOUNDS: Ball X (", court_pos.x, ") > Right bound (", bounds.right + 10, ")")
	
	# Check end boundaries
	if court_pos.y < 0 - 10:  # Past top baseline
		out_of_bounds = true
		fault_message = "Out - Past opponent baseline!"
		print("OUT OF BOUNDS: Ball Y (", court_pos.y, ") < 0")
	elif court_pos.y > main.COURT_HEIGHT + 10:  # Past bottom baseline
		out_of_bounds = true  
		fault_message = "Out - Past your baseline!"
		print("OUT OF BOUNDS: Ball Y (", court_pos.y, ") > ", main.COURT_HEIGHT)
	
	if out_of_bounds:
		# Determine fault
		var fault_team = ""
		if bounces > 0:
			# Ball went out after bounce - fault on side that couldn't return
			fault_team = "player" if court_pos.y > main.NET_Y else "opponent"
			main.show_message("Missed Return!", court_pos.x, court_pos.y, Color(1.0, 0.26, 0.21))
		else:
			# Ball went out without bouncing - fault on last hitter
			fault_team = last_hit_team if last_hit_team else "player"
			main.show_message(fault_message, court_pos.x, court_pos.y, Color(1.0, 0.26, 0.21))
		
		print("BALL OUT: ", fault_message, " at court position: ", court_pos)
		
		# Reset ball
		stop_ball()

func screen_to_court(screen_pos: Vector2) -> Vector2:
	# Inverse of court_to_screen
	var center_x = get_viewport().size.x / 2.0
	var court_top = main.COURT_OFFSET_Y * main.court_scale
	
	# Calculate court Y from screen Y
	var court_y = (screen_pos.y - court_top) / (0.9 * main.court_scale)
	
	# Clamp court_y to valid range first
	court_y = clamp(court_y, 0, main.COURT_HEIGHT)
	
	# Calculate perspective factor
	var perspective_factor = 1.0 - (1.0 - main.PERSPECTIVE_SCALE) * (1.0 - court_y / main.COURT_HEIGHT)
	
	# Calculate court X from screen X
	var relative_x = (screen_pos.x - center_x) / (perspective_factor * main.court_scale)
	var court_x = relative_x + main.COURT_WIDTH / 2.0
	
	# Clamp court_x to valid range
	court_x = clamp(court_x, 0, main.COURT_WIDTH)
	
	return Vector2(court_x, court_y)

func receive_serve(angle: float, power: float) -> void:
	print("Ball receiving serve - Angle: ", angle, " Power: ", power)
	
	# Serve needs to go FORWARD (negative Y) and can go left/right based on angle
	var base_speed: float = 200.0  # Moderate base speed
	var arc: float = 120.0  # Good arc for serves
	
	# Apply power scaling
	var final_speed = base_speed * (0.6 + power * 0.4)
	
	# Force serve to go forward toward opponent's court
	var serve_angle = angle
	if serve_angle > -PI/4 or serve_angle < -3*PI/4:
		serve_angle = -PI/2  # Default to straight up if angle is wrong
	
	# Calculate velocity properly based on angle
	velocity = Vector2(
		cos(serve_angle) * final_speed,
		sin(serve_angle) * final_speed
	)
	
	# Set vertical velocity for arc
	vertical_velocity = arc * (0.8 + power * 0.2)
	
	# Reset ball state
	bounces = 0
	bounces_on_current_side = 0
	in_flight = true
	ball_speed = final_speed
	height = max(height, 40.0)
	last_hit_team = "player"
	last_hit_by = main.get_node_or_null("Player")
	
	# Update game state
	main.game_state.ball_in_play = true
	
	# Clear trail for new shot
	trail_points.clear()
	
	main.show_message("Serve!", main.COURT_WIDTH/2, main.COURT_HEIGHT - 50, Color.WHITE)
	
	print("Serve launched with velocity: ", velocity, " Vertical: ", vertical_velocity)

func receive_hit(angle: float, power: float, shot_type: String) -> void:
	print("Ball received hit - Angle: ", angle, " Power: ", power, " Type: ", shot_type)
	
	# Calculate shot parameters based on type and power
	var base_speed: float = 220.0
	var arc: float = 100.0
	
	match shot_type:
		"dink":
			base_speed = 80.0
			arc = 60.0
		"drop":
			base_speed = 100.0
			arc = 140.0
		"power":
			base_speed = 320.0
			arc = 80.0
		"normal":
			base_speed = 220.0
			arc = 100.0
	
	# Apply power scaling
	var final_speed = base_speed * (0.5 + power * 0.5)  # 50% to 100% of base speed
	
	# Set ball velocity
	velocity = Vector2(
		cos(angle) * final_speed,
		sin(angle) * final_speed
	)
	
	# Set vertical velocity (arc)
	vertical_velocity = arc * (0.7 + power * 0.3)
	
	# Reset ball state
	bounces = 0
	bounces_on_current_side = 0
	in_flight = true
	ball_speed = final_speed
	height = max(height, 5.0)  # Ensure ball is slightly off ground
	last_hit_team = "player"
	last_hit_by = main.get_node_or_null("Player")
	
	# Update game state
	main.game_state.ball_in_play = true
	main.game_state.consecutive_hits += 1
	
	# Clear trail for new shot
	trail_points.clear()
	
	# Show feedback
	var color = Color.WHITE
	match shot_type:
		"dink":
			color = Color(0, 0.74, 0.83)  # Cyan
		"drop":
			color = Color(1.0, 0.84, 0)  # Gold
		"power":
			color = Color(0.96, 0.26, 0.21)  # Red
		"normal":
			color = Color(0.3, 0.69, 0.31)  # Green
	
	main.show_message(shot_type.capitalize() + "!", 
					  main.COURT_WIDTH/2, main.COURT_HEIGHT - 50, color)
	
	print("Ball launched with velocity: ", velocity, " Vertical: ", vertical_velocity)

func stop_ball() -> void:
	velocity = Vector2.ZERO
	vertical_velocity = 0
	height = 0
	in_flight = false
	main.game_state.ball_in_play = false
	
	# Clear trail
	trail_points.clear()
	trail_line.clear_points()
	
	# Reset for next serve
	main.game_state.waiting_for_serve = true
	main.game_state.can_serve = true
	
	# Update instructions
	var instructions = main.get_node_or_null("UI/HUD/Instructions")
	if instructions:
		instructions.text = "Swipe up to serve again!"
	
	# Reset ball position
	var start_pos = main.court_to_screen(main.COURT_WIDTH / 2.0, main.COURT_HEIGHT - 100)
	global_position = start_pos
	
	print("Ball stopped - Ready for next serve")
