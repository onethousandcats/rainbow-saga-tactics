# character.gd
class_name Character
extends Node3D

# Signals
signal health_changed(new_health: int)
signal died
signal move_finished

# Exported properties (visibile in the editor inspector)
@export var character_name: String = "Unnamed"
@export var max_health: int = 100
@export var move_range: int = 3
@export var attack_power: int = 10
@export var max_climb: float = 1.0 # Maximum height difference the character can climb
@export var max_drop: float = 3.0 # Maximum height difference the character can drop

# Regular properties
var current_health: int = max_health
var grid_pos: Vector2i
var tile_size: float = 2.0
var has_moved: bool = false
var is_alive: bool = true
var is_animating: bool = false
var is_player_controlled: bool = true
var facing: Vector2i = Vector2i(0, 1) # Default facing direction (down)
var facing_marker: MeshInstance3D

func _ready() -> void:
	print("Character ", character_name, " has entered the battlefield with ", current_health, " health")

func take_damage(amount: int) -> void:
	if not is_alive:
		return

	current_health = max(0, current_health - amount)
	emit_signal("health_changed", current_health)

	if current_health == 0:
		_die()

func _die() -> void:
	is_alive = false
	emit_signal("died")
	print("Character ", character_name, " has fallen")

func setup(start_pos: Vector2i, size: float, tile_height: float) -> void:
	grid_pos = start_pos
	tile_size = size
	print("Character ", character_name, " is set up at position ", grid_pos)

	var mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = CapsuleMesh.new()
	add_child(mesh_instance)

	facing_marker = MeshInstance3D.new()
	var marker_mesh = BoxMesh.new()
	marker_mesh.size = Vector3(0.3, 0.3, 0.3)
	facing_marker.mesh = marker_mesh
	add_child(facing_marker)
	update_facing_marker()

	position = Vector3(grid_pos.x * tile_size, tile_height + 1.0, grid_pos.y * tile_size)

func move_along_path(path: Array, heights: Array) -> void:
	if path.size() == 0:
		return

	is_animating = true

	var last_step = path[path.size() - 1]
	var second_to_last = path[path.size() - 2] if path.size() > 1 else grid_pos
	facing = last_step - second_to_last
	update_facing_marker()

	var tween = create_tween()
	for step in path:
		var target = Vector3(step.x * tile_size, heights[path.find(step)] + 1.0, step.y * tile_size)
		tween.tween_property(self, "position", target, 0.3)

	tween.finished.connect(_on_move_finished)

	grid_pos = path[path.size() - 1]
	has_moved = true

func _on_move_finished() -> void:
	is_animating = false
	move_finished.emit()

func end_turn() -> void:
	has_moved = false

func update_facing_marker() -> void:
	var offset_distance = 0.6
	var offset = Vector3(facing.x, 0, facing.y) * offset_distance
	facing_marker.position = offset
