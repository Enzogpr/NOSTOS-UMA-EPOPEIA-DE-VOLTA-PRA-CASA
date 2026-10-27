extends "res://Ato3_Ciclope/Cutscenes/Act3_AthenaFarewellCutscene.gd"
## The battle ends before this scene. It owns only the farewell, never saves.
## advance(delta) is the same clock used for preview and campaign playback.
signal aftermath_finished(record: Dictionary)
const STORY := "res://Ato4_Tempestade/Cutscenes/PoseidonAftermath.dialogue.json"
const DIRECTOR_PATH := "res://Ato4_Tempestade/Cutscenes/PoseidonAftermathStage.gd"
const SCORE := preload("res://Ato4_Tempestade/Gameplay/PoseidonScore.gd")
const SOUND := preload("res://Ato4_Tempestade/Gameplay/PoseidonEncounterAudio.gd")
const END_FADE := 0.65
@export var audio_enabled := true
@export var standalone_result := true
var handoff_record: Dictionary = {}
var manual_score_clock := false
var director: Node2D
var score: Node
var encounter_audio: Node
var shot_clock := 0.0
var ending_clock := 0.0
var completion_count := 0
var finished := false
var score_started := false
var wind_released := false
var visited_shots: Array[String] = []
var sound_events: Array[String] = []
var result_panel: Panel
var record: Dictionary = {}

func _ready() -> void:
	set_meta("hide_main_hud",true)
	set_meta("cinematic_active",true)
	GameManager.combat_mode=false
	MainHUD.set_station("Ato 4 - O que restou")
	beats=JSON.parse_string(FileAccess.get_file_as_string(STORY))
	world.hide()
	$MindAmbience.stop()
	director=load(DIRECTOR_PATH).new()
	director.name="AftermathStage"
	stage.add_child(director)
	stage.move_child(director,1)
	director.sound_cue.connect(_sound)
	resized.connect(_fit_stage)
	_fit_stage()
	$Stage/Opening.hide()
	$Stage/TopTitle.text="ATO IV   /   O QUE RESTOU"
	$Stage/Captions.position=Vector2(60,472)
	$Stage/Captions.size=Vector2(1032,123)
	dialogue.size=Vector2(1014,82)
	dialogue.add_theme_font_size_override("normal_font_size",25)
	for path in ["BottomShade","TopBar","TopTitle","Captions","Controls"]:
		get_node("Stage/"+path).z_index=20
	black.z_index=29
	$Stage/Controls/SkipButton.hide()
	$Stage/Controls/InputHint.text="ESPAÇO / ENTER / CLIQUE · CONTINUAR   ESC · PAUSA"
	auto_button.pressed.connect(_toggle_auto)
	next_button.pressed.connect(_advance_requested)
	_update_auto_button()
	_setup_audio()
	_build_result()
	black.color.a=1.0
	can_advance=true
	_show_beat(0)

func _setup_audio() -> void:
	previous_music_volume=AudioManager.music_player.volume_db
	music_ducked=audio_enabled and AudioManager.music_player.playing
	if music_ducked: AudioManager.music_player.volume_db=previous_music_volume-24.0
	score=SCORE.new()
	add_child(score)
	score.setup(audio_enabled,manual_score_clock)
	score.set_process(false)
	score.accent.connect(_score_accent)
	encounter_audio=SOUND.new()
	add_child(encounter_audio)
	encounter_audio.mix_offset_db=-6.0
	encounter_audio.setup(audio_enabled)
	encounter_audio.update_state(0.2,0.8,0.0,false)

func _start_escape_score() -> void:
	if score_started: return
	score_started=true
	# The instrumental begins during the hand reaching for the bag. Its authored
	# wind cue at3.273s falls near the end of the following bag-opening shot.
	score.restore({"section":"escape","elapsed":0.0,"absolute":0.0,"start":0.0,"pending":"","pending_at":-1.0,"wind_sent":false,"running":true})

func _score_accent(kind: String) -> void:
	if kind!="wind_release" or wind_released: return
	wind_released=true
	_sound("gust")
	encounter_audio.update_state(0.75,0.1,0.0,false)

func _sound(kind: String) -> void:
	sound_events.append(kind)
	if not is_instance_valid(encounter_audio): return
	var cue: String="creak" if kind in ["grip","cloth","deck"] else "divine_rumble" if kind in ["threat","rumble"] else "splash" if kind in ["surge","water"] else kind
	encounter_audio.cue(cue)

func _show_beat(index: int) -> void:
	if index<0 or index>=beats.size() or finished: return
	current_beat=index
	shot_clock=0.0
	type_elapsed=0.0
	hold_elapsed=0.0
	input_cooldown=0.2
	var beat: Dictionary=beats[index]
	var shot: String=str(beat.shot)
	visited_shots.append(shot)
	dialogue.text=str(beat.text)
	dialogue.visible_characters=0
	speaker.text=str(beat.speaker).to_upper()
	var tint:=Color(0.40,0.88,0.92) if str(beat.speaker)=="Poseidon" else Color(1.0,0.78,0.53)
	speaker.add_theme_color_override("font_color",tint)
	$Stage/Captions/Accent.color=tint
	speaker_context.text="A FROTA DE ÍTACA · O ÚLTIMO NAVIO"
	$Stage/Captions.visible=not str(beat.text).is_empty()
	$Stage/BottomShade.modulate.a=1.0 if $Stage/Captions.visible else 0.45
	director.present(index,beat)
	if score_started: score.set_frozen(false)
	if shot=="bag_reveal": _start_escape_score()
	_update_next_button()

func _shot_duration() -> float:
	if current_beat<0 or current_beat>=beats.size(): return 0.0
	var text: String=str(beats[current_beat].text)
	var reading: float=float(text.length())/maxf(1.0,characters_per_second)+1.2 if not text.is_empty() else 0.0
	return maxf(float(beats[current_beat].duration),reading)

func _process(delta: float) -> void:
	if not manual_score_clock: advance(delta)

func step(delta: float) -> void:
	advance(delta)

func advance(delta: float) -> void:
	if finished or delta<=0.0 or get_tree().paused: return
	var remaining: float=delta*playback_speed
	input_cooldown=maxf(0,input_cooldown-remaining)
	if is_ending:
		_tick_ending(remaining)
		return
	if not can_advance or director==null: return
	while remaining>0.00001 and not is_ending:
		var span: float=minf(remaining,maxf(0.0,_shot_duration()-shot_clock))
		if span>0.0:
			shot_clock+=span
			type_elapsed+=span
			elapsed+=span
			if score_started: score.advance(span)
			dialogue.visible_characters=mini(dialogue.get_total_character_count(),int(type_elapsed*characters_per_second))
			director.speaking=dialogue.visible_characters<dialogue.get_total_character_count()
			director.seek(shot_clock,span)
			black.color.a=maxf(0.0,1.0-elapsed/0.55)
			remaining-=span
		if shot_clock>=_shot_duration()-0.00001:
			if autoplay:
				_advance()
			else:
				if score_started: score.set_frozen(true)
				# The authored action is held, while secondary sea/breathing motion
				# may keep running until the reader explicitly continues.
				director.speaking=false
				director.seek(shot_clock,remaining)
				break
	_update_next_button()
	if is_ending and remaining>0.0: _tick_ending(remaining)

func _update_next_button() -> void:
	if finished: return
	if dialogue.visible_characters<dialogue.get_total_character_count(): next_button.text="MOSTRAR FALA  ›"
	elif shot_clock<_shot_duration(): next_button.text="AGUARDE  ›"
	else: next_button.text="CONTINUAR  ›"

func _advance_requested() -> void:
	if not can_advance or is_ending or input_cooldown>0.0: return
	input_cooldown=0.2
	if dialogue.visible_characters<dialogue.get_total_character_count():
		type_elapsed=float(dialogue.get_total_character_count())/maxf(1.0,characters_per_second)
		dialogue.visible_characters=dialogue.get_total_character_count()
		director.speaking=false
	elif shot_clock>=_shot_duration()-0.00001:
		_advance()
	_update_next_button()

func _advance() -> void:
	if is_ending or finished or shot_clock<_shot_duration()-0.00001: return
	if current_beat+1<beats.size(): _show_beat(current_beat+1)
	else: _finish()

func _toggle_auto() -> void:
	autoplay=not autoplay
	_update_auto_button()
	if autoplay and not is_ending and shot_clock>=_shot_duration()-0.00001: _advance()

func _finish() -> void:
	if is_ending or finished or current_beat!=beats.size()-1 or shot_clock<_shot_duration()-0.00001: return
	is_ending=true
	can_advance=false
	ending_clock=0.0
	$Stage/Controls.hide()

func _tick_ending(delta: float) -> void:
	if finished: return
	ending_clock=minf(END_FADE,ending_clock+delta)
	black.color.a=smoothstep(0.0,END_FADE,ending_clock)
	$Stage/Captions.modulate.a=1.0-black.color.a
	if score_started: score.advance(delta)
	if ending_clock<END_FADE: return
	finished=true
	completion_count+=1
	stop_audio()
	release_music()
	record=handoff_record.duplicate(true)
	record["escaped"]=true
	record["aftermath_completed"]=true
	record["survivors"]=43
	record["bag_opened"]=wind_released
	record["aftermath_shots"]=visited_shots.duplicate()
	var external_owner: bool=not aftermath_finished.get_connections().is_empty()
	aftermath_finished.emit(record)
	cinematic_finished.emit()
	if external_owner or not standalone_result: hide()
	else: result_panel.show()

func _build_result() -> void:
	result_panel=Panel.new()
	result_panel.position=Vector2(276,220)
	result_panel.size=Vector2(600,220)
	result_panel.z_index=35
	var style:=StyleBoxFlat.new()
	style.bg_color=Color(0.015,0.04,0.06,0.98)
	style.border_color=Color(0.25,0.54,0.58)
	style.set_border_width_all(1)
	result_panel.add_theme_stylebox_override("panel",style)
	stage.add_child(result_panel)
	var title:=Label.new()
	title.text="QUARENTA E TRÊS SOBREVIVERAM"
	title.position=Vector2(25,28)
	title.add_theme_font_size_override("font_size",25)
	result_panel.add_child(title)
	var subtitle:=Label.new()
	subtitle.text="Um único navio escapou de Poseidon."
	subtitle.position=Vector2(25,82)
	subtitle.add_theme_font_size_override("font_size",20)
	result_panel.add_child(subtitle)
	var button:=Button.new()
	button.text="VOLTAR AO MAPA"
	button.position=Vector2(25,150)
	button.size=Vector2(550,42)
	button.pressed.connect(func(): get_tree().change_scene_to_file("res://Scenes/WorldMap.tscn"))
	result_panel.add_child(button)
	result_panel.hide()

func stop_audio() -> void:
	if is_instance_valid(score): score.stop_audio()
	if is_instance_valid(encounter_audio): encounter_audio.stop_audio()

func release_music() -> void:
	if music_ducked and is_instance_valid(AudioManager): AudioManager.music_player.volume_db=previous_music_volume
	music_ducked=false

func _exit_tree() -> void:
	stop_audio()
	release_music()
