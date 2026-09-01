extends Area2D

## Zona de Tempestade Violenta: Desativa bússola e cria ventos fortes

signal entered_storm(is_in_storm: bool)

@export var storm_wind: Vector2 = Vector2(40.0, 110.0)

var _tracked_ships: Array[Node2D] = []

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _physics_process(delta: float) -> void:
	for s in _tracked_ships:
		if is_instance_valid(s):
			s.position += storm_wind * delta

func _on_body_entered(body: Node2D) -> void:
	if body.has_method("repair_hull"):
		_tracked_ships.append(body)
		entered_storm.emit(true)

func _on_body_exited(body: Node2D) -> void:
	_tracked_ships.erase(body)
	if _tracked_ships.is_empty():
		entered_storm.emit(false)
