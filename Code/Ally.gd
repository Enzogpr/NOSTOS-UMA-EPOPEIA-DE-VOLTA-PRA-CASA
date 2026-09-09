extends CharacterBody2D

enum State { WAITING, RUNNING }

var current_state: State = State.WAITING
var _run_dir: Vector2 = Vector2.ZERO
var _run_timer: float = 0.0
var move_speed: float = 110.0
var hp: int = 1
var _visual: Node2D
var attack_area: Area2D
var attack_timer: float = 0.0

func _ready() -> void:
	collision_layer = 0 # Não colide com jogador ou guardas, só anda
	collision_mask = 1 # Colide só com muros
	
	_build_visuals()
	
	GameManager.player_first_move.connect(_on_player_first_move)

func _build_visuals() -> void:
	var tex: Texture2D = _try_load("res://Assets/player.png") # Usa a textura do jogador como base
	if tex:
		var spr := Sprite2D.new()
		spr.texture = tex
		var target_w := 20.0
		spr.scale = Vector2.ONE * (target_w / tex.get_width())
		spr.modulate = Color(0.8, 0.8, 1.0) # Aliados levemente azulados/brancos
		_visual = spr
	else:
		var poly := Polygon2D.new()
		poly.polygon = PackedVector2Array([
			Vector2(-6, -8), Vector2(6, -8), Vector2(6, 8), Vector2(-6, 8)
		])
		poly.color = Color(0.4, 0.4, 0.8) # Aliados azuis
		_visual = poly

	add_child(_visual)

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(16, 16)
	shape.shape = rect
	add_child(shape)

	# Área de ataque que mata guardas
	attack_area = Area2D.new()
	attack_area.collision_layer = 0
	attack_area.collision_mask = 4 # Detecta guardas
	var atk_shape = CollisionShape2D.new()
	var atk_rect = RectangleShape2D.new()
	atk_rect.size = Vector2(50, 50) # Área generosa ao redor do aliado para matar guardas próximos
	atk_shape.shape = atk_rect
	attack_area.add_child(atk_shape)
	add_child(attack_area)

func _try_load(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	return null

func _on_player_first_move() -> void:
	if current_state == State.WAITING:
		current_state = State.RUNNING
		_pick_new_direction()

func _pick_new_direction() -> void:
	var dirs = [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT, Vector2(1,1).normalized(), Vector2(-1,1).normalized(), Vector2(1,-1).normalized(), Vector2(-1,-1).normalized()]
	_run_dir = dirs[randi() % dirs.size()]
	_run_timer = randf_range(1.0, 4.0)

func _physics_process(delta: float) -> void:
	if GameManager.game_over:
		return

	if current_state == State.RUNNING:
		_run_timer -= delta
		if _run_timer <= 0.0 or is_on_wall():
			_pick_new_direction()
			# Se bateu num muro, inverte um pouco a rotação para "descolar" antes de aplicar o novo `move_and_slide` no próximo frame
			global_position += _run_dir * 2.0
		
		velocity = _run_dir * move_speed
		move_and_slide()
		
		if _visual and _run_dir.x != 0:
			_visual.scale.x = absf(_visual.scale.x) * sign(_run_dir.x)
		
		_try_attack()

func _try_attack() -> void:
	if attack_timer > 0:
		attack_timer -= get_physics_process_delta_time()
		return
		
	var overlapping = attack_area.get_overlapping_bodies()
	for body in overlapping:
		if body.has_method("take_damage"):
			body.take_damage(1) # Hit kill nos guardas
			attack_timer = 0.3
			# Flash attack
			if _visual:
				var original_color = _visual.modulate
				_visual.modulate = Color(1.0, 1.0, 1.0, 2.0)
				get_tree().create_timer(0.1).timeout.connect(func(): if is_instance_valid(_visual): _visual.modulate = original_color)
			break

func take_damage(amount: int) -> void:
	hp -= amount
	if hp <= 0:
		queue_free()
