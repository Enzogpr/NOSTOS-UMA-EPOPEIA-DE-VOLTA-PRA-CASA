extends Control
signal escaped(record: Dictionary)
const MODEL := preload("res://Ato4_Tempestade/Gameplay/PoseidonEscapeModel.gd")
const VISUALS := preload("res://Ato4_Tempestade/Gameplay/PoseidonEscapeStage.gd")
const RUPTURE := preload("res://Ato4_Tempestade/Gameplay/PoseidonRuptureModel.gd")
const RUPTURE_STAGE := preload("res://Ato4_Tempestade/Gameplay/PoseidonRuptureStage.gd")
const ENCOUNTER_AUDIO := preload("res://Ato4_Tempestade/Gameplay/PoseidonEncounterAudio.gd")
const DESIGN := Vector2(1152,648)
const RECORD_FILE := "user://poseidon_escape_record.json"
@export var proof_enabled: bool = true
@export var legacy_start_boat: int = 0
@export var audio_enabled: bool = true
@export var persist_record: bool = true
@export var random_seed: int = 614
@onready var stage: Control = $Stage
var model: MODEL
var visuals: VISUALS
var failure_panel: Panel
var failure_detail: Label
var controls_hint: Label
var arrival_shade: ColorRect
var intro: Panel
var result: Panel
var objective_label: Label
var fleet_label: Label
var prompt_label: Label
var notice_label: Label
var balance_label: Label
var action_label: Label
var result_detail: Label
var balance_bar: ProgressBar
var action_bar: ProgressBar
var dash_label: Label
var warning_label: Label
var notice_time: float = 0.0
var ready_delay: float = 0.3
var held_interact: bool = false
var jump_requested: bool = false
var allow_input: bool = true
var handoff_record: Dictionary = {}
var complete_count: int = 0
var ambience: AudioStreamPlayer
var effects: AudioStreamPlayer
var wind: AudioStreamPlayer
var previous_music_volume: float = 0.0
var music_ducked: bool = false
var sound_clock: float = 0.0
var previous_combat: bool = false
var encounter_audio: Node
var legacy_continue: Button
var combat_handed_off := false
var transferring := false

func _ready() -> void:
	set_meta("hide_main_hud",true)
	previous_combat = GameManager.combat_mode
	GameManager.combat_mode = false
	MainHUD.set_station("Ato 4 - Fuga de Poseidon")
	model = RUPTURE.new(random_seed) if proof_enabled else MODEL.new(random_seed)
	model.feedback.connect(_feedback)
	model.impact.connect(_impact)
	model.completed.connect(_completed)
	model.failed.connect(_failed)
	visuals = RUPTURE_STAGE.new() if proof_enabled else VISUALS.new()
	visuals.model = model
	stage.add_child(visuals)
	_build_interface()
	_setup_audio()
	if proof_enabled:
		model.encounter_cue.connect(_encounter_cue)
	resized.connect(_fit)
	_fit()
	_update_interface()

func _fit() -> void:
	var factor: float = minf(size.x/DESIGN.x,size.y/DESIGN.y)
	stage.scale = Vector2.ONE*factor
	stage.position = (size-DESIGN*factor)*0.5

func _panel(at: Vector2, dimensions: Vector2, opacity: float = 0.91) -> Panel:
	var panel := Panel.new()
	panel.position = at
	panel.size = dimensions
	panel.z_index = 30
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.018,0.045,0.065,opacity)
	style.border_color = Color(0.53,0.65,0.64,0.8)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel",style)
	stage.add_child(panel)
	return panel

func _label(text: String, at: Vector2, dimensions: Vector2, font_size: int = 20, parent: Node = null) -> Label:
	var label := Label.new()
	label.text = text
	label.position = at
	label.size = dimensions
	label.z_index = 31
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",Color(0.94,0.95,0.90))
	label.add_theme_color_override("font_shadow_color",Color(0.01,0.02,0.03,0.9))
	label.add_theme_constant_override("shadow_offset_x",1)
	label.add_theme_constant_override("shadow_offset_y",2)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(stage if parent == null else parent).add_child(label)
	return label

func _button(text: String, at: Vector2, dimensions: Vector2, action: Callable, parent: Node = null) -> Button:
	var button := Button.new()
	button.text = text
	button.position = at
	button.size = dimensions
	button.z_index = 31
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size",16)
	button.pressed.connect(action)
	(stage if parent == null else parent).add_child(button)
	return button

func _bar(at: Vector2, dimensions: Vector2, color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.position = at
	bar.size = dimensions
	bar.z_index = 31
	bar.show_percentage = false
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0.12,0.21,0.25)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	for style in [back,fill]:
		style.content_margin_top = 0
		style.content_margin_bottom = 0
	bar.add_theme_stylebox_override("background",back)
	bar.add_theme_stylebox_override("fill",fill)
	bar.add_theme_font_size_override("font_size",1)
	stage.add_child(bar)
	bar.set_deferred("size",dimensions)
	return bar

func _build_interface() -> void:
	_panel(Vector2(18,14),Vector2(890,73))
	_label("POSEIDON  /  MAR EM RUPTURA" if proof_enabled else "POSEIDON  /  O ÚLTIMO NAVIO",Vector2(35,23),Vector2(580,23),17)
	objective_label = _label("",Vector2(35,51),Vector2(685,29),18 if proof_enabled else 22)
	fleet_label = _label("",Vector2(728,28),Vector2(162,45),18)
	fleet_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_button("VOLTAR AO MAPA",Vector2(938,22),Vector2(195,39),return_to_map)
	warning_label = _label("",Vector2(140,203),Vector2(872,30),21)
	warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warning_label.add_theme_color_override("font_color",Color(1,0.79,0.39))
	notice_label = _label("",Vector2(130,157),Vector2(892,40),17)
	notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prompt_label = _label("",Vector2(130,554),Vector2(892,30),19)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.add_theme_color_override("font_color",Color(1.0,0.88,0.51))
	_panel(Vector2(18,593),Vector2(1115,45))
	balance_label = _label("EQUILÍBRIO",Vector2(31,598),Vector2(137,18),13)
	balance_bar = _bar(Vector2(31,621),Vector2(137,7),Color(0.77,0.71,0.44))
	controls_hint = _label("",Vector2(190,607),Vector2(780,23),14)
	dash_label = _label("",Vector2(968,599),Vector2(148,27),14)
	dash_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	action_label = _label("",Vector2(315,111),Vector2(522,23),15)
	action_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	action_bar = _bar(Vector2(408,138),Vector2(336,5),Color(0.44,0.87,0.82))
	intro = _panel(Vector2(222,181),Vector2(708,331),0.97)
	intro.z_index = 40
	_label("MAR EM RUPTURA · TRECHO DE PROVA" if proof_enabled else "ENTRE A FROTA E O DEUS",Vector2(28,20),Vector2(650,42),26 if proof_enabled else 31,intro)
	_label("A destruição vai mudar o caminho.\nVocê mantém o controle durante os acontecimentos." if proof_enabled else "Dez barcos separam você da sua embarcação.\nA bolsa dos ventos está lá. Poseidon vem atrás.",Vector2(28,73),Vector2(650,52),20,intro)
	_label("A / D ou ← / → · Correr e frear. S / ↓ · Abaixar.\nESPAÇO · Pular; segure para ir mais alto.\nLeia a ruptura, recue e use o mastro como passagem.\nDepois atravesse os destroços antes da parede de água." if proof_enabled else "A / D ou ← / → · Correr. S / ↓ · Abaixar.\nESPAÇO · Pular; segure para ir mais alto. E · Interagir.\nUse barcos e destroços. Recue quando precisar.\nNo seu navio: alcance as amarras e recupere a bolsa.",Vector2(28,135),Vector2(650,100),18,intro)
	_label("Se cair ou ficar sem fôlego, retome o ponto seguro.",Vector2(28,239),Vector2(650,24),18,intro)
	_button("INICIAR TRECHO  ›" if proof_enabled else "ATRAVESSAR A FROTA  ›",Vector2(28,278),Vector2(350,37),begin,intro)
	if proof_enabled: _button("FASE ANTERIOR",Vector2(400,278),Vector2(280,37),func(): _continue_legacy(0),intro)
	result = _panel(Vector2(233,182),Vector2(686,322),0.98)
	result.z_index = 40
	_label("UM INSTANTE DE ABRIGO" if proof_enabled else "UM ÚNICO NAVIO ESCAPOU",Vector2(28,25),Vector2(630,42),29,result)
	_label("O caminho ficou para trás. A frota ainda está adiante." if proof_enabled else "Poseidon destruiu a frota. Os ventos abriram a saída.",Vector2(28,83),Vector2(630,28),20,result)
	result_detail = _label("",Vector2(28,135),Vector2(630,95),21,result)
	_button("REPETIR TRECHO" if proof_enabled else "REPETIR A FUGA",Vector2(28,261),Vector2(290,39),replay,result)
	legacy_continue = _button("CONTINUAR TRAVESSIA" if proof_enabled else "VOLTAR AO MAPA",Vector2(366,261),Vector2(290,39),func(): _continue_legacy(3) if proof_enabled else return_to_map(),result)
	result.hide()
	failure_panel = _panel(Vector2(246,190),Vector2(660,301),0.98)
	failure_panel.z_index = 40
	_label("FUGA INTERROMPIDA",Vector2(28,25),Vector2(610,42),30,failure_panel)
	failure_detail = _label("",Vector2(28,88),Vector2(610,100),21,failure_panel)
	failure_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label("Retome o último barco seguro ou o desafio final.",Vector2(28,196),Vector2(610,29),18,failure_panel)
	_button("RETOMAR TRECHO  [ENTER]",Vector2(28,245),Vector2(300,38),retry_checkpoint,failure_panel)
	_button("VOLTAR AO MAPA",Vector2(366,245),Vector2(266,38),return_to_map,failure_panel)
	failure_panel.hide()
	arrival_shade = ColorRect.new()
	arrival_shade.size = DESIGN
	arrival_shade.z_index = 28
	arrival_shade.color = Color(0.01,0.04,0.06,0)
	arrival_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(arrival_shade)

func begin() -> void:
	if ready_delay > 0.0 or model.phase != MODEL.Phase.READY: return
	intro.hide()
	model.start()
	if not proof_enabled and legacy_start_boat > 0:
		var index: int = clampi(legacy_start_boat,0,9)
		model.position = model.boats[index].rect.position+Vector2(65,0)
		for i in index:
			model.boats[i].entered = 0.0
			model._sink(i)
		model._enter_boat(index)
		model._save_checkpoint()
		visuals.reset_camera()

func _unhandled_key_input(event: InputEvent) -> void:
	if not allow_input or not event is InputEventKey or not event.pressed or event.is_echo(): return
	var code: int = event.keycode if event.keycode != 0 else event.physical_keycode
	if code == KEY_ESCAPE: return
	if model.phase == MODEL.Phase.READY and code in [KEY_SPACE,KEY_ENTER]:
		begin()
	elif model.phase == MODEL.Phase.FAILED and code == KEY_ENTER:
		retry_checkpoint()
	elif model.active() and code == KEY_SPACE:
		jump_requested = true
	if code in [KEY_SPACE,KEY_ENTER,KEY_E]: get_viewport().set_input_as_handled()

func _pressed(code: Key) -> bool:
	return Input.is_physical_key_pressed(code) or Input.is_key_pressed(code)

func _physics_process(delta: float) -> void:
	if model == null: return
	ready_delay = maxf(0.0,ready_delay-delta)
	notice_time = maxf(0.0,notice_time-delta)
	sound_clock = maxf(0.0,sound_clock-delta)
	var horizontal := 0.0
	var duck := false
	var jump_held := false
	var interaction: bool = held_interact
	if allow_input:
		horizontal = float(_pressed(KEY_D) or _pressed(KEY_RIGHT))-float(_pressed(KEY_A) or _pressed(KEY_LEFT))
		duck = _pressed(KEY_S) or _pressed(KEY_DOWN)
		jump_held = _pressed(KEY_SPACE)
		interaction = interaction or _pressed(KEY_E)
	model.tick(delta,horizontal,duck,jump_requested,jump_held,interaction)
	jump_requested = false
	_update_interface()
	if proof_enabled and is_instance_valid(encounter_audio):
		encounter_audio.update_state(model.tension,model.quiet,model.velocity.x,model.grounded)
	if audio_enabled and is_instance_valid(wind):
		var escaping_now: bool = model.phase == MODEL.Phase.ESCAPING
		wind.volume_db = move_toward(wind.volume_db,-11.0 if escaping_now else -38.0,delta*16)
		if escaping_now and not wind.playing: wind.play()

func _update_interface() -> void:
	if proof_enabled:
		_update_proof_interface()
		return
	objective_label.text = model.objective()
	fleet_label.text = "FROTA\n%d / 12 NAVIOS" % model.fleet_remaining()
	balance_bar.value = model.balance
	balance_label.text = "FÔLEGO  %d%%" % int(model.balance)
	var playable: bool = model.phase not in [MODEL.Phase.ESCAPING,MODEL.Phase.COMPLETE]
	balance_bar.visible = playable
	balance_label.visible = playable
	dash_label.visible = playable
	dash_label.text = "ABAIXADO" if model.crouching else "NO AR" if not model.grounded else "EM APOIO"
	controls_hint.text = "A / D · CORRER     S / ↓ · ABAIXAR     ESPAÇO · PULAR (SEGURE: MAIS ALTO)     E · INTERAGIR"
	prompt_label.text = model.prompt() if model.active() else ""
	notice_label.visible = notice_time > 0 and model.active()
	warning_label.text = ""
	for hazard in model.hazards:
		if hazard.age >= hazard.warning: continue
		warning_label.text = {"low":"ONDA BAIXA · PULE", "high":"RAJADA ALTA · ABAIXE", "slam":"IMPACTO DE CIMA · SAIA DA MARCA"}.get(hazard.kind,"")
	arrival_shade.color.a = 0
	action_bar.visible = model.active()
	action_label.visible = model.active()
	if model.phase == MODEL.Phase.TRAVERSAL:
		action_bar.value = clampf((model.max_x-145)/(model.final_origin-145)*100,0,100)
		action_label.text = "SEU NAVIO ESTÁ À FRENTE  ›"
	elif model.phase == MODEL.Phase.FINAL_SHIP:
		action_bar.value = model.wind_progress*100 if model.has_bag else (model.bindings[0]+model.bindings[1]+model.bindings[2])/3.0*100
		action_label.text = "VOLTE À POPA COM A BOLSA" if model.has_bag else "SUBA NOS APOIOS · SOLTE AS TRÊS AMARRAS"
	else:
		action_bar.hide()
		action_label.hide()
	if not model.active():
		notice_label.hide()
		warning_label.text = ""

func _failed(reason: String) -> void:
	failure_detail.text = reason
	failure_panel.show()

func retry_checkpoint() -> void:
	if model.phase != MODEL.Phase.FAILED: return
	jump_requested = false
	held_interact = false
	model.retry_checkpoint()
	failure_panel.hide()
	visuals.reset_camera()
	notice_time = 0
	_update_interface()

func _feedback(text: String, kind: String) -> void:
	if proof_enabled:
		notice_label.text = text
		notice_time = 3.0
		return
	if not text.is_empty():
		notice_label.text = text
		notice_time = 3.8
	if kind == "bag": _tone(520)
	elif kind == "guard": _tone(190)
	elif kind == "warning": _tone(310)

func _setup_audio() -> void:
	if proof_enabled:
		encounter_audio = ENCOUNTER_AUDIO.new()
		add_child(encounter_audio)
		encounter_audio.setup(audio_enabled)
		return
	if not audio_enabled: return
	previous_music_volume = AudioManager.music_player.volume_db
	music_ducked = AudioManager.music_player.playing
	if music_ducked: AudioManager.music_player.volume_db = previous_music_volume-13
	ambience = _player(preload("res://Assets/act4_storm/storm_loop.wav"),-24)
	ambience.play()
	effects = _player(null,-16)
	wind = _player(preload("res://Assets/act4_storm/storm_loop.wav"),-38)

func _player(stream: AudioStream, volume: float) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = &"SFX"
	player.volume_db = volume
	add_child(player)
	return player

func _tone(frequency: float) -> void:
	if not audio_enabled or effects == null or sound_clock > 0: return
	var tone := AudioStreamWAV.new()
	tone.format = AudioStreamWAV.FORMAT_16_BITS
	tone.mix_rate = 22050
	var data := PackedByteArray()
	data.resize(2800*2)
	for i in 2800:
		var t: float = float(i)/22050
		data.encode_s16(i*2,int(sin(t*TAU*frequency)*exp(-t*30)*2200))
	tone.data = data
	effects.stream = tone
	effects.volume_db = -17
	effects.play()
	sound_clock = 0.15

func _impact(_kind: String) -> void:
	if proof_enabled:
		_encounter_cue("splash")
		return
	if not audio_enabled or effects == null: return
	effects.stream = preload("res://Assets/act4_storm/thunder.wav")
	effects.volume_db = -18
	effects.play()
	sound_clock = 0.7

func _completed(record: Dictionary) -> void:
	if complete_count > 0: return
	complete_count += 1
	if proof_enabled:
		result_detail.text = "Trecho de prova atravessado.\n%.1f s · %d saltos · %d retomadas\nA fase completa permanece na versão anterior." % [record.seconds,record.jumps,record.retries]
		result.show()
		return
	if persist_record:
		var file := FileAccess.open(RECORD_FILE,FileAccess.WRITE)
		if file: file.store_string(JSON.stringify(record))
	result_detail.text = "11 navios perdidos  ·  1 navio sobrevivente\n10 barcos atravessados  ·  bolsa recuperada\n%.1f s  ·  %d impactos  ·  %d retomadas" % [record.seconds,record.hits,record.retries]
	result.show()
	stop_audio()
	escaped.emit(record)

func stop_audio() -> void:
	if is_instance_valid(encounter_audio): encounter_audio.stop_audio()
	for player in [ambience,effects,wind]:
		if is_instance_valid(player):
			player.stop()
			player.stream = null

func release_music() -> void:
	if music_ducked and is_instance_valid(AudioManager): AudioManager.music_player.volume_db = previous_music_volume
	music_ducked = false

func replay() -> void:
	_replace_scene(proof_enabled,legacy_start_boat)

func return_to_map() -> void:
	stop_audio()
	release_music()
	get_tree().change_scene_to_file("res://Scenes/WorldMap.tscn")

func _exit_tree() -> void:
	stop_audio()
	release_music()
	if not combat_handed_off: GameManager.combat_mode = previous_combat

func _encounter_cue(kind: String) -> void:
	if is_instance_valid(encounter_audio): encounter_audio.cue(kind)

func _update_proof_interface() -> void:
	objective_label.text = model.objective()
	fleet_label.text = "TRECHO DE PROVA"
	fleet_label.add_theme_font_size_override("font_size",14)
	balance_bar.value = model.balance
	balance_label.text = "FÔLEGO  %d%%" % int(model.balance)
	controls_hint.text = "A / D · CORRER     S / ↓ · ABAIXAR     ESPAÇO · PULAR (SEGURE: MAIS ALTO)     ESC · PAUSA"
	dash_label.text = "ABAIXADO" if model.crouching else "NO AR" if not model.grounded else "EM APOIO"
	prompt_label.text = model.prompt() if model.active() else ""
	warning_label.hide()
	action_label.hide()
	action_bar.hide()
	notice_label.hide()
	arrival_shade.color.a = 0
	if model.phase == MODEL.Phase.COMPLETE:
		prompt_label.text = ""
		balance_bar.hide()
		balance_label.hide()
		dash_label.hide()

func _continue_legacy(index: int) -> void:
	_replace_scene(false,index,proof_enabled and model.phase == MODEL.Phase.COMPLETE)

func _replace_scene(next_proof: bool, index: int, include_proof_record: bool = false) -> void:
	if transferring: return
	transferring = true
	stop_audio()
	release_music()
	var next: Control = load("res://Ato4_Tempestade/Gameplay/PoseidonEscape.tscn").instantiate()
	next.proof_enabled = next_proof
	next.legacy_start_boat = index
	next.audio_enabled = audio_enabled
	next.persist_record = persist_record
	next.random_seed = random_seed
	next.allow_input = allow_input
	next.handoff_record = handoff_record.duplicate(true)
	if include_proof_record: next.handoff_record["rupture_proof"] = model.record()
	next.previous_combat = previous_combat
	get_tree().root.add_child(next)
	next.previous_combat = previous_combat
	combat_handed_off = true
	get_tree().current_scene = next
	queue_free()
