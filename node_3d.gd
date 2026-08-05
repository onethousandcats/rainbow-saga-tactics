extends Node3D

# class-level vars
var grid = {}
var turn_manager: TurnManager
var character: Character
var tile_size = 2.0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	print("RAINBOW SAGA TACTICS")

	# spawn a grid of tiles
	for x in range(8):
		for z in range(8):
			var height = randi_range(0, 2) # Random height for visual variety

			var tile = MeshInstance3D.new()
			var mesh = BoxMesh.new()
			mesh.size = Vector3(tile_size, 0.2 + height, tile_size)
			
			tile.mesh = mesh
			tile.position = Vector3(x * tile_size, 0.1 + height / 2.0, z * tile_size)

			var material = StandardMaterial3D.new()

			if (x + z) % 2 == 0:
				material.albedo_color = Color(0.8, 0.8, 0.8)
			else:
				material.albedo_color = Color(0.6, 0.6, 0.6)

			tile.material_override = material

			var static_body = StaticBody3D.new()
			var collision_shape = CollisionShape3D.new()
			var shape = BoxShape3D.new()
			shape.size = mesh.size
			collision_shape.shape = shape

			static_body.set_meta("grid_pos", Vector2i(x, z))

			static_body.add_child(collision_shape)
			tile.add_child(static_body)

			grid[Vector2i(x, z)] = {"walkable": true, "node": tile, "occupant": null, "height": height, "base_color": material.albedo_color} # Random height for visual variety

			add_child(tile)

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

func set_occupant(pos: Vector2i, unit: Character) -> void:
	if grid.has(pos):
		grid[pos]["occupant"] = unit

func is_occupied(pos: Vector2i) -> bool:
	return grid.has(pos) and grid[pos]["occupant"] != null

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

func get_neighbors(pos: Vector2i, max_climb: float, max_drop: float) -> Array:
	var neighbors = []
	var directions = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	var current_height = grid[pos]["height"]

	for dir in directions:
		var neighbor = pos + dir
		if grid.has(neighbor) and grid[neighbor]["walkable"] and not is_occupied(neighbor):
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

func highlight_tiles(tiles: Array) -> void:
	for pos in grid.keys():
		var tile_node = grid[pos]["node"]
		var mat = StandardMaterial3D.new()
		if pos in tiles:
			mat.albedo_color = Color.YELLOW
		else:
			mat.albedo_color = grid[pos]["base_color"]
		tile_node.material_override = mat

func clear_highlights() -> void:
	for pos in grid.keys():
		var tile_node = grid[pos]["node"]
		var mat = StandardMaterial3D.new()
		mat.albedo_color = grid[pos]["base_color"]
		tile_node.material_override = mat

func take_npc_turn(unit: Character) -> void:
	var reachable = get_reachable_tiles(unit.grid_pos, unit.move_range)
	reachable.erase(unit.grid_pos)

	if reachable.size() == 0:
		turn_manager.advance_turn()
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
