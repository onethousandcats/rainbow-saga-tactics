extends Node3D

# class-level vars
var grid = {}
var turn_manager: TurnManager
var character: Character
var tile_size = 2.0

@onready var camera: Camera3D = $Camera3D
var camera_offset = Vector3(14, 14, 14)
var camera_transitioning: bool = false
var camera_rotation_index: int = 0 # 0-3, representing 0, 90, 180, 270 degrees
var base_camera_offset = Vector3(14, 14, 14)

var camera_tween: Tween = null

var edit_mode: bool = false
var selected_tile: Vector2i
var has_selected_tile: bool = false

var tile_types = {
	"plains": {"walkable": true, "color": Color(0.6, 0.8, 0.4)},
	"grassland": {"walkable": true, "color": Color(0.4, 0.7, 0.3)},
	"river": {"walkable": true, "color": Color(0.3, 0.5, 0.8)},
	"ocean": {"walkable": false, "color": Color(0.2, 0.4, 0.7)},
	"mountain": {"walkable": true, "color": Color(0.5, 0.5, 0.5)},
}


# --- Godot lifecycle ---

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	print("RAINBOW SAGA TACTICS")

	# spawn a grid of tiles
	for x in range(16):
		for z in range(16):
			var height = randi_range(0, 2) # Random height for visual variety
			var type_name = tile_types.keys().pick_random()
			spawn_tile(x, z, type_name, height)

	# load_level("res://saved_level.json") # Load the level from a JSON file

	# spawn a player character
	var player_unit = Character.new()
	add_child(player_unit)
	player_unit.setup(Vector2i(0, 0), tile_size, grid[Vector2i(0, 0)]["height"]) # Initialize the character with starting position and tile size
	set_occupant(player_unit.grid_pos, player_unit)

	player_unit.is_player_controlled = true

	# spawn an enemy character
	var enemy_unit = Character.new()
	add_child(enemy_unit)
	enemy_unit.setup(Vector2i(7, 7), tile_size, grid[Vector2i(7, 7)]["height"])
	enemy_unit.is_player_controlled = false
	set_occupant(enemy_unit.grid_pos, enemy_unit)

	turn_manager = TurnManager.new()
	add_child(turn_manager)
	turn_manager.setup([player_unit, enemy_unit], self)

	highlight_tiles(get_reachable_tiles(turn_manager.current_unit().grid_pos, turn_manager.current_unit().move_range))

func _process(delta: float) -> void:
	if camera_transitioning:
		return # Skip camera updates while transitioning
	if turn_manager and turn_manager.units.size() > 0:
		var unit = turn_manager.current_unit()
		var angle = deg_to_rad(camera_rotation_index * 90)
		var rotated_offset = base_camera_offset.rotated(Vector3.UP, angle)
		camera.position = unit.position + rotated_offset
		camera.look_at(unit.position, Vector3.UP)

func _unhandled_input(event: InputEvent) -> void:
	var unit = turn_manager.current_unit()

	if unit.is_animating:
		return # Ignore input while character is animating

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var cam = get_viewport().get_camera_3d()
		var from = cam.project_ray_origin(event.position)
		var to = from + cam.project_ray_normal(event.position) * 1000.0

		var space_state = get_world_3d().direct_space_state
		var query = PhysicsRayQueryParameters3D.create(from, to)
		var result = space_state.intersect_ray(query)

		print("Move range of character: ", unit.move_range)
		print("Reachable tiles from character position: ", get_reachable_tiles(unit.grid_pos, unit.move_range))

		if result:
			var grid_pos = result.collider.get_meta("grid_pos")

			if edit_mode:
				selected_tile = grid_pos
				has_selected_tile = true
				edit_tile(grid_pos)
				return

			if not unit.has_moved:
				var reachable = get_reachable_tiles(unit.grid_pos, unit.move_range)
				if grid_pos in reachable:
					var old_pos = unit.grid_pos
					var path = find_path(old_pos, grid_pos)
					var heights = []
					for step in path:
						heights.append(grid[step]["height"])
					unit.move_along_path(path, heights)

					# update the grid occupancy
					set_occupant(old_pos, null)
					set_occupant(grid_pos, unit)

					clear_highlights()
				else:
					print("Target tile is not reachable")
			else:
				print("Character has already moved this turn")

	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		turn_manager.advance_turn()
		print("Turn ended")

	if event is InputEventKey and event.pressed and event.keycode == KEY_S:
		save_level("res://saved_level.json")
		print("Level saved")

	if event is InputEventKey and event.pressed and event.keycode == KEY_E:
		edit_mode = not edit_mode
		if not edit_mode:
			has_selected_tile = false
		print("Edit mode toggled: ", edit_mode)

	if event is InputEventKey and event.pressed and edit_mode and has_selected_tile:
		if event.keycode == KEY_UP:
			adjust_height(selected_tile, 1)
		elif event.keycode == KEY_DOWN:
			adjust_height(selected_tile, -1)

	if event is InputEventKey and event.pressed and event.keycode == KEY_L:
		load_level("res://saved_level.json")
		print("Level loaded")

	if event is InputEventKey and event.pressed and event.keycode == KEY_Q:
		rotate_camera(-1) # Rotate left
	elif event is InputEventKey and event.pressed and event.keycode == KEY_R:
		rotate_camera(1) # Rotate right


# --- Grid / occupancy ---

func set_occupant(pos: Vector2i, unit: Character) -> void:
	if grid.has(pos):
		grid[pos]["occupant"] = unit

func is_occupied(pos: Vector2i) -> bool:
	return grid.has(pos) and grid[pos]["occupant"] != null


# --- Tile management ---

func spawn_tile(x: int, z: int, type_name: String, height: int) -> void:
	var type_data = tile_types[type_name]

	var tile = MeshInstance3D.new()
	var mesh = BoxMesh.new()
	mesh.size = Vector3(tile_size, 0.2 + height, tile_size)
	tile.mesh = mesh
	tile.position = Vector3(x * tile_size, 0.1 + height / 2.0, z * tile_size)

	var material = StandardMaterial3D.new()
	material.albedo_color = type_data["color"]
	tile.material_override = material

	var static_body = StaticBody3D.new()
	var collision_shape = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = mesh.size
	collision_shape.shape = shape
	static_body.set_meta("grid_pos", Vector2i(x, z))
	static_body.add_child(collision_shape)
	tile.add_child(static_body)

	grid[Vector2i(x, z)] = {
		"type": type_name,
		"node": tile,
		"occupant": null,
		"height": height
	}

	add_child(tile)

func edit_tile(pos: Vector2i) -> void:
	if grid[pos]["occupant"] != null:
		print("Cannot edit tile at ", pos, " because it is occupied by a character.")
		return

	var current_type = grid[pos]["type"]
	var type_names = tile_types.keys()
	var current_index = type_names.find(current_type)
	var next_type = type_names[(current_index + 1) % type_names.size()]
	var height = grid[pos]["height"]

	grid[pos]["node"].queue_free()
	spawn_tile(pos.x, pos.y, next_type, height)

func adjust_height(pos: Vector2i, delta: int) -> void:
	var type_name = grid[pos]["type"]
	var new_height = grid[pos]["height"] + delta
	new_height = max(0, new_height)

	grid[pos]["node"].queue_free()
	spawn_tile(pos.x, pos.y, type_name, new_height)


# --- Level persistence ---

func save_level(path: String) -> void:
	var tiles = []
	for pos in grid.keys():
		tiles.append({
			"x": pos.x,
			"y": pos.y,
			"type": grid[pos]["type"],
			"height": grid[pos]["height"],
		})

	var data = {"tiles": tiles}
	var json_string = JSON.stringify(data)

	var file = FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(json_string)
		file.close()
		print("Level saved to ", path)
	else:
		print("Failed to save level to ", path)

func load_level(path: String) -> void:
	if not FileAccess.file_exists(path):
		print("Level file does not exist: ", path)
		return

	var file = FileAccess.open(path, FileAccess.READ)
	var json_string = file.get_as_text()
	file.close()

	var json = JSON.new()
	var parse_result = json.parse(json_string)
	if parse_result != OK:
		print("Failed to parse level JSON: ", json.get_error_message())
		return

	var data = json.data

	for tile_data in data["tiles"]:
		spawn_tile(tile_data["x"], tile_data["y"], tile_data["type"], tile_data["height"])


# --- Pathfinding / movement ---

func get_neighbors(pos: Vector2i, max_climb: float, max_drop: float) -> Array:
	var neighbors = []
	var directions = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	var current_height = grid[pos]["height"]

	for dir in directions:
		var neighbor = pos + dir
		if grid.has(neighbor) and tile_types[grid[neighbor]["type"]]["walkable"] and not is_occupied(neighbor):
			var height_diff = abs(grid[neighbor]["height"] - current_height)
			if grid[neighbor]["height"] > current_height:
				if height_diff <= max_climb:
					neighbors.append(neighbor)
			else:
				if height_diff <= max_drop:
					neighbors.append(neighbor)

	return neighbors

func get_reachable_tiles(start: Vector2i, move_range: int) -> Array:
	var distances = {start: 0}
	var queue = [start]

	while queue.size() > 0:
		var current = queue.pop_front()
		var current_distance = distances[current]

		if current_distance >= move_range:
			continue # don't expand further from here, out of range

		for neighbor in get_neighbors(current, turn_manager.current_unit().max_climb, turn_manager.current_unit().max_drop):
			if not distances.has(neighbor):
				distances[neighbor] = current_distance + 1
				queue.append(neighbor)

	return distances.keys()

func find_path(start: Vector2i, target: Vector2i) -> Array:
	var queue = [start]
	var came_from = {start: start}

	while queue.size() > 0:
		var current = queue.pop_front()

		if current == target:
			break

		for neighbor in get_neighbors(current, turn_manager.current_unit().max_climb, turn_manager.current_unit().max_drop):
			if not came_from.has(neighbor):
				came_from[neighbor] = current
				queue.append(neighbor)

	if not came_from.has(target):
		return [] # No path found

	var path = []
	var step = target
	while step != start:
		path.append(step)
		step = came_from[step]
	path.reverse()

	return path


# --- Tile highlighting ---

func highlight_tiles(tiles: Array) -> void:
	for pos in grid.keys():
		var tile_node = grid[pos]["node"]
		var mat = StandardMaterial3D.new()
		if pos in tiles:
			mat.albedo_color = Color.YELLOW
		else:
			mat.albedo_color = tile_types[grid[pos]["type"]]["color"]
		tile_node.material_override = mat

func clear_highlights() -> void:
	for pos in grid.keys():
		var tile_node = grid[pos]["node"]
		var mat = StandardMaterial3D.new()
		mat.albedo_color = tile_types[grid[pos]["type"]]["color"]
		tile_node.material_override = mat


# --- Turn logic ---

func take_npc_turn(unit: Character) -> void:
	var reachable = get_reachable_tiles(unit.grid_pos, unit.move_range)
	reachable.erase(unit.grid_pos)

	if reachable.size() == 0:
		call_deferred("advance_turn") # No reachable tiles, end turn
		return

	var target = reachable.pick_random()
	var old_pos = unit.grid_pos
	var path = find_path(old_pos, target)

	var heights = []
	for step in path:
		heights.append(grid[step]["height"])
	unit.move_along_path(path, heights)
	set_occupant(old_pos, null)
	set_occupant(target, unit)

	unit.move_finished.connect(turn_manager.advance_turn, CONNECT_ONE_SHOT)


# --- Camera ---

func rotate_camera(direction: int) -> void:
	camera_rotation_index = (camera_rotation_index + direction) % 4
	if camera_rotation_index < 0:
		camera_rotation_index += 4
	transition_camera_to(turn_manager.current_unit())

func transition_camera_to(unit: Character, on_finished: Callable = Callable()) -> void:
	if camera_tween and camera_tween.is_valid():
		camera_tween.kill()

	camera_transitioning = true
	var start_pos = camera.position
	var angle = deg_to_rad(camera_rotation_index * 90)
	var rotated_offset = base_camera_offset.rotated(Vector3.UP, angle)

	camera_tween = create_tween()
	camera_tween.tween_method(_update_camera_transition.bind(unit, start_pos, rotated_offset), 0.0, 1.0, 0.5)
	camera_tween.finished.connect(func():
		camera_transitioning = false
		if on_finished.is_valid():
			on_finished.call()
	)

func _update_camera_transition(t: float, unit: Character, start_pos: Vector3, offset: Vector3) -> void:
	var current_target = unit.position + offset
	camera.position = start_pos.lerp(current_target, t)
	camera.look_at(camera.position - offset, Vector3.UP)
