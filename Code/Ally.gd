extends CharacterBody2D

enum State { WAITING, RUNNING }

var current_state: State = State.WAITING
var _run_dir: Vector2 = Vector2.ZERO
var _run_timer: float = 0.0
var move_speed: float = 110.0
var hp: int = 1
var _sprite: Sprite2D
var attack_area: Area2D
var attack_timer: float = 0.0

var helper_type: String = "lanca" # "lanca" ou "machado"
var _anims: Dictionary = {}
var _anim_timer: float = 0.0
var _frame_index: int = 0
var _current_dir: String = "down"

func _ready() -> void:
	collision_layer = 0 # Não colide com jogador ou guardas, só anda
	collision_mask = 1 # Colide só com muros
	
	helper_type = "lanca" if randf() < 0.5 else "machado"
	_load_animations()
	_build_visuals()
	
	GameManager.player_first_move.connect(_on_player_first_move)

func _try_load(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	return null

func _load_animations() -> void:
	_anims.clear()
	var prefix = "res://IMAGEM JOGO/ajudantes/ajudante" + helper_type
	
	if helper_type == "lanca":
		_anims["down"] = _load_frames([prefix + "baixo01.png", prefix + "baixo02.png"])
		_anims["up"] = _load_frames([prefix + "cima01.png", prefix + "cima02.png"])
		_anims["left"] = _load_frames([prefix + "esquerda01.png", prefix + "esquerda02.png"])
		_anims["right"] = _load_frames([prefix + "direita01.png"])
	else:
		_anims["down"] = _load_frames([prefix + "baixo1.png", prefix + "baixo2.png"])
		_anims["up"] = _load_frames([prefix + "cima1.png", prefix + "cima2.png"])
		_anims["left"] = _load_frames([prefix + "esquerda1.png", prefix + "esquerda2.png"])
		_anims["right"] = _load_frames([prefix + "direita1.png", prefix + "direita2.png"])

func _load_frames(paths: Array) -> Array[Texture2D]:
	var list: Array[Texture2D] = []
	for p in paths:
		var tex = _try_load(p)
		if tex:
			list.append(tex)
	return list

func _build_visuals() -> void:
	_sprite = Sprite2D.new()
	var default_tex: Texture2D = null
	if _anims.has("down") and _anims["down"].size() > 0:
		default_tex = _anims["down"][0]
	else:
		default_tex = _try_load("res://Assets/player.png")

	if default_tex:
		_sprite.texture = default_tex
		var target_h := 34.0
		if default_tex.get_height() > 0:
			_sprite.scale = Vector2.ONE * (target_h / float(default_tex.get_height()))
	
	add_child(_sprite)

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(16, 16)
	shape.shape = rect
	add_child(shape)

	# Área de ataque que atinge guardas
	attack_area = Area2D.new()
	attack_area.collision_layer = 0
	attack_area.collision_mask = 4 # Detecta guardas
	var atk_shape = CollisionShape2D.new()
	var atk_rect = RectangleShape2D.new()
	atk_rect.size = Vector2(50, 50)
	atk_shape.shape = atk_rect
	attack_area.add_child(atk_shape)
	add_child(attack_area)

func _on_player_first_move() -> void:
	if current_state == State.WAITING:
		current_state = State.RUNNING
		_pick_new_direction()

func _pick_new_direction() -> void:
	var dirs = [
		Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT,
		Vector2(1,1).normalized(), Vector2(-1,1).normalized(),
		Vector2(1,-1).normalized(), Vector2(-1,-1).normalized()
	]
	_run_dir = dirs[randi() % dirs.size()]
	_run_timer = randf_range(1.0, 4.0)

func _physics_process(delta: float) -> void:
	if GameManager.game_over:
		return

	if current_state == State.RUNNING:
		_run_timer -= delta
		if _run_timer <= 0.0 or is_on_wall():
			_pick_new_direction()
			global_position += _run_dir * 2.0
		
		velocity = _run_dir * move_speed
		move_and_slide()
		
		_update_direction_and_anim(delta)
		_try_attack()
	else:
		_set_frame_texture("down", 0)

func _update_direction_and_anim(delta: float) -> void:
	if _run_dir.length_squared() > 0.01:
		if absf(_run_dir.x) > absf(_run_dir.y):
			_current_dir = "right" if _run_dir.x > 0 else "left"
		else:
			_current_dir = "down" if _run_dir.y > 0 else "up"

	if _anims.has(_current_dir) and _anims[_current_dir].size() > 0:
		var frames: Array[Texture2D] = _anims[_current_dir]
		_anim_timer += delta * 7.0
		if _anim_timer >= 1.0:
			_anim_timer = 0.0
			_frame_index = (_frame_index + 1) % frames.size()
		
		_set_frame_texture(_current_dir, _frame_index)

func _set_frame_texture(dir: String, idx: int) -> void:
	if not is_instance_valid(_sprite):
		return
	if _anims.has(dir) and _anims[dir].size() > 0:
		var frames: Array[Texture2D] = _anims[dir]
		var tex: Texture2D = frames[idx % frames.size()]
		if tex and _sprite.texture != tex:
			_sprite.texture = tex
			var target_h := 34.0
			if tex.get_height() > 0:
				_sprite.scale = Vector2.ONE * (target_h / float(tex.get_height()))

func _try_attack() -> void:
	if attack_timer > 0:
		attack_timer -= get_physics_process_delta_time()
		return
		
	var overlapping = attack_area.get_overlapping_bodies()
	for body in overlapping:
		if body.has_method("take_damage"):
			body.take_damage(1) # Hit kill nos guardas
			attack_timer = 0.35
			# Flash attack
			if is_instance_valid(_sprite):
				var original_color = _sprite.modulate
				_sprite.modulate = Color(2.0, 2.0, 2.0, 1.0)
				get_tree().create_timer(0.1).timeout.connect(
					func(): if is_instance_valid(_sprite): _sprite.modulate = original_color
				)
			break

func take_damage(amount: int) -> void:
	hp -= amount
	if hp <= 0:
		queue_free()
