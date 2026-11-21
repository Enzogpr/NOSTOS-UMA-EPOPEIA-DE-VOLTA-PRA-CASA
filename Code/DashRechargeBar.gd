extends Node2D

const BAR := Rect2(-15, 12, 30, 4)
const BACKGROUND := Color(0.2, 0.2, 0.2, 0.8)
const FILL := Color(0.2, 0.8, 1.0)

var progress := 0.0

func _init() -> void:
	hide()

func update_at(feet: Vector2, remaining: float, total: float, active: bool = true) -> void:
	position = feet
	visible = active and remaining > 0.0 and total > 0.0
	if visible:
		progress = 1.0 - clampf(remaining / total, 0.0, 1.0)
		queue_redraw()

func _draw() -> void:
	draw_rect(BAR, BACKGROUND)
	draw_rect(Rect2(BAR.position, Vector2(BAR.size.x * progress, BAR.size.y)), FILL)
