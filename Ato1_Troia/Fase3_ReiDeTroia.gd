extends Node2D

## Fase 3 - O Rei de Troia (Ato 1)
## A Sala do Trono (Boss Fight)
## Batalha final contra o Rei de Troia.

@export var arena_size: Vector2 = Vector2(1000, 800)
@export var player_spawn_pos: Vector2 = Vector2(200, 400)
@export var boss_spawn_pos: Vector2 = Vector2(800, 400)

var player: CharacterBody2D
var boss: CharacterBody2D
var hp_icons: Array[ColorRect] = []
var boss_health_bg: ColorRect
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

	for i in range(10):
		var node = get_node_or_null("UILayer/HPIcon_" + str(i))
		if node: hp_icons.append(node)

	GameManager.player_health_changed.connect(_on_health_changed)
	GameManager.game_over_combat.connect(_on_game_over)
	
	_on_health_changed(GameManager.player_current_hp)

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
