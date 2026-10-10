extends Area2D
## The current participates in move_and_slide; it never teleports the hull.

@export var radius: float = 240.0
@export var pull_strength: float = 215.0
var age: float = 0.0

func _ready() -> void:
	var shape := ($Influence.shape as CircleShape2D).duplicate() as CircleShape2D
	shape.radius = radius
	$Influence.shape = shape

func field_at(point: Vector2) -> Vector2:
	var toward: Vector2 = global_position - point
	var distance: float = toward.length()
	if distance > radius or distance < 0.01:
		return Vector2.ZERO
	var depth: float = 1.0 - distance / radius
	var inward: Vector2 = toward / distance
	return inward * lerpf(pull_strength * 0.25, pull_strength, depth) + inward.orthogonal() * lerpf(28, 80, depth)

func contains(point: Vector2) -> bool:
	return global_position.distance_to(point) <= radius

func _process(delta: float) -> void:
	age += delta
	queue_redraw()

func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, Color(0.025, 0.08, 0.14, 0.35))
	for ring in range(9):
		draw_circle(Vector2.ZERO, radius * (1.0 - ring / 10.0), Color(0.005, 0.025, 0.055, 0.055))
	for arm in range(5):
		var points := PackedVector2Array()
		var foam := PackedVector2Array()
		for step in range(100):
			var t: float = step / 99.0
			var angle: float = arm * TAU / 5.0 + t * TAU * 1.6 - age * 1.3
			var r: float = 28 + t * (radius - 28)
			var point := Vector2(cos(angle), sin(angle)) * r
			points.append((point / 3.0).floor() * 3.0)
			if step > 58:
				foam.append((point / 3.0).floor() * 3.0)
		draw_polyline(points, Color(0.11, 0.36, 0.44, 0.6), 9)
		draw_polyline(foam, Color(0.57, 0.81, 0.84, 0.55), 2)
	draw_circle(Vector2.ZERO, 25, Color(0.005, 0.013, 0.033))
