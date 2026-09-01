extends CharacterBody2D

## Controlador de Navegação do Navio Grego de Odisseu

signal hull_changed(current_hp: int, max_hp: int)
signal ship_destroyed
signal item_collected(item_name: String)

@export var max_hull: int = 100
var current_hull: int = 100

@export var max_speed: float = 230.0
@export var acceleration: float = 85.0
@export var deceleration: float = 55.0
@export var turn_speed: float = 2.0 # rad/s

# Corrente marítima contínua leve de fundo (exige correção constante do leme)
@export var ocean_drift: Vector2 = Vector2(5.0, 18.0)

var current_speed: float = 0.0
var boost_timer: float = 0.0
var boost_cooldown: float = 0.0
var is_invulnerable: bool = false
var invuln_timer: float = 0.0

@onready var visual: Node2D = $Visual
@onready var wake_particles: CPUParticles2D = $WakeParticles

func _ready() -> void:
	current_hull = max_hull
	hull_changed.emit(current_hull, max_hull)

func _physics_process(delta: float) -> void:
	if current_hull <= 0:
		return
		
	# Cooldowns
	if invuln_timer > 0.0:
		invuln_timer -= delta
		visual.modulate.a = 0.5 if fmod(invuln_timer * 10.0, 1.0) > 0.5 else 1.0
		if invuln_timer <= 0.0:
			is_invulnerable = false
			visual.modulate.a = 1.0
			
	if boost_cooldown > 0.0:
		boost_cooldown -= delta
		
	if boost_timer > 0.0:
		boost_timer -= delta
		
	# Rotação do Leme (A / D ou Esquerda / Direita)
	var turn_input = Input.get_axis("ui_left", "ui_right")
	if abs(current_speed) > 5.0 or boost_timer > 0.0:
		rotation += turn_input * turn_speed * delta * (1.0 if current_speed >= 0 else -0.8)
		
	# Aceleração das Velas / Remos (W / S ou Cima / Baixo)
	var throttle_input = Input.get_axis("ui_down", "ui_up")
	var target_speed = 0.0
	
	if throttle_input > 0:
		target_speed = max_speed
		if boost_timer > 0.0:
			target_speed *= 1.6
	elif throttle_input < 0:
		target_speed = -max_speed * 0.35
	else:
		target_speed = 0.0
		
	if current_speed < target_speed:
		current_speed = move_toward(current_speed, target_speed, acceleration * delta)
	else:
		current_speed = move_toward(current_speed, target_speed, deceleration * delta)
		
	# Impulso de Remadores (Espaço) - CUSTA 5 DE CASCO (Esforço Extremo)
	if Input.is_action_just_pressed("ui_accept") and boost_cooldown <= 0.0 and current_hull > 10:
		boost_timer = 1.8
		boost_cooldown = 5.0
		current_speed = max_speed * 1.55
		# Custo de integridade pelo esforço extremo dos remadores
		current_hull = maxi(1, current_hull - 5)
		hull_changed.emit(current_hull, max_hull)
		item_collected.emit("⚡ Esforço Máximo dos Remadores! (-5 Casco)")
		
	# Movimento do Barco + Deriva contínua do oceano
	var forward_dir = Vector2.RIGHT.rotated(rotation)
	velocity = (forward_dir * current_speed) + ocean_drift
	
	# Partículas de esteira de água
	if wake_particles:
		wake_particles.emitting = abs(current_speed) > 15.0
		wake_particles.speed_scale = clamp(abs(current_speed) / 100.0, 0.5, 2.0)
		
	move_and_slide()
	
	# Checagem de colisões com rochedos
	for i in range(get_slide_collision_count()):
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		if collider and collider.is_in_group("rocks") and not is_invulnerable:
			_take_damage(20)
			# Rebote violento
			current_speed = -current_speed * 0.6
			break

func _take_damage(amount: int) -> void:
	if is_invulnerable or current_hull <= 0:
		return
		
	current_hull = maxi(0, current_hull - amount)
	is_invulnerable = true
	invuln_timer = 1.2
	hull_changed.emit(current_hull, max_hull)
	
	if current_hull <= 0:
		ship_destroyed.emit()

func repair_hull(amount: int) -> void:
	current_hull = mini(max_hull, current_hull + amount)
	hull_changed.emit(current_hull, max_hull)
	item_collected.emit("Madeira de Reparo (+25 Casco)")
