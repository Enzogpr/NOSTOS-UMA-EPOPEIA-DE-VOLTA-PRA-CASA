extends Area2D

var speed: float = 400.0
var direction: Vector2 = Vector2.ZERO
var lifetime: float = 3.0

func _ready() -> void:
	AudioManager.play_bow_sfx()
	collision_layer = 0
	collision_mask = 2 # Player
	body_entered.connect(_on_body_entered)
	
	var poly := Polygon2D.new()
	poly.polygon = PackedVector2Array([
		Vector2(-6, -2), Vector2(6, -2), Vector2(12, 0), Vector2(6, 2), Vector2(-6, 2)
	])
	poly.color = Color(1.0, 0.8, 0.2)
	add_child(poly)
	
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(18, 4)
	shape.shape = rect
	add_child(shape)

func _physics_process(delta: float) -> void:
	if GameManager.game_over: return
	position += direction * speed * delta
	rotation = direction.angle()
	
	lifetime -= delta
	if lifetime <= 0:
		queue_free()

func _on_body_entered(body: Node) -> void:
	if body.has_method("take_damage"):
		body.take_damage(1)
		queue_free()
