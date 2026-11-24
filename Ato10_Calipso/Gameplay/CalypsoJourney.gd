extends Control

const PATHS := preload("res://Ato10_Calipso/Gameplay/OgygiaPaths.gd")
const RAFT := preload("res://Ato10_Calipso/Gameplay/RaftLaunch.gd")
const STAGE := preload("res://Ato10_Calipso/Gameplay/OgygiaStage.gd")
const ATTRIBUTES := preload("res://Code/PlayerAttributes.gd")
const VIEW := Vector2(1152, 648)
const MAP := "res://Scenes/WorldMap.tscn"
const DEPARTURE := "res://Ato10_Calipso/Gameplay/CalypsoDeparture.tscn"
const CHARYBDIS := "res://Ato11_Caribdis/Gameplay/Charybdis.tscn"
const GOLD := Color("f6d798")
const INK := Color("e5f0ec")
const RETURN_SECONDS := 6.1

# Shot, speaker, original dialogue.
const ARRIVAL := [
	["wake", "ODISSEU", "O último trovão... Euríloco? Tem alguém aí?"],
	["welcome", "CALIPSO", "Só encontrei você, na areia. Sou Calipso. Pode ficar comigo em Ogígia."],
	["welcome", "ODISSEU", "Penélope e Telêmaco estão me esperando. Preciso voltar para Ítaca."],
	["refusal", "CALIPSO", "Já esperou tempo demais por essa volta. Aqui eu posso te dar uma vida inteira."],
	["refusal", "ODISSEU", "A vida que eu quero está com eles. Vou embora assim que conseguir andar."],
	["refusal", "CALIPSO", "Sou a deusa desta ilha. Enquanto eu quiser que fique, o mar vai trazer você de volta."],
]
const TELL_CALYPSO := [
	["plan", "ODISSEU", "Preparei um remo. Vou tentar passar pelos recifes. Queria que você soubesse por mim."],
	["plan", "CALIPSO", "Eu estarei na praia quando voltar."],
	["plan", "ODISSEU", "É isso que você ainda não entendeu. Eu não estou fazendo uma viagem de volta para esta ilha."],
]
const RETURN_SHORE := [
	["return", "CALIPSO", "Eu disse que esperaria você na praia. Encontrei o remo quando a espuma baixou."],
	["return", "ODISSEU", "Passei dos recifes. Remei até que a costa sumisse. Como você ainda podia me ver?"],
	["return", "CALIPSO", "Eu guardei o remo. Pensei que você fosse querer tentar de novo."],
]
const RETURN_HOME := [
	["bench_return", "CALIPSO", "Deixei o seu remo na mesa. A corrente o trouxe antes de você."],
	["bench_return", "ODISSEU", "Eu saí além dos recifes. Eu vi a ilha desaparecer."],
	["bench_return", "CALIPSO", "Eu sei. Daqui eu ainda podia ver você."],
]
const APPEAL := [
	["cliff", "CALIPSO", "Há sete anos eu tirei você desse mar. Odisseu... venha para perto de mim."],
	["cliff_memory", "ODISSEU", "Às vezes é Euríloco. Às vezes é minha mãe. Eu fecho os olhos e estamos todos lá de novo."],
	["cliff_call", "ODISSEU", "Atena... Eu não sei quanto tempo ainda consigo ficar aqui. Por favor, me ouça."],
	["olympus", "ATENA", "Eu ouvi Odisseu de Ogígia. Pai, o filho dele passou anos esperando por uma resposta."],
	["olympus", "ZEUS", "Quer que o Olimpo intervenha? Então convença o conselho a libertá-lo."],
	["olympus", "APOLO", "Ouvi o que ele fez às sereias. Ainda assim, reconheço que o canto delas ameaçava a tripulação."],
	["olympus", "HEFESTO", "A tripulação confiou nele. O que fará se alguém confiar nele outra vez?"],
	["olympus", "AFRODITE", "E quando a mãe dele esperou até o último dia?"],
	["olympus", "ARES", "O capitão deixou o próprio navio cair. Por que dar outra chance a ele?"],
	["olympus", "ATENA", "Eu vi o filho dele enfrentar homens maiores do que ele. Quero que Odisseu esteja lá quando Telêmaco chamar."],
	["olympus", "HERA", "Entre a promessa de Calipso e a vida que tinha em Ítaca, ele continuou escolhendo Penélope. Tem meu voto."],
	["olympus_judgment", "ZEUS", "Você reuniu os votos. Ainda quer desafiar a minha decisão, Atena?"],
	["olympus_judgment", "ATENA", "Por favor, pai. Deixe que ele volte para casa."],
	["olympus_release", "ZEUS", "Que Hermes leve a ordem a Ogígia. Calipso terá de deixá-lo partir."],
]
const FAREWELL := [
	["farewell", "CALIPSO", "Hermes trouxe a ordem de Zeus. Deixei um remo novo na praia. O seu ficou na bancada."],
	["farewell", "CALIPSO", "Eu queria que você escolhesse ficar. Passei sete anos ouvindo sua resposta e fingindo que ia mudar."],
	["farewell", "ODISSEU", "Você me tirou do mar. Eu vou lembrar disso. O que eu quero agora é ver Penélope de novo."],
	["farewell", "CALIPSO", "Eu sei. Deixei água junto da madeira. Vai precisar dela na travessia."],
]
const MESSENGER := [
	["hermes", "HERMES", "Você já passou a arrebentação. Agora guarde forças para o estreito."],
	["hermes", "ODISSEU", "Caríbdis."],
	["hermes", "HERMES", "Quando a água começar a girar, procure a corrente que corre por fora."],
	["hermes", "HERMES", "E leve a bolsa de ventos com você. Guarde-a fechada enquanto puder."],
]

enum Mode { LOCKED, STORY, WALK, ESCAPE, RETURN_CURRENT, SAIL, DONE }

@export_enum("Cativeiro", "Jangada") var episode := 0
@export var audio_enabled := true
var paths := PATHS.new()
var raft := RAFT.new()
var stage: STAGE
var mode := Mode.LOCKED
var frame: Node2D
var hud: Control
var heading: Label
var progress: Label
var help: Label
var controls: Label
var note: Label
var shore_ui: Control
var cove_button: Button
var open_button: Button
var story: Control
var scene_label: Label
var speaker: Label
var line: Label
var advance_button: Button
var result: Panel
var result_title: Label
var result_text: Label
var departure_button: Button
var return_age := 0.0
var note_time := 0.0
var beats: Array = []
var beat := 0
var story_age := 0.0
var final_story := false
var ambience: AudioStreamPlayer
var effects: AudioStreamPlayer
var wood_rustle: AudioStreamPlayer
var music_was_paused := false

func _ready() -> void:
	set_meta("hide_main_hud", true)
	MainHUD.set_station("Ato X - Ogígia")
	frame = Node2D.new()
	add_child(frame)
	stage = STAGE.new()
	stage.paths = paths
	stage.raft = raft
	frame.add_child(stage)
	_build_ui()
	paths.escape_requested.connect(_start_escape)
	paths.conversation_requested.connect(_island_conversation)
	paths.completed.connect(_summit)
	paths.years_elapsed.connect(_record_years)
	paths.thought.connect(_message)
	raft.notice.connect(_message)
	raft.reached_sea.connect(_at_sea)
	raft.grounded.connect(_splash)
	GameManager.player_stats_changed.connect(_apply_stats)
	_apply_stats()
	resized.connect(_fit)
	_fit()
	if audio_enabled and DisplayServer.get_name() != "headless":
		_setup_audio()
	var unlocked := GameManager.ogygia_paths_completed if episode == 1 else GameManager.mutiny_completed
	if (unlocked or GameManager.standalone_stage_preview) and episode == 0:
		GameManager.begin_calypso_stay()
	if unlocked or GameManager.standalone_stage_preview:
		_open_story(FAREWELL if episode == 1 else ARRIVAL, false)
	else:
		stage.shot = "wake" if episode == 0 else "farewell"
		_set_mode(Mode.LOCKED)
		result_title.text = "OGÍGIA AINDA ESTÁ DISTANTE"
		result_text.text = "A partida estará disponível quando Atena conseguir libertar Odisseu." if episode == 1 else "Conclua o Motim para abrir a chegada a Ogígia."

func _fit() -> void:
	var factor := minf(size.x / VIEW.x, size.y / VIEW.y)
	frame.scale = Vector2.ONE * factor
	frame.position = (size - VIEW * factor) * 0.5

func _axes() -> Vector2:
	var left := Input.is_action_pressed("ui_left") or Input.is_physical_key_pressed(KEY_A)
	var right := Input.is_action_pressed("ui_right") or Input.is_physical_key_pressed(KEY_D)
	var up := Input.is_action_pressed("ui_up") or Input.is_physical_key_pressed(KEY_W)
	var down := Input.is_action_pressed("ui_down") or Input.is_physical_key_pressed(KEY_S)
	return Vector2(float(right) - float(left), float(down) - float(up))

func _physics_process(delta: float) -> void:
	if mode == Mode.WALK:
		paths.tick(delta, _axes(), Input.is_physical_key_pressed(KEY_E))
		_update_hud()
	elif mode in [Mode.ESCAPE, Mode.SAIL]:
		var axes := _axes()
		raft.tick(delta, axes.x, -axes.y, mode == Mode.SAIL and Input.is_physical_key_pressed(KEY_E))
		_update_hud()

func _process(delta: float) -> void:
	stage.update_view(delta, mode == Mode.WALK and Input.is_physical_key_pressed(KEY_E))
	if mode == Mode.RETURN_CURRENT:
		return_age += delta
		stage.return_age = return_age
		if return_age >= RETURN_SECONDS:
			paths.return_from_sea()
			_set_mode(Mode.WALK)
			_update_hud()
	if mode == Mode.STORY:
		story_age += delta
		advance_button.disabled = story_age < 0.65
		if story_age >= 5.5 and beat + 1 < beats.size():
			advance_story()
	if note_time > 0.0:
		note_time = maxf(0.0, note_time - delta)
		note.visible = note_time > 0.0
	if is_instance_valid(ambience):
		var volume := -24.0
		if mode == Mode.WALK and paths.place == PATHS.Place.BENCH:
			volume = -34.0 + 4.0 * sin(paths.seasons * 2.3)
		elif mode in [Mode.ESCAPE, Mode.SAIL]:
			volume = lerpf(-24.0, -12.0, raft.tide())
		elif mode == Mode.RETURN_CURRENT:
			volume = lerpf(-31.0, -15.0, smoothstep(2.9, 5.0, return_age))
		elif mode == Mode.STORY and stage.shot == "cliff_memory":
			volume = -38.0
		ambience.volume_db = move_toward(ambience.volume_db, volume, delta * 22.0)
		var working := mode == Mode.WALK and paths.can_work() and (Input.is_physical_key_pressed(KEY_E) or paths.time_cut > 0.0)
		wood_rustle.volume_db = move_toward(wood_rustle.volume_db, -23.0 if working else -50.0, delta * 100.0)
		if working and not wood_rustle.playing:
			wood_rustle.pitch_scale = lerpf(1.12, 0.79, paths.seasons / 7.0)
			wood_rustle.play()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and mode == Mode.STORY:
		advance_story()
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
	if mode == Mode.STORY and key in [KEY_ENTER, KEY_SPACE]:
		advance_story()
	elif key == KEY_R:
		restart_checkpoint()
	elif mode == Mode.WALK:
		if key == KEY_E: paths.interact()
	elif mode == Mode.SAIL and raft.phase == RAFT.Phase.SHORE:
		if key == KEY_1: raft.choose_beach(RAFT.COVE)
		elif key == KEY_2: raft.choose_beach(RAFT.OPEN)
		elif key in [KEY_E, KEY_SPACE]: raft.launch()

func _open_story(sequence: Array, is_final: bool) -> void:
	beats = sequence
	beat = 0
	final_story = is_final
	_set_mode(Mode.STORY)
	_show_beat()

func _show_beat() -> void:
	story_age = 0.0
	var scene: Array = beats[beat]
	if beat == 0 or stage.shot != scene[0]:
		stage.shot_age = 0.0
	stage.shot = scene[0]
	var location := "OGÍGIA"
	if scene[0].begins_with("olympus"): location = "OLIMPO"
	elif scene[0] == "hermes": location = "MAR ABERTO"
	elif scene[0].begins_with("cliff"): location = "A BORDA DA FALÉSIA"
	elif scene[0] == "bench_return": location = "A CASA DE CALIPSO"
	scene_label.text = "CALIPSO  /  " + location
	speaker.text = scene[1]
	line.text = scene[2]
	advance_button.text = "CONTINUAR  ›"
	if beat == beats.size() - 1 and not final_story:
		advance_button.text = "PREPARAR A JANGADA  ›" if episode == 1 else "VOLTAR  ›" if paths.in_conversation else "IR À PRAIA  ›"
	advance_button.disabled = true

func advance_story() -> void:
	if mode != Mode.STORY or advance_button.disabled:
		return
	if beat + 1 < beats.size():
		beat += 1
		_show_beat()
	elif final_story:
		_complete()
	elif episode == 0:
		if paths.in_conversation:
			paths.finish_conversation()
		_set_mode(Mode.WALK)
		_update_hud()
	else:
		_set_mode(Mode.SAIL)
		_update_hud()

func _set_mode(next: Mode) -> void:
	mode = next
	match mode:
		Mode.WALK: stage.mode = "walk"
		Mode.ESCAPE, Mode.SAIL: stage.mode = "raft"
		Mode.RETURN_CURRENT: stage.mode = "return_current"
		_: stage.mode = "story"
	hud.visible = mode in [Mode.WALK, Mode.ESCAPE, Mode.SAIL]
	if mode != Mode.SAIL:
		shore_ui.hide()
	story.visible = mode == Mode.STORY
	result.visible = mode in [Mode.LOCKED, Mode.DONE]
	departure_button.visible = mode == Mode.DONE

func _island_conversation(key: String) -> void:
	match key:
		"plan": _open_story(TELL_CALYPSO, false)
		"return_shore": _open_story(RETURN_SHORE, false)
		"return_home": _open_story(RETURN_HOME, false)

func _start_escape(route: int) -> void:
	raft.begin_escape(route)
	note.hide()
	note_time = 0.0
	_set_mode(Mode.ESCAPE)
	_update_hud()

func _record_years(total: int) -> void:
	if episode == 0:
		GameManager.record_calypso_years(total)

func _summit() -> void:
	_open_story(APPEAL, true)

func _at_sea() -> void:
	if mode == Mode.ESCAPE:
		return_age = 0.0
		stage.return_age = 0.0
		_set_mode(Mode.RETURN_CURRENT)
		return
	_play_chime(0.95)
	_open_story(MESSENGER, true)

func _splash() -> void:
	_play_chime(0.53)
	if mode == Mode.ESCAPE:
		paths.retry_escape()
		_set_mode(Mode.WALK)
		_update_hud()

func _complete() -> void:
	if GameManager.standalone_stage_preview and episode == 0:
		GameManager.record_calypso_years(7)
	if not GameManager.standalone_stage_preview:
		if episode == 0: GameManager.complete_ogygia_paths()
		else: GameManager.complete_calypso()
	_set_mode(Mode.DONE)
	result_title.text = "O OLIMPO RESPONDEU" if episode == 0 else "OGÍGIA FICOU PARA TRÁS"
	result_text.text = "Atena conseguiu a autorização. É hora de preparar a jangada." if episode == 0 else "A jangada alcançou o mar aberto. Odisseu segue sozinho para o estreito de Caríbdis."

func restart_checkpoint() -> void:
	if mode == Mode.ESCAPE:
		raft.retry()
		paths.retry_escape()
		_set_mode(Mode.WALK)
		_update_hud()
	elif mode == Mode.SAIL:
		raft.retry()
		_message("De volta à areia. As amarras continuam firmes.")

func _apply_stats() -> void:
	var stats := ATTRIBUTES.capture(GameManager)
	paths.apply_player_stats(stats)
	raft.apply_stats(stats)

func _update_hud() -> void:
	# A simulation step can open a cutscene before the HUD refreshes.
	if mode not in [Mode.WALK, Mode.ESCAPE, Mode.SAIL]:
		return
	shore_ui.visible = mode == Mode.SAIL and raft.phase == RAFT.Phase.SHORE
	if mode == Mode.WALK:
		var action := paths.nearby_action()
		progress.text = ""
		controls.text = "WASD OU SETAS · ANDAR    E · INTERAGIR    ESC · PAUSA"
		help.text = "E · " + paths.action_label(action) if action != PATHS.Action.NONE else ""
		var at := paths.action_position(action) - Vector2(0, 107)
		if paths.place == PATHS.Place.BENCH:
			at = PATHS.BENCH_ACTION_AT
			if paths.can_work():
				var work := "TALHAR O REMO" if paths.beat == PATHS.Beat.CARVE else "ENROLAR O PANO NO CABO"
				help.text = "SEGURE E · " + work if paths.work < 0.06 else ""
			controls.text = "SEGURE E · TRABALHAR O REMO    ESC · PAUSA" if paths.can_work() else "E · INTERAGIR    ESC · PAUSA"
		help.position = Vector2(clampf(at.x - help.size.x * 0.5, 24.0, VIEW.x - help.size.x - 24.0), at.y)
	elif mode == Mode.ESCAPE:
		progress.text = ""
		help.text = ""
		controls.text = "A/D · LEME    W/S · REMAR OU FREAR    R · VOLTAR À PRAIA    ESC · PAUSA"
	elif raft.phase == RAFT.Phase.SHORE:
		heading.text = RAFT.NAMES[raft.beach]
		progress.text = "AMARRAS FIRMES" if raft.lash >= 1.0 else "AMARRAS SOLTAS"
		cove_button.modulate = GOLD if raft.beach == RAFT.COVE else Color.WHITE
		open_button.modulate = GOLD if raft.beach == RAFT.OPEN else Color.WHITE
		help.text = ""
		controls.text = "1/2 · PRAIA    A/D · VIRAR    SEGURE E · AMARRAR    PRESSIONE E · LANÇAR    R · RETOMAR    ESC · PAUSA"
	else:
		heading.text = RAFT.NAMES[raft.beach]
		progress.text = "MAR ABERTO   %d%%" % roundi(clampf(raft.distance / RAFT.FINISH, 0, 1) * 100)
		help.text = ""
		controls.text = "A/D · LEME    W/S · IMPULSIONAR OU FREAR    R · VOLTAR À PRAIA    ESC · PAUSA"
		if note.visible:
			note.hide()
			note_time = 0.0

func _message(text: String) -> void:
	note.text = text
	note.show()
	note_time = 4.5

func _to_map() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(MAP)

func _to_departure() -> void:
	if mode == Mode.DONE:
		get_tree().change_scene_to_file(DEPARTURE if episode == 0 else CHARYBDIS)

func _layer() -> Control:
	var layer := Control.new()
	layer.size = VIEW
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(layer)
	return layer

func _panel(parent: Node, bounds: Rect2) -> Panel:
	var panel := Panel.new()
	panel.position = bounds.position
	panel.size = bounds.size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.027, 0.061, 0.071, 0.94)
	style.border_color = Color("7c9a89")
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	return panel

func _label(parent: Node, text: String, bounds: Rect2, font_size: int, tint := INK, wrap := false) -> Label:
	var label := Label.new()
	if wrap:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.position = bounds.position
	label.size = bounds.size
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", tint)
	label.text = text
	parent.add_child(label)
	return label

func _button(parent: Node, text: String, bounds: Rect2, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.position = bounds.position
	button.size = bounds.size
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _build_ui() -> void:
	hud = _layer()
	var top := _panel(hud, Rect2(24, 16, 1104, 54 if episode == 0 else 76))
	_label(top, "OGÍGIA  /  "+("OS SETE ANOS" if episode == 0 else "A ÚLTIMA MARÉ"), Rect2(18, 10 if episode == 0 else 7, 655, 31), 23, GOLD)
	if episode == 1:
		heading = _label(top, "", Rect2(19, 44, 611, 24), 16)
	progress = _label(top, "", Rect2(708, 15 if episode == 0 else 25, 240, 24), 17, GOLD)
	_button(top, "MAPA", Rect2(975, 11 if episode == 0 else 24, 109, 32), _to_map)
	var bottom := _panel(hud, Rect2(24, 607, 1104, 28))
	help = _label(hud, "", Rect2(376, 572, 400, 28), 17, GOLD)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.add_theme_color_override("font_shadow_color", Color("092024"))
	help.add_theme_constant_override("shadow_outline_size", 7)
	controls = _label(bottom, "", Rect2(17, 4, 1060, 20), 13)
	note = _label(hud, "", Rect2(123, 102, 907, 45), 17, GOLD, true)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_color_override("font_shadow_color", Color("102c30"))
	note.add_theme_constant_override("shadow_outline_size", 6)
	shore_ui = _layer()
	cove_button = _button(shore_ui, "1 · ENSEADA PROTEGIDA", Rect2(245, 497, 314, 40), func(): raft.choose_beach(RAFT.COVE))
	open_button = _button(shore_ui, "2 · PRAIA ABERTA", Rect2(584, 497, 322, 40), func(): raft.choose_beach(RAFT.OPEN))
	shore_ui.hide()
	story = _layer()
	var story_header := _panel(story, Rect2(0, 0, 1152, 40))
	scene_label = _label(story_header, "", Rect2(29, 7, 906, 24), 17, GOLD)
	var subtitles := _panel(story, Rect2(69, 473, 1014, 103))
	speaker = _label(subtitles, "", Rect2(22, 11, 968, 25), 17, GOLD)
	line = _label(subtitles, "", Rect2(22, 42, 968, 50), 22, INK, true)
	advance_button = _button(story, "CONTINUAR  ›", Rect2(831, 588, 252, 38), advance_story)
	result = _panel(frame, Rect2(282, 206, 588, 234))
	result_title = _label(result, "", Rect2(23, 19, 542, 40), 27, GOLD, true)
	result_text = _label(result, "", Rect2(24, 78, 539, 75), 19, INK, true)
	var next_label := "SEGUIR PARA A PRAIA  ›" if episode == 0 else "SEGUIR PARA CARÍBDIS  ›"
	departure_button = _button(result, next_label, Rect2(24, 170, 253, 41), _to_departure)
	_button(result, "VOLTAR AO MAPA", Rect2(307, 170, 257, 41), _to_map)

func _setup_audio() -> void:
	music_was_paused = AudioManager.music_player.stream_paused
	AudioManager.music_player.stream_paused = true
	ambience = AudioStreamPlayer.new()
	var surf: AudioStreamWAV = preload("res://Assets/act7_sirens/cove_surf.wav").duplicate()
	surf.loop_mode = AudioStreamWAV.LOOP_FORWARD
	surf.loop_end = roundi(surf.get_length() * surf.mix_rate)
	ambience.stream = surf
	ambience.bus = &"SFX"
	ambience.volume_db = -24.0
	add_child(ambience)
	ambience.play()
	effects = AudioStreamPlayer.new()
	effects.stream = preload("res://Assets/act5_circe/soft_chime.wav")
	effects.bus = &"SFX"
	effects.volume_db = -17.0
	add_child(effects)
	wood_rustle = AudioStreamPlayer.new()
	wood_rustle.stream = _bench_sound()
	wood_rustle.bus = &"SFX"
	wood_rustle.volume_db = -50.0
	add_child(wood_rustle)

func _bench_sound() -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var sample_count := roundi(stream.mix_rate * 0.54)
	var sound := PackedByteArray()
	sound.resize(sample_count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 91
	var roughness := 0.0
	for index in sample_count:
		var time := float(index) / stream.mix_rate
		var pulse := (smoothstep(0.012, 0.065, time) - smoothstep(0.155, 0.32, time))
		roughness = lerpf(roughness, rng.randf_range(-1.0, 1.0), 0.29)
		var grit := roughness * (0.55 + 0.45 * sin(time * 308.0)) + sin(time * TAU * 137.0) * 0.062
		sound.encode_s16(index * 2, roundi(grit * pulse * 17700.0))
	stream.data = sound
	return stream

func _play_chime(pitch: float) -> void:
	if is_instance_valid(effects):
		effects.pitch_scale = pitch
		effects.play()

func _exit_tree() -> void:
	if is_instance_valid(ambience):
		ambience.stop()
		if is_instance_valid(AudioManager.music_player):
			AudioManager.music_player.stream_paused = music_was_paused
	if is_instance_valid(effects): effects.stop()
