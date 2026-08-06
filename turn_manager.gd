# turn_manager.gd
class_name TurnManager
extends Node

# Regular properties
var units: Array[Character] = []
var current_unit_index: int = 0
var bf: Node3D # Battlefield node reference

func setup(units_list: Array[Character], battlefield_node: Node3D) -> void:
	units = units_list
	bf = battlefield_node
	print("turn_manager setup complete with ", units.size(), " units.")

func current_unit() -> Character:
	if units.size() == 0:
		return null
	return units[current_unit_index]

func advance_turn() -> void:
	current_unit().end_turn()
	current_unit_index = (current_unit_index + 1) % units.size()
	var new_unit = current_unit()
	bf.highlight_tiles(bf.get_reachable_tiles(new_unit.grid_pos, new_unit.move_range))

	if not new_unit.is_player_controlled:
		bf.transition_camera_to(new_unit, func(): bf.take_npc_turn(new_unit))
	else:
		bf.transition_camera_to(new_unit) # Call the NPC turn function for AI-controlled units
