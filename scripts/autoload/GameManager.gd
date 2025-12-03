# GameManager.gd - Global Game State Autoload
# Manages game state, scoring, and persistence across scenes
extends Node

# Signals
signal game_started()
signal game_ended(winner: String)
signal point_scored(team: String, new_score: int)
signal side_out(new_serving_team: String)
signal rally_ended(winning_team: String, rally_length: int)
signal mastery_activated()
signal mastery_ended()
signal tutorial_completed()

# Game Constants - Pickleball Official Rules
const WINNING_SCORE: int = 11
const WIN_BY: int = 2
const MAX_SCORE: int = 15  # Tournament cap

# Court dimensions (in court units, scaled to screen)
const COURT_WIDTH: float = 280.0
const COURT_HEIGHT: float = 560.0
const COURT_OFFSET_Y: float = 60.0
const PERSPECTIVE_SCALE: float = 0.75

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
const HIT_DISTANCE: float = 80.0
const HIT_COOLDOWN: float = 0.4

# Game State
enum GamePhase { MENU, TUTORIAL, PRE_MATCH, PLAYING, PAUSED, POST_MATCH }
enum Team { PLAYER, OPPONENT }
enum ServingState { WAITING, IN_PROGRESS, COMPLETED }

var current_phase: GamePhase = GamePhase.MENU

# Score tracking (Pickleball format: score-score-server#)
var player_score: int = 0
var opponent_score: int = 0
var serving_team: Team = Team.PLAYER
var server_number: int = 2  # First game starts at server 2
var is_first_serve_of_game: bool = true

# Rally tracking
var rally_count: int = 0
var rally_length: int = 0
var consecutive_hits: int = 0
var total_rallies: int = 0

# Kitchen/Mastery
var kitchen_pressure: float = 0.0
var kitchen_pressure_max: float = 100.0
var mastery_active: bool = false
var mastery_timer: float = 0.0
var mastery_duration: float = 8.0
var kitchen_violations: Dictionary = {"player": 0, "opponent": 0}

# Ball state
var ball_in_play: bool = false
var waiting_for_serve: bool = false
var can_serve: bool = false
var first_bounce_complete: bool = false
var second_bounce_complete: bool = false
var is_serve_in_progress: bool = false
var expected_service_box: String = ""

# Statistics
var stats: Dictionary = {
	"games_played": 0,
	"games_won": 0,
	"total_points": 0,
	"longest_rally": 0,
	"dinks_hit": 0,
	"mastery_activations": 0,
	"kitchen_violations": 0
}

# Settings
var settings: Dictionary = {
	"music_volume": 0.8,
	"sfx_volume": 1.0,
	"vibration": true,
	"tutorial_completed": false
}

# Save file path
const SAVE_PATH: String = "user://pickleball_save.json"

func _ready() -> void:
	load_game_data()
	print("GameManager initialized")

func _process(delta: float) -> void:
	if mastery_active:
		mastery_timer -= delta
		if mastery_timer <= 0:
			end_mastery()

# =================== GAME FLOW ===================

func start_new_game() -> void:
	"""Initialize a new game"""
	player_score = 0
	opponent_score = 0
	serving_team = Team.PLAYER
	server_number = 2
	is_first_serve_of_game = true
	rally_count = 0
	rally_length = 0
	consecutive_hits = 0
	kitchen_pressure = 0.0
	mastery_active = false
	kitchen_violations = {"player": 0, "opponent": 0}

	current_phase = GamePhase.PLAYING
	waiting_for_serve = true
	can_serve = (serving_team == Team.PLAYER)

	emit_signal("game_started")
	print("New game started - Player serves")

func point_scored_by(team: Team) -> void:
	"""Handle point scoring with proper pickleball rules"""
	var team_name = "player" if team == Team.PLAYER else "opponent"

	# Update stats
	if team == Team.PLAYER:
		stats.total_points += 1

	if rally_length > stats.longest_rally:
		stats.longest_rally = rally_length

	total_rallies += 1

	# Only serving team can score
	if team == serving_team:
		if team == Team.PLAYER:
			player_score += 1
			emit_signal("point_scored", "player", player_score)
		else:
			opponent_score += 1
			emit_signal("point_scored", "opponent", opponent_score)

		# Switch server sides after scoring
		switch_server_sides()
		print("%s scores! Score: %d-%d-%d" % [team_name, player_score, opponent_score, server_number])
	else:
		# Side out - receiving team wins rally
		handle_side_out()

	# Check for game end
	if check_game_over():
		return

	# Reset for next point
	reset_for_new_point()

func handle_side_out() -> void:
	"""Handle side out (serving team loses rally)"""
	if is_first_serve_of_game:
		# First serve of game goes directly to side out
		serving_team = Team.OPPONENT if serving_team == Team.PLAYER else Team.PLAYER
		server_number = 1
		is_first_serve_of_game = false
	elif server_number == 1:
		# First server loses, go to second server
		server_number = 2
	else:
		# Second server loses, side out
		serving_team = Team.OPPONENT if serving_team == Team.PLAYER else Team.PLAYER
		server_number = 1

	var team_name = "player" if serving_team == Team.PLAYER else "opponent"
	emit_signal("side_out", team_name)
	print("Side out! %s now serving (server %d)" % [team_name, server_number])

func switch_server_sides() -> void:
	"""After scoring, server switches sides"""
	# In doubles, partners switch positions after scoring
	pass

func reset_for_new_point() -> void:
	"""Reset state for a new point"""
	ball_in_play = false
	waiting_for_serve = true
	can_serve = (serving_team == Team.PLAYER and server_number == 2) or \
				(serving_team == Team.PLAYER and server_number == 1)
	first_bounce_complete = false
	second_bounce_complete = false
	consecutive_hits = 0
	rally_length = 0
	is_serve_in_progress = false

	emit_signal("rally_ended", "player" if serving_team == Team.PLAYER else "opponent", rally_length)

func check_game_over() -> bool:
	"""Check if game has ended"""
	var player_wins = player_score >= WINNING_SCORE and (player_score - opponent_score) >= WIN_BY
	var opponent_wins = opponent_score >= WINNING_SCORE and (opponent_score - player_score) >= WIN_BY

	# Tournament cap
	if player_score >= MAX_SCORE or opponent_score >= MAX_SCORE:
		player_wins = player_score > opponent_score
		opponent_wins = opponent_score > player_score

	if player_wins or opponent_wins:
		var winner = "player" if player_wins else "opponent"
		end_game(winner)
		return true

	return false

func end_game(winner: String) -> void:
	"""End the current game"""
	current_phase = GamePhase.POST_MATCH
	stats.games_played += 1

	if winner == "player":
		stats.games_won += 1

	save_game_data()
	emit_signal("game_ended", winner)
	print("Game Over! %s wins %d-%d" % [winner, player_score, opponent_score])

# =================== SERVING ===================

func get_server_side() -> String:
	"""Determine which side server should be on based on score"""
	var score = player_score if serving_team == Team.PLAYER else opponent_score
	return "right" if score % 2 == 0 else "left"

func get_receiver_side() -> String:
	"""Determine diagonal receiver position"""
	var server_side = get_server_side()
	return "left" if server_side == "right" else "right"

func start_serve() -> void:
	"""Mark that serve has started"""
	ball_in_play = true
	waiting_for_serve = false
	is_serve_in_progress = true
	consecutive_hits = 0
	rally_length = 0
	first_bounce_complete = false
	second_bounce_complete = false

	# Determine expected service box (diagonal from server)
	expected_service_box = get_receiver_side()

func serve_fault() -> void:
	"""Handle a service fault"""
	is_serve_in_progress = false
	ball_in_play = false
	handle_side_out()
	reset_for_new_point()

# =================== KITCHEN/MASTERY ===================

func add_kitchen_pressure(amount: float) -> void:
	"""Add to kitchen pressure meter"""
	kitchen_pressure = clamp(kitchen_pressure + amount, 0.0, kitchen_pressure_max)

	if kitchen_pressure >= kitchen_pressure_max and not mastery_active:
		# Ready to activate mastery
		print("Mastery ready!")

func activate_mastery() -> void:
	"""Activate kitchen mastery mode"""
	if kitchen_pressure < kitchen_pressure_max or mastery_active:
		return

	mastery_active = true
	mastery_timer = mastery_duration
	kitchen_pressure = 0.0
	stats.mastery_activations += 1

	emit_signal("mastery_activated")
	print("MASTERY ACTIVATED!")

func end_mastery() -> void:
	"""End mastery mode"""
	mastery_active = false
	mastery_timer = 0.0
	emit_signal("mastery_ended")
	print("Mastery ended")

func record_kitchen_violation(team: String) -> void:
	"""Record a kitchen violation"""
	kitchen_violations[team] += 1
	if team == "player":
		stats.kitchen_violations += 1
		add_kitchen_pressure(-20.0)  # Penalty

# =================== UTILITY ===================

func get_score_string() -> String:
	"""Get score in pickleball format"""
	return "%d-%d-%d" % [player_score, opponent_score, server_number]

func get_visual_court_bounds(y: float) -> Dictionary:
	"""Calculate court bounds with perspective"""
	var perspective_factor = 1.0 - (1.0 - PERSPECTIVE_SCALE) * (1.0 - y / COURT_HEIGHT)
	var visual_width = COURT_WIDTH * perspective_factor
	var left_bound = (COURT_WIDTH - visual_width) / 2.0
	var right_bound = COURT_WIDTH - left_bound
	return {"left": left_bound, "right": right_bound, "width": visual_width}

# =================== PERSISTENCE ===================

func save_game_data() -> void:
	"""Save game statistics and settings"""
	var save_data = {
		"stats": stats,
		"settings": settings,
		"version": "1.0.0"
	}

	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data))
		file.close()
		print("Game data saved")

func load_game_data() -> void:
	"""Load saved game data"""
	if not FileAccess.file_exists(SAVE_PATH):
		print("No save file found, using defaults")
		return

	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file:
		var json = JSON.new()
		var error = json.parse(file.get_as_text())
		file.close()

		if error == OK:
			var data = json.get_data()
			if data.has("stats"):
				for key in data.stats:
					if stats.has(key):
						stats[key] = data.stats[key]
			if data.has("settings"):
				for key in data.settings:
					if settings.has(key):
						settings[key] = data.settings[key]
			print("Game data loaded")

func complete_tutorial() -> void:
	"""Mark tutorial as completed"""
	settings.tutorial_completed = true
	save_game_data()
	emit_signal("tutorial_completed")

func is_tutorial_completed() -> bool:
	"""Check if tutorial has been completed"""
	return settings.tutorial_completed

# =================== MENU SUPPORT ===================

func has_completed_tutorial() -> bool:
	"""Alias for is_tutorial_completed for menu compatibility"""
	return settings.tutorial_completed

func start_tutorial_mode() -> void:
	"""Set up for tutorial mode"""
	current_phase = GamePhase.TUTORIAL
	print("Tutorial mode started")

func get_setting(key: String, default_value = null):
	"""Get a setting value"""
	if settings.has(key):
		return settings[key]
	return default_value

func set_setting(key: String, value) -> void:
	"""Set a setting value"""
	settings[key] = value
	save_game_data()

	# Apply settings immediately
	match key:
		"sfx_volume":
			AudioManager.set_sfx_volume(float(value) / 100.0)
		"music_volume":
			AudioManager.set_music_volume(float(value) / 100.0)

func get_stats() -> Dictionary:
	"""Get statistics for display"""
	var display_stats = stats.duplicate()

	# Calculate win rate
	if stats.games_played > 0:
		display_stats["win_rate"] = float(stats.games_won) / float(stats.games_played)
	else:
		display_stats["win_rate"] = 0.0

	return display_stats

func reset_stats() -> void:
	"""Reset all statistics"""
	stats = {
		"games_played": 0,
		"games_won": 0,
		"total_points": 0,
		"longest_rally": 0,
		"dinks_hit": 0,
		"mastery_activations": 0,
		"kitchen_violations": 0
	}
	save_game_data()
	print("Statistics reset")
