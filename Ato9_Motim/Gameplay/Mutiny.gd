extends Control

const FIGHT := preload("res://Ato9_Motim/Gameplay/MutinyFight.gd")
const ARENA := preload("res://Ato9_Motim/Gameplay/MutinyArena.gd")
const STORY := preload("res://Ato9_Motim/Cutscenes/MutinyStory.gd")
const ATTRIBUTES := preload("res://Code/PlayerAttributes.gd")
const DESIGN := Vector2(1152, 648)
const MAP := "res://Scenes/WorldMap.tscn"
const GOLD := Color("edc58d")
const PALE := Color("e4eeec")

# Shot, speaker, original dialogue and auto-advance time.
const INTRO := [
	["accuse", "EURÍLOCO", "Quando me mandou acender as tochas, você já sabia o que ia acontecer?", 4.4],
	["answer", "ODISSEU", "Eu escolhi a passagem que ainda podia levar este navio para casa.", 4.4],
	["draw", "EURÍLOCO", "Seis homens obedeceram à sua ordem. Quem vai responder por eles?", 4.1],
]
const AFTER := [
	["intervene", "", "", 2.6],
	["shore", "ODISSEU", "Onde estamos? Quem trouxe o navio para cá?", 4.1],
	["warning", "ODISSEU", "Olhem o altar. Esse rebanho é de Hélios. Afastem-se dos animais.", 4.5],
	["choice", "EURÍLOCO", "Os homens mal conseguem ficar de pé. Eu também respondo por eles.", 4.3],
	["offering", "", "", 2.0],
	["escape", "ODISSEU", "Vocês mataram um animal sagrado. Para o navio, depressa!", 4.0],
	["thunder", "", "", 3.6],
]

enum Mode { LOCKED, INTRO, DUEL, LOST, AFTER, DONE }

@export var audio_enabled := true
var fight := FIGHT.new()
var mode := Mode.LOCKED
var frame: Node2D
var arena: ARENA
var story: STORY
var hud: Control
var subtitles: Control
var subtitle_panel: Panel
var chapter_label: Label
var speaker_label: Label
var line_label: Label
var hint_label: Label
var hero_label: Label
var enemy_label: Label
var enemy_bar: ProgressBar
var guard_bar: ProgressBar
var next_button: Button
var result: Panel
var result_title: Label
var result_text: Label
var retry_button: Button
var ogygia_button: Button
var beats: Array = []
var beat_index := 0
var beat_age := 0.0
var disarm_hold := 0.0
var notice := 0.0
var sound: AudioStreamPlayer
var ambience: AudioStreamPlayer
var old_music_paused := false

func _ready() -> void:
	set_meta("hide_main_hud", true)
	MainHUD.set_station("Ato IX - O Motim")
	fight.apply_attributes(ATTRIBUTES.capture(GameManager))
	GameManager.player_stats_changed.connect(_apply_stats)
	frame = Node2D.new()
	add_child(frame)
	arena = ARENA.new()
	arena.fight = fight
	frame.add_child(arena)
	story = STORY.new()
	frame.add_child(story)
	_build_ui()
	fight.cue.connect(_cue)
	resized.connect(_fit)
	_fit()
	if audio_enabled:
		_setup_audio()
	if GameManager.scylla_completed or GameManager.standalone_stage_preview:
		_open_story(false)
	else:
		_set_mode(Mode.LOCKED)
		result_title.text = "O NAVIO AINDA ESTÁ NA GRUTA"
		result_text.text = "Conclua a travessia de Cila para abrir o Motim."

func _fit() -> void:
	var factor := minf(size.x / DESIGN.x, size.y / DESIGN.y)
	frame.scale = Vector2.ONE * factor
	frame.position = (size - DESIGN * factor) * 0.5

func _axis() -> Vector2:
	var left := Input.is_action_pressed("ui_left") or Input.is_physical_key_pressed(KEY_A)
	var right := Input.is_action_pressed("ui_right") or Input.is_physical_key_pressed(KEY_D)
	var up := Input.is_action_pressed("ui_up") or Input.is_physical_key_pressed(KEY_W)
	var down := Input.is_action_pressed("ui_down") or Input.is_physical_key_pressed(KEY_S)
	return Vector2(float(right) - float(left), float(down) - float(up))

func _aim() -> Vector2:
	return frame.to_local(get_global_mouse_position()) - fight.position

func _physics_process(delta: float) -> void:
	if mode != Mode.DUEL:
		return
	fight.tick(delta, _axis(), _aim(), Input.is_physical_key_pressed(KEY_SHIFT))
	_update_hud()
	if fight.phase == FIGHT.Phase.LOST:
		_set_mode(Mode.LOST)
		result_title.text = "ODISSEU CAIU"
		result_text.text = "Proteja a frente ou saia do alcance. Ataque quando Euríloco terminar o golpe."
	elif fight.phase == FIGHT.Phase.DISARMED:
		disarm_hold += delta
		if disarm_hold >= 0.82:
			_open_story(true)

func _process(delta: float) -> void:
	if arena.visible:
		arena.update_view(delta)
	if subtitles.visible:
		_update_story(delta)
	if notice > 0.0:
		notice = maxf(0.0, notice - delta)
		if notice == 0.0:
			hint_label.text = "Abra a guarda de Euríloco e desarme-o."
	if is_instance_valid(ambience):
		var target := -34.0 if mode == Mode.AFTER else -19.0 if mode == Mode.DUEL else -26.0
		ambience.volume_db = move_toward(ambience.volume_db, target, delta * 22.0)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		if subtitles.visible and key in [KEY_SPACE, KEY_ENTER]:
			advance_story()
		elif key == KEY_R and mode in [Mode.DUEL, Mode.LOST]:
			restart_checkpoint()
		elif key in [KEY_J, KEY_SPACE] and mode == Mode.DUEL:
			fight.attack(_aim())
		elif key == KEY_Q and mode == Mode.DUEL:
			fight.dash(_axis())
	elif event is InputEventMouseButton and event.pressed:
		if subtitles.visible and event.button_index == MOUSE_BUTTON_LEFT:
			advance_story()
		elif mode == Mode.DUEL:
			if event.button_index == MOUSE_BUTTON_LEFT:
				fight.attack(_aim())
			elif event.button_index == MOUSE_BUTTON_RIGHT:
				fight.dash(_axis())

func _open_story(after: bool) -> void:
	beats = AFTER if after else INTRO
	beat_index = 0
	story.clock = 0.0
	_set_mode(Mode.AFTER if after else Mode.INTRO)
	_show_beat(true)

func _show_beat(snap := false) -> void:
	beat_age = 0.0
	var beat: Array = beats[beat_index]
	story.show_shot(beat[0], beat[1], snap or beat[0] in ["shore", "escape", "thunder"])
	var location := "NO CONVÉS"
	if beat[0] in ["shore", "warning", "choice", "offering"]:
		location = "NA ILHA DE HÉLIOS"
	elif beat[0] in ["escape", "thunder"]:
		location = "DE VOLTA AO MAR"
	chapter_label.text = "MOTIM  /  " + location
	speaker_label.text = beat[1]
	line_label.text = beat[2]
	subtitle_panel.visible = not line_label.text.is_empty()
	next_button.disabled = true
	next_button.text = "DESEMBANHAR  ›" if mode == Mode.INTRO and beat_index == beats.size() - 1 else "CONTINUAR  ›"

func _update_story(delta: float) -> void:
	var before := beat_age
	beat_age += delta
	story.update_view(delta)
	var beat: Array = beats[beat_index]
	if beat[0] == "intervene" and before < 0.72 and beat_age >= 0.72:
		_play("res://Assets/sfx_damage.wav", 0.68, -9.0)
	elif beat[0] == "offering" and before < 0.8 and beat_age >= 0.8:
		_play("res://Assets/sfx_sword.wav", 0.61, -10.0)
	elif beat[0] == "thunder" and before < 0.73 and beat_age >= 0.73:
		_play("res://Assets/act4_storm/thunder.wav", 0.83, -8.0)
	var final_intro := mode == Mode.INTRO and beat_index == beats.size() - 1
	var hold := 1.7 if beat[1].is_empty() else 0.9
	next_button.disabled = beat_age < hold
	if not final_intro and beat_age >= float(beat[3]):
		advance_story()

func advance_story() -> void:
	if not subtitles.visible or next_button.disabled:
		return
	if beat_index + 1 < beats.size():
		beat_index += 1
		_show_beat()
	elif mode == Mode.INTRO:
		_start_duel(false)
	else:
		_complete()

func _start_duel(retry: bool) -> void:
	GameManager.reset_encounter()
	arena.reset_effects()
	disarm_hold = 0.0
	if retry:
		fight.restart()
	else:
		fight.begin()
	_set_mode(Mode.DUEL)
	hint_label.text = "Abra a guarda de Euríloco e desarme-o."
	_update_hud()

func restart_checkpoint() -> void:
	if mode in [Mode.DUEL, Mode.LOST] and fight.phase != FIGHT.Phase.DISARMED:
		_start_duel(true)

func _complete() -> void:
	if not GameManager.standalone_stage_preview:
		GameManager.complete_mutiny(fight.hp)
	_set_mode(Mode.DONE)
	result_title.text = "O TROVÃO RESPONDEU"
	result_text.text = "O navio já está em mar aberto. A decisão na ilha de Hélios alcança a tripulação."

func _set_mode(next: Mode) -> void:
	mode = next
	hud.visible = mode == Mode.DUEL
	subtitles.visible = mode in [Mode.INTRO, Mode.AFTER]
	story.visible = subtitles.visible or mode == Mode.DONE
	arena.visible = mode in [Mode.DUEL, Mode.LOST, Mode.LOCKED]
	result.visible = mode in [Mode.LOCKED, Mode.LOST, Mode.DONE]
	retry_button.visible = mode == Mode.LOST
	ogygia_button.visible = mode == Mode.DONE

func _apply_stats() -> void:
	fight.apply_attributes(ATTRIBUTES.capture(GameManager))
	_update_hud()

func _update_hud() -> void:
	hero_label.text = "VIDA  %d / %d" % [fight.hp, fight.max_hp]
	enemy_label.text = "EURÍLOCO  ·  %d / %d" % [fight.resolve, FIGHT.RESOLVE_MAX]
	enemy_bar.value = float(fight.resolve) / FIGHT.RESOLVE_MAX
	guard_bar.value = fight.guard / 100.0

func _cue(kind: String) -> void:
	arena.accent(kind)
	match kind:
		"crew":
			hint_label.text = "A tripulação começa a cercar o convés."
			notice = 3.2
		"disarm":
			hint_label.text = "Euríloco perdeu a espada."
			notice = 1.0
			_play("res://Assets/act5_circe/soft_chime.wav", 0.64, -12.0)
		"parry", "clang":
			if kind == "parry":
				hint_label.text = "A guarda dele abriu."
				notice = 1.0
			_play("res://Assets/sfx_sword.wav", 1.45 if kind == "parry" else 1.09, -14.0)
		"sword", "enemy_swing": _play("res://Assets/sfx_sword.wav", 1.0 if kind == "sword" else 0.75, -17.0)
		"dash": _play("res://Assets/sfx_dash.wav", 1.0, -18.0)
		"hurt", "hit": _play("res://Assets/sfx_damage.wav", 0.92 if kind == "hurt" else 1.18, -14.0)

func _return_to_map() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(MAP)

func _continue_to_ogygia() -> void:
	if mode == Mode.DONE:
		get_tree().change_scene_to_file("res://Ato10_Calipso/Gameplay/CalypsoPaths.tscn")

func _layer() -> Control:
	var node := Control.new()
	node.size = DESIGN
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(node)
	return node

func _panel(parent: Node, bounds: Rect2) -> Panel:
	var node := Panel.new()
	node.position = bounds.position
	node.size = bounds.size
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.029, 0.052, 0.065, 0.94)
	style.border_color = Color("738789")
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	node.add_theme_stylebox_override("panel", style)
	parent.add_child(node)
	return node

func _label(parent: Node, text: String, bounds: Rect2, font_size: int, tint := PALE, wrap := false) -> Label:
	var node := Label.new()
	if wrap:
		node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.position = bounds.position
	node.size = bounds.size
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", tint)
	node.text = text
	parent.add_child(node)
	return node

func _button(parent: Node, text: String, bounds: Rect2, action: Callable) -> Button:
	var node := Button.new()
	node.text = text
	node.position = bounds.position
	node.size = bounds.size
	node.focus_mode = Control.FOCUS_NONE
	node.pressed.connect(action)
	parent.add_child(node)
	return node

func _bar(parent: Node, bounds: Rect2, color: Color) -> ProgressBar:
	var node := ProgressBar.new()
	node.position = bounds.position
	node.max_value = 1.0
	node.step = 0.0
	node.show_percentage = false
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	var back := StyleBoxFlat.new()
	back.bg_color = Color("293940")
	node.add_theme_stylebox_override("fill", fill)
	node.add_theme_stylebox_override("background", back)
	parent.add_child(node)
	node.size = bounds.size
	return node

func _build_ui() -> void:
	hud = _layer()
	var header := _panel(hud, Rect2(23, 17, 1106, 82))
	_label(header, "MOTIM  /  O CONVÉS DIVIDIDO", Rect2(17, 7, 610, 30), 24, GOLD)
	hint_label = _label(header, "", Rect2(17, 44, 620, 24), 16)
	enemy_label = _label(header, "", Rect2(679, 12, 246, 22), 16, GOLD)
	enemy_bar = _bar(header, Rect2(679, 44, 257, 8), Color("be7256"))
	_button(header, "MAPA", Rect2(987, 21, 99, 36), _return_to_map)
	var footer := _panel(hud, Rect2(23, 561, 1106, 69))
	hero_label = _label(footer, "", Rect2(17, 7, 302, 23), 17)
	_label(footer, "GUARDA", Rect2(17, 36, 72, 20), 12)
	guard_bar = _bar(footer, Rect2(87, 42, 171, 7), Color("8ac6c6"))
	_label(footer, "WASD / SETAS · MOVER    MOUSE · MIRAR    J / CLIQUE · ESPADA    SHIFT · DEFENDER    Q · DASH    R · REINICIAR", Rect2(325, 37, 758, 20), 12)
	subtitles = _layer()
	var top := _panel(subtitles, Rect2(0, 0, 1152, 38))
	chapter_label = _label(top, "", Rect2(28, 6, 900, 25), 16, GOLD)
	subtitle_panel = _panel(subtitles, Rect2(69, 474, 1014, 99))
	speaker_label = _label(subtitle_panel, "", Rect2(22, 10, 970, 26), 17, GOLD)
	line_label = _label(subtitle_panel, "", Rect2(22, 41, 970, 49), 22, PALE, true)
	next_button = _button(subtitles, "CONTINUAR  ›", Rect2(831, 586, 252, 38), advance_story)
	result = _panel(frame, Rect2(279, 209, 594, 225))
	result_title = _label(result, "", Rect2(24, 21, 546, 41), 26, GOLD, true)
	result_text = _label(result, "", Rect2(24, 78, 546, 71), 18, PALE, true)
	retry_button = _button(result, "TENTAR DE NOVO  ·  R", Rect2(24, 162, 252, 38), restart_checkpoint)
	ogygia_button = _button(result, "SEGUIR PARA OGÍGIA  ›", Rect2(24, 162, 252, 38), _continue_to_ogygia)
	_button(result, "VOLTAR AO MAPA", Rect2(319, 162, 252, 38), _return_to_map)

func _setup_audio() -> void:
	old_music_paused = AudioManager.music_player.stream_paused
	AudioManager.music_player.stream_paused = true
	ambience = AudioStreamPlayer.new()
	var surf: AudioStreamWAV = preload("res://Assets/act7_sirens/cove_surf.wav").duplicate()
	surf.loop_mode = AudioStreamWAV.LOOP_FORWARD
	surf.loop_end = roundi(surf.get_length() * surf.mix_rate)
	ambience.stream = surf
	ambience.bus = &"SFX"
	ambience.volume_db = -26.0
	add_child(ambience)
	ambience.play()
	sound = AudioStreamPlayer.new()
	sound.bus = &"SFX"
	sound.max_polyphony = 4
	add_child(sound)

func _play(path: String, pitch: float, volume: float) -> void:
	if not is_instance_valid(sound):
		return
	sound.stream = load(path)
	sound.pitch_scale = pitch
	sound.volume_db = volume
	sound.play()

func _exit_tree() -> void:
	if is_instance_valid(ambience):
		ambience.stop()
	if is_instance_valid(sound):
		sound.stop()
	if audio_enabled and is_instance_valid(AudioManager.music_player):
		AudioManager.music_player.stream_paused = old_music_paused
