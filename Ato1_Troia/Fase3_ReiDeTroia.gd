extends Node2D

## Fase 3 - O Rei de Troia (Ato 1)
## A Sala do Trono (Boss Fight)
## Batalha final contra o Rei de Troia.

@export var arena_size: Vector2 = Vector2(1000, 800)
@export var player_spawn_pos: Vector2 = Vector2(180, 349)
@export var boss_spawn_pos: Vector2 = Vector2(680, 350)

var player: CharacterBody2D
var boss: CharacterBody2D
var hp_icons: Array[ColorRect] = []
var boss_health_bg: ColorRect
var _torch_lights: Array[PointLight2D] = []
var _flicker_time: float = 0.0
@onready var boss_health_bar: ProgressBar = $UILayer/BossHealthBar
@onready var message_bg: ColorRect = $UILayer/MessageBG
@onready var message_label: Label = $UILayer/MessageLabel

func _try_load(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	return null

func _ready() -> void:
	add_to_group("level")
	GameManager.enable_combat_mode()
	GameManager.heal_fully()
	MainHUD.set_station("Ato 1 - Fase 3: O Rei de Troia")
	randomize()

	var boss_style = StyleBoxFlat.new()
	boss_style.bg_color = Color(0.8, 0.1, 0.1)
	boss_health_bar.add_theme_stylebox_override("fill", boss_style)

	_build_boss()
	_build_player()
	_build_lighting()

	for i in range(10):
		var node = get_node_or_null("UILayer/HPIcon_" + str(i))
		if node: hp_icons.append(node)

	GameManager.player_health_changed.connect(_on_health_changed)
	GameManager.game_over_combat.connect(_on_game_over)
	
	_on_health_changed(GameManager.player_current_hp)

func _process(delta: float) -> void:
	_flicker_time += delta
	for light in _torch_lights:
		if is_instance_valid(light):
			var pulse = 1.1 + 0.18 * sin(_flicker_time * 1.5 + light.global_position.y * 0.03)
			light.energy = pulse
			light.texture_scale = 2.2 + 0.15 * sin(_flicker_time * 1.1 + light.global_position.x * 0.02)

func _build_boss() -> void:
	boss = CharacterBody2D.new()
	boss.position = boss_spawn_pos
	boss.set_script(load("res://Code/Boss.gd"))
	add_child(boss)

func _build_player() -> void:
	player = CharacterBody2D.new()
	player.position = player_spawn_pos
	player.set_script(load("res://Code/Player.gd"))
	player.collision_layer = 2
	player.collision_mask  = 1

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 10.0
	shape.shape = circle
	player.add_child(shape)

	var cam := Camera2D.new()
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed   = 6.0
	cam.limit_left   = 0
	cam.limit_top    = 0
	cam.limit_right  = int(arena_size.x)
	cam.limit_bottom = int(arena_size.y)
	player.add_child(cam)

	add_child(player)
	
	var tutorial = preload("res://Scenes/TutorialOverlay.tscn").instantiate()
	add_child(tutorial)
	tutorial.setup([
		"O portão está aberto e nossos aliados entraram...",
		"Mas o Rei de Troia despertou!",
		"Sobreviva aos ataques dele e ataque sem piedade.",
		"Quando ele mudar de fase, ele deixará corações no chão para recuperar a sua vida.",
		"Esta é a batalha final, e os Deuses observam. Vença!"
	])

func _on_health_changed(hp: int) -> void:
	for i in range(10):
		if i < hp:
			hp_icons[i].color = Color(1.0, 0.2, 0.2)
		else:
			hp_icons[i].color = Color(0.2, 0.2, 0.2)

func update_boss_health(current: float, maximum: float) -> void:
	if is_instance_valid(boss_health_bar):
		boss_health_bar.max_value = maximum
		boss_health_bar.value = current

func show_victory() -> void:
	GameManager.game_over = true
	message_label.text = "O REI CAIU!"
	message_label.visible = true
	message_bg.visible    = true
	var t = get_tree().create_timer(2.0)
	t.timeout.connect(func(): get_tree().change_scene_to_file("res://Ato1_Troia/Cutscenes/Act1_EndingCutscene.tscn"))

func _on_game_over() -> void:
	message_label.text = "ODISSEU FOI DERROTADO!\nPressione R para tentar de novo"
	message_label.visible = true
	message_bg.visible    = true

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		GameManager.heal_fully()
		get_tree().reload_current_scene()

func spawn_heart() -> void:
	var h = Area2D.new()
	h.collision_layer = 0
	h.collision_mask = 2

	var shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 15.0
	shape.shape = circle
	h.add_child(shape)

	var visual = Polygon2D.new()
	visual.polygon = PackedVector2Array([
		Vector2(0, -10), Vector2(10, 0), Vector2(0, 10), Vector2(-10, 0)
	])
	visual.color = Color(1.0, 0.4, 0.6)
	h.add_child(visual)

	h.position = Vector2(randf_range(100, arena_size.x - 100), randf_range(100, arena_size.y - 100))
	add_child(h)

	h.body_entered.connect(func(body: Node):
		if body == player and body.has_method("heal"):
			body.heal(1)
			h.queue_free()
	)

func _build_lighting() -> void:
	# 1. CanvasModulate: iluminação nobre de interior de castelo (visível e não tão escura)
	var canvas_mod = CanvasModulate.new()
	canvas_mod.name = "AmbientLight"
	canvas_mod.color = Color(0.48, 0.44, 0.52, 1.0)
	add_child(canvas_mod)

	# 2. Textura radial suave para os pontos de luz
	var light_img = Image.create(256, 256, false, Image.FORMAT_RGBA8)
	for y in range(256):
		for x in range(256):
			var dx = (x - 128.0) / 128.0
			var dy = (y - 128.0) / 128.0
			var dist = sqrt(dx * dx + dy * dy)
			var alpha = clamp(1.0 - dist, 0.0, 1.0)
			alpha = alpha * alpha
			light_img.set_pixel(x, y, Color(1, 1, 1, alpha))
	var light_tex := ImageTexture.create_from_image(light_img)

	# 3. Luzes nas tochas de parede
	var torch_container = get_node_or_null("Torches")
	if torch_container:
		for torch_node in torch_container.get_children():
			if torch_node is Sprite2D:
				var light = PointLight2D.new()
				light.texture = light_tex
				light.texture_scale = 2.2
				light.color = Color(1.0, 0.62, 0.20, 1.0)
				light.energy = 1.15
				light.position = Vector2(-15, -20)
				light.shadow_enabled = false
				torch_node.add_child(light)
				_torch_lights.append(light)

	# 4. Luzes nas tochas de chão na frente das estátuas
	var floor_torch_container = get_node_or_null("FloorTorches")
	if floor_torch_container:
		for f_torch in floor_torch_container.get_children():
			var light = PointLight2D.new()
			light.texture = light_tex
			light.texture_scale = 2.5
			light.color = Color(1.0, 0.65, 0.22, 1.0)
			light.energy = 1.25
			light.position = Vector2(0, -22)
			light.shadow_enabled = false
			f_torch.add_child(light)
			_torch_lights.append(light)

	# 5. Luz suave no jogador
	if is_instance_valid(player):
		var p_light = PointLight2D.new()
		p_light.texture = light_tex
		p_light.texture_scale = 1.2
		p_light.color = Color(0.85, 0.88, 1.0, 1.0)
		p_light.energy = 0.4
		player.add_child(p_light)

	# 6. Luz suave avermelhada de presença no Rei de Troia (Boss)
	if is_instance_valid(boss):
		var b_light = PointLight2D.new()
		b_light.texture = light_tex
		b_light.texture_scale = 1.6
		b_light.color = Color(1.0, 0.4, 0.3, 1.0)
		b_light.energy = 0.6
		boss.add_child(b_light)
