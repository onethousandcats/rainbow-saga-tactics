extends Node3D

# class-level vars
var grid = {}
var character: Character
var tile_size = 2.0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	print("RAINBOW SAGA TACTICS")

	# spawn a grid of tiles
	for x in range(8):
		for z in range(8):
			var tile = MeshInstance3D.new()
			var mesh = BoxMesh.new()
			mesh.size = Vector3(tile_size, 0.2, tile_size)
			
			tile.mesh = mesh
			tile.position = Vector3(x * tile_size, 0, z * tile_size)

			var static_body = StaticBody3D.new()
			var collision_shape = CollisionShape3D.new()
			var shape = BoxShape3D.new()
			shape.size = mesh.size
			collision_shape.shape = shape

			static_body.set_meta("grid_pos", Vector2i(x, z))

			static_body.add_child(collision_shape)
			tile.add_child(static_body)

			grid[Vector2i(x, z)] = {"walkable": true, "node": tile }

			add_child(tile)

	# spawn a player character
	character = Character.new()
	add_child(character)

	character.setup(Vector2i(0, 0), tile_size) # Initialize the character with starting position and tile size
	highlight_tiles(get_reachable_tiles(character.grid_pos, character.move_range))

func _unhandled_input(event: InputEvent) -> void:
	if character.is_animating:
		return # Ignore input while character is animating

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var cam = get_viewport().get_camera_3d()
		var from = cam.project_ray_origin(event.position)
		var to = from + cam.project_ray_normal(event.position) * 1000.0

		var space_state = get_world_3d().direct_space_state
		var query = PhysicsRayQueryParameters3D.create(from, to)
		var result = space_state.intersect_ray(query)

		print("Move range of character: ", character.move_range)
		print("Reachable tiles from character position: ", get_reachable_tiles(character.grid_pos, character.move_range))

		if result:
			var grid_pos = result.collider.get_meta("grid_pos")
			if not character.has_moved:
				var reachable = get_reachable_tiles(character.grid_pos, character.move_range)
				if grid_pos in reachable:
					var path = find_path(character.grid_pos, grid_pos)
					character.move_along_path(path)
					clear_highlights()
				else:
					print("Target tile is not reachable")
			else:
				print("Character has already moved this turn")

	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		character.end_turn()
		highlight_tiles(get_reachable_tiles(character.grid_pos, character.move_range))
		print("Turn ended")

func get_neighbors(pos: Vector2i) -> Array:
	var neighbors = []
	var directions = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

	for dir in directions:
		var neighbor = pos + dir
		if grid.has(neighbor) and grid[neighbor]["walkable"]:
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

		for neighbor in get_neighbors(current):
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

		for neighbor in get_neighbors(current):
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
			mat.albedo_color = Color.WHITE
		tile_node.set_surface_override_material(0, mat)

func clear_highlights() -> void:
	for pos in grid.keys():
		var tile_node = grid[pos]["node"]
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color.WHITE
		tile_node.set_surface_override_material(0, mat)
		