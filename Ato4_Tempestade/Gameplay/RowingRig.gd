extends Node2D
## Each oar turns around its own rowlock; hull, sail and ram remain rigid.

var phase: float = 0.0
var effort: float = 0.0
var oars: Array[Node2D] = []
var sides: Array[float] = []
@onready var ship: CharacterBody2D = get_parent()

func _ready() -> void:
	for side in [-1.0, 1.0]:
		for index in range(12):
			var pivot := Node2D.new()
			pivot.position = Vector2(-44 + index * 9.0, side * 16.5)
			pivot.name = "Oar_%s_%d" % ["Port" if side < 0 else "Starboard", index]
			pivot.rotation = side * PI / 2.0
			add_child(pivot)
			var shaft := Polygon2D.new()
			shaft.polygon = PackedVector2Array([Vector2(0, -1.3), Vector2(29, -1.3), Vector2(29, 1.3), Vector2(0, 1.3)])
			shaft.color = Color(0.48, 0.29, 0.13)
			pivot.add_child(shaft)
			var blade := Polygon2D.new()
			blade.polygon = PackedVector2Array([Vector2(22, -2), Vector2(27, -3), Vector2(34, -3), Vector2(35, -1), Vector2(35, 1), Vector2(34, 3), Vector2(27, 3), Vector2(22, 2)])
			blade.color = Color(0.55, 0.16, 0.08)
			pivot.add_child(blade)
			var edge := Line2D.new()
			edge.points = PackedVector2Array([Vector2(1, -0.7), Vector2(28, -0.7), Vector2(34, -1.8)])
			edge.width = 0.8
			edge.default_color = Color(0.89, 0.63, 0.3)
			pivot.add_child(edge)
			oars.append(pivot)
			sides.append(side)

func _process(delta: float) -> void:
	var command: float = ship.rowing_effort if ship.sailing else 0.0
	effort = move_toward(effort, absf(command), delta * 3.0)
	if effort > 0.01:
		phase += delta * (3.5 + absf(ship.speed) * 0.017) * signf(command if command != 0 else 1.0)
	for index in oars.size():
		var side: float = sides[index]
		var turn_bias: float = ship.helm_turn * side * 0.12
		var stroke: float = sin(phase + (index % 12) * 0.055 + turn_bias) * 0.48 * effort
		oars[index].rotation = side * PI / 2.0 + side * (stroke - 0.16)
	queue_redraw()

func _draw() -> void:
	if effort < 0.1:
		return
	for index in range(0, oars.size(), 3):
		if sin(phase) > 0.2:
			var tip: Vector2 = oars[index].position + Vector2(34, 0).rotated(oars[index].rotation)
			draw_line(tip + Vector2(-3, -1), tip + Vector2(3, 1), Color(0.67, 0.88, 0.9, 0.48), 1.4)
