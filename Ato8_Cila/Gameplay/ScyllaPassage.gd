extends Control

const RUN := preload("res://Ato8_Cila/Gameplay/ScyllaRun.gd")
const STAGE := preload("res://Ato8_Cila/Gameplay/ScyllaStage.gd")
const DECK := preload("res://Ato8_Cila/Cutscenes/ScyllaDeck.gd")
const ATTRIBUTES := preload("res://Code/PlayerAttributes.gd")
const DESIGN := Vector2(1152, 648)
const GOLD := Color("f1ce8b")
const PALE := Color("deeeea")
const MAP := "res://Scenes/WorldMap.tscn"

# Shot, speaker, original subtitle and automatic hold in seconds.
const INTRO := [
	["approach", "EURÍLOCO", "O mar ficou quieto. Tem certeza de que é por aqui?", 4.0],
	["order", "ODISSEU", "É por aqui. Mande acender seis tochas no convés.", 4.0],
	["torches", "", "", 3.4],
]
const OUTRO := [
	["empty", "", "", 3.2],
	["recognize", "EURÍLOCO", "Foram os homens com as tochas. Os seis.", 3.6],
	["recognize", "EURÍLOCO", "Você sabia, não sabia?", 3.2],
	["silence", "", "", 4.0],
]

enum Mode { LOCKED, INTRO, HELM, OUTRO, RESULT }

@export var audio_enabled := true
var mode := Mode.LOCKED
var run := RUN.new()
var frame: Node2D
var stage: STAGE
var deck: DECK
var hud: Control
var advance_hint: Label
var story: Control
var story_tag: Label
var story_panel: Panel
var speaker_label: Label
var line_label: Label
var next_button: Button
var result: Panel
var result_title: Label
var result_text: Label
var next_stage: Button
var curtain: ColorRect
var curtain_alpha := 1.0
var beats: Array = []
var beat_index := 0
var beat_age := 0.0
var awaiting_helm := false
var ending_pending := false
var ambience: AudioStreamPlayer
var effects: AudioStreamPlayer2D
var music_was_paused := false

func _ready() -> void:
	set_meta("hide_main_hud", true)
	MainHUD.set_station("Ato VIII - A gruta de Cila")
	frame = Node2D.new()
	add_child(frame)
	stage = STAGE.new()
	stage.run = run
	frame.add_child(stage)
	deck = DECK.new()
	frame.add_child(deck)
	_build_ui()
	_apply_attributes()
	GameManager.player_stats_changed.connect(_apply_attributes)
	run.impact.connect(_on_impact)
	run.torch_lost.connect(_on_torch_lost)
	resized.connect(_fit)
	_fit()
	if audio_enabled:
		_setup_audio()
	if GameManager.sirens_completed or GameManager.standalone_stage_preview:
		_begin_story(false)
	else:
		_set_mode(Mode.LOCKED)
		result_title.text = "A GRUTA ESTÁ ALÉM DO RECIFE"
		result_text.text = "Capture a sereia para descobrir a passagem que evita Poseidon."

func _fit() -> void:
	var factor := minf(size.x / DESIGN.x, size.y / DESIGN.y)
	frame.scale = Vector2.ONE * factor
	frame.position = (size - DESIGN * factor) / 2.0

func _physics_process(delta: float) -> void:
	if mode != Mode.HELM or awaiting_helm:
		return
	var ahead := Input.is_action_pressed("ui_up") or Input.is_physical_key_pressed(KEY_W)
	run.tick(delta, ahead)
	if run.phase == RUN.Phase.ESCAPED:
		awaiting_helm = true
		ending_pending = true

func _process(delta: float) -> void:
	if ending_pending:
		curtain_alpha = move_toward(curtain_alpha, 1.0, delta * 1.9)
		if curtain_alpha >= 1.0:
			ending_pending = false
			_begin_story(true)
	else:
		curtain_alpha = move_toward(curtain_alpha, 0.0, delta * 1.55)
	curtain.color.a = curtain_alpha
	if stage.visible:
		stage.update_view(delta)
	if story.visible:
		_update_story(delta)
	if mode == Mode.HELM:
		var show_hint := run.speed < 12.0 and (run.distance < 220.0 or run.torches == 0) and not ending_pending
		advance_hint.modulate.a = move_toward(advance_hint.modulate.a, float(show_hint), delta * 3.0)
	if is_instance_valid(ambience):
		var level := -24.0
		if mode in [Mode.OUTRO, Mode.RESULT]: level = -39.0
		elif mode == Mode.HELM:
			level = -31.0 if run.torches == 0 else -20.0 + run.speed / 85.0
		ambience.volume_db = move_toward(ambience.volume_db, level, delta * 12.0)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_R and mode == Mode.HELM:
			restart_checkpoint()
		elif event.physical_keycode in [KEY_SPACE, KEY_ENTER] and story.visible:
			advance_story()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and story.visible:
		advance_story()

func _begin_story(outro: bool) -> void:
	awaiting_helm = false
	beats = OUTRO if outro else INTRO
	beat_index = 0
	deck.time = 0.0
	deck.torch_count = 0
	story_tag.text = "FORA DA GRUTA" if outro else "À BOCA DA GRUTA"
	_set_mode(Mode.OUTRO if outro else Mode.INTRO)
	_show_beat(true)

func _show_beat(snap: bool = false) -> void:
	beat_age = 0.0
	var beat: Array = beats[beat_index]
	deck.show_shot(beat[0], beat[1], snap)
	speaker_label.text = beat[1]
	line_label.text = beat[2]
	story_panel.visible = not line_label.text.is_empty()
	next_button.disabled = true
	var final_intro := mode == Mode.INTRO and beat_index == beats.size() - 1
	next_button.text = "ENTRAR NA GRUTA  ›" if final_intro else "CONTINUAR  ›"

func _update_story(delta: float) -> void:
	beat_age += delta
	deck.advance_view(delta)
	var beat: Array = beats[beat_index]
	if beat[0] == "torches":
		deck.torch_count = clampi(floori((beat_age - 0.15) / 0.37), 0, RUN.TORCHES.size())
	var final_intro := mode == Mode.INTRO and beat_index == beats.size() - 1
	var minimum := 2.5 if final_intro or beat[0] == "silence" else 1.5 if mode == Mode.OUTRO else 0.8
	next_button.disabled = beat_age < minimum
	# At the helm handoff, give the player control at a deliberate input.
	if not final_intro and beat_age >= float(beat[3]):
		advance_story()

func advance_story() -> void:
	if not story.visible or next_button.disabled:
		return
	if beat_index + 1 < beats.size():
		beat_index += 1
		_show_beat()
	elif mode == Mode.INTRO:
		restart_checkpoint()
	else:
		_finish_passage()

func restart_checkpoint() -> void:
	if mode not in [Mode.INTRO, Mode.HELM] or ending_pending:
		return
	if mode == Mode.INTRO and beat_index != INTRO.size() - 1:
		return
	GameManager.reset_encounter()
	curtain_alpha = 0.65
	stage.reset_effects()
	run.restart()
	_set_mode(Mode.HELM)
	awaiting_helm = false
	advance_hint.modulate.a = 1.0

func _finish_passage() -> void:
	if not GameManager.standalone_stage_preview:
		GameManager.complete_scylla()
	_set_mode(Mode.RESULT)
	result_title.text = "O NAVIO DEIXOU A GRUTA"
	result_text.text = "Seis homens ficaram para trás. No convés, os remos voltaram a bater antes que alguém respondesse a Euríloco."

func _set_mode(next: Mode) -> void:
	mode = next
	hud.visible = mode == Mode.HELM
	story.visible = mode in [Mode.INTRO, Mode.OUTRO]
	stage.visible = mode in [Mode.HELM, Mode.LOCKED]
	deck.visible = story.visible or mode == Mode.RESULT
	result.visible = mode in [Mode.RESULT, Mode.LOCKED]
	next_stage.visible = mode == Mode.RESULT

func _apply_attributes() -> void:
	run.apply_attributes(ATTRIBUTES.capture(GameManager))

func _on_impact(kind: String, at: Vector2) -> void:
	stage.add_impact(kind, at)
	if not is_instance_valid(effects):
		return
	effects.position = stage.project(at)
	if kind == "surface":
		effects.pitch_scale = 0.58
		effects.volume_db = -24.0
	else:
		effects.pitch_scale = 0.87 + sin(run.clock * 2.0) * 0.12
		effects.volume_db = -11.0
	effects.play()

func _on_torch_lost(_index: int, at: Vector2) -> void:
	stage.add_impact("torch", at)

func _return_to_map() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(MAP)

func _continue_to_mutiny() -> void:
	if mode == Mode.RESULT:
		get_tree().change_scene_to_file("res://Ato9_Motim/Gameplay/Mutiny.tscn")

func _layer() -> Control:
	var layer := Control.new()
	layer.size = DESIGN
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(layer)
	return layer

func _panel(parent: Node, rect: Rect2, opaque := false) -> Panel:
	var panel := Panel.new()
	panel.position = rect.position
	panel.size = rect.size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.056, 0.067, 0.96 if opaque else 0.90)
	style.border_color = Color("5c8687")
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	return panel

func _label(parent: Node, text: String, rect: Rect2, font_size: int, tint := PALE, wrap := false) -> Label:
	var label := Label.new()
	if wrap:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.position = rect.position
	label.size = rect.size
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", tint)
	label.text = text
	parent.add_child(label)
	return label

func _button(parent: Node, text: String, rect: Rect2, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.position = rect.position
	button.size = rect.size
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _build_ui() -> void:
	hud = _layer()
	advance_hint = _label(hud, "SEGURE W OU ↑ PARA SEGUIR", Rect2(360, 567, 432, 42), 17, Color("e6d7b7"))
	advance_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	advance_hint.add_theme_color_override("font_outline_color", Color("080c0e"))
	advance_hint.add_theme_constant_override("outline_size", 5)
	story = _layer()
	var bar := _panel(story, Rect2(0, 0, 1152, 38), true)
	story_tag = _label(bar, "", Rect2(29, 6, 600, 26), 16, GOLD)
	story_panel = _panel(story, Rect2(68, 477, 1016, 96), true)
	speaker_label = _label(story_panel, "", Rect2(21, 10, 960, 24), 16, GOLD)
	line_label = _label(story_panel, "", Rect2(21, 39, 960, 44), 23, PALE, true)
	next_button = _button(story, "CONTINUAR  ›", Rect2(832, 587, 252, 37), advance_story)
	result = _panel(frame, Rect2(275, 207, 602, 235), true)
	result_title = _label(result, "", Rect2(24, 19, 554, 39), 25, GOLD, true)
	result_text = _label(result, "", Rect2(24, 76, 554, 90), 18, PALE, true)
	next_stage = _button(result, "SEGUIR PARA O MOTIM  ›", Rect2(24, 175, 260, 37), _continue_to_mutiny)
	_button(result, "VOLTAR AO MAPA", Rect2(318, 175, 260, 37), _return_to_map)
	curtain = ColorRect.new()
	curtain.size = DESIGN
	curtain.color = Color(0.015, 0.029, 0.039, 1)
	curtain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(curtain)

func _setup_audio() -> void:
	music_was_paused = AudioManager.music_player.stream_paused
	AudioManager.music_player.stream_paused = true
	ambience = AudioStreamPlayer.new()
	var current: AudioStreamWAV = load("res://Assets/act8_scylla/cave_current.wav").duplicate()
	current.loop_mode = AudioStreamWAV.LOOP_FORWARD
	current.loop_end = roundi(current.get_length() * current.mix_rate)
	ambience.stream = current
	ambience.bus = &"SFX"
	ambience.volume_db = -24.0
	add_child(ambience)
	ambience.play()
	effects = AudioStreamPlayer2D.new()
	effects.stream = load("res://Assets/act8_scylla/cave_lunge.wav")
	effects.bus = &"SFX"
	effects.max_distance = 1100.0
	effects.attenuation = 0.65
	effects.max_polyphony = 3
	frame.add_child(effects)

func _exit_tree() -> void:
	if is_instance_valid(ambience):
		ambience.stop()
	if is_instance_valid(effects):
		effects.stop()
	if audio_enabled and is_instance_valid(AudioManager.music_player):
		AudioManager.music_player.stream_paused = music_was_paused
