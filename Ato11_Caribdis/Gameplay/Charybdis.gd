extends Control

const RUN := preload("res://Ato11_Caribdis/Gameplay/CharybdisRun.gd")
const SEA := preload("res://Ato11_Caribdis/Gameplay/CharybdisSea.gd")
const MAP := "res://Scenes/WorldMap.tscn"
const FINAL_POSEIDON := "res://Ato12_Poseidon/Gameplay/FinalPoseidon.tscn"
const GOLD := Color("f6d798")
const INK := Color("e5f0ec")

@export var audio_enabled := true
var run := RUN.new()
var frame := Node2D.new()
var sea := SEA.new()
var status: Label
var timer: Label
var hull: Label
var fill: ColorRect
var dialog: Panel
var title: Label
var detail: Label
var action: Button
var current_audio: AudioStreamPlayer
var impact_audio: AudioStreamPlayer
var music_was_paused := false
var locked := false

func _ready() -> void:
	set_meta("hide_main_hud", true)
	MainHUD.set_station("Ato XI - Caríbdis")
	add_child(frame)
	sea.run = run
	frame.add_child(sea)
	_build_ui()
	resized.connect(_fit)
	_fit()
	locked = not (GameManager.calypso_completed or GameManager.standalone_stage_preview)
	GameManager.player_stats_changed.connect(_apply_stats)
	_apply_stats()
	if audio_enabled and DisplayServer.get_name() != "headless":
		_setup_audio()
	run.struck.connect(_impact)
	_refresh()

func _apply_stats() -> void:
	run.set_agility(maxf(0.3, GameManager.player_speed_mult))

func _fit() -> void:
	var factor := minf(size.x / SEA.VIEW.x, size.y / SEA.VIEW.y)
	frame.scale = Vector2.ONE * factor
	frame.position = (size - SEA.VIEW * factor) * 0.5

func _physics_process(delta: float) -> void:
	var previous := run.phase
	run.tick(delta)
	if previous != RUN.Phase.DONE and run.phase == RUN.Phase.DONE:
		if not GameManager.standalone_stage_preview:
			GameManager.complete_charybdis()
	if previous != run.phase or run.phase == RUN.Phase.ORBIT:
		_refresh()

func _process(delta: float) -> void:
	sea.advance(delta)
	if is_instance_valid(current_audio):
		current_audio.volume_db = lerpf(-33.0, -10.0, run.power())
		current_audio.pitch_scale = lerpf(0.78, 1.17, run.power())

func _unhandled_key_input(event: InputEvent) -> void:
	if not event.pressed or event.echo:
		return
	var key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
	if key in [KEY_A, KEY_LEFT]:
		run.steer(-1)
	elif key in [KEY_D, KEY_RIGHT]:
		run.steer(1)
	elif key in [KEY_ENTER, KEY_SPACE] and run.phase in [RUN.Phase.READY, RUN.Phase.LOST]:
		restart_checkpoint()
	elif key == KEY_R and run.phase != RUN.Phase.DONE:
		restart_checkpoint()

func restart_checkpoint() -> void:
	if locked:
		return
	run.start()
	_refresh()

func _refresh() -> void:
	timer.text = "%02d s" % ceili(RUN.LIMIT - run.time)
	hull.text = "JANGADA  %d / %d" % [run.hull, RUN.MAX_HULL]
	hull.modulate = Color("f2a189") if run.hull <= 1 else Color.WHITE
	fill.size.x = 321.0 * run.time / RUN.LIMIT
	dialog.visible = run.phase in [RUN.Phase.READY, RUN.Phase.LOST, RUN.Phase.DONE]
	action.visible = not locked
	match run.phase:
		RUN.Phase.READY:
			status.text = "A corrente já pegou a jangada."
			title.text = "O REDOMOINHO À FRENTE" if not locked else "CARÍBDIS AINDA ESTÁ DISTANTE"
			detail.text = "Deixe a corrente levar a jangada. Mude de faixa quando a água borbulhar à frente e aguente até o monstro perder a força." if not locked else "Conclua a partida de Ogígia para liberar esta travessia."
			action.text = "ENTRAR NA CORRENTE"
		RUN.Phase.ORBIT:
			if run.time < 15.0: status.text = "A corrente se fecha"
			elif run.time < 34.0: status.text = "Caríbdis arrasta os destroços"
			else: status.text = "Últimas investidas"
		RUN.Phase.RELEASE:
			status.text = "Caríbdis perdeu a força. A corrente está soltando a jangada."
		RUN.Phase.LOST:
			status.text = "A jangada se partiu"
			title.text = "ENGOLIDO PELA CORRENTE"
			detail.text = "Você resistiu por %.1f segundos. Observe onde a água se levanta antes de mudar de faixa." % run.time
			action.text = "TENTAR DE NOVO"
		RUN.Phase.DONE:
			status.text = "A corrente cedeu"
			title.text = "CARÍBDIS FICOU PARA TRÁS"
			detail.text = "O mar voltou a correr para fora. Odisseu solta o leme por um instante e avista terra no horizonte."
			action.text = "SEGUIR PARA ÍTACA"

func _primary_action() -> void:
	if run.phase == RUN.Phase.DONE:
		get_tree().change_scene_to_file(FINAL_POSEIDON)
	else:
		restart_checkpoint()

func _impact() -> void:
	if is_instance_valid(impact_audio):
		impact_audio.play()

func _setup_audio() -> void:
	music_was_paused = AudioManager.music_player.stream_paused
	AudioManager.music_player.stream_paused = true
	current_audio = AudioStreamPlayer.new()
	var current: AudioStreamWAV = preload("res://Assets/act8_scylla/cave_current.wav").duplicate()
	current.loop_mode = AudioStreamWAV.LOOP_FORWARD
	current.loop_end = roundi(current.get_length() * current.mix_rate)
	current_audio.stream = current
	current_audio.bus = &"SFX"
	current_audio.volume_db = -26.0
	add_child(current_audio)
	current_audio.play()
	impact_audio = AudioStreamPlayer.new()
	impact_audio.stream = preload("res://Assets/act8_scylla/cave_lunge.wav")
	impact_audio.bus = &"SFX"
	impact_audio.volume_db = -13.0
	add_child(impact_audio)

func _exit_tree() -> void:
	if is_instance_valid(current_audio):
		current_audio.stop()
		if is_instance_valid(AudioManager.music_player):
			AudioManager.music_player.stream_paused = music_was_paused
	if is_instance_valid(impact_audio):
		impact_audio.stop()

func _panel(bounds: Rect2) -> Panel:
	var panel := Panel.new()
	panel.position = bounds.position
	panel.size = bounds.size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color("09171bea")
	style.border_color = Color("527879")
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	panel.add_theme_stylebox_override("panel", style)
	frame.add_child(panel)
	return panel

func _label(parent: Node, text: String, bounds: Rect2, font_size: int, tint := INK) -> Label:
	var label := Label.new()
	label.text = text
	label.position = bounds.position
	label.size = bounds.size
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", tint)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _button(parent: Node, text: String, bounds: Rect2, handler: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.position = bounds.position
	button.size = bounds.size
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(handler)
	parent.add_child(button)
	return button

func _to_map() -> void:
	get_tree().change_scene_to_file(MAP)

func _build_ui() -> void:
	var top := _panel(Rect2(24, 15, 1104, 72))
	_label(top, "ATO XI   /   CARÍBDIS", Rect2(19, 7, 670, 30), 23, GOLD)
	status = _label(top, "", Rect2(20, 40, 640, 22), 17)
	timer = _label(top, "", Rect2(646, 7, 104, 46), 34, GOLD)
	hull = _label(top, "", Rect2(773, 22, 175, 25), 18)
	_button(top, "MAPA", Rect2(973, 18, 111, 34), _to_map)
	var bottom := _panel(Rect2(24, 576, 1104, 55))
	_label(bottom, "A / ←  MAIS PERTO DO CENTRO     D / →  MAIS LONGE     R  RECOMEÇAR     ESC  PAUSA", Rect2(17, 15, 715, 23), 14)
	var rail := ColorRect.new()
	rail.color = Color("294444")
	rail.position = Vector2(760, 24)
	rail.size = Vector2(321, 7)
	rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(rail)
	fill = ColorRect.new()
	fill.color = GOLD
	fill.size = Vector2(0, 7)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rail.add_child(fill)
	dialog = _panel(Rect2(281, 203, 590, 235))
	title = _label(dialog, "", Rect2(24, 20, 542, 40), 27, GOLD)
	detail = _label(dialog, "", Rect2(24, 79, 542, 79), 19)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	action = _button(dialog, "", Rect2(24, 175, 255, 40), _primary_action)
	_button(dialog, "VOLTAR AO MAPA", Rect2(308, 175, 255, 40), _to_map)
