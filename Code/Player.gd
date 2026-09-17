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

var _dash_timer: Timer
var _dash_cooldown: Timer
var _attack_timer: Timer

# Animation state
var _anims: Dictionary = { }
var _anim_timer: float = 0.0
var _frame_index: int = 0
var _current_dir: String = "down"
var _facing_left: bool = false


func _ready() -> void:
	max_hp = GameManager.player_max_hp
	current_hp = max_hp
	GameManager.player_current_hp = max_hp
	add_to_group("player")

	GameManager.player_stats_changed.connect(_update_odysseus_sprite)
	_update_odysseus_sprite()

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
	attack_visual.polygon = PackedVector2Array(
		[Vector2(10, -10), Vector2(50, -5), Vector2(65, 0), Vector2(50, 5), Vector2(10, 10)]
	)
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
	_dash_timer.timeout.connect(
		func():
			is_dashing = false
			if visual:
				visual.modulate = Color(1, 1, 1),
	)
	add_child(_dash_timer)

	_dash_cooldown = Timer.new()
	_dash_cooldown.one_shot = true
	add_child(_dash_cooldown)

	_attack_timer = Timer.new()
	_attack_timer.one_shot = true
	_attack_timer.timeout.connect(
		func():
			is_attacking = false
			var anim_spr = get_node_or_null("AttackAnimSprite")
			if anim_spr:
				anim_spr.visible = false
			if is_instance_valid(visual):
				visual.visible = true,
	)
	add_child(_attack_timer)

	# Troca o Sprite2D simples por um AnimatedSprite2D no final do próximo frame,
	# permitindo que o script da fase tenha adicionado o Sprite2D primeiro.
	call_deferred("_setup_animations")


func _setup_animations() -> void:
	var anim_spr = AnimatedSprite2D.new()
	anim_spr.name = "AttackAnimSprite"
	anim_spr.visible = false

	var frames = SpriteFrames.new()

	# Cria a animação de ataque lateral
	frames.add_animation("attack")
	frames.set_animation_loop("attack", false)
	frames.set_animation_speed("attack", 20.0)

	for i in range(1, 9):
		var path = "res://Assets/animations/odisseuAtack_frame_%d.png" % i
		if ResourceLoader.exists(path):
			frames.add_frame("attack", load(path))

	# Cria a animação de ataque para cima
	frames.add_animation("attack_up")
	frames.set_animation_loop("attack_up", false)
	frames.set_animation_speed("attack_up", 20.0)

	for i in range(1, 9):
		var path = "res://Assets/animations/odisseuAtackup_frame_%d.png" % i
		if ResourceLoader.exists(path):
			frames.add_frame("attack_up", load(path))

	anim_spr.sprite_frames = frames

	# Força a escala correta para o personagem não ficar gigante
	if frames.has_animation("idle") and frames.get_animation_frames("idle").size() > 0:
		var idle_tex: Texture2D = frames.get_animation_frames("idle")[0]
		if idle_tex:
			var target_w := 22.0
			anim_spr.scale = Vector2.ONE * (target_w / idle_tex.get_width())

	var old_visual = get_node_or_null("Sprite2D")
	if old_visual:
		anim_spr.scale = old_visual.scale
		anim_spr.position = old_visual.position
	else:
		anim_spr.scale = Vector2(0.2, 0.2)

	add_child(anim_spr)


func _physics_process(delta: float) -> void:
	if GameManager.game_over:
		return

	if not visual:
		visual = get_node_or_null("AnimatedSprite2D")
		if not visual:
			visual = get_node_or_null("Sprite2D")
		if not visual:
			visual = get_node_or_null("Polygon2D")

	if not _dash_cooldown.is_stopped():
		dash_bar.size.x = 30.0 * (1.0
		- (_dash_cooldown.time_left / GameManager.player_dash_cooldown))
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
	if Input.is_action_pressed("ui_up") or Input.is_key_pressed(KEY_W):
		input.y -= 1
	if Input.is_action_pressed("ui_down") or Input.is_key_pressed(KEY_S):
		input.y += 1
	if Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A):
		input.x -= 1
	if Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D):
		input.x += 1

	var is_moving := (input != Vector2.ZERO)
	if is_moving:
		if not GameManager.has_player_moved:
			GameManager.has_player_moved = true
			GameManager.player_first_move.emit()

		input = input.normalized()

		# Direction strictly determined by movement keys (W, S, A, D)
		if absf(input.y) > absf(input.x) * 0.8:
			if input.y < 0:
				_current_dir = "up"
				_facing_left = false
			else:
				_current_dir = "down"
				_facing_left = false
		else:
			if input.x < 0:
				# Usar frames de 'left' se existirem, senao 'side'
				if _anims.has("left"):
					_current_dir = "left"
				else:
					_current_dir = "side"
				_facing_left = false  # sem flip: sprites de left/side ja estao virados para esquerda
			else:
				if _anims.has("right"):
					_current_dir = "right"
				else:
					_current_dir = "side"
				_facing_left = true  # side virado para esquerda precisa flip para direita

	facing_dir = (get_global_mouse_position() - global_position).normalized()

	var current_move_speed = 120.0 * GameManager.player_speed_mult
	velocity = input * current_move_speed

	move_and_slide()

	attack_area.rotation = facing_dir.angle()

	# Process walking / idle animation
	var spr := visual as Sprite2D
	if is_moving:
		_anim_timer += delta * (9.5 * GameManager.player_speed_mult)
		_frame_index = int(_anim_timer) % 4
		if spr:
			# Subtle step bounce so movement feels alive
			spr.offset.y = -absf(sin(_anim_timer * PI)) * 2.0
	else:
		_anim_timer = 0.0
		_frame_index = 0
		if spr:
			spr.offset.y = 0.0

	if spr and _anims.has(_current_dir):
		var frames: Array = _anims[_current_dir]
		if _frame_index < frames.size():
			spr.texture = frames[_frame_index]
		# side sem right frames: flip_h para ir para direita
		if _current_dir == "side":
			spr.flip_h = _facing_left  # _facing_left=true quando indo para direita (flip side para direita)
		else:
			spr.flip_h = false  # left, right, up, down: sem flip


func _input(event: InputEvent) -> void:
	if GameManager.game_over or not GameManager.combat_mode:
		return

	var is_attack_input = (
		event.is_action_pressed("ui_accept")
		or (event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_LEFT and event.pressed)
	)
	if is_attack_input and _attack_timer.is_stopped() and not is_dashing:
		_attack()

	var is_dash_input = (
		(event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed)
		or (event is InputEventKey and event.keycode == KEY_SHIFT and event.pressed)
	)
	if is_dash_input and not is_dashing and _dash_cooldown.is_stopped():
		_dash()


func _dash() -> void:
	is_dashing = true
	_dash_timer.start(0.2)
	_dash_cooldown.start(GameManager.player_dash_cooldown)

	var input := Vector2.ZERO
	if Input.is_action_pressed("ui_up") or Input.is_key_pressed(KEY_W):
		input.y -= 1
	if Input.is_action_pressed("ui_down") or Input.is_key_pressed(KEY_S):
		input.y += 1
	if Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A):
		input.x -= 1
	if Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D):
		input.x += 1

	if input != Vector2.ZERO:
		dash_dir = input.normalized()
	else:
		dash_dir = facing_dir

	if visual:
		visual.modulate = Color(0.5, 0.8, 1.0)


func _attack() -> void:
	is_attacking = true
	_attack_timer.start(0.4)

	var anim_spr = get_node_or_null("AttackAnimSprite") as AnimatedSprite2D
	if anim_spr:
		if is_instance_valid(visual):
			visual.visible = false
		anim_spr.visible = true

		if facing_dir.y < -0.5:
			anim_spr.play("attack_up")
			anim_spr.flip_h = false
		else:
			anim_spr.play("attack")
			if facing_dir.x != 0:
				anim_spr.flip_h = (facing_dir.x < 0)

	var overlapping = attack_area.get_overlapping_bodies()
	for body in overlapping:
		if body.has_method("take_damage"):
			body.take_damage(GameManager.player_damage)


func take_damage(amount: int) -> void:
	if GameManager.game_over or not GameManager.combat_mode:
		return
	GameManager.player_current_hp -= amount
	current_hp = GameManager.player_current_hp
	GameManager.player_health_changed.emit(current_hp)

	if visual:
		visual.modulate = Color(1.0, 0.0, 0.0)
		var t = get_tree().create_timer(0.2)
		t.timeout.connect(
			func():
				if is_instance_valid(visual):
					visual.modulate = Color(1, 1, 1),
		)

	if current_hp <= 0:
		GameManager.game_over = true
		GameManager.game_over_combat.emit()


func heal(amount: int) -> void:
	if GameManager.game_over or not GameManager.combat_mode:
		return
	GameManager.player_current_hp = clampi(
		GameManager.player_current_hp + amount,
		0,
		GameManager.player_max_hp,
	)
	current_hp = GameManager.player_current_hp
	GameManager.player_health_changed.emit(current_hp)
	if visual:
		visual.modulate = Color(0.2, 1.0, 0.2)
		var t = get_tree().create_timer(0.2)
		t.timeout.connect(
			func():
				if is_instance_valid(visual):
					visual.modulate = Color(1, 1, 1),
		)


func _update_odysseus_sprite() -> void:
	var spr: Sprite2D = get_node_or_null("Sprite2D") as Sprite2D
	if not spr:
		spr = Sprite2D.new()
		spr.name = "Sprite2D"
		add_child(spr)

	var base_folder := "res://Assets/odisseu/"
	if GameManager.player_age >= 40:
		base_folder = "res://Assets/odisseu_velho/"

	_anims.clear()
	for dir_name in ["down", "up", "side", "left", "right"]:
		var frame_list: Array = []
		for f_idx in range(4):
			var p = base_folder + dir_name + "_" + str(f_idx) + ".png"
			var img = Image.new()
			# Tenta carregar usando ProjectSettings.globalize_path para pegar o arquivo real
			var global_path = ProjectSettings.globalize_path(p)
			if FileAccess.file_exists(global_path):
				var err = img.load(global_path)
				if err == OK:
					frame_list.append(ImageTexture.create_from_image(img))
		if frame_list.size() > 0:
			_anims[dir_name] = frame_list
	
	# Se nao ha frames 'left' explicitos, usa 'side' (ja virado para esquerda, sem flip)
	if not _anims.has("left") and _anims.has("side"):
		_anims["left"] = _anims["side"]
	# Se nao ha frames 'right' explicitos, usa 'side' (vai ser flipado pelo codigo de movimento)
	if not _anims.has("right") and _anims.has("side"):
		_anims["right"] = _anims["side"]
	
	if _anims.has("down") and _anims["down"].size() > 0:
		var tex: Texture2D = _anims["down"][0]
		spr.texture = tex
		# Target height: ~38px for the new larger sprint sprites (they're taller due to legs)
		var target_h: float = 38.0
		if tex.get_height() > 0:
			spr.scale = Vector2.ONE * (target_h / float(tex.get_height()))
	elif ResourceLoader.exists("res://Assets/player.png"):
		var tex: Texture2D = load("res://Assets/player.png")
		spr.texture = tex
		var target_h: float = 38.0
		if tex.get_height() > 0:
			spr.scale = Vector2.ONE * (target_h / float(tex.get_height()))

	var poly := get_node_or_null("Polygon2D")
	if poly:
		poly.visible = false
	visual = spr
