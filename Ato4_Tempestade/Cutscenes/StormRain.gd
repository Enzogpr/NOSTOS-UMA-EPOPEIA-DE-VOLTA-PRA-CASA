extends Node2D
## Two moving rain depths in design coordinates; pauses with the cutscene.

var drops: Array[Vector4] = []
var age: float = 0.0

func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42017
	for index in range(135):
		drops.append(Vector4(rng.randf_range(0, 1320), rng.randf_range(-60, 720), rng.randf_range(0.55, 1.0), rng.randf_range(14, 30)))

func _process(delta: float) -> void:
	if not visible:
		return
	age += delta
	queue_redraw()

func _draw() -> void:
	for drop in drops:
		var x: float = fposmod(drop.x - age * 210.0 * drop.z, 1320.0) - 80.0
		var y: float = fposmod(drop.y + age * 510.0 * drop.z, 780.0) - 60.0
		var origin := Vector2(roundf(x), roundf(y))
		draw_line(origin, origin + Vector2(-drop.w * 0.42, drop.w), Color(0.66, 0.83, 0.95, 0.15 + drop.z * 0.12), 1.0 if drop.z < 0.8 else 2.0)
