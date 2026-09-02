extends Node2D

## Fase 2 - Navegação Marítima (Ato 2)
## Da Ilha dos Lotófagos até a Ilha a Leste

@onready var ship: CharacterBody2D = $ShipPlayer
@onready var destination: Area2D = $DestinationIsland
@onready var hud_hull_bar: ProgressBar = $CanvasLayer/HUD/Margin/HBox/HullContainer/HullBar
@onready var hud_hull_text: Label = $CanvasLayer/HUD/Margin/HBox/HullContainer/HullText
@onready var hud_compass_arrow: Label = $CanvasLayer/HUD/Margin/HBox/NavContainer/CompassArrow
@onready var hud_dist_label: Label = $CanvasLayer/HUD/Margin/HBox/NavContainer/DistLabel
@onready var message_overlay: ColorRect = $CanvasLayer/MessageOverlay
@onready var message_label: Label = $CanvasLayer/MessageOverlay/Label

var is_level_ended: bool = false
var is_game_over: bool = false

func _ready() -> void:
	MainHUD.set_station("Ato 2 - Fase 2: Navegação Marítima")
	message_overlay.visible = false
	
	if ship:
		ship.hull_changed.connect(_on_hull_changed)
		ship.ship_destroyed.connect(_on_ship_destroyed)
		ship.item_collected.connect(_on_item_collected)
		_on_hull_changed(ship.current_hull, ship.max_hull)
		
	if destination:
		destination.body_entered.connect(_on_destination_reached)
		
	# Tutorial da Atena sem mencionar o ciclope e sem boost
	var tutorial = preload("res://Scenes/TutorialOverlay.tscn").instantiate()
	add_child(tutorial)
	tutorial.setup([
		"Odisseu, ajuste as velas e comande o leme rumo à ilha a leste em busca de provisões.",
		"Use [W / S] para acelerar e frear, e [A / D] para manobrar o leme do navio.",
		"Cuidado com os recifes e redemoinhos no caminho, e colete caixas na água para reparar o casco!"
	])

func _process(_delta: float) -> void:
	if not is_instance_valid(ship) or is_level_ended:
		return
		
	# Atualiza a bússola e distância até o destino
	if is_instance_valid(destination) and is_instance_valid(hud_dist_label) and is_instance_valid(hud_compass_arrow):
		var to_dest = destination.global_position - ship.global_position
		var dist_meters = int(to_dest.length() * 0.1)
		hud_dist_label.text = "🏝️ Ilha a Leste: %d m" % dist_meters
		
		# Seta que aponta na direção
		var angle_deg = rad_to_deg(to_dest.angle())
		if angle_deg >= -45 and angle_deg < 45:
			hud_compass_arrow.text = "➔ (Leste)"
		elif angle_deg >= 45 and angle_deg < 135:
			hud_compass_arrow.text = "🡫 (Sul)"
		elif angle_deg >= -135 and angle_deg < -45:
			hud_compass_arrow.text = "🡩 (Norte)"
		else:
			hud_compass_arrow.text = "⬅ (Oeste)"

func _unhandled_input(event: InputEvent) -> void:
	if is_game_over:
		if event.is_pressed() and (event.is_action_pressed("ui_accept") or (event is InputEventKey and event.keycode == KEY_R)):
			get_tree().reload_current_scene()

func _on_hull_changed(current: int, max_val: int) -> void:
	if not is_instance_valid(hud_hull_bar) or not is_instance_valid(hud_hull_text):
		return
		
	hud_hull_bar.max_value = max_val
	hud_hull_bar.value = current
	hud_hull_text.text = "🛡️ Casco: %d / %d" % [current, max_val]
	
	var ratio = float(current) / float(max_val)
	if ratio > 0.6:
		hud_hull_text.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5))
	elif ratio > 0.3:
		hud_hull_text.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	else:
		hud_hull_text.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))

func _on_item_collected(msg: String) -> void:
	_show_popup_msg(msg)

func _on_destination_reached(body: Node2D) -> void:
	if body == ship and not is_level_ended:
		is_level_ended = true
		message_label.text = "TERRA À VISTA!\nOdisseu ancorou na costa da ilha a leste em busca da grande caverna!"
		message_overlay.visible = true
		var t = get_tree().create_timer(3.5)
		t.timeout.connect(func():
			get_tree().change_scene_to_file("res://Ato2_Lotofagos/Cutscenes/Act2_EndingCutscene.tscn")
		)

func _on_ship_destroyed() -> void:
	is_game_over = true
	is_level_ended = true
	message_label.text = "O NAVIO NAUFRAGOU!\nO casco foi destruído contra os rochedos e redemoinhos.\nPressione [ R ] para tentar novamente."
	message_overlay.visible = true

func _show_popup_msg(text: String) -> void:
	message_label.text = text
	message_overlay.visible = true
	var t = get_tree().create_timer(2.0)
	t.timeout.connect(func(): if is_instance_valid(message_overlay) and not is_level_ended: message_overlay.visible = false)
