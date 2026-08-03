# character.gd
class_name Character
extends Node3D

# Signals
signal health_changed(new_health: int)
signal died

# Exported properties (visibile in the editor inspector)
@export var character_name: String = "Unnamed"
@export var max_health: int = 100
@export var move_range: int = 3
@export var attack_power: int = 10

# Regular properties
var current_health: int = max_health
var grid_pos: Vector2i
var tile_size: float = 2.0
var has_moved: bool = false
var is_alive: bool = true

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

func setup(start_pos: Vector2i, size: float) -> void:
	grid_pos = start_pos
	tile_size = size
	print("Character ", character_name, " is set up at position ", grid_pos)

	var mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = CapsuleMesh.new()

	add_child(mesh_instance)

	position = Vector3(grid_pos.x * tile_size, 1.0, grid_pos.y * tile_size)

func move_along_path(path: Array) -> void:
	if path.size() == 0:
		return

	var tween = create_tween()
	for step in path:
		var target = Vector3(step.x * tile_size, position.y, step.y * tile_size)
		tween.tween_property(self, "position", target, 0.3)

	grid_pos = path[path.size() - 1]
	has_moved = true

func end_turn() -> void:
	has_moved = false
