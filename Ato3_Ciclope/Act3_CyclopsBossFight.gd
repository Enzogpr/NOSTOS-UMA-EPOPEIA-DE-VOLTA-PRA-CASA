extends Node2D

## Arena da Batalha contra Polifemo (Ato 3)

@onready var message_bg: ColorRect = $UILayer/MessageBG
@onready var message_label: Label = $UILayer/MessageLabel
@onready var boss_hp_bar: ProgressBar = $UILayer/BossHPBar
@onready var boss_hp_label: Label = $UILayer/BossHPBar/Label
@onready var survival_timer_label: Label = $UILayer/SurvivalTimerLabel

var player: CharacterBody2D
var boss: CharacterBody2D

var is_survival_phase: bool = false
var survival_time_left: float = 180.0

var hp_icons: Array[ColorRect] = []

func _ready() -> void:
	MainHUD.set_station("Ato 3 - O Despertar da Fúria")
	GameManager.enable_combat_mode()
	GameManager.heal_fully()
	
	_build_arena()
	_spawn_player()
	_spawn_boss()
	_spawn_allies(15)
	_build_hp_icons()
	
	survival_timer_label.visible = false
	boss.phase_changed.connect(_on_boss_phase_changed)
	boss.boss_defeated.connect(_on_boss_defeated)
	GameManager.player_health_changed.connect(_on_health_changed)
	GameManager.game_over_combat.connect(_on_game_over)
	
	_on_health_changed(GameManager.player_current_hp)
	_show_message("LUTE! Faça Polifemo sangrar!")

func _build_hp_icons() -> void:
	for i in range(10):
		var rect = ColorRect.new()
		rect.size = Vector2(20, 20)
		rect.position = Vector2(20 + i * 25, 34)
		rect.color = Color(1.0, 0.2, 0.2)
		$UILayer.add_child(rect)
		hp_icons.append(rect)

func _on_health_changed(hp: int) -> void:
	for i in range(10):
		if i < hp_icons.size():
			if i < hp:
				hp_icons[i].color = Color(1.0, 0.2, 0.2)
			else:
				hp_icons[i].color = Color(0.2, 0.2, 0.2)

func _on_game_over() -> void:
	_show_message("O TEMPO ACABOU!\nPolifemo esmagou Odisseu.\nPressione [ R ] para tentar novamente.")

func _unhandled_input(event: InputEvent) -> void:
	if GameManager.game_over and event is InputEventKey and event.pressed and event.keycode == KEY_R:
		GameManager.heal_fully()
		get_tree().reload_current_scene()

func _build_arena() -> void:
	# Chão da Caverna
	var bg = ColorRect.new()
	bg.color = Color(0.2, 0.18, 0.15) # Clareado para ver melhor
	bg.size = Vector2(1400, 900)
	bg.position = Vector2(0, 0)
	bg.z_index = -10
	add_child(bg)
	
	# Paredes (Limites)
	_build_wall(Rect2(0, -200, 1400, 200)) # Topo
	_build_wall(Rect2(0, 900, 1400, 200)) # Baixo
	_build_wall(Rect2(-200, 0, 200, 900)) # Esquerda
	_build_wall(Rect2(1400, 0, 200, 900)) # Direita

func _build_wall(rect: Rect2) -> void:
	var body = StaticBody2D.new()
	var poly = Polygon2D.new()
	poly.polygon = PackedVector2Array([
		rect.position,
		Vector2(rect.position.x + rect.size.x, rect.position.y),
		Vector2(rect.position.x + rect.size.x, rect.position.y + rect.size.y),
		Vector2(rect.position.x, rect.position.y + rect.size.y)
	])
	poly.color = Color(0.05, 0.04, 0.03)
	body.add_child(poly)
	
	var shape = CollisionShape2D.new()
	var cshape = RectangleShape2D.new()
	cshape.size = rect.size
	shape.shape = cshape
	shape.position = rect.position + rect.size / 2.0
	body.add_child(shape)
	
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)

func _spawn_player() -> void:
	player = CharacterBody2D.new()
	player.set_script(load("res://Code/Player.gd"))
	player.position = Vector2(700, 800)
	player.collision_layer = 2
	player.collision_mask = 1
	add_child(player)
	
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 10.0
	shape.shape = circle
	player.add_child(shape)
	
	var cam = Camera2D.new()
	cam.position_smoothing_enabled = true
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = 1400
	cam.limit_bottom = 900
	player.add_child(cam)

func _try_load(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	return null

func _spawn_boss() -> void:
	boss = CharacterBody2D.new()
	boss.set_script(load("res://Ato3_Ciclope/CyclopsBoss.gd"))
	boss.position = Vector2(700, 400) # Aproximado do player
	add_child(boss)

func _spawn_allies(count: int) -> void:
	var ally_script = load("res://Code/Ally.gd")
	for i in range(count):
		var a = CharacterBody2D.new()
		a.set_script(ally_script)
		a.position = Vector2(700 + randf_range(-200, 200), 700 + randf_range(-100, 100))
		a.move_speed = 70.0
		add_child(a)
		a.add_to_group("allies")

func _process(delta: float) -> void:
	if boss:
		boss_hp_bar.value = float(boss.current_hp) / boss.max_hp * 100.0
		boss_hp_label.text = "POLIFEMO: " + str(boss.current_hp) + " / " + str(boss.max_hp)
	
	if is_survival_phase and not GameManager.game_over:
		survival_time_left -= delta
		if survival_time_left <= 0:
			survival_time_left = 0
			is_survival_phase = false
			boss.fall_asleep()
			
		var m = int(survival_time_left) / 60
		var s = int(survival_time_left) % 60
		survival_timer_label.text = "SOBREVIVA: %02d:%02d" % [m, s]

func _on_boss_phase_changed() -> void:
	is_survival_phase = true
	survival_timer_label.visible = true
	_show_message("SOBREVIVA!\nPolifemo empunha sua clava. A fúria é incontrolável!")
	boss_hp_bar.modulate = Color(1.0, 0.5, 0.0)

func _on_boss_defeated() -> void:
	survival_timer_label.text = "O CICLOPE CAIU!"
	
	# Aguardar a animação dele dormir/desmaiar
	var tw = create_tween()
	tw.tween_interval(4.0)
	tw.tween_callback(func(): get_tree().change_scene_to_file("res://Ato3_Ciclope/Cutscenes/Act3_BlindingCutscene.tscn"))

func _show_message(msg: String) -> void:
	message_label.text = msg
	message_bg.visible = true
	message_label.visible = true
	var tw = create_tween()
	tw.tween_interval(3.0)
	tw.tween_property(message_bg, "modulate", Color(1,1,1,0), 1.0)
	tw.parallel().tween_property(message_label, "modulate", Color(1,1,1,0), 1.0)
	tw.tween_callback(func(): 
		message_bg.visible = false
		message_label.visible = false
		message_bg.modulate = Color(1,1,1,1)
		message_label.modulate = Color(1,1,1,1)
	)
