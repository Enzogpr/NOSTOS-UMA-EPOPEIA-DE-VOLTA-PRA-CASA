extends CharacterBody2D

## Controlador de Navegação do Navio Grego de Odisseu

signal hull_changed(current_hp: int, max_hp: int)
signal ship_destroyed
signal item_collected(item_name: String)

@export var max_hull: int = 100
var current_hull: int = 100

@export var max_speed: float = 260.0
@export var acceleration: float = 110.0
@export var deceleration: float = 65.0
@export var turn_speed: float = 2.4 # rad/s

var current_speed: float = 0.0
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
		
	# Cooldown de invulnerabilidade após colisão
	if invuln_timer > 0.0:
		invuln_timer -= delta
		visual.modulate.a = 0.5 if fmod(invuln_timer * 10.0, 1.0) > 0.5 else 1.0
		if invuln_timer <= 0.0:
			is_invulnerable = false
			visual.modulate.a = 1.0
			
	# Leitura direta de Teclado (W, A, S, D + Setas)
	var turn_input: float = 0.0
	if Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		turn_input += 1.0
	if Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		turn_input -= 1.0
		
	var throttle_input: float = 0.0
	if Input.is_action_pressed("ui_up") or Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		throttle_input += 1.0
	if Input.is_action_pressed("ui_down") or Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		throttle_input -= 1.0
		
	# Rotação do Leme
	if turn_input != 0.0:
		var turn_factor = 1.0
		if current_speed < -5.0:
			turn_factor = -0.8
		elif abs(current_speed) < 20.0 and throttle_input == 0.0:
			turn_factor = 0.6 # Permite alinhar a proa mesmo quase parado
		rotation += turn_input * turn_speed * delta * turn_factor
		
	# Aceleração das Velas / Remos
	var target_speed = 0.0
	if throttle_input > 0.0:
		target_speed = max_speed
	elif throttle_input < 0.0:
		target_speed = -max_speed * 0.4
	else:
		target_speed = 0.0
		
	if current_speed < target_speed:
		current_speed = move_toward(current_speed, target_speed, acceleration * delta)
	else:
		current_speed = move_toward(current_speed, target_speed, deceleration * delta)
		
	# Movimento do Barco na direção da proa
	var forward_dir = Vector2.RIGHT.rotated(rotation)
	velocity = forward_dir * current_speed
	
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
			# Rebote do barco
			current_speed = -current_speed * 0.5
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
