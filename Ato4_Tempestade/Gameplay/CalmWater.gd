extends Area2D

@export var radius: float = 180.0
var age: float = 0.0

func _ready() -> void:
	var shape := CircleShape2D.new()
	shape.radius = radius
	var collision := CollisionShape2D.new()
	collision.shape = shape
	add_child(collision)
	collision_layer = 0
	collision_mask = 2

func _process(delta: float) -> void:
	age += delta
	queue_redraw()

func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, Color(0.06, 0.43, 0.40, 0.20))
	for index in range(3):
		var size: float = radius - index * 21.0 + sin(age + index) * 3.0
		draw_arc(Vector2.ZERO, size, 0, TAU, 64, Color(0.38, 0.84, 0.74, 0.18 + index * 0.04), 2)
	draw_string(ThemeDB.fallback_font, Vector2(-63, -10), "ÁGUAS CALMAS", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.67, 0.97, 0.83))
	draw_string(ThemeDB.fallback_font, Vector2(-76, 17), "PARE + E: REPARAR", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.67, 0.97, 0.83, 0.7))
