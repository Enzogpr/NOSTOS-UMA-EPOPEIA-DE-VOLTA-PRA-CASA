extends Node2D

## Fase de Navegação Marítima: Odisseia pelo Arquipélago da Névoa (Versão Épica & Não-Linear)

@onready var ship: CharacterBody2D = $ShipPlayer
@onready var destination: Area2D = $DestinationIsland
@onready var hud_hull_bar: ProgressBar = $CanvasLayer/HUD/Margin/HBox/HullContainer/HullBar
@onready var hud_hull_text: Label = $CanvasLayer/HUD/Margin/HBox/HullContainer/HullText
@onready var hud_compass_arrow: Label = $CanvasLayer/HUD/Margin/HBox/NavContainer/CompassArrow
@onready var hud_dist_label: Label = $CanvasLayer/HUD/Margin/HBox/NavContainer/DistLabel
@onready var hud_boost_label: Label = $CanvasLayer/HUD/Margin/HBox/BoostContainer/BoostLabel
@onready var message_overlay: ColorRect = $CanvasLayer/MessageOverlay
@onready var message_label: Label = $CanvasLayer/MessageOverlay/Label
@onready var fog_overlay: ColorRect = $CanvasLayer/FogOverlay

var is_level_ended: bool = false
var is_game_over: bool = false
var is_in_storm: bool = false

# Waypoints de orientação da rota (não é linha reta!)
var route_waypoints: Array[Vector2] = [
	Vector2(2400, 3200), # 1. Contornar península para o Sul
	Vector2(4500, 1400), # 2. Subir pelo estreito para o Norte
	Vector2(6800, 2200), # 3. Cruzar a tempestade a Leste
	Vector2(9200, 2600)  # 4. Costa da Ilha do Ciclope
]
var current_wp_idx: int = 0

func _ready() -> void:
	MainHUD.set_station("Viagem Marítima: O Grande Arquipélago da Névoa")
	message_overlay.visible = false
	
	if ship:
		ship.hull_changed.connect(_on_hull_changed)
		ship.ship_destroyed.connect(_on_ship_destroyed)
		ship.item_collected.connect(_on_item_collected)
		_on_hull_changed(ship.current_hull, ship.max_hull)
		
	if destination:
		destination.body_entered.connect(_on_destination_reached)
		
	# Conecta zonas de tempestade
	for storm in get_tree().get_nodes_in_group("storm_zones"):
		if storm.has_signal("entered_storm"):
			storm.entered_storm.connect(func(active): is_in_storm = active)
			
	# Tutorial da Atena
	var tutorial = preload("res://Scenes/TutorialOverlay.tscn").instantiate()
	add_child(tutorial)
	tutorial.setup([
		"Odisseu, o arquipélago até a Ilha do Ciclope é um labirinto de rochedos afiados sob névoa densa.",
		"A rota não é reta: canais falsos levam a paredões intransponíveis. Observe os momentos de clareza na névoa!",
		"Siga as gaivotas brancas puras para os canais seguros, mas desconfie de bandos dispersos.",
		"O mar possui corrente contínua e obstáculos à deriva. O impulso [Espaço] consome um pouco de integridade do casco!"
	])

func _process(_delta: float) -> void:
	if not is_instance_valid(ship) or is_level_ended:
		return
		
	# 1. Névoa Dinâmica Pulsante (Janelas de Clareza e Ondas de Nevoeiro)
	var time_sec = Time.get_ticks_msec() * 0.001
	var mist_pulse = 0.35 + sin(time_sec * 0.5) * 0.22 + sin(time_sec * 1.3) * 0.08
	
	if is_in_storm:
		# Na tempestade: névoa densa e escura com trovoadas
		var flash = 0.1 if fmod(time_sec * 8.0, 3.0) < 0.15 else 0.0
		fog_overlay.color = Color(0.08 + flash, 0.12 + flash, 0.18 + flash, 0.65)
		hud_dist_label.text = "⚡ TEMPESTADE VIOLENTA! ⚡"
		hud_dist_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
		hud_compass_arrow.text = ["🌪️ [ Bússola Cega ]", "⚡ Vento Sul 🡫", "⚡ Vento Leste ➔"][randi() % 3]
	else:
		fog_overlay.color = Color(0.12, 0.22, 0.32, clamp(mist_pulse, 0.12, 0.65))
		
		# 2. Navegação por Waypoints (Rota Não-Linear)
		if current_wp_idx < route_waypoints.size():
			var target_wp = route_waypoints[current_wp_idx]
			var to_wp = target_wp - ship.global_position
			
			if to_wp.length() < 500.0 and current_wp_idx < route_waypoints.size() - 1:
				current_wp_idx += 1
				
			var total_to_dest = destination.global_position - ship.global_position
			var dist_meters = int(total_to_dest.length() * 0.1)
			hud_dist_label.text = "🌫️ Distância Total: ~%d m" % dist_meters
			hud_dist_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
			
			# Indicador da próxima direção do canal
			var angle_deg = rad_to_deg(to_wp.angle())
			if angle_deg >= -25 and angle_deg < 25:
				hud_compass_arrow.text = "➔ (Leste)"
			elif angle_deg >= 25 and angle_deg < 70:
				hud_compass_arrow.text = "🡮 (Sudeste)"
			elif angle_deg >= 70 and angle_deg < 115:
				hud_compass_arrow.text = "🡫 (Sul)"
			elif angle_deg >= 115 and angle_deg < 160:
				hud_compass_arrow.text = "🡯 (Sudoeste)"
			elif angle_deg >= -70 and angle_deg < -25:
				hud_compass_arrow.text = "🡭 (Nordeste)"
			elif angle_deg >= -115 and angle_deg < -70:
				hud_compass_arrow.text = "🡩 (Norte)"
			else:
				hud_compass_arrow.text = "⬅ (Oeste)"
				
	# 3. Status do Boost
	if ship.boost_cooldown > 0.0:
		hud_boost_label.text = "⚡ Remadores: Recarregando (%.1fs)" % ship.boost_cooldown
		hud_boost_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	else:
		hud_boost_label.text = "⚡ [ESPAÇO] Força Total (-5 Casco)"
		hud_boost_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5))

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
		message_label.text = "TERRA À VISTA!\nOdisseu atravessou os rochedos e a tempestade e ancorou na Ilha do Ciclope!"
		message_overlay.visible = true
		var t = get_tree().create_timer(3.5)
		t.timeout.connect(func():
			get_tree().change_scene_to_file("res://Scenes/TitleScreen.tscn")
		)

func _on_ship_destroyed() -> void:
	is_game_over = true
	is_level_ended = true
	message_label.text = "O NAVIO NAUFRAGOU!\nO casco foi despedaçado pelas rochas e tempestade.\nPressione [ R ] para tentar novamente."
	message_overlay.visible = true

func _show_popup_msg(text: String) -> void:
	message_label.text = text
	message_overlay.visible = true
	var t = get_tree().create_timer(2.5)
	t.timeout.connect(func(): if is_instance_valid(message_overlay) and not is_level_ended: message_overlay.visible = false)
