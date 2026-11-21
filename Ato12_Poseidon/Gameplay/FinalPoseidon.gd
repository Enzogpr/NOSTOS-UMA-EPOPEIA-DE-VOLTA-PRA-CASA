extends Control

const DUEL := preload("res://Ato12_Poseidon/Gameplay/PoseidonDuel.gd")
const STAGE := preload("res://Ato12_Poseidon/Gameplay/PoseidonDuelStage.gd")
const STATS := preload("res://Code/PlayerAttributes.gd")
const MAP := "res://Scenes/WorldMap.tscn"
const ITHACA := "res://Ato13_Itaca/Gameplay/Ithaca.tscn"
const GOLD := Color("f6d99f")
const INK := Color("e4eeee")

@export var audio_enabled := true
var duel := DUEL.new()
var frame := Node2D.new()
var stage := STAGE.new()
var locked := false
var objective: Label
var health: Label
var detail: Label
var controls: Label
var interaction_hint: Label
var dash_hint: Label
var dash_taught := false
var title: Label
var result_text: Label
var result: Panel
var action: Button
var surf: AudioStreamPlayer
var pulse: AudioStreamPlayer
var impact: AudioStreamPlayer
var music_was_paused := false

func _ready() -> void:
	set_meta("hide_main_hud", true)
	MainHUD.set_station("Ato XII - Poseidon")
	locked = not (GameManager.charybdis_completed or GameManager.standalone_stage_preview)
	add_child(frame)
	stage.duel = duel
	frame.add_child(stage)
	_build_ui()
	_fit()
	resized.connect(_fit)
	GameManager.player_stats_changed.connect(_apply_stats)
	_apply_stats()
	duel.cue.connect(stage.on_cue)
	duel.cue.connect(_sound)
	duel.phase_changed.connect(_on_phase)
	if audio_enabled and DisplayServer.get_name() != "headless":
		_setup_audio()
	_refresh()

func _apply_stats() -> void:
	duel.apply_stats(STATS.capture(GameManager))

func _fit() -> void:
	var scale_factor := minf(size.x / STAGE.VIEW.x, size.y / STAGE.VIEW.y)
	frame.scale = Vector2.ONE * scale_factor
	frame.position = (size - STAGE.VIEW * scale_factor) * 0.5

func _held(key: Key, alternate: StringName) -> bool:
	return Input.is_physical_key_pressed(key) or Input.is_action_pressed(alternate)

func _input_state(pointer_override: Variant = null) -> void:
	var motion := Vector2(
		float(_held(KEY_D, &"ui_right")) - float(_held(KEY_A, &"ui_left")),
		float(_held(KEY_S, &"ui_down")) - float(_held(KEY_W, &"ui_up"))
	)
	var pointer: Vector2 = frame.get_global_transform_with_canvas().affine_inverse()*pointer_override if pointer_override is Vector2 else frame.get_local_mouse_position()
	pointer += Vector2(stage.camera_x,0)
	duel.set_input(motion, pointer - (duel.position - Vector2(0, 36)), Input.is_physical_key_pressed(KEY_SHIFT), Input.is_physical_key_pressed(KEY_E))

func _physics_process(delta: float) -> void:
	_input_state()
	duel.tick(delta)
	_refresh()

func _process(delta: float) -> void:
	stage.advance(delta)
	if is_instance_valid(surf):
		var target := -13.0 + duel.storm * 3.0
		if duel.phase in [DUEL.Phase.READY, DUEL.Phase.WON]:
			target = -29.0
		elif duel.phase == DUEL.Phase.UNLEASH and not duel.bag_emptied:
			target = -36.0
		surf.volume_db = move_toward(surf.volume_db, target, delta * 16)
		surf.pitch_scale = move_toward(surf.pitch_scale, 0.93 + duel.storm * 0.15, delta * 0.3)
		var score := -13.0 if duel.phase == DUEL.Phase.DUEL else -18.0 if duel.phase in [DUEL.Phase.SURGE, DUEL.Phase.GUARDS] else -40.0
		pulse.volume_db = move_toward(pulse.volume_db, score, delta * 16)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_input_state(event.position)
		if event.button_index == MOUSE_BUTTON_LEFT:
			duel.request_attack()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_dash()
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
	if key == KEY_ENTER and duel.phase in [DUEL.Phase.READY, DUEL.Phase.LOST]:
		restart_checkpoint()
	elif key == KEY_R and duel.phase not in [DUEL.Phase.ENDING, DUEL.Phase.WON]:
		restart_checkpoint()
	elif key == KEY_E:
		duel.interact()
	elif key == KEY_Q:
		_input_state()
		_dash()
	elif key in [KEY_SPACE, KEY_J]:
		_input_state()
		if key == KEY_SPACE:
			_dash()
		else:
			duel.request_attack()

func _dash() -> void:
	duel.request_dash()
	if duel.dash_left > 0:
		dash_taught = true

func restart_checkpoint() -> void:
	if locked or duel.phase in [DUEL.Phase.ENDING, DUEL.Phase.WON]:
		return
	if duel.phase == DUEL.Phase.READY:
		duel.start()
		if is_instance_valid(surf):
			surf.play()
			pulse.play()
	else:
		duel.retry()
	_refresh()

func _on_phase() -> void:
	if duel.phase == DUEL.Phase.WON and not GameManager.standalone_stage_preview:
		GameManager.complete_final_poseidon(duel.hp)

func _refresh() -> void:
	var phase := duel.phase
	result.visible = phase in [DUEL.Phase.READY, DUEL.Phase.LOST, DUEL.Phase.WON]
	action.visible = not locked
	health.text = "VIDA  %d / %d" % [duel.hp, duel.max_hp]
	health.modulate = Color("ffab96") if duel.hp <= 2 else Color.WHITE
	if duel.recovered_hp > 0 and duel.clock < duel.recovery_until:
		health.text += "   +%d" % duel.recovered_hp
		health.modulate = Color("9be2b0")
	detail.text = ""
	controls.text = ""
	interaction_hint.visible = false
	dash_hint.visible = not dash_taught and phase in [DUEL.Phase.SURGE, DUEL.Phase.GUARDS, DUEL.Phase.DUEL] and duel.dash_recharge <= 0
	dash_hint.position = duel.position + Vector2(-66, 23)
	match phase:
		DUEL.Phase.READY:
			objective.text = "O último confronto"
			title.text = "O DEUS ENTRE VOCÊ E ÍTACA" if not locked else "ÍTACA AINDA ESTÁ DISTANTE"
			result_text.text = "WASD / setas: mover. Mire com o mouse.\nDesvie até a proteção de Poseidon abrir. Use o vento no ponto que brilha.\nE: vento   ·   Clique direito / Q / Espaço: dash\nJ / clique esquerdo: arma   ·   Shift: defesa" if not locked else "Atravesse Caríbdis para chegar a este trecho da costa."
			action.text = "ENFRENTAR POSEIDON"
		DUEL.Phase.SURGE:
			objective.text = "I / III   ·   Onda %d / 3: desvie e use o vento na abertura" % mini(3,duel.barrier_hits+1)
			detail.text = "Odisseu   ·   Penélope... Estou tão perto." if duel.phase_age < 4 else "Poseidon   ·   Entre na água. Ou sua ilha inteira vai afundar." if duel.phase_age < 9 else ""
		DUEL.Phase.GUARDS:
			var waves := ["5 cavaleiros","Cavaleiro forte","Atirador e 2 cavaleiros"]
			objective.text = "II / III   ·   Onda %d / 3: %s" % [duel.formation+1,waves[mini(2,duel.formation)]]
			if duel.phase_age < 4:
				detail.text = "Poseidon   ·   Até o mar se levanta contra você."
			elif duel.formation == 1 and duel.guards.formation_age < 4:
				detail.text = "O cavaleiro forte resiste de frente. Ataque pelos flancos ou na recuperação."
			elif duel.formation == 2 and duel.guards.formation_age < 4:
				detail.text = "O atirador mantém distância. O vento pode afastar a escolta."
			if duel.guards.remaining() == 0:
				objective.text = "II / III   ·   Onda concluída"
		DUEL.Phase.DISARM:
			objective.text = "Use E no punho exposto para desarmar Poseidon"
			if duel.disarm_age < 1.35:
				detail.text = "Poseidon   ·   Meu exército pode se erguer outra vez."
			elif not duel.trident_dropped:
				detail.text = "Odisseu   ·   Ele baixou o tridente. É a minha chance."
			if duel.trident_dropped:
				objective.text = "Vá até o tridente e pressione E"
				detail.text = "Odisseu   ·   Agora!"
				if duel.release_age >= 0.8:
					_hint("E · PEGAR TRIDENTE",duel.trident-Vector2(0,84))
		DUEL.Phase.UNLEASH:
			objective.text = "Pare e segure E para abrir toda a bolsa"
			if not duel.bag_emptied:
				detail.text = "Odisseu   ·   As rajadas não bastam. Preciso soltar tudo."
				_hint("SEGURE E · ABRIR A BOLSA", duel.position - Vector2(0, 116))
			else:
				objective.text = "A tempestade foi libertada"
				detail.text = "Poseidon   ·   Você soltou a minha tempestade!"
		DUEL.Phase.DUEL:
			objective.text = "III / III   ·   Desvie do combo e contra-ataque com o tridente"
			if duel.boss_vulnerable():
				objective.text = "III / III   ·   Guarda baixa: aproxime-se e contra-ataque"
				_hint("GUARDA BAIXA · ATAQUE",duel.boss-Vector2(0,172))
			elif duel.clock < duel.attack_feedback_until:
				_hint(duel.attack_feedback,duel.boss-Vector2(0,172))
			if duel.phase_age < 4:
				detail.text = "Odisseu   ·   Então venha me impedir."
		DUEL.Phase.ENDING:
			objective.text = "O mar enfim cede"
			if duel.phase_age < 3.8:
				detail.text = "Odisseu   ·   Baixe a tempestade. Eu vou voltar para minha esposa."
			elif duel.phase_age < 6.8:
				detail.text = "Poseidon   ·   Basta. O caminho está aberto."
			elif duel.phase_age < 10:
				detail.text = "Poseidon   ·   Como vai conseguir dormir depois disso?"
			else:
				detail.text = "Odisseu   ·   Ao lado da minha esposa."
		DUEL.Phase.LOST:
			objective.text = "A tempestade continua"
			title.text = "POSEIDON O DERRUBOU"
			var names := {DUEL.Phase.SURGE:"o domínio do mar",DUEL.Phase.GUARDS:"o exército da água",DUEL.Phase.DUEL:"o duelo na tempestade"}
			result_text.text = "Retome %s. Sua vida volta ao valor de entrada desta etapa." % names.get(duel.checkpoint,"o confronto")
			action.visible = not locked and duel.checkpoint_hp > 0
			action.text = "TENTAR DE NOVO"
		DUEL.Phase.WON:
			objective.text = "Ítaca à vista"
			title.text = "O CAMINHO PARA ÍTACA ESTÁ ABERTO"
			result_text.text = "Odisseu baixa o tridente. A tempestade se desfaz, e sua terra reaparece."
			action.text = "SEGUIR PARA ÍTACA"
	if phase in [DUEL.Phase.SURGE,DUEL.Phase.DISARM] and duel.state == DUEL.State.EXPOSED and not duel.opening_used and not duel.trident_dropped:
		var command := "E · DESARMAR" if phase == DUEL.Phase.DISARM else "E · VENTO"
		if duel.wind_charges <= 0:
			command = "VENTO RECARREGANDO"
		_hint(command,duel.wind_point-Vector2(0,82))
	var pickup := duel.nearby_health_pickup()
	if not pickup.is_empty() and (duel.hp < duel.max_hp or not interaction_hint.visible):
		var command := "E · RECUPERAR +%d DE VIDA" % pickup.amount if duel.hp < duel.max_hp else "VIDA CHEIA · CURA DISPONÍVEL"
		_hint(command,pickup.position-Vector2(0,83))

func _hint(text: String, at: Vector2) -> void:
	interaction_hint.text = text
	interaction_hint.position = Vector2(clampf(at.x - 150, 24, 828), clampf(at.y, 110, 559))
	interaction_hint.visible = true

func _setup_audio() -> void:
	music_was_paused = AudioManager.music_player.stream_paused
	AudioManager.music_player.stream_paused = true
	var sea_loop: AudioStreamWAV = preload("res://Assets/act4_storm/storm_loop.wav").duplicate()
	sea_loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
	sea_loop.loop_end = roundi(sea_loop.get_length() * sea_loop.mix_rate)
	surf = _player(sea_loop, &"SFX", -18.0)
	var score: AudioStreamOggVorbis = preload("res://Assets/act4_poseidon_escape/music/vamp_wrath.ogg").duplicate()
	score.loop = true
	pulse = _player(score, &"Music", -45.0)
	impact = _player(null, &"SFX", -14.0)

func _player(stream: AudioStream, bus: StringName, volume: float) -> AudioStreamPlayer:
	var node := AudioStreamPlayer.new()
	node.stream = stream
	node.bus = bus
	node.volume_db = volume
	add_child(node)
	return node

func _sound(kind: StringName) -> void:
	if not is_instance_valid(impact):
		return
	match kind:
		&"arrow":
			impact.stream = preload("res://Assets/sfx_bow.wav")
		&"unleash", &"duel_start":
			impact.stream = preload("res://Assets/act4_storm/thunder.wav")
		&"crash", &"burst", &"wave", &"guard_arrive", &"water_hit":
			impact.stream = preload("res://Assets/act8_scylla/cave_lunge.wav")
		&"bag", &"dash", &"wind":
			impact.stream = preload("res://Assets/sfx_dash.wav")
		&"claim", &"grip_hit", &"disarm", &"parry", &"sword", &"trident", &"boss_hit", &"trident_lower":
			impact.stream = preload("res://Assets/sfx_sword.wav")
		&"hurt":
			impact.stream = preload("res://Assets/sfx_damage.wav")
		_:
			return
	impact.play()

func _exit_tree() -> void:
	if is_instance_valid(surf):
		surf.stop()
		if is_instance_valid(AudioManager.music_player):
			AudioManager.music_player.stream_paused = music_was_paused
	if is_instance_valid(pulse): pulse.stop()
	if is_instance_valid(impact): impact.stop()

func _panel(bounds: Rect2) -> Panel:
	var panel := Panel.new()
	panel.position = bounds.position
	panel.size = bounds.size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color("09171bed")
	style.border_color = Color("55777e")
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

func _button(parent: Node, text: String, bounds: Rect2, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.position = bounds.position
	button.size = bounds.size
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _to_map() -> void:
	_leave(MAP)

func _primary_action() -> void:
	if duel.phase == DUEL.Phase.WON:
		_leave(ITHACA)
	else:
		restart_checkpoint()

func _leave(path: String) -> void:
	for player in [surf, pulse, impact]:
		if is_instance_valid(player):
			player.stop()
	get_tree().change_scene_to_file(path)

func _build_ui() -> void:
	var top := _panel(Rect2(24, 15, 1104, 72))
	_label(top, "ATO XII   /   POSEIDON", Rect2(19, 7, 660, 30), 24, GOLD)
	objective = _label(top, "", Rect2(21, 41, 615, 23), 17)
	health = _label(top, "", Rect2(637, 24, 326, 27), 17)
	_button(top, "MAPA", Rect2(974, 19, 110, 33), _to_map)
	detail = _label(frame, "", Rect2(96, 577, 960, 47), 19, GOLD)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail.add_theme_color_override("font_shadow_color", Color("071a20"))
	detail.add_theme_constant_override("shadow_outline_size", 7)
	controls = _label(frame, "", Rect2(24, 624, 1104, 20), 12)
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	interaction_hint = _label(frame, "", Rect2(0, 0, 300, 24), 14, GOLD)
	interaction_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dash_hint = _label(frame, "DIREITO / Q · DASH", Rect2(0, 0, 132, 20), 11, Color("a3dfeb"))
	dash_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for hint in [interaction_hint, dash_hint]:
		hint.add_theme_color_override("font_shadow_color", Color("06131c"))
		hint.add_theme_constant_override("shadow_outline_size", 5)
	result = _panel(Rect2(245, 180, 662, 284))
	title = _label(result, "", Rect2(24, 19, 613, 42), 27, GOLD)
	result_text = _label(result, "", Rect2(24, 75, 613, 130), 17)
	result_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	action = _button(result, "", Rect2(24, 222, 286, 42), _primary_action)
	_button(result, "VOLTAR AO MAPA", Rect2(350, 222, 286, 42), _to_map)
