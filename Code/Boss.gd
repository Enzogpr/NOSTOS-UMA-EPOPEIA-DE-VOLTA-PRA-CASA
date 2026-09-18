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

# ── Animation state ──────────────────────────────────────────────────────────
# Frames de movimento (pasta: Assets/rei de troia/)
#   down_0..3, up_0..3, side_0..3
# Frames de combate (pasta: Assets/animations/)
#   reiAtack_frame_1..N    → animação de ataque corpo-a-corpo
#   reiDash_frame_1..N     → animação de dash
#   reiSpear_frame_1..N    → animação de arremesso de lança
var _walk_anims: Dictionary = {}   # { "down": [...], "up": [...], "side": [...] }
var _combat_sprite: AnimatedSprite2D  # sprite dedicado às animações de combate
var _anim_timer: float = 0.0
var _frame_index: int = 0
var _current_walk_dir: String = "down"
var _facing_left: bool = false
var _is_playing_combat_anim: bool = false  # true enquanto uma anim de combate está tocando

func _ready() -> void:
	collision_layer = 4
	collision_mask = 1

	_player = get_tree().get_first_node_in_group("player")
	_level = get_parent()

	_build_visuals()
	call_deferred("_setup_animations")

func _build_visuals() -> void:
	# Placeholder visual: quadrado dourado
	# Será substituído/escondido pelo Sprite2D de movimento quando os assets chegarem
	var poly := Polygon2D.new()
	poly.name = "PlaceholderPoly"
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

	# Placeholder de arma (será escondido durante animações de combate)
	_attack_visual = Polygon2D.new()
	_attack_visual.polygon = PackedVector2Array([
		Vector2(20, -40), Vector2(70, -20), Vector2(80, 0), Vector2(70, 20), Vector2(20, 40)
	])
	_attack_visual.color = Color(1.0, 0.1, 0.1, 0.8)
	_attack_visual.visible = false
	add_child(_attack_visual)

func _setup_animations() -> void:
	# ── 1. Sprite2D para animações de MOVIMENTO ───────────────────────────────
	var walk_spr := Sprite2D.new()
	walk_spr.name = "WalkSprite"
	add_child(walk_spr)

	# Carrega os frames de movimento da pasta "Assets/rei de troia/"
	var walk_folder := "res://Assets/rei_de_troia/"
	for dir_name in ["down", "up", "side"]:
		var frame_list: Array = []
		for f in range(4):
			var p
			p = walk_folder + dir_name + "_" + str(f) + ".png"
			if ResourceLoader.exists(p):
				frame_list.append(load(p))
		if frame_list.size() > 0:
			_walk_anims[dir_name] = frame_list

	# Configura textura inicial e escala do sprite de caminhada
	if _walk_anims.has("down") and _walk_anims["down"].size() > 0:
		var tex: Texture2D = _walk_anims["down"][0]
		walk_spr.texture = tex
		var target_h := 44.0
		if tex.get_height() > 0:
			walk_spr.scale = Vector2.ONE * (target_h / float(tex.get_height()))
		# Esconde o placeholder dourado se tiver arte real
		var poly := get_node_or_null("PlaceholderPoly")
		if poly:
			poly.visible = false
		_visual = walk_spr
	else:
		# Sem arte ainda: usa o placeholder dourado como visual
		walk_spr.visible = false

	# ── 2. AnimatedSprite2D para animações de COMBATE ─────────────────────────
	_combat_sprite = AnimatedSprite2D.new()
	_combat_sprite.name = "CombatAnimSprite"
	_combat_sprite.visible = false

	var frames := SpriteFrames.new()

	# Helper para carregar N frames de um padrão de nome
	var load_frames := func(anim_name: String, file_prefix: String, max_frames: int) -> void:
		frames.add_animation(anim_name)
		frames.set_animation_loop(anim_name, false)
		frames.set_animation_speed(anim_name, 12.0)
		for i in range(1, max_frames + 1):
			var p := "res://Assets/animations/" + file_prefix + str(i) + ".png"
			if ResourceLoader.exists(p):
				frames.add_frame(anim_name, load(p))

	# Animação de ataque corpo-a-corpo
	# Arquivos esperados: Assets/animations/reiAtack_frame_1.png ... reiAtack_frame_N.png
	load_frames.call("attack", "reiAtack_frame_", 8)

	# Animação de dash
	# Arquivos esperados: Assets/animations/reiDash_frame_1.png ... reiDash_frame_N.png
	load_frames.call("dash", "reiDash_frame_", 8)

	# Animação de arremesso de lança
	# Arquivos esperados: Assets/animations/reiSpear_frame_1.png ... reiSpear_frame_N.png
	load_frames.call("throw_spear", "reiSpear_frame_", 8)

	_combat_sprite.sprite_frames = frames

	# Copia escala do WalkSprite se existir arte
	var ws := get_node_or_null("WalkSprite") as Sprite2D
	if ws and ws.texture:
		_combat_sprite.scale = ws.scale
	else:
		_combat_sprite.scale = Vector2(0.25, 0.25)

	add_child(_combat_sprite)

	# Volta o visual principal ao terminar cada animação de combate
	_combat_sprite.animation_finished.connect(func():
		_is_playing_combat_anim = false
		_combat_sprite.visible = false
		if is_instance_valid(_visual):
			_visual.visible = true
	)

# Toca uma animação de combate (esconde o walk sprite durante ela)
func _play_combat_anim(anim_name: String, flip: bool = false) -> void:
	if not is_instance_valid(_combat_sprite):
		return
	if not _combat_sprite.sprite_frames.has_animation(anim_name):
		return
	if _combat_sprite.sprite_frames.get_frame_count(anim_name) == 0:
		return  # Sem frames ainda, aguarda as artes

	if is_instance_valid(_visual):
		_visual.visible = false
	_combat_sprite.flip_h = flip
	_combat_sprite.visible = true
	_combat_sprite.play(anim_name)
	_is_playing_combat_anim = true

# Atualiza o sprite de caminhada (direção + flip + frame)
func _update_walk_anim(delta: float, is_moving: bool, dir_to_player: Vector2) -> void:
	var ws := get_node_or_null("WalkSprite") as Sprite2D
	if not ws or not ws.visible:
		return

	# Determina direção dominante
	if absf(dir_to_player.y) > absf(dir_to_player.x) * 0.8:
		_current_walk_dir = "up" if dir_to_player.y < 0 else "down"
	else:
		_current_walk_dir = "side"
		_facing_left = dir_to_player.x < 0

	if is_moving:
		_anim_timer += delta * 8.0
		_frame_index = int(_anim_timer) % 4
		ws.offset.y = -absf(sin(_anim_timer * PI)) * 2.0
	else:
		_anim_timer = 0.0
		_frame_index = 0
		ws.offset.y = 0.0

	if _walk_anims.has(_current_walk_dir):
		var flist: Array = _walk_anims[_current_walk_dir]
		if _frame_index < flist.size():
			ws.texture = flist[_frame_index]
		ws.flip_h = (_current_walk_dir == "side" and _facing_left)

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
	var dir_to_player := (_player.global_position - global_position).normalized()

	if bow_reload_timer > 0:
		bow_reload_timer -= delta
		# Recarregando: Kiting (foge do jogador)
		var kite_dir := -dir_to_player
		velocity = kite_dir * move_speed
		move_and_slide()
		if is_instance_valid(_visual): _visual.modulate = Color(0.5, 0.5, 0.8)
		if not _is_playing_combat_anim:
			_update_walk_anim(delta, true, kite_dir)
	else:
		if is_instance_valid(_visual): _visual.modulate = Color(0.8, 0.7, 0.2)
		# Atirando: Mantém distância
		var to_player := _player.global_position - global_position
		var is_moving := false
		if to_player.length() < 300.0:
			velocity = -dir_to_player * (move_speed * 0.5)
			move_and_slide()
			is_moving = true
		if not _is_playing_combat_anim:
			_update_walk_anim(delta, is_moving, dir_to_player)

		if bow_cooldown > 0:
			bow_cooldown -= delta
		else:
			# Toca animação de arremesso de lança antes de disparar
			_play_combat_anim("throw_spear", dir_to_player.x < 0)
			_shoot_arrow()
			bow_shots_left -= 1
			bow_cooldown = 0.8

			if bow_shots_left <= 0:
				if current_phase == Phase.PHASE_3:
					bow_shots_left = randi_range(3, 7)
					_summon_guards()
				else:
					bow_shots_left = 4
				bow_reload_timer = 3.0

func _shoot_arrow() -> void:
	if arrow_scene:
		var a = Area2D.new()
		a.set_script(arrow_scene)
		a.position = global_position
		a.direction = (_player.global_position - global_position).normalized()
		_level.add_child(a)

func _process_phase_2(delta: float) -> void:
	var dir_to_player := (_player.global_position - global_position).normalized()

	if is_dashing:
		dash_timer -= delta
		velocity = dash_dir * dash_speed
		move_and_slide()
		# Mantém a animação de dash ativa durante o movimento
		if not _is_playing_combat_anim:
			_play_combat_anim("dash", dash_dir.x < 0)

		# Causa dano se encostar no dash
		var to_player := _player.global_position - global_position
		if to_player.length() < 45.0 and attack_timer <= 0:
			_attack_player(true)

		if dash_timer <= 0 or is_on_wall():
			is_dashing = false
			dash_cooldown = 2.0
			if is_instance_valid(_visual): _visual.modulate = Color(0.8, 0.7, 0.2)

	elif is_charging_dash:
		# Tremendo antes do dash
		if is_instance_valid(_visual):
			_visual.position = Vector2(randf_range(-2, 2), randf_range(-2, 2))
	else:
		if dash_cooldown <= 0:
			# Prepara o Dash
			is_charging_dash = true
			if is_instance_valid(_visual): _visual.modulate = Color(1.0, 0.3, 0.3)
			dash_dir = dir_to_player

			var telegraph := Polygon2D.new()
			telegraph.polygon = PackedVector2Array([
				Vector2(0, -15), Vector2(600, -15), Vector2(600, 15), Vector2(0, 15)
			])
			telegraph.color = Color(1.0, 0.2, 0.2, 0.35)
			telegraph.rotation = dash_dir.angle()
			add_child(telegraph)

			var t = get_tree().create_timer(0.3)
			t.timeout.connect(func():
				if is_instance_valid(self):
					if is_instance_valid(telegraph): telegraph.queue_free()
					is_charging_dash = false
					is_dashing = true
					dash_timer = 0.5
					if is_instance_valid(_visual): _visual.position = Vector2.ZERO
			)
		else:
			# Anda lentamente enquanto o dash recarrega
			velocity = dir_to_player * (move_speed * 0.4)
			move_and_slide()
			if not _is_playing_combat_anim:
				_update_walk_anim(delta, true, dir_to_player)

func _process_phase_3(delta: float) -> void:
	# Na Fase 3, ele volta a agir como o Arqueiro da Fase 1, mas com os guardas protegendo ele
	_process_phase_1(delta)

func _chase_and_attack(delta: float = 0.0) -> void:
	var to_player := _player.global_position - global_position
	var dist := to_player.length()
	var dir := to_player.normalized()

	if dist <= attack_range:
		velocity = Vector2.ZERO
		if attack_timer <= 0:
			_attack_player(false)
		if not _is_playing_combat_anim:
			_update_walk_anim(delta, false, dir)
	else:
		velocity = dir * move_speed
		move_and_slide()
		if not _is_playing_combat_anim:
			_update_walk_anim(delta, true, dir)

		if dir.x > 0.1: _attack_visual.rotation = 0
		elif dir.x < -0.1: _attack_visual.rotation = PI
		elif dir.y > 0.1: _attack_visual.rotation = PI/2
		elif dir.y < -0.1: _attack_visual.rotation = -PI/2

func _attack_player(is_dash_hit: bool) -> void:
	attack_timer = 1.0

	if not is_dash_hit:
		# Toca animação de ataque corpo-a-corpo
		var to_player := _player.global_position - global_position
		_play_combat_anim("attack", to_player.x < 0)
		# Fallback: mostra placeholder de arma se não tiver arte
		if _combat_sprite.sprite_frames.get_frame_count("attack") == 0:
			_attack_visual.visible = true
			get_tree().create_timer(0.2).timeout.connect(
				func(): if is_instance_valid(_attack_visual): _attack_visual.visible = false
			)

	if _player.has_method("take_damage"):
		var damage := 2 if is_dash_hit else 1
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
