extends Node2D

## Bando de Pássaros Marítimos (Gaivotas)
## Guia visual no meio da névoa. Se is_distractor = true, o bando voa de forma dispersa/escura indicando rota perigosa.

@export var fly_direction: Vector2 = Vector2.RIGHT
@export var fly_speed: float = 85.0
@export var is_distractor: bool = false

@onready var birds: Node2D = $Birds

func _ready() -> void:
	if is_distractor:
		# Pássaros dispersos / cinzentos
		birds.modulate = Color(0.65, 0.65, 0.7, 0.7)
		fly_speed *= 0.8
	else:
		# Gaivotas brancas puras
		birds.modulate = Color(1.0, 1.0, 1.0, 0.95)

func _process(delta: float) -> void:
	birds.position += fly_direction.normalized() * fly_speed * delta
	if birds.position.length() > 450.0:
		birds.position = -fly_direction.normalized() * 350.0
