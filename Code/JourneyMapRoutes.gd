extends Node2D
var stops: Array[MapNode] = []

func _draw() -> void:
	if stops.size() != 12: return
	for index in range(1, 11):
		_segment(stops[index-1].position, stops[index].position, stops[index].is_unlocked())
	# Caribdis reuses the strait. The return voyage is a second route, not a pin.
	var return_route := PackedVector2Array([stops[10].position,Vector2(525,539),Vector2(196,539),stops[8].position])
	var home_route := PackedVector2Array([stops[8].position,Vector2(194,545),Vector2(702,545),stops[11].position])
	for index in range(1,return_route.size()): _segment(return_route[index-1],return_route[index],GameManager.calypso_completed,true)
	for index in range(1,home_route.size()): _segment(home_route[index-1],home_route[index],GameManager.charybdis_completed,true)

func _segment(from: Vector2, to: Vector2, unlocked: bool, returning := false) -> void:
	var shade := Color(0.91,0.77,0.47,0.6) if unlocked else Color(0.48,0.65,0.68,0.22)
	if returning: shade = Color(0.44,0.85,0.88,0.56) if unlocked else Color(0.44,0.66,0.71,0.16)
	var direction := (to-from).normalized()
	var start := from + direction * 17
	var finish := to - direction * 17
	if from.distance_to(to) < 40:
		start = from
		finish = to
	draw_dashed_line(start,finish,shade,1.3,5.0,true,true)
