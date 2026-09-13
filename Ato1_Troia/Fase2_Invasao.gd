extends Node2D

## Fase 2 - Invasão de Troia (Ato 1)
## Caminho para a Torre do Palácio (Combate)
## Odisseu e os guerreiros de Ítaca enfrentam o exército troiano nas ruas.

var guard_spawns: Array[Vector2] = [
	Vector2(250, 1950), Vector2(1750, 1950), Vector2(1000, 1500), 
	Vector2(1000, 1100), Vector2(250, 1100), Vector2(1750, 1100),
	Vector2(1000, 700), Vector2(250, 500), Vector2(1750, 500),
	Vector2(250, 150), Vector2(1000, 250), Vector2(1750, 150),
	Vector2(600, 1800), Vector2(1400, 1800), Vector2(600, 1300),
	Vector2(1400, 1300), Vector2(600, 800), Vector2(1400, 800),
	Vector2(500, 400), Vector2(1500, 400), Vector2(1000, 1800),
	Vector2(1000, 1300), Vector2(1000, 900), Vector2(1000, 500),
	Vector2(500, 900), Vector2(550, 900), Vector2(1400, 800),
	Vector2(1450, 800), Vector2(2600, 300), Vector2(2600, 400)
]

var ally_spawns: Array[Vector2] = [
	Vector2(850, 2200), Vector2(900, 2250), Vector2(950, 2150),
	Vector2(1000, 2200), Vector2(1050, 2250), Vector2(1100, 2150),
	Vector2(1150, 2200), Vector2(800, 2100), Vector2(1200, 2100),
	Vector2(900, 2100), Vector2(1100, 2100), Vector2(950, 2300),
	Vector2(1050, 2300), Vector2(850, 2350), Vector2(1150, 2350),
	Vector2(1000, 2100), Vector2(1000, 2300), Vector2(950, 2200),
	Vector2(1050, 2200), Vector2(900, 2150)
]

var player: CharacterBody2D
var tower_area: Area2D
var hp_icons: Array[ColorRect] = []

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
	MainHUD.set_station("Ato 1 - Fase 2: Invasão de Troia")
	randomize()

	_build_background()
	_build_tower()
	_build_guards()
	_build_player()
	_build_allies()

	for i in range(10):
		var node = get_node_or_null("UILayer/HPIcon_" + str(i))
		if node: hp_icons.append(node)

	GameManager.player_health_changed.connect(_on_health_changed)
	GameManager.game_over_combat.connect(_on_game_over)
	
	_on_health_changed(GameManager.player_current_hp)

func _build_background() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.1, 0.05, 0.05)
	bg.size = Vector2(4000, 3000)
	bg.position = Vector2(-400, -400)
	bg.z_index = -10
	add_child(bg)

	var ground := Polygon2D.new()
	ground.polygon = PackedVector2Array([
		Vector2(0, 0), Vector2(3000, 0), Vector2(3000, 2000), Vector2(0, 2000)
	])
	ground.color = Color(0.2, 0.18, 0.15)
	ground.z_index = -9
	add_child(ground)

func _build_tower() -> void:
	var tower_pos := Vector2(2800, 100)
	var tower_visual := Polygon2D.new()
	tower_visual.polygon = PackedVector2Array([
		Vector2(0, 0), Vector2(160, 0), Vector2(160, 160), Vector2(0, 160)
	])
	tower_visual.position = tower_pos
	tower_visual.color = Color(0.4, 0.4, 0.5)
	add_child(tower_visual)

	tower_area = Area2D.new()
	tower_area.collision_layer = 3
	tower_area.collision_mask  = 2   
	var shape := CollisionShape2D.new()
	var rect_shape := RectangleShape2D.new()
	rect_shape.size = Vector2(160, 160)
	shape.shape = rect_shape
	shape.position = Vector2(80, 80)
	tower_area.add_child(shape)
	tower_area.position = tower_pos
	tower_area.body_entered.connect(_on_tower_entered)
	add_child(tower_area)

func _build_guards() -> void:
	var guard_script := load("res://Code/Guard.gd")
	
	for pos in guard_spawns:
		var g := CharacterBody2D.new()
		g.set_script(guard_script)
		g.position = pos
		g.patrol_mode = "random"
		add_child(g)

func _build_player() -> void:
	player = CharacterBody2D.new()
	player.position = Vector2(100, 1000)
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
	cam.limit_bottom = 2000
	player.add_child(cam)

	add_child(player)
	
	var tutorial = preload("res://Scenes/TutorialOverlay.tscn").instantiate()
	add_child(tutorial)
	tutorial.setup([
		"O exército troiano foi alertado!",
		"Lute contra a horda de guardas nas ruas e chegue à Torre do Palácio.",
		"Use o Mouse para mirar e clique com o Botão Esquerdo para atacar.",
		"Aperte SHIFT ou o Botão Direito para dar um Dash (esquiva rápida).",
		"Você está fraco. Aperte TAB para abrir seus atributos e sacrifique anos da sua vida para ganhar força.",
		"Sacrificar anos é uma habilidade poderosa, mas nada vem sem preço. Seja responsável."
	])

func _build_allies() -> void:
	var ally_script = load("res://Code/Ally.gd")
	for i in range(20):
		var a = CharacterBody2D.new()
		a.set_script(ally_script)
		a.position = Vector2(100 + randf_range(-60, 60), 1000 + randf_range(-60, 60))
		add_child(a)

func _on_health_changed(hp: int) -> void:
	for i in range(10):
		if i < hp:
			hp_icons[i].color = Color(1.0, 0.2, 0.2)
		else:
			hp_icons[i].color = Color(0.2, 0.2, 0.2)

func _on_tower_entered(body: Node) -> void:
	if body == player and not GameManager.game_over:
		message_label.text = "A TORRE DO PALÁCIO!\nEnfrente o Rei de Troia..."
		message_label.visible = true
		message_bg.visible    = true
		var t = get_tree().create_timer(2.0)
		t.timeout.connect(func(): get_tree().change_scene_to_file("res://Ato1_Troia/Cutscenes/Act1_Cutscene_Palacio.tscn"))

func _on_game_over() -> void:
	message_label.text = "ODISSEU CAIU EM BATALHA!\nPressione R para tentar de novo"
	message_label.visible = true
	message_bg.visible    = true

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		GameManager.heal_fully()
		get_tree().reload_current_scene()
