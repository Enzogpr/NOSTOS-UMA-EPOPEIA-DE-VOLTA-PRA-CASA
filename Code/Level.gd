extends Node2D

## O Grande Labirinto de Troia: 4000x2400.
## Labirinto brutal com becos sem saída, 20 guardas no total
## (snipers em muralhas internas/externas e rondas) e mini-game hardcore no portão.

var shadow_rects: Array = []
var player: CharacterBody2D
var gate_area: Area2D

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
	randomize()

	# A cena visual (.tscn) já possui as paredes, UI e sombras.
	# Precisamos apenas popular as matrizes de dados e criar os atores dinâmicos.
	_build_shadow_data()
	_connect_gate_area()
	_build_guards()
	_build_player()
	
	# Restaurar o fill da barra de progresso que o Godot gera dinamicamente
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

func _process(delta: float) -> void:
	if is_in_gate_zone and not GameManager.game_over:
		gate_progress -= 20.0 * delta
		
		if Input.is_action_just_pressed("ui_accept"):
			gate_progress += 7.0
			
		gate_progress = clamp(gate_progress, 0.0, 100.0)
		
		if gate_progress_bar:
			gate_progress_bar.value = gate_progress
			
		if gate_progress >= 100.0:
			is_in_gate_zone = false
			if gate_ui_container:
				gate_ui_container.visible = false
			GameManager.trigger_victory()

func _build_background() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.07, 0.14)
	bg.size = Vector2(4800, 3200)
	bg.position = Vector2(-400, -400)
	bg.z_index = -10
	add_child(bg)

	var courtyard := Polygon2D.new()
	courtyard.polygon = PackedVector2Array([
		Vector2(0, 0), Vector2(4000, 0), Vector2(4000, 2400), Vector2(0, 2400)
	])
	courtyard.color = Color(0.25, 0.22, 0.18)
	courtyard.z_index = -9
	add_child(courtyard)

	for i in range(350):
		var star := ColorRect.new()
		star.color = Color(1, 1, 1, randf_range(0.3, 0.9))
		star.size = Vector2(2, 2)
		star.position = Vector2(randf_range(-400, 4400), randf_range(-400, 2800))
		star.z_index = -8
		add_child(star)

func _build_walls() -> void:
	var wall_defs := [
		# -- PERÍMETRO --
		Rect2(0, 0, 4000, 40),       # Topo
		Rect2(0, 2360, 4000, 40),    # Base
		Rect2(0, 0, 40, 2400),       # Esquerda
		# Direita (com abertura para o portão lá no alto)
		Rect2(3960, 0, 40, 200),
		Rect2(3960, 360, 40, 2040),

		# -- LABIRINTO (Desafios, bloqueios e becos sem saída) --
		# Bloqueio inicial (força ir para cima ou direita, direita é beco sem saída longo)
		Rect2(400, 1800, 40, 560),   # Parede vertical logo após o início
		Rect2(40, 1800, 200, 40),    # Forma um canto no spawn
		Rect2(440, 2100, 600, 40),   # Beco sem saída para quem for pela direita
		
		# Corredores longos e divisões
		Rect2(1000, 1500, 40, 860),  # Divisória vertical principal da parte de baixo
		Rect2(800, 800, 40, 1000),   # Outra divisória vertical
		Rect2(400, 800, 400, 40),    # Beco sem saída em "C"
		Rect2(400, 400, 40, 400),    
		
		# Centro massivo (A grande fortaleza interna)
		Rect2(1500, 600, 800, 800),  # Bloco gigante central, intransponível, os snipers ficam aqui
		
		# Rotas acima e abaixo da fortaleza
		Rect2(1200, 400, 1000, 40),  # Parede horizontal comprida em cima
		Rect2(2300, 40, 40, 800),    # Bloqueio descendo do topo (força zigue-zague)
		Rect2(2600, 800, 40, 1560),  # Parede longa vertical direita
		Rect2(2600, 1600, 800, 40),  # Teto de um corredor
		Rect2(3400, 1200, 40, 1160), # Último bloqueio antes da subida final
		
		# Labirinto Final perto do portão (canto superior direito)
		Rect2(2800, 400, 800, 40),   # Parede horizontal
		Rect2(3200, 700, 400, 40),   
		Rect2(3600, 400, 40, 340),   # Beco sem saída em "U" perto do portão
		Rect2(3200, 440, 40, 100)
	]

	for w in wall_defs:
		var wall := Polygon2D.new()
		wall.polygon = PackedVector2Array([
			Vector2(0, 0), Vector2(w.size.x, 0), Vector2(w.size.x, w.size.y), Vector2(0, w.size.y)
		])
		wall.position = w.position
		wall.color = Color(0.35, 0.3, 0.25)
		wall.z_index = -5
		add_child(wall)

		var body := StaticBody2D.new()
		body.collision_layer = 1
		body.collision_mask  = 0   
		var shape := CollisionShape2D.new()
		var rect_shape := RectangleShape2D.new()
		rect_shape.size = w.size
		shape.shape = rect_shape
		shape.position = w.size / 2.0
		body.add_child(shape)
		body.position = w.position
		add_child(body)

func _build_shadow_data() -> void:
	var shadow_defs := [
		Rect2(200, 2000, 100, 80),
		Rect2(600, 2200, 80, 80),
		Rect2(850, 1200, 100, 100),
		Rect2(450, 600, 80, 80),
		Rect2(1100, 1600, 80, 100),
		Rect2(1300, 500, 100, 80),
		Rect2(2400, 900, 80, 80),
		Rect2(2700, 1800, 100, 80),
		Rect2(3100, 1400, 80, 100),
		Rect2(3500, 1000, 80, 80),
		Rect2(2900, 200, 100, 100),
		Rect2(3700, 500, 80, 80)
	]
	for s in shadow_defs:
		shadow_rects.append(s)

func is_in_shadow(pos: Vector2) -> bool:
	for r in shadow_rects:
		if r.has_point(pos):
			return true
	return false

func _build_horse() -> void:
	var horse := Node2D.new()
	horse.position = Vector2(120, 2250)
	var tex: Texture2D = _try_load("res://Assets/horse.jpg")
	if tex:
		var spr := Sprite2D.new()
		spr.texture = tex
		var target_w := 90.0
		spr.scale = Vector2.ONE * (target_w / tex.get_width())
		spr.position = Vector2(0, -30) 
		horse.add_child(spr)
	else:
		var body := Polygon2D.new()
		body.polygon = PackedVector2Array([
			Vector2(-40, 0), Vector2(40, 0), Vector2(50, -60), Vector2(20, -90),
			Vector2(-10, -70), Vector2(-40, -50)
		])
		body.color = Color(0.55, 0.4, 0.22)
		horse.add_child(body)
	add_child(horse)

func _connect_gate_area() -> void:
	# Encontrar a gate_area que foi gerada na arvore
	for child in get_children():
		if child is Area2D:
			gate_area = child
			gate_area.body_entered.connect(_on_gate_entered)
			gate_area.body_exited.connect(_on_gate_exited)
			break

# ── Personagens ───────────────────────────────────────────────────────────

func _build_guards() -> void:
	var guard_script := load("res://Code/Guard.gd")
	
	# Guardas Snipers (Muralhas internas e externas)
	var sniper_data := [
		[Vector2(2000, 20), Vector2(500, 20), Vector2(3500, 20)], # Muro Topo
		[Vector2(3980, 1200), Vector2(3980, 400), Vector2(3980, 2000)], # Muro Direito
		[Vector2(1900, 1000), Vector2(1600, 1000), Vector2(2200, 1000)], # Fortaleza Central (Alto)
		[Vector2(1520, 1000), Vector2(1520, 700), Vector2(1520, 1300)], # Fortaleza Central (Lateral Esq)
		[Vector2(2280, 1000), Vector2(2280, 700), Vector2(2280, 1300)], # Fortaleza Central (Lateral Dir)
		[Vector2(2620, 1200), Vector2(2620, 900), Vector2(2620, 2200)] # Muro vertical comprido
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

	# Guardas do Chão (Movimento Aleatório) - Agora são 24 deles, somando 30 guardas!
	var random_positions := [
		Vector2(250, 1950),  # Perto do spawn
		Vector2(650, 2250),  # Corredor Beco
		Vector2(1150, 2200), # Corredor Base
		Vector2(900, 1200),  # Meio esquerdo
		Vector2(600, 600),   # Beco em C esquerdo
		Vector2(1300, 200),  # Corredor Topo Esq
		Vector2(2000, 200),  # Corredor Topo Meio
		Vector2(1300, 1500), # Entre Fortaleza e Muro Vertical
		Vector2(2450, 1200), # Direita da Fortaleza
		Vector2(2900, 2000), # Canto Inferior Direito
		Vector2(3500, 2200), # Canto Inferior Direito extremo
		Vector2(3000, 1400), # Subida final
		Vector2(3400, 800),  # Área central labirinto final
		Vector2(3800, 600),  # Último vigia do portão
		# --- Mais 10 guardas adicionados para preencher o mapa ---
		Vector2(500, 1400),
		Vector2(850, 400),
		Vector2(1800, 2200),
		Vector2(2800, 1200),
		Vector2(3200, 1800),
		Vector2(3700, 1600),
		Vector2(2400, 400),
		Vector2(1500, 2100),
		Vector2(100, 1000),
		Vector2(3600, 200)
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

	var player_tex: Texture2D = _try_load("res://Assets/player.png")
	if player_tex:
		var spr := Sprite2D.new()
		spr.texture = player_tex
		var target_w := 22.0
		spr.scale = Vector2.ONE * (target_w / player_tex.get_width())
		player.add_child(spr)
	else:
		var visual := Polygon2D.new()
		visual.polygon = PackedVector2Array([
			Vector2(-8, -10), Vector2(8, -10), Vector2(8, 10), Vector2(-8, 10)
		])
		visual.color = Color(0.75, 0.7, 0.55)
		player.add_child(visual)

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
	tutorial.setup("Bem-vindo a Troia, Odisseu.\n\n- Use as Teclas WASD ou as Setas Direcionais para se mover.\n- Fique em cima das áreas de Sombra para ficar invisível aos guardas.\n\nVocê saiu do Cavalo de Madeira. Mova-se furtivamente até os portões da fortaleza e esmague o botão Espaço para abri-los!")

# ── UI ────────────────────────────────────────────────────────────────────

func _build_ui() -> void:
	var ui_layer := CanvasLayer.new()
	ui_layer.name = "UILayer"
	add_child(ui_layer)

	var bar_bg := ColorRect.new()
	bar_bg.color = Color(0.0, 0.0, 0.0, 0.55)
	bar_bg.size = Vector2(300, 44)
	bar_bg.position = Vector2(10, 10)
	ui_layer.add_child(bar_bg)

	var eye_label := Label.new()
	eye_label.text = "👁  Suspeita"
	eye_label.position = Vector2(18, 12)
	eye_label.add_theme_font_size_override("font_size", 13)
	eye_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	ui_layer.add_child(eye_label)

	suspicion_bar = ProgressBar.new()
	suspicion_bar.name = "SuspicionBar"
	suspicion_bar.min_value = 0
	suspicion_bar.max_value = 100
	suspicion_bar.value = 0
	suspicion_bar.position = Vector2(18, 28)
	suspicion_bar.size = Vector2(272, 16)
	suspicion_bar.show_percentage = false

	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.15, 0.1, 0.1)
	bg_style.border_width_left   = 1
	bg_style.border_width_right  = 1
	bg_style.border_width_top    = 1
	bg_style.border_width_bottom = 1
	bg_style.border_color = Color(0.35, 0.2, 0.2)
	bg_style.corner_radius_top_left     = 4
	bg_style.corner_radius_top_right    = 4
	bg_style.corner_radius_bottom_left  = 4
	bg_style.corner_radius_bottom_right = 4
	suspicion_bar.add_theme_stylebox_override("background", bg_style)

	suspicion_bar_fill = StyleBoxFlat.new()
	suspicion_bar_fill.bg_color = Color(0.8, 0.15, 0.1)
	suspicion_bar_fill.corner_radius_top_left     = 4
	suspicion_bar_fill.corner_radius_top_right    = 4
	suspicion_bar_fill.corner_radius_bottom_left  = 4
	suspicion_bar_fill.corner_radius_bottom_right = 4
	suspicion_bar.add_theme_stylebox_override("fill", suspicion_bar_fill)

	ui_layer.add_child(suspicion_bar)

	# -- UI Mini-game do Portão --
	gate_ui_container = Control.new()
	gate_ui_container.name = "GateUIContainer"
	gate_ui_container.visible = false
	ui_layer.add_child(gate_ui_container)

	var gate_msg := Label.new()
	gate_msg.text = "ESMAGUE [ESPAÇO] PARA ABRIR O PORTÃO!"
	gate_msg.add_theme_font_size_override("font_size", 20)
	gate_msg.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2))
	gate_msg.position = Vector2(370, 480)
	gate_ui_container.add_child(gate_msg)

	gate_progress_bar = ProgressBar.new()
	gate_progress_bar.name = "GateProgressBar"
	gate_progress_bar.min_value = 0
	gate_progress_bar.max_value = 100
	gate_progress_bar.value = 0
	gate_progress_bar.size = Vector2(400, 24)
	gate_progress_bar.position = Vector2(376, 510)
	
	var gate_fill := StyleBoxFlat.new()
	gate_fill.bg_color = Color(0.2, 0.7, 0.2)
	gate_progress_bar.add_theme_stylebox_override("fill", gate_fill)
	gate_ui_container.add_child(gate_progress_bar)

	message_bg = ColorRect.new()
	message_bg.name = "MessageBG"
	message_bg.color = Color(0.0, 0.0, 0.0, 0.72)
	message_bg.size = Vector2(500, 120)
	message_bg.position = Vector2(326, 264) 
	message_bg.anchors_preset = Control.PRESET_CENTER
	message_bg.visible = false
	ui_layer.add_child(message_bg)

	message_label = Label.new()
	message_label.name = "MessageLabel"
	message_label.size = Vector2(480, 100)
	message_label.position = Vector2(336, 274)
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	message_label.add_theme_font_size_override("font_size", 24)
	message_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.8))
	message_label.visible = false
	ui_layer.add_child(message_label)

	var hint_bg := ColorRect.new()
	hint_bg.color = Color(0.0, 0.0, 0.0, 0.45)
	hint_bg.size = Vector2(1152, 28)
	hint_bg.position = Vector2(0, 620)
	ui_layer.add_child(hint_bg)

	var hint := Label.new()
	hint.text = "Setas: mover  |  Sombras: ocultam  |  R: reiniciar"
	hint.position = Vector2(12, 624)
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	ui_layer.add_child(hint)

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
	message_label.text = "PORTÃO ABERTO!\nPrepare-se para o combate..."
	message_label.visible = true
	message_bg.visible    = true
	var t = get_tree().create_timer(2.0)
	t.timeout.connect(func(): get_tree().change_scene_to_file("res://Scenes/Level2Cutscene.tscn"))

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		get_tree().reload_current_scene()
