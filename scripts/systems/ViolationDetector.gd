# ViolationDetector.gd - Comprehensive rule checking system
extends Node

signal violation_detected(violator: String, violation_type: String, message: String)
signal line_fault(player: String)
signal momentum_violation(player: String)
signal establishment_required(player: String)

# Violation types
enum ViolationType {
	VOLLEY_IN_KITCHEN,
	LINE_FAULT,
	NOT_ESTABLISHED,
	MOMENTUM_CARRY,
	DOUBLE_BOUNCE,
	SERVICE_FAULT,
	OUT_OF_BOUNDS,
	OWN_COURT
}

# Reference to main
var main_node: Node2D = null

# Court values
var NET_Y: float = 280.0
var KITCHEN_LINE_TOP: float = 210.0
var KITCHEN_LINE_BOTTOM: float = 350.0
var KITCHEN_LINE_TOLERANCE: float = 5.0

func _ready() -> void:
	pass

func setup_from_main(main: Node2D) -> void:
	"""Get constants from main node"""
	main_node = main
	if main:
		NET_Y = main.NET_Y
		KITCHEN_LINE_TOP = main.KITCHEN_LINE_TOP
		KITCHEN_LINE_BOTTOM = main.KITCHEN_LINE_BOTTOM

func check_comprehensive_kitchen_violation(hitter_data: Dictionary, ball_height: float, is_player_team: bool) -> Dictionary:
	"""
	Check all possible kitchen violations when hitting the ball.
	Returns: { "violation": bool, "type": ViolationType, "message": String, "severe": bool }
	"""

	# Priority 1: Direct volley in kitchen
	if hitter_data.in_kitchen and ball_height > 0:
		return {
			"violation": true,
			"type": ViolationType.VOLLEY_IN_KITCHEN,
			"message": "Cannot volley in kitchen!",
			"severe": true
		}

	# Priority 2: Touching kitchen line during volley
	if not hitter_data.in_kitchen and ball_height > 0:
		var kitchen_line = KITCHEN_LINE_BOTTOM if is_player_team else KITCHEN_LINE_TOP
		var dist_to_kitchen_line = abs(hitter_data.court_y - kitchen_line)

		if dist_to_kitchen_line < KITCHEN_LINE_TOLERANCE:
			return {
				"violation": true,
				"type": ViolationType.LINE_FAULT,
				"message": "Touched line during volley!",
				"severe": true
			}

	# Priority 3: Not re-established after being in kitchen
	if hitter_data.was_in_kitchen and not hitter_data.feet_established and ball_height > 0:
		return {
			"violation": true,
			"type": ViolationType.NOT_ESTABLISHED,
			"message": "Must establish both feet outside!",
			"severe": true
		}

	# Priority 4: Momentum carried into kitchen after volley
	if hitter_data.momentum_timer > 0 and hitter_data.in_kitchen:
		var time_since_volley = 1.5 - hitter_data.momentum_timer
		if time_since_volley < 1.0 and hitter_data.volley_position != Vector2.ZERO:
			return {
				"violation": true,
				"type": ViolationType.MOMENTUM_CARRY,
				"message": "Momentum carried into kitchen!",
				"severe": true
			}

	# No violation
	return {
		"violation": false,
		"type": -1,
		"message": "",
		"severe": false
	}

func check_volley_in_kitchen(hitter_data: Dictionary, ball_height: float) -> bool:
	"""Simple check for volley in kitchen"""
	return hitter_data.in_kitchen and ball_height > 10.0

func check_line_fault(hitter_data: Dictionary, ball_height: float, is_player_team: bool) -> bool:
	"""Check if player touched kitchen line during volley"""
	if ball_height <= 0:
		return false  # Not a volley

	var kitchen_line = KITCHEN_LINE_BOTTOM if is_player_team else KITCHEN_LINE_TOP
	var dist_to_line = abs(hitter_data.court_y - kitchen_line)

	if dist_to_line < KITCHEN_LINE_TOLERANCE:
		emit_signal("line_fault", "player" if is_player_team else "opponent")
		return true

	return false

func check_establishment_violation(hitter_data: Dictionary, ball_height: float) -> bool:
	"""Check if player hit volley without re-establishing feet"""
	if ball_height <= 0:
		return false  # Ground stroke, OK

	if hitter_data.was_in_kitchen and not hitter_data.feet_established:
		emit_signal("establishment_required", "player" if hitter_data.get("is_player", false) else "other")
		return true

	return false

func check_momentum_violation(hitter_data: Dictionary) -> bool:
	"""Check for momentum carrying into kitchen after volley"""
	if hitter_data.momentum_timer <= 0:
		return false

	if hitter_data.in_kitchen:
		var time_since_volley = 1.5 - hitter_data.momentum_timer
		if time_since_volley < 1.0 and hitter_data.volley_position != Vector2.ZERO:
			emit_signal("momentum_violation", "player" if hitter_data.get("is_player", false) else "other")
			return true

	return false

func check_ball_out_of_bounds(court_x: float, court_y: float, court_width: float, court_height: float) -> Dictionary:
	"""Check if ball is out of bounds"""
	var out = false
	var message = ""

	if court_x < -10:
		out = true
		message = "Out - Wide Left!"
	elif court_x > court_width + 10:
		out = true
		message = "Out - Wide Right!"
	elif court_y < -10:
		out = true
		message = "Out - Past baseline!"
	elif court_y > court_height + 10:
		out = true
		message = "Out - Past baseline!"

	return {
		"out": out,
		"message": message
	}

func check_own_court_bounce(ball_y: float, last_hit_team: String) -> bool:
	"""Check if ball bounced on the hitter's own side"""
	var bounced_on_player_side = ball_y > NET_Y

	if last_hit_team == "player" and bounced_on_player_side:
		return true
	if last_hit_team == "opponent" and not bounced_on_player_side:
		return true

	return false

func record_volley_position(hitter_data: Dictionary, position: Vector2) -> void:
	"""Record position when volleying for momentum check"""
	hitter_data.volley_position = position
	hitter_data.momentum_timer = 1.5  # 1.5 seconds to check for momentum

func update_momentum_timers(all_players: Array, delta: float) -> void:
	"""Update momentum timers for all players"""
	for player_data in all_players:
		if player_data.momentum_timer > 0:
			player_data.momentum_timer -= delta

			# Check for momentum violation
			if player_data.in_kitchen and player_data.volley_position != Vector2.ZERO:
				var time_since_volley = 1.5 - player_data.momentum_timer
				if time_since_volley < 1.0:
					# Violation!
					var player_name = player_data.get("name", "unknown")
					emit_signal("violation_detected", player_name, "MOMENTUM_CARRY",
								"Momentum carried into kitchen!")
					player_data.momentum_timer = 0
					player_data.volley_position = Vector2.ZERO

			if player_data.momentum_timer <= 0:
				player_data.volley_position = Vector2.ZERO

func get_violation_message(type: ViolationType) -> String:
	"""Get user-friendly message for violation type"""
	match type:
		ViolationType.VOLLEY_IN_KITCHEN:
			return "Kitchen Violation: Cannot volley in kitchen!"
		ViolationType.LINE_FAULT:
			return "Kitchen Violation: Touched line during volley!"
		ViolationType.NOT_ESTABLISHED:
			return "Kitchen Violation: Must establish both feet outside!"
		ViolationType.MOMENTUM_CARRY:
			return "Momentum Violation: Carried into kitchen!"
		ViolationType.DOUBLE_BOUNCE:
			return "Double Bounce Violation: Must let ball bounce!"
		ViolationType.SERVICE_FAULT:
			return "Service Fault!"
		ViolationType.OUT_OF_BOUNDS:
			return "Out of Bounds!"
		ViolationType.OWN_COURT:
			return "Fault: Ball bounced on own side!"
		_:
			return "Violation!"
