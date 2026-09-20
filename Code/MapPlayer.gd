extends Node2D

signal arrived_at_node(node: MapNode)

@export var current_node: MapNode
var is_moving: bool = false
var speed: float = 200.0 # Pixels per second

func _ready() -> void:
	if current_node:
		global_position = current_node.global_position
		arrived_at_node.emit(current_node)

func _unhandled_input(event: InputEvent) -> void:
	if is_moving or not current_node:
		return
		
	var target_node: MapNode = null
	
	if event.is_action_pressed("ui_up"):
		target_node = current_node.get_up()
	elif event.is_action_pressed("ui_down"):
		target_node = current_node.get_down()
	elif event.is_action_pressed("ui_left"):
		target_node = current_node.get_left()
	elif event.is_action_pressed("ui_right"):
		target_node = current_node.get_right()
		
	if target_node:
		# Check if unlocked or is the next level to unlock
		if target_node.level_id <= GameManager.highest_unlocked_level:
			_move_to_node(target_node)
			
	if event.is_action_pressed("ui_accept"):
		if current_node.level_scene != "":
			get_tree().change_scene_to_file(current_node.level_scene)
			
	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file("res://Scenes/TitleScreen.tscn")

func _move_to_node(target: MapNode) -> void:
	is_moving = true
	var dist = global_position.distance_to(target.global_position)
	var time = dist / speed
	
	var tween = create_tween()
	tween.tween_property(self, "global_position", target.global_position, time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(func():
		current_node = target
		is_moving = false
		arrived_at_node.emit(current_node)
	)
