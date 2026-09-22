extends Node2D

## Fase 1 - Portão de Troia (Ato 1)
## O Grande Labirinto de Troia: 4000x2400.
## Labirinto com sombras, patrulhas de guardas e mini-game no portão.

var shadow_rects: Array = []
var player: CharacterBody2D
var gate_area: Area2D
var _campfire_lights: Array = []  # PointLight2D references for flickering

@onready var suspicion_bar: ProgressBar = $UILayer/SuspicionBar
@onready var message_label: Label = $UILayer/MessageLabel
@onready var message_bg: ColorRect = $UILayer/MessageBG

var suspicion_bar_fill: StyleBoxFlat

# Mini-game do Portão
var is_in_gate_zone: bool = false
var gate_progress: float = 0.0
@onready var gate_ui_container: Control = $UILayer/GateUIContainer
@onready var gate_progress_bar: ProgressBar = $UILayer/GateUIContainer/GateProgressBar

func _try_load(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	return null

func _ready() -> void:
	add_to_group("level")
	GameManager.reset()
	MainHUD.set_station("Ato 1 - Fase 1: Portão de Troia")
	randomize()

	_build_shadow_data()
	_connect_gate_area()
	_build_guards()
	_build_player()
	_build_lighting()
	
	suspicion_bar_fill = StyleBoxFlat.new()
	suspicion_bar_fill.bg_color = Color(0.8, 0.15, 0.1)
	suspicion_bar_fill.corner_radius_top_left     = 4
	suspicion_bar_fill.corner_radius_top_right    = 4
	suspicion_bar_fill.corner_radius_bottom_left  = 4
	suspicion_bar_fill.corner_radius_bottom_right = 4
	suspicion_bar.add_theme_stylebox_override("fill", suspicion_bar_fill)

	GameManager.suspicion_changed.connect(_on_suspicion_changed)
	GameManager.detected.connect(_on_detected)
	GameManager.victory.connect(_on_victory)

var _flicker_time: float = 0.0

func _process(delta: float) -> void:
	if is_instance_valid(player):
		if is_in_shadow(player.position):
			player.modulate = Color(0.65, 0.65, 0.85, 0.65)
		else:
			player.modulate = Color(1.0, 1.0, 1.0, 1.0)

	# Iluminação dinâmica suave das fogueiras
	_flicker_time += delta * 6.0
	var decor_node = get_node_or_null("Decorations")
	if decor_node:
		for item in decor_node.get_children():
			if item.name.begins_with("Campfire"):
				var pulse = 0.92 + 0.12 * sin(_flicker_time + item.position.x * 0.04)
				item.self_modulate = Color(2.2 * pulse, 1.6 * pulse, 0.8 * pulse, 1.0)

	# Flicker das luzes das fogueiras
	for light in _campfire_lights:
		if is_instance_valid(light):
			var pulse = 1.05 + 0.18 * sin(_flicker_time * 1.3 + light.position.x * 0.03)
			light.energy = pulse
			light.texture_scale = 2.4 + 0.15 * sin(_flicker_time * 0.9 + light.position.y * 0.02)

	if is_in_gate_zone and not GameManager.game_over:
		gate_progress -= 20.0 * delta
		
		if Input.is_action_just_pressed("ui_accept") or Input.is_key_pressed(KEY_SPACE):
			gate_progress += 7.0
			
		gate_progress = clamp(gate_progress, 0.0, 100.0)
		
		if gate_progress_bar:
			gate_progress_bar.value = gate_progress
			
		if gate_progress >= 100.0:
			is_in_gate_zone = false
			if gate_ui_container:
				gate_ui_container.visible = false
			GameManager.trigger_victory()

func _build_shadow_data() -> void:
	var shadow_defs := [
		Rect2(174, 1960, 100, 95),  # Tent1
		Rect2(595, 2190, 100, 95),  # Tent2
		Rect2(850, 1205, 100, 95),  # Tent3
		Rect2(440, 595, 100, 95),   # Tent4
		Rect2(1090, 1605, 100, 95), # Tent5
		Rect2(1300, 495, 100, 95),  # Tent6
		Rect2(2390, 895, 100, 95),  # Tent7
		Rect2(2700, 1795, 100, 95), # Tent8
		Rect2(3090, 1405, 100, 95), # Tent9
		Rect2(3490, 995, 100, 95),  # Tent10
		Rect2(2900, 205, 100, 95),  # Tent11
		Rect2(3690, 495, 100, 95)   # Tent12
	]
	for s in shadow_defs:
		shadow_rects.append(s)

func is_in_shadow(pos: Vector2) -> bool:
	for r in shadow_rects:
		if r.has_point(pos):
			return true
	return false

func _connect_gate_area() -> void:
	for child in get_children():
		if child is Area2D:
			gate_area = child
			gate_area.body_entered.connect(_on_gate_entered)
			gate_area.body_exited.connect(_on_gate_exited)
			break

func _build_guards() -> void:
	var guard_script := load("res://Code/Guard.gd")
	
	var sniper_data := [
		[Vector2(2000, 20), Vector2(500, 20), Vector2(3500, 20)],
		[Vector2(3980, 1200), Vector2(3980, 400), Vector2(3980, 2000)],
		[Vector2(1900, 1000), Vector2(1600, 1000), Vector2(2200, 1000)],
		[Vector2(1520, 1000), Vector2(1520, 700), Vector2(1520, 1300)],
		[Vector2(2280, 1000), Vector2(2280, 700), Vector2(2280, 1300)],
		[Vector2(2620, 1200), Vector2(2620, 900), Vector2(2620, 2200)]
	]

	for data in sniper_data:
		var g := CharacterBody2D.new()
		g.set_script(guard_script)
		g.position = data[0]
		g.patrol_mode = "points"
		g.patrol_a = data[1]
		g.patrol_b = data[2]
		g.is_wall_guard = true
		g.z_index = -4 
		add_child(g)

	var random_positions := [
		Vector2(250, 1950), Vector2(650, 2250), Vector2(1150, 2200),
		Vector2(900, 1200), Vector2(600, 600), Vector2(1300, 200),
		Vector2(2000, 200), Vector2(1300, 1500), Vector2(2450, 1200),
		Vector2(2900, 2000), Vector2(3500, 2200), Vector2(3000, 1400),
		Vector2(3400, 800), Vector2(3800, 600), Vector2(500, 1400),
		Vector2(850, 400), Vector2(1800, 2200), Vector2(2800, 1200),
		Vector2(3200, 1800), Vector2(3700, 1600), Vector2(2400, 400),
		Vector2(1500, 2100), Vector2(100, 1000), Vector2(3600, 200)
	]

	for pos in random_positions:
		var g := CharacterBody2D.new()
		g.set_script(guard_script)
		g.position = pos
		g.patrol_mode = "random"
		add_child(g)

func _build_player() -> void:
	player = CharacterBody2D.new()
	player.position = Vector2(200, 2250)
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
	cam.limit_right  = 4000
	cam.limit_bottom = 2400
	player.add_child(cam)

	add_child(player)
	
	var tutorial = preload("res://Scenes/TutorialOverlay.tscn").instantiate()
	add_child(tutorial)
	tutorial.setup([
		"Bem-vindo a Troia, Odisseu.",
		"Use as Teclas WASD ou as Setas Direcionais para se mover.",
		"Esconda-se dentro das Barracas Militares para ficar invisível aos guardas.",
		"Você saiu do Cavalo de Madeira. Mova-se furtivamente até os portões da fortaleza e esmague o botão Espaço para abri-los!"
	])

func _on_suspicion_changed(value: float) -> void:
	if not suspicion_bar:
		return
	suspicion_bar.value = value
	if value > 75.0:
		var t := (value - 75.0) / 25.0
		suspicion_bar_fill.bg_color = Color(0.9, lerp(0.15, 0.55, t), 0.05)
	else:
		suspicion_bar_fill.bg_color = Color(0.8, 0.15, 0.1)

func _on_gate_entered(body: Node) -> void:
	if body == player and not GameManager.game_over:
		is_in_gate_zone = true
		if gate_ui_container:
			gate_ui_container.visible = true

func _on_gate_exited(body: Node) -> void:
	if body == player:
		is_in_gate_zone = false
		if gate_ui_container:
			gate_ui_container.visible = false
		gate_progress = 0.0
		if gate_progress_bar:
			gate_progress_bar.value = 0.0

func _on_detected() -> void:
	message_label.text = "VOCÊ FOI DESCOBERTO!\nPressione R para tentar de novo"
	message_label.visible = true
	message_bg.visible    = true
	suspicion_bar_fill.bg_color = Color(1.0, 0.0, 0.0)

func _on_victory() -> void:
	message_label.text = "PORTÃO ABERTO!\nPrepare-se para a invasão..."
	message_label.visible = true
	message_bg.visible    = true
	var t = get_tree().create_timer(2.0)
	t.timeout.connect(func(): get_tree().change_scene_to_file("res://Ato1_Troia/Cutscenes/Act1_Cutscene_Invasao.tscn"))

func _build_lighting() -> void:
	# Canvas modulate: escurecer o ambiente para criar noite envolvente
	var canvas_mod = CanvasModulate.new()
	canvas_mod.name = "AmbientLight"
	canvas_mod.color = Color(0.14, 0.12, 0.18, 1.0)
	add_child(canvas_mod)

	# Posições das 12 fogueiras junto às barracas
	var campfire_positions := [
		Vector2(320, 2040),
		Vector2(760, 2220),
		Vector2(780, 1260),
		Vector2(600, 620),
		Vector2(1250, 1630),
		Vector2(1460, 520),
		Vector2(2330, 930),
		Vector2(2640, 1820),
		Vector2(3250, 1430),
		Vector2(3430, 1030),
		Vector2(3060, 240),
		Vector2(3630, 530),
	]

	# Posições das barracas (Tent1..12) para iluminação interna suave
	var tent_positions := [
		Vector2(224, 2006),
		Vector2(645, 2238),
		Vector2(900, 1250),
		Vector2(490, 640),
		Vector2(1140, 1650),
		Vector2(1350, 540),
		Vector2(2440, 940),
		Vector2(2750, 1840),
		Vector2(3140, 1450),
		Vector2(3540, 1040),
		Vector2(2950, 250),
		Vector2(3740, 540),
	]

	# Criar textura de luz suave (radial)
	var light_img = Image.create(256, 256, false, Image.FORMAT_RGBA8)
	for y in range(256):
		for x in range(256):
			var dx = (x - 128.0) / 128.0
			var dy = (y - 128.0) / 128.0
			var dist = sqrt(dx * dx + dy * dy)
			var alpha = clamp(1.0 - dist, 0.0, 1.0)
			alpha = alpha * alpha  # falloff quadrático suave
			light_img.set_pixel(x, y, Color(1, 1, 1, alpha))
	var light_tex := ImageTexture.create_from_image(light_img)

	# Fogueiras: luz quente alaranjada com grande raio e flickering
	for pos in campfire_positions:
		var light = PointLight2D.new()
		light.texture = light_tex
		light.texture_scale = 2.4
		light.color = Color(1.0, 0.62, 0.20, 1.0)
		light.energy = 1.15
		light.position = pos - Vector2(0, 10)
		light.shadow_enabled = false
		add_child(light)
		_campfire_lights.append(light)

	# Barracas: luz amarelada suave
	for pos in tent_positions:
		var light = PointLight2D.new()
		light.texture = light_tex
		light.texture_scale = 1.2
		light.color = Color(0.95, 0.75, 0.40, 1.0)
		light.energy = 0.45
		light.position = pos
		light.shadow_enabled = false
		add_child(light)

	# Luz suave no jogador para garantir legibilidade no escuro
	if is_instance_valid(player):
		var p_light = PointLight2D.new()
		p_light.texture = light_tex
		p_light.texture_scale = 1.0
		p_light.color = Color(0.8, 0.85, 1.0, 1.0)
		p_light.energy = 0.35
		player.add_child(p_light)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		get_tree().reload_current_scene()
