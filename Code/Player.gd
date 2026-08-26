extends CharacterBody2D

@export var move_speed: float = 120.0
@export var max_hp: int = 10
@export var dash_speed: float = 400.0

var current_hp: int = 10
var facing_dir: Vector2 = Vector2.RIGHT

var is_dashing: bool = false
var dash_dir: Vector2 = Vector2.ZERO

var dash_bar: ColorRect
var dash_bar_bg: ColorRect

var attack_area: Area2D
var is_attacking: bool = false
var visual: Node2D
var attack_visual: Polygon2D

# Timers físicos (Nodes)
var _dash_timer: Timer
var _dash_cooldown: Timer
var _attack_timer: Timer

func _ready() -> void:
	current_hp = GameManager.player_current_hp
	max_hp = GameManager.player_max_hp
	move_speed = 120.0 * GameManager.player_speed_mult
	add_to_group("player")
	
	# Attack hitbox
	attack_area = Area2D.new()
	attack_area.collision_layer = 0
	attack_area.collision_mask = 4 
	var shape = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = Vector2(65, 25)
	shape.shape = rect
	shape.position = Vector2(32, 0) 
	attack_area.add_child(shape)
	
	# Visual do ataque
	attack_visual = Polygon2D.new()
	attack_visual.polygon = PackedVector2Array([
		Vector2(10, -10), Vector2(50, -5), Vector2(65, 0), Vector2(50, 5), Vector2(10, 10)
	])
	attack_visual.color = Color(0.9, 0.9, 0.9, 0.6)
	attack_visual.visible = false
	attack_area.add_child(attack_visual)
	
	# Interface do Dash
	dash_bar_bg = ColorRect.new()
	dash_bar_bg.size = Vector2(30, 4)
	dash_bar_bg.position = Vector2(-15, 12)
	dash_bar_bg.color = Color(0.2, 0.2, 0.2, 0.8)
	dash_bar_bg.visible = false
	add_child(dash_bar_bg)
	
	dash_bar = ColorRect.new()
	dash_bar.size = Vector2(30, 4)
	dash_bar.position = Vector2(-15, 12)
	dash_bar.color = Color(0.2, 0.8, 1.0, 1.0)
	dash_bar.visible = false
	add_child(dash_bar)

	add_child(attack_area)

	_dash_timer = Timer.new()
	_dash_timer.one_shot = true
	_dash_timer.timeout.connect(func():
		is_dashing = false
		if visual: visual.modulate = Color(1, 1, 1)
	)
	add_child(_dash_timer)

	_dash_cooldown = Timer.new()
	_dash_cooldown.one_shot = true
	add_child(_dash_cooldown)

	_attack_timer = Timer.new()
	_attack_timer.one_shot = true
	_attack_timer.timeout.connect(func():
		is_attacking = false
		if attack_visual: attack_visual.visible = false
	)
	add_child(_attack_timer)

func _physics_process(delta: float) -> void:
	if GameManager.game_over:
		return

	if not visual:
		visual = get_node_or_null("Sprite2D")
		if not visual:
			visual = get_node_or_null("Polygon2D")

	if not _dash_cooldown.is_stopped():
		dash_bar.size.x = 30.0 * (1.0 - (_dash_cooldown.time_left / GameManager.player_dash_cooldown))
		dash_bar_bg.visible = true
		dash_bar.visible = true
	else:
		dash_bar_bg.visible = false
		dash_bar.visible = false

	if is_dashing:
		velocity = dash_dir * dash_speed
		move_and_slide()
		return

	var input := Vector2.ZERO
	if Input.is_action_pressed("ui_up") or Input.is_key_pressed(KEY_W): input.y -= 1
	if Input.is_action_pressed("ui_down") or Input.is_key_pressed(KEY_S): input.y += 1
	if Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A): input.x -= 1
	if Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D): input.x += 1

	if input != Vector2.ZERO:
		if not GameManager.has_player_moved:
			GameManager.has_player_moved = true
			GameManager.player_first_move.emit()
		
		input = input.normalized()

	facing_dir = (get_global_mouse_position() - global_position).normalized()

	velocity = input * move_speed
		
	move_and_slide()
	
	attack_area.rotation = facing_dir.angle()

	if visual and facing_dir.x != 0:
		visual.scale.x = absf(visual.scale.x) * sign(facing_dir.x)

func _input(event: InputEvent) -> void:
	if GameManager.game_over or not GameManager.combat_mode:
		return
		
	var is_attack_input = event.is_action_pressed("ui_accept") or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed)
	if is_attack_input and _attack_timer.is_stopped() and not is_dashing:
		_attack()
		
	var is_dash_input = (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed) or (event is InputEventKey and event.keycode == KEY_SHIFT and event.pressed)
	if is_dash_input and not is_dashing and _dash_cooldown.is_stopped():
		_dash()

func _dash() -> void:
	is_dashing = true
	_dash_timer.start(0.2)
	_dash_cooldown.start(GameManager.player_dash_cooldown)
	
	var input := Vector2.ZERO
	if Input.is_action_pressed("ui_up") or Input.is_key_pressed(KEY_W): input.y -= 1
	if Input.is_action_pressed("ui_down") or Input.is_key_pressed(KEY_S): input.y += 1
	if Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A): input.x -= 1
	if Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D): input.x += 1
	
	if input != Vector2.ZERO:
		dash_dir = input.normalized()
	else:
		dash_dir = facing_dir
		
	if visual:
		visual.modulate = Color(0.5, 0.8, 1.0)

func _attack() -> void:
	is_attacking = true
	_attack_timer.start(0.4)
	attack_visual.visible = true
	
	var overlapping = attack_area.get_overlapping_bodies()
	for body in overlapping:
		if body.has_method("take_damage"):
			body.take_damage(GameManager.player_damage)

func take_damage(amount: int) -> void:
	if GameManager.game_over or not GameManager.combat_mode: return
	GameManager.player_current_hp -= amount
	current_hp = GameManager.player_current_hp
	GameManager.player_health_changed.emit(current_hp)
	
	if visual:
		visual.modulate = Color(1.0, 0.0, 0.0)
		var t = get_tree().create_timer(0.2)
		t.timeout.connect(func(): if is_instance_valid(visual): visual.modulate = Color(1,1,1))

	if current_hp <= 0:
		GameManager.game_over = true
		GameManager.game_over_combat.emit()

func heal(amount: int) -> void:
	if GameManager.game_over or not GameManager.combat_mode: return
	GameManager.player_current_hp = clampi(GameManager.player_current_hp + amount, 0, GameManager.player_max_hp)
	current_hp = GameManager.player_current_hp
	GameManager.player_health_changed.emit(current_hp)
	if visual:
		visual.modulate = Color(0.2, 1.0, 0.2)
		var t = get_tree().create_timer(0.2)
		t.timeout.connect(func(): if is_instance_valid(visual): visual.modulate = Color(1,1,1))
