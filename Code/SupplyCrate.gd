extends Area2D

## Barril / Caixa de Suprimentos Flutuante

@export var heal_amount: int = 25

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	# Movimento suave de flutuação na água
	position.y += sin(Time.get_ticks_msec() * 0.003 + position.x) * 0.25

func _on_body_entered(body: Node2D) -> void:
	if body.has_method("repair_hull"):
		body.repair_hull(heal_amount)
		queue_free()
