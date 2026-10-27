extends Node2D
signal arrived_at_node(node: MapNode)
signal entry_requested(path: String)
@export var current_node: MapNode
var is_moving := false
var speed := 650.0
var travel_tween: Tween

func _ready() -> void:
	if is_instance_valid(current_node): snap_to(current_node)

func snap_to(target: MapNode) -> void:
	if is_instance_valid(travel_tween): travel_tween.kill()
	current_node=target
	is_moving=false
	position=get_parent().to_local(target.global_position)
	arrived_at_node.emit(target)

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo(): return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		get_tree().change_scene_to_file("res://Scenes/TitleScreen.tscn")
		return
	if is_moving or not is_instance_valid(current_node): return
	var target: MapNode
	var key: int=event.keycode if event is InputEventKey else 0
	if event.is_action_pressed("ui_up") or key==KEY_W: target=current_node.get_up()
	elif event.is_action_pressed("ui_down") or key==KEY_S: target=current_node.get_down()
	elif event.is_action_pressed("ui_left") or key==KEY_A: target=current_node.get_left()
	elif event.is_action_pressed("ui_right") or key==KEY_D: target=current_node.get_right()
	if target!=null:
		request_travel(target)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		enter_current()
		get_viewport().set_input_as_handled()

func entry_path() -> String:
	if is_moving or not is_instance_valid(current_node) or not current_node.is_unlocked(): return ""
	return current_node.level_scene

func enter_current() -> bool:
	var path: String=entry_path()
	if path.is_empty() or not ResourceLoader.exists(path): return false
	entry_requested.emit(path)
	return true

func request_travel(target: MapNode) -> bool:
	if is_moving or not is_instance_valid(target) or not target.is_unlocked(): return false
	if target==current_node: return true
	is_moving=true
	var destination: Vector2=get_parent().to_local(target.global_position)
	var duration: float=clampf(position.distance_to(destination)/speed,0.16,0.75)
	travel_tween=create_tween()
	travel_tween.tween_property(self,"position",destination,duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	travel_tween.tween_callback(func():
		current_node=target
		is_moving=false
		arrived_at_node.emit(target)
	)
	return true
