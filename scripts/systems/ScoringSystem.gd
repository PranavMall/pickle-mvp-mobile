# ScoringSystem.gd - Handles pickleball scoring rules
extends Node

signal score_updated(player_score: int, opponent_score: int, server_number: int)
signal game_point(team: String)
signal match_point(team: String)
signal game_over(winner: String)

# Score state
var player_score: int = 0
var opponent_score: int = 0
var serving_team: String = "player"  # "player" or "opponent"
var server_number: int = 2  # 1 or 2 (which partner is serving)
var is_first_serve_of_game: bool = true

# Game constants
const WINNING_SCORE: int = 11
const WIN_BY: int = 2
const TOURNAMENT_CAP: int = 15

# Reference to main
var main_node: Node2D = null

func _ready() -> void:
	pass

func reset() -> void:
	"""Reset scoring for a new game"""
	player_score = 0
	opponent_score = 0
	serving_team = "player"
	server_number = 2  # First game starts with server 2 (side-out rule)
	is_first_serve_of_game = true
	emit_signal("score_updated", player_score, opponent_score, server_number)

func rally_won_by(team: String) -> void:
	"""Called when a team wins a rally"""
	print("Rally won by: %s (serving: %s)" % [team, serving_team])

	if team == serving_team:
		# Serving team scores a point
		if team == "player":
			player_score += 1
		else:
			opponent_score += 1

		# After scoring, server switches court sides
		_switch_server_sides()

		print("Point scored! Score: %d-%d-%d" % [player_score, opponent_score, server_number])

		# Check for game/match point situations
		_check_game_point()
	else:
		# Receiving team wins rally = side out
		_handle_side_out()

	emit_signal("score_updated", player_score, opponent_score, server_number)

	# Check if game is over
	if _is_game_over():
		var winner = "player" if player_score > opponent_score else "opponent"
		emit_signal("game_over", winner)

func _handle_side_out() -> void:
	"""Handle side out (serving team loses rally)"""
	print("Side out!")

	if is_first_serve_of_game:
		# First serve of game - immediate side out
		serving_team = "opponent" if serving_team == "player" else "player"
		server_number = 1
		is_first_serve_of_game = false
	elif server_number == 1:
		# First server loses - switch to second server
		server_number = 2
	else:
		# Second server loses - side out
		serving_team = "opponent" if serving_team == "player" else "player"
		server_number = 1

	print("Now serving: %s (server %d)" % [serving_team, server_number])

func _switch_server_sides() -> void:
	"""After scoring, the server/partner positions swap"""
	# This is tracked in player positions, not here
	pass

func _check_game_point() -> void:
	"""Check if either team is at game/match point"""
	var player_can_win = player_score >= WINNING_SCORE - 1 and \
						 (player_score - opponent_score) >= WIN_BY - 1
	var opponent_can_win = opponent_score >= WINNING_SCORE - 1 and \
						   (opponent_score - player_score) >= WIN_BY - 1

	if player_can_win and serving_team == "player":
		emit_signal("game_point", "player")
		if main_node:
			main_node.show_message("GAME POINT!", main_node.COURT_WIDTH/2.0,
								   main_node.COURT_HEIGHT/2.0, Color(1.0, 0.84, 0))
	elif opponent_can_win and serving_team == "opponent":
		emit_signal("game_point", "opponent")

func _is_game_over() -> bool:
	"""Check if game has ended"""
	# Standard win condition
	if player_score >= WINNING_SCORE and (player_score - opponent_score) >= WIN_BY:
		return true
	if opponent_score >= WINNING_SCORE and (opponent_score - player_score) >= WIN_BY:
		return true

	# Tournament cap (whoever is ahead at 15 wins)
	if player_score >= TOURNAMENT_CAP or opponent_score >= TOURNAMENT_CAP:
		return true

	return false

func get_score_string() -> String:
	"""Get score in official pickleball format: player-opponent-server#"""
	if serving_team == "player":
		return "%d-%d-%d" % [player_score, opponent_score, server_number]
	else:
		return "%d-%d-%d" % [opponent_score, player_score, server_number]

func get_server_side() -> String:
	"""Get which side of court the server should be on"""
	var serving_score = player_score if serving_team == "player" else opponent_score
	# Even score = right side, Odd score = left side
	return "right" if serving_score % 2 == 0 else "left"

func get_receiver_side() -> String:
	"""Get the diagonal receiving position"""
	var server_side = get_server_side()
	return "left" if server_side == "right" else "right"

func is_player_serving() -> bool:
	"""Check if player team is currently serving"""
	return serving_team == "player"

func is_player_first_server() -> bool:
	"""Check if the player (not partner) is the current server"""
	return serving_team == "player" and server_number == 2

func get_serving_info() -> Dictionary:
	"""Get complete serving information"""
	return {
		"team": serving_team,
		"server_number": server_number,
		"side": get_server_side(),
		"receiver_side": get_receiver_side(),
		"is_first_serve_of_game": is_first_serve_of_game
	}
