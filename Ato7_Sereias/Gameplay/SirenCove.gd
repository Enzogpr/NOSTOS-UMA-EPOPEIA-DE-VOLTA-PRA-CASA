extends Control

const MODEL := preload("res://Ato7_Sereias/Gameplay/SirenEncounter.gd")
const STAGE := preload("res://Ato7_Sereias/Gameplay/SirenStage.gd")
const ATTRIBUTES := preload("res://Code/PlayerAttributes.gd")
const MAP := "res://Scenes/WorldMap.tscn"
const GOLD := Color("f2d78e")
const WHITE := Color("e3f1e7")
const MUTED := Color("99c7c2")

@export var audio_enabled := true

var encounter := MODEL.new()
var stage: STAGE
var frame: Node2D
var encounter_label: Label
var window_label: Label
var clock_label: Label
var hp_label: Label
var phase_label: Label
var status_label: Label
var net_meter: ProgressBar
var intro: Panel
var result: Panel
var result_title: Label
var result_text: Label
var result_retry: Button
var result_next: Button
var result_map: Button
var top: Panel
var bottom: Panel
var final_dialogue: Panel
var message := ""
var message_time := 0.0
var gate_open := false
var victory_age := 0.0
var previous_phase := MODEL.Phase.READY
var ambience: AudioStreamPlayer
var song: AudioStreamPlayer
var effects: AudioStreamPlayer
var music_was_paused := false

func _ready() -> void:
	set_meta("hide_main_hud", true)
	MainHUD.set_station("Ato VII - O canto das sereias")
	gate_open = GameManager.standalone_stage_preview or GameManager.underworld_prophecy_completed
	_apply_attributes()
	encounter.set_entry_health(GameManager.player_current_hp)
	GameManager.player_stats_changed.connect(_apply_attributes)
	encounter.cue.connect(_on_cue)
	frame = Node2D.new()
	add_child(frame)
	stage = STAGE.new()
	stage.encounter = encounter
	frame.add_child(stage)
	_build_hud()
	resized.connect(_fit)
	_fit()
	if audio_enabled:
		_setup_audio()
	_update_hud()

func _fit() -> void:
	var factor := minf(size.x / STAGE.SIZE.x, size.y / STAGE.SIZE.y)
	frame.scale = Vector2.ONE * factor
	frame.position = (size - STAGE.SIZE * factor) / 2.0

func _physics_process(delta: float) -> void:
	var left := Input.is_action_pressed("ui_left") or Input.is_physical_key_pressed(KEY_A)
	var right := Input.is_action_pressed("ui_right") or Input.is_physical_key_pressed(KEY_D)
	var up := Input.is_action_pressed("ui_up") or Input.is_physical_key_pressed(KEY_W)
	var down := Input.is_action_pressed("ui_down") or Input.is_physical_key_pressed(KEY_S)
	var direction := Vector2(float(right) - float(left), float(down) - float(up))
	encounter.tick(delta, direction, Input.is_physical_key_pressed(KEY_E))
	if encounter.phase != previous_phase:
		previous_phase = encounter.phase
		if previous_phase == MODEL.Phase.WON and not GameManager.standalone_stage_preview:
			GameManager.complete_sirens(encounter.hp)
		if previous_phase == MODEL.Phase.LOST:
			_show_result(false)
	if encounter.phase == MODEL.Phase.WON:
		victory_age += delta
		if victory_age >= 0.85 and not stage.deck_visible:
			stage.deck_visible = true
			top.hide()
			bottom.hide()
		if stage.deck_visible and not stage.cave_visible and stage.deck_blend >= 0.65:
			final_dialogue.show()
		if stage.cave_visible and stage.cave_age >= 1.75 and not result.visible:
			_show_result(true)
	message_time = maxf(0.0, message_time - delta)
	_update_hud()

func _process(delta: float) -> void:
	var local := frame.to_local(get_global_mouse_position())
	stage.update_view(delta, local, MODEL.WATER.grow(16.0).has_point(local))
	if is_instance_valid(song):
		var strength := encounter.song_strength
		if encounter.helm_inverted(): strength = maxf(strength, 0.43)
		if encounter.phase in [MODEL.Phase.WON, MODEL.Phase.LOST]:
			strength = 0.0
		song.volume_db = move_toward(song.volume_db, lerpf(-65.0, -8.0, pow(strength, 0.6)), delta * 45.0)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if final_dialogue.visible and event.physical_keycode in [KEY_SPACE, KEY_ENTER]:
			_reveal_route()
			get_viewport().set_input_as_handled()
			return
		if event.physical_keycode == KEY_R:
			restart_checkpoint()
			return
		if event.physical_keycode == KEY_SPACE:
			if intro.visible and gate_open:
				_begin()
			else:
				encounter.cast_net(frame.to_local(get_global_mouse_position()))
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		encounter.cast_net(frame.to_local(get_global_mouse_position()))

func _begin() -> void:
	if not gate_open:
		return
	intro.hide()
	GameManager.reset_encounter()
	encounter.begin()

func restart_checkpoint() -> void:
	if not gate_open or encounter.phase == MODEL.Phase.WON:
		return
	intro.hide()
	result.hide()
	message_time = 0.0
	stage.clear_effects()
	encounter.restart()
	_update_hud()

func _return_to_map() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(MAP)

func _continue_to_scylla() -> void:
	if encounter.phase == MODEL.Phase.WON and stage.cave_visible:
		get_tree().change_scene_to_file("res://Ato8_Cila/Gameplay/ScyllaPassage.tscn")

func _reveal_route() -> void:
	if not final_dialogue.visible: return
	final_dialogue.hide()
	stage.reveal_cave()

func _apply_attributes() -> void:
	encounter.apply_attributes(ATTRIBUTES.capture(GameManager))
	if encounter.phase == MODEL.Phase.READY:
		encounter.set_entry_health(GameManager.player_current_hp)

func _update_hud() -> void:
	var titles := ["A PERSEGUIÇÃO", "O CORO DE ILUSÕES", "O CANTO NO LEME"]
	encounter_label.text = "LEME INVERTIDO · W ↔ S   /   A ↔ D" if encounter.helm_inverted() else titles[encounter.leg]
	encounter_label.modulate = Color("e4c0f5") if encounter.helm_inverted() else Color.WHITE
	var remaining := ceili(maxf(0.0, MODEL.LIMIT - encounter.elapsed))
	clock_label.text = "%02d:%02d" % [floori(remaining / 60.0), remaining % 60]
	clock_label.modulate = Color("ffad9b") if remaining <= 15 else Color.WHITE
	window_label.text = ""
	if encounter.window_left > 0.0:
		window_label.text = "ABERTURA  %.1f s" % encounter.window_left
	elif encounter.hooked and encounter.leg != MODEL.Leg.CHASE:
		window_label.text = "CORDA  %.1f s" % maxf(0.0, encounter.line_limit() - encounter.line_age)
	hp_label.text = "VIDA   %d / %d" % [encounter.hp, encounter.max_hp]
	phase_label.text = "FASE   %d / 3" % (encounter.leg + 1)
	net_meter.value = 1.0 - clampf(encounter.net_cooldown / MODEL.NET_COOLDOWN, 0.0, 1.0)
	if encounter.hooked and encounter.leg != MODEL.Leg.CHASE:
		net_meter.value = encounter.reel_progress / encounter.reel_time()
	if encounter.phase == MODEL.Phase.WON:
		status_label.text = "A sereia foi capturada."
	elif encounter.phase == MODEL.Phase.ENTHRALLED:
		status_label.text = "Odisseu se entrega ao canto. O barco segue a sereia."
	elif encounter.hooked:
		if encounter.leg == MODEL.Leg.CHASE:
			status_label.text = "A sereia luta contra a primeira rede."
		elif encounter.line_blocker >= 0:
			status_label.text = "A corda tocou o recife. Solte E e contorne a pedra."
		elif encounter.tug >= 0.54 or encounter.line_tension >= MODEL.STRAIN_LIMIT:
			status_label.text = "Corda esticada. Solte E até ela afrouxar."
		elif encounter.can_haul():
			status_label.text = "Corda livre. Segure E para recolher."
		else:
			status_label.text = "Aproxime o barco para recolher."
	elif message_time > 0.0:
		status_label.text = message
	elif encounter.interlude > 0.0:
		status_label.text = "Siga as bolhas. Ela está mudando de rumo."
	elif encounter.window_left > 0.0:
		status_label.text = "Observe o rastro e lance a rede." if encounter.leg == MODEL.Leg.MIRAGE else "A sereia subiu à superfície. Lance a rede."
	elif encounter.leg == MODEL.Leg.CHASE:
		status_label.text = "Persiga a sereia e mire à frente dela."
	elif encounter.leg == MODEL.Leg.MIRAGE:
		status_label.text = "Espere o canto criar as imagens."
	else:
		status_label.text = "Espere a sereia emergir entre os recifes."

func _show_result(won: bool) -> void:
	result_retry.visible = not won
	result_next.visible = won
	if won:
		result.position.y = 485.0
		result.size.y = 142.0
		result_title.text = "A GRUTA DE CILA"
		result_text.hide()
		result_next.position.y = 76.0
		result_map.position.y = 76.0
	elif encounter.charm_age > 0.0:
		result_title.text = "O CANTO TOMOU O LEME"
		result_text.text = "Enfeitiçado pela sereia, Odisseu abandona a rede e deixa o barco seguir sua voz."
	else:
		result_title.text = "ODISSEU CAIU"
		result_text.text = "A sereia alcançou o convés. Mantenha distância e lance a rede à frente dela."
	result.show()

func _panel(rect: Rect2, dim := false) -> Panel:
	var panel := Panel.new()
	panel.position = rect.position
	panel.size = rect.size
	panel.mouse_filter = Control.MOUSE_FILTER_STOP if dim else Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.075, 0.09, 0.97 if dim else 0.92)
	style.border_color = Color("638f87")
	style.set_border_width_all(1)
	style.set_corner_radius_all(7)
	panel.add_theme_stylebox_override("panel", style)
	frame.add_child(panel)
	return panel

func _label(parent: Control, text: String, rect: Rect2, font_size: int, color := WHITE, wrap := false) -> Label:
	var label := Label.new()
	if wrap:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = text
	label.position = rect.position
	label.size = rect.size
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label

func _button(parent: Control, text: String, rect: Rect2, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.position = rect.position
	button.size = rect.size
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _build_hud() -> void:
	top = _panel(Rect2(24, 18, 1104, 78))
	_label(top, "SEREIAS  /  O RECIFE DO CANTO", Rect2(19, 8, 670, 31), 24, GOLD)
	encounter_label = _label(top, "", Rect2(20, 43, 680, 24), 16, MUTED)
	window_label = _label(top, "", Rect2(650, 26, 173, 29), 16, MUTED)
	clock_label = _label(top, "", Rect2(835, 12, 132, 51), 30, GOLD)
	_button(top, "MAPA", Rect2(984, 22, 100, 33), _return_to_map)
	bottom = _panel(Rect2(24, 565, 1104, 64))
	hp_label = _label(bottom, "", Rect2(16, 7, 140, 22), 16)
	phase_label = _label(bottom, "", Rect2(170, 7, 150, 22), 16, GOLD)
	status_label = _label(bottom, "", Rect2(322, 7, 738, 22), 16, MUTED)
	net_meter = ProgressBar.new()
	net_meter.position = Vector2(16, 42)
	net_meter.size = Vector2(262, 7)
	net_meter.max_value = 1.0
	net_meter.step = 0.0
	net_meter.show_percentage = false
	net_meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := StyleBoxFlat.new()
	fill.bg_color = GOLD
	fill.set_corner_radius_all(3)
	net_meter.add_theme_stylebox_override("fill", fill)
	var track := StyleBoxFlat.new()
	track.bg_color = Color("284c50")
	track.set_corner_radius_all(3)
	net_meter.add_theme_stylebox_override("background", track)
	bottom.add_child(net_meter)
	net_meter.size = Vector2(262, 7)
	_label(bottom, "WASD / SETAS · REMAR    MOUSE · MIRAR    CLIQUE / ESPAÇO · REDE    SEGURE E · RECOLHER    R · REINICIAR", Rect2(322, 35, 755, 23), 12)
	intro = _panel(Rect2(262, 169, 628, 306), true)
	_label(intro, "O RECIFE DO CANTO", Rect2(25, 18, 578, 45), 30, GOLD)
	var brief := "Uma sereia conhece a rota que Poseidon evita. Persiga-a pelos recifes e capture-a em até %d segundos, antes que seu canto tome o leme.\n\nMire com o mouse, lance a rede com clique ou Espaço e segure E para recolher a corda." % int(MODEL.LIMIT)
	if not gate_open:
		brief = "Ouça a profecia de Tirésias para liberar esta etapa no mapa."
	_label(intro, brief, Rect2(25, 73, 578, 164), 19, WHITE, true)
	_button(intro, "REMAR PARA O RECIFE" if gate_open else "VOLTAR AO MAPA", Rect2(25, 248, 578, 40), _begin if gate_open else _return_to_map)
	result = _panel(Rect2(294, 202, 564, 244), true)
	result_title = _label(result, "", Rect2(24, 19, 516, 42), 28, GOLD)
	result_text = _label(result, "", Rect2(24, 72, 516, 80), 19, WHITE, true)
	result_retry = _button(result, "TENTAR DE NOVO  ·  R", Rect2(24, 173, 246, 42), restart_checkpoint)
	result_next = _button(result, "SEGUIR PARA A GRUTA  ›", Rect2(24, 173, 246, 42), _continue_to_scylla)
	result_map = _button(result, "VOLTAR AO MAPA", Rect2(292, 173, 248, 42), _return_to_map)
	result.hide()
	final_dialogue = _panel(Rect2(144, 443, 864, 167), true)
	_label(final_dialogue, "SEREIA", Rect2(23, 13, 800, 29), 18, GOLD)
	_label(final_dialogue, "Poseidon evita a passagem entre aqueles paredões. É por ali que você encontra Cila.", Rect2(23, 47, 806, 55), 20, WHITE, true)
	_button(final_dialogue, "OLHAR A PASSAGEM  ›", Rect2(568, 117, 270, 33), _reveal_route)
	final_dialogue.hide()

func _setup_audio() -> void:
	music_was_paused = AudioManager.music_player.stream_paused
	AudioManager.music_player.stream_paused = true
	ambience = _loop_player("res://Assets/act7_sirens/cove_surf.wav", -12.0, &"SFX")
	song = _loop_player("res://Assets/act7_sirens/siren_call.wav", -65.0, &"Music")
	effects = AudioStreamPlayer.new()
	effects.bus = &"SFX"
	effects.volume_db = -14.0
	add_child(effects)

func _loop_player(path: String, volume: float, bus_name: StringName) -> AudioStreamPlayer:
	var stream: AudioStreamWAV = load(path).duplicate()
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = roundi(stream.get_length() * stream.mix_rate)
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = bus_name
	player.volume_db = volume
	add_child(player)
	player.play()
	return player

func _on_cue(kind: String, at: Vector2) -> void:
	stage.add_splash(kind, at)
	var notice := ""
	match kind:
		"false_target": notice = "A rede atravessou o reflexo. Procure o rastro na água."
		"escape": notice = "A sereia se soltou. Espere a próxima abertura."
		"break_free": notice = "Ela rompeu a rede. Siga o rastro de bolhas."
		"capture": message_time = 0.0
	if not notice.is_empty():
		message = notice
		message_time = 2.2
	if not is_instance_valid(effects):
		return
	match kind:
		"cast":
			effects.stream = preload("res://Assets/sfx_dash.wav")
			effects.pitch_scale = 1.23
		"window", "hook", "capture":
			effects.stream = preload("res://Assets/act5_circe/soft_chime.wav")
			effects.pitch_scale = 1.05 + encounter.leg * 0.10
		"break_free":
			effects.stream = preload("res://Assets/sfx_dash.wav")
			effects.pitch_scale = 0.75
		"hurt":
			effects.stream = preload("res://Assets/sfx_damage.wav")
			effects.pitch_scale = 0.82
		_:
			return
	effects.play()

func _exit_tree() -> void:
	for player in [ambience, song, effects]:
		if is_instance_valid(player):
			player.stop()
	if audio_enabled and is_instance_valid(AudioManager.music_player):
		AudioManager.music_player.stream_paused = music_was_paused
