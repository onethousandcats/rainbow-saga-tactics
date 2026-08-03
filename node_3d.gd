extends Node3D

# class-level vars
var grid = {}
var character: MeshInstance3D
var tile_size = 2.0
var has_moved = false

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

			grid[Vector2i(x, z)] = { "walkable": true }

			add_child(tile)

	# spawn a player character
	character = MeshInstance3D.new()
	var char_mesh = CapsuleMesh.new()

	character.mesh = char_mesh

	var starting_pos = Vector2i(0, 0)
	character.position = Vector3(starting_pos.x * tile_size, 1.0, starting_pos.y * tile_size)

	add_child(character)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var cam = get_viewport().get_camera_3d()
		var from = cam.project_ray_origin(event.position)
		var to = from + cam.project_ray_normal(event.position) * 1000.0

		var space_state = get_world_3d().direct_space_state
		var query = PhysicsRayQueryParameters3D.create(from, to)
		var result = space_state.intersect_ray(query)

		if result:
			var grid_pos = result.collider.get_meta("grid_pos")
			if not has_moved:
				character.position = Vector3(grid_pos.x * tile_size, character.position.y, grid_pos.y * tile_size)
				has_moved = true

	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		has_moved = false
