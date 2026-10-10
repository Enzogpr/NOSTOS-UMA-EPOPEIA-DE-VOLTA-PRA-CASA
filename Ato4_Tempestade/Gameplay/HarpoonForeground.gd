extends Node2D

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	get_parent().get_parent().draw_foreground(self)
