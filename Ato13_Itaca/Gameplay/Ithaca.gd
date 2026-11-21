extends Control

const FIGHT := preload("res://Ato13_Itaca/Gameplay/SuitorsFight.gd")
const HALL := preload("res://Ato13_Itaca/Gameplay/IthacaHall.gd")
const ATTRIBUTES := preload("res://Code/PlayerAttributes.gd")
const MAP := "res://Scenes/WorldMap.tscn"
const GOLD := Color("ffdca0")
const INK := Color("ede4da")

@export var audio_enabled := true
var fight := FIGHT.new()
var frame := Node2D.new()
var hall := HALL.new()
var locked := false
var objective: Label
var hp: Label
var guard_bar: ColorRect
var guard_fill: ColorRect
var instruction: Label
var controls: Label
var panel_result: Panel
var title: Label
var result_text: Label
var action: Button
var fx: AudioStreamPlayer
var note := ""
var note_time := 0.0

func _ready() -> void:
	set_meta("hide_main_hud", true)
	MainHUD.set_station("Ato XIII - Ítaca")
	locked = not (GameManager.final_poseidon_completed or GameManager.standalone_stage_preview)
	add_child(frame)
	hall.fight = fight
	frame.add_child(hall)
	_build_ui()
	_fit()
	resized.connect(_fit)
	GameManager.player_stats_changed.connect(_stats)
	_stats()
	fight.phase_changed.connect(_phase_changed)
	fight.cue.connect(_cue)
	fight.cue.connect(hall.react)
	if audio_enabled and DisplayServer.get_name() != "headless":
		fx = AudioStreamPlayer.new()
		fx.bus = &"SFX"
		fx.volume_db = -15.0
		add_child(fx)
	_refresh()

func _stats() -> void:
	fight.apply_stats(ATTRIBUTES.capture(GameManager))

func _fit() -> void:
	var ratio := minf(size.x / HALL.VIEW.x, size.y / HALL.VIEW.y)
	frame.scale = Vector2.ONE * ratio
	frame.position = (size - HALL.VIEW * ratio) * 0.5

func _held(key: Key, action_name: StringName) -> bool:
	return Input.is_physical_key_pressed(key) or Input.is_action_pressed(action_name)

func _read_input() -> void:
	var axis := Vector2(
		float(_held(KEY_D, &"ui_right")) - float(_held(KEY_A, &"ui_left")),
		float(_held(KEY_S, &"ui_down")) - float(_held(KEY_W, &"ui_up"))
	)
	fight.set_input(axis, frame.get_local_mouse_position(), Input.is_physical_key_pressed(KEY_SHIFT))

func _physics_process(delta: float) -> void:
	_read_input()
	fight.tick(delta)
	note_time = maxf(0, note_time - delta)
	_refresh()

func _process(delta: float) -> void:
	hall.advance(delta)

func _input(event: InputEvent) -> void:
	if fight.phase != FIGHT.Phase.BOW or not fight.drawing or event.is_pressed():
		return
	if (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventKey and event.physical_keycode in [KEY_SPACE, KEY_J]):
		_read_input()
		fight.attack_up()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_read_input()
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed: fight.attack_down()
			else: fight.attack_up()
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			fight.dash()
		return
	if not (event is InputEventKey and not event.echo):
		return
	var key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
	if key in [KEY_SPACE, KEY_J]:
		_read_input()
		if event.pressed: fight.attack_down()
		else: fight.attack_up()
	elif event.pressed and key == KEY_ENTER and fight.phase in [FIGHT.Phase.READY, FIGHT.Phase.LOST]:
		restart_checkpoint()
	elif event.pressed and key == KEY_R:
		restart_checkpoint()

func restart_checkpoint() -> void:
	if locked or fight.phase in [FIGHT.Phase.EPILOGUE, FIGHT.Phase.WON]:
		return
	note_time = 0.0
	if fight.phase == FIGHT.Phase.READY:
		fight.start()
	else:
		fight.retry()

func _phase_changed() -> void:
	note_time = 0.0
	if fight.phase == FIGHT.Phase.WON and not GameManager.standalone_stage_preview:
		GameManager.complete_ithaca(fight.hp)
	_refresh()

func _cue(kind: StringName) -> void:
	match kind:
		&"weak_bow":
			note = "Puxe a corda um pouco mais antes de soltar."
			note_time = 2.6
		&"miss":
			note = "A flecha parou num dos machados. Ajuste a mira pela fileira de aros."
			note_time = 3.1
	if not is_instance_valid(fx):
		return
	match kind:
		&"bow": fx.stream = preload("res://Assets/sfx_bow.wav")
		&"dash": fx.stream = preload("res://Assets/sfx_dash.wav")
		&"enemy", &"sword", &"block", &"hit": fx.stream = preload("res://Assets/sfx_sword.wav")
		&"hurt": fx.stream = preload("res://Assets/sfx_damage.wav")
		_: return
	fx.play()

func _refresh() -> void:
	var phase := fight.phase
	hp.text = "VIDA  %d / %d" % [fight.hp, fight.max_hp]
	hp.modulate = Color("ffc09a") if fight.hp <= 2 else Color.WHITE
	guard_bar.visible = phase == FIGHT.Phase.FIGHT
	guard_fill.size.x = guard_bar.size.x * fight.guard_stamina
	panel_result.visible = phase in [FIGHT.Phase.READY, FIGHT.Phase.LOST, FIGHT.Phase.WON]
	action.visible = not locked and phase != FIGHT.Phase.WON and (phase != FIGHT.Phase.LOST or fight.checkpoint_hp > 0)
	controls.text = ""
	instruction.text = ""
	match phase:
		FIGHT.Phase.READY:
			objective.text = "O salão do trono"
			title.text = "O ARCO DO REI" if not locked else "O CAMINHO PARA ÍTACA SEGUE FECHADO"
			result_text.text = "Os pretendentes ocuparam o palácio. O arco de Odisseu espera ao lado da fileira de machados." if not locked else "Vença o último confronto com Poseidon para entrar no palácio."
			action.text = "TOMAR O ARCO"
		FIGHT.Phase.BOW:
			objective.text = "A prova dos doze machados"
			if fight.bow_victory_age >= 0.0:
				instruction.text = "Odisseu   ·   Voltei para tomar minha casa."
			elif note_time > 0.0:
				instruction.text = note
			else:
				instruction.text = "Alinhe a flecha com os doze aros e solte quando a corda estiver tensa."
			controls.text = "MOUSE · MIRAR     SEGURE E SOLTE O CLIQUE ESQUERDO · ATIRAR     ESC · PAUSA"
		FIGHT.Phase.FIGHT:
			objective.text = "INVESTIDA %d / %d   ·   %d PRETENDENTES" % [fight.wave + 1, FIGHT.ROUNDS.size(), fight.remaining()]
			if fight.wave == 0 and fight.phase_age < 6.0:
				instruction.text = "Use as colunas como cobertura e não deixe que o cerquem."
			elif fight.wave == 1 and fight.phase_age < 6.0:
				instruction.text = "Passe pelo escudo com o dash ou ataque durante a recuperação."
			elif fight.wave == 2 and fight.phase_age < 5.0:
				instruction.text = "Eurímaco   ·   Cerquem-no! Eu fecho o caminho pelo centro."
			controls.text = "WASD / SETAS · MOVER     SHIFT · DEFESA     CLIQUE DIREITO · DASH     CLIQUE ESQUERDO · ATACAR     ESC · PAUSA"
		FIGHT.Phase.BREATH:
			objective.text = "Passos nos corredores"
			instruction.text = "Os arqueiros procuram os vãos entre as colunas." if fight.wave == 0 else "Eurímaco reúne os últimos pretendentes."
		FIGHT.Phase.EPILOGUE:
			objective.text = "O retorno"
			if fight.phase_age < 3.1: instruction.text = "Penélope   ·   A oliveira ainda está aqui."
			elif fight.phase_age < 6.5: instruction.text = "Odisseu   ·   Eu lembro de cada marca na madeira."
			else: instruction.text = "Telêmaco   ·   Bem-vindo à sua casa, pai."
		FIGHT.Phase.WON:
			objective.text = "Ítaca"
			title.text = "ODISSEU VOLTOU PARA CASA"
			result_text.text = "O salão está em silêncio. Penélope, Telêmaco e Odisseu estão juntos de novo."
		FIGHT.Phase.LOST:
			objective.text = "O salão do trono"
			title.text = "ODISSEU CAIU"
			result_text.text = "Retome do começo da investida %d." % (fight.checkpoint + 1) if fight.checkpoint >= 0 else "Retome da prova do arco."
			action.text = "TENTAR DE NOVO"

func _panel(bounds: Rect2) -> Panel:
	var panel := Panel.new()
	panel.position = bounds.position
	panel.size = bounds.size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color("181218ed")
	style.border_color = Color("987253")
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
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

func _button(parent: Node, text: String, bounds: Rect2, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.position = bounds.position
	button.size = bounds.size
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _map() -> void:
	if is_instance_valid(fx): fx.stop()
	get_tree().change_scene_to_file(MAP)

func _build_ui() -> void:
	var top := _panel(Rect2(24, 16, 1104, 73))
	_label(top, "ATO XIII   /   ÍTACA", Rect2(20, 7, 622, 29), 24, GOLD)
	objective = _label(top, "", Rect2(21, 42, 636, 23), 17)
	hp = _label(top, "", Rect2(743, 16, 202, 28), 17)
	guard_bar = ColorRect.new()
	guard_bar.position = Vector2(743, 52)
	guard_bar.size = Vector2(129, 5)
	guard_bar.color = Color("59403a")
	guard_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	guard_fill = ColorRect.new()
	guard_fill.size = guard_bar.size
	guard_fill.color = Color("d5b581")
	guard_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	guard_bar.add_child(guard_fill)
	top.add_child(guard_bar)
	_button(top, "MAPA", Rect2(973, 19, 111, 34), _map)
	var bottom := _panel(Rect2(24, 554, 1104, 76))
	instruction = _label(bottom, "", Rect2(17, 8, 1069, 29), 20, GOLD)
	controls = _label(bottom, "", Rect2(17, 45, 1069, 23), 14)
	panel_result = _panel(Rect2(255, 200, 642, 232))
	title = _label(panel_result, "", Rect2(24, 20, 594, 40), 27, GOLD)
	result_text = _label(panel_result, "", Rect2(24, 79, 594, 73), 20)
	result_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	action = _button(panel_result, "", Rect2(24, 172, 267, 40), restart_checkpoint)
	_button(panel_result, "VOLTAR AO MAPA", Rect2(345, 172, 273, 40), _map)
