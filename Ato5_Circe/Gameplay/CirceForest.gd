extends Control
const MODEL := preload("res://Ato5_Circe/Gameplay/CirceForestModel.gd")
const VISUALS := preload("res://Ato5_Circe/Gameplay/CirceForestStage.gd")
const ATTRIBUTES := preload("res://Code/PlayerAttributes.gd")
const DESIGN := Vector2(1152,648)
@export var audio_enabled := true
var model: MODEL
var visuals: VISUALS
var stage: Node2D
var objective_label: Label
var vitality_label: Label
var flower_label: Label
var attempt_label: Label
var focus_bar: ProgressBar
var message_panel: Panel
var message_label: Label
var failure_panel: Panel
var failure_label: Label
var result_panel: Panel
var message_time := 0.0
var footstep_distance := 0.0
var ambience: AudioStreamPlayer
var effects: AudioStreamPlayer
var previous_music_paused := false

func _ready() -> void:
	set_meta("hide_main_hud",true)
	GameManager.reset_encounter()
	MainHUD.set_station("Ato V - A flor de Hermes")
	if GameManager.act4_completed: GameManager.unlock_level(5)
	model = MODEL.new()
	model.apply_player_stats(ATTRIBUTES.capture(GameManager))
	# Resume an unfinished search. A completed chapter replays its full
	# challenge without erasing campaign inventory or permanent attributes.
	if GameManager.circe_moly_found and not GameManager.circe_search_completed:
		model.resume_with_flower()
	stage = Node2D.new()
	add_child(stage)
	visuals = VISUALS.new()
	visuals.model = model
	stage.add_child(visuals)
	_build_ui()
	model.feedback.connect(_feedback)
	model.cue.connect(_cue)
	model.flower_collected.connect(_on_flower_collected)
	model.completed.connect(_on_completed)
	model.failed.connect(_on_failed)
	GameManager.player_stats_changed.connect(_apply_stats)
	resized.connect(_fit)
	_fit()
	_setup_audio()
	_sync_hp()
	_feedback("Seus homens foram capturados. A voz de Hermes vem da floresta." if not model.has_flower else "A holimoli continua com você. Volte à entrada do palácio.")
	_update_ui()

func _fit() -> void:
	var factor: float = minf(size.x/DESIGN.x,size.y/DESIGN.y)
	stage.scale = Vector2.ONE * factor
	stage.position = (size-DESIGN*factor)*0.5

func _panel(at: Vector2, dimensions: Vector2, opacity := 0.90) -> Panel:
	var panel := Panel.new()
	panel.position = at
	panel.size = dimensions
	panel.z_index=20
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.024,0.055,0.049,opacity)
	style.border_color = Color(0.51,0.59,0.36,0.7)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel",style)
	stage.add_child(panel)
	return panel

func _label(value: String, at: Vector2, dimensions: Vector2, font_size: int, parent: Node = null) -> Label:
	var label := Label.new()
	label.text = value
	label.z_index=21
	label.position = at
	label.size = dimensions
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",Color(0.95,0.94,0.84))
	label.add_theme_color_override("font_shadow_color",Color(0.01,0.025,0.02))
	label.add_theme_constant_override("shadow_outline_size",3)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(stage if parent == null else parent).add_child(label)
	return label

func _button(value: String, at: Vector2, dimensions: Vector2, action: Callable, parent: Node = null) -> Button:
	var button := Button.new()
	button.text = value
	button.z_index=22
	button.position = at
	button.size = dimensions
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size",15)
	button.pressed.connect(action)
	(stage if parent == null else parent).add_child(button)
	return button

func _build_ui() -> void:
	_panel(Vector2(22,18),Vector2(1108,74),0.87)
	_label("CIRCE  /  A FLOR DE HERMES",Vector2(39,27),Vector2(265,25),18)
	vitality_label = _label("",Vector2(326,29),Vector2(105,23),13)
	attempt_label = _label("",Vector2(577,29),Vector2(110,23),13)
	flower_label = _label("",Vector2(706,29),Vector2(235,23),13)
	objective_label = _label("",Vector2(39,55),Vector2(910,26),18)
	_button("VOLTAR AO MAPA",Vector2(962,30),Vector2(151,33),return_to_map)
	focus_bar = ProgressBar.new()
	focus_bar.z_index=21
	focus_bar.position = Vector2(962,73)
	focus_bar.max_value = 1.0
	focus_bar.show_percentage = false
	focus_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var focus_track := StyleBoxFlat.new()
	focus_track.bg_color = Color(0.21,0.26,0.17)
	var focus_fill := StyleBoxFlat.new()
	focus_fill.bg_color = Color(0.90,0.82,0.56)
	focus_bar.add_theme_stylebox_override("background",focus_track)
	focus_bar.add_theme_stylebox_override("fill",focus_fill)
	focus_bar.size = Vector2(151,4)
	stage.add_child(focus_bar)
	message_panel = _panel(Vector2(218,103),Vector2(716,76),0.88)
	message_label = _label("",Vector2(17,10),Vector2(682,60),18,message_panel)
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	failure_panel = _panel(Vector2(306,223),Vector2(540,225),0.98)
	failure_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_label("O CAMINHO SE PERDEU",Vector2(24,20),Vector2(490,35),25,failure_panel)
	failure_label = _label("",Vector2(24,70),Vector2(490,78),19,failure_panel)
	failure_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_button("RETOMAR",Vector2(24,166),Vector2(300,37),retry,failure_panel)
	_button("MAPA",Vector2(342,166),Vector2(174,37),return_to_map,failure_panel)
	failure_panel.hide()
	result_panel = _panel(Vector2(271,197),Vector2(610,254),0.98)
	result_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_label("ÀS PORTAS DE CIRCE",Vector2(26,23),Vector2(558,35),28,result_panel)
	var result_text := _label("A holimoli repele a magia da feiticeira.\nSeus homens continuam prisioneiros.\nOdisseu está pronto para enfrentar Circe.",Vector2(26,80),Vector2(558,100),20,result_panel)
	result_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_button("ENFRENTAR CIRCE",Vector2(26,198),Vector2(350,37),enter_circe_battle,result_panel)
	_button("MAPA",Vector2(390,198),Vector2(194,37),return_to_map,result_panel)
	result_panel.hide()

func _physics_process(delta: float) -> void:
	if model == null: return
	var axis := _movement_axis()
	model.set_input(axis,Input.is_physical_key_pressed(KEY_SPACE),Input.is_physical_key_pressed(KEY_E),Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN))
	var before_hp: int = model.hp
	model.tick(delta)
	if before_hp != model.hp: _sync_hp()
	visuals.update_visuals(delta)
	if model.grounded and absf(model.velocity.x)>80:
		footstep_distance += absf(model.velocity.x)*delta
		if footstep_distance>92:
			footstep_distance=0
			_cue("step")
	message_time = maxf(0,message_time-delta)
	message_panel.visible = message_time>0 and model.phase not in [MODEL.Phase.COMPLETE,MODEL.Phase.FAILED]
	_update_ui()

func _unhandled_input(event: InputEvent) -> void:
	if model == null or not event.is_pressed() or event.is_echo(): return
	if event is InputEventKey:
		if model.phase==MODEL.Phase.COMPLETE and event.keycode==KEY_ENTER: return_to_map()
		elif model.phase==MODEL.Phase.FAILED and event.keycode in [KEY_R,KEY_ENTER,KEY_SPACE]: retry()
		elif event.keycode==KEY_R: restart_checkpoint()
		elif event.keycode==KEY_SPACE: model.request_jump()
		elif event.keycode==KEY_Q: model.request_dash(_movement_axis())
		elif event.keycode==KEY_E: model.interact()
	elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_RIGHT:
		model.request_dash(_movement_axis())

func _movement_axis() -> float:
	return float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT))-float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT))

func _apply_stats() -> void:
	model.apply_player_stats(ATTRIBUTES.capture(GameManager))
	_sync_hp()
	_update_ui()

func _sync_hp() -> void:
	GameManager.player_current_hp = model.hp
	GameManager.player_health_changed.emit(model.hp)

func _feedback(message: String) -> void:
	message_label.text = message
	message_time = 7.0
	message_panel.show()

func _update_ui() -> void:
	var prompt := model.prompt()
	objective_label.text = model.objective() if prompt.is_empty() else prompt
	attempt_label.text="TENTATIVA %02d" % (model.retries+1)
	vitality_label.text = "VIDA  %d / %d" % [model.hp,model.max_hp]
	flower_label.text = "HOLIMOLI  ·  PROTEÇÃO ATIVA" if model.has_flower else ""
	focus_bar.value = model.focus
	focus_bar.visible = model.focus>0.01
	if model.focus_remaining>0 and model.focus<0.05 and not model.has_flower:
		flower_label.text="MEMÓRIA DA ROTA  ·  %.1f s" % model.focus_remaining

func _on_flower_collected() -> void:
	GameManager.collect_circe_moly()

func _on_completed() -> void:
	GameManager.complete_circe_search()
	message_panel.hide()
	result_panel.show()

func _on_failed(reason: String) -> void:
	failure_label.text = reason
	failure_panel.show()
	message_panel.hide()

func retry() -> void:
	model.retry()
	message_time=0
	message_panel.hide()
	failure_panel.hide()
	_sync_hp()
	visuals.reset_camera()
	_update_ui()

func restart_checkpoint() -> void:
	if model.phase==MODEL.Phase.COMPLETE: return
	if model.phase!=MODEL.Phase.FAILED: model._fail("Nova tentativa.")
	retry()

func return_to_map() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Scenes/WorldMap.tscn")

func enter_circe_battle() -> void:
	if GameManager.circe_search_completed:
		get_tree().change_scene_to_file("res://Ato5_Circe/Gameplay/CirceBattle.tscn")

func _setup_audio() -> void:
	if not audio_enabled: return
	previous_music_paused = AudioManager.music_player.stream_paused
	AudioManager.music_player.stream_paused = true
	ambience = AudioStreamPlayer.new()
	ambience.stream = preload("res://Assets/act5_circe/forest_ambience.wav")
	ambience.bus = "SFX" if AudioServer.get_bus_index("SFX")>=0 else "Master"
	ambience.volume_db = -12
	add_child(ambience)
	ambience.finished.connect(ambience.play)
	ambience.play()
	effects = AudioStreamPlayer.new()
	effects.bus = ambience.bus
	add_child(effects)

func _cue(kind: String) -> void:
	if not audio_enabled or not is_instance_valid(effects): return
	if kind=="step" and effects.playing: return
	var path := "res://Assets/act5_circe/soft_chime.wav" if kind in ["flower","hermes","checkpoint","trick"] else "res://Assets/sfx_dash.wav" if kind=="dash" else "res://Assets/sfx_damage.wav" if kind=="hurt" else "res://Assets/act5_circe/forest_step.wav" if kind in ["step","crack"] else ""
	if path.is_empty() or not ResourceLoader.exists(path): return
	effects.stream = load(path)
	effects.pitch_scale=0.55 if kind=="crack" else 0.72 if kind=="trick" else 1.0
	effects.volume_db = -12 if kind in ["flower","hermes","checkpoint"] else -18
	effects.play()

func _exit_tree() -> void:
	if audio_enabled and is_instance_valid(AudioManager.music_player):
		AudioManager.music_player.stream_paused = previous_music_paused
