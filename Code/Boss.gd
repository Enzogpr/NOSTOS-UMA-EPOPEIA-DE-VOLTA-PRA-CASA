extends CharacterBody2D

## O Rei de Troia (Boss)

enum Phase { PHASE_1, PHASE_2, PHASE_3 }

@export var max_hp: int = 60
@export var move_speed: float = 100.0
@export var dash_speed: float = 600.0
@export var attack_range: float = 45.0

@onready var arrow_scene = preload("res://Code/Arrow.gd")
@onready var guard_scene = preload("res://Code/Guard.gd")

var current_hp: int = 60
var current_phase: Phase = Phase.PHASE_1

var _player: Node2D
var _level: Node2D
var _visual: Node2D
var _attack_visual: Polygon2D

var attack_timer: float = 0.0

# Dash states (Phase 2)
var is_dashing: bool = false
var dash_dir: Vector2 = Vector2.ZERO
var dash_timer: float = 0.0
var dash_cooldown: float = 0.0
var is_charging_dash: bool = false

# Bow states (Phase 1)
var bow_shots_left: int = 4
var bow_cooldown: float = 0.0
var bow_reload_timer: float = 0.0

# Summon states (Phase 3)
var summon_timer: float = 0.0

func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	
	_player = get_tree().get_first_node_in_group("player")
	_level = get_parent()
	
	_build_visuals()

func _build_visuals() -> void:
	# O Rei é um quadrado maior e dourado
	var poly := Polygon2D.new()
	poly.polygon = PackedVector2Array([
		Vector2(-20, -20), Vector2(20, -20), Vector2(20, 20), Vector2(-20, 20)
	])
	poly.color = Color(0.8, 0.7, 0.2)
	_visual = poly
	add_child(_visual)

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(40, 40)
	shape.shape = rect
	add_child(shape)

	# A arma do Rei (muito maior)
	_attack_visual = Polygon2D.new()
	_attack_visual.polygon = PackedVector2Array([
		Vector2(20, -40), Vector2(70, -20), Vector2(80, 0), Vector2(70, 20), Vector2(20, 40)
	])
	_attack_visual.color = Color(1.0, 0.1, 0.1, 0.8)
	_attack_visual.visible = false
	add_child(_attack_visual)

func _physics_process(delta: float) -> void:
	if GameManager.game_over:
		return

	if not _player:
		_player = get_tree().get_first_node_in_group("player")
		if not _player:
			return

	if attack_timer > 0:
		attack_timer -= delta

	if dash_cooldown > 0:
		dash_cooldown -= delta

	match current_phase:
		Phase.PHASE_1:
			_process_phase_1(delta)
		Phase.PHASE_2:
			_process_phase_2(delta)
		Phase.PHASE_3:
			_process_phase_3(delta)

func _process_phase_1(delta: float) -> void:
	if bow_reload_timer > 0:
		bow_reload_timer -= delta
		# Recarregando: Corre do jogador (Kiting)
		var dir = (global_position - _player.global_position).normalized()
		velocity = dir * move_speed
		move_and_slide()
		_visual.modulate = Color(0.5, 0.5, 0.8) # Azulado = recarregando (vulnerável)
	else:
		_visual.modulate = Color(0.8, 0.7, 0.2) # Dourado = atacando
		# Atirando: Mantém distância ou fica quase parado
		var to_player = _player.global_position - global_position
		if to_player.length() < 300.0:
			velocity = -to_player.normalized() * (move_speed * 0.5)
			move_and_slide()
		
		if bow_cooldown > 0:
			bow_cooldown -= delta
		else:
			_shoot_arrow()
			bow_shots_left -= 1
			bow_cooldown = 0.8
			
			if bow_shots_left <= 0:
				if current_phase == Phase.PHASE_3:
					bow_shots_left = randi_range(3, 7) # Aleatório apenas no desespero da Fase 3
					_summon_guards() # Invoca mais guardas a cada recarga na Fase 3
				else:
					bow_shots_left = 4 # Fixo na Fase 1
					
				bow_reload_timer = 3.0

func _shoot_arrow() -> void:
	if arrow_scene:
		var a = Area2D.new()
		a.set_script(arrow_scene)
		a.position = global_position
		a.direction = (_player.global_position - global_position).normalized()
		_level.add_child(a)

func _process_phase_2(delta: float) -> void:
	if is_dashing:
		dash_timer -= delta
		velocity = dash_dir * dash_speed
		move_and_slide()
		
		# Causa dano se encostar no dash
		var to_player = _player.global_position - global_position
		if to_player.length() < 45.0 and attack_timer <= 0:
			_attack_player(true)
			
		if dash_timer <= 0 or is_on_wall():
			is_dashing = false
			dash_cooldown = 2.0
			_visual.modulate = Color(0.8, 0.7, 0.2) # Volta a cor normal
	elif is_charging_dash:
		# Tremendo antes do dash
		_visual.position = Vector2(randf_range(-2, 2), randf_range(-2, 2))
	else:
		if dash_cooldown <= 0:
			# Prepara o Dash
			is_charging_dash = true
			_visual.modulate = Color(1.0, 0.3, 0.3)
			var dir = (_player.global_position - global_position).normalized()
			dash_dir = dir
			
			var telegraph := Polygon2D.new()
			telegraph.polygon = PackedVector2Array([
				Vector2(0, -15), Vector2(600, -15), Vector2(600, 15), Vector2(0, 15)
			])
			telegraph.color = Color(1.0, 0.2, 0.2, 0.35)
			telegraph.rotation = dash_dir.angle()
			add_child(telegraph)
			
			var t = get_tree().create_timer(0.3) # Reduzido de 0.6 para 0.3s
			t.timeout.connect(func(): 
				if is_instance_valid(self):
					if is_instance_valid(telegraph):
						telegraph.queue_free()
					is_charging_dash = false
					is_dashing = true
					dash_timer = 0.5
					_visual.position = Vector2.ZERO
			)
		else:
			# Anda lentamente enquanto o dash recarrega
			var dir = (_player.global_position - global_position).normalized()
			velocity = dir * (move_speed * 0.4)
			move_and_slide()

func _process_phase_3(delta: float) -> void:
	# Na Fase 3, ele volta a agir como o Arqueiro da Fase 1, mas com os guardas protegendo ele
	_process_phase_1(delta)

func _chase_and_attack() -> void:
	var to_player = _player.global_position - global_position
	var dist = to_player.length()
	
	if dist <= attack_range:
		velocity = Vector2.ZERO
		if attack_timer <= 0:
			_attack_player(false)
	else:
		var dir = to_player.normalized()
		velocity = dir * move_speed
		move_and_slide()
		
		if dir.x > 0.1: _attack_visual.rotation = 0
		elif dir.x < -0.1: _attack_visual.rotation = PI
		elif dir.y > 0.1: _attack_visual.rotation = PI/2
		elif dir.y < -0.1: _attack_visual.rotation = -PI/2

func _attack_player(is_dash_hit: bool) -> void:
	attack_timer = 1.0
	
	if not is_dash_hit:
		_attack_visual.visible = true
		get_tree().create_timer(0.2).timeout.connect(func(): if is_instance_valid(_attack_visual): _attack_visual.visible = false)
	
	if _player.has_method("take_damage"):
		var damage = 2 if is_dash_hit else 1
		_player.take_damage(damage)

func _summon_guards() -> void:
	var corners = [Vector2(50, 50), Vector2(950, 50), Vector2(50, 750), Vector2(950, 750)]
	
	# Sumona apenas 1 guarda por vez para não lotar a tela tão rápido
	for i in range(1):
		var g = CharacterBody2D.new()
		if guard_scene:
			g.set_script(guard_scene)
		g.position = corners[randi() % corners.size()]
		_level.add_child(g)
		g.current_state = 1 # State.CHASE

func take_damage(amount: int) -> void:
	if GameManager.game_over: return
	
	current_hp -= amount
	if _level.has_method("update_boss_health"):
		_level.update_boss_health(current_hp, max_hp)
		
	# Efeito visual de tomar dano
	var orig = _visual.modulate
	_visual.modulate = Color(1, 1, 1)
	get_tree().create_timer(0.1).timeout.connect(func(): if is_instance_valid(_visual): _visual.modulate = orig)
		
	if current_hp <= 0:
		if _level.has_method("show_victory"):
			_level.show_victory()
		queue_free()
	else:
		_check_phase()

func _check_phase() -> void:
	if current_phase == Phase.PHASE_3:
		return # Nunca sai da Fase 3
		
	if current_hp <= 18:
		current_phase = Phase.PHASE_3
		move_speed = 160.0 # Fica mais rápido no desespero
		current_hp = 30 # Cura para 50%
		if _level.has_method("update_boss_health"):
			_level.update_boss_health(current_hp, max_hp)
		_summon_guards()
		if _level.has_method("spawn_heart"):
			_level.spawn_heart()
		
		# Reinicia a lógica do arco para ele voltar atirando
		bow_shots_left = 5
		bow_reload_timer = 0.0
	elif current_hp <= 36 and current_phase == Phase.PHASE_1:
		current_phase = Phase.PHASE_2
		if _level.has_method("spawn_heart"):
			_level.spawn_heart()
