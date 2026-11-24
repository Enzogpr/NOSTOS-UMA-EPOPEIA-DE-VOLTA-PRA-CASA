extends Node2D
class_name MapNode
const DATA := preload("res://Code/JourneyMapData.gd")
var destination_id := ""
var real_name := ""
var short_name := ""
var subtitle := ""
var description := ""
var chapters: Array = []
var selected_chapter_id := ""
var selected := false
# These fields follow the selected chapter for existing scene callers.
var level_id := 1
var level_scene := ""
var journey_id := 1
var chapter_index := -1
var previous: MapNode
var following: MapNode

func configure(place: Dictionary, index: int) -> void:
	destination_id = place.id
	real_name = place.name
	short_name = real_name
	subtitle = place.subtitle
	description = place.description
	chapters = place.chapters
	position = place.position
	journey_id = index + 1
	select_chapter(recommended_chapter().get("id", ""))

func get_up() -> MapNode: return previous
func get_down() -> MapNode: return following
func get_left() -> MapNode: return previous
func get_right() -> MapNode: return following
func get_display_name() -> String: return real_name

func is_unlocked() -> bool:
	for entry in chapters:
		if DATA.chapter_unlocked(entry): return true
	return false

func is_completed() -> bool:
	for entry in chapters:
		if not DATA.chapter_completed(entry): return false
	return not chapters.is_empty()

func completed_chapters() -> int:
	var count := 0
	for entry in chapters:
		if DATA.chapter_completed(entry): count += 1
	return count

func latest_unlocked_order() -> int:
	var latest := -1
	for entry in chapters:
		if DATA.chapter_unlocked(entry): latest = maxi(latest, int(entry.order))
	return latest

func recommended_chapter() -> Dictionary:
	var last: Dictionary = {}
	for entry in chapters:
		if not DATA.chapter_unlocked(entry): continue
		last = entry
		if not DATA.chapter_completed(entry): return entry
	return last

func selected_chapter() -> Dictionary:
	for entry in chapters:
		if entry.id == selected_chapter_id: return entry
	return {}

func select_chapter(id: String) -> bool:
	for entry in chapters:
		if entry.id != id or not DATA.chapter_unlocked(entry): continue
		selected_chapter_id = id
		level_scene = entry.scene
		level_id = int(entry.act)
		chapter_index = int(entry.chapter)
		return true
	return false

func entry_scene() -> String:
	var entry := selected_chapter()
	return String(entry.scene) if not entry.is_empty() and DATA.chapter_unlocked(entry) else ""

func get_status_text() -> String:
	if is_completed(): return "CONCLUÍDO"
	if completed_chapters() > 0: return "EM ANDAMENTO"
	return "DISPONÍVEL" if is_unlocked() else "BLOQUEADO"

func _draw() -> void:
	var tint := Color("eccb83") if is_completed() else Color("91d5ce") if is_unlocked() else Color("758d94")
	if selected:
		draw_circle(Vector2.ZERO, 22, Color(0.96, 0.81, 0.48, 0.14))
		draw_arc(Vector2.ZERO, 19, 0, TAU, 48, Color("f8d99a"), 1.5, true)
	draw_circle(Vector2.ZERO, 10, Color("091d29"))
	draw_arc(Vector2.ZERO, 10, 0, TAU, 40, tint, 1.5, true)
	if is_completed():
		draw_polyline(PackedVector2Array([Vector2(-4,0),Vector2(-1,3),Vector2(5,-4)]), tint, 1.8, true)
	elif is_unlocked():
		draw_circle(Vector2.ZERO, 3, tint)
	else:
		draw_rect(Rect2(-3,-1,6,5), tint)
		draw_arc(Vector2(0,-1), 3, PI, TAU, 16, tint, 1.2, true)
