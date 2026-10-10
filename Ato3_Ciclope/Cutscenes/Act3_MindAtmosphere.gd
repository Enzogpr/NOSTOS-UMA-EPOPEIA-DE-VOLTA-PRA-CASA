extends Node2D
## Pixel particles remain separate from the art, so the apparition can disperse.

var presence: float = 0.0
var agitation: float = 0.0
var elapsed: float = 0.0
var burst_time: float = 10.0
var motes: Array[Dictionary] = []

func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 30317
	for i in range(70):
		motes.append({
			"x": rng.randf_range(-540.0, 540.0),
			"y": rng.randf_range(-260.0, 205.0),
			"speed": rng.randf_range(4.0, 18.0),
			"phase": rng.randf_range(0.0, TAU),
			"size": rng.randi_range(1, 3),
			"direction": Vector2.from_angle(rng.randf_range(0.0, TAU)),
		})

func burst() -> void:
	burst_time = 0.0

func _process(delta: float) -> void:
	elapsed += delta
	burst_time += delta
	queue_redraw()

func _draw() -> void:
	for mote in motes:
		var y: float = wrapf(float(mote.y) - elapsed * float(mote.speed), -260.0, 205.0)
		var x: float = float(mote.x) + sin(elapsed * 0.35 + float(mote.phase)) * 7.0
		var alpha: float = (0.10 + presence * 0.25) * (0.6 + 0.4 * sin(elapsed + float(mote.phase)))
		var tint := Color(0.65, 0.77, 1.0, alpha)
		if x < -100.0:
			tint = Color(1.0, 0.65, 0.26, alpha * 0.7)
		draw_rect(Rect2(Vector2(x, y).round(), Vector2.ONE * float(mote.size)), tint)
		if burst_time < 2.5:
			var distance: float = burst_time * (70.0 + float(mote.speed) * 7.0)
			var origin := Vector2(292.0, -65.0)
			var point: Vector2 = origin + Vector2(mote.direction) * distance
			draw_rect(Rect2(point.round(), Vector2(2, 2)), Color(0.65, 0.80, 1.0, (1.0 - burst_time / 2.5) * 0.55))
