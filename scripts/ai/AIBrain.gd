# AIBrain.gd - AI decision making for partner and opponents
extends Node

# Skill levels
@export var skill_level: float = 0.75  # 0.0 to 1.0
@export var reaction_time: float = 0.3  # seconds
@export var aggression: float = 0.5  # 0.0 (defensive) to 1.0 (aggressive)

# AI state
var current_strategy: String = "baseline"  # baseline, kitchen, defensive, aggressive
var should_enter_kitchen: bool = false
var preparing_dink: bool = false
var exiting_kitchen: bool = false
var kitchen_timer: float = 0.0

# References
var player_data: Dictionary = {}
var ball: Node2D = null
var main_node: Node2D = null

# Decision cooldowns
var decision_cooldown: float = 0.0
var last_decision_time: float = 0.0

# Court constants (set from main)
var NET_Y: float = 280.0
var KITCHEN_LINE_TOP: float = 210.0
var KITCHEN_LINE_BOTTOM: float = 350.0
var BASELINE_TOP: float = 30.0
var BASELINE_BOTTOM: float = 530.0
var COURT_WIDTH: float = 280.0

func _ready() -> void:
	pass

func setup(main: Node2D, data: Dictionary) -> void:
	"""Initialize AI with main reference and player data"""
	main_node = main
	player_data = data

	if main:
		NET_Y = main.NET_Y
		KITCHEN_LINE_TOP = main.KITCHEN_LINE_TOP
		KITCHEN_LINE_BOTTOM = main.KITCHEN_LINE_BOTTOM
		BASELINE_TOP = main.BASELINE_TOP
		BASELINE_BOTTOM = main.BASELINE_BOTTOM
		COURT_WIDTH = main.COURT_WIDTH

func update(delta: float, ball_node: Node2D) -> Dictionary:
	"""
	Main AI update - returns movement and shot decisions.
	Returns: { "target_x": float, "target_y": float, "should_hit": bool, "shot_type": String }
	"""
	ball = ball_node

	if not ball or not main_node:
		return {"target_x": player_data.court_x, "target_y": player_data.court_y,
				"should_hit": false, "shot_type": "normal"}

	decision_cooldown -= delta
	kitchen_timer -= delta if kitchen_timer > 0 else 0.0

	# Get ball court position
	var ball_court_pos = Vector2.ZERO
	if ball.has_method("screen_to_court"):
		ball_court_pos = ball.screen_to_court(ball.global_position)

	# Determine strategy
	update_strategy(ball_court_pos, ball)

	# Calculate movement target
	var movement = calculate_movement(ball_court_pos, ball, delta)

	# Decide if should hit
	var should_hit = should_attempt_hit(ball, delta)
	var shot_type = select_shot_type(ball, ball_court_pos)

	return {
		"target_x": movement.x,
		"target_y": movement.y,
		"should_hit": should_hit,
		"shot_type": shot_type
	}

func update_strategy(ball_pos: Vector2, ball_node: Node2D) -> void:
	"""Update current playing strategy based on game state"""
	var is_opponent = player_data.get("is_opponent", false)
	var ball_on_our_side = (is_opponent and ball_pos.y < NET_Y) or \
						   (not is_opponent and ball_pos.y > NET_Y)

	# Base strategy on ball position and speed
	var ball_speed = ball_node.velocity.length() if ball_node else 0
	var ball_height = ball_node.height if ball_node else 0

	if ball_speed < 100 and ball_height < 40 and ball_on_our_side:
		# Slow, low ball - opportunity for kitchen play
		if should_attempt_kitchen_entry(ball_speed, ball_height, ball_pos):
			current_strategy = "kitchen"
			should_enter_kitchen = true
		else:
			current_strategy = "baseline"
	elif ball_speed > 250:
		# Fast ball - defensive positioning
		current_strategy = "defensive"
		should_enter_kitchen = false
	else:
		current_strategy = "baseline"

func should_attempt_kitchen_entry(ball_speed: float, ball_height: float, ball_pos: Vector2) -> bool:
	"""Decide if AI should move to kitchen for dink play"""
	var is_opponent = player_data.get("is_opponent", false)
	var kitchen_line = KITCHEN_LINE_TOP if is_opponent else KITCHEN_LINE_BOTTOM
	var distance_to_kitchen = abs(player_data.court_y - kitchen_line)

	var factors = 0.0

	# Slow ball encourages kitchen play
	if ball_speed < 150:
		factors += 0.3

	# Low ball near net
	if ball_height < 50 and distance_to_kitchen < 150:
		factors += 0.3

	# Skill level affects decision
	factors += skill_level * 0.2

	# Aggression increases kitchen attempts
	factors += aggression * 0.2

	return factors > 0.5 and randf() < factors

func calculate_movement(ball_pos: Vector2, ball_node: Node2D, delta: float) -> Vector2:
	"""Calculate target position for AI movement"""
	var is_opponent = player_data.get("is_opponent", false)
	var ball_on_our_side = (is_opponent and ball_pos.y < NET_Y) or \
						   (not is_opponent and ball_pos.y > NET_Y)

	var target_x = player_data.court_x
	var target_y = player_data.court_y

	if ball_on_our_side and ball_node.in_flight:
		# Predict where ball will be
		var time_to_reach = estimate_time_to_reach(ball_pos, ball_node)
		var predicted_x = ball_pos.x + ball_node.velocity.x * time_to_reach * 0.0005
		var predicted_y = ball_pos.y + ball_node.velocity.y * time_to_reach * 0.0005

		# Clamp to court bounds
		predicted_x = clamp(predicted_x, 20, COURT_WIDTH - 20)

		# Should this AI cover the ball?
		if should_cover_ball(predicted_x):
			target_x = predicted_x

			# Determine Y based on strategy
			match current_strategy:
				"kitchen":
					var kitchen_y = KITCHEN_LINE_TOP - 10 if is_opponent else KITCHEN_LINE_BOTTOM + 10
					target_y = kitchen_y
				"defensive":
					var baseline = BASELINE_TOP + 40 if is_opponent else BASELINE_BOTTOM - 40
					target_y = baseline
				"baseline":
					if is_opponent:
						target_y = clamp(predicted_y - 15, BASELINE_TOP + 20, KITCHEN_LINE_TOP - 10)
					else:
						target_y = clamp(predicted_y + 15, KITCHEN_LINE_BOTTOM + 10, BASELINE_BOTTOM - 20)
		else:
			# Return to default position
			target_x = player_data.default_x
			target_y = player_data.default_y
	else:
		# Ball on opponent's side - return to default
		target_x = player_data.default_x
		target_y = player_data.default_y

	return Vector2(target_x, target_y)

func should_cover_ball(predicted_x: float) -> bool:
	"""Determine if this AI should cover the predicted ball position"""
	var court_side = player_data.get("court_side", "right")

	if court_side == "right":
		return predicted_x > COURT_WIDTH * 0.4
	else:
		return predicted_x < COURT_WIDTH * 0.6

func estimate_time_to_reach(ball_pos: Vector2, ball_node: Node2D) -> float:
	"""Estimate time for ball to reach our position"""
	var dx = ball_pos.x - player_data.court_x
	var dy = ball_pos.y - player_data.court_y
	var dist = sqrt(dx*dx + dy*dy)

	var player_speed = 180.0  # Default speed
	return dist / player_speed

func should_attempt_hit(ball_node: Node2D, delta: float) -> bool:
	"""Decide if AI should attempt to hit the ball"""
	if not player_data.can_hit:
		return false

	if ball_node.last_hit_team == get_team_name():
		return false  # Can't hit own team's shot before opponent

	# Skill-based hit probability
	var hit_chance = skill_level * delta * 3.0

	# Increase chance if ball is close and low
	if ball_node.height < 30:
		hit_chance *= 1.5

	return randf() < hit_chance

func select_shot_type(ball_node: Node2D, ball_pos: Vector2) -> String:
	"""Select appropriate shot type based on situation"""
	var is_opponent = player_data.get("is_opponent", false)

	# If in or near kitchen, prefer dinks
	if player_data.in_kitchen or current_strategy == "kitchen":
		if randf() < 0.6:
			return "dink"

	# High ball - opportunity for power
	if ball_node.height > 60 and randf() < aggression:
		return "power"

	# Slow ball - good for drops
	if ball_node.velocity.length() < 100 and randf() < 0.3:
		return "drop"

	# Default to normal
	return "normal"

func get_shot_parameters(shot_type: String, target_data: Dictionary) -> Dictionary:
	"""Get angle, speed, arc for a shot"""
	var is_opponent = player_data.get("is_opponent", false)
	var base_angle = PI/2 if is_opponent else -PI/2  # Toward opponent

	var speed = 200.0
	var arc = 100.0

	match shot_type:
		"dink":
			speed = 80.0 + randf() * 20.0
			arc = 60.0
			# Aim for opponent's kitchen
			var target_y = KITCHEN_LINE_BOTTOM - 20 if is_opponent else KITCHEN_LINE_TOP + 20
		"drop":
			speed = 100.0 + randf() * 30.0
			arc = 140.0
		"power":
			speed = 280.0 + randf() * 60.0
			arc = 80.0
		"normal":
			speed = 180.0 + randf() * 60.0
			arc = 90.0 + randf() * 30.0

	# Add skill-based accuracy variation
	var accuracy_offset = (1.0 - skill_level) * 0.4
	base_angle += randf_range(-accuracy_offset, accuracy_offset)

	return {
		"angle": base_angle,
		"speed": speed,
		"arc": arc
	}

func get_team_name() -> String:
	"""Get team name for this AI"""
	return "opponent" if player_data.get("is_opponent", false) else "player"

func get_dink_target() -> Vector2:
	"""Calculate target position for dink shot"""
	var is_opponent = player_data.get("is_opponent", false)

	if is_opponent:
		# Aim for player's kitchen
		return Vector2(
			COURT_WIDTH * 0.5 + randf_range(-30, 30),
			KITCHEN_LINE_BOTTOM - 20
		)
	else:
		# Aim for opponent's kitchen
		return Vector2(
			COURT_WIDTH * 0.5 + randf_range(-30, 30),
			KITCHEN_LINE_TOP + 20
		)

func get_safe_target() -> Vector2:
	"""Get a safe return target"""
	var is_opponent = player_data.get("is_opponent", false)
	var center_x = COURT_WIDTH * 0.5
	var target_y = BASELINE_BOTTOM - 100 if is_opponent else BASELINE_TOP + 100

	return Vector2(
		center_x + randf_range(-50, 50),
		target_y
	)
