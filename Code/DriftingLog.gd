extends Area2D

## Tronco Flutuante com Espinhos / Rocha Móvel (Obstáculo Dinâmico de Reflexo)

@export var move_distance: float = 350.0
@export var move_speed: float = 90.0
@export var move_axis: Vector2 = Vector2.DOWN
@export var damage: int = 25

var _start_pos: Vector2
var _direction: float = 1.0

func _ready() -> void:
	_start_pos = position
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	position += move_axis.normalized() * move_speed * _direction * delta
	var current_dist = (position - _start_pos).dot(move_axis.normalized())
	
	if current_dist > move_distance:
		_direction = -1.0
	elif current_dist < 0.0:
		_direction = 1.0

func _on_body_entered(body: Node2D) -> void:
	if body.has_method("_take_damage"):
		body._take_damage(damage)
