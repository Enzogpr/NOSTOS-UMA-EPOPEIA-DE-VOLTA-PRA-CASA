extends Node2D

func _draw() -> void:
	get_parent().draw_stage(self)
