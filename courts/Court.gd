# Court.gd
extends Node2D

# Reference to main game
@onready var main = get_node("/root/Main")

# Court areas for collision detection
@onready var kitchen_top_area: Area2D = $KitchenTopArea
@onready var kitchen_bottom_area: Area2D = $KitchenBottomArea
@onready var service_boxes: Node2D = $ServiceBoxes

# Visual elements
var bounce_markers: Array = []
var max_bounce_markers: int = 10

func _ready() -> void:
	setup_court_areas()
	setup_service_boxes()

func setup_court_areas() -> void:
	# Create collision shapes for kitchen zones
	if not kitchen_top_area:
		kitchen_top_area = Area2D.new()
		add_child(kitchen_top_area)
		kitchen_top_area.name = "KitchenTopArea"
	
	if not kitchen_bottom_area:
		kitchen_bottom_area = Area2D.new()
		add_child(kitchen_bottom_area)
		kitchen_bottom_area.name = "KitchenBottomArea"
	
	# Top kitchen collision shape
	var top_shape = CollisionPolygon2D.new()
	kitchen_top_area.add_child(top_shape)
	update_kitchen_collision_shapes()
	
	# Bottom kitchen collision shape
	var bottom_shape = CollisionPolygon2D.new()
	kitchen_bottom_area.add_child(bottom_shape)
	
	# Connect signals
	kitchen_top_area.body_entered.connect(_on_kitchen_entered.bind("top"))
	kitchen_top_area.body_exited.connect(_on_kitchen_exited.bind("top"))
	kitchen_bottom_area.body_entered.connect(_on_kitchen_entered.bind("bottom"))
	kitchen_bottom_area.body_exited.connect(_on_kitchen_exited.bind("bottom"))

func update_kitchen_collision_shapes() -> void:
	# Update collision shapes based on perspective
	var center_x = get_viewport().size.x / 2.0
	var court_scale = main.court_scale
	
	# Calculate scaled positions
	var net_pos = main.court_to_screen(main.COURT_WIDTH/2.0, main.NET_Y)
	var kitchen_top_pos = main.court_to_screen(main.COURT_WIDTH/2.0, main.KITCHEN_LINE_TOP)
	var kitchen_bottom_pos = main.court_to_screen(main.COURT_WIDTH/2.0, main.KITCHEN_LINE_BOTTOM)
	
	# Top kitchen polygon
	if kitchen_top_area.has_node("CollisionPolygon2D"):
		var top_collision = kitchen_top_area.get_node("CollisionPolygon2D") as CollisionPolygon2D
		var top_kitchen_scale = 1.0 - (1.0 - main.PERSPECTIVE_SCALE) * (1.0 - main.KITCHEN_LINE_TOP / main.COURT_HEIGHT)
		var net_scale = 1.0 - (1.0 - main.PERSPECTIVE_SCALE) * (1.0 - main.NET_Y / main.COURT_HEIGHT)
		
		top_collision.polygon = PackedVector2Array([
			Vector2(center_x - (main.COURT_WIDTH/2.0) * top_kitchen_scale * court_scale, kitchen_top_pos.y),
			Vector2(center_x + (main.COURT_WIDTH/2.0) * top_kitchen_scale * court_scale, kitchen_top_pos.y),
			Vector2(center_x + (main.COURT_WIDTH/2.0) * net_scale * court_scale, net_pos.y),
			Vector2(center_x - (main.COURT_WIDTH/2.0) * net_scale * court_scale, net_pos.y)
		])
	
	# Bottom kitchen polygon
	if kitchen_bottom_area.has_node("CollisionPolygon2D"):
		var bottom_collision = kitchen_bottom_area.get_node("CollisionPolygon2D") as CollisionPolygon2D
		var net_scale = 1.0 - (1.0 - main.PERSPECTIVE_SCALE) * (1.0 - main.NET_Y / main.COURT_HEIGHT)
		var bottom_kitchen_scale = 1.0 - (1.0 - main.PERSPECTIVE_SCALE) * (1.0 - main.KITCHEN_LINE_BOTTOM / main.COURT_HEIGHT)
		
		bottom_collision.polygon = PackedVector2Array([
			Vector2(center_x - (main.COURT_WIDTH/2.0) * net_scale * court_scale, net_pos.y),
			Vector2(center_x + (main.COURT_WIDTH/2.0) * net_scale * court_scale, net_pos.y),
			Vector2(center_x + (main.COURT_WIDTH/2.0) * bottom_kitchen_scale * court_scale, kitchen_bottom_pos.y),
			Vector2(center_x - (main.COURT_WIDTH/2.0) * bottom_kitchen_scale * court_scale, kitchen_bottom_pos.y)
		])

func setup_service_boxes() -> void:
	if not service_boxes:
		service_boxes = Node2D.new()
		add_child(service_boxes)
		service_boxes.name = "ServiceBoxes"
	
	# Create 4 service box areas (2 on each side)
	var boxes = ["TopLeft", "TopRight", "BottomLeft", "BottomRight"]
	for box_name in boxes:
		var service_box = Area2D.new()
		service_box.name = box_name
		service_boxes.add_child(service_box)
		
		var collision = CollisionShape2D.new()
		service_box.add_child(collision)
		
		# We'll update these shapes based on court dimensions
		update_service_box_shape(box_name, collision)

func update_service_box_shape(box_name: String, collision: CollisionShape2D) -> void:
	var rect = RectangleShape2D.new()
	
	# Calculate service box dimensions
	var box_width = main.COURT_WIDTH / 2.0
	var box_height = (main.KITCHEN_LINE_TOP - main.BASELINE_TOP) if box_name.begins_with("Top") else (main.BASELINE_BOTTOM - main.KITCHEN_LINE_BOTTOM)
	
	rect.size = Vector2(box_width * main.court_scale, box_height * main.court_scale)
	collision.shape = rect
	
	# Position the collision shape
	var x_offset = box_width / 2.0 if box_name.ends_with("Right") else -box_width / 2.0
	var y_pos = 0.0
	
	if box_name.begins_with("Top"):
		y_pos = (main.BASELINE_TOP + main.KITCHEN_LINE_TOP) / 2.0
	else:
		y_pos = (main.KITCHEN_LINE_BOTTOM + main.BASELINE_BOTTOM) / 2.0
	
	var screen_pos = main.court_to_screen(main.COURT_WIDTH / 2.0 + x_offset, y_pos)
	collision.position = screen_pos

func _on_kitchen_entered(body: Node2D, zone: String) -> void:
	if body.name == "Player":
		if zone == "bottom":
			# Player entered their kitchen
			if main.game_state.kitchen_state == main.KitchenState.AVAILABLE:
				print("Player entered kitchen during opportunity")

func _on_kitchen_exited(body: Node2D, zone: String) -> void:
	if body.name == "Player":
		if zone == "bottom":
			# Player exited their kitchen
			print("Player exited kitchen")

func add_bounce_marker(marker_pos: Vector2) -> void:
	# Create visual bounce indicator
	var marker = Node2D.new()
	add_child(marker)

	# Store marker data
	bounce_markers.append({
		"node": marker,
		"time": Time.get_ticks_msec(),
		"position": marker_pos
	})
	
	# Limit number of markers
	if bounce_markers.size() > max_bounce_markers:
		var old_marker = bounce_markers.pop_front()
		old_marker.node.queue_free()
	
	# Force redraw to show marker
	queue_redraw()

func _draw() -> void:
	# Draw bounce markers
	var current_time = Time.get_ticks_msec()
	
	for marker in bounce_markers:
		var age = current_time - marker.time
		if age < 3000:  # 3 seconds lifetime
			var alpha = 1.0 - (age / 3000.0)
			var color = Color(1.0, 0.4, 0, alpha * 0.6)
			
			# Draw X mark
			var size = 8
			draw_line(marker.position - Vector2(size, size), 
					 marker.position + Vector2(size, size), color, 2)
			draw_line(marker.position + Vector2(size, -size), 
					 marker.position - Vector2(size, -size), color, 2)
			
			# Draw circle around X
			draw_arc(marker.position, size * 0.7, 0, TAU, 16, color, 2)

func _process(delta: float) -> void:
	# Update bounce markers fade
	var current_time = Time.get_ticks_msec()
	var markers_to_remove = []
	
	for i in range(bounce_markers.size()):
		var marker = bounce_markers[i]
		var age = current_time - marker.time
		
		if age > 3000:  # 3 seconds lifetime
			markers_to_remove.append(i)
	
	# Remove old markers
	for i in range(markers_to_remove.size() - 1, -1, -1):
		var marker = bounce_markers[markers_to_remove[i]]
		marker.node.queue_free()
		bounce_markers.remove_at(markers_to_remove[i])
	
	# Force redraw if we have markers
	if bounce_markers.size() > 0:
		queue_redraw()

func is_in_correct_service_box(ball_pos: Vector2, expected_side: String, serving_from_top: bool) -> bool:
	# Convert ball position to court coordinates
	var court_pos = screen_to_court(ball_pos)
	var is_top_court = court_pos.y < main.NET_Y
	
	if serving_from_top:
		# Serving from top to bottom
		if not is_top_court:
			if court_pos.y > main.KITCHEN_LINE_BOTTOM and court_pos.y < main.BASELINE_BOTTOM:
				var landed_left = court_pos.x < main.COURT_WIDTH / 2.0
				var should_be_left = expected_side == "left"
				return landed_left == should_be_left
	else:
		# Serving from bottom to top
		if is_top_court:
			if court_pos.y > main.BASELINE_TOP and court_pos.y < main.KITCHEN_LINE_TOP:
				var landed_left = court_pos.x < main.COURT_WIDTH / 2.0
				var should_be_left = expected_side == "left"
				return landed_left == should_be_left
	
	return false

func screen_to_court(screen_pos: Vector2) -> Vector2:
	# Inverse of court_to_screen for collision detection
	var center_x = get_viewport().size.x / 2.0
	var court_top = main.COURT_OFFSET_Y * main.court_scale
	
	# Approximate inverse (simplified for now)
	var court_y = (screen_pos.y - court_top) / (0.9 * main.court_scale)
	var perspective_factor = 1.0 - (1.0 - main.PERSPECTIVE_SCALE) * (1.0 - court_y / main.COURT_HEIGHT)
	
	var relative_x = (screen_pos.x - center_x) / (perspective_factor * main.court_scale)
	var court_x = relative_x + main.COURT_WIDTH / 2.0
	
	return Vector2(court_x, court_y)
