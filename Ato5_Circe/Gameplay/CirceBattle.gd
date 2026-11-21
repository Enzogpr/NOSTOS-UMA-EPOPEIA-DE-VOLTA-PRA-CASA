extends Control
const MODEL := preload("res://Ato5_Circe/Gameplay/CirceBattleModel.gd")
const VISUALS := preload("res://Ato5_Circe/Gameplay/CirceBattleStage.gd")
const ATTRIBUTES := preload("res://Code/PlayerAttributes.gd")
const DESIGN := Vector2(1152,648)
@export var enforce_campaign_gate := true
@export var audio_enabled := true
var model: MODEL
var visuals: VISUALS
var stage: Node2D
var phase_label: Label
var health_label: Label
var status_label: Label
var boss_bar: Meter
var focus_bar: Meter
var intro: Panel
var failure: Panel
var result: Panel
var notice: Label
var notice_time := 0.0
var gate_open := false
var previous_music_paused := false
var ambience: AudioStreamPlayer
var effects: AudioStreamPlayer
var previous_hp := -1

class Meter extends Control:
	var tint := Color.WHITE
	var value := 100.0:
		set(next): value=next; queue_redraw()
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO,size),Color("252030"))
		draw_rect(Rect2(Vector2.ZERO,Vector2(size.x*clampf(value/100,0,1),size.y)),tint)

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE; set_meta("hide_main_hud",true)
	MainHUD.set_station("Ato V - O palácio de Circe")
	model=MODEL.new(); model.apply_player_stats(ATTRIBUTES.capture(GameManager))
	gate_open=GameManager.standalone_stage_preview or not enforce_campaign_gate or (GameManager.circe_search_completed and GameManager.circe_moly_found)
	stage=Node2D.new(); add_child(stage)
	visuals=VISUALS.new(); visuals.model=model; stage.add_child(visuals)
	_build_ui()
	model.feedback.connect(_feedback); model.cue.connect(_cue)
	model.health_changed.connect(func(_hp: int): _sync_hp())
	model.won.connect(_won); model.failed.connect(func(): failure.show())
	GameManager.player_stats_changed.connect(_apply_stats)
	resized.connect(_fit); _fit()
	if audio_enabled: _setup_audio()
	_update_ui()

func _fit() -> void:
	var factor := minf(size.x/DESIGN.x,size.y/DESIGN.y)
	stage.scale=Vector2.ONE*factor; stage.position=(size-DESIGN*factor)*0.5

func _panel(at: Vector2,dimensions: Vector2) -> Panel:
	var node := Panel.new(); node.position=at; node.size=dimensions; node.z_index=20
	var style := StyleBoxFlat.new(); style.bg_color=Color(0.045,0.025,0.075,0.94)
	style.border_color=Color("a68c63"); style.set_border_width_all(1); style.set_corner_radius_all(5)
	node.add_theme_stylebox_override("panel",style); stage.add_child(node); return node

func _label(text: String,at: Vector2,dimensions: Vector2,font_size: int,parent: Node=null,wrap: bool=false) -> Label:
	var label := Label.new()
	if wrap: label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	label.text=text; label.position=at; label.size=dimensions; label.z_index=21
	label.add_theme_font_size_override("font_size",font_size); label.add_theme_color_override("font_color",Color("f2e4c8"))
	label.add_theme_color_override("font_shadow_color",Color("10091b")); label.add_theme_constant_override("shadow_outline_size",4)
	label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	(stage if parent==null else parent).add_child(label); return label

func _button(text: String,at: Vector2,dimensions: Vector2,action: Callable,parent: Node=null) -> Button:
	var button := Button.new(); button.text=text; button.position=at; button.size=dimensions; button.z_index=22
	button.add_theme_font_size_override("font_size",16); button.pressed.connect(action)
	(stage if parent==null else parent).add_child(button); return button

func _bar(at: Vector2,dimensions: Vector2,color: Color,parent: Node) -> Meter:
	var bar := Meter.new(); bar.position=at; bar.size=dimensions; bar.tint=color
	bar.z_index=21; bar.mouse_filter=Control.MOUSE_FILTER_IGNORE; parent.add_child(bar); return bar

func _build_ui() -> void:
	var top := _panel(Vector2(24,16),Vector2(1104,79)); top.mouse_filter=Control.MOUSE_FILTER_IGNORE
	phase_label=_label("CIRCE  /  O PALÁCIO ENFEITIÇADO",Vector2(18,8),Vector2(880,26),20,top)
	_label("CIRCE",Vector2(18,45),Vector2(70,22),14,top)
	boss_bar=_bar(Vector2(98,51),Vector2(607,8),Color("bd75cf"),top)
	_button("MAPA",Vector2(1001,24),Vector2(108,31),return_to_map)
	health_label=_label("",Vector2(735,8),Vector2(225,23),14,top)
	status_label=_label("",Vector2(735,34),Vector2(225,21),13,top)
	focus_bar=_bar(Vector2(735,61),Vector2(210,5),Color("e3cf86"),top)
	notice=_label("",Vector2(110,110),Vector2(930,55),17,null,true)
	notice.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var intro_height := 344.0 if gate_open else 184.0
	intro = _panel(Vector2(254,(DESIGN.y-intro_height)*0.5),Vector2(644,intro_height))
	var intro_content := VBoxContainer.new()
	intro_content.add_theme_constant_override("separation",16)
	intro.add_child(intro_content)
	intro_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	intro_content.offset_left = 26
	intro_content.offset_right = -28
	intro_content.offset_top = 20
	intro_content.offset_bottom = -17
	_label("O PALÁCIO DE CIRCE",Vector2.ZERO,Vector2.ZERO,27,intro_content)
	var text := "A holimoli repele os encantamentos automaticamente.\n\nDesvie das mesas e raízes. Acerte Circe para interromper o golpe dela.\n\nSegurar E revela a verdadeira entre as cópias, mas exige ficar parado. No fim, o próprio salão reagirá aos seus movimentos."
	if not gate_open: text="Encontre a holimoli e retorne ao palácio antes de enfrentar Circe."
	var description := _label(text,Vector2.ZERO,Vector2.ZERO,17,intro_content,true)
	description.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var intro_action := _button("ENFRENTAR CIRCE" if gate_open else "BUSCAR A HOLIMOLI",Vector2.ZERO,Vector2.ZERO,begin if gate_open else return_to_forest,intro_content)
	intro_action.custom_minimum_size.y = 35
	failure=_panel(Vector2(306,215),Vector2(540,220)); failure.hide()
	_label("A MAGIA TOMOU A ARENA",Vector2(24,22),Vector2(490,36),25,failure)
	_label("A próxima tentativa começa na primeira fase.\nSeus atributos e sacrifícios foram preservados.",Vector2(24,76),Vector2(492,63),18,failure)
	_button("TENTAR NOVAMENTE  ·  R",Vector2(24,161),Vector2(492,36),restart_checkpoint,failure)
	result=_panel(Vector2(271,190),Vector2(610,258)); result.hide()
	_label("CIRCE CEDEU",Vector2(26,24),Vector2(558,36),29,result)
	_label("Circe baixou o cajado e o salão se aquietou.\n\nSeus homens ainda aguardam o resgate.\nO confronto foi concluído.",Vector2(26,81),Vector2(558,105),19,result,true)
	_button("SEGUIR PARA O SUBMUNDO",Vector2(26,205),Vector2(350,35),continue_to_underworld,result)
	_button("MAPA",Vector2(391,205),Vector2(193,35),return_to_map,result)

func begin() -> void:
	if not gate_open: return
	intro.hide(); GameManager.reset_encounter(); model.begin()

func _movement() -> Vector2:
	return Vector2(float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT))-float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN))-float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))

func _read_input() -> void:
	var local_mouse := stage.to_local(get_global_mouse_position())
	model.set_input(_movement(),local_mouse-model.position,Input.is_physical_key_pressed(KEY_SHIFT),Input.is_physical_key_pressed(KEY_E))

func _physics_process(delta: float) -> void:
	_read_input()
	var remaining := minf(delta,0.1)
	while remaining>0:
		var step := minf(remaining,1.0/120); model.tick(step); remaining-=step
	_sync_hp(); _update_ui()
	if notice_time>0: notice_time-=delta; notice.visible=notice_time>0

func _process(delta: float) -> void:
	if is_instance_valid(visuals): visuals.update_visuals(delta)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode==KEY_R: restart_checkpoint()
		elif event.physical_keycode==KEY_Q: _read_input(); model.request_dash()
		elif event.physical_keycode==KEY_J or event.physical_keycode==KEY_SPACE: _read_input(); model.request_attack()
	elif event is InputEventMouseButton and event.pressed:
		_read_input()
		if event.button_index==MOUSE_BUTTON_LEFT: model.request_attack()
		elif event.button_index==MOUSE_BUTTON_RIGHT: model.request_dash()

func _apply_stats() -> void:
	model.apply_player_stats(ATTRIBUTES.capture(GameManager)); _update_ui()

func _sync_hp() -> void:
	if not gate_open or previous_hp==model.hp: return
	previous_hp=model.hp; GameManager.player_current_hp=model.hp; GameManager.player_health_changed.emit(model.hp)

func _feedback(message: String) -> void:
	notice.text=message; notice_time=6; notice.show()

func _update_ui() -> void:
	var names := {MODEL.Phase.READY:"O PALÁCIO ENFEITIÇADO",MODEL.Phase.DUEL:"A FEITICEIRA PERDE A VANTAGEM",MODEL.Phase.MIRRORS:"O PALÁCIO DAS CÓPIAS",MODEL.Phase.PALACE:"CIRCE CONTROLA O SALÃO",MODEL.Phase.WON:"CIRCE CEDEU",MODEL.Phase.FAILED:"NOVA TENTATIVA"}
	phase_label.text="CIRCE  /  "+names[model.phase]
	boss_bar.value=float(model.boss_hp)/float(model.tuning.boss_hp)*100
	health_label.text="VIDA  %d / %d   ·   CLAREZA %d%%" % [model.hp,model.max_hp,model.focus]
	focus_bar.value=model.focus
	status_label.text = ""
	if model.observing: status_label.text="CONCENTRANDO %.0f%%" % (model.observe_progress/float(model.tuning.observe_charge)*100)
	elif model.reveal_time>0: status_label.text="VERDADE REVELADA"

func restart_checkpoint() -> void:
	if not gate_open or model.phase==MODEL.Phase.WON: return
	intro.hide()
	failure.hide()
	notice.hide()
	notice_time = 0.0
	model.retry()
	_sync_hp()
	_update_ui()

func _won() -> void:
	if enforce_campaign_gate: GameManager.complete_circe_battle()
	result.show()

func return_to_map() -> void:
	get_tree().paused=false; get_tree().change_scene_to_file("res://Scenes/WorldMap.tscn")

func return_to_forest() -> void:
	get_tree().change_scene_to_file("res://Ato5_Circe/Gameplay/CirceForest.tscn")

func continue_to_underworld() -> void:
	if model.phase!=MODEL.Phase.WON: return
	get_tree().change_scene_to_file("res://Ato6_Submundo/Gameplay/UnderworldCrossing.tscn")

func _setup_audio() -> void:
	previous_music_paused=AudioManager.music_player.stream_paused; AudioManager.music_player.stream_paused=true
	ambience=AudioStreamPlayer.new(); ambience.stream=preload("res://Assets/act5_circe/forest_ambience.wav")
	ambience.volume_db=-22; add_child(ambience); ambience.finished.connect(ambience.play); ambience.play()
	effects=AudioStreamPlayer.new(); effects.max_polyphony=6; effects.volume_db=-15; add_child(effects)
	if AudioServer.get_bus_index("SFX")>=0: ambience.bus="SFX"; effects.bus="SFX"

func _cue(kind: String) -> void:
	if not audio_enabled or not is_instance_valid(effects): return
	var path := "res://Assets/act5_circe/soft_chime.wav"
	if kind=="dash": path="res://Assets/sfx_dash.wav"
	elif kind in ["sword","staff"]: path="res://Assets/sfx_sword.wav"
	elif kind in ["hurt","hit","impact"]: path="res://Assets/sfx_damage.wav"
	effects.stream=load(path); effects.pitch_scale=0.65 if kind in ["cast","impact"] else 1.35 if kind in ["flower","reveal"] else 1; effects.play()

func _exit_tree() -> void:
	if is_instance_valid(ambience):
		if ambience.finished.is_connected(ambience.play): ambience.finished.disconnect(ambience.play)
		ambience.stop()
	if is_instance_valid(effects): effects.stop()
	if audio_enabled and is_instance_valid(AudioManager.music_player): AudioManager.music_player.stream_paused=previous_music_paused
