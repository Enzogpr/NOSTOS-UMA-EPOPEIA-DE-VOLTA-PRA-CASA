extends CharacterBody2D

signal phase_changed
signal boss_defeated

@export var max_hp: int = 200
@export var speed_phase1: float = 95.0
@export var speed_phase2: float = 135.0

var current_hp: int = 200
var is_phase2: bool = false
var is_sleeping: bool = false

var _target: Node2D
var _attack_timer: float = 0.0
var _visual: Polygon2D
var _attack_cone: Polygon2D

# Configurações de ataque
var attack_cooldown: float = 2.0
var attack_range: float = 80.0
var attack_damage: int = 5
var attack_prep_time: float = 0.8
var _is_preparing_attack: bool = false
var _prep_timer: float = 0.0

func _ready() -> void:
	add_to_group("enemies")
	add_to_group("boss")
	current_hp = max_hp
	collision_layer = 4
	collision_mask = 1 | 2 # Mundo e Jogador
	
	_build_visuals()
	
func _build_visuals() -> void:
	# Corpo Base (Ciclope)
	_visual = Polygon2D.new()
	_visual.polygon = PackedVector2Array([
		Vector2(-30, -50), Vector2(30, -50), Vector2(40, 0), Vector2(30, 50), Vector2(-30, 50), Vector2(-40, 0)
	])
	_visual.color = Color(0.4, 0.25, 0.15) # Cor de pele monstruosa
	add_child(_visual)
	
	# Olho
	var eye = Polygon2D.new()
	eye.polygon = PackedVector2Array([
		Vector2(-10, -10), Vector2(10, -10), Vector2(10, 10), Vector2(-10, 10)
	])
	eye.color = Color(0.9, 0.9, 0.9)
	eye.position = Vector2(25, 0)
	_visual.add_child(eye)
	
	var pupil = Polygon2D.new()
	pupil.polygon = PackedVector2Array([
		Vector2(-4, -4), Vector2(4, -4), Vector2(4, 4), Vector2(-4, 4)
	])
	pupil.color = Color(0.1, 0.1, 0.1)
	eye.add_child(pupil)
	
	# Colisão
	var shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 40.0
	shape.shape = circle
	add_child(shape)
	
	# Área de Ataque
	_attack_cone = Polygon2D.new()
	_attack_cone.polygon = _get_attack_polygon(attack_range)
	_attack_cone.color = Color(1.0, 0.0, 0.0, 0.0)
	_attack_cone.z_index = -1
	add_child(_attack_cone)

func _get_attack_polygon(radius: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	pts.append(Vector2.ZERO)
	var angle_span = 70.0 # Graus
	var start_a = deg_to_rad(-angle_span/2.0)
	var end_a = deg_to_rad(angle_span/2.0)
	var steps = 10
	for i in range(steps + 1):
		var a = lerp(start_a, end_a, float(i)/steps)
		pts.append(Vector2(cos(a), sin(a)) * radius)
	return pts

func _process(delta: float) -> void:
	if is_sleeping:
		return
		
	# Encontrar alvo mais próximo (Jogador ou Aliado)
	_find_target()
	
	if _target:
		# Girar visual
		var dir = (_target.global_position - global_position).normalized()
		_visual.rotation = dir.angle()
		_attack_cone.rotation = dir.angle()

func _physics_process(delta: float) -> void:
	if is_sleeping:
		return
		
	if _is_preparing_attack:
		_prep_timer -= delta
		# Pisca vermelho e aumenta opacidade para indicar onde vai bater
		var alpha = 1.0 - (_prep_timer / attack_prep_time)
		_attack_cone.color = Color(1.0, 0.2, 0.2, alpha * 0.5)
		
		if _prep_timer <= 0.0:
			_execute_attack()
		return
		
	if _attack_timer > 0:
		_attack_timer -= delta
		
	if _target:
		var dist = global_position.distance_to(_target.global_position)
		if dist <= attack_range and _attack_timer <= 0.0:
			_start_attack()
		elif dist > attack_range * 0.8:
			var speed = speed_phase2 if is_phase2 else speed_phase1
			velocity = (_target.global_position - global_position).normalized() * speed
			move_and_slide()

func _find_target() -> void:
	var possible_targets = get_tree().get_nodes_in_group("player")
	possible_targets.append_array(get_tree().get_nodes_in_group("allies"))
	
	var closest_dist = 999999.0
	var closest_node = null
	
	for n in possible_targets:
		# Se for aliado, checa se está vivo
		if n.has_method("is_dead") and n.is_dead():
			continue
		# Se for player e houver game over
		if n.is_in_group("player") and GameManager.game_over:
			continue
			
		var d = global_position.distance_to(n.global_position)
		if d < closest_dist:
			closest_dist = d
			closest_node = n
			
	_target = closest_node

func _start_attack() -> void:
	_is_preparing_attack = true
	_prep_timer = attack_prep_time

func _execute_attack() -> void:
	_is_preparing_attack = false
	_attack_timer = attack_cooldown
	
	# Flash forte na área
	_attack_cone.color = Color(1.0, 0.0, 0.0, 0.8)
	var tween = create_tween()
	tween.tween_property(_attack_cone, "color", Color(1.0, 0.0, 0.0, 0.0), 0.3)
	
	# Dano em área no cone
	var hit_targets = []
	var possible_targets = get_tree().get_nodes_in_group("player")
	possible_targets.append_array(get_tree().get_nodes_in_group("allies"))
	
	for n in possible_targets:
		var dist = global_position.distance_to(n.global_position)
		if dist <= attack_range + 20.0:
			var dir_to_n = (n.global_position - global_position).normalized()
			var my_dir = Vector2.RIGHT.rotated(_visual.rotation)
			var angle = rad_to_deg(my_dir.angle_to(dir_to_n))
			if abs(angle) <= 45.0:
				hit_targets.append(n)
				
	for t in hit_targets:
		if t.has_method("take_damage"):
			t.take_damage(attack_damage)
			if t.is_in_group("player") and t.has_method("apply_knockback"):
				t.apply_knockback((t.global_position - global_position).normalized() * 300.0)

func take_damage(amount: int) -> void:
	if is_sleeping: return
	
	current_hp -= amount
	
	# Feedback visual de dano
	_visual.modulate = Color(10, 0, 0)
	var tw = create_tween()
	tw.tween_property(_visual, "modulate", Color(1,1,1), 0.2)
	
	if current_hp <= max_hp / 2 and not is_phase2:
		_enter_phase2()
		
func _enter_phase2() -> void:
	is_phase2 = true
	attack_damage = 8
	attack_range = 140.0
	attack_cooldown = 1.5
	attack_prep_time = 0.6
	
	_attack_cone.polygon = _get_attack_polygon(attack_range)
	
	# Visual da Clava
	var club = Polygon2D.new()
	club.polygon = PackedVector2Array([
		Vector2(40, -10), Vector2(100, -15), Vector2(110, 0), Vector2(100, 15), Vector2(40, 10)
	])
	club.color = Color(0.3, 0.2, 0.1)
	club.position = Vector2(0, 40)
	_visual.add_child(club)
	
	phase_changed.emit()

func fall_asleep() -> void:
	is_sleeping = true
	_target = null
	_attack_cone.visible = false
	
	# Animação caindo
	var tw = create_tween()
	tw.set_parallel(true)
	tw.tween_property(_visual, "rotation", deg_to_rad(90), 1.0)
	tw.tween_property(_visual, "modulate", Color(0.5, 0.5, 0.8), 1.0) # Cor de sono
	
	boss_defeated.emit()
