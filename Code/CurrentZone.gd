extends Area2D

## Corrente Marítima: Empurra o navio lateralmente em direção a perigos

@export var current_direction: Vector2 = Vector2.DOWN
@export var current_force: float = 140.0

var _tracked_ships: Array[Node2D] = []

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _physics_process(delta: float) -> void:
	for s in _tracked_ships:
		if is_instance_valid(s):
			s.position += current_direction.normalized() * current_force * delta

func _on_body_entered(body: Node2D) -> void:
	if body.has_method("repair_hull"):
		_tracked_ships.append(body)

func _on_body_exited(body: Node2D) -> void:
	_tracked_ships.erase(body)
