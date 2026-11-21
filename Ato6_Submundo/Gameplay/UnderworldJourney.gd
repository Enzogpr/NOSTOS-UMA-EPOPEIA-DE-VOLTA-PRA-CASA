extends Control
const CROSSING := preload("res://Ato6_Submundo/Gameplay/UnderworldCrossingModel.gd")
const ORACLE := preload("res://Ato6_Submundo/Gameplay/UnderworldOracleModel.gd")
const ORACLE_STAGE := preload("res://Ato6_Submundo/Gameplay/UnderworldStage.gd")
const RUN_STAGE := preload("res://Ato6_Submundo/Gameplay/UnderworldRunStage.gd")
const ATTRIBUTES := preload("res://Code/PlayerAttributes.gd")
const DESIGN := Vector2(1152,648)
@export_enum("Travessia","Tirésias") var chapter := 0
@export var enforce_campaign_gate := true
@export var audio_enabled := true
var model: RefCounted
var visuals: Node2D
var stage: Node2D
var objective: Label
var status: Label
var meter_label: Label
var meter: Meter
var notice: Label
var notice_time := 0.0
var intro: Panel
var failure: Panel
var result: Panel
var dialogue: Panel
var resting_place: Panel
var speaker: Label
var sentence: Label
var dialogue_key := ""
var dialogue_index := 0
var gate_open := false
var previous_music_paused := false
var ambience: AudioStreamPlayer
var effects: AudioStreamPlayer
var surge: AudioStreamPlayer
var result_delay := -1.0

class Meter extends Control:
	var value := 0.0:
		set(next): value=next; queue_redraw()
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO,size),Color("182c32"))
		draw_rect(Rect2(Vector2.ZERO,Vector2(size.x*clampf(value/100,0,1),size.y)),Color("b4d3c7"))

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE; set_meta("hide_main_hud",true)
	MainHUD.set_station("Ato VI - O Submundo")
	model=CROSSING.new() if chapter==0 else ORACLE.new()
	model.apply_player_stats(ATTRIBUTES.capture(GameManager))
	gate_open=GameManager.standalone_stage_preview or not enforce_campaign_gate or (GameManager.circe_battle_completed if chapter==0 else GameManager.underworld_crossing_completed)
	if chapter==0:
		model.resume(0 if GameManager.underworld_crossing_completed else GameManager.underworld_checkpoint,GameManager.underworld_mother_heard)
		model.checkpoint_reached.connect(_checkpoint); model.mother_heard.connect(_mother_heard)
	else: model.resume(0 if GameManager.underworld_prophecy_completed else GameManager.underworld_vision_index)
	stage=Node2D.new(); add_child(stage)
	visuals = RUN_STAGE.new() if chapter == 0 else ORACLE_STAGE.new()
	if chapter == 1: visuals.chapter = 1
	visuals.model = model; stage.add_child(visuals)
	_build_ui()
	model.feedback.connect(_feedback); model.cue.connect(_cue); model.dialogue_requested.connect(_open_dialogue)
	if chapter == 0: model.rest_reached.connect(_rest_reached)
	model.failed.connect(func(): notice.hide(); failure.show()); model.completed.connect(_completed)
	GameManager.player_stats_changed.connect(_apply_stats)
	resized.connect(_fit); _fit()
	if audio_enabled: _setup_audio()
	_update_ui()

func _fit() -> void:
	var factor := minf(size.x/DESIGN.x,size.y/DESIGN.y)
	stage.scale=Vector2.ONE*factor; stage.position=(size-DESIGN*factor)*0.5

func _panel(at: Vector2,dimensions: Vector2) -> Panel:
	var panel := Panel.new(); panel.position=at; panel.size=dimensions; panel.z_index=20
	var skin := StyleBoxFlat.new(); skin.bg_color=Color(0.025,0.065,0.079,0.95)
	skin.border_color=Color("7f9f9a"); skin.set_border_width_all(1); skin.set_corner_radius_all(5)
	panel.add_theme_stylebox_override("panel",skin); stage.add_child(panel); return panel

func _label(text: String,at: Vector2,dimensions: Vector2,font_size: int,parent: Node=null,wrap: bool=false) -> Label:
	var label := Label.new()
	if wrap: label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	label.text=text; label.position=at; label.size=dimensions; label.z_index=21
	label.add_theme_font_size_override("font_size",font_size); label.add_theme_color_override("font_color",Color("e8e4cd"))
	label.add_theme_color_override("font_shadow_color",Color("07191e")); label.add_theme_constant_override("shadow_outline_size",4)
	label.mouse_filter=Control.MOUSE_FILTER_IGNORE; (stage if parent==null else parent).add_child(label); return label

func _button(text: String,at: Vector2,dimensions: Vector2,action: Callable,parent: Node=null) -> Button:
	var button := Button.new(); button.text=text; button.position=at; button.size=dimensions; button.z_index=22
	button.focus_mode=Control.FOCUS_NONE; button.add_theme_font_size_override("font_size",16); button.pressed.connect(action)
	(stage if parent==null else parent).add_child(button); return button

func _build_ui() -> void:
	var header := _panel(Vector2(24,16),Vector2(1104,76)); header.mouse_filter=Control.MOUSE_FILTER_IGNORE
	_label("SUBMUNDO  /  "+("A FUGA DAS ALMAS" if chapter==0 else "OS ECOS DE TIRÉSIAS"),Vector2(17,7),Vector2(860,26),21,header)
	objective=_label("",Vector2(17,42),Vector2(880,25),17,header)
	_button("MAPA",Vector2(1001,25),Vector2(108,32),return_to_map)
	var footer := _panel(Vector2(24,576 if chapter == 0 else 562),Vector2(1104,60 if chapter == 0 else 69)); footer.mouse_filter=Control.MOUSE_FILTER_IGNORE
	meter_label=_label("",Vector2(15,7),Vector2(325,25),16,footer)
	meter=Meter.new(); meter.position=Vector2(15,39); meter.size=Vector2(190,7); meter.mouse_filter=Control.MOUSE_FILTER_IGNORE; footer.add_child(meter)
	status=_label("",Vector2(335,7),Vector2(750,25),15,footer)
	_label("A/D OU ←/→ · FAIXA     ESPAÇO · PULAR     S/↓ · DESLIZAR     Q · DASH     R · RECOMEÇAR     ESC · PAUSA" if chapter == 0 else "WASD / SETAS · MOVER     Q · DASH     E · LER     R · RECOMEÇAR     ESC · PAUSA",Vector2(222,33 if chapter == 0 else 37),Vector2(865,22),13,footer)
	notice=_label("",Vector2(100,105),Vector2(950,48),17,null,true); notice.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	intro=_panel(Vector2(254,173),Vector2(644,306))
	_label("A FUGA DAS ALMAS" if chapter==0 else "OS ECOS DE TIRÉSIAS",Vector2(26,20),Vector2(590,37),27,intro)
	var explanation := "Odisseu ganha velocidade enquanto foge dos mortos. No Submundo, a culpa distorce o espaço, e uma passagem próxima pode recuar diante de seus olhos.\n\nMude de faixa com A/D ou ←/→. Pule pedras com Espaço e deslize sob as vigas com S ou ↓. As lanternas guardam seu avanço."
	if chapter==1: explanation="Seus passos voltam como ecos, inclusive quando você para. Na primeira prova, deixe o primeiro eco sobre o selo azul e ocupe o selo dourado.\n\nCada prova revela uma frase de Tirésias. E mostra uma dica. R recomeça a prova atual."
	if not gate_open: explanation="Conclua o confronto com Circe para alcançar o Submundo." if chapter==0 else "Conclua a fuga das almas antes de consultar Tirésias."
	_label(explanation,Vector2(26,75),Vector2(590,165),18,intro,true)
	_button("SEGUIR ADIANTE" if gate_open else "VOLTAR AO MAPA",Vector2(26,251),Vector2(590,35),begin if gate_open else return_to_map,intro)
	failure=_panel(Vector2(291,210),Vector2(570,226)); failure.hide()
	_label("AS ALMAS ALCANÇARAM ODISSEU" if chapter == 0 else "A PROVA FOI INTERROMPIDA",Vector2(24,23),Vector2(520,37),24,failure)
	_label("Retome da última lanterna.\nPule as pedras e deslize sob as vigas baixas.",Vector2(24,84),Vector2(520,65),17,failure)
	_button("TENTAR NOVAMENTE  ·  R",Vector2(24,170),Vector2(522,34),restart_checkpoint,failure)
	result=_panel(Vector2(286,197),Vector2(580,254)); result.hide()
	_label("A OUTRA MARGEM" if chapter==0 else "O CAMINHO AINDA EXISTE",Vector2(26,22),Vector2(528,36),26,result)
	var end_text := "As almas ficaram para trás.\nTirésias espera além da passagem." if chapter==0 else "Odisseu permanece imóvel. Seu reflexo já começou a caminhar.\n\nA consulta foi concluída."
	_label(end_text,Vector2(26,78),Vector2(528,91),19,result,true)
	if chapter==0:
		_button("PROCURAR TIRÉSIAS",Vector2(26,174),Vector2(528,34),continue_to_oracle,result)
		_button("VOLTAR AO MAPA",Vector2(26,215),Vector2(528,29),return_to_map,result)
	else:
		_button("SEGUIR PARA AS SEREIAS",Vector2(26,200),Vector2(286,34),continue_to_sirens,result)
		_button("VOLTAR AO MAPA",Vector2(324,200),Vector2(230,34),return_to_map,result)
	if chapter == 0:
		resting_place = _panel(Vector2(236,102),Vector2(680,241))
		_label("A LUZ DE ANTICLEIA",Vector2(26,21),Vector2(628,38),27,resting_place)
		_label("O caminho aquieta por um instante. Anticleia espera junto à lanterna.",Vector2(26,79),Vector2(628,57),18,resting_place,true)
		_button("FALAR COM ANTICLEIA  ·  E",Vector2(26,172),Vector2(309,39),func(): model.request_interact(),resting_place)
		_button("CONTINUAR A FUGA",Vector2(348,172),Vector2(306,39),_leave_rest,resting_place)
		resting_place.hide()
	dialogue=_panel(Vector2(85,405),Vector2(982,144)); dialogue.hide()
	speaker=_label("",Vector2(23,13),Vector2(800,26),19,dialogue)
	sentence=_label("",Vector2(23,47),Vector2(935,59),21,dialogue,true)
	_button("CONTINUAR  ›",Vector2(740,107),Vector2(219,28),advance_dialogue,dialogue)

func begin() -> void:
	if not gate_open: return
	intro.hide(); GameManager.reset_encounter(); model.begin()

func _movement() -> Vector2:
	return Vector2(float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT))-float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN))-float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))

func _physics_process(delta: float) -> void:
	if chapter == 1: model.set_input(_movement())
	var remaining := minf(delta,0.1)
	while remaining>0:
		var step := minf(remaining,1.0/120); model.tick(step); remaining-=step
	_update_ui()
	if notice_time>0: notice_time-=delta; notice.visible=notice_time>0
	if result_delay>=0:
		result_delay-=delta
		if result_delay<0: result.show()

func _process(delta: float) -> void:
	visuals.update_visuals(delta)
	if chapter == 0 and is_instance_valid(surge):
		var running: bool = model.phase == model.Phase.ACTIVE
		var level_db := lerpf(-37.0, -22.0, model.pressure / 100.0) if running else -51.0
		surge.volume_db = move_toward(surge.volume_db, level_db, delta * 28.0)

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
	if dialogue.visible:
		if key in [KEY_SPACE, KEY_ENTER, KEY_E]:
			advance_dialogue()
			get_viewport().set_input_as_handled()
		return
	if intro.visible and key == KEY_ENTER:
		begin()
	elif key == KEY_R:
		restart_checkpoint()
	elif key == KEY_Q:
		if chapter == 1: model.set_input(_movement())
		model.request_dash()
	elif key == KEY_E:
		model.request_interact()
	elif chapter == 0:
		match key:
			KEY_A, KEY_LEFT: model.change_lane(-1)
			KEY_D, KEY_RIGHT: model.change_lane(1)
			KEY_W, KEY_UP, KEY_SPACE: model.request_jump()
			KEY_S, KEY_DOWN: model.request_slide()
			KEY_ENTER: _leave_rest()
			_: return
	else:
		return
	get_viewport().set_input_as_handled()

func _rest_reached() -> void:
	notice.hide()
	resting_place.show()

func _leave_rest() -> void:
	if chapter != 0 or model.phase != model.Phase.REST:
		return
	resting_place.hide()
	model.leave_rest()

func _open_dialogue(key: String) -> void:
	if chapter == 0:
		resting_place.hide()
	else:
		visuals.vision = int(key.trim_prefix("vision_")) if key.begins_with("vision_") else 0
	dialogue_key=key; dialogue_index=0; dialogue.show(); notice.hide(); _show_sentence()
	_cue("memory")

func _show_sentence() -> void:
	var entry: Dictionary=model.level.dialogues[dialogue_key][dialogue_index]
	speaker.text=entry.speaker; sentence.text=entry.text

func advance_dialogue() -> void:
	if not dialogue.visible: return
	dialogue_index+=1
	if dialogue_index<model.level.dialogues[dialogue_key].size(): _show_sentence(); return
	var key := dialogue_key; dialogue.hide(); dialogue_key=""
	if chapter == 1: visuals.vision=0
	model.finish_dialogue(key)
	if chapter == 0: resting_place.show()
	if enforce_campaign_gate and key.begins_with("vision_"): GameManager.record_underworld_vision(model.puzzle)
	_update_ui()

func _apply_stats() -> void: model.apply_player_stats(ATTRIBUTES.capture(GameManager)); _update_ui()

func _checkpoint(index: int) -> void:
	if enforce_campaign_gate: GameManager.record_underworld_checkpoint(index)

func _mother_heard() -> void:
	if enforce_campaign_gate: GameManager.record_underworld_mother()

func _completed() -> void:
	notice.hide()
	if enforce_campaign_gate:
		if chapter==0: GameManager.complete_underworld_crossing()
		else: GameManager.complete_underworld_prophecy()
	_cue("vision")
	if chapter==0: result.show()
	else: result_delay=3.1

func _feedback(message: String) -> void: notice.text=message; notice_time=5; notice.show()

func _update_ui() -> void:
	if chapter==0:
		meter_label.text = "ALMAS  %d%%   ·   LANTERNA %d / 3" % [model.pressure, model.checkpoint + 1]
		meter.value = model.pressure
		objective.text = "Travessia %d%%  ·  Alcance a passagem de Tirésias." % int(model.distance / CROSSING.FINISH * 100)
	else:
		meter_label.text="PROVAS  %d / %d   ·   ECO %.1f s" % [model.puzzle,model.proof_count(),model.echo_interval]
		meter.value=100.0 if model.puzzle>=model.proof_count() else model.proof_progress*100.0
		objective.text=model.room.title if model.puzzle<model.proof_count() else "Tirésias espera na última ilha."
	if chapter == 0:
		status.text = "AS ALMAS ESTÃO PERTO" if model.pressure >= 70.0 else ""
	else:
		status.text = model.prompt()
	if model.phase==model.Phase.COMPLETE: status.text="AS ALMAS FICARAM PARA TRÁS" if chapter==0 else "A PROFECIA FOI LIDA"

func restart_checkpoint() -> void:
	if not gate_open or model.phase not in [model.Phase.ACTIVE,model.Phase.FAILED]: return
	notice.hide(); failure.hide(); model.retry(); visuals.snap_camera(); _update_ui()

func continue_to_oracle() -> void:
	if model.phase!=model.Phase.COMPLETE: return
	get_tree().change_scene_to_file("res://Ato6_Submundo/Gameplay/UnderworldOracle.tscn")

func continue_to_sirens() -> void:
	if chapter != 1 or model.phase != model.Phase.COMPLETE: return
	get_tree().change_scene_to_file("res://Ato7_Sereias/Gameplay/SirenCove.tscn")

func return_to_map() -> void:
	get_tree().paused=false; get_tree().change_scene_to_file("res://Scenes/WorldMap.tscn")

func _setup_audio() -> void:
	previous_music_paused=AudioManager.music_player.stream_paused; AudioManager.music_player.stream_paused=true
	ambience=AudioStreamPlayer.new(); ambience.stream=preload("res://Assets/act6_underworld/river_drone.wav")
	ambience.volume_db=-20; add_child(ambience); ambience.finished.connect(ambience.play); ambience.play()
	effects=AudioStreamPlayer.new(); effects.max_polyphony=5; effects.volume_db=-19; add_child(effects)
	if AudioServer.get_bus_index("SFX")>=0: ambience.bus="SFX"; effects.bus="SFX"
	if chapter != 0: return
	surge = AudioStreamPlayer.new()
	var water: AudioStreamWAV = preload("res://Assets/act6_underworld/river_surge.wav").duplicate()
	water.loop_mode = AudioStreamWAV.LOOP_FORWARD
	water.loop_end = roundi(water.get_length() * water.mix_rate)
	surge.stream = water
	surge.volume_db = -53.0
	surge.bus = effects.bus
	add_child(surge)
	surge.play()

func _cue(kind: String) -> void:
	if not audio_enabled or not is_instance_valid(effects): return
	effects.stream=load("res://Assets/sfx_dash.wav" if kind in ["dash","hit","slide"] else "res://Assets/act5_circe/soft_chime.wav")
	effects.pitch_scale=0.48 if kind in ["lost","hit"] else 0.63 if kind=="slide" else 0.72 if kind=="memory" else 0.85; effects.play()

func _exit_tree() -> void:
	if is_instance_valid(ambience):
		if ambience.finished.is_connected(ambience.play): ambience.finished.disconnect(ambience.play)
		ambience.stop()
	if is_instance_valid(effects): effects.stop()
	if is_instance_valid(surge): surge.stop()
	if audio_enabled and is_instance_valid(AudioManager.music_player): AudioManager.music_player.stream_paused=previous_music_paused
