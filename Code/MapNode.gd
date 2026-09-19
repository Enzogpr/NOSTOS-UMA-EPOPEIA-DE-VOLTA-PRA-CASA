extends Node2D
class_name MapNode

@export var level_id: int = 1
@export var level_scene: String = ""
@export var real_name: String = ""

@export var up_node: NodePath
@export var down_node: NodePath
@export var left_node: NodePath
@export var right_node: NodePath

func get_up() -> MapNode:
	return get_node_or_null(up_node) as MapNode

func get_down() -> MapNode:
	return get_node_or_null(down_node) as MapNode

func get_left() -> MapNode:
	return get_node_or_null(left_node) as MapNode

func get_right() -> MapNode:
	return get_node_or_null(right_node) as MapNode

func get_display_name() -> String:
	var highest = GameManager.highest_unlocked_level
	if highest > level_id:
		return real_name
	elif highest == level_id:
		return "Estação " + str(level_id)
	else:
		return "???"
