extends Control

## Fase 1 - A Ilha dos Lotófagos (Ato 2)
## Dungeon Crawler em Primeira Pessoa na Selva Labiríntica.

var map_width := 20
var map_height := 20

# 0: Caminho livre, 1: Parede de Árvores/Selva, 2: Ponto de Tripulante (Ordem Dinâmica), 5: Praia (Spawn/Saída), 6: Ruínas
var map := [
	[1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1],
	[1,5,0,0,1,0,0,0,1,0,0,0,0,0,1,0,0,0,2,1],
	[1,1,1,0,1,0,1,0,1,0,1,1,1,0,1,0,1,1,1,1],
	[1,0,0,0,0,0,1,0,0,0,1,0,0,0,0,0,0,0,0,1],
	[1,0,1,1,1,1,1,1,1,0,1,0,1,1,1,1,1,1,0,1],
	[1,0,1,0,0,0,0,0,1,0,0,0,1,0,0,0,0,1,0,1],
	[1,0,1,0,1,1,1,0,1,1,1,1,1,0,1,1,0,1,0,1],
	[1,0,0,0,1,6,1,0,0,0,0,0,0,0,1,2,0,1,0,1],
	[1,1,1,0,1,0,1,1,1,0,1,1,1,1,1,1,0,1,0,1],
	[1,0,0,0,1,0,0,0,1,0,0,0,0,0,0,0,0,0,0,1],
	[1,0,1,1,1,1,1,0,1,1,1,1,1,0,1,1,1,1,1,1],
	[1,0,0,0,0,0,1,0,0,0,0,0,1,0,1,0,0,0,0,1],
	[1,1,1,1,1,0,1,1,1,1,1,0,1,0,1,0,1,1,0,1],
	[1,0,0,0,1,0,0,0,0,0,1,0,0,0,1,0,1,0,0,1],
	[1,0,1,0,1,1,1,1,1,0,1,1,1,0,1,0,1,0,1,1],
	[1,0,1,0,0,0,0,0,1,0,0,0,1,0,0,0,1,0,0,1],
	[1,0,1,1,1,1,1,0,1,1,1,0,1,1,1,1,1,1,0,1],
	[1,0,0,0,0,6,1,0,0,0,1,0,0,0,0,0,0,0,0,1],
	[1,1,1,1,1,0,1,0,1,0,1,1,1,1,1,0,1,1,2,1],
	[1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1]
]

var dir_vectors := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
var dir_names := ["NORTE", "LESTE", "SUL", "OESTE"]

var player_pos := Vector2i(1, 1)
var player_dir := 1

# Estado da Missão
var time_left: float = 300.0 # 5 Minutos
var crew_saved: int = 0
var has_lotus_flower: bool = false
var mission_completed: bool = false
var is_game_over: bool = false
var is_dialogue_open: bool = false
var is_cutscene_open: bool = false

# Cutscene do Último Encontro
var cutscene_slide := 0
var cutscene_slides := [
	{
		"image": "res://Assets/lotus_encounter_1.jpg",
		"speaker": "Narrador",
		"text": "Adentrando uma clareira sagrada, Odisseu encontra o último de seus marinheiros reunido com os pacíficos comedores de lótus."
	},
	{
		"image": "res://Assets/lotus_encounter_1.jpg",
		"speaker": "Odisseu (empunhando a espada)",
		"text": "\"Afastem-se dele! Viemos da grande guerra de Troia... estamos nesta ilha apenas em busca de comida para nossa tripulação faminta!\""
	},
	{
		"image": "res://Assets/lotus_encounter_2.jpg",
		"speaker": "Ancião dos Lotófagos",
		"text": "\"Abaixe sua lâmina, nobre guerreiro. Não há ódio nesta terra... Aceite nosso doce fruto e permaneça em paz conosco para sempre.\""
	},
	{
		"image": "res://Assets/lotus_encounter_3.jpg",
		"speaker": "Odisseu (examinando a flor)",
		"text": "(pensamento) \"Esta é a lendária Flor de Lótus... seu torpor é tão doce e avassalador que seria capaz de derrubar até o maior dos inimigos. Devo guardá-la comigo.\""
	},
	{
		"image": "res://Assets/lotus_encounter_4.jpg",
		"speaker": "Odisseu & Ancião",
		"text": "Odisseu: \"Não podemos ficar. Meus homens precisam de sustento real... Existe outra fonte de comida nestas ilhas?\"\n\nAncião dos Lotófagos: \"Nós apenas nos alimentamos do Lótus... mas já ouvimos navegantes dizerem que há uma grande caverna na ilha a leste.\""
	}
]

var explored := {}

@onready var first_person_view: Control = $MainLayout/ViewContainer/FirstPersonView
@onready var minimap: Control = $MainLayout/SideContainer/MinimapContainer/Minimap
@onready var timer_label: Label = $HUD/TimerLabel
@onready var crew_label: Label = $HUD/CrewLabel
@onready var compass_label: Label = $MainLayout/SideContainer/CompassLabel

@onready var dialogue_box: Panel = $DialogueBox
@onready var dialogue_text: Label = $DialogueBox/Margin/VBox/Text
@onready var dialogue_title: Label = $DialogueBox/Margin/VBox/Title

@onready var cutscene_overlay: Control = $CutsceneOverlay
@onready var cutscene_img: TextureRect = $CutsceneOverlay/TextureRect
@onready var cutscene_speaker: Label = $CutsceneOverlay/TextPanel/Margin/VBox/SpeakerLabel
@onready var cutscene_text: Label = $CutsceneOverlay/TextPanel/Margin/VBox/DialogueLabel

@onready var message_overlay: ColorRect = $MessageOverlay
@onready var message_label: Label = $MessageOverlay/Label
@onready var inventory_menu: Control = $InventoryMenu

var inventory_tut_shown: bool = false

func _ready() -> void:
	MainHUD.set_station("Ato 2 - Fase 1: Ilha dos Lotófagos")
	GameManager.heal_fully()
	
	dialogue_box.visible = false
	cutscene_overlay.visible = false
	message_overlay.visible = false
	
	if inventory_menu:
		inventory_menu.inventory_closed.connect(_on_inventory_closed)
	
	_mark_explored(player_pos)
	_update_hud()
	_render_view()
	_render_minimap()
	
	var tutorial = preload("res://Scenes/TutorialOverlay.tscn").instantiate()
	add_child(tutorial)
	tutorial.setup([
		"Bem-vindo à misteriosa Ilha dos Lotófagos, Odisseu.",
		"Esta selva é um labirinto denso e desorientador.",
		"Seus homens provaram do fruto do Lótus e caíram em profundo torpor e esquecimento.",
		"Use [W/S] ou [Cima/Baixo] para avançar e recuar, e [A/D] para girar a visão em 90 graus.",
		"Você tem 5 minutos antes que o efeito da flor se torne permanente. Encontre os 3 tripulantes!"
	])

func _process(delta: float) -> void:
	if is_game_over or mission_completed or get_tree().paused or is_dialogue_open or is_cutscene_open:
		return
		
	time_left -= delta
	_update_hud()
	
	if time_left <= 0.0:
		time_left = 0.0
		_trigger_game_over("O TEMPO ACABOU!\nSeus homens esqueceram de suas casas para sempre e você perdeu sua tripulação.\nPressione [ R ] para reiniciar.")

func _unhandled_input(event: InputEvent) -> void:
	if is_game_over:
		if event.is_pressed() and not event.is_echo():
			if event.is_action_pressed("ui_accept") or (event is InputEventKey and event.keycode == KEY_R):
				get_tree().reload_current_scene()
		return
		
	if is_cutscene_open:
		if event.is_pressed() and not event.is_echo():
			_next_cutscene_slide()
		return

	if is_dialogue_open:
		if event.is_pressed() and not event.is_echo():
			_close_dialogue()
		return
		
	if event.is_pressed() and not event.is_echo():
		if event is InputEventKey and event.keycode == KEY_I:
			if inventory_menu.visible:
				inventory_menu.close_inventory()
			else:
				inventory_menu.open_inventory()
			return
			
		if event.is_action_pressed("ui_up") or (event is InputEventKey and event.keycode == KEY_W):
			_move_forward()
		elif event.is_action_pressed("ui_down") or (event is InputEventKey and event.keycode == KEY_S):
			_move_backward()
		elif event.is_action_pressed("ui_left") or (event is InputEventKey and event.keycode == KEY_A):
			_turn_left()
		elif event.is_action_pressed("ui_right") or (event is InputEventKey and event.keycode == KEY_D):
			_turn_right()

func _move_forward() -> void:
	var next_pos = player_pos + dir_vectors[player_dir]
	if _can_walk(next_pos):
		player_pos = next_pos
		_mark_explored(player_pos)
		_check_tile_events()
		_render_view()
		_render_minimap()

func _move_backward() -> void:
	var next_pos = player_pos - dir_vectors[player_dir]
	if _can_walk(next_pos):
		player_pos = next_pos
		_mark_explored(player_pos)
		_check_tile_events()
		_render_view()
		_render_minimap()

func _turn_left() -> void:
	player_dir = (player_dir - 1 + 4) % 4
	_update_hud()
	_render_view()
	_render_minimap()

func _turn_right() -> void:
	player_dir = (player_dir + 1) % 4
	_update_hud()
	_render_view()
	_render_minimap()

func _can_walk(pos: Vector2i) -> bool:
	if pos.x < 0 or pos.x >= map_width or pos.y < 0 or pos.y >= map_height:
		return false
	var tile = map[pos.y][pos.x]
	return tile != 1 and tile != 6

func _mark_explored(pos: Vector2i) -> void:
	explored[pos] = true
	for d in dir_vectors:
		var adj = pos + d
		if adj.x >= 0 and adj.x < map_width and adj.y >= 0 and adj.y < map_height:
			explored[adj] = true

func _check_tile_events() -> void:
	var tile = map[player_pos.y][player_pos.x]
	
	if tile == 2:
		map[player_pos.y][player_pos.x] = 0
		crew_saved += 1
		_update_hud()
		
		if crew_saved < 3:
			_show_crew_dialogue(crew_saved)
		else:
			_trigger_last_encounter_cutscene()
			
	elif tile == 5 and has_lotus_flower and crew_saved >= 3:
		_trigger_victory()

func _show_crew_dialogue(idx: int) -> void:
	is_dialogue_open = true
	dialogue_box.visible = true
	dialogue_title.text = "Companheiro de Ítaca (" + str(idx) + "/3 Resgatado)"
	if idx == 1:
		dialogue_text.text = "\"Capitão Odisseu... as flores daqui têm um sabor dos deuses... esqueci de Ítaca, esqueci de minha família...\"\n\n(Odisseu puxa o soldado com firmeza pelo braço e o arrasta em direção ao barco)."
	elif idx == 2:
		dialogue_text.text = "\"Por que partir? Esta terra traz a paz que nunca tivemos em dez anos de guerra...\"\n\n(Odisseu amarra o guerreiro à margem e continua a busca pelo último homem)."

func _close_dialogue() -> void:
	is_dialogue_open = false
	dialogue_box.visible = false
	_render_view()

func _trigger_last_encounter_cutscene() -> void:
	is_cutscene_open = true
	cutscene_slide = 0
	MainHUD.visible = false
	cutscene_overlay.visible = true
	cutscene_overlay.modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(cutscene_overlay, "modulate:a", 1.0, 0.7)
	_update_cutscene_slide()

func _update_cutscene_slide() -> void:
	var slide = cutscene_slides[cutscene_slide]
	cutscene_speaker.text = slide["speaker"]
	cutscene_text.text = slide["text"]
	
	var img_path: String = slide["image"]
	if ResourceLoader.exists(img_path):
		cutscene_img.texture = load(img_path)
	elif ResourceLoader.exists(img_path.replace(".jpg", ".png")):
		cutscene_img.texture = load(img_path.replace(".jpg", ".png"))
	else:
		cutscene_img.texture = null

func _next_cutscene_slide() -> void:
	cutscene_slide += 1
	if cutscene_slide < cutscene_slides.size():
		var tween = create_tween()
		tween.tween_property(cutscene_text, "modulate:a", 0.0, 0.15)
		tween.tween_callback(func():
			_update_cutscene_slide()
		)
		tween.tween_property(cutscene_text, "modulate:a", 1.0, 0.2)
	else:
		var tween = create_tween()
		tween.tween_property(cutscene_overlay, "modulate:a", 0.0, 0.6)
		tween.tween_callback(func():
			is_cutscene_open = false
			cutscene_overlay.visible = false
			MainHUD.visible = true
			has_lotus_flower = true
			
			GameManager.add_item(
				"lotus_flower",
				"Flor de Lótus Sagrada",
				"res://Assets/lotus_encounter_3.jpg",
				"Uma flor sagrada de pétalas púrpuras e fragrância adocicada. Quem consome suas folhas ou respira seu aroma cai em profundo torpor e esquecimento.",
				"Pode ser misturada ao vinho doce para entorpecer e adormecer qualquer criatura viva, por mais colossal que seja."
			)
			
			_update_hud()
			_render_view()
			
			var tutorial = preload("res://Scenes/TutorialOverlay.tscn").instantiate()
			add_child(tutorial)
			tutorial.setup([
				"Odisseu, você obteve a Flor de Lótus Sagrada e agora possui acesso ao seu Inventário.",
				"Pressione [ I ] a qualquer momento para abrir seus itens.",
				"Dê um clique duplo no item para examiná-lo e descobrir como usá-lo."
			])
		)

func _on_inventory_closed() -> void:
	if has_lotus_flower and not inventory_tut_shown:
		inventory_tut_shown = true
		var tutorial = preload("res://Scenes/TutorialOverlay.tscn").instantiate()
		add_child(tutorial)
		tutorial.setup([
			"Excelente! Agora que recuperou todos os seus homens e conhece o segredo do Lótus...",
			"Retorne ao barco na praia (Ponto de Início) para zarpar rumo à próxima ilha!"
		])
		_show_popup_msg("Retorne ao barco na praia (Ponto de Início) para zarpar!")

func _show_popup_msg(text: String) -> void:
	message_label.text = text
	message_overlay.visible = true
	var t = get_tree().create_timer(4.0)
	t.timeout.connect(func(): if is_instance_valid(message_overlay): message_overlay.visible = false)

func _trigger_victory() -> void:
	mission_completed = true
	message_label.text = "ESTAÇÃO 2 CONCLUÍDA!\nOdisseu reuniu sua tripulação e zarpou rumo ao mar aberto..."
	message_overlay.visible = true
	var t = get_tree().create_timer(3.0)
	t.timeout.connect(func():
		get_tree().change_scene_to_file("res://Ato2_Lotofagos/Fase2_NavegacaoMaritima.tscn")
	)

func _trigger_game_over(msg: String) -> void:
	is_game_over = true
	message_label.text = msg
	message_overlay.visible = true

func _render_view() -> void:
	first_person_view.queue_redraw()

func _render_minimap() -> void:
	minimap.queue_redraw()

func _update_hud() -> void:
	var mins = int(time_left) / 60
	var secs = int(time_left) % 60
	timer_label.text = "⏳ TEMPO: %02d:%02d" % [mins, secs]
	if time_left < 60.0:
		timer_label.add_theme_color_override("font_color", Color(1, 0.2, 0.2))
	else:
		timer_label.add_theme_color_override("font_color", Color(1, 0.9, 0.4))
		
	crew_label.text = "👥 MARINHEIROS: %d / 3" % crew_saved
	compass_label.text = "BÚSSOLA: " + dir_names[player_dir]
