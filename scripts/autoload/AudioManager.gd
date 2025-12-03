# AudioManager.gd - Audio System Autoload
# Manages all game audio including hits, ambient, and UI sounds
extends Node

# Audio bus names
const BUS_MASTER: String = "Master"
const BUS_MUSIC: String = "Music"
const BUS_SFX: String = "SFX"
const BUS_UI: String = "UI"

# Audio players
var music_player: AudioStreamPlayer
var ambient_player: AudioStreamPlayer
var crowd_player: AudioStreamPlayer

# SFX players pool (for overlapping sounds)
var sfx_players: Array[AudioStreamPlayer2D] = []
var sfx_pool_size: int = 8

# UI audio player
var ui_player: AudioStreamPlayer

# Preloaded sounds (will be generated procedurally for MVP)
var hit_sounds: Array[AudioStream] = []
var bounce_sounds: Array[AudioStream] = []
var serve_sounds: Array[AudioStream] = []

# Sound settings
var music_volume: float = 0.8
var sfx_volume: float = 1.0
var ui_volume: float = 1.0

# Pitch variation for hit sounds
const HIT_PITCH_MIN: float = 0.9
const HIT_PITCH_MAX: float = 1.1

func _ready() -> void:
	setup_audio_buses()
	create_audio_players()
	generate_procedural_sounds()
	print("AudioManager initialized")

func setup_audio_buses() -> void:
	"""Setup audio buses if they don't exist"""
	# For MVP, we'll use the default Master bus
	# In production, create separate buses for music, SFX, UI
	pass

func create_audio_players() -> void:
	"""Create all audio player nodes"""
	# Music player
	music_player = AudioStreamPlayer.new()
	music_player.name = "MusicPlayer"
	music_player.bus = BUS_MASTER
	add_child(music_player)

	# Ambient player
	ambient_player = AudioStreamPlayer.new()
	ambient_player.name = "AmbientPlayer"
	ambient_player.bus = BUS_MASTER
	ambient_player.volume_db = -10.0
	add_child(ambient_player)

	# Crowd player
	crowd_player = AudioStreamPlayer.new()
	crowd_player.name = "CrowdPlayer"
	crowd_player.bus = BUS_MASTER
	crowd_player.volume_db = -15.0
	add_child(crowd_player)

	# UI player
	ui_player = AudioStreamPlayer.new()
	ui_player.name = "UIPlayer"
	ui_player.bus = BUS_MASTER
	add_child(ui_player)

	# SFX player pool (2D for positional audio)
	for i in range(sfx_pool_size):
		var player = AudioStreamPlayer2D.new()
		player.name = "SFXPlayer_%d" % i
		player.bus = BUS_MASTER
		player.max_distance = 2000.0
		add_child(player)
		sfx_players.append(player)

func generate_procedural_sounds() -> void:
	"""Generate procedural audio for MVP (no external files needed)"""
	# Generate hit sounds with different characteristics
	for i in range(5):
		var stream = generate_hit_sound(0.5 + i * 0.1)
		hit_sounds.append(stream)

	# Generate bounce sounds
	for i in range(3):
		var stream = generate_bounce_sound(0.3 + i * 0.1)
		bounce_sounds.append(stream)

	# Generate serve sound (longer, whoosh-like)
	serve_sounds.append(generate_serve_sound())

func generate_hit_sound(intensity: float) -> AudioStreamWAV:
	"""Generate a procedural paddle hit sound"""
	var sample_rate = 22050
	var duration = 0.08 + intensity * 0.05
	var samples = int(sample_rate * duration)

	var audio = AudioStreamWAV.new()
	audio.format = AudioStreamWAV.FORMAT_16_BITS
	audio.mix_rate = sample_rate
	audio.stereo = false

	var data = PackedByteArray()
	data.resize(samples * 2)

	for i in range(samples):
		var t = float(i) / sample_rate
		var envelope = exp(-t * 30.0)

		# Mix of frequencies for "pop" sound
		var freq1 = 800.0 + intensity * 400.0
		var freq2 = 1200.0 + intensity * 300.0
		var noise = (randf() - 0.5) * 0.3

		var sample = sin(t * freq1 * TAU) * 0.5
		sample += sin(t * freq2 * TAU) * 0.3
		sample += noise
		sample *= envelope * intensity

		var value = int(clamp(sample * 32767, -32768, 32767))
		data[i * 2] = value & 0xFF
		data[i * 2 + 1] = (value >> 8) & 0xFF

	audio.data = data
	return audio

func generate_bounce_sound(intensity: float) -> AudioStreamWAV:
	"""Generate a procedural ball bounce sound"""
	var sample_rate = 22050
	var duration = 0.05
	var samples = int(sample_rate * duration)

	var audio = AudioStreamWAV.new()
	audio.format = AudioStreamWAV.FORMAT_16_BITS
	audio.mix_rate = sample_rate
	audio.stereo = false

	var data = PackedByteArray()
	data.resize(samples * 2)

	for i in range(samples):
		var t = float(i) / sample_rate
		var envelope = exp(-t * 60.0)

		var freq = 400.0 + intensity * 200.0
		var sample = sin(t * freq * TAU) * envelope * intensity * 0.5

		var value = int(clamp(sample * 32767, -32768, 32767))
		data[i * 2] = value & 0xFF
		data[i * 2 + 1] = (value >> 8) & 0xFF

	audio.data = data
	return audio

func generate_serve_sound() -> AudioStreamWAV:
	"""Generate a procedural serve whoosh sound"""
	var sample_rate = 22050
	var duration = 0.15
	var samples = int(sample_rate * duration)

	var audio = AudioStreamWAV.new()
	audio.format = AudioStreamWAV.FORMAT_16_BITS
	audio.mix_rate = sample_rate
	audio.stereo = false

	var data = PackedByteArray()
	data.resize(samples * 2)

	for i in range(samples):
		var t = float(i) / sample_rate
		var envelope = sin(t / duration * PI)

		# Whoosh is mostly filtered noise
		var noise = (randf() - 0.5)
		var sample = noise * envelope * 0.4

		var value = int(clamp(sample * 32767, -32768, 32767))
		data[i * 2] = value & 0xFF
		data[i * 2 + 1] = (value >> 8) & 0xFF

	audio.data = data
	return audio

# =================== PLAYBACK FUNCTIONS ===================

func play_hit(power: float = 0.5, position: Vector2 = Vector2.ZERO) -> void:
	"""Play a paddle hit sound"""
	var player = get_available_sfx_player()
	if player and hit_sounds.size() > 0:
		var index = clampi(int(power * hit_sounds.size()), 0, hit_sounds.size() - 1)
		player.stream = hit_sounds[index]
		player.global_position = position
		player.volume_db = linear_to_db(sfx_volume * (0.7 + power * 0.3))
		player.pitch_scale = randf_range(HIT_PITCH_MIN, HIT_PITCH_MAX)
		player.play()

func play_bounce(position: Vector2 = Vector2.ZERO) -> void:
	"""Play a ball bounce sound"""
	var player = get_available_sfx_player()
	if player and bounce_sounds.size() > 0:
		var index = randi() % bounce_sounds.size()
		player.stream = bounce_sounds[index]
		player.global_position = position
		player.volume_db = linear_to_db(sfx_volume * 0.6)
		player.pitch_scale = randf_range(0.95, 1.05)
		player.play()

func play_serve(position: Vector2 = Vector2.ZERO) -> void:
	"""Play serve sound"""
	var player = get_available_sfx_player()
	if player and serve_sounds.size() > 0:
		player.stream = serve_sounds[0]
		player.global_position = position
		player.volume_db = linear_to_db(sfx_volume * 0.8)
		player.pitch_scale = 1.0
		player.play()

func play_fault() -> void:
	"""Play fault/violation sound"""
	var player = get_available_sfx_player()
	if player:
		# Generate a quick error beep
		var stream = generate_fault_sound()
		player.stream = stream
		player.volume_db = linear_to_db(sfx_volume * 0.7)
		player.play()

func generate_fault_sound() -> AudioStreamWAV:
	"""Generate a fault buzzer sound"""
	var sample_rate = 22050
	var duration = 0.2
	var samples = int(sample_rate * duration)

	var audio = AudioStreamWAV.new()
	audio.format = AudioStreamWAV.FORMAT_16_BITS
	audio.mix_rate = sample_rate
	audio.stereo = false

	var data = PackedByteArray()
	data.resize(samples * 2)

	for i in range(samples):
		var t = float(i) / sample_rate
		var envelope = 1.0 if t < duration * 0.9 else (duration - t) / (duration * 0.1)

		var sample = sin(t * 200 * TAU) * 0.3
		sample += sin(t * 250 * TAU) * 0.2
		sample *= envelope

		var value = int(clamp(sample * 32767, -32768, 32767))
		data[i * 2] = value & 0xFF
		data[i * 2 + 1] = (value >> 8) & 0xFF

	audio.data = data
	return audio

func play_ui_sound(sound_name: String) -> void:
	"""Play a UI sound effect"""
	var stream = generate_ui_sound(sound_name)
	if stream and ui_player:
		ui_player.stream = stream
		ui_player.volume_db = linear_to_db(ui_volume * 0.8)
		ui_player.play()

func generate_ui_sound(sound_name: String) -> AudioStreamWAV:
	"""Generate procedural UI sounds"""
	var sample_rate = 22050
	var duration = 0.1
	var freq = 800.0

	match sound_name:
		"button_press":
			freq = 600.0
			duration = 0.08
		"success":
			freq = 1000.0
			duration = 0.15
		"error":
			freq = 200.0
			duration = 0.2
		"score":
			freq = 1200.0
			duration = 0.2

	var samples = int(sample_rate * duration)

	var audio = AudioStreamWAV.new()
	audio.format = AudioStreamWAV.FORMAT_16_BITS
	audio.mix_rate = sample_rate
	audio.stereo = false

	var data = PackedByteArray()
	data.resize(samples * 2)

	for i in range(samples):
		var t = float(i) / sample_rate
		var envelope = exp(-t * 20.0)
		var sample = sin(t * freq * TAU) * envelope * 0.4

		var value = int(clamp(sample * 32767, -32768, 32767))
		data[i * 2] = value & 0xFF
		data[i * 2 + 1] = (value >> 8) & 0xFF

	audio.data = data
	return audio

func play_crowd_reaction(reaction: String) -> void:
	"""Play crowd reaction sound"""
	# For MVP, generate simple crowd noise
	pass

func play_mastery_activation() -> void:
	"""Play mastery activation fanfare"""
	play_ui_sound("score")
	# Could add more dramatic sound later

# =================== UTILITY ===================

func get_available_sfx_player() -> AudioStreamPlayer2D:
	"""Get an available SFX player from the pool"""
	for player in sfx_players:
		if not player.playing:
			return player
	# If all are busy, return the first one (will interrupt)
	return sfx_players[0] if sfx_players.size() > 0 else null

func set_music_volume(volume: float) -> void:
	"""Set music volume (0.0 to 1.0)"""
	music_volume = clamp(volume, 0.0, 1.0)
	music_player.volume_db = linear_to_db(music_volume)
	ambient_player.volume_db = linear_to_db(music_volume * 0.5)

func set_sfx_volume(volume: float) -> void:
	"""Set SFX volume (0.0 to 1.0)"""
	sfx_volume = clamp(volume, 0.0, 1.0)

func set_ui_volume(volume: float) -> void:
	"""Set UI sound volume (0.0 to 1.0)"""
	ui_volume = clamp(volume, 0.0, 1.0)

func stop_all() -> void:
	"""Stop all playing sounds"""
	music_player.stop()
	ambient_player.stop()
	crowd_player.stop()
	for player in sfx_players:
		player.stop()
