extends Node2D
class_name MapNode

@export var level_id: int = 1
@export var level_scene: String = ""
@export var real_name: String = ""
@export var short_name: String = ""
@export var journey_id: int = 1
@export var chapter_index: int = -1
var selected := false

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
	return real_name if is_unlocked() else "???"

func is_unlocked() -> bool:
	if GameManager.highest_unlocked_level<level_id: return false
	return chapter_index<0 or chapter_index<=GameManager.act4_unlocked_stage

func is_completed() -> bool:
	if not is_unlocked(): return false
	if chapter_index<0: return GameManager.highest_unlocked_level>level_id
	return GameManager.act4_completed or chapter_index<GameManager.act4_unlocked_stage

func get_status_text() -> String:
	return "CONCLUÍDA" if is_completed() else "DISPONÍVEL" if is_unlocked() else "BLOQUEADA"

func _draw() -> void:
	var color:=Color(0.91,0.76,0.38) if is_completed() else Color(0.47,0.86,0.89) if is_unlocked() else Color(0.38,0.43,0.46)
	if selected:
		draw_circle(Vector2.ZERO,26,Color(0.67,0.9,0.94,0.16))
		draw_arc(Vector2.ZERO,25,0,TAU,48,Color(0.76,0.95,0.97),2,true)
	draw_circle(Vector2.ZERO,18,Color(0.025,0.055,0.07,0.96))
	draw_arc(Vector2.ZERO,18,0,TAU,40,color,2.5,true)
	var text: String=str(journey_id) if is_unlocked() else "?"
	var font: Font=ThemeDB.fallback_font
	var width: float=font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,18).x
	draw_string(font,Vector2(-width*0.5,6),text,HORIZONTAL_ALIGNMENT_LEFT,-1,18,color)
