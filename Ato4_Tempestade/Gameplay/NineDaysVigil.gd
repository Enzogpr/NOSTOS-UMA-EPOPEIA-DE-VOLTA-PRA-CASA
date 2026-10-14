extends Control
signal vigilance_completed(record: Dictionary)
signal vigilance_failed(reason: String)
const MODEL := preload("res://Ato4_Tempestade/Gameplay/VigilModel.gd")
const VISUALS := preload("res://Ato4_Tempestade/Gameplay/VigilStage.gd")
const SOUND := preload("res://Ato4_Tempestade/Gameplay/VigilAudio.gd")
const DESIGN_SIZE := Vector2(1152,648)
const RECORD_FILE := "user://vigil_record.json"
const THOUGHTS_FILE := "res://Ato4_Tempestade/Cutscenes/VigilThoughts.dialogue.json"
@export var day_duration: float = 25.0
@export var random_seed: int = 0
@export var persist_record: bool = true
@export var audio_enabled: bool = true
@export var autoplay_thoughts: bool = true
@onready var stage: Control = $Stage
var model: MODEL
var visuals: VISUALS
var sounds: SOUND
var day_label: Label
var day_bar: ProgressBar
var sleep_bar: ProgressBar
var sleep_label: Label
var wake_label: Label
var left_label: Label
var right_label: Label
var message_label: Label
var phase_label: Label
var status_label: Label
var day_dots: Array[Label] = []
var gameplay_panels: Array[Panel] = []
var intro: Panel
var result_panel: Panel
var result_title: Label
var result_subtitle: Label
var result_detail: Label
var thought_panel: Panel
var thought_speaker_label: Label
var thought_text: RichTextLabel
var thought_next: Button
var thought_auto: Button
var thoughts: Array = []
var thought_index: int = -1
var thought_type_clock: float = 0.0
var thought_hold_clock: float = 0.0
var thought_cooldown: float = 0.0
var wake_button: Button
var warn_button: Button
var day_shade: ColorRect
var day_card: Label
var message_time: float = 0.0
var exiting: bool = false
var completion_count: int = 0
var ready_delay: float = 0.35

func _ready() -> void:
	set_meta("hide_main_hud",true)
	GameManager.combat_mode = false
	MainHUD.set_station("Ato 4 - Nove dias de vigília")
	model = MODEL.new(random_seed)
	model.day_duration = maxf(day_duration,0.25)
	model.feedback.connect(_feedback)
	model.day_started.connect(_day_started)
	model.ending_started.connect(_ending_started)
	model.failed.connect(_failed)
	model.completed.connect(_completed)
	thoughts = JSON.parse_string(FileAccess.get_file_as_string(THOUGHTS_FILE))
	visuals = VISUALS.new()
	visuals.model = model
	stage.add_child(visuals)
	sounds = SOUND.new()
	sounds.enabled = audio_enabled
	sounds.model = model
	add_child(sounds)
	_build_interface()
	resized.connect(_fit_stage)
	_fit_stage()
	_update_interface()

func _fit_stage() -> void:
	var factor: float = minf(size.x/DESIGN_SIZE.x,size.y/DESIGN_SIZE.y)
	stage.scale = Vector2.ONE*factor
	stage.position = (size-DESIGN_SIZE*factor)*0.5

func _panel(at: Vector2, dimensions: Vector2, parent: Node = null) -> Panel:
	var panel := Panel.new()
	panel.position = at
	panel.size = dimensions
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025,0.065,0.10,0.94)
	style.border_color = Color(0.71,0.63,0.40,0.8)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel",style)
	(stage if parent == null else parent).add_child(panel)
	return panel

func _label(text: String, at: Vector2, dimensions: Vector2, font_size: int = 20, parent: Node = null) -> Label:
	var label := Label.new()
	label.text = text
	label.position = at
	label.size = dimensions
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",Color(0.96,0.94,0.87))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(stage if parent == null else parent).add_child(label)
	return label

func _button(text: String, at: Vector2, dimensions: Vector2, action: Callable, parent: Node = null) -> Button:
	var button := Button.new()
	button.text = text
	button.position = at
	button.size = dimensions
	button.add_theme_font_size_override("font_size",17)
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(action)
	(stage if parent == null else parent).add_child(button)
	return button

func _bar(at: Vector2, dimensions: Vector2, color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.position = at
	bar.size = dimensions
	bar.show_percentage = false
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.13,0.21,0.25)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	bar.add_theme_stylebox_override("background",background)
	bar.add_theme_stylebox_override("fill",fill)
	stage.add_child(bar)
	return bar

func _build_interface() -> void:
	gameplay_panels.append(_panel(Vector2(20,16),Vector2(770,96)))
	day_label = _label("DIA 1 / 9",Vector2(38,27),Vector2(170,30),25)
	phase_label = _label("AMANHECER",Vector2(213,31),Vector2(180,24),16)
	status_label = _label("",Vector2(402,31),Vector2(365,26),17)
	day_bar = _bar(Vector2(38,69),Vector2(373,8),Color(0.83,0.75,0.47))
	for index in 9:
		var dot := _label(str(index+1),Vector2(432+index*36,67),Vector2(30,30),18)
		dot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		day_dots.append(dot)
	_button("VOLTAR AO MAPA",Vector2(930,22),Vector2(202,38),return_to_map)
	gameplay_panels.append(_panel(Vector2(20,518),Vector2(1112,112)))
	sleep_label = _label("SONOLÊNCIA",Vector2(38,530),Vector2(330,26),18)
	sleep_bar = _bar(Vector2(38,566),Vector2(305,13),Color(0.78,0.65,0.40))
	wake_label = _label("Espere os olhos pesarem",Vector2(38,590),Vector2(355,24),16)
	left_label = _label("",Vector2(390,530),Vector2(220,26),18)
	right_label = _label("",Vector2(637,530),Vector2(220,26),18)
	_button("◀  A / ←",Vector2(390,568),Vector2(102,35),func(): model.look(-1))
	_button("D / →  ▶",Vector2(502,568),Vector2(102,35),func(): model.look(1))
	warn_button = _button("E · AFASTAR",Vector2(621,568),Vector2(164,35),func(): model.warn_crew())
	wake_button = _button("ESPAÇO · DESPERTAR",Vector2(808,568),Vector2(303,35),func(): model.wake())
	message_label = _label("",Vector2(50,467),Vector2(1052,43),20)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.add_theme_color_override("font_shadow_color",Color(0,0,0,0.95))
	message_label.add_theme_constant_override("shadow_offset_x",2)
	message_label.add_theme_constant_override("shadow_offset_y",2)
	day_shade = ColorRect.new()
	day_shade.position = Vector2(0,112)
	day_shade.size = Vector2(1152,398)
	day_shade.color = Color(0.025,0.06,0.09,0.6)
	day_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(day_shade)
	day_card = _label("",Vector2(166,246),Vector2(820,108),34,day_shade)
	day_card.position = Vector2(166,134)
	day_card.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intro = _panel(Vector2(225,155),Vector2(702,334))
	_label("NOVE DIAS DE VIGÍLIA",Vector2(26,20),Vector2(650,43),31,intro)
	_label("Odisseu prometeu manter a bolsa fechada.",Vector2(26,73),Vector2(650,28),21,intro)
	_label("ESPAÇO  ·  Desperte quando ficar sonolento.\nA / D ou ← / →  ·  Olhe para os lados.\nE  ·  Afaste tripulantes apenas enquanto estiver alerta.",Vector2(26,121),Vector2(650,112),20,intro)
	_label("100% de sono ou alguém na bolsa: derrota.\nNove dias de 25 segundos. Esc: pausa.",Vector2(26,233),Vector2(650,42),17,intro)
	_button("COMEÇAR A VIGÍLIA  ›",Vector2(190,277),Vector2(322,41),begin,intro)
	result_panel = _panel(Vector2(208,155),Vector2(736,337))
	result_panel.name = "Result"
	result_title = _label("",Vector2(25,18),Vector2(685,42),29,result_panel)
	result_subtitle = _label("",Vector2(25,69),Vector2(685,30),21,result_panel)
	var record_label := _label("",Vector2(25,118),Vector2(685,106),22,result_panel)
	record_label.name = "Record"
	result_detail = _label("",Vector2(25,238),Vector2(685,25),17,result_panel)
	_button("TENTAR NOVAMENTE",Vector2(25,283),Vector2(320,38),replay,result_panel)
	_button("VOLTAR AO MAPA",Vector2(389,283),Vector2(320,38),return_to_map,result_panel)
	result_panel.hide()
	day_shade.hide()
	_build_thought_interface()

func _build_thought_interface() -> void:
	thought_panel = _panel(Vector2(32,457),Vector2(1088,171))
	thought_panel.name = "Thoughts"
	thought_speaker_label = _label("",Vector2(20,10),Vector2(1000,30),23,thought_panel)
	thought_text = RichTextLabel.new()
	thought_text.position = Vector2(20,49)
	thought_text.size = Vector2(1048,76)
	thought_text.scroll_active = false
	thought_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	thought_text.add_theme_font_size_override("normal_font_size",25)
	thought_panel.add_child(thought_text)
	thought_auto = _button("AUTO: SIM  [A]",Vector2(20,132),Vector2(160,30),_toggle_thought_auto,thought_panel)
	thought_next = _button("MOSTRAR FALA  ›",Vector2(828,132),Vector2(240,30),_advance_thought_requested,thought_panel)
	_label("ESPAÇO / ENTER / CLIQUE  ·  ESC: PAUSA",Vector2(204,136),Vector2(610,24),14,thought_panel)
	thought_panel.hide()

func begin() -> void:
	if ready_delay > 0.0 or model.state != MODEL.State.READY:
		return
	intro.hide()
	model.start()

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.is_echo():
		return
	var code: int = event.keycode
	if code == KEY_ESCAPE:
		return
	if model.state == MODEL.State.READY and code in [KEY_ENTER,KEY_SPACE]:
		begin()
	elif model.state == MODEL.State.PLAYING:
		match code:
			KEY_A,KEY_LEFT: model.look(-1)
			KEY_D,KEY_RIGHT: model.look(1)
			KEY_SPACE: model.wake()
			KEY_E: model.warn_crew()
	elif model.state == MODEL.State.ENDING:
		if code in [KEY_SPACE,KEY_ENTER]: _advance_thought_requested()
		elif code == KEY_A: _toggle_thought_auto()
	if code in [KEY_ENTER,KEY_SPACE,KEY_A,KEY_D,KEY_LEFT,KEY_RIGHT,KEY_E]:
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if model == null:
		return
	ready_delay = maxf(0.0,ready_delay-delta)
	message_time = maxf(0.0,message_time-delta)
	model.tick(delta)
	_update_interface()
	if model.state == MODEL.State.ENDING:
		_process_thoughts(delta)

func _feedback(text: String, kind: String) -> void:
	if message_label == null:
		return
	message_label.text = text
	message_time = 2.4
	message_label.add_theme_color_override("font_color",Color(1.0,0.70,0.50) if kind == "miss" else Color(0.86,0.96,1.0))
	if sounds != null:
		sounds.feedback(text,kind)

func _day_started(day: int) -> void:
	var hints := ["","Ventos favoráveis. Guarde a bolsa.","A curiosidade cresce no convés.","O boato do tesouro começa a circular.","Olhe para os dois lados.","A saudade começa a parecer real.","O sono pesa mais a cada noite.","Cada passo exige atenção.","A costa aparece ao longe.","Ítaca. Tão perto de casa."]
	_feedback(hints[day],"notice")

func _update_interface() -> void:
	day_label.text = "DIA %d / 9" % model.day
	day_bar.value = model.day_progress()*100.0
	var progress: float = model.day_progress()
	phase_label.text = "AMANHECER" if progress < 0.22 else "TARDE" if progress < 0.48 else "NOITE" if progress < 0.90 else "ALVORECER"
	status_label.text = "Aproximações impedidas: %d" % model.prevented
	sleep_bar.value = model.fatigue
	var ready: bool = model.fatigue >= MODEL.WAKE_START and model.state == MODEL.State.PLAYING
	var color := Color(0.38,0.84,0.77) if ready else Color(0.78,0.65,0.40)
	if model.fatigue > MODEL.WAKE_END:
		color = Color(0.96,0.40,0.29)
	(sleep_bar.get_theme_stylebox("fill") as StyleBoxFlat).bg_color = color
	sleep_label.text = "SONOLÊNCIA  %d%%" % int(model.fatigue)
	wake_label.text = "ESPAÇO · DESPERTE AGORA" if ready else "Espere os olhos pesarem"
	wake_label.add_theme_color_override("font_color",color)
	wake_button.disabled = model.state != MODEL.State.PLAYING or model.wake_cooldown > 0.0
	warn_button.disabled = model.state != MODEL.State.PLAYING or model.shout_cooldown > 0.0 or model.is_sleepy()
	warn_button.text = "E · BLOQUEADO" if model.is_sleepy() else "E · AFASTAR"
	left_label.text = "◀ ESQUERDA" + (" · VIGIANDO" if model.look_side < 0 else "")
	right_label.text = "DIREITA ▶" + (" · VIGIANDO" if model.look_side > 0 else "")
	for side in [-1,1]:
		var label: Label = left_label if side < 0 else right_label
		var danger: bool = false
		for visitor in model.crew:
			danger = danger or (int(visitor.side) == side and not visitor.retreating and float(visitor.progress) > 0.18)
		label.add_theme_color_override("font_color",Color(1.0,0.67,0.35) if danger else Color(0.74,0.82,0.89))
	for index in 9:
		day_dots[index].add_theme_color_override("font_color",Color(0.52,0.86,0.72) if model.perfect_days.has(index+1) else Color(1.0,0.82,0.44) if index+1 == model.day else Color(0.48,0.56,0.65))
	message_label.visible = message_time > 0.0
	day_shade.visible = model.state == MODEL.State.DAY_BREAK
	if day_shade.visible:
		day_shade.modulate.a = sin(clampf(model.break_clock/1.65,0.0,1.0)*PI)
		day_card.text = "DIA %d\nMais uma noite protegendo a bolsa." % (model.day+1)
	if model.state in [MODEL.State.ENDING,MODEL.State.COMPLETE,MODEL.State.FAILED]:
		message_label.hide()

func _ending_started() -> void:
	message_time = 0.0
	_hide_gameplay()
	thought_panel.show()
	_show_thought(0)

func _hide_gameplay() -> void:
	for control in [day_label,phase_label,status_label,day_bar,sleep_bar,sleep_label,wake_label,left_label,right_label,wake_button,warn_button]:
		control.hide()
	for dot in day_dots:
		dot.hide()
	for panel in gameplay_panels:
		panel.hide()
	for child in stage.get_children():
		if child is Button and child not in [wake_button,warn_button] and child.position.y >= 560:
			child.hide()

func _show_thought(index: int) -> void:
	thought_index = index
	thought_type_clock = 0.0
	thought_hold_clock = 0.0
	thought_cooldown = 0.25
	var beat: Dictionary = thoughts[index]
	thought_text.text = str(beat.text)
	thought_text.visible_characters = 0
	thought_speaker_label.text = str(beat.speaker).to_upper()
	thought_speaker_label.add_theme_color_override("font_color",Color(0.74,0.89,1.0) if beat.speaker == "Penélope" else Color(1.0,0.80,0.56))
	visuals.thought_speaker = str(beat.speaker)
	thought_auto.text = "AUTO: SIM  [A]" if autoplay_thoughts else "AUTO: NÃO  [A]"
	if index == 4:
		model.ending_alarm()
		if sounds != null: sounds.feedback("","alarm")

func _process_thoughts(delta: float) -> void:
	thought_cooldown = maxf(0.0,thought_cooldown-delta)
	thought_type_clock += delta
	var count: int = thought_text.get_total_character_count()
	thought_text.visible_characters = mini(count,int(thought_type_clock*38.0))
	visuals.speaking = thought_text.visible_characters < count
	thought_next.text = "MOSTRAR FALA  ›" if visuals.speaking else "CONTINUAR  ›"
	if not visuals.speaking:
		thought_hold_clock += delta
		if autoplay_thoughts and thought_hold_clock >= float(thoughts[thought_index].hold)+count/70.0:
			_next_thought()

func _advance_thought_requested() -> void:
	if model.state != MODEL.State.ENDING or thought_cooldown > 0.0: return
	thought_cooldown = 0.22
	if thought_text.visible_characters < thought_text.get_total_character_count():
		thought_type_clock = 1000.0
		thought_text.visible_characters = thought_text.get_total_character_count()
	else: _next_thought()

func _next_thought() -> void:
	if thought_index+1 < thoughts.size(): _show_thought(thought_index+1)
	else: model.finish_thoughts()

func _toggle_thought_auto() -> void:
	autoplay_thoughts = not autoplay_thoughts
	thought_auto.text = "AUTO: SIM  [A]" if autoplay_thoughts else "AUTO: NÃO  [A]"

func _failed(reason: String) -> void:
	_hide_gameplay()
	result_title.text = "VIGÍLIA INTERROMPIDA"
	result_subtitle.text = "Odisseu adormeceu." if reason == "sono" else "Alguém alcançou a bolsa."
	result_detail.text = "A tentativa terminou. Tente proteger a bolsa novamente."
	_present_record(model.record())
	if sounds != null: sounds.feedback("","miss")
	vigilance_failed.emit(reason)

func _completed(record: Dictionary) -> void:
	completion_count += 1
	thought_panel.hide()
	visuals.speaking = false
	result_title.text = "UM AVISO NA ESCURIDÃO"
	result_subtitle.text = "Acorda, Odisseu!"
	result_detail.text = "Eles estão abrindo a bolsa."
	_present_record(record)
	vigilance_completed.emit(record)

func _present_record(record: Dictionary) -> void:
	result_panel.show()
	result_panel.get_node("Record").text = "Aproximações impedidas: %d\nDespertares a tempo: %d\nDias concluídos: %d / 8" % [record.prevented,record.successful_wakes,record.days_completed]
	message_label.hide()
	if persist_record:
		_save_record(record)

func _save_record(record: Dictionary) -> void:
	var best: Dictionary = {}
	if FileAccess.file_exists(RECORD_FILE):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(RECORD_FILE))
		if parsed is Dictionary:
			best = parsed
	best.last_run = record
	best.best_prevented = maxi(int(best.get("best_prevented",0)),int(record.prevented))
	best.best_perfect_days = maxi(mini(8,int(best.get("best_perfect_days",0))),record.perfect_days.size())
	var file := FileAccess.open(RECORD_FILE,FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(best))

func replay() -> void:
	if not exiting:
		exiting = true
		get_tree().reload_current_scene()

func return_to_map() -> void:
	if not exiting:
		exiting = true
		get_tree().change_scene_to_file("res://Scenes/WorldMap.tscn")
