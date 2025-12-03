# VisualEffects.gd - Visual polish and particle effects
extends Node2D

# Particle pools
var hit_particles: Array = []
var bounce_particles: Array = []
var mastery_particles: Array = []
var score_particles: Array = []

const POOL_SIZE: int = 20

# Screen shake
var shake_intensity: float = 0.0
var shake_decay: float = 5.0
var shake_offset: Vector2 = Vector2.ZERO

# Reference to camera
var camera: Camera2D = null

func _ready() -> void:
	create_particle_pools()
	print("VisualEffects initialized")

func _process(delta: float) -> void:
	# Update screen shake
	if shake_intensity > 0:
		shake_intensity = max(0, shake_intensity - shake_decay * delta)
		shake_offset = Vector2(
			randf_range(-shake_intensity, shake_intensity),
			randf_range(-shake_intensity, shake_intensity)
		)
		if camera:
			camera.offset = shake_offset
	elif camera and shake_offset != Vector2.ZERO:
		camera.offset = Vector2.ZERO
		shake_offset = Vector2.ZERO

	# Update all active particles
	update_particles(delta)

func create_particle_pools() -> void:
	"""Create reusable particle pools"""
	for _i in range(POOL_SIZE):
		hit_particles.append(create_hit_particle())
		bounce_particles.append(create_bounce_particle())
		mastery_particles.append(create_mastery_particle())
		score_particles.append(create_score_particle())

func create_hit_particle() -> Dictionary:
	"""Create a hit effect particle"""
	return {
		"active": false,
		"position": Vector2.ZERO,
		"velocity": Vector2.ZERO,
		"life": 0.0,
		"max_life": 0.3,
		"size": 4.0,
		"color": Color.WHITE,
		"type": "hit"
	}

func create_bounce_particle() -> Dictionary:
	"""Create a bounce effect particle"""
	return {
		"active": false,
		"position": Vector2.ZERO,
		"radius": 0.0,
		"life": 0.0,
		"max_life": 0.5,
		"color": Color(1.0, 0.84, 0, 0.5),
		"type": "bounce"
	}

func create_mastery_particle() -> Dictionary:
	"""Create a mastery effect particle"""
	return {
		"active": false,
		"position": Vector2.ZERO,
		"velocity": Vector2.ZERO,
		"life": 0.0,
		"max_life": 1.0,
		"size": 6.0,
		"color": Color(1.0, 0.84, 0),
		"rotation": 0.0,
		"type": "mastery"
	}

func create_score_particle() -> Dictionary:
	"""Create a score celebration particle"""
	return {
		"active": false,
		"position": Vector2.ZERO,
		"velocity": Vector2.ZERO,
		"life": 0.0,
		"max_life": 1.5,
		"size": 8.0,
		"color": Color.GREEN,
		"type": "score"
	}

func update_particles(delta: float) -> void:
	"""Update all active particles"""
	for particle in hit_particles:
		if particle.active:
			update_hit_particle(particle, delta)

	for particle in bounce_particles:
		if particle.active:
			update_bounce_particle(particle, delta)

	for particle in mastery_particles:
		if particle.active:
			update_mastery_particle(particle, delta)

	for particle in score_particles:
		if particle.active:
			update_score_particle(particle, delta)

	queue_redraw()

func update_hit_particle(p: Dictionary, delta: float) -> void:
	p.life -= delta
	if p.life <= 0:
		p.active = false
		return
	p.position += p.velocity * delta
	p.velocity *= 0.95  # Damping
	p.size *= 0.95

func update_bounce_particle(p: Dictionary, delta: float) -> void:
	p.life -= delta
	if p.life <= 0:
		p.active = false
		return
	p.radius += 150 * delta
	p.color.a = (p.life / p.max_life) * 0.5

func update_mastery_particle(p: Dictionary, delta: float) -> void:
	p.life -= delta
	if p.life <= 0:
		p.active = false
		return
	p.position += p.velocity * delta
	p.velocity.y += 50 * delta  # Light gravity
	p.rotation += 5 * delta
	p.color.a = (p.life / p.max_life)

func update_score_particle(p: Dictionary, delta: float) -> void:
	p.life -= delta
	if p.life <= 0:
		p.active = false
		return
	p.position += p.velocity * delta
	p.velocity.y += 100 * delta  # Gravity
	p.velocity.x *= 0.99  # Air resistance
	p.color.a = (p.life / p.max_life)

# =================== PUBLIC EFFECTS ===================

func spawn_hit_effect(pos: Vector2, power: float, color: Color = Color.WHITE) -> void:
	"""Spawn hit particles at position"""
	var count = int(5 + power * 10)
	for _i in range(count):
		var p = get_inactive_particle(hit_particles)
		if p:
			p.active = true
			p.position = pos
			var angle = randf() * TAU
			var speed = 100 + randf() * 150 * power
			p.velocity = Vector2(cos(angle) * speed, sin(angle) * speed)
			p.life = p.max_life
			p.size = 3 + randf() * 4 * power
			p.color = color

	# Small screen shake for power shots
	if power > 0.7:
		shake_screen(3 * power)

func spawn_bounce_effect(pos: Vector2) -> void:
	"""Spawn bounce ring effect"""
	var p = get_inactive_particle(bounce_particles)
	if p:
		p.active = true
		p.position = pos
		p.radius = 5
		p.life = p.max_life
		p.color = Color(1.0, 0.84, 0, 0.5)

func spawn_mastery_effect(center: Vector2) -> void:
	"""Spawn mastery activation burst"""
	for _i in range(30):
		var p = get_inactive_particle(mastery_particles)
		if p:
			p.active = true
			p.position = center
			var angle = randf() * TAU
			var speed = 200 + randf() * 300
			p.velocity = Vector2(cos(angle) * speed, sin(angle) * speed)
			p.life = p.max_life
			p.size = 4 + randf() * 6
			p.color = Color(1.0, 0.84, 0)
			p.rotation = randf() * TAU

	shake_screen(8)

func spawn_score_celebration(center: Vector2, is_player_point: bool) -> void:
	"""Spawn score celebration particles"""
	var base_color = Color(0.3, 0.69, 0.31) if is_player_point else Color(0.8, 0.2, 0.2)

	for _i in range(25):
		var p = get_inactive_particle(score_particles)
		if p:
			p.active = true
			p.position = center + Vector2(randf_range(-50, 50), randf_range(-20, 20))
			var angle = randf() * TAU
			var speed = 150 + randf() * 200
			p.velocity = Vector2(cos(angle) * speed, -abs(sin(angle)) * speed - 100)
			p.life = p.max_life
			p.size = 5 + randf() * 8
			p.color = base_color.lerp(Color.WHITE, randf() * 0.5)

	if is_player_point:
		shake_screen(5)

func spawn_violation_effect(pos: Vector2) -> void:
	"""Spawn violation/fault effect"""
	for _i in range(15):
		var p = get_inactive_particle(hit_particles)
		if p:
			p.active = true
			p.position = pos
			var angle = randf() * TAU
			var speed = 80 + randf() * 120
			p.velocity = Vector2(cos(angle) * speed, sin(angle) * speed)
			p.life = 0.4
			p.size = 4 + randf() * 4
			p.color = Color(1.0, 0.26, 0.21)

	shake_screen(6)

func shake_screen(intensity: float) -> void:
	"""Apply screen shake"""
	shake_intensity = max(shake_intensity, intensity)

func get_inactive_particle(pool: Array) -> Dictionary:
	"""Get an inactive particle from pool"""
	for p in pool:
		if not p.active:
			return p
	return pool[0] if pool.size() > 0 else {}

# =================== DRAWING ===================

func _draw() -> void:
	# Draw hit particles
	for p in hit_particles:
		if p.active:
			var alpha = p.life / p.max_life
			var c = Color(p.color.r, p.color.g, p.color.b, alpha)
			draw_circle(p.position, p.size, c)

	# Draw bounce rings
	for p in bounce_particles:
		if p.active:
			draw_arc(p.position, p.radius, 0, TAU, 32, p.color, 2)

	# Draw mastery particles
	for p in mastery_particles:
		if p.active:
			var c = p.color
			# Draw star shape
			draw_star(p.position, p.size, p.rotation, c)

	# Draw score particles
	for p in score_particles:
		if p.active:
			var c = p.color
			draw_circle(p.position, p.size, c)

func draw_star(center: Vector2, size: float, rotation: float, color: Color) -> void:
	"""Draw a 4-pointed star"""
	var points = []
	for i in range(8):
		var angle = rotation + i * PI / 4
		var r = size if i % 2 == 0 else size * 0.4
		points.append(center + Vector2(cos(angle), sin(angle)) * r)

	if points.size() >= 8:
		for i in range(8):
			var next = (i + 1) % 8
			draw_line(points[i], points[next], color, 2)
