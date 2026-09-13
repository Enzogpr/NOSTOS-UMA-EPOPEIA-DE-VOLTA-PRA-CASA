extends CharacterBody2D

## Guarda com IA aprimorada para Stealth e Combate.
## Na Fase 1: Adiciona suspeita ao ver o jogador.
## Na Fase 2: Persegue e ataca o jogador, e chama ajuda de guardas próximos.

enum State { PATROL, CHASE }

@export var patrol_mode: String = "points"
@export var patrol_a: Vector2
@export var patrol_b: Vector2
@export var move_speed: float = 60.0
@export var chase_speed: float = 100.0
@export var vision_range: float = 220.0
@export var vision_angle_deg: float = 50.0
@export var is_wall_guard: bool = false
@export var attack_range: float = 35.0

var current_state: State = State.PATROL
var health: int = 1
var attack_timer: float = 0.0

var _target: Vector2
var _facing_dir: Vector2 = Vector2.RIGHT
var _cone: Polygon2D
var _visual: Node2D
var _attack_visual: Polygon2D

var _player: Node2D
var _level: Node2D

var _random_dir: Vector2 = Vector2.ZERO
var _random_timer: float = 0.0
var _shoot_timer: float = 0.0

var _anims: Dictionary = {}
var _anim_timer: float = 0.0
var _frame_index: int = 0
var _current_dir: String = "down"

func _ready() -> void:
	add_to_group("guards")
	collision_layer = 4
	
	if is_wall_guard:
		vision_range = 450.0 
		vision_angle_deg = 60.0
		collision_mask = 0 
	else:
		collision_mask = 1 

	if patrol_mode == "points":
		_target = patrol_b
	else:
		_pick_new_random_dir()

	_build_visuals()
	_player = get_tree().get_first_node_in_group("player")
	_level  = get_tree().get_first_node_in_group("level")

func _build_visuals() -> void:
	_anims.clear()
	var base_folder := "res://Assets/guard_wall/" if is_wall_guard else "res://Assets/guard/"
	var fallback_png := "res://Assets/guard_wall.png" if is_wall_guard else "res://Assets/guard.png"

	for dir_name in ["down", "up", "left", "right"]:
		var frame_list: Array = []
		for f_idx in range(4):
			var p = base_folder + dir_name + "_" + str(f_idx) + ".png"
			if ResourceLoader.exists(p):
				frame_list.append(load(p))
		if frame_list.size() > 0:
			_anims[dir_name] = frame_list

	var spr := Sprite2D.new()
	if _anims.has("down") and _anims["down"].size() > 0:
		var tex: Texture2D = _anims["down"][0]
		spr.texture = tex
		var target_h: float = 34.0
		if tex.get_height() > 0:
			spr.scale = Vector2.ONE * (target_h / float(tex.get_height()))
		_visual = spr
	else:
		var tex: Texture2D = _try_load(fallback_png)
		if tex:
			spr.texture = tex
			var target_h: float = 34.0
			spr.scale = Vector2.ONE * (target_h / float(tex.get_height()))
			_visual = spr
		else:
			var poly := Polygon2D.new()
			poly.polygon = PackedVector2Array([
				Vector2(-8, -14), Vector2(8, -14), Vector2(10, 14), Vector2(-10, 14)
			])
			poly.color = Color(0.55, 0.15, 0.15)
			_visual = poly
	
	add_child(_visual)

	# Visual de Ataque (Lança/Espada do guarda)
	_attack_visual = Polygon2D.new()
	_attack_visual.polygon = PackedVector2Array([
		Vector2(10, -10), Vector2(30, -5), Vector2(35, 0), Vector2(30, 5), Vector2(10, 10)
	])
	_attack_visual.color = Color(1.0, 0.2, 0.2, 0.8)
	_attack_visual.visible = false
	add_child(_attack_visual)

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(20, 20)
	shape.shape = rect
	add_child(shape)

	_cone = Polygon2D.new()
	_cone.color = Color(1.0, 0.1, 0.1, 0.22) if is_wall_guard else Color(1.0, 0.9, 0.3, 0.22)
	_cone.z_index = -1
	add_child(_cone)
	_update_cone()

func _try_load(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	return null

func _update_cone() -> void:
	if current_state == State.CHASE or not is_inside_tree():
		_cone.visible = false
		return
	_cone.visible = true
	var half_angle: float = deg_to_rad(vision_angle_deg) * 0.5
	var base_angle: float = _facing_dir.angle()
	var pts := PackedVector2Array([Vector2.ZERO])
	var steps := 24
	
	var world_2d = get_world_2d()
	var space_state = world_2d.direct_space_state if world_2d else null
	
	for i in range(steps + 1):
		var a: float = base_angle - half_angle + (2.0 * half_angle) * (float(i) / float(steps))
		var dir_vec := Vector2(cos(a), sin(a)) * vision_range
		var target_global := global_position + dir_vec
		
		if space_state and not is_wall_guard:
			var query = PhysicsRayQueryParameters2D.create(global_position, target_global, 1)
			var hit: Dictionary = space_state.intersect_ray(query)
			if not hit.is_empty():
				pts.append(to_local(hit.position))
			else:
				pts.append(to_local(target_global))
		else:
			pts.append(to_local(target_global))
			
	_cone.polygon = pts

func _physics_process(delta: float) -> void:
	if GameManager.game_over:
		return
		
	if attack_timer > 0:
		attack_timer -= delta

	if current_state == State.PATROL:
		if patrol_mode == "points":
			_move_points()
		else:
			_move_random(delta)
		_update_cone()
		_check_vision(delta)
	elif current_state == State.CHASE:
		_chase_player(delta)
		
	_update_animation(delta)

func _update_animation(delta: float) -> void:
	var spr := _visual as Sprite2D
	if not spr:
		return

	var is_moving := (velocity.length_squared() > 1.0)
	if is_moving:
		_anim_timer += delta * 7.5
		_frame_index = int(_anim_timer) % 4
		spr.offset.y = -absf(sin(_anim_timer * PI)) * 1.5
	else:
		_anim_timer = 0.0
		_frame_index = 0
		spr.offset.y = 0.0

	if absf(_facing_dir.y) > absf(_facing_dir.x) * 0.8:
		if _facing_dir.y < 0:
			_current_dir = "up"
		else:
			_current_dir = "down"
	else:
		if _facing_dir.x < 0:
			_current_dir = "left"
		else:
			_current_dir = "right"

	if _anims.has(_current_dir):
		var frames: Array = _anims[_current_dir]
		if _frame_index < frames.size():
			spr.texture = frames[_frame_index]
			spr.flip_h = false
	elif _anims.has("side"):
		var frames: Array = _anims["side"]
		if _frame_index < frames.size():
			spr.texture = frames[_frame_index]
			spr.flip_h = (_facing_dir.x < 0)

func _move_points() -> void:
	var to_target: Vector2 = _target - global_position
	if to_target.length() < 6.0:
		_target = patrol_a if _target == patrol_b else patrol_b
	else:
		var dir: Vector2 = to_target.normalized()
		velocity = dir * move_speed
		move_and_slide()
		_facing_dir = dir
		_update_cone()

func _move_random(delta: float) -> void:
	_random_timer -= delta
	if _random_timer <= 0.0 or is_on_wall():
		_pick_new_random_dir()
		
	velocity = _random_dir * move_speed
	move_and_slide()
	_facing_dir = _random_dir
	_update_cone()

func _pick_new_random_dir() -> void:
	var dirs = [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]
	_random_dir = dirs[randi() % dirs.size()]
	_random_timer = randf_range(1.5, 4.0)

func _check_vision(delta: float) -> void:
	if not _player:
		_player = get_tree().get_first_node_in_group("player")
	if not _player: return

	var to_player: Vector2 = _player.global_position - global_position
	var dist: float = to_player.length()

	if dist > vision_range:
		if not GameManager.combat_mode: GameManager.reduce_suspicion(8.0 * delta)
		return

	var angle_to_player: float = absf(_facing_dir.angle_to(to_player.normalized()))
	if angle_to_player > deg_to_rad(vision_angle_deg * 0.5) + 0.08:
		if not GameManager.combat_mode: GameManager.reduce_suspicion(8.0 * delta)
		return

	if _level and _level.has_method("is_in_shadow") and _level.is_in_shadow(_player.global_position):
		if not GameManager.combat_mode: GameManager.reduce_suspicion(8.0 * delta)
		return

	var space_state = get_world_2d().direct_space_state
	# Testar o centro e extremidades do jogador para garantir detecção fiel na ponta do cone
	var sample_offsets = [Vector2.ZERO, Vector2(0, -8), Vector2(0, 8), Vector2(-8, 0), Vector2(8, 0)]
	var visible_hit: bool = false
	for offset in sample_offsets:
		var target_pos = _player.global_position + offset
		var query = PhysicsRayQueryParameters2D.create(global_position, target_pos, 1)
		var result: Dictionary = space_state.intersect_ray(query)
		if result.is_empty():
			visible_hit = true
			break
			
	if not visible_hit:
		if not GameManager.combat_mode: GameManager.reduce_suspicion(8.0 * delta)
		return

	# Jogador Avistado!
	if GameManager.combat_mode:
		set_chase_target()
		_alert_nearby_guards()
	else:
		var dist_ratio = clamp(dist / vision_range, 0.0, 1.0)
		# De 550 de suspeita (bem perto) a 280 (na ponta da visão)
		var detection_speed = lerp(550.0, 280.0, dist_ratio) * GameManager.guard_detection_mult
		GameManager.add_suspicion(detection_speed * delta)

func set_chase_target() -> void:
	if current_state != State.CHASE:
		current_state = State.CHASE
		_update_cone()
		if _visual: _visual.modulate = Color(1.0, 0.5, 0.5)

func _alert_nearby_guards() -> void:
	for g in get_tree().get_nodes_in_group("guards"):
		if g != self and g.has_method("set_chase_target") and g.current_state == State.PATROL:
			if global_position.distance_to(g.global_position) < 500.0:
				g.set_chase_target()

func _chase_player(delta: float) -> void:
	if not _player: return
	
	if is_wall_guard:
		_shoot_at_player(delta)
		return
	
	var to_player = _player.global_position - global_position
	var dist = to_player.length()
	
	if dist <= attack_range:
		velocity = Vector2.ZERO
		if attack_timer <= 0:
			_attack_player()
	else:
		var dir = to_player.normalized()
		velocity = dir * chase_speed
		move_and_slide()
		_facing_dir = dir
		
		if _visual and dir.x != 0.0:
			_visual.scale.x = absf(_visual.scale.x) * sign(dir.x)
			
	if _attack_visual:
		if _facing_dir.x > 0.1: _attack_visual.rotation = 0
		elif _facing_dir.x < -0.1: _attack_visual.rotation = PI
		elif _facing_dir.y > 0.1: _attack_visual.rotation = PI/2
		elif _facing_dir.y < -0.1: _attack_visual.rotation = -PI/2

func _shoot_at_player(delta: float) -> void:
	var to_player: Vector2 = _player.global_position - global_position
	_facing_dir = to_player.normalized()
	
	_shoot_timer -= delta
	if _shoot_timer <= 0.0 and to_player.length() <= vision_range:
		_shoot_timer = 1.4
		var arrow = Area2D.new()
		arrow.set_script(load("res://Code/Arrow.gd"))
		arrow.direction = to_player.normalized()
		arrow.global_position = global_position
		get_tree().current_scene.add_child(arrow)

func _attack_player() -> void:
	attack_timer = 1.0
	
	if _attack_visual:
		_attack_visual.visible = true
		get_tree().create_timer(0.2).timeout.connect(func(): if is_instance_valid(_attack_visual): _attack_visual.visible = false)
	
	if _player.has_method("take_damage"):
		_player.take_damage(1)

func take_damage(amount: int) -> void:
	if not GameManager.combat_mode: return
	health -= amount
	if health <= 0:
		queue_free()
