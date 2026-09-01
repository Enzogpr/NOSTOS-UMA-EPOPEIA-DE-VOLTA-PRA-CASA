extends Area2D

## Redemoinho Marítimo: Puxa o navio para o centro e causa dano contínuo se ficar preso

@export var pull_force: float = 160.0
@export var damage_per_second: float = 15.0

@onready var visual: Node2D = $Visual

var _tracked_ships: Array[Node2D] = []

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _process(delta: float) -> void:
	# Efeito de rotação do vórtice
	visual.rotation -= 3.0 * delta
	
	# Puxa os navios em direção ao centro
	for ship in _tracked_ships:
		if is_instance_valid(ship):
			var to_center = (global_position - ship.global_position)
			var dist = to_center.length()
			if dist > 5.0:
				var pull_dir = to_center.normalized()
				var vortex_force = (pull_dir + pull_dir.orthogonal() * 0.5).normalized() * pull_force * (1.0 - clamp(dist / 140.0, 0.0, 1.0))
				ship.position += vortex_force * delta
			else:
				# No olho do redemoinho causa dano
				if ship.has_method("_take_damage"):
					ship._take_damage(int(damage_per_second * delta * 5.0))

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("ship") or body.has_method("repair_hull"):
		_tracked_ships.append(body)

func _on_body_exited(body: Node2D) -> void:
	_tracked_ships.erase(body)
