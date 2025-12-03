# ServiceRules.gd - Handles serve validation and double-bounce rule
extends Node

signal serve_valid(bounce_position: Vector2)
signal serve_fault(fault_type: String, message: String)
signal double_bounce_complete()
signal double_bounce_violation(team: String)

# Service state
var is_serve_in_progress: bool = false
var expected_service_box: String = ""  # "left" or "right"
var serve_bounced: bool = false
var return_bounced: bool = false
var _double_bounce_done: bool = false  # Renamed to avoid signal conflict
var consecutive_hits: int = 0

# Reference to main
var main_node: Node2D = null

# Court reference values (from Main.gd)
var COURT_WIDTH: float = 280.0
var COURT_HEIGHT: float = 560.0
var NET_Y: float = COURT_HEIGHT / 2.0
var KITCHEN_LINE_TOP: float = NET_Y - 70.0
var KITCHEN_LINE_BOTTOM: float = NET_Y + 70.0
var BASELINE_TOP: float = 30.0
var BASELINE_BOTTOM: float = COURT_HEIGHT - 30.0

func _ready() -> void:
	pass

func setup_from_main(main: Node2D) -> void:
	"""Get constants from main node"""
	main_node = main
	if main:
		COURT_WIDTH = main.COURT_WIDTH
		COURT_HEIGHT = main.COURT_HEIGHT
		NET_Y = main.NET_Y
		KITCHEN_LINE_TOP = main.KITCHEN_LINE_TOP
		KITCHEN_LINE_BOTTOM = main.KITCHEN_LINE_BOTTOM
		BASELINE_TOP = main.BASELINE_TOP
		BASELINE_BOTTOM = main.BASELINE_BOTTOM

func start_serve(serving_from_top: bool, target_box: String) -> void:
	"""Initialize serve validation for a new serve"""
	is_serve_in_progress = true
	expected_service_box = target_box
	serve_bounced = false
	return_bounced = false
	_double_bounce_done = false
	consecutive_hits = 0

	print("Serve started - expecting bounce in %s box" % expected_service_box)

func reset() -> void:
	"""Reset for new point"""
	is_serve_in_progress = false
	expected_service_box = ""
	serve_bounced = false
	return_bounced = false
	_double_bounce_done = false
	consecutive_hits = 0

func validate_serve_bounce(court_x: float, court_y: float, serving_from_top: bool) -> bool:
	"""Validate that serve bounced in correct service box"""
	if not is_serve_in_progress:
		return true

	# Check if ball crossed to opponent's side
	var on_correct_side = false
	if serving_from_top:
		# Serving from top (opponent serves) - must land on player's side
		on_correct_side = court_y > NET_Y
	else:
		# Serving from bottom (player serves) - must land on opponent's side
		on_correct_side = court_y < NET_Y

	if not on_correct_side:
		emit_signal("serve_fault", "NET_FAULT", "Serve didn't cross net!")
		return false

	# Check if in kitchen (NVZ) - serve cannot land in kitchen
	if serving_from_top:
		if court_y >= NET_Y and court_y <= KITCHEN_LINE_BOTTOM:
			emit_signal("serve_fault", "KITCHEN_FAULT", "Serve landed in kitchen!")
			return false
	else:
		if court_y <= NET_Y and court_y >= KITCHEN_LINE_TOP:
			emit_signal("serve_fault", "KITCHEN_FAULT", "Serve landed in kitchen!")
			return false

	# Check if in correct service box (diagonal from server)
	var in_correct_box = false
	if serving_from_top:
		# Landing on player's side
		if court_y > KITCHEN_LINE_BOTTOM and court_y < BASELINE_BOTTOM:
			var landed_left = court_x < COURT_WIDTH / 2.0
			var should_be_left = expected_service_box == "left"
			in_correct_box = landed_left == should_be_left
	else:
		# Landing on opponent's side
		if court_y > BASELINE_TOP and court_y < KITCHEN_LINE_TOP:
			var landed_left = court_x < COURT_WIDTH / 2.0
			var should_be_left = expected_service_box == "left"
			in_correct_box = landed_left == should_be_left

	if not in_correct_box:
		# Check if completely out of bounds
		if court_x < 0 or court_x > COURT_WIDTH or court_y < 0 or court_y > COURT_HEIGHT:
			emit_signal("serve_fault", "OUT_OF_BOUNDS", "Serve out of bounds!")
		else:
			emit_signal("serve_fault", "WRONG_BOX", "Serve landed in wrong service box!")
		return false

	# Valid serve!
	serve_bounced = true
	is_serve_in_progress = false
	emit_signal("serve_valid", Vector2(court_x, court_y))
	print("Valid serve! Bounced at (%d, %d)" % [int(court_x), int(court_y)])
	return true

func record_hit(team: String) -> void:
	"""Record a hit for double-bounce tracking"""
	consecutive_hits += 1

	print("Hit recorded - consecutive hits: %d, serve_bounced: %s, return_bounced: %s" % [
		consecutive_hits, serve_bounced, return_bounced
	])

func ball_bounced(team_side: String) -> void:
	"""Record a bounce for double-bounce tracking"""
	if not serve_bounced:
		# This is the serve bounce (already validated)
		serve_bounced = true
	elif not return_bounced and consecutive_hits == 1:
		# This is the return bounce (second required bounce)
		return_bounced = true
		_double_bounce_done = true
		emit_signal("double_bounce_complete")
		print("Double-bounce rule satisfied!")

func serve_landed_valid() -> void:
	"""Called when serve lands in valid position"""
	serve_bounced = true
	is_serve_in_progress = false

func can_volley(hitting_team: String, ball_height: float) -> bool:
	"""Check if a volley (hitting before bounce) is allowed"""
	# Cannot volley until double-bounce rule is satisfied
	if not _double_bounce_done and ball_height > 10.0:
		# Check which bounce we're waiting for
		if consecutive_hits == 0:
			# Receiver must let serve bounce
			emit_signal("double_bounce_violation", hitting_team)
			return false
		elif consecutive_hits == 1 and not return_bounced:
			# Server must let return bounce
			emit_signal("double_bounce_violation", hitting_team)
			return false

	return true

func check_double_bounce_violation(hitting_team: String, ball_has_bounced: bool) -> bool:
	"""Check if hitting before required bounce"""
	if _double_bounce_done:
		return false  # No violation possible after double-bounce complete

	# First hit (serve return) - must let serve bounce first
	if consecutive_hits == 0 and not serve_bounced:
		return true

	# Second hit (server's return) - must let return bounce first
	if consecutive_hits == 1 and not return_bounced and not ball_has_bounced:
		return true

	return false

func is_double_bounce_complete() -> bool:
	"""Check if the double-bounce rule has been satisfied"""
	return _double_bounce_done

func get_state() -> Dictionary:
	"""Get current state for debugging"""
	return {
		"is_serve_in_progress": is_serve_in_progress,
		"expected_service_box": expected_service_box,
		"serve_bounced": serve_bounced,
		"return_bounced": return_bounced,
		"double_bounce_done": _double_bounce_done,
		"consecutive_hits": consecutive_hits
	}
