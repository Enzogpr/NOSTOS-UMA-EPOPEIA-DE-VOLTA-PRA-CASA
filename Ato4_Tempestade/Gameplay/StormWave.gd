extends Area2D
## One physical front; the tsunami has two shapes and a genuine navigable gap.

@export var tsunami: bool = false
@export var height: float = 340.0
@export var sea_height: float = 1600.0
@export var gap_center: float = 800.0
@export var gap_size: float = 310.0
@export var travel_speed: float = 175.0
@export var warning_seconds: float = 2.5
@export var damage: float = 28.0
@export var travel_direction := Vector2.LEFT
var age: float = 0.0
var moving: bool = false
var impacted: Dictionary = {}
var segments: Array[Vector2] = []
var level: Node2D
var crest: Texture2D = preload("res://Assets/act4_storm/wave_front.png")

func _ready() -> void:
	segments = [Vector2(-height / 2.0, height / 2.0)]
	if tsunami:
		segments = [Vector2(0.0, gap_center - gap_size / 2.0), Vector2(gap_center + gap_size / 2.0, sea_height)]
	for segment in segments:
		var shape := RectangleShape2D.new()
		shape.size = Vector2(74.0 if tsunami else 46.0, segment.y - segment.x)
		var collision := CollisionShape2D.new()
		collision.shape = shape
		collision.position.y = (segment.x + segment.y) / 2.0
		add_child(collision)
	body_entered.connect(_on_body_entered)
	moving = warning_seconds <= 0.0
	monitoring = moving

func _physics_process(delta: float) -> void:
	if level and level.state != level.State.SAILING:
		return
	age += delta
	if age >= warning_seconds:
		if not moving:
			moving = true
			monitoring = true
			# A hull already within the warning area also gets hit at activation.
		position += travel_direction.normalized() * travel_speed * delta
		for body in get_overlapping_bodies():
			_on_body_entered(body)
	if level and position.x < level.ship.position.x - 1000.0:
		queue_free()
	queue_redraw()

func _on_body_entered(body: Node2D) -> void:
	if not moving or not body.has_method("take_wave_damage") or impacted.has(body.get_instance_id()):
		return
	# Calm shelters dissipate the crest; elsewhere each front pushes only once.
	impacted[body.get_instance_id()] = true
	body.take_wave_damage(damage, travel_direction.normalized() * (560.0 if tsunami else 360.0))

func _draw() -> void:
	for segment in segments:
		if not moving:
			var pulse: float = 0.25 + sin(age * 8.0) * 0.12
			draw_rect(Rect2(-42, segment.x, 84, segment.y - segment.x), Color(1.0, 0.5, 0.27, pulse))
			for y in range(int(segment.x), int(segment.y), 40):
				draw_polyline(PackedVector2Array([Vector2(18, y), Vector2(-2, y + 12), Vector2(18, y + 24)]), Color(1.0, 0.78, 0.48, 0.75), 3)
		else:
			_draw_crest(segment)
	if tsunami:
		draw_rect(Rect2(-55, gap_center - gap_size / 2.0, 110, gap_size), Color(0.3, 0.9, 0.78, 0.12))
		draw_line(Vector2(-60, gap_center), Vector2(70, gap_center), Color(0.54, 1.0, 0.82, 0.7), 2)

func _draw_crest(segment: Vector2) -> void:
	var width: float = 205.0 if tsunami else 130.0
	var factor: float = width / crest.get_width()
	var tile_height: float = crest.get_height() * factor
	var y: float = segment.x - fposmod(age * 12.0, tile_height)
	while y < segment.y:
		var top: float = maxf(y, segment.x)
		var bottom: float = minf(y + tile_height, segment.y)
		var source := Rect2(0, (top - y) / factor, crest.get_width(), (bottom - top) / factor)
		# Draw only inside each physical segment; no foam spans the safe channel.
		draw_texture_rect_region(crest, Rect2(-width * 0.38, top, width, bottom - top), source)
		y += tile_height
